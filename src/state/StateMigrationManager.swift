//
//  StateMigrationManager.swift
//  Fueki Wallet
//
//  State migration system for schema version upgrades
//

import Foundation

@MainActor
class StateMigrationManager {
    // MARK: - Singleton
    static let shared = StateMigrationManager()

    // MARK: - Properties
    private let persistence = StatePersistence.shared
    private let logger = StateLogger.shared
    private let currentVersion = 1
    private let versionKey = "state_schema_version"

    // MARK: - Initialization
    private init() {}

    // MARK: - Migration Management

    func checkAndMigrate() async throws {
        let savedVersion = UserDefaults.standard.integer(forKey: versionKey)

        guard savedVersion < currentVersion else {
            logger.log("State schema is up to date (v\(currentVersion))", level: .info)
            return
        }

        logger.log("Migrating state schema from v\(savedVersion) to v\(currentVersion)", level: .info)

        // Create backup before migration
        try await persistence.createBackup()

        // Perform migrations
        for version in (savedVersion + 1)...currentVersion {
            try await performMigration(to: version)
        }

        // Update version
        UserDefaults.standard.set(currentVersion, forKey: versionKey)

        logger.log("State migration completed successfully", level: .info)
    }

    func getCurrentVersion() -> Int {
        return currentVersion
    }

    func getSavedVersion() -> Int {
        return UserDefaults.standard.integer(forKey: versionKey)
    }

    // MARK: - Private Methods

    private func performMigration(to version: Int) async throws {
        logger.log("Performing migration to version \(version)", level: .info)

        switch version {
        case 1:
            try await migrateToV1()

        case 2:
            try await migrateToV2()

        case 3:
            try await migrateToV3()

        default:
            logger.log("No migration needed for version \(version)", level: .warning)
        }
    }

    // MARK: - Version-Specific Migrations

    private func migrateToV1() async throws {
        // Initial version - set up base structure
        logger.log("Setting up base state structure", level: .info)

        // Ensure all state files use correct format
        if let appState = try await persistence.restoreAppState() {
            // Re-save with current format
            try await persistence.saveAppState(appState)
        }
    }

    private func migrateToV2() async throws {
        // Example: Add new fields to transactions
        logger.log("Migrating to v2: Adding confirmations field", level: .info)

        if let appState = try await persistence.restoreAppState() {
            // Update transaction structure
            let updatedTransactions = appState.transactions.transactions.map { transaction in
                var updated = transaction
                // Add default confirmations if missing
                if updated.confirmations == 0 && updated.status == .confirmed {
                    updated.confirmations = 6
                }
                return updated
            }

            // Create updated snapshot
            var updatedState = appState
            let transactionSnapshot = TransactionStateSnapshot(
                transactions: updatedTransactions,
                pendingTransactions: appState.transactions.pendingTransactions
            )

            // Re-save
            try await persistence.saveAppState(updatedState)
        }
    }

    private func migrateToV3() async throws {
        // Example: Convert currency format
        logger.log("Migrating to v3: Updating currency format", level: .info)

        if let appState = try await persistence.restoreAppState() {
            // Perform currency format conversion
            var updatedState = appState

            // Re-save with updated format
            try await persistence.saveAppState(updatedState)
        }
    }

    // MARK: - Rollback

    func rollbackToVersion(_ version: Int) async throws {
        guard version < currentVersion else {
            throw MigrationError.invalidVersion
        }

        logger.log("Rolling back to version \(version)", level: .warning)

        // Restore from backup
        let backups = try persistence.listBackups()

        for backup in backups.reversed() {
            do {
                try await persistence.restoreFromBackup(backupName: backup)

                // Update version
                UserDefaults.standard.set(version, forKey: versionKey)

                logger.log("Successfully rolled back to version \(version)", level: .info)
                return
            } catch {
                logger.log("Failed to restore from backup: \(backup)", level: .warning)
                continue
            }
        }

        throw MigrationError.rollbackFailed
    }
}

// MARK: - Migration Errors

enum MigrationError: Error, LocalizedError {
    case invalidVersion
    case migrationFailed(String)
    case rollbackFailed
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .invalidVersion:
            return "Invalid migration version"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .rollbackFailed:
            return "Failed to rollback state"
        case .corruptedData:
            return "State data is corrupted"
        }
    }
}
