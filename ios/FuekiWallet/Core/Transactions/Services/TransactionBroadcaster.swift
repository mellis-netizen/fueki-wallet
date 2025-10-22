import Foundation

// MARK: - Broadcast Result
struct BroadcastResult {
    let txHash: String
    let status: BroadcastStatus
    let timestamp: Date
    let confirmations: Int

    init(txHash: String, status: BroadcastStatus = .pending, confirmations: Int = 0) {
        self.txHash = txHash
        self.status = status
        self.timestamp = Date()
        self.confirmations = confirmations
    }
}

// MARK: - Broadcast Status
enum BroadcastStatus: String, Codable {
    case pending
    case broadcasted
    case confirmed
    case failed

    var description: String {
        switch self {
        case .pending: return "Pending broadcast"
        case .broadcasted: return "Broadcasted to network"
        case .confirmed: return "Confirmed on blockchain"
        case .failed: return "Broadcast failed"
        }
    }
}

// MARK: - Transaction Broadcaster
class TransactionBroadcaster {
    static let shared = TransactionBroadcaster()

    private let rpcService: RPCService
    private let transactionMonitor: TransactionMonitor
    private var broadcastQueue: [String: any Transaction] = [:]
    private let queue = DispatchQueue(label: "com.fueki.broadcaster", attributes: .concurrent)

    init(rpcService: RPCService = .shared, transactionMonitor: TransactionMonitor = .shared) {
        self.rpcService = rpcService
        self.transactionMonitor = transactionMonitor
    }

    // MARK: - Broadcast Transaction
    func broadcast(_ transaction: any Transaction) async throws -> BroadcastResult {
        // Serialize transaction
        let serialized = try transaction.serialize()

        // Get transaction hash
        let txHash = try transaction.hash()

        // Add to queue
        queueTransaction(transaction, hash: txHash)

        // Broadcast based on chain type
        let result: BroadcastResult

        switch transaction.chain {
        case .ethereum:
            result = try await broadcastEthereumTransaction(serialized, hash: txHash)
        case .bitcoin:
            result = try await broadcastBitcoinTransaction(serialized, hash: txHash)
        case .solana:
            result = try await broadcastSolanaTransaction(serialized, hash: txHash)
        }

        // Start monitoring if successful
        if result.status == .broadcasted {
            await transactionMonitor.startMonitoring(
                txHash: result.txHash,
                chain: transaction.chain
            )
        }

        return result
    }

    // MARK: - Ethereum Broadcasting
    private func broadcastEthereumTransaction(_ data: Data, hash: String) async throws -> BroadcastResult {
        let hexData = "0x" + data.toHexString()

        do {
            let txHash = try await rpcService.sendEthereumTransaction(hexData)

            return BroadcastResult(
                txHash: txHash,
                status: .broadcasted
            )
        } catch {
            throw BroadcastError.broadcastFailed(error.localizedDescription)
        }
    }

    // MARK: - Bitcoin Broadcasting
    private func broadcastBitcoinTransaction(_ data: Data, hash: String) async throws -> BroadcastResult {
        let hexData = data.toHexString()

        do {
            let txHash = try await rpcService.sendBitcoinTransaction(hexData)

            return BroadcastResult(
                txHash: txHash,
                status: .broadcasted
            )
        } catch {
            throw BroadcastError.broadcastFailed(error.localizedDescription)
        }
    }

    // MARK: - Solana Broadcasting
    private func broadcastSolanaTransaction(_ data: Data, hash: String) async throws -> BroadcastResult {
        let base64Data = data.base64EncodedString()

        do {
            let signature = try await rpcService.sendSolanaTransaction(base64Data)

            return BroadcastResult(
                txHash: signature,
                status: .broadcasted
            )
        } catch {
            throw BroadcastError.broadcastFailed(error.localizedDescription)
        }
    }

    // MARK: - Batch Broadcasting
    func broadcastBatch(_ transactions: [any Transaction]) async throws -> [BroadcastResult] {
        return try await withThrowingTaskGroup(of: BroadcastResult.self) { group in
            var results: [BroadcastResult] = []

            for transaction in transactions {
                group.addTask {
                    try await self.broadcast(transaction)
                }
            }

            for try await result in group {
                results.append(result)
            }

            return results
        }
    }

