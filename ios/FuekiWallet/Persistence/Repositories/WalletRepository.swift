//
//  WalletRepository.swift
//  FuekiWallet
//
//  Repository for wallet data operations
//

import Foundation
import CoreData
import os.log

/// Repository pattern implementation for wallet entities
final class WalletRepository {
    // MARK: - Properties
    private let context: NSManagedObjectContext
    private let cache: CacheManager
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "WalletRepository")

    // MARK: - Initialization
    init(context: NSManagedObjectContext, cache: CacheManager) {
        self.context = context
        self.cache = cache
    }

    // MARK: - CRUD Operations

    /// Creates a new wallet entity
    func create(
        name: String,
        address: String,
        privateKey: String,
        type: WalletType = .imported
    ) throws -> WalletEntity {
        let wallet = WalletEntity(context: context)
        wallet.id = UUID()
        wallet.name = name
        wallet.address = address.lowercased()
        wallet.type = type.rawValue
        wallet.balance = 0.0
        wallet.createdAt = Date()
        wallet.updatedAt = Date()
        wallet.isActive = true

        // Store private key securely in Keychain
        try KeychainManager.shared.save(privateKey, for: wallet.id!.uuidString)

        try context.save()
        invalidateCache()

        logger.info("Wallet created: \(name)")
        return wallet
    }

    /// Fetches a wallet by ID
    func fetch(id: UUID) throws -> WalletEntity? {
        // Check cache first
        let cacheKey = "wallet_\(id.uuidString)"
        if let cached: WalletEntity = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try context.fetch(fetchRequest)

        // Cache the result
        if let wallet = results.first {
            cache.set(wallet, key: cacheKey, ttl: 300) // 5 minutes
        }

        return results.first
    }

    /// Fetches a wallet by address
    func fetch(address: String) throws -> WalletEntity? {
        let normalizedAddress = address.lowercased()

        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "address == %@", normalizedAddress)
        fetchRequest.fetchLimit = 1

        let results = try context.fetch(fetchRequest)
        return results.first
    }

    /// Fetches all wallets
    func fetchAll(in context: NSManagedObjectContext? = nil) throws -> [WalletEntity] {
        let ctx = context ?? self.context

        // Check cache first
        let cacheKey = "wallets_all"
        if let cached: [WalletEntity] = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \WalletEntity.createdAt, ascending: false)
        ]

        let results = try ctx.fetch(fetchRequest)

        // Cache the results
        cache.set(results, key: cacheKey, ttl: 60) // 1 minute

        return results
    }

    /// Fetches active wallets only
    func fetchActive() throws -> [WalletEntity] {
        let cacheKey = "wallets_active"
        if let cached: [WalletEntity] = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == true")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \WalletEntity.createdAt, ascending: false)
        ]

        let results = try context.fetch(fetchRequest)
        cache.set(results, key: cacheKey, ttl: 60)

        return results
    }

    /// Updates a wallet's balance
    func updateBalance(_ wallet: WalletEntity, balance: Double) throws {
        wallet.balance = balance
        wallet.updatedAt = Date()

        try context.save()
        invalidateCache()

        logger.info("Wallet balance updated: \(wallet.name ?? "Unknown")")
    }

    /// Updates a wallet's name
    func updateName(_ wallet: WalletEntity, name: String) throws {
        wallet.name = name
        wallet.updatedAt = Date()

        try context.save()
        invalidateCache()

        logger.info("Wallet name updated: \(name)")
    }

    /// Marks a wallet as active or inactive
    func setActive(_ wallet: WalletEntity, isActive: Bool) throws {
        wallet.isActive = isActive
        wallet.updatedAt = Date()

        try context.save()
        invalidateCache()

        logger.info("Wallet active status changed: \(wallet.name ?? "Unknown") - \(isActive)")
    }

    /// Deletes a wallet
    func delete(_ wallet: WalletEntity) throws {
        // Delete private key from Keychain
        if let id = wallet.id?.uuidString {
            try? KeychainManager.shared.delete(for: id)
        }

        context.delete(wallet)
        try context.save()
        invalidateCache()

        logger.info("Wallet deleted: \(wallet.name ?? "Unknown")")
    }

    // MARK: - Batch Operations

    /// Updates multiple wallet balances efficiently
    func batchUpdateBalances(_ updates: [(UUID, Double)]) async throws {
        try await CoreDataStack.shared.performBackgroundTask { context in
            for (id, balance) in updates {
                let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                fetchRequest.fetchLimit = 1

                if let wallet = try context.fetch(fetchRequest).first {
                    wallet.balance = balance
                    wallet.updatedAt = Date()
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        invalidateCache()
        logger.info("Batch balance update completed: \(updates.count) wallets")
    }

    // MARK: - Query Operations

    /// Fetches wallets with total balance greater than specified amount
    func fetchWallets(withBalanceGreaterThan amount: Double) throws -> [WalletEntity] {
        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "balance > %f AND isActive == true", amount)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \WalletEntity.balance, ascending: false)
        ]

        return try context.fetch(fetchRequest)
    }

    /// Calculates total balance across all active wallets
    func calculateTotalBalance() throws -> Double {
        let cacheKey = "wallets_total_balance"
        if let cached: Double = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isActive == true")

        let wallets = try context.fetch(fetchRequest)
        let total = wallets.reduce(0.0) { $0 + $1.balance }

        cache.set(total, key: cacheKey, ttl: 30) // 30 seconds

        return total
    }

    /// Searches wallets by name or address
    func search(query: String) throws -> [WalletEntity] {
        let fetchRequest: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "name CONTAINS[cd] %@ OR address CONTAINS[cd] %@",
            query, query
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \WalletEntity.name, ascending: true)
        ]

        return try context.fetch(fetchRequest)
    }

    // MARK: - Import/Export

    /// Imports a wallet from transfer object
    func importWallet(_ data: WalletTransferObject, in context: NSManagedObjectContext) throws {
        let wallet = WalletEntity(context: context)
        wallet.id = data.id
        wallet.name = data.name
        wallet.address = data.address
        wallet.balance = data.balance
        wallet.createdAt = data.createdAt
        wallet.updatedAt = Date()
        wallet.isActive = true

        logger.info("Wallet imported: \(data.name)")
    }

    // MARK: - Private Helpers

    private func invalidateCache() {
        cache.remove(key: "wallets_all")
        cache.remove(key: "wallets_active")
        cache.remove(key: "wallets_total_balance")
    }
}

// MARK: - Wallet Entity Extension
extension WalletEntity: TransferObjectConvertible {
    func toTransferObject() -> WalletTransferObject {
        return WalletTransferObject(
            id: id ?? UUID(),
            name: name ?? "",
            address: address ?? "",
            balance: balance,
            createdAt: createdAt ?? Date()
        )
    }
}

// MARK: - Wallet Type
enum WalletType: String, Codable {
    case imported = "imported"
    case generated = "generated"
    case watchOnly = "watch_only"
    case hardware = "hardware"
}

// MARK: - Keychain Manager (Placeholder)
class KeychainManager {
    static let shared = KeychainManager()

    func save(_ data: String, for key: String) throws {
        // Implementation would use Security framework
        // Placeholder for now
    }

    func delete(for key: String) throws {
        // Implementation would use Security framework
        // Placeholder for now
    }
}
