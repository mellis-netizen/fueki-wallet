//
//  PersistenceController.swift
//  FuekiWallet
//
//  Main persistence coordinator and data access layer
//

import Foundation
import CoreData
import Combine
import os.log

/// Main persistence controller coordinating all data operations
final class PersistenceController: ObservableObject {
    // MARK: - Singleton
    static let shared = PersistenceController()

    // MARK: - Properties
    private let coreDataStack: CoreDataStack
    private let cacheManager: CacheManager
    private let userDefaultsManager: UserDefaultsManager
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "Persistence")

    // Repository instances
    let walletRepository: WalletRepository
    let transactionRepository: TransactionRepository
    let assetRepository: AssetRepository
    let settingsRepository: SettingsRepository

    // Published properties for reactive updates
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date?

    // MARK: - Initialization
    private init() {
        self.coreDataStack = CoreDataStack.shared
        self.cacheManager = CacheManager.shared
        self.userDefaultsManager = UserDefaultsManager.shared

        // Initialize repositories
        self.walletRepository = WalletRepository(
            context: coreDataStack.viewContext,
            cache: cacheManager
        )
        self.transactionRepository = TransactionRepository(
            context: coreDataStack.viewContext,
            cache: cacheManager
        )
        self.assetRepository = AssetRepository(
            context: coreDataStack.viewContext,
            cache: cacheManager
        )
        self.settingsRepository = SettingsRepository(
            userDefaults: userDefaultsManager
        )

        logger.info("PersistenceController initialized")
    }

    // MARK: - Context Access

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        return coreDataStack.viewContext
    }

    /// Creates a new background context
    func newBackgroundContext() -> NSManagedObjectContext {
        return coreDataStack.newBackgroundContext()
    }

    // MARK: - Save Operations

    /// Saves all pending changes
    func save() async throws {
        do {
            try coreDataStack.saveViewContext()
            lastSyncDate = Date()
            logger.info("All changes saved successfully")
        } catch {
            logger.error("Failed to save changes: \(error.localizedDescription)")
            throw error
        }
    }

    /// Saves changes in a background context
    func saveInBackground(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await coreDataStack.performBackgroundTask(block)
            lastSyncDate = Date()
            logger.info("Background save completed")
        } catch {
            logger.error("Background save failed: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Data Import/Export

    /// Imports wallet data from JSON
    func importWalletData(from jsonData: Data) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let importData = try decoder.decode(WalletImportData.self, from: jsonData)

            try await saveInBackground { context in
                // Import wallets
                for walletData in importData.wallets {
                    try self.walletRepository.importWallet(walletData, in: context)
                }

                // Import transactions
                for txData in importData.transactions {
                    try self.transactionRepository.importTransaction(txData, in: context)
                }

                // Import assets
                for assetData in importData.assets {
                    try self.assetRepository.importAsset(assetData, in: context)
                }
            }

            logger.info("Wallet data imported successfully")
        } catch {
            logger.error("Failed to import wallet data: \(error.localizedDescription)")
            throw PersistenceError.saveFailed(error)
        }
    }

    /// Exports wallet data to JSON
    func exportWalletData() async throws -> Data {
        isSyncing = true
        defer { isSyncing = false }

        let context = newBackgroundContext()

        return try await context.perform {
            let wallets = try self.walletRepository.fetchAll(in: context)
            let transactions = try self.transactionRepository.fetchAll(in: context)
            let assets = try self.assetRepository.fetchAll(in: context)

            let exportData = WalletExportData(
                version: "1.0",
                exportDate: Date(),
                wallets: wallets.map { $0.toTransferObject() },
                transactions: transactions.map { $0.toTransferObject() },
                assets: assets.map { $0.toTransferObject() }
            )

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

            return try encoder.encode(exportData)
        }
    }

    // MARK: - Backup & Restore

    /// Creates a backup of all wallet data
    func createBackup() async throws -> URL {
        isSyncing = true
        defer { isSyncing = false }

        let backupData = try await exportWalletData()

        let backupDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Backups", isDirectory: true)

        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        let dateFormatter = ISO8601DateFormatter()
        let filename = "fueki-backup-\(dateFormatter.string(from: Date())).json"
        let backupURL = backupDir.appendingPathComponent(filename)

        try backupData.write(to: backupURL, options: .completeFileProtection)

        logger.info("Backup created: \(backupURL.path)")
        return backupURL
    }

    /// Restores wallet data from a backup
    func restoreFromBackup(url: URL) async throws {
        isSyncing = true
        defer { isSyncing = false }

        let backupData = try Data(contentsOf: url)

        // Clear existing data
        try await clearAllData()

        // Import backup data
        try await importWalletData(from: backupData)

        logger.info("Backup restored successfully")
    }

    // MARK: - Data Management

    /// Clears all wallet data
    func clearAllData() async throws {
        isSyncing = true
        defer { isSyncing = false }

        do {
            try await coreDataStack.clearAllData()
            cacheManager.clearAll()
            logger.info("All data cleared")
        } catch {
            logger.error("Failed to clear data: \(error.localizedDescription)")
            throw error
        }
    }

    /// Optimizes the database by removing orphaned records and compacting
    func optimizeDatabase() async throws {
        isSyncing = true
        defer { isSyncing = false }

        try await saveInBackground { context in
            // Remove orphaned transactions
            let orphanedTxFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "Transaction")
            orphanedTxFetch.predicate = NSPredicate(format: "wallet == nil")

            let orphanedTxDelete = NSBatchDeleteRequest(fetchRequest: orphanedTxFetch)
            try context.execute(orphanedTxDelete)

            // Vacuum the database
            try context.save()
        }

        logger.info("Database optimized")
    }

    // MARK: - Migration Support

    /// Performs data migration if needed
    func performMigrationIfNeeded() async throws {
        let migrationManager = MigrationManager()

        if await migrationManager.needsMigration() {
            isSyncing = true
            defer { isSyncing = false }

            try await migrationManager.performMigration()
            logger.info("Migration completed successfully")
        }
    }
}

