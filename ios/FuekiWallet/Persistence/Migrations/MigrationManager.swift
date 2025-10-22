//
//  MigrationManager.swift
//  FuekiWallet
//
//  Manages Core Data schema migrations
//

import Foundation
import CoreData
import os.log

/// Manages progressive Core Data migrations
final class MigrationManager {
    // MARK: - Properties
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "Migration")
    private let persistentContainer: NSPersistentContainer

    // Current schema version
    private static let currentVersion = 2

    // MARK: - Initialization
    init() {
        self.persistentContainer = CoreDataStack.shared.persistentContainer
    }

    // MARK: - Migration Check

    /// Checks if migration is needed
    func needsMigration() async -> Bool {
        let storeURL = getStoreURL()

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            logger.info("No existing store found, migration not needed")
            return false
        }

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL
            )

            let model = persistentContainer.managedObjectModel
            let isCompatible = model.isConfiguration(
                withName: nil,
                compatibleWithStoreMetadata: metadata
            )

            if isCompatible {
                logger.info("Store is compatible, migration not needed")
                return false
            } else {
                logger.info("Store is incompatible, migration needed")
                return true
            }
        } catch {
            logger.error("Failed to check migration status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Migration Execution

    /// Performs progressive migration
    func performMigration() async throws {
        logger.info("Starting Core Data migration...")

        let storeURL = getStoreURL()
        let storeVersion = try getStoreVersion(at: storeURL)

        logger.info("Current store version: \(storeVersion)")
        logger.info("Target version: \(Self.currentVersion)")

        // Create backup before migration
        try await createBackup(of: storeURL)

        // Perform progressive migrations
        var currentVersion = storeVersion

        while currentVersion < Self.currentVersion {
            let nextVersion = currentVersion + 1
            logger.info("Migrating from v\(currentVersion) to v\(nextVersion)")

            try await performMigration(
                from: currentVersion,
                to: nextVersion,
                at: storeURL
            )

            currentVersion = nextVersion
        }

        logger.info("Migration completed successfully")
    }

    // MARK: - Private Migration Methods

    private func performMigration(
        from sourceVersion: Int,
        to destinationVersion: Int,
        at storeURL: URL
    ) async throws {
        switch (sourceVersion, destinationVersion) {
        case (1, 2):
            try await Migration_v1_to_v2().migrate(storeURL: storeURL)
        default:
            throw MigrationError.unsupportedMigration(
                from: sourceVersion,
                to: destinationVersion
            )
        }
    }

    private func getStoreVersion(at url: URL) throws -> Int {
        let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: url
        )

        // Check version identifiers in metadata
        if let versionIdentifiers = metadata[NSStoreModelVersionIdentifiersKey] as? Set<String> {
            for identifier in versionIdentifiers {
                if identifier.contains("v2") {
                    return 2
                } else if identifier.contains("v1") {
                    return 1
                }
            }
        }

        // Default to version 1 if no identifier found
        return 1
    }

    private func getStoreURL() -> URL {
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FuekiWallet.sqlite")
    }

    // MARK: - Backup

    private func createBackup(of storeURL: URL) async throws {
        let backupURL = storeURL.deletingPathExtension()
            .appendingPathExtension("backup")
            .appendingPathExtension("sqlite")

        // Remove old backup if exists
        try? FileManager.default.removeItem(at: backupURL)

        // Copy store to backup location
        try FileManager.default.copyItem(at: storeURL, to: backupURL)

        // Also backup WAL and SHM files if they exist
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        if FileManager.default.fileExists(atPath: walURL.path) {
            let walBackup = backupURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
            try? FileManager.default.copyItem(at: walURL, to: walBackup)
        }

        if FileManager.default.fileExists(atPath: shmURL.path) {
            let shmBackup = backupURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
            try? FileManager.default.copyItem(at: shmURL, to: shmBackup)
        }

        logger.info("Migration backup created at: \(backupURL.path)")
    }

    // MARK: - Rollback

    func rollbackToBackup() async throws {
        let storeURL = getStoreURL()
        let backupURL = storeURL.deletingPathExtension()
            .appendingPathExtension("backup")
            .appendingPathExtension("sqlite")

        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw MigrationError.backupNotFound
        }

        // Remove current store
        try? FileManager.default.removeItem(at: storeURL)

        // Restore from backup
        try FileManager.default.copyItem(at: backupURL, to: storeURL)

        logger.info("Rolled back to backup")
    }
}

// MARK: - Migration Protocol
protocol Migration {
    func migrate(storeURL: URL) async throws
}

// MARK: - Migration Errors
enum MigrationError: LocalizedError {
    case unsupportedMigration(from: Int, to: Int)
    case migrationFailed(String)
    case backupNotFound
    case incompatibleStore

    var errorDescription: String? {
        switch self {
        case .unsupportedMigration(let from, let to):
            return "Unsupported migration from version \(from) to \(to)"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        case .backupNotFound:
            return "Migration backup not found"
        case .incompatibleStore:
            return "Store is incompatible with current model"
        }
    }
}
