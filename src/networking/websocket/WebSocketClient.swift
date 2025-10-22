import Foundation
import Combine

/// WebSocket client for real-time blockchain updates
final class WebSocketClient: NSObject {

    // MARK: - Properties

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var isConnected = false
    private let reconnectStrategy: ReconnectStrategy
    private var reconnectAttempts = 0

    private let messageSubject = PassthroughSubject<WebSocketMessage, Never>()
    private let connectionSubject = PassthroughSubject<ConnectionState, Never>()

    var messagePublisher: AnyPublisher<WebSocketMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    var connectionPublisher: AnyPublisher<ConnectionState, Never> {
        connectionSubject.eraseToAnyPublisher()
    }

    // MARK: - Types

    enum ConnectionState {
        case connecting
        case connected
        case disconnected(Error?)
        case reconnecting(attempt: Int)
    }

    enum WebSocketMessage {
        case text(String)
        case data(Data)
    }

    struct Configuration {
        let autoReconnect: Bool
        let maxReconnectAttempts: Int
        let pingInterval: TimeInterval
        let timeout: TimeInterval

        static let `default` = Configuration(
            autoReconnect: true,
            maxReconnectAttempts: 5,
            pingInterval: 30.0,
            timeout: 10.0
        )
    }

    private let configuration: Configuration

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.reconnectStrategy = ReconnectStrategy(
            maxAttempts: configuration.maxReconnectAttempts
        )

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.waitsForConnectivity = true

        self.session = URLSession(configuration: sessionConfig)

        super.init()
    }

    // MARK: - Connection Management

    func connect(to url: URL) async throws {
        guard !isConnected else { return }

        connectionSubject.send(.connecting)

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        isConnected = true
        reconnectAttempts = 0
        connectionSubject.send(.connected)

        // Start receiving messages
        receiveMessages()

        // Start ping/pong for keep-alive
        if configuration.pingInterval > 0 {
            startPingTimer()
        }
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        connectionSubject.send(.disconnected(nil))
    }

    // MARK: - Message Handling

    func send(_ message: WebSocketMessage) async throws {
        guard isConnected, let task = webSocketTask else {
            throw NetworkError.invalidResponse
        }

        switch message {
        case .text(let text):
            try await task.send(.string(text))
        case .data(let data):
            try await task.send(.data(data))
        }
    }

    func send<T: Encodable>(_ payload: T) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        try await send(.data(data))
    }

    private func receiveMessages() {
        guard let task = webSocketTask else { return }

        Task {
            do {
                let message = try await task.receive()

                switch message {
                case .string(let text):
                    messageSubject.send(.text(text))
                case .data(let data):
                    messageSubject.send(.data(data))
                @unknown default:
                    break
                }

                // Continue receiving
                if isConnected {
                    receiveMessages()
                }
            } catch {
                handleDisconnection(error: error)
            }
        }
    }

    private func startPingTimer() {
        Task {
            while isConnected {
                try? await Task.sleep(nanoseconds: UInt64(configuration.pingInterval * 1_000_000_000))

                guard isConnected else { break }

                try? await webSocketTask?.sendPing { error in
                    if let error = error {
                        print("WebSocket ping failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Reconnection

    private func handleDisconnection(error: Error) {
        isConnected = false
        webSocketTask = nil
        connectionSubject.send(.disconnected(error))

        guard configuration.autoReconnect,
              reconnectStrategy.shouldReconnect(attempt: reconnectAttempts) else {
            return
        }

        reconnectAttempts += 1
        connectionSubject.send(.reconnecting(attempt: reconnectAttempts))

        Task {
            let delay = reconnectStrategy.delay(for: reconnectAttempts)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            // Attempt reconnection (URL would need to be stored)
            // try? await connect(to: lastURL)
        }
    }

    deinit {
        disconnect()
    }
}

// MARK: - Reconnect Strategy

private struct ReconnectStrategy {
    let maxAttempts: Int
    let baseDelay: TimeInterval = 1.0
    let maxDelay: TimeInterval = 30.0

    func shouldReconnect(attempt: Int) -> Bool {
        attempt < maxAttempts
    }

    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        return min(exponentialDelay, maxDelay)
    }
}