// MARK: - Preview Support
extension PersistenceController {
    /// Preview instance for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController()

        // Add sample data for previews
        Task {
            let context = controller.viewContext

            // Sample wallet
            let wallet = WalletEntity(context: context)
            wallet.id = UUID()
            wallet.name = "Preview Wallet"
            wallet.address = "0x1234567890abcdef"
            wallet.balance = 1.5
            wallet.createdAt = Date()

            // Sample transaction
            let transaction = TransactionEntity(context: context)
            transaction.id = UUID()
            transaction.hash = "0xabcdef123456"
            transaction.amount = 0.5
            transaction.timestamp = Date()
            transaction.wallet = wallet

            try? context.save()
        }

        return controller
    }()
}

// MARK: - Data Transfer Objects
struct WalletImportData: Codable {
    let wallets: [WalletTransferObject]
    let transactions: [TransactionTransferObject]
    let assets: [AssetTransferObject]
}

struct WalletExportData: Codable {
    let version: String
    let exportDate: Date
    let wallets: [WalletTransferObject]
    let transactions: [TransactionTransferObject]
    let assets: [AssetTransferObject]
}

// Transfer object protocols (to be implemented by entities)
protocol TransferObjectConvertible {
    associatedtype TransferObject: Codable
    func toTransferObject() -> TransferObject
}

struct WalletTransferObject: Codable {
    let id: UUID
    let name: String
    let address: String
    let balance: Double
    let createdAt: Date
}

struct TransactionTransferObject: Codable {
    let id: UUID
    let hash: String
    let amount: Double
    let timestamp: Date
    let walletId: UUID
}

struct AssetTransferObject: Codable {
    let id: UUID
    let symbol: String
    let name: String
    let balance: Double
    let walletId: UUID
}
