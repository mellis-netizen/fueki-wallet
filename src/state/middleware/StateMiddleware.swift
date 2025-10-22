//
//  StateMiddleware.swift
//  Fueki Wallet
//
//  Middleware system for state management
//

import Foundation

protocol MiddlewareHandler {
    func preExecution(_ action: StateAction) async throws
    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async
}

@MainActor
class StateMiddleware {
    // MARK: - Singleton
    static let shared = StateMiddleware()

    // MARK: - Properties
    private var handlers: [MiddlewareHandler] = []

    // MARK: - Initialization
    private init() {}

    // MARK: - Registration

    func register(_ handler: MiddlewareHandler) {
        handlers.append(handler)
    }

    func unregister<T: MiddlewareHandler>(_ handlerType: T.Type) {
        handlers.removeAll { handler in
            type(of: handler) == handlerType
        }
    }

    // MARK: - Execution

    func preExecution(_ action: StateAction) async throws {
        for handler in handlers {
            try await handler.preExecution(action)
        }
    }

    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async {
        for handler in handlers {
            await handler.postExecution(action, duration: duration, success: success)
        }
    }
}

// MARK: - Logging Middleware

class LoggingMiddleware: MiddlewareHandler {
    func preExecution(_ action: StateAction) async throws {
        print("🔵 [STATE] Executing: \(action.name)")
    }

    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async {
        let icon = success ? "✅" : "❌"
        let durationMs = Int(duration * 1000)
        print("\(icon) [STATE] Completed: \(action.name) (\(durationMs)ms)")
    }
}

// MARK: - Validation Middleware

class ValidationMiddleware: MiddlewareHandler {
    func preExecution(_ action: StateAction) async throws {
        // Validate action before execution
        switch action.category {
        case .auth:
            try validateAuthAction(action)
        case .wallet:
            try validateWalletAction(action)
        case .transaction:
            try validateTransactionAction(action)
        default:
            break
        }
    }

    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async {
        // Post-execution validation if needed
    }

    private func validateAuthAction(_ action: StateAction) throws {
        // Validate authentication-related actions
    }

    private func validateWalletAction(_ action: StateAction) throws {
        // Validate wallet-related actions
    }

    private func validateTransactionAction(_ action: StateAction) throws {
        // Validate transaction-related actions
    }
}

// MARK: - Performance Middleware

class PerformanceMiddleware: MiddlewareHandler {
    private var actionMetrics: [String: [TimeInterval]] = [:]
    private let slowThreshold: TimeInterval = 1.0 // 1 second

    func preExecution(_ action: StateAction) async throws {
        // No pre-execution needed
    }

    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async {
        // Record performance metric
        if actionMetrics[action.name] == nil {
            actionMetrics[action.name] = []
        }
        actionMetrics[action.name]?.append(duration)

        // Warn on slow actions
        if duration > slowThreshold {
            print("⚠️ [PERFORMANCE] Slow action: \(action.name) took \(duration)s")
        }
    }

    func getMetrics(for actionName: String) -> (avg: TimeInterval, max: TimeInterval, count: Int)? {
        guard let durations = actionMetrics[actionName], !durations.isEmpty else {
            return nil
        }

        let avg = durations.reduce(0, +) / TimeInterval(durations.count)
        let max = durations.max() ?? 0

        return (avg: avg, max: max, count: durations.count)
    }
}

// MARK: - Error Handling Middleware

class ErrorHandlingMiddleware: MiddlewareHandler {
    private var errorCount: [String: Int] = [:]
    private let maxRetries = 3

    func preExecution(_ action: StateAction) async throws {
        let errorKey = action.name

        if let count = errorCount[errorKey], count >= maxRetries {
            throw StateError.validationError("Action \(action.name) has failed too many times")
        }
    }

    func postExecution(_ action: StateAction, duration: TimeInterval, success: Bool) async {
        let errorKey = action.name

        if success {
            // Reset error count on success
            errorCount[errorKey] = 0
        } else {
            // Increment error count on failure
            errorCount[errorKey, default: 0] += 1
        }
    }
}
