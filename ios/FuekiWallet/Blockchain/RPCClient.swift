//
//  RPCClient.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - JSON-RPC Client with Retry Logic
//

import Foundation
import Combine

// MARK: - RPC Request
struct RPCRequest: Codable {
    let jsonrpc: String
    let id: Int
    let method: String
    let params: [Any]?

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }

    init(method: String, params: [Any]? = nil, id: Int = 1) {
        self.jsonrpc = "2.0"
        self.id = id
        self.method = method
        self.params = params
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)

        if let params = params {
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            try container.encode(AnyCodable(jsonObject), forKey: .params)
        }
    }
}

// MARK: - RPC Response
struct RPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int
    let result: T?
    let error: RPCError?

    struct RPCError: Decodable {
        let code: Int
        let message: String
        let data: String?
    }
}

// MARK: - AnyCodable Helper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}

// MARK: - RPC Client
class RPCClient {
    private let endpoints: [String]
    private let session: URLSession
    private let timeout: TimeInterval
    private let maxRetries: Int
    private let retryDelay: TimeInterval
    private var currentEndpointIndex = 0
    private let queue = DispatchQueue(label: "io.fueki.rpc.client")

    private var requestIdCounter = 0
    private let requestIdLock = NSLock()

    // WebSocket support
    private var webSocketTask: URLSessionWebSocketTask?
    private let wsSubject = PassthroughSubject<Data, Error>()

    init(
        endpoints: [String],
        timeout: TimeInterval = NetworkConstants.defaultTimeout,
        maxRetries: Int = NetworkConstants.maxRetryAttempts,
        retryDelay: TimeInterval = NetworkConstants.retryDelay
    ) {
        self.endpoints = endpoints
        self.timeout = timeout
        self.maxRetries = maxRetries
        self.retryDelay = retryDelay

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
    }

    deinit {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: - RPC Call
    func call<T: Decodable>(
        method: String,
        params: [Any]? = nil
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...maxRetries {
            do {
                let requestId = nextRequestId()
                let request = RPCRequest(method: method, params: params, id: requestId)
                let result: T = try await executeRequest(request)
                return result
            } catch {
                lastError = error

                // Don't retry on certain errors
                if let blockchainError = error as? BlockchainError {
                    switch blockchainError {
                    case .invalidAddress, .invalidTransaction:
                        throw error
                    default:
                        break
                    }
                }

                // Try next endpoint
                if attempt < maxRetries {
                    rotateEndpoint()
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? BlockchainError.timeout
    }

    // MARK: - Batch RPC Call
    func batchCall<T: Decodable>(
        requests: [(method: String, params: [Any]?)]
    ) async throws -> [T] {
        let rpcRequests = requests.enumerated().map { index, request in
            RPCRequest(method: request.method, params: request.params, id: index + 1)
        }

        let endpoint = getCurrentEndpoint()
        guard let url = URL(string: endpoint) else {
            throw BlockchainError.networkError(URLError(.badURL))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(rpcRequests)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlockchainError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BlockchainError.networkError(URLError(.badServerResponse))
        }

        let rpcResponses = try JSONDecoder().decode([RPCResponse<T>].self, from: data)

        return try rpcResponses.map { response in
            if let error = response.error {
                throw BlockchainError.rpcError(error.code, error.message)
            }
            guard let result = response.result else {
                throw BlockchainError.networkError(URLError(.cannotParseResponse))
            }
            return result
        }
    }

    // MARK: - WebSocket Support
    func connectWebSocket(endpoint: String) throws {
        guard let url = URL(string: endpoint) else {
            throw BlockchainError.networkError(URLError(.badURL))
        }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveWebSocketMessage()
    }

    func sendWebSocketMessage(_ message: RPCRequest) throws {
        let data = try JSONEncoder().encode(message)
        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { [weak self] error in
            if let error = error {
                self?.wsSubject.send(completion: .failure(error))
            }
        }
    }

    func webSocketPublisher() -> AnyPublisher<Data, Error> {
        wsSubject.eraseToAnyPublisher()
    }

    func disconnectWebSocket() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Private Methods
    private func executeRequest<T: Decodable>(_ request: RPCRequest) async throws -> T {
        let endpoint = getCurrentEndpoint()
        guard let url = URL(string: endpoint) else {
            throw BlockchainError.networkError(URLError(.badURL))
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlockchainError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw BlockchainError.networkError(URLError(.badServerResponse))
        }

        let rpcResponse = try JSONDecoder().decode(RPCResponse<T>.self, from: data)

        if let error = rpcResponse.error {
            throw BlockchainError.rpcError(error.code, error.message)
        }

        guard let result = rpcResponse.result else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        return result
    }

    private func receiveWebSocketMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.wsSubject.send(data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        self.wsSubject.send(data)
                    }
                @unknown default:
                    break
                }
                self.receiveWebSocketMessage()

            case .failure(let error):
                self.wsSubject.send(completion: .failure(error))
            }
        }
    }

    private func getCurrentEndpoint() -> String {
        queue.sync {
            endpoints[currentEndpointIndex]
        }
    }

    private func rotateEndpoint() {
        queue.sync {
            currentEndpointIndex = (currentEndpointIndex + 1) % endpoints.count
        }
    }

    private func nextRequestId() -> Int {
        requestIdLock.lock()
        defer { requestIdLock.unlock() }
        requestIdCounter += 1
        return requestIdCounter
    }
}

// MARK: - Endpoint Health Checker
class EndpointHealthChecker {
    private let rpcClient: RPCClient
    private var healthStatus: [String: Bool] = [:]
    private let queue = DispatchQueue(label: "io.fueki.rpc.health")

    init(endpoints: [String]) {
        self.rpcClient = RPCClient(endpoints: endpoints, timeout: 5)
        endpoints.forEach { healthStatus[$0] = false }
    }

    func checkHealth(endpoint: String) async -> Bool {
        do {
            let _: String = try await rpcClient.call(method: "eth_blockNumber")
            updateHealth(endpoint: endpoint, isHealthy: true)
            return true
        } catch {
            updateHealth(endpoint: endpoint, isHealthy: false)
            return false
        }
    }

    func getHealthyEndpoints() -> [String] {
        queue.sync {
            healthStatus.filter { $0.value }.map { $0.key }
        }
    }

    private func updateHealth(endpoint: String, isHealthy: Bool) {
        queue.sync {
            healthStatus[endpoint] = isHealthy
        }
    }
}
