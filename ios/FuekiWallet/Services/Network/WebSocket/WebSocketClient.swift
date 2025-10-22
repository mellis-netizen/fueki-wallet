//
//  WebSocketClient.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation
import Combine

/// Production-grade WebSocket client with auto-reconnect and subscription management
public actor WebSocketClient {
    private let configuration: NetworkConfiguration
    private let url: URL

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var isConnected = false
    private var reconnectAttempts = 0
    private var pingTimer: Task<Void, Never>?

    // Subscription management
    private var subscriptions: [String: Subscription] = [:]
    private var nextSubscriptionId = 1

    // Message handling
    private var messageHandlers: [String: (Data) -> Void] = [:]
    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()

    // State
    private var connectionState: ConnectionState = .disconnected
    private let stateSubject = PassthroughSubject<ConnectionState, Never>()

    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(Error)
    }

    public struct Subscription {
        let id: String
        let method: String
        let params: [String]
        let handler: (Data) -> Void
    }

    public enum WebSocketMessage {
        case text(String)
        case data(Data)
    }

    public init(
        url: URL,
        configuration: NetworkConfiguration = .default
    ) {
        self.url = url
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Connection Management

    /// Connect to WebSocket server
    public func connect() async throws {
        guard connectionState != .connected else { return }

        updateState(.connecting)

        do {
            webSocketTask = session.webSocketTask(with: url)
            webSocketTask?.resume()

            isConnected = true
            reconnectAttempts = 0
            updateState(.connected)

            // Start receiving messages
            await startReceiving()

            // Start ping timer
            startPingTimer()

            // Resubscribe to all active subscriptions
            await resubscribeAll()

        } catch {
            updateState(.failed(error))
            throw NetworkError.webSocketConnectionFailed
        }
    }

    /// Disconnect from WebSocket server
    public func disconnect() {
        isConnected = false
        pingTimer?.cancel()
        pingTimer = nil

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        updateState(.disconnected)
    }

    /// Check if WebSocket is connected
    public var connected: Bool {
        isConnected
    }

    // MARK: - Subscription Management

    /// Subscribe to events
    public func subscribe(
        method: String,
        params: [String],
        handler: @escaping (Data) -> Void
    ) async throws -> String {
        let subscriptionId = String(nextSubscriptionId)
        nextSubscriptionId += 1

        let subscription = Subscription(
            id: subscriptionId,
            method: method,
            params: params,
            handler: handler
        )

        subscriptions[subscriptionId] = subscription
        messageHandlers[subscriptionId] = handler

        // Send subscription request if connected
        if isConnected {
            try await sendSubscriptionRequest(subscription)
        }

        return subscriptionId
    }

    /// Unsubscribe from events
    public func unsubscribe(_ subscriptionId: String) async throws {
        guard let subscription = subscriptions[subscriptionId] else { return }

        // Send unsubscribe request
        if isConnected {
            let unsubscribeRequest = SubscriptionRequest(
                id: Int(subscriptionId) ?? 0,
                method: "eth_unsubscribe",
                params: [subscription.id]
            )

            try await send(unsubscribeRequest)
        }

        subscriptions.removeValue(forKey: subscriptionId)
        messageHandlers.removeValue(forKey: subscriptionId)
    }

    /// Unsubscribe from all events
    public func unsubscribeAll() async throws {
        let subscriptionIds = Array(subscriptions.keys)

        for id in subscriptionIds {
            try await unsubscribe(id)
        }
    }

    // MARK: - Message Sending

    /// Send message to WebSocket server
    public func send<T: Encodable>(_ message: T) async throws {
        guard isConnected else {
            throw NetworkError.webSocketDisconnected
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)
        let string = String(data: data, encoding: .utf8)!

        let message = URLSessionWebSocketTask.Message.string(string)

        try await webSocketTask?.send(message)
    }

    /// Send raw string message
    public func sendString(_ string: String) async throws {
        guard isConnected else {
            throw NetworkError.webSocketDisconnected
        }

        let message = URLSessionWebSocketTask.Message.string(string)
        try await webSocketTask?.send(message)
    }

    /// Send raw data message
    public func sendData(_ data: Data) async throws {
        guard isConnected else {
            throw NetworkError.webSocketDisconnected
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)
    }

    // MARK: - Message Receiving

    private func startReceiving() async {
        guard isConnected else { return }

        Task {
            do {
                while isConnected {
                    guard let message = try await webSocketTask?.receive() else {
                        break
                    }

                    await handleMessage(message)
                }
            } catch {
                if isConnected {
                    await handleError(error)
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) async {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            await processMessage(data)
            messageSubject.send(.text(text))

        case .data(let data):
            await processMessage(data)
            messageSubject.send(.data(data))

        @unknown default:
            break
        }
    }

    private func processMessage(_ data: Data) async {
        do {
            let decoder = JSONDecoder()

            // Try to decode as subscription response
            if let response = try? decoder.decode(SubscriptionResponse.self, from: data),
               let params = response.params,
               let handler = messageHandlers[params.subscription] {

                // Call subscription handler
                let resultData = try JSONEncoder().encode(params.result)
                handler(resultData)
            }

        } catch {
            print("Error processing WebSocket message: \(error)")
        }
    }

    // MARK: - Reconnection Logic

    private func handleError(_ error: Error) async {
        print("WebSocket error: \(error)")

        isConnected = false
        updateState(.failed(error))

        // Attempt reconnection
        await attemptReconnect()
    }

    private func attemptReconnect() async {
        guard reconnectAttempts < configuration.webSocketMaxReconnectAttempts else {
            print("Max reconnect attempts exceeded")
            updateState(.failed(NetworkError.maxRetriesExceeded))
            return
        }

        reconnectAttempts += 1
        updateState(.reconnecting(attempt: reconnectAttempts))

        let delay = configuration.webSocketReconnectDelay * Double(reconnectAttempts)
        print("Reconnecting in \(delay)s (attempt \(reconnectAttempts))...")

        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        do {
            try await connect()
        } catch {
            await attemptReconnect()
        }
    }

    // MARK: - Ping/Pong

    private func startPingTimer() {
        pingTimer?.cancel()

        pingTimer = Task {
            while isConnected {
                try? await Task.sleep(nanoseconds: UInt64(configuration.webSocketPingInterval * 1_000_000_000))

                if isConnected {
                    try? await webSocketTask?.sendPing { error in
                        if let error = error {
                            print("Ping error: \(error)")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Subscription Helpers

    private func sendSubscriptionRequest(_ subscription: Subscription) async throws {
        let request = SubscriptionRequest(
            id: Int(subscription.id) ?? 0,
            method: subscription.method,
            params: subscription.params
        )

        try await send(request)
    }

    private func resubscribeAll() async {
        for subscription in subscriptions.values {
            try? await sendSubscriptionRequest(subscription)
        }
    }

    // MARK: - State Management

    private func updateState(_ newState: ConnectionState) {
        connectionState = newState
        stateSubject.send(newState)
    }

    public func statePublisher() -> AnyPublisher<ConnectionState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public func messagePublisher() -> AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    deinit {
        disconnect()
    }
}
