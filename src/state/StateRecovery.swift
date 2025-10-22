//
//  StateRecovery.swift
//  Fueki Wallet
//
//  State recovery and error handling mechanisms
//

import Foundation
import Combine

@MainActor
class StateRecovery {
    // MARK: - Singleton
    static let shared = StateRecovery()

    // MARK: - Properties
    private let persistence = StatePersistence.shared
    private let logger = StateLogger.shared

    // Recovery strategies
    private var recoveryStrategies: [StateError: RecoveryStrategy] = [:]

    // Circuit breaker for preventing cascading failures
    private var circuitBreakers: [String: CircuitBreaker] = [:]

    // MARK: - Initialization
    private init() {
        setupDefaultStrategies()
    }

    // MARK: - Recovery Management

    func attemptRecovery(from error: StateError, context: RecoveryContext) async -> RecoveryResult {
        logger.log("Attempting recovery from error: \(error.localizedDescription)", level: .warning)

        // Check circuit breaker
        let breakerKey = context.operation
        if let breaker = circuitBreakers[breakerKey], breaker.isOpen {
            logger.log("Circuit breaker open for \(breakerKey), skipping recovery", level: .error)
            return .failed(reason: "Circuit breaker open")
        }

        // Get recovery strategy
        let strategy = recoveryStrategies[error] ?? .default

        // Execute recovery
        let result = await executeRecovery(strategy: strategy, error: error, context: context)

        // Update circuit breaker
        updateCircuitBreaker(key: breakerKey, success: result.isSuccess)

        return result
    }

    func recoverFromCorruptedState() async -> Bool {
        logger.log("Attempting to recover from corrupted state", level: .critical)

        do {
            // Try to restore from latest backup
            let backups = try await persistence.listBackups()

            for backup in backups.reversed() {
                do {
                    try await persistence.restoreFromBackup(backupName: backup)
                    logger.log("Successfully restored from backup: \(backup)", level: .info)
                    return true
                } catch {
                    logger.log("Failed to restore from backup \(backup): \(error)", level: .warning)
                    continue
                }
            }

            // If no backups work, reset to defaults
            logger.log("No valid backups found, resetting to defaults", level: .critical)
            await resetToDefaults()
            return true

        } catch {
            logger.log("Recovery failed: \(error)", level: .critical)
            return false
        }
    }

    func createStateSnapshot() async throws -> StateSnapshot {
        let appState = AppState.shared

        let snapshot = StateSnapshot(
            action: StateAction(name: "manual_snapshot", category: .system),
            timestamp: Date(),
            success: true,
            error: nil
        )

        // Save current state
        try await persistence.createBackup()

        return snapshot
    }

    func validateStateIntegrity() async -> ValidationResult {
        logger.log("Validating state integrity", level: .info)

        var issues: [String] = []

        // Validate auth state
        let authState = AppState.shared.authState
        if authState.isAuthenticated && authState.currentUser == nil {
            issues.append("Auth state inconsistent: authenticated but no user")
        }

        // Validate wallet state
        let walletState = AppState.shared.walletState
        if walletState.activeWallet != nil && walletState.wallets.isEmpty {
            issues.append("Wallet state inconsistent: active wallet but empty list")
        }

        // Validate transaction state
        let transactionState = AppState.shared.transactionState
        if transactionState.pendingTransactions.count > 50 {
            issues.append("Too many pending transactions: \(transactionState.pendingTransactions.count)")
        }

        if issues.isEmpty {
            return .valid
        } else {
            return .invalid(issues: issues)
        }
    }

    // MARK: - Private Methods

    private func setupDefaultStrategies() {
        recoveryStrategies = [
            .syncError(NSError(domain: "", code: 0)): .retry(maxAttempts: 3, delay: 5.0),
            .persistenceError(NSError(domain: "", code: 0)): .restoreFromBackup,
            .networkError(""): .queueAndRetry,
            .validationError(""): .resetInvalidState
        ]
    }

    private func executeRecovery(
        strategy: RecoveryStrategy,
        error: StateError,
        context: RecoveryContext
    ) async -> RecoveryResult {
        switch strategy {
        case .retry(let maxAttempts, let delay):
            return await retryOperation(maxAttempts: maxAttempts, delay: delay, context: context)

        case .restoreFromBackup:
            return await restoreFromBackup()

        case .queueAndRetry:
            return await queueForLater(context: context)

        case .resetInvalidState:
            return await resetInvalidState(context: context)

        case .default:
            return await defaultRecovery(error: error, context: context)
        }
    }

