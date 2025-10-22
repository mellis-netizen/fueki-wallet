//
//  RPCClient.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation
import Combine

/// Production-grade RPC client with connection pooling, retry logic, and fallback support
public actor RPCClient {
    private let configuration: NetworkConfiguration
    private let endpointConfig: EndpointConfiguration
    private let session: URLSession
    private let logger: NetworkLogger

    // Connection pool management
    private var requestQueue: [CheckedContinuation<Void, Never>] = []
    private var activeRequests = 0

    // Rate limiting
    private var requestTimestamps: [Date] = []

    // Request ID management
    private var nextRequestId = 1

    // Fallback tracking
    private var endpointFailures: [URL: Int] = [:]
    private var currentEndpointIndex = 0

    public init(
        endpointConfig: EndpointConfiguration,
        configuration: NetworkConfiguration = .default
    ) {
        self.endpointConfig = endpointConfig
        self.configuration = configuration
        self.logger = NetworkLogger(level: configuration.logLevel)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = configuration.requestTimeout
        sessionConfig.timeoutIntervalForResource = configuration.resourceTimeout
        sessionConfig.httpMaximumConnectionsPerHost = configuration.connectionPoolSize
        sessionConfig.httpShouldSetCookies = false
        sessionConfig.requestCachePolicy = configuration.cachePolicy
        sessionConfig.httpAdditionalHeaders = configuration.customHeaders

        self.session = URLSession(configuration: sessionConfig)
    }

    // MARK: - Public API

    /// Execute single RPC request with retry and fallback
    public func request<Params: Encodable, Result: Decodable>(
        method: String,
        params: Params
    ) async throws -> Result {
        try await withConnectionPooling {
            try await executeWithRetry { url in
                try await self.performRequest(url: url, method: method, params: params)
            }
        }
    }

    /// Execute batch RPC requests
    public func batchRequest<Params: Encodable, Result: Decodable>(
        requests: [(method: String, params: Params)]
    ) async throws -> [Result] {
        try await withConnectionPooling {
            try await executeWithRetry { url in
                try await self.performBatchRequest(url: url, requests: requests)
            }
        }
    }

    /// Execute raw HTTP request
    public func rawRequest(
        method: String,
        path: String,
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> Data {
        try await withConnectionPooling {
            try await executeWithRetry { url in
                let requestURL = url.appendingPathComponent(path)
                var request = URLRequest(url: requestURL)
                request.httpMethod = method
                request.httpBody = body

                // Add headers
                headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }

                // Add API key if available
                if let apiKey = self.endpointConfig.apiKey {
                    request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
                }

                let (data, response) = try await self.session.data(for: request)
                try self.validateResponse(response)
                return data
            }
        }
    }

    // MARK: - Private Methods

    private func performRequest<Params: Encodable, Result: Decodable>(
        url: URL,
        method: String,
        params: Params
    ) async throws -> Result {
        let requestId = getNextRequestId()
        let rpcRequest = RPCRequest(id: requestId, method: method, params: params)

        logger.log(.debug, "RPC Request [\(requestId)]: \(method)")

        var request = try createURLRequest(url: url, body: rpcRequest)

        let startTime = Date()
        let (data, response) = try await session.data(for: request)
        let duration = Date().timeIntervalSince(startTime)

        logger.log(.debug, "RPC Response [\(requestId)]: \(duration)s")

        try validateResponse(response)

        let rpcResponse: RPCResponse<Result> = try decodeResponse(data)
        return try rpcResponse.unwrappedResult
    }

    private func performBatchRequest<Params: Encodable, Result: Decodable>(
        url: URL,
        requests: [(method: String, params: Params)]
    ) async throws -> [Result] {
        let encodableRequests = requests.enumerated().map { index, item in
            let requestId = getNextRequestId()
            return AnyEncodable(RPCRequest(id: requestId, method: item.method, params: item.params))
        }

        let batchRequest = RPCBatchRequest(requests: encodableRequests)

        logger.log(.debug, "Batch RPC Request: \(requests.count) requests")

        var request = try createURLRequest(url: url, body: batchRequest)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let responses: [RPCResponse<Result>] = try decodeResponse(data)
        return try responses.map { try $0.unwrappedResult }
    }

    private func createURLRequest<T: Encodable>(url: URL, body: T) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add API key if available
        if let apiKey = endpointConfig.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Add custom headers
        configuration.customHeaders.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw NetworkError.encodingError(error.localizedDescription)
        }

        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        logger.log(.debug, "HTTP Status: \(httpResponse.statusCode)")

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw NetworkError.rateLimitExceeded(retryAfter: retryAfter)
        case 500...599:
            throw NetworkError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            )
        }
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            logger.log(.error, "Decoding error: \(error)")

            // Try to decode as error response
            if let errorResponse = try? decoder.decode(RPCResponse<String>.self, from: data),
               let rpcError = errorResponse.error {
                throw NetworkError.rpcError(
                    code: rpcError.code,
                    message: rpcError.message,
                    data: rpcError.data
                )
            }

            throw NetworkError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - Retry Logic

    private func executeWithRetry<T>(
        _ operation: (URL) async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var attemptCount = 0

        // Try primary endpoint first
        for url in endpointConfig.allURLs {
            attemptCount = 0

            while attemptCount < configuration.maxRetries {
                do {
                    let result = try await operation(url)

                    // Reset failure count on success
                    endpointFailures[url] = 0

                    return result
                } catch {
                    lastError = error
                    attemptCount += 1

                    logger.log(.warning, "Attempt \(attemptCount) failed for \(url): \(error)")

                    // Check if error is retryable
                    guard let networkError = error as? NetworkError,
                          networkError.isRetryable,
                          attemptCount < configuration.maxRetries else {
                        break
                    }

                    // Calculate delay with exponential backoff
                    let delay = calculateRetryDelay(
                        attempt: attemptCount,
                        baseDelay: networkError.retryDelay
                    )

                    logger.log(.info, "Retrying after \(delay)s...")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }

            // Track endpoint failures
            endpointFailures[url, default: 0] += 1

            // Try next endpoint
            logger.log(.warning, "Endpoint \(url) failed, trying fallback...")
        }

        // All endpoints failed
        let failureMap = endpointConfig.allURLs.reduce(into: [String: Error]()) { dict, url in
            dict[url.absoluteString] = lastError ?? NetworkError.unknown(NSError(domain: "", code: -1))
        }

        throw NetworkError.allEndpointsFailed(failureMap)
    }

    private func calculateRetryDelay(attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
        guard configuration.exponentialBackoff else {
            return baseDelay
        }

        let exponentialDelay = baseDelay * pow(configuration.backoffMultiplier, Double(attempt - 1))

        // Add jitter (±20%)
        let jitter = Double.random(in: 0.8...1.2)
        return exponentialDelay * jitter
    }

    // MARK: - Connection Pooling

    private func withConnectionPooling<T>(_ operation: () async throws -> T) async throws -> T {
        // Check rate limiting
        try await enforceRateLimit()

        // Wait for available connection
        await acquireConnection()

        defer {
            Task { await releaseConnection() }
        }

        return try await operation()
    }

    private func acquireConnection() async {
        if activeRequests >= configuration.maxConcurrentRequests {
            await withCheckedContinuation { continuation in
                requestQueue.append(continuation)
            }
        }
        activeRequests += 1
    }

    private func releaseConnection() {
        activeRequests -= 1

        if let continuation = requestQueue.first {
            requestQueue.removeFirst()
            continuation.resume()
        }
    }

    // MARK: - Rate Limiting

    private func enforceRateLimit() async throws {
        guard let limit = configuration.rateLimitPerSecond else { return }

        let now = Date()
        let oneSecondAgo = now.addingTimeInterval(-1.0)

        // Remove old timestamps
        requestTimestamps.removeAll { $0 < oneSecondAgo }

        // Check if we've exceeded the limit
        if requestTimestamps.count >= limit {
            let oldestTimestamp = requestTimestamps.first ?? now
            let delay = 1.0 - now.timeIntervalSince(oldestTimestamp)

            if delay > 0 {
                logger.log(.warning, "Rate limit reached, waiting \(delay)s")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        requestTimestamps.append(now)
    }

    // MARK: - Utilities

    private func getNextRequestId() -> Int {
        let id = nextRequestId
        nextRequestId += 1
        return id
    }
}

// MARK: - Network Logger

private actor NetworkLogger {
    private let level: NetworkConfiguration.LogLevel

    init(level: NetworkConfiguration.LogLevel) {
        self.level = level
    }

    func log(_ messageLevel: NetworkConfiguration.LogLevel, _ message: String) {
        guard messageLevel.rawValue <= level.rawValue else { return }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let prefix: String

        switch messageLevel {
        case .none:
            return
        case .error:
            prefix = "❌ ERROR"
        case .warning:
            prefix = "⚠️ WARNING"
        case .info:
            prefix = "ℹ️ INFO"
        case .debug:
            prefix = "🔍 DEBUG"
        }

        print("[\(timestamp)] \(prefix): \(message)")
    }
}
