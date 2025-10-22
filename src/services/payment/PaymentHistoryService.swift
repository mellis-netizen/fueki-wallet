//
//  PaymentHistoryService.swift
//  Fueki Wallet
//
//  Payment transaction history tracking and persistence
//

import Foundation
import CoreData
import Combine

/// Service for managing payment transaction history
class PaymentHistoryService: ObservableObject {

    static let shared = PaymentHistoryService()

    // MARK: - Published Properties
    @Published var transactions: [PaymentTransaction] = []
    @Published var isLoading = false

    // MARK: - Core Data
    private let persistentContainer: NSPersistentContainer
    private let context: NSManagedObjectContext

    // MARK: - Initialization
    init() {
        // Initialize Core Data stack
        self.persistentContainer = NSPersistentContainer(name: "PaymentHistory")

        persistentContainer.loadPersistentStores { description, error in
            if let error = error {
                print("❌ Failed to load Core Data: \(error)")
            }
        }

        self.context = persistentContainer.viewContext
        self.context.automaticallyMergesChangesFromParent = true

        // Load initial data
        loadTransactions()
    }

    // MARK: - Public Methods

    /// Add new transaction to history
    func addTransaction(
        id: String,
        type: TransactionType,
        provider: PaymentProvider,
        status: TransactionStatus.Status,
        cryptocurrency: String,
        cryptoAmount: Decimal?,
        fiatCurrency: String,
        fiatAmount: Decimal,
        fee: Decimal,
        walletAddress: String?,
        metadata: [String: String]? = nil
    ) async {
        await MainActor.run {
            let transaction = PaymentTransaction(
                id: id,
                type: type,
                provider: provider,
                status: status,
                cryptocurrency: cryptocurrency,
                cryptoAmount: cryptoAmount,
                fiatCurrency: fiatCurrency,
                fiatAmount: fiatAmount,
                fee: fee,
                walletAddress: walletAddress,
                createdAt: Date(),
                updatedAt: Date(),
                completedAt: nil,
                failureReason: nil,
                metadata: metadata
            )

            self.transactions.insert(transaction, at: 0)
            self.saveTransaction(transaction)
        }
    }

    /// Update existing transaction
    func updateTransaction(
        id: String,
        status: TransactionStatus.Status,
        cryptoAmount: Decimal? = nil,
        completedAt: Date? = nil,
        failureReason: String? = nil
    ) async {
        await MainActor.run {
            if let index = self.transactions.firstIndex(where: { $0.id == id }) {
                var transaction = self.transactions[index]
                transaction.status = status
                transaction.updatedAt = Date()

                if let cryptoAmount = cryptoAmount {
                    transaction.cryptoAmount = cryptoAmount
                }

                if let completedAt = completedAt {
                    transaction.completedAt = completedAt
                }

                if let failureReason = failureReason {
                    transaction.failureReason = failureReason
                }

                self.transactions[index] = transaction
                self.updatePersistedTransaction(transaction)
            }
        }
    }

    /// Get transaction by ID
    func getTransaction(id: String) -> PaymentTransaction? {
        return transactions.first { $0.id == id }
    }

    /// Get transactions filtered by type
    func getTransactions(type: TransactionType? = nil, limit: Int = 100) -> [PaymentTransaction] {
        var filtered = transactions

        if let type = type {
            filtered = filtered.filter { $0.type == type }
        }

        return Array(filtered.prefix(limit))
    }

    /// Get pending transactions
    func getPendingTransactions() -> [PaymentTransaction] {
        return transactions.filter {
            $0.status == .pending ||
            $0.status == .processing ||
            $0.status == .waitingForPayment ||
            $0.status == .paymentReceived
        }
    }

    /// Get completed transactions
    func getCompletedTransactions(limit: Int = 50) -> [PaymentTransaction] {
        return Array(transactions.filter { $0.status == .completed }.prefix(limit))
    }

    /// Get failed transactions
    func getFailedTransactions() -> [PaymentTransaction] {
        return transactions.filter {
            $0.status == .failed ||
            $0.status == .cancelled ||
            $0.status == .expired
        }
    }

    /// Get transactions in date range
    func getTransactions(from startDate: Date, to endDate: Date) -> [PaymentTransaction] {
        return transactions.filter {
            $0.createdAt >= startDate && $0.createdAt <= endDate
        }
    }