    private func retryOperation(maxAttempts: Int, delay: TimeInterval, context: RecoveryContext) async -> RecoveryResult {
        for attempt in 1...maxAttempts {
            logger.log("Retry attempt \(attempt)/\(maxAttempts)", level: .info)

            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            do {
                // Retry the actual operation based on context
                switch context.operation {
                case "sync":
                    try await StateSync.shared.syncAllStates()

                case "persist":
                    try await AppState.shared.persistState()

                case "restore":
                    await AppState.shared.restoreState()

                default:
                    break
                }

                return .recovered(method: "retry")
            } catch {
                logger.log("Retry attempt \(attempt) failed: \(error)", level: .warning)

                if attempt == maxAttempts {
                    return .failed(reason: "Max retry attempts exceeded")
                }
            }
        }

        return .failed(reason: "Max retry attempts exceeded")
    }

    private func restoreFromBackup() async -> RecoveryResult {
        do {
            try await persistence.restoreFromBackup()
            return .recovered(method: "backup_restore")
        } catch {
            return .failed(reason: "Backup restore failed: \(error.localizedDescription)")
        }
    }

    private func queueForLater(context: RecoveryContext) async -> RecoveryResult {
        // Queue operation for when connection is restored
        let operation = SyncOperation(
            type: .createTransaction,
            data: context.metadata
        )

        StateSync.shared.queueOperation(operation)

        return .deferred(until: "network_available")
    }

    private func resetInvalidState(context: RecoveryContext) async -> RecoveryResult {
        // Reset specific state that is invalid
        logger.log("Resetting invalid state for: \(context.operation)", level: .warning)

        // Implement selective state reset based on context
        switch context.operation {
        case "auth":
            AppState.shared.authState.reset()

        case "wallet":
            AppState.shared.walletState.reset()

        case "transaction":
            AppState.shared.transactionState.reset()

        case "settings":
            AppState.shared.settingsState.reset()

        default:
            await AppState.shared.resetState()
        }

        return .recovered(method: "state_reset")
    }

    private func defaultRecovery(error: StateError, context: RecoveryContext) async -> RecoveryResult {
        logger.log("Using default recovery for: \(error.localizedDescription)", level: .info)

        // Default: try backup restore, then reset
        let backupResult = await restoreFromBackup()
        if backupResult.isSuccess {
            return backupResult
        }

        await resetToDefaults()
        return .recovered(method: "default_reset")
    }

    private func resetToDefaults() async {
        let appState = AppState.shared
        await appState.resetState()

        logger.log("State reset to defaults", level: .info)
    }

    private func updateCircuitBreaker(key: String, success: Bool) {
        if circuitBreakers[key] == nil {
            circuitBreakers[key] = CircuitBreaker()
        }

        if success {
            circuitBreakers[key]?.recordSuccess()
        } else {
            circuitBreakers[key]?.recordFailure()
        }
    }
}

// MARK: - Supporting Types

enum RecoveryStrategy {
    case retry(maxAttempts: Int, delay: TimeInterval)
    case restoreFromBackup
    case queueAndRetry
    case resetInvalidState
    case `default`
}

enum RecoveryResult {
    case recovered(method: String)
    case failed(reason: String)
    case deferred(until: String)

    var isSuccess: Bool {
        switch self {
        case .recovered, .deferred:
            return true
        case .failed:
            return false
        }
    }
}

enum ValidationResult {
    case valid
    case invalid(issues: [String])

    var isValid: Bool {
        switch self {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
}

struct RecoveryContext {
    let operation: String
    let timestamp: Date
    let metadata: [String: String]

    init(operation: String, metadata: [String: String] = [:]) {
        self.operation = operation
        self.timestamp = Date()
        self.metadata = metadata
    }
}

// MARK: - Circuit Breaker

class CircuitBreaker {
    private var failureCount = 0
    private var lastFailureTime: Date?
    private let threshold = 5
    private let timeout: TimeInterval = 60 // 1 minute

    var isOpen: Bool {
        guard failureCount >= threshold else { return false }

        if let lastFailure = lastFailureTime {
            let timeSinceFailure = Date().timeIntervalSince(lastFailure)
            if timeSinceFailure > timeout {
                // Reset after timeout
                reset()
                return false
            }
        }

        return true
    }

    func recordSuccess() {
        reset()
    }

    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
    }

    func reset() {
        failureCount = 0
        lastFailureTime = nil
    }
}
