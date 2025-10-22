//
//  TransactionRepository.swift
//  FuekiWallet
//
//  Repository for transaction data operations
//

import Foundation
import CoreData
import os.log

/// Repository pattern implementation for transaction entities
final class TransactionRepository {
    // MARK: - Properties
    private let context: NSManagedObjectContext
    private let cache: CacheManager
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "TransactionRepository")

    // MARK: - Initialization
    init(context: NSManagedObjectContext, cache: CacheManager) {
        self.context = context
        self.cache = cache
    }

    // MARK: - CRUD Operations

    /// Creates a new transaction entity
    func create(
        hash: String,
        from: String,
        to: String,
        amount: Double,
        fee: Double,
        wallet: WalletEntity,
        type: TransactionType = .send,
        status: TransactionStatus = .pending
    ) throws -> TransactionEntity {
        let transaction = TransactionEntity(context: context)
        transaction.id = UUID()
        transaction.hash = hash.lowercased()
        transaction.fromAddress = from.lowercased()
        transaction.toAddress = to.lowercased()
        transaction.amount = amount
        transaction.fee = fee
        transaction.type = type.rawValue
        transaction.status = status.rawValue
        transaction.timestamp = Date()
        transaction.wallet = wallet
        transaction.confirmations = 0

        try context.save()
        invalidateCache(for: wallet)

        logger.info("Transaction created: \(hash)")
        return transaction
    }

    /// Fetches a transaction by ID
    func fetch(id: UUID) throws -> TransactionEntity? {
        let cacheKey = "tx_\(id.uuidString)"
        if let cached: TransactionEntity = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        let results = try context.fetch(fetchRequest)

        if let transaction = results.first {
            cache.set(transaction, key: cacheKey, ttl: 300)
        }

        return results.first
    }

    /// Fetches a transaction by hash
    func fetch(hash: String) throws -> TransactionEntity? {
        let normalizedHash = hash.lowercased()

        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "hash == %@", normalizedHash)
        fetchRequest.fetchLimit = 1

        return try context.fetch(fetchRequest).first
    }

    /// Fetches all transactions
    func fetchAll(in context: NSManagedObjectContext? = nil) throws -> [TransactionEntity] {
        let ctx = context ?? self.context

        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
        ]

        return try ctx.fetch(fetchRequest)
    }

    /// Fetches transactions for a specific wallet
    func fetchTransactions(for wallet: WalletEntity, limit: Int? = nil) throws -> [TransactionEntity] {
        let cacheKey = "tx_wallet_\(wallet.id?.uuidString ?? "")"
        if let cached: [TransactionEntity] = cache.get(key: cacheKey) {
            return cached
        }

        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "wallet == %@", wallet)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
        ]

        if let limit = limit {
            fetchRequest.fetchLimit = limit
        }

        let results = try context.fetch(fetchRequest)
        cache.set(results, key: cacheKey, ttl: 60)

        return results
    }

    /// Fetches pending transactions
    func fetchPending() throws -> [TransactionEntity] {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", TransactionStatus.pending.rawValue)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
        ]

        return try context.fetch(fetchRequest)
    }

    /// Fetches transactions by status
    func fetchTransactions(status: TransactionStatus) throws -> [TransactionEntity] {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", status.rawValue)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
        ]

        return try context.fetch(fetchRequest)
    }

    /// Fetches transactions within a date range
    func fetchTransactions(from startDate: Date, to endDate: Date) throws -> [TransactionEntity] {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "timestamp >= %@ AND timestamp <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TransactionEntity.timestamp, ascending: false)
        ]

        return try context.fetch(fetchRequest)
    }

    // MARK: - Update Operations

    /// Updates transaction status
    func updateStatus(_ transaction: TransactionEntity, status: TransactionStatus) throws {
        transaction.status = status.rawValue

        if status == .confirmed {
            transaction.confirmedAt = Date()
        }

        try context.save()

        if let wallet = transaction.wallet {
            invalidateCache(for: wallet)
        }

        logger.info("Transaction status updated: \(transaction.hash ?? "Unknown") - \(status.rawValue)")
    }

    /// Updates transaction confirmations
    func updateConfirmations(_ transaction: TransactionEntity, confirmations: Int) throws {
        transaction.confirmations = Int32(confirmations)

        // Auto-confirm if confirmations reach threshold
        if confirmations >= 12 && transaction.status == TransactionStatus.pending.rawValue {
            transaction.status = TransactionStatus.confirmed.rawValue
            transaction.confirmedAt = Date()
        }

        try context.save()

        logger.info("Transaction confirmations updated: \(transaction.hash ?? "Unknown") - \(confirmations)")
    }

    /// Updates transaction metadata
    func updateMetadata(_ transaction: TransactionEntity, metadata: [String: String]) throws {
        transaction.metadata = metadata
        try context.save()
    }

    // MARK: - Delete Operations

    /// Deletes a transaction
    func delete(_ transaction: TransactionEntity) throws {
        let wallet = transaction.wallet

        context.delete(transaction)
        try context.save()

        if let wallet = wallet {
            invalidateCache(for: wallet)
        }

        logger.info("Transaction deleted: \(transaction.hash ?? "Unknown")")
    }

    /// Deletes old transactions (older than specified days)
    func deleteOldTransactions(olderThan days: Int) async throws {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        try await CoreDataStack.shared.performBackgroundTask { context in
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = TransactionEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "timestamp < %@", cutoffDate as NSDate)

            let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            batchDelete.resultType = .resultTypeCount

            let result = try context.execute(batchDelete) as? NSBatchDeleteResult
            let count = result?.result as? Int ?? 0

            self.logger.info("Deleted \(count) old transactions")
        }

        cache.clearAll()
    }

    // MARK: - Batch Operations

    /// Batch updates transaction statuses
    func batchUpdateStatuses(_ updates: [(UUID, TransactionStatus)]) async throws {
        try await CoreDataStack.shared.performBackgroundTask { context in
            for (id, status) in updates {
                let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                fetchRequest.fetchLimit = 1

                if let transaction = try context.fetch(fetchRequest).first {
                    transaction.status = status.rawValue
                    if status == .confirmed {
                        transaction.confirmedAt = Date()
                    }
                }
            }

            if context.hasChanges {
                try context.save()
            }
        }

        cache.clearAll()
        logger.info("Batch status update completed: \(updates.count) transactions")
    }

    // MARK: - Statistics

    /// Calculates total sent amount for a wallet
    func calculateTotalSent(for wallet: WalletEntity) throws -> Double {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "wallet == %@ AND type == %@",
            wallet,
            TransactionType.send.rawValue
        )

        let transactions = try context.fetch(fetchRequest)
        return transactions.reduce(0.0) { $0 + $1.amount }
    }

    /// Calculates total received amount for a wallet
    func calculateTotalReceived(for wallet: WalletEntity) throws -> Double {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "wallet == %@ AND type == %@",
            wallet,
            TransactionType.receive.rawValue
        )

        let transactions = try context.fetch(fetchRequest)
        return transactions.reduce(0.0) { $0 + $1.amount }
    }

    /// Gets transaction count for a wallet
    func getTransactionCount(for wallet: WalletEntity) throws -> Int {
        let fetchRequest: NSFetchRequest<TransactionEntity> = TransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "wallet == %@", wallet)

        return try context.count(for: fetchRequest)
    }

    // MARK: - Import/Export

    /// Imports a transaction from transfer object
    func importTransaction(_ data: TransactionTransferObject, in context: NSManagedObjectContext) throws {
        let transaction = TransactionEntity(context: context)
        transaction.id = data.id
        transaction.hash = data.hash
        transaction.amount = data.amount
        transaction.timestamp = data.timestamp

        // Find and link wallet
        let walletFetch: NSFetchRequest<WalletEntity> = WalletEntity.fetchRequest()
        walletFetch.predicate = NSPredicate(format: "id == %@", data.walletId as CVarArg)
        walletFetch.fetchLimit = 1

        if let wallet = try context.fetch(walletFetch).first {
            transaction.wallet = wallet
        }

        logger.info("Transaction imported: \(data.hash)")
    }

    // MARK: - Private Helpers

    private func invalidateCache(for wallet: WalletEntity) {
        cache.remove(key: "tx_wallet_\(wallet.id?.uuidString ?? "")")
    }
}

// MARK: - Transaction Entity Extension
extension TransactionEntity: TransferObjectConvertible {
    func toTransferObject() -> TransactionTransferObject {
        return TransactionTransferObject(
            id: id ?? UUID(),
            hash: hash ?? "",
            amount: amount,
            timestamp: timestamp ?? Date(),
            walletId: wallet?.id ?? UUID()
        )
    }
}

// MARK: - Transaction Type
enum TransactionType: String, Codable {
    case send = "send"
    case receive = "receive"
    case swap = "swap"
    case contract = "contract"
}

// MARK: - Transaction Status
enum TransactionStatus: String, Codable {
    case pending = "pending"
    case confirmed = "confirmed"
    case failed = "failed"
    case dropped = "dropped"
}
