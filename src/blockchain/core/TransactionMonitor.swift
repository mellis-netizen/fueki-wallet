import Foundation
import Combine

/// Transaction monitoring and confirmation tracking
public class TransactionMonitor {

    // MARK: - Types

    public enum TransactionStatus {
        case pending
        case confirming(confirmations: Int)
        case confirmed(confirmations: Int)
        case failed(reason: String)
        case dropped

        public var isFinalized: Bool {
            switch self {
            case .confirmed, .failed, .dropped:
                return true
            default:
                return false
            }
        }
    }

    public struct MonitoredTransaction {
        public let txHash: String
        public let blockchain: String
        public var status: TransactionStatus
        public let createdAt: Date
        public var lastChecked: Date
        public let requiredConfirmations: Int

        public init(txHash: String, blockchain: String, requiredConfirmations: Int = 6) {
            self.txHash = txHash
            self.blockchain = blockchain
            self.status = .pending
            self.createdAt = Date()
            self.lastChecked = Date()
            self.requiredConfirmations = requiredConfirmations
        }
    }

    // MARK: - Properties

    private var monitoredTransactions: [String: MonitoredTransaction] = [:]
    private let queue = DispatchQueue(label: "io.fueki.transaction.monitor", attributes: .concurrent)
    private var monitoringTask: Task<Void, Never>?

    // Publishers for status updates
    private let statusSubject = PassthroughSubject<(String, TransactionStatus), Never>()
    public var statusPublisher: AnyPublisher<(String, TransactionStatus), Never> {
        statusSubject.eraseToAnyPublisher()
    }

    // Configuration
    public var checkInterval: TimeInterval = 10.0 // seconds
    public var maxMonitoringDuration: TimeInterval = 3600.0 // 1 hour

    // MARK: - Initialization

    public init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Public Methods

    /// Add transaction to monitoring
    public func monitor(txHash: String, blockchain: String, requiredConfirmations: Int = 6) {
        queue.async(flags: .barrier) {
            let transaction = MonitoredTransaction(
                txHash: txHash,
                blockchain: blockchain,
                requiredConfirmations: requiredConfirmations
            )
            self.monitoredTransactions[txHash] = transaction
        }
    }

    /// Remove transaction from monitoring
    public func stopMonitoring(txHash: String) {
        queue.async(flags: .barrier) {
            self.monitoredTransactions.removeValue(forKey: txHash)
        }
    }

    /// Get current status of transaction
    public func getStatus(txHash: String) -> TransactionStatus? {
        return queue.sync {
            monitoredTransactions[txHash]?.status
        }
    }

    /// Get all monitored transactions
    public func getAllMonitored() -> [MonitoredTransaction] {
        return queue.sync {
            Array(monitoredTransactions.values)
        }
    }

    /// Wait for transaction confirmation
    public func waitForConfirmation(
        txHash: String,
        timeout: TimeInterval = 300
    ) async throws -> TransactionStatus {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if let status = getStatus(txHash: txHash), status.isFinalized {
                return status
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        throw BlockchainError.timeout
    }

    // MARK: - Private Methods

    private func startMonitoring() {
        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkAllTransactions()

                try? await Task.sleep(
                    nanoseconds: UInt64((self?.checkInterval ?? 10) * 1_000_000_000)
                )
            }
        }
    }

    private func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func checkAllTransactions() async {
        let transactions = getAllMonitored()

        for var transaction in transactions {
            // Skip if finalized
            guard !transaction.status.isFinalized else {
                continue
            }

            // Check if monitoring duration exceeded
            if Date().timeIntervalSince(transaction.createdAt) > maxMonitoringDuration {
                updateStatus(txHash: transaction.txHash, status: .dropped)
                continue
            }

            // Check transaction status based on blockchain
            await checkTransactionStatus(&transaction)
        }
    }

    private func checkTransactionStatus(_ transaction: inout MonitoredTransaction) async {
        do {
            // Get blockchain-specific status
            // This would integrate with the actual blockchain provider
            let confirmations = try await getConfirmations(
                txHash: transaction.txHash,
                blockchain: transaction.blockchain
            )

            let newStatus: TransactionStatus
            if confirmations >= transaction.requiredConfirmations {
                newStatus = .confirmed(confirmations: confirmations)
            } else if confirmations > 0 {
                newStatus = .confirming(confirmations: confirmations)
            } else {
                newStatus = .pending
            }

            updateStatus(txHash: transaction.txHash, status: newStatus)

        } catch {
            // Handle errors - could be network issues or transaction failure
            if case BlockchainError.transactionNotFound = error {
                // Transaction might have been dropped or is in mempool
                let elapsed = Date().timeIntervalSince(transaction.createdAt)
                if elapsed > 600 { // 10 minutes
                    updateStatus(txHash: transaction.txHash, status: .dropped)
                }
            }
        }
    }

    private func updateStatus(txHash: String, status: TransactionStatus) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }

            self.monitoredTransactions[txHash]?.status = status
            self.monitoredTransactions[txHash]?.lastChecked = Date()

            // Notify subscribers
            self.statusSubject.send((txHash, status))

            // Remove if finalized
            if status.isFinalized {
                // Keep for a short while for final status retrieval
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
                    self?.queue.async(flags: .barrier) {
                        self?.monitoredTransactions.removeValue(forKey: txHash)
                    }
                }
            }
        }
    }

    private func getConfirmations(txHash: String, blockchain: String) async throws -> Int {
        // This would integrate with BlockchainManager to get the appropriate provider
        // For now, return a placeholder

        // Example integration:
        // let manager = BlockchainManager.shared
        // if let provider = manager.getProvider(for: blockchain) {
        //     let receipt = try await provider.getTransactionReceipt(txHash)
        //     return calculateConfirmations(receipt)
        // }

        throw BlockchainError.unsupportedOperation
    }
}

// MARK: - Transaction Cache

/// Cache for transaction data to reduce network calls
public class TransactionCache {

    private struct CachedTransaction {
        let data: Data
        let timestamp: Date
    }

    private var cache: [String: CachedTransaction] = [:]
    private let queue = DispatchQueue(label: "io.fueki.transaction.cache", attributes: .concurrent)
    private let maxAge: TimeInterval = 300 // 5 minutes

    public func store(_ data: Data, for txHash: String) {
        queue.async(flags: .barrier) {
            self.cache[txHash] = CachedTransaction(data: data, timestamp: Date())
        }
    }

    public func retrieve(txHash: String) -> Data? {
        return queue.sync {
            guard let cached = cache[txHash] else { return nil }

            // Check if expired
            if Date().timeIntervalSince(cached.timestamp) > maxAge {
                return nil
            }

            return cached.data
        }
    }

    public func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }

    public func cleanup() {
        queue.async(flags: .barrier) {
            let now = Date()
            self.cache = self.cache.filter { _, value in
                now.timeIntervalSince(value.timestamp) <= self.maxAge
            }
        }
    }
}
