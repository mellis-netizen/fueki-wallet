import Foundation

/// Retry strategy with exponential backoff
struct RetryStrategy {
    let maxRetries: Int
    let baseDelay: TimeInterval
    let maxDelay: TimeInterval
    let jitterFactor: Double

    init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        jitterFactor: Double = 0.1
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFactor = jitterFactor
    }

    /// Calculate delay for retry attempt with exponential backoff and jitter
    func delay(for attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = cappedDelay * jitterFactor * Double.random(in: -1...1)
        return max(0, cappedDelay + jitter)
    }

    /// Determine if should retry based on attempt count
    func shouldRetry(attempt: Int) -> Bool {
        attempt < maxRetries
    }
}

/// Request queue for managing concurrent requests
final class RequestQueue {
    private let maxConcurrent: Int
    private var activeCount = 0
    private var pendingRequests: [(priority: RequestPriority, work: () async throws -> Void)] = []
    private let lock = NSLock()

    init(maxConcurrent: Int = 6) {
        self.maxConcurrent = maxConcurrent
    }

    func enqueue<T>(
        priority: RequestPriority = .normal,
        work: @escaping () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            defer { lock.unlock() }

            if activeCount < maxConcurrent {
                activeCount += 1
                Task {
                    defer {
                        lock.lock()
                        activeCount -= 1
                        processNext()
                        lock.unlock()
                    }

                    do {
                        let result = try await work()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } else {
                pendingRequests.append((priority, {
                    do {
                        let result = try await work()
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }))
                pendingRequests.sort { $0.priority > $1.priority }
            }
        }
    }

    private func processNext() {
        guard activeCount < maxConcurrent, !pendingRequests.isEmpty else { return }

        let next = pendingRequests.removeFirst()
        activeCount += 1

        Task {
            defer {
                lock.lock()
                activeCount -= 1
                processNext()
                lock.unlock()
            }
            try await next.work()
        }
    }
}
