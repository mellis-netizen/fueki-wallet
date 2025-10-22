//
//  Migration_v1_to_v2.swift
//  FuekiWallet
//
//  Migration from schema version 1 to version 2
//

import Foundation
import CoreData
import os.log

/// Migrates Core Data schema from v1 to v2
/// Changes:
/// - Added metadata field to Transaction entity
/// - Added isEnabled field to Asset entity
/// - Added priceUSD and lastPriceUpdate to Asset entity
/// - Added type field to Wallet entity
struct Migration_v1_to_v2: Migration {
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "Migration_v1_to_v2")

    func migrate(storeURL: URL) async throws {
        logger.info("Starting migration v1 to v2...")

        // Load source model (v1)
        guard let sourceModel = loadModel(version: 1) else {
            throw MigrationError.migrationFailed("Failed to load source model v1")
        }

        // Load destination model (v2)
        guard let destinationModel = loadModel(version: 2) else {
            throw MigrationError.migrationFailed("Failed to load destination model v2")
        }

        // Create mapping model
        let mappingModel = try createMappingModel(
            from: sourceModel,
            to: destinationModel
        )

        // Create temporary URL for migrated store
        let tempURL = storeURL.deletingLastPathComponent()
            .appendingPathComponent("temp_migration.sqlite")

        // Remove temp file if exists
        try? FileManager.default.removeItem(at: tempURL)

        // Perform migration
        let migrationManager = NSMigrationManager(
            sourceModel: sourceModel,
            destinationModel: destinationModel
        )

        do {
            try migrationManager.migrateStore(
                from: storeURL,
                sourceType: NSSQLiteStoreType,
                options: nil,
                with: mappingModel,
                toDestinationURL: tempURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: nil
            )

            // Replace old store with migrated one
            try replaceStore(at: storeURL, with: tempURL)

            logger.info("Migration v1 to v2 completed successfully")
        } catch {
            // Clean up temp file on error
            try? FileManager.default.removeItem(at: tempURL)
            logger.error("Migration v1 to v2 failed: \(error.localizedDescription)")
            throw MigrationError.migrationFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func loadModel(version: Int) -> NSManagedObjectModel? {
        guard let modelURL = Bundle.main.url(
            forResource: "FuekiWallet_v\(version)",
            withExtension: "momd"
        ) else {
            // If versioned model not found, try loading the main model
            return NSManagedObjectModel.mergedModel(from: [Bundle.main])
        }

        return NSManagedObjectModel(contentsOf: modelURL)
    }

    private func createMappingModel(
        from sourceModel: NSManagedObjectModel,
        to destinationModel: NSManagedObjectModel
    ) throws -> NSMappingModel {
        // Try to find custom mapping model
        if let mappingModel = NSMappingModel(
            from: [Bundle.main],
            forSourceModel: sourceModel,
            destinationModel: destinationModel
        ) {
            return mappingModel
        }

        // Infer mapping model automatically
        do {
            return try NSMappingModel.inferredMappingModel(
                forSourceModel: sourceModel,
                destinationModel: destinationModel
            )
        } catch {
            logger.error("Failed to infer mapping model: \(error.localizedDescription)")
            throw MigrationError.migrationFailed("Could not create mapping model")
        }
    }

    private func replaceStore(at originalURL: URL, with migratedURL: URL) throws {
        let fileManager = FileManager.default

        // Remove original store files
        try? fileManager.removeItem(at: originalURL)

        let walURL = originalURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let shmURL = originalURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        try? fileManager.removeItem(at: walURL)
        try? fileManager.removeItem(at: shmURL)

        // Move migrated store to original location
        try fileManager.moveItem(at: migratedURL, to: originalURL)

        // Move WAL and SHM files if they exist
        let migratedWalURL = migratedURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        let migratedShmURL = migratedURL.deletingPathExtension().appendingPathExtension("sqlite-shm")

        if fileManager.fileExists(atPath: migratedWalURL.path) {
            try? fileManager.moveItem(at: migratedWalURL, to: walURL)
        }

        if fileManager.fileExists(atPath: migratedShmURL.path) {
            try? fileManager.moveItem(at: migratedShmURL, to: shmURL)
        }
    }
}

// MARK: - Custom Entity Mappings

/// Custom migration policy for Wallet entity
final class WalletMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )

        guard let destinationInstances = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            return
        }

        // Set default type for existing wallets
        destinationInstances.setValue("imported", forKey: "type")
    }
}

/// Custom migration policy for Asset entity
final class AssetMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )

        guard let destinationInstances = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            return
        }

        // Set default values for new fields
        destinationInstances.setValue(true, forKey: "isEnabled")
        destinationInstances.setValue(0.0, forKey: "priceUSD")
        destinationInstances.setValue(nil, forKey: "lastPriceUpdate")
    }
}

/// Custom migration policy for Transaction entity
final class TransactionMigrationPolicy: NSEntityMigrationPolicy {
    override func createDestinationInstances(
        forSource sInstance: NSManagedObject,
        in mapping: NSEntityMapping,
        manager: NSMigrationManager
    ) throws {
        try super.createDestinationInstances(
            forSource: sInstance,
            in: mapping,
            manager: manager
        )

        guard let destinationInstances = manager.destinationInstances(
            forEntityMappingName: mapping.name,
            sourceInstances: [sInstance]
        ).first else {
            return
        }

        // Initialize empty metadata dictionary
        destinationInstances.setValue([String: String](), forKey: "metadata")
    }
}
