import Foundation

/// Generic RPC client with retry logic and error handling
public class RPCClient {

    // MARK: - Types

    public struct Configuration {
        public let endpoints: [URL]
        public let timeout: TimeInterval
        public let maxRetries: Int
        public let retryDelay: TimeInterval
        public let rateLimitDelay: TimeInterval

        public init(endpoints: [URL],
                   timeout: TimeInterval = 30,
                   maxRetries: Int = 3,
                   retryDelay: TimeInterval = 1.0,
                   rateLimitDelay: TimeInterval = 2.0) {
            self.endpoints = endpoints
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.retryDelay = retryDelay
            self.rateLimitDelay = rateLimitDelay
        }
    }

    public struct RPCRequest: Encodable {
        let jsonrpc: String
        let id: Int
        let method: String
        let params: [AnyCodable]

        public init(method: String, params: [AnyCodable], id: Int = 1) {
            self.jsonrpc = "2.0"
            self.id = id
            self.method = method
            self.params = params
        }
    }

    public struct RPCResponse<T: Decodable>: Decodable {
        let jsonrpc: String
        let id: Int
        let result: T?
        let error: RPCError?

        public var value: T {
            get throws {
                if let error = error {
                    throw BlockchainError.networkError("RPC Error \(error.code): \(error.message)")
                }
                guard let result = result else {
                    throw BlockchainError.networkError("No result in RPC response")
                }
                return result
            }
        }
    }

    public struct RPCError: Decodable {
        let code: Int
        let message: String
        let data: AnyCodable?
    }

    // MARK: - Properties

    private let configuration: Configuration
    private var currentEndpointIndex: Int = 0
    private var requestIdCounter: Int = 1
    private let session: URLSession
    private let queue = DispatchQueue(label: "io.fueki.rpc.client")

    // Rate limiting
    private var lastRequestTime: Date?
    private let rateLimitSemaphore = DispatchSemaphore(value: 1)

    // MARK: - Initialization

    public init(configuration: Configuration) {
        self.configuration = configuration

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.timeout
        sessionConfig.timeoutIntervalForResource = configuration.timeout * 2
        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Public Methods

    /// Make RPC call with automatic retry and failover
    public func call<T: Decodable>(
        method: String,
        params: [AnyCodable] = []
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<configuration.maxRetries {
            do {
                let result: T = try await performRequest(method: method, params: params)
                return result
            } catch let error as BlockchainError {
                lastError = error

                switch error {
                case .rateLimitExceeded:
                    // Wait before retry
                    try await Task.sleep(nanoseconds: UInt64(configuration.rateLimitDelay * 1_000_000_000))
                    continue

                case .networkError, .timeout:
                    // Try next endpoint
                    rotateEndpoint()

                    if attempt < configuration.maxRetries - 1 {
                        try await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
                        continue
                    }

                default:
                    throw error
                }
            } catch {
                lastError = error

                // Retry on network errors
                if attempt < configuration.maxRetries - 1 {
                    rotateEndpoint()
                    try await Task.sleep(nanoseconds: UInt64(configuration.retryDelay * 1_000_000_000))
                    continue
                }
            }
        }

        throw lastError ?? BlockchainError.networkError("All retry attempts failed")
    }

    /// Make batch RPC call
    public func batchCall<T: Decodable>(
        requests: [(method: String, params: [AnyCodable])]
    ) async throws -> [T] {
        let batchRequests = requests.enumerated().map { index, request in
            RPCRequest(method: request.method, params: request.params, id: index + 1)
        }

        let endpoint = getCurrentEndpoint()
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try JSONEncoder().encode(batchRequests)
        urlRequest.httpBody = requestData

        // Apply rate limiting
        try await applyRateLimit()

        let (data, response) = try await session.data(for: urlRequest)

        try validateResponse(response)

        let decoder = JSONDecoder()
        let responses = try decoder.decode([RPCResponse<T>].self, from: data)

        return try responses.map { try $0.value }
    }

    // MARK: - Private Methods

    private func performRequest<T: Decodable>(
        method: String,
        params: [AnyCodable]
    ) async throws -> T {
        let requestId = getNextRequestId()
        let rpcRequest = RPCRequest(method: method, params: params, id: requestId)

        let endpoint = getCurrentEndpoint()
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestData = try JSONEncoder().encode(rpcRequest)
        urlRequest.httpBody = requestData

        // Apply rate limiting
        try await applyRateLimit()

        let (data, response) = try await session.data(for: urlRequest)

        try validateResponse(response)

        let decoder = JSONDecoder()
        let rpcResponse = try decoder.decode(RPCResponse<T>.self, from: data)

        return try rpcResponse.value
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BlockchainError.networkError("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 429:
            throw BlockchainError.rateLimitExceeded
        case 408, 504:
            throw BlockchainError.timeout
        default:
            throw BlockchainError.networkError("HTTP \(httpResponse.statusCode)")
        }
    }

    private func getCurrentEndpoint() -> URL {
        return queue.sync {
            configuration.endpoints[currentEndpointIndex]
        }
    }

    private func rotateEndpoint() {
        queue.sync {
            currentEndpointIndex = (currentEndpointIndex + 1) % configuration.endpoints.count
        }
    }

    private func getNextRequestId() -> Int {
        return queue.sync {
            let id = requestIdCounter
            requestIdCounter += 1
            return id
        }
    }

    private func applyRateLimit() async throws {
        rateLimitSemaphore.wait()
        defer { rateLimitSemaphore.signal() }

        if let lastRequest = lastRequestTime {
            let minInterval: TimeInterval = 0.1 // 10 requests per second max
            let elapsed = Date().timeIntervalSince(lastRequest)

            if elapsed < minInterval {
                let delay = minInterval - elapsed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        lastRequestTime = Date()
    }
}

// MARK: - AnyCodable Helper

/// Type-erased codable value for flexible RPC parameters
public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let int = try? container.decode(Int.self) {
            value = int
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let int as Int:
            try container.encode(int)
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let double as Double:
            try container.encode(double)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(
                codingPath: container.codingPath,
                debugDescription: "Unsupported type"
            )
            throw EncodingError.invalidValue(value, context)
        }
    }
}
