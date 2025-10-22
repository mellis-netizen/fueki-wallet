//
//  TransactionMonitor.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Transaction Status Tracking
//

import Foundation
import Combine

// MARK: - Transaction Monitor
class TransactionMonitor {
    private let provider: BlockchainProviderProtocol
    private var monitoredTransactions: [String: MonitoredTransaction] = [:]
    private var subscriptions = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "io.fueki.transaction.monitor")

    private let statusUpdateSubject = PassthroughSubject<TransactionUpdate, Never>()

    var statusUpdatePublisher: AnyPublisher<TransactionUpdate, Never> {
        statusUpdateSubject.eraseToAnyPublisher()
    }

    // Polling configuration
    private let pollingInterval: TimeInterval = 5  // Check every 5 seconds
    private var pollingTimer: Timer?

    struct MonitoredTransaction {
        let hash: String
        let sentAt: Date
        var status: TransactionStatus
        var confirmations: UInt64
        var lastChecked: Date
    }

    struct TransactionUpdate {
        let hash: String
        let status: TransactionStatus
        let confirmations: UInt64?
        let timestamp: Date
    }

    init(provider: BlockchainProviderProtocol) {
        self.provider = provider
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Monitor Transaction
    func monitorTransaction(hash: String) {
        queue.sync {
            monitoredTransactions[hash] = MonitoredTransaction(
                hash: hash,
                sentAt: Date(),
                status: .pending,
                confirmations: 0,
                lastChecked: Date()
            )
        }

        // Start polling if not already started
        if pollingTimer == nil {
            startPolling()
        }

        // Immediate check
        Task {
            await checkTransaction(hash: hash)
        }
    }

    // MARK: - Stop Monitoring
    func stopMonitoring(hash: String) {
        queue.sync {
            monitoredTransactions.removeValue(forKey: hash)
        }

        // Stop polling if no more transactions
        if monitoredTransactions.isEmpty {
            stopMonitoring()
        }
    }

    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Get Transaction Status
    func getStatus(for hash: String) -> TransactionStatus? {
        return queue.sync {
            monitoredTransactions[hash]?.status
        }
    }

    func getConfirmations(for hash: String) -> UInt64? {
        return queue.sync {
            monitoredTransactions[hash]?.confirmations
        }
    }

    // MARK: - Wait for Confirmation
    func waitForConfirmation(
        hash: String,
        requiredConfirmations: UInt64 = 1,
        timeout: TimeInterval = 300
    ) async throws -> BlockchainTransaction {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            let status = try await provider.getTransactionStatus(hash: hash)

            if status == .finalized {
                return try await provider.getTransaction(hash: hash)
            }

            if status == .failed || status == .dropped {
                throw BlockchainError.transactionFailed("Transaction \(status.rawValue)")
            }

            // Check confirmations for chains that support it
            if status == .confirmed {
                let tx = try await provider.getTransaction(hash: hash)

                if let confirmations = tx.confirmations,
                   confirmations >= requiredConfirmations {
                    return tx
                }
            }

            // Wait before next check
            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }

        throw BlockchainError.timeout
    }

    // MARK: - Private Methods
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(
            withTimeInterval: pollingInterval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.pollAllTransactions()
            }
        }

        pollingTimer?.tolerance = pollingInterval * 0.1
    }

    private func pollAllTransactions() async {
        let hashes = queue.sync {
            Array(monitoredTransactions.keys)
        }

        await withTaskGroup(of: Void.self) { group in
            for hash in hashes {
                group.addTask {
                    await self.checkTransaction(hash: hash)
                }
            }
        }
    }

    private func checkTransaction(hash: String) async {
        do {
            let status = try await provider.getTransactionStatus(hash: hash)
            let tx = try await provider.getTransaction(hash: hash)

            queue.sync {
                guard var monitored = monitoredTransactions[hash] else { return }

                monitored.status = status
                monitored.confirmations = tx.confirmations ?? 0
                monitored.lastChecked = Date()

                monitoredTransactions[hash] = monitored
            }

            // Emit status update
            statusUpdateSubject.send(TransactionUpdate(
                hash: hash,
                status: status,
                confirmations: tx.confirmations,
                timestamp: Date()
            ))

            // Stop monitoring if complete
            if status.isComplete {
                stopMonitoring(hash: hash)
            }

        } catch {
            print("Error checking transaction \(hash): \(error)")
        }
    }
}

// MARK: - Transaction History Manager
class TransactionHistoryManager {
    private let provider: BlockchainProviderProtocol
    private var cachedHistory: [String: CachedHistory] = [:]
    private let queue = DispatchQueue(label: "io.fueki.transaction.history")
    private let cacheDuration: TimeInterval = 60  // Cache for 60 seconds

    struct CachedHistory {
        let transactions: [BlockchainTransaction]
        let timestamp: Date
    }

    init(provider: BlockchainProviderProtocol) {
        self.provider = provider
    }

