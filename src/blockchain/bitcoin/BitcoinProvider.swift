import Foundation

/// Enhanced Bitcoin provider with BlockchainProvider protocol conformance
public class BitcoinProvider: BlockchainProvider {

    // MARK: - Protocol Conformance

    public typealias Address = BitcoinIntegration.BitcoinAddress
    public typealias Transaction = BitcoinIntegration.BitcoinTransaction
    public typealias TransactionReceipt = BitcoinTransactionReceipt

    public var networkId: String {
        return integration.network == .mainnet ? "bitcoin_mainnet" : "bitcoin_testnet"
    }

    // MARK: - Properties

    private let integration: BitcoinIntegration
    private let rpcClient: RPCClient
    private let monitor: TransactionMonitor

    // MARK: - Initialization

    public init(network: BitcoinIntegration.Network = .mainnet, monitor: TransactionMonitor = .init()) {
        self.integration = BitcoinIntegration(network: network)
        self.monitor = monitor

        // Setup RPC client with multiple endpoints for redundancy
        let endpoints = network == .mainnet ? [
            URL(string: "https://blockstream.info/api")!,
            URL(string: "https://blockchain.info/api")!,
            URL(string: "https://mempool.space/api")!
        ] : [
            URL(string: "https://blockstream.info/testnet/api")!,
            URL(string: "https://mempool.space/testnet/api")!
        ]

        let config = RPCClient.Configuration(
            endpoints: endpoints,
            timeout: 30,
            maxRetries: 3,
            retryDelay: 2.0
        )
        self.rpcClient = RPCClient(configuration: config)

        // Register with BlockchainManager
        BlockchainManager.shared.registerProvider(self, for: networkId)
    }

    // MARK: - BlockchainProvider Protocol Implementation

    public func generateAddress(from publicKey: Data) throws -> BitcoinIntegration.BitcoinAddress {
        return try integration.generateAddress(from: publicKey, type: .segwit)
    }

    public func validateAddress(_ address: String) -> Bool {
        return integration.validateAddress(address)
    }

    public func getBalance(for address: String) async throws -> UInt64 {
        return try await integration.getBalance(for: address)
    }

    public func createTransaction(from: String, to: String, amount: UInt64) async throws -> BitcoinIntegration.BitcoinTransaction {
        let feeRate = try await estimateFee(priority: .medium)
        return try await integration.createSendTransaction(
            from: from,
            to: to,
            amount: amount,
            feeRate: feeRate
        )
    }

    public func broadcastTransaction(_ signedTransaction: Data) async throws -> String {
        let txHash = try await integration.broadcastTransaction(signedTransaction)

        // Start monitoring the transaction
        monitor.monitor(txHash: txHash, blockchain: networkId, requiredConfirmations: 6)

        return txHash
    }

    public func getTransactionReceipt(_ txHash: String) async throws -> BitcoinTransactionReceipt {
        // Fetch transaction details
        let tx = try await integration.getTransactionDetails(txHash)

        // Get confirmation count
        let confirmations = try await getConfirmationCount(txHash: txHash)

        return BitcoinTransactionReceipt(
            txHash: txHash,
            confirmations: UInt32(confirmations),
            transaction: tx
        )
    }

    public func fetchTransactionHistory(for address: String, limit: Int = 50) async throws -> [String] {
        return try await integration.fetchTransactionHistory(for: address, limit: limit)
    }

    public func estimateFee(priority: FeePriority) async throws -> UInt64 {
        let btcPriority: BitcoinIntegration.TransactionFee.Priority

        switch priority {
        case .low:
            btcPriority = .low
        case .medium:
            btcPriority = .medium
        case .high:
            btcPriority = .high
        case .custom(let rate):
            btcPriority = .custom(rate)
        }

        return try await integration.estimateFeeRate(priority: btcPriority)
    }

    // MARK: - Bitcoin-Specific Methods

    /// Create multi-recipient transaction
    public func createBatchTransaction(
        from: String,
        recipients: [(address: String, amount: UInt64)],
        feeRate: UInt64? = nil
    ) async throws -> BitcoinIntegration.BitcoinTransaction {
        let rate = feeRate ?? (try await estimateFee(priority: .medium))
        return try await integration.createMultiRecipientTransaction(
            from: from,
            recipients: recipients,
            feeRate: rate
        )
    }

    /// Get UTXOs for address
    public func getUTXOs(for address: String) async throws -> [BitcoinIntegration.UTXO] {
        return try await integration.fetchUTXOs(for: address)
    }

    /// Wait for transaction confirmation
    public func waitForConfirmation(
        txHash: String,
        requiredConfirmations: Int = 6,
        timeout: TimeInterval = 3600
    ) async throws -> BitcoinTransactionReceipt {
        let status = try await monitor.waitForConfirmation(txHash: txHash, timeout: timeout)

        switch status {
        case .confirmed(let confirmations):
            return try await getTransactionReceipt(txHash)
        case .failed(let reason):
            throw BlockchainError.transactionFailed(reason)
        default:
            throw BlockchainError.timeout
        }
    }

    // MARK: - Private Helpers

    private func getConfirmationCount(txHash: String) async throws -> Int {
        // This would query the blockchain for the current block height
        // and the block height of the transaction to calculate confirmations
        // Simplified implementation
        return 0
    }
}

/// Bitcoin transaction receipt
public struct BitcoinTransactionReceipt {
    public let txHash: String
    public let confirmations: UInt32
    public let transaction: BitcoinIntegration.BitcoinTransaction

    public var isConfirmed: Bool {
        return confirmations >= 6
    }

    public init(txHash: String, confirmations: UInt32, transaction: BitcoinIntegration.BitcoinTransaction) {
        self.txHash = txHash
        self.confirmations = confirmations
        self.transaction = transaction
    }
}
