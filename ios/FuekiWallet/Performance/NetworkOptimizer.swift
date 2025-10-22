import Foundation
import os.signpost

/// Optimizes network requests with batching, deduplication, and caching
@MainActor
final class NetworkOptimizer {

    // MARK: - Singleton
    static let shared = NetworkOptimizer()

    // MARK: - Signpost Logging
    private let signpostLog = OSLog(subsystem: "com.fueki.wallet", category: "Network")

    // MARK: - Configuration
    struct Configuration {
        var maxConcurrentRequests: Int = 4
        var requestTimeout: TimeInterval = 30
        var batchingWindow: TimeInterval = 0.1 // 100ms
        var maxBatchSize: Int = 10
        var enableDeduplication: Bool = true
        var enableResponseCaching: Bool = true
        var cacheDuration: TimeInterval = 300 // 5 minutes
        var retryAttempts: Int = 3
        var retryDelay: TimeInterval = 1.0
    }

    private(set) var configuration = Configuration()

    // MARK: - Request Queue
    private var pendingRequests: [String: PendingRequest] = [:]
    private var batchedRequests: [String: [BatchableRequest]] = [:]
    private let requestsLock = NSLock()

    // MARK: - Response Cache
    private var responseCache: [String: CachedResponse] = [:]
    private let cacheLock = NSLock()

    // MARK: - Concurrent Request Management
    private var activeRequests: Set<String> = []
    private let semaphore: DispatchSemaphore

    // MARK: - Statistics
    @Published private(set) var stats = NetworkStatistics()

    // MARK: - URL Session
    private let urlSession: URLSession

    // MARK: - Initialization
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.requestTimeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        urlSession = URLSession(configuration: config)

        semaphore = DispatchSemaphore(value: configuration.maxConcurrentRequests)

