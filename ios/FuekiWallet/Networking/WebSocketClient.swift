//
//  WebSocketClient.swift
//  FuekiWallet
//
//  WebSocket support for real-time updates
//

import Foundation
import Combine

/// WebSocket client for real-time communication
public final class WebSocketClient {

    // MARK: - Types

    public enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting
    }

    public enum Event {
        case connected
        case disconnected(Error?)
        case message(Data)
        case text(String)
        case error(Error)
    }

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let url: URL
    private let queue: DispatchQueue

    @Published public private(set) var state: ConnectionState = .disconnected
    private let eventSubject = PassthroughSubject<Event, Never>()

    public var eventPublisher: AnyPublisher<Event, Never> {
        eventSubject.eraseToAnyPublisher()
    }

    // Auto-reconnect configuration
    private let autoReconnect: Bool
    private let maxReconnectAttempts: Int
    private var reconnectAttempts: Int = 0
    private var reconnectTask: Task<Void, Never>?

    // Ping/pong for keeping connection alive
    private var pingTimer: Timer?
    private let pingInterval: TimeInterval

    // MARK: - Initialization

    public init(
        url: URL,
        configuration: URLSessionConfiguration = .default,
        autoReconnect: Bool = true,
        maxReconnectAttempts: Int = 5,
        pingInterval: TimeInterval = 30.0
    ) {
        self.url = url
        self.autoReconnect = autoReconnect
        self.maxReconnectAttempts = maxReconnectAttempts
        self.pingInterval = pingInterval
        self.queue = DispatchQueue(label: "io.fueki.wallet.websocket", qos: .userInitiated)

        // Configure session for WebSocket
        configuration.timeoutIntervalForRequest = 30
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    deinit {
        disconnect()
    }

    // MARK: - Public Methods

    /// Connect to WebSocket
    public func connect() {
        guard state == .disconnected else { return }

        state = .connecting

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        webSocketTask = session.webSocketTask(with: request)
        webSocketTask?.resume()

        // Start receiving messages
        receiveMessage()

        // Start ping timer
        startPingTimer()

        // Update state
        state = .connected
        reconnectAttempts = 0
        eventSubject.send(.connected)
    }

    /// Disconnect from WebSocket
    public func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil

        stopPingTimer()

        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        state = .disconnected
        eventSubject.send(.disconnected(nil))
    }

    /// Send text message
    public func send(text: String) async throws {
        guard state == .connected else {
            throw NetworkError.connectionLost
        }

        let message = URLSessionWebSocketTask.Message.string(text)
        try await webSocketTask?.send(message)
    }

    /// Send binary data
    public func send(data: Data) async throws {
        guard state == .connected else {
            throw NetworkError.connectionLost
        }

        let message = URLSessionWebSocketTask.Message.data(data)
        try await webSocketTask?.send(message)
    }

    /// Send JSON-encodable object
    public func send<T: Encodable>(json object: T, encoder: JSONEncoder = .init()) async throws {
        let data = try encoder.encode(object)
        try await send(data: data)
    }

    // MARK: - Private Methods

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)

                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                self.handleError(error)
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            eventSubject.send(.text(text))

        case .data(let data):
            eventSubject.send(.message(data))

        @unknown default:
            break
        }
    }

    private func handleError(_ error: Error) {
        state = .disconnected
        eventSubject.send(.error(error))
        eventSubject.send(.disconnected(error))

        // Attempt reconnection
        if autoReconnect && reconnectAttempts < maxReconnectAttempts {
            attemptReconnection()
        }
    }

    private func attemptReconnection() {
        guard reconnectAttempts < maxReconnectAttempts else {
            return
        }

        state = .reconnecting
        reconnectAttempts += 1

        // Exponential backoff
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0)

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard let self = self, !Task.isCancelled else { return }

            await MainActor.run {
                self.connect()
            }
        }
    }

    private func startPingTimer() {
        stopPingTimer()

        pingTimer = Timer.scheduledTimer(withTimeInterval: pingInterval, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error = error {
                self?.handleError(error)
            }
        }
    }
}

// MARK: - Combine Extensions
public extension WebSocketClient {
    /// Publisher for text messages only
    var textPublisher: AnyPublisher<String, Never> {
        eventPublisher
            .compactMap { event in
                if case .text(let text) = event {
                    return text
                }
                return nil
            }
            .eraseToAnyPublisher()
    }

    /// Publisher for binary messages only
    var dataPublisher: AnyPublisher<Data, Never> {
        eventPublisher
            .compactMap { event in
                if case .message(let data) = event {
                    return data
                }
                return nil
            }
            .eraseToAnyPublisher()
    }

    /// Publisher for decoded JSON messages
    func jsonPublisher<T: Decodable>(
        type: T.Type,
        decoder: JSONDecoder = .init()
    ) -> AnyPublisher<T, Error> {
        dataPublisher
            .tryMap { data in
                try decoder.decode(T.self, from: data)
            }
            .eraseToAnyPublisher()
    }
}