    // MARK: - Transaction Status
    func getStatus(txHash: String, chain: BlockchainType) async throws -> BroadcastResult {
        switch chain {
        case .ethereum:
            return try await getEthereumTransactionStatus(txHash)
        case .bitcoin:
            return try await getBitcoinTransactionStatus(txHash)
        case .solana:
            return try await getSolanaTransactionStatus(txHash)
        }
    }

    private func getEthereumTransactionStatus(_ txHash: String) async throws -> BroadcastResult {
        let receipt = try await rpcService.getEthereumTransactionReceipt(txHash)

        guard let confirmations = receipt["confirmations"] as? Int else {
            return BroadcastResult(txHash: txHash, status: .pending)
        }

        let status: BroadcastStatus = confirmations > 0 ? .confirmed : .pending

        return BroadcastResult(
            txHash: txHash,
            status: status,
            confirmations: confirmations
        )
    }

    private func getBitcoinTransactionStatus(_ txHash: String) async throws -> BroadcastResult {
        let tx = try await rpcService.getBitcoinTransaction(txHash)

        let confirmations = (tx["confirmations"] as? Int) ?? 0
        let status: BroadcastStatus = confirmations > 0 ? .confirmed : .pending

        return BroadcastResult(
            txHash: txHash,
            status: status,
            confirmations: confirmations
        )
    }

    private func getSolanaTransactionStatus(_ signature: String) async throws -> BroadcastResult {
        let status = try await rpcService.getSolanaTransactionStatus(signature)

        let confirmations = (status["confirmations"] as? Int) ?? 0
        let broadcastStatus: BroadcastStatus = confirmations > 0 ? .confirmed : .pending

        return BroadcastResult(
            txHash: signature,
            status: broadcastStatus,
            confirmations: confirmations
        )
    }

    // MARK: - Queue Management
    private func queueTransaction(_ transaction: any Transaction, hash: String) {
        queue.async(flags: .barrier) {
            self.broadcastQueue[hash] = transaction
        }
    }

    func removeFromQueue(_ txHash: String) {
        queue.async(flags: .barrier) {
            self.broadcastQueue.removeValue(forKey: txHash)
        }
    }

    func getQueuedTransactions() -> [any Transaction] {
        return queue.sync {
            Array(broadcastQueue.values)
        }
    }

    // MARK: - Replace-By-Fee (RBF)
    func replaceTransaction(
        originalTxHash: String,
        newFee: Decimal,
        chain: BlockchainType
    ) async throws -> BroadcastResult {
        guard let originalTx = queue.sync(execute: { broadcastQueue[originalTxHash] }) else {
            throw BroadcastError.transactionNotFound
        }

        // Only Bitcoin and Ethereum support RBF
        switch chain {
        case .ethereum:
            guard var ethTx = originalTx as? EthereumTransaction else {
                throw BroadcastError.invalidTransactionType
            }

            // Increase max fee by at least 10%
            let newMaxFee = ethTx.maxFeePerGas * Decimal(1.1)
            guard newFee >= newMaxFee else {
                throw BroadcastError.insufficientFeeIncrease
            }

            ethTx = EthereumTransaction(
                from: ethTx.from,
                to: ethTx.to,
                amount: ethTx.amount,
                nonce: ethTx.nonce, // Keep same nonce
                maxFeePerGas: newFee,
                maxPriorityFeePerGas: ethTx.maxPriorityFeePerGas * Decimal(1.1),
                gasLimit: ethTx.gasLimit,
                data: ethTx.data
            )

            return try await broadcast(ethTx)

        case .bitcoin:
            throw BroadcastError.rbfNotImplemented

        case .solana:
            throw BroadcastError.rbfNotSupported
        }
    }

    // MARK: - Cancel Transaction
    func cancelTransaction(txHash: String, chain: BlockchainType) async throws -> BroadcastResult {
        guard let originalTx = queue.sync(execute: { broadcastQueue[txHash] }) else {
            throw BroadcastError.transactionNotFound
        }

        // Send 0 value transaction to self with same nonce (Ethereum only)
        if chain == .ethereum, let ethTx = originalTx as? EthereumTransaction {
            let cancelTx = EthereumTransaction(
                from: ethTx.from,
                to: ethTx.from, // Send to self
                amount: 0,
                nonce: ethTx.nonce, // Same nonce
                maxFeePerGas: ethTx.maxFeePerGas * Decimal(1.2),
                maxPriorityFeePerGas: ethTx.maxPriorityFeePerGas * Decimal(1.2),
                gasLimit: 21_000
            )

            return try await broadcast(cancelTx)
        }

        throw BroadcastError.cancellationNotSupported
    }
}