    // MARK: - Get Transaction History
    func getHistory(
        for address: String,
        limit: Int = 50,
        useCache: Bool = true
    ) async throws -> [BlockchainTransaction] {
        if useCache, let cached = getCachedHistory(for: address) {
            return cached
        }

        let transactions = try await provider.getTransactionHistory(
            for: address,
            limit: limit
        )

        cacheHistory(transactions, for: address)

        return transactions
    }

    // MARK: - Get Paginated History
    func getPaginatedHistory(
        for address: String,
        page: Int,
        pageSize: Int
    ) async throws -> TransactionHistory {
        let allTransactions = try await getHistory(
            for: address,
            limit: (page + 1) * pageSize,
            useCache: false
        )

        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, allTransactions.count)

        let pageTransactions = Array(allTransactions[startIndex..<endIndex])

        return TransactionHistory(
            transactions: pageTransactions,
            total: allTransactions.count,
            page: page,
            pageSize: pageSize,
            hasMore: endIndex < allTransactions.count
        )
    }

    // MARK: - Filter Transactions
    func filterTransactions(
        _ transactions: [BlockchainTransaction],
        type: TransactionType? = nil,
        status: TransactionStatus? = nil,
        dateRange: DateInterval? = nil
    ) -> [BlockchainTransaction] {
        var filtered = transactions

        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }

        if let dateRange = dateRange {
            filtered = filtered.filter { dateRange.contains($0.timestamp) }
        }

        if let type = type {
            filtered = filtered.filter { transaction in
                switch type {
                case .send:
                    return transaction.value > 0
                case .receive:
                    return transaction.value > 0
                case .contractInteraction:
                    return transaction.data != nil
                case .tokenTransfer:
                    return transaction.tokenTransfers != nil
                }
            }
        }

        return filtered
    }

    // MARK: - Get Transaction Statistics
    func getStatistics(for address: String) async throws -> TransactionStatistics {
        let transactions = try await getHistory(for: address, useCache: true)

        let totalSent = transactions
            .filter { $0.from.lowercased() == address.lowercased() }
            .reduce(Decimal(0)) { $0 + $1.value }

        let totalReceived = transactions
            .filter { $0.to.lowercased() == address.lowercased() }
            .reduce(Decimal(0)) { $0 + $1.value }

        let totalFees = transactions
            .filter { $0.from.lowercased() == address.lowercased() }
            .reduce(Decimal(0)) { $0 + $1.fee }

        return TransactionStatistics(
            totalTransactions: transactions.count,
            totalSent: totalSent,
            totalReceived: totalReceived,
            totalFees: totalFees,
            firstTransaction: transactions.last,
            lastTransaction: transactions.first
        )
    }

    // MARK: - Cache Management
    private func getCachedHistory(for address: String) -> [BlockchainTransaction]? {
        return queue.sync {
            guard let cached = cachedHistory[address] else { return nil }

            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheDuration {
                return cached.transactions
            } else {
                cachedHistory.removeValue(forKey: address)
                return nil
            }
        }
    }

    private func cacheHistory(_ transactions: [BlockchainTransaction], for address: String) {
        queue.sync {
            cachedHistory[address] = CachedHistory(
                transactions: transactions,
                timestamp: Date()
            )
        }
    }

    func clearCache() {
        queue.sync {
            cachedHistory.removeAll()
        }
    }
}

// MARK: - Supporting Types
enum TransactionType {
    case send
    case receive
    case contractInteraction
    case tokenTransfer
}

struct TransactionStatistics {
    let totalTransactions: Int
    let totalSent: Decimal
    let totalReceived: Decimal
    let totalFees: Decimal
    let firstTransaction: BlockchainTransaction?
    let lastTransaction: BlockchainTransaction?

    var netBalance: Decimal {
        totalReceived - totalSent - totalFees
    }
}

// MARK: - Transaction Notifier
class TransactionNotifier {
    private let monitor: TransactionMonitor
    private var subscriptions = Set<AnyCancellable>()

    init(monitor: TransactionMonitor) {
        self.monitor = monitor
        setupNotifications()
    }

    // MARK: - Setup Notifications
    private func setupNotifications() {
        monitor.statusUpdatePublisher
            .sink { [weak self] update in
                self?.handleStatusUpdate(update)
            }
            .store(in: &subscriptions)
    }

    // MARK: - Handle Status Update
    private func handleStatusUpdate(_ update: TransactionMonitor.TransactionUpdate) {
        switch update.status {
        case .confirmed:
            sendNotification(
                title: "Transaction Confirmed",
                body: "Transaction \(update.hash.prefix(10))... has been confirmed"
            )

        case .finalized:
            sendNotification(
                title: "Transaction Finalized",
                body: "Transaction \(update.hash.prefix(10))... has been finalized"
            )

        case .failed:
            sendNotification(
                title: "Transaction Failed",
                body: "Transaction \(update.hash.prefix(10))... has failed"
            )

        default:
            break
        }
    }

    // MARK: - Send Notification
    private func sendNotification(title: String, body: String) {
        #if os(iOS)
        // iOS notification implementation
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
        #endif
    }
}