        setupCacheCleanup()
    }

    // MARK: - Configuration

    func configure(_ config: Configuration) {
        self.configuration = config
    }

    // MARK: - Request Execution

    /// Execute network request with optimization
    func execute<T: Decodable>(
        request: URLRequest,
        cacheKey: String? = nil,
        deduplicationKey: String? = nil
    ) async throws -> T {

        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Network Request", signpostID: signpostID)

        stats.totalRequests += 1

        // Check cache
        if configuration.enableResponseCaching,
           let key = cacheKey,
           let cached: T = getCachedResponse(key: key) {
            stats.cacheHits += 1
            os_signpost(.end, log: signpostLog, name: "Network Request", signpostID: signpostID,
                       "Source: Cache")
            return cached
        }

        // Check for duplicate in-flight request
        if configuration.enableDeduplication,
           let dedupKey = deduplicationKey ?? cacheKey {
            if let pending = getPendingRequest(key: dedupKey) as PendingRequest? {
                stats.deduplicatedRequests += 1
                os_signpost(.end, log: signpostLog, name: "Network Request", signpostID: signpostID,
                           "Source: Deduplicated")
                return try await pending.task.value as! T
            }
        }

        // Wait for available slot
        semaphore.wait()

        let requestKey = deduplicationKey ?? cacheKey ?? UUID().uuidString
        markRequestActive(key: requestKey)

        defer {
            markRequestInactive(key: requestKey)
            semaphore.signal()
        }

        // Create request task
        let task = Task<T, Error> {
            try await executeWithRetry(request: request)
        }

        // Store as pending for deduplication
        if configuration.enableDeduplication {
            storePendingRequest(key: requestKey, task: task)
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let result: T = try await task.value
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

            stats.totalRequestTimeMs += duration
            stats.averageRequestTimeMs = stats.totalRequestTimeMs / Double(stats.totalRequests)

            if duration > 1000 {
                stats.slowRequests += 1
                print("⚠️ Slow network request: \(String(format: "%.2f", duration))ms")
            }

            // Cache response
            if configuration.enableResponseCaching, let key = cacheKey {
                cacheResponse(result, key: key)
            }

            removePendingRequest(key: requestKey)

            os_signpost(.end, log: signpostLog, name: "Network Request", signpostID: signpostID,
                       "Duration: %.2f ms", duration)

            return result

        } catch {
            stats.failedRequests += 1
            removePendingRequest(key: requestKey)

            os_signpost(.end, log: signpostLog, name: "Network Request", signpostID: signpostID,
                       "Error: %{public}s", error.localizedDescription)

            throw error
        }
    }

    /// Execute request with retry logic
    private func executeWithRetry<T: Decodable>(request: URLRequest) async throws -> T {
        var lastError: Error?

        for attempt in 0..<configuration.retryAttempts {
            do {
                let (data, response) = try await urlSession.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    throw NetworkError.httpError(statusCode: httpResponse.statusCode)
                }

                let decoded = try JSONDecoder().decode(T.self, from: data)
                return decoded

            } catch {
                lastError = error

                // Don't retry on client errors (4xx)
                if let networkError = error as? NetworkError,
                   case .httpError(let statusCode) = networkError,
                   (400...499).contains(statusCode) {
                    throw error
                }

                if attempt < configuration.retryAttempts - 1 {
                    let delay = configuration.retryDelay * Double(attempt + 1)
                    print("⚠️ Request failed, retrying in \(delay)s (attempt \(attempt + 1)/\(configuration.retryAttempts))")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NetworkError.unknown
    }

    // MARK: - Request Batching

    /// Add request to batch
    func addToBatch<T: Decodable>(
        endpoint: String,
        requestBuilder: @escaping ([Any]) async throws -> URLRequest,
        responseHandler: @escaping (T) async -> Void
    ) {

        let batchRequest = BatchableRequest(
            endpoint: endpoint,
            timestamp: Date(),
            handler: { data in
                if let response = data as? T {
                    await responseHandler(response)
                }
            }
        )

        requestsLock.lock()
        if batchedRequests[endpoint] == nil {
            batchedRequests[endpoint] = []

            // Schedule batch execution
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self?.configuration.batchingWindow ?? 0.1 * 1_000_000_000))
                await self?.executeBatch(endpoint: endpoint)
            }
        }
        batchedRequests[endpoint]?.append(batchRequest)
        requestsLock.unlock()
    }

    /// Execute batched requests
    private func executeBatch(endpoint: String) async {
        requestsLock.lock()
        guard let requests = batchedRequests[endpoint], !requests.isEmpty else {
            requestsLock.unlock()
            return
        }
        batchedRequests.removeValue(forKey: endpoint)
        requestsLock.unlock()

        os_signpost(.event, log: signpostLog, name: "Batch Execution",
                   "Endpoint: %{public}s, Count: %d", endpoint, requests.count)

        stats.batchedRequests += requests.count

        print("📦 Executing batch of \(requests.count) requests for \(endpoint)")

        // Execute batch request (implementation depends on API design)
        // This is a simplified example
        for request in requests {
            // Process each request
            await request.handler(nil)
        }
    }

    // MARK: - Response Cache

    private func getCachedResponse<T: Decodable>(key: String) -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = responseCache[key],
              !cached.isExpired else {
            return nil
        }

        guard let data = cached.data else {
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func cacheResponse<T: Encodable>(_ response: T, key: String) {
        guard let data = try? JSONEncoder().encode(response) else {
            return
        }

        cacheLock.lock()
        responseCache[key] = CachedResponse(
            data: data,
            timestamp: Date(),
            ttl: configuration.cacheDuration
        )
        cacheLock.unlock()
    }

    func clearCache(key: String? = nil) {
        cacheLock.lock()
        if let key = key {
            responseCache.removeValue(forKey: key)
        } else {
            responseCache.removeAll()
        }
        cacheLock.unlock()

        print("🧹 Network cache cleared" + (key != nil ? " for \(key!)" : ""))
    }

    private func setupCacheCleanup() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                cleanupExpiredCache()
            }
        }
    }

    private func cleanupExpiredCache() {
        cacheLock.lock()
        let expiredKeys = responseCache.filter { $0.value.isExpired }.map { $0.key }
        expiredKeys.forEach { responseCache.removeValue(forKey: $0) }
        cacheLock.unlock()

        if !expiredKeys.isEmpty {
            print("🧹 Cleaned up \(expiredKeys.count) expired network cache entries")
        }
    }

    // MARK: - Request Deduplication

    private func getPendingRequest(key: String) -> PendingRequest? {
        requestsLock.lock()
        defer { requestsLock.unlock() }
        return pendingRequests[key]
    }

    private func storePendingRequest(key: String, task: Task<Any, Error>) {
        requestsLock.lock()
        pendingRequests[key] = PendingRequest(task: task, timestamp: Date())
        requestsLock.unlock()
    }

    private func removePendingRequest(key: String) {
        requestsLock.lock()
        pendingRequests.removeValue(forKey: key)
        requestsLock.unlock()
    }

    // MARK: - Active Request Tracking

    private func markRequestActive(key: String) {
        requestsLock.lock()
        activeRequests.insert(key)
        requestsLock.unlock()
    }

    private func markRequestInactive(key: String) {
        requestsLock.lock()
        activeRequests.remove(key)
        requestsLock.unlock()
    }

    // MARK: - Statistics

    func getStatistics() -> NetworkStatistics {
        return stats
    }

    func resetStatistics() {
        stats = NetworkStatistics()
    }

    // MARK: - Monitoring

    func getActiveRequestCount() -> Int {
        requestsLock.lock()
        defer { requestsLock.unlock() }
        return activeRequests.count
    }
}

// MARK: - Supporting Types

private struct PendingRequest {
    let task: Task<Any, Error>
    let timestamp: Date
}

private struct BatchableRequest {
    let endpoint: String
    let timestamp: Date
    let handler: (Any?) async -> Void
}

private struct CachedResponse {
    let data: Data?
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

struct NetworkStatistics {
    var totalRequests: Int = 0
    var cacheHits: Int = 0
    var deduplicatedRequests: Int = 0
    var batchedRequests: Int = 0
    var failedRequests: Int = 0
    var slowRequests: Int = 0
    var totalRequestTimeMs: Double = 0
    var averageRequestTimeMs: Double = 0

    var cacheHitRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(cacheHits) / Double(totalRequests)
    }

    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(totalRequests - failedRequests) / Double(totalRequests)
    }
}

enum NetworkError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .decodingError:
            return "Failed to decode response"
        case .unknown:
            return "Unknown network error"
        }
    }
}
