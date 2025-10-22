//
//  StateCoordinator.swift
//  Fueki Wallet
//
//  Central coordinator for all state management operations
//

import Foundation
import Combine

@MainActor
class StateCoordinator {
    // MARK: - Singleton
    static let shared = StateCoordinator()

    // MARK: - Components
    private let stateManager = StateManager.shared
    private let recovery = StateRecovery.shared
    private let undoRedo = UndoRedoManager.shared
    private let migration = StateMigrationManager.shared
    private let persistence = StatePersistence.shared
    private let sync = StateSync.shared
    private let logger = StateLogger.shared

    // MARK: - Initialization
    private init() {}

    // MARK: - Lifecycle Management

    /// Initialize the entire state management system
    func initialize() async throws {
        logger.log("Initializing state management system", level: .info)

        // Check and perform migrations
        try await migration.checkAndMigrate()

        // Restore persisted state
        await AppState.shared.restoreState()

        // Validate state integrity
        let validation = await recovery.validateStateIntegrity()
        if !validation.isValid {
            logger.log("State integrity issues detected", level: .warning)
            try await handleIntegrityIssues(validation)
        }

        // Start network monitoring and sync
        if sync.isOnline {
            try? await sync.syncAllStates()
        }

        logger.log("State management system initialized successfully", level: .info)
    }

    /// Shutdown the state management system gracefully
    func shutdown() async throws {
        logger.log("Shutting down state management system", level: .info)

        // Cancel any ongoing sync operations
        sync.cancelSync()

        // Persist current state
        try await AppState.shared.persistState()

        // Create final backup
        try await persistence.createBackup()

        logger.log("State management system shutdown complete", level: .info)
    }

    // MARK: - State Operations

    /// Execute a state mutation with full tracking and recovery
    func execute<T>(
        _ action: StateAction,
        undoable: Bool = false,
        mutation: @escaping () async throws -> T
    ) async throws -> T {
        do {
            // Execute through state manager
            let result = try await stateManager.execute(action, mutation: mutation)

            // Record for undo/redo if needed
            if undoable {
                let operation = StateOperation(
                    type: action.name,
                    data: action.metadata.mapValues { "\($0)" }
                )
                undoRedo.recordOperation(operation)
            }

            return result
        } catch {
            // Attempt recovery
            let context = RecoveryContext(
                operation: action.name,
                metadata: action.metadata.mapValues { "\($0)" }
            )

            let recoveryResult = await recovery.attemptRecovery(
                from: StateError.syncError(error),
                context: context
            )

            if !recoveryResult.isSuccess {
                throw error
            }

            // Retry after recovery
            return try await mutation()
        }
    }

    /// Perform undo operation
    func undo() async throws {
        guard let operation = try await undoRedo.undo() else {
            logger.log("No operations to undo", level: .info)
            return
        }

        logger.log("Undid operation: \(operation.type)", level: .info)

        // Persist state after undo
        try await AppState.shared.persistState()
    }

    /// Perform redo operation
    func redo() async throws {
        guard let operation = try await undoRedo.redo() else {
            logger.log("No operations to redo", level: .info)
            return
        }

        logger.log("Redid operation: \(operation.type)", level: .info)

        // Persist state after redo
        try await AppState.shared.persistState()
    }

    // MARK: - Recovery

    /// Perform full state recovery
    func recoverState() async -> Bool {
        logger.log("Initiating full state recovery", level: .warning)

        let success = await recovery.recoverFromCorruptedState()

        if success {
            logger.log("State recovery successful", level: .info)

            // Reinitialize
            try? await initialize()
        } else {
            logger.log("State recovery failed", level: .critical)
        }

        return success
    }

    /// Create manual state snapshot
    func createSnapshot() async throws -> StateSnapshot {
        return try await recovery.createStateSnapshot()
    }

    // MARK: - Diagnostics

    /// Get comprehensive system health status
    func getSystemHealth() async -> SystemHealth {
        let metrics = stateManager.getPerformanceMetrics()
        let validation = await recovery.validateStateIntegrity()

        let queueSize = sync.isOnline ? 0 : 1 // Placeholder

        return SystemHealth(
            isHealthy: validation.isValid && metrics.successRate > 0.9,
            performanceMetrics: metrics,
            validationResult: validation,
            syncQueueSize: queueSize,
            canUndo: undoRedo.canUndo,
            canRedo: undoRedo.canRedo,
            currentVersion: migration.getCurrentVersion(),
            savedVersion: migration.getSavedVersion()
        )
    }

    /// Export complete diagnostic report
    func exportDiagnostics() async -> String {
        var report = "=== Fueki Wallet State Diagnostics ===\n"
        report += "Generated: \(Date().ISO8601Format())\n\n"

        // System Health
        let health = await getSystemHealth()
        report += "=== System Health ===\n"
        report += "Status: \(health.isHealthy ? "Healthy" : "Unhealthy")\n"
        report += "Schema Version: \(health.currentVersion) (Saved: \(health.savedVersion))\n"
        report += "Can Undo: \(health.canUndo)\n"
        report += "Can Redo: \(health.canRedo)\n"
        report += "Sync Queue Size: \(health.syncQueueSize)\n\n"

        // Performance Metrics
        report += "=== Performance ===\n"
        report += "Total Actions: \(health.performanceMetrics.totalActions)\n"
        report += "Success Rate: \(String(format: "%.2f%%", health.performanceMetrics.successRate * 100))\n"
        report += "Average Duration: \(String(format: "%.2fms", health.performanceMetrics.averageDuration * 1000))\n\n"

        // Validation Results
        report += "=== Validation ===\n"
        if let issues = health.validationResult.issues {
            report += "Issues Found: \(issues.count)\n"
            for issue in issues {
                report += "  - \(issue)\n"
            }
        } else {
            report += "No issues found\n"
        }
        report += "\n"

        // Logs
        report += logger.exportLogs()

        return report
    }

    // MARK: - Private Methods

    private func handleIntegrityIssues(_ validation: ValidationResult) async throws {
        guard case .invalid(let issues) = validation else { return }

        logger.log("Handling \(issues.count) integrity issues", level: .warning)

        for issue in issues {
            logger.log("Issue: \(issue)", level: .warning)

            // Attempt automatic fixes
            if issue.contains("auth") {
                AppState.shared.authState.reset()
            } else if issue.contains("wallet") {
                // Validate wallet consistency
                let walletState = AppState.shared.walletState
                if walletState.activeWallet != nil && walletState.wallets.isEmpty {
                    walletState.reset()
                }
            } else if issue.contains("transaction") {
                // Clean up excessive pending transactions
                let transactionState = AppState.shared.transactionState
                if transactionState.pendingTransactions.count > 50 {
                    // Keep only most recent 20 pending
                    let recentPending = Array(transactionState.pendingTransactions.suffix(20))
                    for tx in transactionState.pendingTransactions {
                        if !recentPending.contains(where: { $0.id == tx.id }) {
                            transactionState.removeTransaction(tx.id)
                        }
                    }
                }
            }
        }

        // Persist fixes
        try await AppState.shared.persistState()
    }
}

// MARK: - System Health

struct SystemHealth {
    let isHealthy: Bool
    let performanceMetrics: PerformanceMetrics
    let validationResult: ValidationResult
    let syncQueueSize: Int
    let canUndo: Bool
    let canRedo: Bool
    let currentVersion: Int
    let savedVersion: Int
}

extension ValidationResult {
    var issues: [String]? {
        switch self {
        case .valid:
            return nil
        case .invalid(let issues):
            return issues
        }
    }
}
