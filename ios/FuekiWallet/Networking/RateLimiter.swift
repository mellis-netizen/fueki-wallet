//
//  RateLimiter.swift
//  FuekiWallet
//
//  API rate limiting implementation
//

import Foundation

/// Rate limiter for API requests
public actor RateLimiter {

    // MARK: - Types

    public enum Algorithm {
        case tokenBucket
        case slidingWindow
        case fixedWindow
    }

    private struct Limit {
        let maxRequests: Int
        let windowDuration: TimeInterval
        let algorithm: Algorithm
    }

    private struct RequestLog {
        var timestamps: [Date]
        var tokens: Int
        var lastRefill: Date

        init(maxTokens: Int) {
            self.timestamps = []
            self.tokens = maxTokens
            self.lastRefill = Date()
        }
    }

    // MARK: - Properties

    private var requestLogs: [String: RequestLog] = [:]
    private let globalLimit: Limit
    private let endpointLimits: [String: Limit]

    // MARK: - Initialization

    public init(
        globalMaxRequests: Int = 100,
        globalWindowDuration: TimeInterval = 60.0,
        algorithm: Algorithm = .tokenBucket,
        endpointLimits: [String: (maxRequests: Int, windowDuration: TimeInterval)] = [:]
    ) {
        self.globalLimit = Limit(
            maxRequests: globalMaxRequests,
            windowDuration: globalWindowDuration,
            algorithm: algorithm
        )

        self.endpointLimits = endpointLimits.mapValues { limit in
            Limit(
                maxRequests: limit.maxRequests,
                windowDuration: limit.windowDuration,
                algorithm: algorithm
            )
        }
    }

    // MARK: - Public Methods

    /// Check if request is allowed and update rate limit
    public func checkLimit(for endpoint: String) async throws {
        // Check global limit
        try await checkAndUpdate(key: "global", limit: globalLimit)

        // Check endpoint-specific limit if exists
        if let endpointLimit = endpointLimits[endpoint] {
            try await checkAndUpdate(key: endpoint, limit: endpointLimit)
        }
    }

    /// Get current rate limit status
    public func status(for endpoint: String) -> (remaining: Int, resetAt: Date) {
        let limit = endpointLimits[endpoint] ?? globalLimit
        let key = endpointLimits[endpoint] != nil ? endpoint : "global"

        guard let log = requestLogs[key] else {
            return (limit.maxRequests, Date())
        }

        switch limit.algorithm {
        case .tokenBucket:
            let remaining = log.tokens
            let resetAt = log.lastRefill.addingTimeInterval(limit.windowDuration)
            return (remaining, resetAt)

        case .slidingWindow, .fixedWindow:
            let validTimestamps = log.timestamps.filter { timestamp in
                Date().timeIntervalSince(timestamp) < limit.windowDuration
            }
            let remaining = limit.maxRequests - validTimestamps.count
            let resetAt = (validTimestamps.first ?? Date()).addingTimeInterval(limit.windowDuration)
            return (max(0, remaining), resetAt)
        }
    }

    /// Reset rate limits
    public func reset() {
        requestLogs.removeAll()
    }

    /// Reset specific endpoint rate limit
    public func reset(for endpoint: String) {
        requestLogs.removeValue(forKey: endpoint)
        requestLogs.removeValue(forKey: "global")
    }

    // MARK: - Private Methods

    private func checkAndUpdate(key: String, limit: Limit) async throws {
        // Initialize log if needed
        if requestLogs[key] == nil {
            requestLogs[key] = RequestLog(maxTokens: limit.maxRequests)
        }

        guard var log = requestLogs[key] else { return }

        switch limit.algorithm {
        case .tokenBucket:
            try await checkTokenBucket(key: key, limit: limit, log: &log)

        case .slidingWindow:
            try await checkSlidingWindow(key: key, limit: limit, log: &log)

        case .fixedWindow:
            try await checkFixedWindow(key: key, limit: limit, log: &log)
        }

        requestLogs[key] = log
    }

    private func checkTokenBucket(key: String, limit: Limit, log: inout RequestLog) async throws {
        // Refill tokens based on time elapsed
        let now = Date()
        let elapsed = now.timeIntervalSince(log.lastRefill)
        let tokensToAdd = Int(elapsed / limit.windowDuration * Double(limit.maxRequests))

        if tokensToAdd > 0 {
            log.tokens = min(log.tokens + tokensToAdd, limit.maxRequests)
            log.lastRefill = now
        }

        // Check if we have tokens available
        guard log.tokens > 0 else {
            let retryAfter = limit.windowDuration - elapsed
            throw NetworkError.rateLimitExceeded(retryAfter: retryAfter)
        }

        // Consume one token
        log.tokens -= 1
    }

    private func checkSlidingWindow(key: String, limit: Limit, log: inout RequestLog) async throws {
        let now = Date()

        // Remove timestamps outside the window
        log.timestamps = log.timestamps.filter { timestamp in
            now.timeIntervalSince(timestamp) < limit.windowDuration
        }

        // Check if limit is exceeded
        guard log.timestamps.count < limit.maxRequests else {
            let oldestTimestamp = log.timestamps.first ?? now
            let retryAfter = limit.windowDuration - now.timeIntervalSince(oldestTimestamp)
            throw NetworkError.rateLimitExceeded(retryAfter: max(0, retryAfter))
        }

        // Add current timestamp
        log.timestamps.append(now)
    }

    private func checkFixedWindow(key: String, limit: Limit, log: inout RequestLog) async throws {
        let now = Date()
        let windowStart = Date(timeIntervalSince1970:
            floor(now.timeIntervalSince1970 / limit.windowDuration) * limit.windowDuration
        )

        // Reset counter if we're in a new window
        if log.lastRefill < windowStart {
            log.timestamps.removeAll()
            log.lastRefill = windowStart
        }

        // Check if limit is exceeded
        guard log.timestamps.count < limit.maxRequests else {
            let nextWindow = windowStart.addingTimeInterval(limit.windowDuration)
            let retryAfter = nextWindow.timeIntervalSince(now)
            throw NetworkError.rateLimitExceeded(retryAfter: retryAfter)
        }

        // Add current request
        log.timestamps.append(now)
    }
}

// MARK: - Predefined Rate Limiters
public extension RateLimiter {
    /// Conservative rate limiter (60 requests per minute)
    static func conservative() -> RateLimiter {
        RateLimiter(
            globalMaxRequests: 60,
            globalWindowDuration: 60.0,
            algorithm: .tokenBucket
        )
    }

    /// Standard rate limiter (100 requests per minute)
    static func standard() -> RateLimiter {
        RateLimiter(
            globalMaxRequests: 100,
            globalWindowDuration: 60.0,
            algorithm: .slidingWindow
        )
    }

    /// Aggressive rate limiter (200 requests per minute)
    static func aggressive() -> RateLimiter {
        RateLimiter(
            globalMaxRequests: 200,
            globalWindowDuration: 60.0,
            algorithm: .tokenBucket
        )
    }

    /// Fueki Wallet specific rate limiter with endpoint limits
    static func fuekiWallet() -> RateLimiter {
        RateLimiter(
            globalMaxRequests: 100,
            globalWindowDuration: 60.0,
            algorithm: .slidingWindow,
            endpointLimits: [
                "/wallets": (maxRequests: 20, windowDuration: 60.0),
                "/transactions": (maxRequests: 50, windowDuration: 60.0),
                "/tokens": (maxRequests: 30, windowDuration: 60.0),
                "/nfts": (maxRequests: 30, windowDuration: 60.0)
            ]
        )
    }
}
