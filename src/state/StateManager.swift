//
//  StateManager.swift
//  Fueki Wallet
//
//  Central state management orchestration
//

import Foundation
import Combine
import SwiftUI

@MainActor
class StateManager: ObservableObject {
    // MARK: - Singleton
    static let shared = StateManager()

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let middleware: StateMiddleware
    private let logger: StateLogger

    // State change history for debugging
    private var stateHistory: [StateSnapshot] = []
    private let maxHistorySize = 50

    // MARK: - Initialization
    private init(
        middleware: StateMiddleware = .shared,
        logger: StateLogger = .shared
    ) {
        self.middleware = middleware
        self.logger = logger

        setupMiddleware()
    }

    // MARK: - State Management

    /// Execute a state mutation with middleware
    func execute<T>(_ action: StateAction, mutation: @escaping () async throws -> T) async throws -> T {
        // Pre-execution middleware
        try await middleware.preExecution(action)

        let startTime = Date()

        do {
            // Execute mutation
            let result = try await mutation()

            // Post-execution middleware
            let duration = Date().timeIntervalSince(startTime)
            await middleware.postExecution(action, duration: duration, success: true)

            // Log success
            logger.logAction(action, success: true, duration: duration)

            // Record state change
            recordStateChange(action, success: true)

            return result
        } catch {
            // Handle error
            let duration = Date().timeIntervalSince(startTime)
            await middleware.postExecution(action, duration: duration, success: false)

            // Log error
            logger.logAction(action, success: false, duration: duration, error: error)

            // Record failed state change
            recordStateChange(action, success: false, error: error)

            throw error
        }
    }

    /// Execute a state query (read-only operation)
    func query<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        return try await operation()
    }

    // MARK: - State History

    func getStateHistory() -> [StateSnapshot] {
        return stateHistory
    }

    func clearHistory() {
        stateHistory.removeAll()
    }

    func undoLastAction() async {
        guard stateHistory.count > 1 else { return }

        // Remove current state
        stateHistory.removeLast()

        // Get previous state
        if let previousSnapshot = stateHistory.last {
            await restoreSnapshot(previousSnapshot)
        }
    }

    // MARK: - Debugging

    func printStateTree() {
        logger.printStateTree()
    }

    func getPerformanceMetrics() -> PerformanceMetrics {
        logger.getMetrics()
    }

    func logError(_ error: StateError) {
        logger.logError(error)
    }

    // MARK: - Private Methods

    private func setupMiddleware() {
        // Register middleware handlers
        middleware.register(LoggingMiddleware())
        middleware.register(ValidationMiddleware())
        middleware.register(PerformanceMiddleware())
    }

    private func recordStateChange(_ action: StateAction, success: Bool, error: Error? = nil) {
        let snapshot = StateSnapshot(
            action: action,
            timestamp: Date(),
            success: success,
            error: error
        )

        stateHistory.append(snapshot)

        // Maintain max history size
        if stateHistory.count > maxHistorySize {
            stateHistory.removeFirst()
        }
    }

    private func restoreSnapshot(_ snapshot: StateSnapshot) async {
        logger.log("Restoring state from snapshot: \(snapshot.action.name)")

        do {
            // Restore the last good state
            if let restoredState = try await StatePersistence.shared.restoreAppState() {
                await AppState.shared.applyRestoredState(restoredState)
                logger.log("State restored successfully from snapshot", level: .info)
            }
        } catch {
            logger.log("Failed to restore state: \(error.localizedDescription)", level: .error)
        }
    }
}

// MARK: - State Action

struct StateAction {
    let name: String
    let category: ActionCategory
    let metadata: [String: Any]

    enum ActionCategory {
        case auth
        case wallet
        case transaction
        case settings
        case sync
        case system
    }

    init(name: String, category: ActionCategory, metadata: [String: Any] = [:]) {
        self.name = name
        self.category = category
        self.metadata = metadata
    }
}

// MARK: - State Snapshot

struct StateSnapshot {
    let action: StateAction
    let timestamp: Date
    let success: Bool
    let error: Error?

    var description: String {
        let status = success ? "SUCCESS" : "FAILED"
        let errorDesc = error != nil ? " - \(error!.localizedDescription)" : ""
        return "[\(timestamp.ISO8601Format())] \(action.name): \(status)\(errorDesc)"
    }
}

// MARK: - Performance Metrics

struct PerformanceMetrics {
    let totalActions: Int
    let successfulActions: Int
    let failedActions: Int
    let averageDuration: TimeInterval
    let slowestActions: [(String, TimeInterval)]

    var successRate: Double {
        guard totalActions > 0 else { return 0 }
        return Double(successfulActions) / Double(totalActions)
    }
}