    /// Get transaction statistics
    func getStatistics(period: StatisticsPeriod = .all) -> TransactionStatistics {
        let filtered = getTransactionsForPeriod(period)

        let purchases = filtered.filter { $0.type == .purchase }
        let sales = filtered.filter { $0.type == .sale }

        let totalPurchaseAmount = purchases.reduce(Decimal(0)) { $0 + $1.fiatAmount }
        let totalSaleAmount = sales.reduce(Decimal(0)) { $0 + $1.fiatAmount }
        let totalFees = filtered.reduce(Decimal(0)) { $0 + $1.fee }

        let completedCount = filtered.filter { $0.status == .completed }.count
        let failedCount = filtered.filter {
            $0.status == .failed || $0.status == .cancelled
        }.count

        return TransactionStatistics(
            period: period,
            totalTransactions: filtered.count,
            completedTransactions: completedCount,
            failedTransactions: failedCount,
            totalPurchaseAmount: totalPurchaseAmount,
            totalSaleAmount: totalSaleAmount,
            totalFees: totalFees,
            successRate: filtered.isEmpty ? 0 : Double(completedCount) / Double(filtered.count)
        )
    }

    /// Export transaction history
    func exportHistory(format: ExportFormat = .csv) throws -> Data {
        switch format {
        case .csv:
            return try exportAsCSV()
        case .json:
            return try exportAsJSON()
        }
    }

    /// Clear transaction history
    func clearHistory() async {
        await MainActor.run {
            self.transactions.removeAll()
            self.clearPersistedTransactions()
        }
    }

    /// Delete specific transaction
    func deleteTransaction(id: String) async {
        await MainActor.run {
            self.transactions.removeAll { $0.id == id }
            self.deletePersistedTransaction(id: id)
        }
    }

    // MARK: - Private Methods

    private func loadTransactions() {
        isLoading = true
        defer { isLoading = false }

        let fetchRequest: NSFetchRequest<PaymentTransactionEntity> = PaymentTransactionEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        fetchRequest.fetchLimit = 500

        do {
            let entities = try context.fetch(fetchRequest)
            transactions = entities.compactMap { mapEntityToTransaction($0) }
        } catch {
            print("❌ Failed to load transactions: \(error)")
        }
    }

    private func saveTransaction(_ transaction: PaymentTransaction) {
        let entity = PaymentTransactionEntity(context: context)
        entity.id = transaction.id
        entity.type = transaction.type.rawValue
        entity.provider = transaction.provider.rawValue
        entity.status = transaction.status.rawValue
        entity.cryptocurrency = transaction.cryptocurrency
        entity.cryptoAmount = transaction.cryptoAmount as NSDecimalNumber?
        entity.fiatCurrency = transaction.fiatCurrency
        entity.fiatAmount = transaction.fiatAmount as NSDecimalNumber
        entity.fee = transaction.fee as NSDecimalNumber
        entity.walletAddress = transaction.walletAddress
        entity.createdAt = transaction.createdAt
        entity.updatedAt = transaction.updatedAt
        entity.completedAt = transaction.completedAt
        entity.failureReason = transaction.failureReason

        if let metadata = transaction.metadata {
            entity.metadata = try? JSONSerialization.data(withJSONObject: metadata)
        }

        saveContext()
    }

    private func updatePersistedTransaction(_ transaction: PaymentTransaction) {
        let fetchRequest: NSFetchRequest<PaymentTransactionEntity> = PaymentTransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", transaction.id)

        do {
            let entities = try context.fetch(fetchRequest)
            if let entity = entities.first {
                entity.status = transaction.status.rawValue
                entity.cryptoAmount = transaction.cryptoAmount as NSDecimalNumber?
                entity.updatedAt = transaction.updatedAt
                entity.completedAt = transaction.completedAt
                entity.failureReason = transaction.failureReason

                saveContext()
            }
        } catch {
            print("❌ Failed to update transaction: \(error)")
        }
    }

    private func deletePersistedTransaction(id: String) {
        let fetchRequest: NSFetchRequest<PaymentTransactionEntity> = PaymentTransactionEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)

