//
//  RetryPolicy.swift
//  FuekiWallet
//
//  Exponential backoff retry logic for network requests
//

import Foundation

/// Retry policy configuration
public struct RetryPolicy {

    // MARK: - Properties

    /// Maximum number of retry attempts
    public let maxRetries: Int

    /// Base delay for exponential backoff (in seconds)
    public let baseDelay: TimeInterval

    /// Maximum delay between retries
    public let maxDelay: TimeInterval

    /// Jitter factor (0.0 to 1.0) to randomize delays
    public let jitterFactor: Double

    /// Multiplier for exponential backoff
    public let multiplier: Double

    /// HTTP status codes that should trigger retry
    public let retryableStatusCodes: Set<Int>

    /// Whether to retry on timeout errors
    public let retryOnTimeout: Bool

    /// Whether to retry on connection errors
    public let retryOnConnectionError: Bool

    // MARK: - Predefined Policies

    public static let `default` = RetryPolicy(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        jitterFactor: 0.1,
        multiplier: 2.0,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryOnTimeout: true,
        retryOnConnectionError: true
    )

    public static let aggressive = RetryPolicy(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        jitterFactor: 0.2,
        multiplier: 2.5,
        retryableStatusCodes: [408, 429, 500, 502, 503, 504],
        retryOnTimeout: true,
        retryOnConnectionError: true
    )

    public static let conservative = RetryPolicy(
        maxRetries: 2,
        baseDelay: 2.0,
        maxDelay: 15.0,
        jitterFactor: 0.05,
        multiplier: 1.5,
        retryableStatusCodes: [500, 502, 503, 504],
        retryOnTimeout: false,
        retryOnConnectionError: false
    )

    public static let none = RetryPolicy(
        maxRetries: 0,
        baseDelay: 0.0,
        maxDelay: 0.0,
        jitterFactor: 0.0,
        multiplier: 1.0,
        retryableStatusCodes: [],
        retryOnTimeout: false,
        retryOnConnectionError: false
    )

    // MARK: - Initialization

    public init(
        maxRetries: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        jitterFactor: Double,
        multiplier: Double,
        retryableStatusCodes: Set<Int>,
        retryOnTimeout: Bool,
        retryOnConnectionError: Bool
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFactor = jitterFactor
        self.multiplier = multiplier
        self.retryableStatusCodes = retryableStatusCodes
        self.retryOnTimeout = retryOnTimeout
        self.retryOnConnectionError = retryOnConnectionError
    }

    // MARK: - Public Methods

    /// Calculate delay for a given retry attempt
    public func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }

        // Calculate exponential backoff
        let exponentialDelay = baseDelay * pow(multiplier, Double(attempt - 1))

        // Apply maximum delay cap
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)

        return max(0, cappedDelay + jitter)
    }

    /// Determine if an error should trigger a retry
    public func shouldRetry(error: NetworkError, attempt: Int) -> Bool {
        guard attempt < maxRetries else { return false }

        switch error {
        case .timeout:
            return retryOnTimeout

        case .noConnection, .connectionLost, .cannotConnectToHost:
            return retryOnConnectionError

        case .httpError(let statusCode, _), .serverError(let statusCode):
            return retryableStatusCodes.contains(statusCode)

        case .tooManyRequests, .rateLimitExceeded:
            return true

        default:
            return false
        }
    }

    /// Get retry delay from error (e.g., Retry-After header)
    public func retryDelay(from error: NetworkError, attempt: Int) -> TimeInterval {
        switch error {
        case .tooManyRequests(let retryAfter), .rateLimitExceeded(let retryAfter):
            return retryAfter ?? delay(for: attempt)
        default:
            return delay(for: attempt)
        }
    }
}

// MARK: - Retry Executor
public actor RetryExecutor {

    private let policy: RetryPolicy

    public init(policy: RetryPolicy = .default) {
        self.policy = policy
    }

    /// Execute operation with retry logic
    public func execute<T>(
        operation: @Sendable () async throws -> T,
        shouldRetry: ((Error) -> Bool)? = nil
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0...policy.maxRetries {
            do {
                return try await operation()
            } catch let error as NetworkError {
                lastError = error

                // Check if we should retry
                let customCheck = shouldRetry?(error) ?? true
                guard customCheck && policy.shouldRetry(error: error, attempt: attempt) else {
                    throw error
                }

                // Calculate delay
                let delay = policy.retryDelay(from: error, attempt: attempt + 1)

                // Wait before retrying
                if delay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }

                // Continue to next attempt
                continue
            } catch {
                // Non-NetworkError, don't retry
                throw error
            }
        }

        // All retries exhausted
        throw lastError ?? NetworkError.unknown(NSError(domain: "RetryExecutor", code: -1))
    }
}

// MARK: - Retry Metrics
public struct RetryMetrics {
    public let totalAttempts: Int
    public let totalDelay: TimeInterval
    public let errors: [NetworkError]
    public let success: Bool

    public init(totalAttempts: Int, totalDelay: TimeInterval, errors: [NetworkError], success: Bool) {
        self.totalAttempts = totalAttempts
        self.totalDelay = totalDelay
        self.errors = errors
        self.success = success
    }
}