// MARK: - Transaction Monitor
class TransactionMonitor {
    static let shared = TransactionMonitor()

    private var monitoredTransactions: [String: MonitoringTask] = [:]
    private let queue = DispatchQueue(label: "com.fueki.monitor", attributes: .concurrent)
    private let broadcaster: TransactionBroadcaster?

    struct MonitoringTask {
        let txHash: String
        let chain: BlockchainType
        let startTime: Date
        var lastCheck: Date
        var confirmations: Int
    }

    init(broadcaster: TransactionBroadcaster? = nil) {
        self.broadcaster = broadcaster
    }

    func startMonitoring(txHash: String, chain: BlockchainType) async {
        let task = MonitoringTask(
            txHash: txHash,
            chain: chain,
            startTime: Date(),
            lastCheck: Date(),
            confirmations: 0
        )

        queue.async(flags: .barrier) {
            self.monitoredTransactions[txHash] = task
        }

        // Start monitoring loop
        await monitorLoop(txHash: txHash, chain: chain)
    }

    private func monitorLoop(txHash: String, chain: BlockchainType) async {
        let maxConfirmations = requiredConfirmations(for: chain)

        while true {
            do {
                // Wait before checking (exponential backoff)
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds

                guard let broadcaster = broadcaster else { continue }

                let result = try await broadcaster.getStatus(txHash: txHash, chain: chain)

                queue.async(flags: .barrier) {
                    if var task = self.monitoredTransactions[txHash] {
                        task.confirmations = result.confirmations
                        task.lastCheck = Date()
                        self.monitoredTransactions[txHash] = task
                    }
                }

                // Stop monitoring if confirmed
                if result.confirmations >= maxConfirmations {
                    stopMonitoring(txHash: txHash)
                    break
                }

            } catch {
                print("Error monitoring transaction \(txHash): \(error)")
            }
        }
    }

    func stopMonitoring(txHash: String) {
        queue.async(flags: .barrier) {
            self.monitoredTransactions.removeValue(forKey: txHash)
        }
    }

    func getMonitoringStatus(txHash: String) -> MonitoringTask? {
        return queue.sync {
            monitoredTransactions[txHash]
        }
    }

    private func requiredConfirmations(for chain: BlockchainType) -> Int {
        switch chain {
        case .ethereum: return 12
        case .bitcoin: return 6
        case .solana: return 32
        }
    }
}

// MARK: - RPC Service
class RPCService {
    static let shared = RPCService()

    // MARK: - Ethereum
    func sendEthereumTransaction(_ hexData: String) async throws -> String {
        // Mock implementation - replace with actual RPC call
        return "0x" + String(repeating: "0", count: 64)
    }

    func getEthereumTransactionReceipt(_ txHash: String) async throws -> [String: Any] {
        // Mock implementation
        return ["confirmations": 1]
    }

    // MARK: - Bitcoin
    func sendBitcoinTransaction(_ hexData: String) async throws -> String {
        // Mock implementation
        return String(repeating: "0", count: 64)
    }

    func getBitcoinTransaction(_ txHash: String) async throws -> [String: Any] {
        // Mock implementation
        return ["confirmations": 1]
    }

    // MARK: - Solana
    func sendSolanaTransaction(_ base64Data: String) async throws -> String {
        // Mock implementation
        return String(repeating: "0", count: 88)
    }

    func getSolanaTransactionStatus(_ signature: String) async throws -> [String: Any] {
        // Mock implementation
        return ["confirmations": 1]
    }
}

// MARK: - Broadcast Error
enum BroadcastError: LocalizedError {
    case broadcastFailed(String)
    case transactionNotFound
    case invalidTransactionType
    case insufficientFeeIncrease
    case rbfNotImplemented
    case rbfNotSupported
    case cancellationNotSupported

    var errorDescription: String? {
        switch self {
        case .broadcastFailed(let msg): return "Broadcast failed: \(msg)"
        case .transactionNotFound: return "Transaction not found in queue"
        case .invalidTransactionType: return "Invalid transaction type for operation"
        case .insufficientFeeIncrease: return "Fee increase too low (minimum 10%)"
        case .rbfNotImplemented: return "Replace-by-fee not yet implemented"
        case .rbfNotSupported: return "Replace-by-fee not supported on this chain"
        case .cancellationNotSupported: return "Transaction cancellation not supported"
        }
    }
}