        do {
            let entities = try context.fetch(fetchRequest)
            entities.forEach { context.delete($0) }
            saveContext()
        } catch {
            print("❌ Failed to delete transaction: \(error)")
        }
    }

    private func clearPersistedTransactions() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = PaymentTransactionEntity.fetchRequest()
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

        do {
            try context.execute(deleteRequest)
            saveContext()
        } catch {
            print("❌ Failed to clear transactions: \(error)")
        }
    }

    private func saveContext() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
    }

    private func mapEntityToTransaction(_ entity: PaymentTransactionEntity) -> PaymentTransaction? {
        guard let id = entity.id,
              let typeString = entity.type,
              let type = TransactionType(rawValue: typeString),
              let providerString = entity.provider,
              let provider = PaymentProvider(rawValue: providerString),
              let statusString = entity.status,
              let status = TransactionStatus.Status(rawValue: statusString),
              let cryptocurrency = entity.cryptocurrency,
              let fiatCurrency = entity.fiatCurrency,
              let fiatAmount = entity.fiatAmount as Decimal?,
              let fee = entity.fee as Decimal?,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt else {
            return nil
        }

        var metadata: [String: String]?
        if let metadataData = entity.metadata {
            metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: String]
        }

        return PaymentTransaction(
            id: id,
            type: type,
            provider: provider,
            status: status,
            cryptocurrency: cryptocurrency,
            cryptoAmount: entity.cryptoAmount as Decimal?,
            fiatCurrency: fiatCurrency,
            fiatAmount: fiatAmount,
            fee: fee,
            walletAddress: entity.walletAddress,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: entity.completedAt,
            failureReason: entity.failureReason,
            metadata: metadata
        )
    }

    private func getTransactionsForPeriod(_ period: StatisticsPeriod) -> [PaymentTransaction] {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .all:
            return transactions
        case .today:
            let startOfDay = calendar.startOfDay(for: now)
            return transactions.filter { $0.createdAt >= startOfDay }
        case .week:
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
            return transactions.filter { $0.createdAt >= weekAgo }
        case .month:
            let monthAgo = calendar.date(byAdding: .month, value: -1, to: now)!
            return transactions.filter { $0.createdAt >= monthAgo }
        case .year:
            let yearAgo = calendar.date(byAdding: .year, value: -1, to: now)!
            return transactions.filter { $0.createdAt >= yearAgo }
        }
    }

    private func exportAsCSV() throws -> Data {
        var csv = "ID,Type,Provider,Status,Cryptocurrency,Crypto Amount,Fiat Currency,Fiat Amount,Fee,Created At,Completed At\n"

        for transaction in transactions {
            let row = [
                transaction.id,
                transaction.type.rawValue,
                transaction.provider.rawValue,
                transaction.status.rawValue,
                transaction.cryptocurrency,
                "\(transaction.cryptoAmount ?? 0)",
                transaction.fiatCurrency,
                "\(transaction.fiatAmount)",
                "\(transaction.fee)",
                ISO8601DateFormatter().string(from: transaction.createdAt),
                transaction.completedAt.map { ISO8601DateFormatter().string(from: $0) } ?? ""
            ].joined(separator: ",")

            csv += row + "\n"
        }

        guard let data = csv.data(using: .utf8) else {
            throw PaymentError.unknownError
        }

        return data
    }

    private func exportAsJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        return try encoder.encode(transactions)
    }
}

// MARK: - Supporting Models

struct PaymentTransaction: Codable, Identifiable {
    let id: String
    let type: TransactionType
    let provider: PaymentProvider
    var status: TransactionStatus.Status
    let cryptocurrency: String
    var cryptoAmount: Decimal?
    let fiatCurrency: String
    let fiatAmount: Decimal
    let fee: Decimal
    let walletAddress: String?
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var failureReason: String?
    let metadata: [String: String]?
}

struct TransactionStatistics {
    let period: StatisticsPeriod
    let totalTransactions: Int
    let completedTransactions: Int
    let failedTransactions: Int
    let totalPurchaseAmount: Decimal
    let totalSaleAmount: Decimal
    let totalFees: Decimal
    let successRate: Double
}

enum StatisticsPeriod {
    case all
    case today
    case week
    case month
    case year
}

enum ExportFormat {
    case csv
    case json
}

// MARK: - Core Data Entity

@objc(PaymentTransactionEntity)
class PaymentTransactionEntity: NSManagedObject {
    @NSManaged var id: String?
    @NSManaged var type: String?
    @NSManaged var provider: String?
    @NSManaged var status: String?
    @NSManaged var cryptocurrency: String?
    @NSManaged var cryptoAmount: NSDecimalNumber?
    @NSManaged var fiatCurrency: String?
    @NSManaged var fiatAmount: NSDecimalNumber?
    @NSManaged var fee: NSDecimalNumber?
    @NSManaged var walletAddress: String?
    @NSManaged var createdAt: Date?
    @NSManaged var updatedAt: Date?
    @NSManaged var completedAt: Date?
    @NSManaged var failureReason: String?
    @NSManaged var metadata: Data?
}

extension PaymentTransactionEntity {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PaymentTransactionEntity> {
        return NSFetchRequest<PaymentTransactionEntity>(entityName: "PaymentTransactionEntity")
    }
}
