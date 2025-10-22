//
//  AssetRepository.swift
//  FuekiWallet
//
//  Repository for asset (token) data operations
//

import Foundation
import CoreData
import os.log

/// Repository pattern implementation for asset entities
final class AssetRepository {
    // MARK: - Properties
    private let context: NSManagedObjectContext
    private let cache: CacheManager
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "AssetRepository")

    // MARK: - Initialization
    init(context: NSManagedObjectContext, cache: CacheManager) {
        self.context = context
        self.cache = cache
    }

    // MARK: - CRUD Operations

    /// Creates a new asset entity
    func create(
        symbol: String,
        name: String,
        contractAddress: String?,
        decimals: Int,
        wallet: WalletEntity,
        balance: Double = 0.0
    ) throws -> AssetEntity {
        let asset = AssetEntity(context: context)
        asset.id = UUID()
        asset.symbol = symbol.uppercased()
        asset.name = name
        asset.contractAddress = contractAddress?.lowercased()
        asset.decimals = Int16(decimals)
        asset.balance = balance
        asset.wallet = wallet
        asset.isEnabled = true
        asset.createdAt = Date()
        asset.updatedAt = Date()

        try context.save()
        invalidateCache(for: wallet)

        logger.info("Asset created: \(symbol)")
        return asset
    }

    /// Fetches an asset by ID
    func fetch(id: UUID) throws -> AssetEntity? {
        let cacheKey = "asset_\(id.uuidString)"
        if let cached: AssetEntity = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try context.fetch(fetchRequest)

        if let asset = results.first {
            cache.set(asset, key: cacheKey, ttl: 300)
        }

        return results.first
    }

    /// Fetches an asset by contract address
    func fetch(contractAddress: String, wallet: WalletEntity) throws -> AssetEntity? {
        let normalizedAddress = contractAddress.lowercased()

        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "contractAddress == %@ AND wallet == %@",
            normalizedAddress,
            wallet
        )
        fetchRequest.fetchLimit = 1

        return try context.fetch(fetchRequest).first
    }

    /// Fetches all assets
    func fetchAll(in context: NSManagedObjectContext? = nil) throws -> [AssetEntity] {
        let ctx = context ?? self.context

        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \AssetEntity.symbol, ascending: true)
        ]

        return try ctx.fetch(fetchRequest)
    }

    /// Fetches assets for a specific wallet
    func fetchAssets(for wallet: WalletEntity) throws -> [AssetEntity] {
        let cacheKey = "assets_wallet_\(wallet.id?.uuidString ?? "")"
        if let cached: [AssetEntity] = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "wallet == %@", wallet)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \AssetEntity.balance, ascending: false),
            NSSortDescriptor(keyPath: \AssetEntity.symbol, ascending: true)
        ]

        let results = try context.fetch(fetchRequest)
        cache.set(results, key: cacheKey, ttl: 60)

        return results
    }

    /// Fetches enabled assets for a wallet
    func fetchEnabledAssets(for wallet: WalletEntity) throws -> [AssetEntity] {
        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "wallet == %@ AND isEnabled == true",
            wallet
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \AssetEntity.balance, ascending: false)
        ]

        return try context.fetch(fetchRequest)
    }

    /// Fetches assets with non-zero balance
    func fetchNonZeroAssets(for wallet: WalletEntity) throws -> [AssetEntity] {
        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "wallet == %@ AND balance > 0",
            wallet
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \AssetEntity.balance, ascending: false)
        ]

        return try context.fetch(fetchRequest)
    }

    // MARK: - Update Operations

    /// Updates asset balance
    func updateBalance(_ asset: AssetEntity, balance: Double) throws {
        asset.balance = balance
        asset.updatedAt = Date()

        try context.save()

        if let wallet = asset.wallet {
            invalidateCache(for: wallet)
        }

        logger.info("Asset balance updated: \(asset.symbol ?? "Unknown")")
    }

    /// Updates asset price
    func updatePrice(_ asset: AssetEntity, price: Double, currency: String = "USD") throws {
        asset.priceUSD = price
        asset.lastPriceUpdate = Date()
        asset.updatedAt = Date()

        try context.save()

        logger.info("Asset price updated: \(asset.symbol ?? "Unknown") - $\(price)")
    }

    /// Updates asset metadata
    func updateMetadata(_ asset: AssetEntity, metadata: [String: String]) throws {
        asset.metadata = metadata
        asset.updatedAt = Date()

        try context.save()
    }

    /// Enables or disables an asset
    func setEnabled(_ asset: AssetEntity, isEnabled: Bool) throws {
        asset.isEnabled = isEnabled
        asset.updatedAt = Date()

        try context.save()

        if let wallet = asset.wallet {
            invalidateCache(for: wallet)
        }

        logger.info("Asset enabled status changed: \(asset.symbol ?? "Unknown") - \(isEnabled)")
    }

    // MARK: - Delete Operations

    /// Deletes an asset
    func delete(_ asset: AssetEntity) throws {
        let wallet = asset.wallet

        context.delete(asset)
        try context.save()

        if let wallet = wallet {
            invalidateCache(for: wallet)
        }

        logger.info("Asset deleted: \(asset.symbol ?? "Unknown")")
    }

    // MARK: - Batch Operations

    /// Batch updates asset balances
    func batchUpdateBalances(_ updates: [(UUID, Double)]) async throws {
        try await CoreDataStack.shared.performBackgroundTask { context in
            for (id, balance) in updates {
                let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                fetchRequest.fetchLimit = 1

                if let asset = try context.fetch(fetchRequest).first {
                    asset.balance = balance
                    asset.updatedAt = Date()
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        cache.clearAll()
        logger.info("Batch balance update completed: \(updates.count) assets")
    }

    /// Batch updates asset prices
    func batchUpdatePrices(_ updates: [(String, Double)]) async throws {
        try await CoreDataStack.shared.performBackgroundTask { context in
            for (symbol, price) in updates {
                let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "symbol == %@", symbol.uppercased())

                let assets = try context.fetch(fetchRequest)
                for asset in assets {
                    asset.priceUSD = price
                    asset.lastPriceUpdate = Date()
                    asset.updatedAt = Date()
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        cache.clearAll()
        logger.info("Batch price update completed: \(updates.count) assets")
    }

    // MARK: - Statistics

    /// Calculates total portfolio value for a wallet
    func calculatePortfolioValue(for wallet: WalletEntity) throws -> Double {
        let assets = try fetchEnabledAssets(for: wallet)
        return assets.reduce(0.0) { total, asset in
            total + (asset.balance * asset.priceUSD)
        }
    }

    /// Gets asset allocation (percentage of total value)
    func getAssetAllocation(for wallet: WalletEntity) throws -> [(symbol: String, percentage: Double)] {
        let assets = try fetchNonZeroAssets(for: wallet)
        let totalValue = try calculatePortfolioValue(for: wallet)

        guard totalValue > 0 else { return [] }

        return assets.map { asset in
            let value = asset.balance * asset.priceUSD
            let percentage = (value / totalValue) * 100
            return (symbol: asset.symbol ?? "", percentage: percentage)
        }.sorted { $0.percentage > $1.percentage }
    }

    /// Gets top assets by value
    func getTopAssets(for wallet: WalletEntity, limit: Int = 5) throws -> [AssetEntity] {
        let assets = try fetchNonZeroAssets(for: wallet)
        return Array(assets
            .sorted { ($0.balance * $0.priceUSD) > ($1.balance * $1.priceUSD) }
            .prefix(limit))
    }

    // MARK: - Search Operations

    /// Searches assets by symbol or name
    func search(query: String, in wallet: WalletEntity) throws -> [AssetEntity] {
        let fetchRequest: NSFetchRequest<AssetEntity> = AssetEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "wallet == %@ AND (symbol CONTAINS[cd] %@ OR name CONTAINS[cd] %@)",
            wallet,
            query,
            query
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \AssetEntity.symbol, ascending: true)
        ]

        return try context.fetch(fetchRequest)
    }

    // MARK: - Import/Export

    /// Imports an asset from transfer object
    func importAsset(_ data: AssetTransferObject, in context: NSManagedObjectContext) throws {
        let asset = AssetEntity(context: context)
        asset.id = data.id
        asset.symbol = data.symbol
        asset.name = data.name
        asset.balance = data.balance

        // Find and link wallet
        let walletFetch: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        walletFetch.predicate = NSPredicate(format: "id == %@", data.walletId as CVarArg)
        walletFetch.fetchLimit = 1

        if let wallet = try context.fetch(walletFetch).first {
            asset.wallet = wallet
        }

        logger.info("Asset imported: \(data.symbol)")
    }

    // MARK: - Private Helpers

    private func invalidateCache(for wallet: WalletEntity) {
        cache.remove(key: "assets_wallet_\(wallet.id?.uuidString ?? "")")
    }
}

// MARK: - Asset Entity Extension
extension AssetEntity: TransferObjectConvertible {
    func toTransferObject() -> AssetTransferObject {
        return AssetTransferObject(
            id: id ?? UUID(),
            symbol: symbol ?? "",
            name: name ?? "",
            balance: balance,
            walletId: wallet?.id ?? UUID()
        )
    }
}

// MARK: - Asset Type
enum AssetType: String, Codable {
    case native = "native"
    case erc20 = "erc20"
    case erc721 = "erc721"
    case erc1155 = "erc1155"
}
