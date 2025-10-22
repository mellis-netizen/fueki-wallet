import Foundation

// MARK: - Transaction Builder Protocol
protocol TransactionBuilderProtocol {
    associatedtype TransactionType: Transaction
    func build() async throws -> TransactionType
}

// MARK: - Ethereum Transaction Builder
class EthereumTransactionBuilder: TransactionBuilderProtocol {
    private let from: String
    private let to: String
    private let amount: Decimal
    private var data: Data?
    private var gasLimit: UInt64?
    private var maxFeePerGas: Decimal?
    private var maxPriorityFeePerGas: Decimal?

    private let nonceManager: NonceManager
    private let feeEstimator: FeeEstimator
    private let validator: TransactionValidator

    init(from: String, to: String, amount: Decimal,
         nonceManager: NonceManager = .shared,
         feeEstimator: FeeEstimator = .shared,
         validator: TransactionValidator = .shared) {
        self.from = from
        self.to = to
        self.amount = amount
        self.nonceManager = nonceManager
        self.feeEstimator = feeEstimator
        self.validator = validator
    }

    func withData(_ data: Data) -> Self {
        self.data = data
        return self
    }

    func withGasLimit(_ limit: UInt64) -> Self {
        self.gasLimit = limit
        return self
    }

    func withMaxFeePerGas(_ fee: Decimal) -> Self {
        self.maxFeePerGas = fee
        return self
    }

    func withMaxPriorityFeePerGas(_ fee: Decimal) -> Self {
        self.maxPriorityFeePerGas = fee
        return self
    }

    func build() async throws -> EthereumTransaction {
        // Validate addresses
        try validator.validateEthereumAddress(from)
        try validator.validateEthereumAddress(to)

        // Get nonce
        let nonce = try await nonceManager.getNonce(for: from, chain: .ethereum)

        // Estimate gas if not provided
        let gasLimit = try await self.gasLimit ?? estimateGasLimit()

        // Estimate fees if not provided
        let fees = try await estimateFees()

        // Create transaction
        let transaction = EthereumTransaction(
            from: from,
            to: to,
            amount: amount,
            nonce: nonce,
            maxFeePerGas: fees.maxFee,
            maxPriorityFeePerGas: fees.priorityFee,
            gasLimit: gasLimit,
            data: data
        )

        // Validate transaction
        try validator.validate(transaction)

        return transaction
    }

    private func estimateGasLimit() async throws -> UInt64 {
        if let data = data, !data.isEmpty {
            // Contract interaction - estimate based on data
            return 100_000 + UInt64(data.count * 68)
        } else {
            // Simple transfer
            return 21_000
        }
    }

    private func estimateFees() async throws -> (maxFee: Decimal, priorityFee: Decimal) {
        if let maxFee = maxFeePerGas, let priorityFee = maxPriorityFeePerGas {
            return (maxFee, priorityFee)
        }

        let estimate = try await feeEstimator.estimateEthereumFees()
        return (
            maxFeePerGas ?? estimate.maxFeePerGas,
            maxPriorityFeePerGas ?? estimate.maxPriorityFeePerGas
        )
    }
}

// MARK: - Bitcoin Transaction Builder
class BitcoinTransactionBuilder: TransactionBuilderProtocol {
    private let from: String
    private let to: String
    private let amount: Decimal
    private var feeRate: Decimal?
    private var utxos: [UTXOInput]?

    private let utxoManager: UTXOManager
    private let feeEstimator: FeeEstimator
    private let validator: TransactionValidator

    init(from: String, to: String, amount: Decimal,
         utxoManager: UTXOManager = .shared,
         feeEstimator: FeeEstimator = .shared,
         validator: TransactionValidator = .shared) {
        self.from = from
        self.to = to
        self.amount = amount
        self.utxoManager = utxoManager
        self.feeEstimator = feeEstimator
        self.validator = validator
    }

    func withFeeRate(_ rate: Decimal) -> Self {
        self.feeRate = rate
        return self
    }

    func withUTXOs(_ utxos: [UTXOInput]) -> Self {
        self.utxos = utxos
        return self
    }

    func build() async throws -> BitcoinTransaction {
        // Validate addresses
        try validator.validateBitcoinAddress(from)
        try validator.validateBitcoinAddress(to)

        // Get UTXOs if not provided
        let availableUTXOs = try await utxos ?? utxoManager.getUTXOs(for: from)

        // Get fee rate
        let feeRate = try await self.feeRate ?? feeEstimator.estimateBitcoinFeeRate()

        // Select UTXOs
        let selection = try selectUTXOs(from: availableUTXOs, amount: amount, feeRate: feeRate)

        // Create transaction
        let transaction = BitcoinTransaction(
            from: from,
            to: to,
            amount: amount,
            inputs: selection.inputs,
            fee: selection.fee
        )

        // Validate transaction
        try validator.validate(transaction)

        return transaction
    }

    private func selectUTXOs(from utxos: [UTXOInput], amount: Decimal, feeRate: Decimal) throws -> (inputs: [UTXOInput], fee: Decimal) {
        // Sort UTXOs by value (largest first) for efficient selection
        let sortedUTXOs = utxos.sorted { $0.value > $1.value }

        var selectedInputs: [UTXOInput] = []
        var totalValue = Decimal(0)

        // Calculate base transaction size (without inputs)
        // Version (4) + marker+flag (2) + input count (1) + output count (1) + locktime (4) = 12 bytes
        var txSize = 12

        // Output size: value (8) + scriptPubKey length (1) + scriptPubKey (22 for P2WPKH) = 31 bytes
        let outputSize = 31
        txSize += outputSize * 2 // Recipient + potential change output

        // Input size: txid (32) + vout (4) + scriptSig length (1) + sequence (4) = 41 bytes
        // + witness data (varies, ~107 bytes for P2WPKH)
        let inputSize = 41 + 107

        for utxo in sortedUTXOs {
            selectedInputs.append(utxo)
            totalValue += utxo.value

            // Calculate current transaction size
            let currentSize = txSize + (inputSize * selectedInputs.count)

            // Calculate fee (satoshis per byte * size / 100_000_000 to get BTC)
            let currentFee = (feeRate * Decimal(currentSize)) / Decimal(100_000_000)

            // Check if we have enough
            if totalValue >= amount + currentFee {
                return (selectedInputs, currentFee)
            }
        }

        throw TransactionError.insufficientFunds
    }
}

// MARK: - Solana Transaction Builder
class SolanaTransactionBuilder: TransactionBuilderProtocol {
    private let from: String
    private let to: String
    private let amount: Decimal

    private let blockchainService: BlockchainService
    private let validator: TransactionValidator

    init(from: String, to: String, amount: Decimal,
         blockchainService: BlockchainService = .shared,
         validator: TransactionValidator = .shared) {
        self.from = from
        self.to = to
        self.amount = amount
        self.blockchainService = blockchainService
        self.validator = validator
    }

    func build() async throws -> SolanaTransaction {
        // Validate addresses
        try validator.validateSolanaAddress(from)
        try validator.validateSolanaAddress(to)

        // Get recent blockhash
        let recentBlockhash = try await blockchainService.getRecentBlockhash()

        // Create transaction
        let transaction = SolanaTransaction(
            from: from,
            to: to,
            amount: amount,
            recentBlockhash: recentBlockhash
        )

        // Validate transaction
        try validator.validate(transaction)

        return transaction
    }
}

// MARK: - Nonce Manager
class NonceManager {
    static let shared = NonceManager()

    private var nonceCache: [String: UInt64] = [:]
    private let queue = DispatchQueue(label: "com.fueki.nonce", attributes: .concurrent)
    private let blockchainService: BlockchainService

    init(blockchainService: BlockchainService = .shared) {
        self.blockchainService = blockchainService
    }

    func getNonce(for address: String, chain: BlockchainType) async throws -> UInt64 {
        let cacheKey = "\(chain.rawValue):\(address)"

        return try await withCheckedThrowingContinuation { continuation in
            queue.async(flags: .barrier) {
                if let cachedNonce = self.nonceCache[cacheKey] {
                    // Return cached nonce and increment
                    let nonce = cachedNonce
                    self.nonceCache[cacheKey] = cachedNonce + 1
                    continuation.resume(returning: nonce)
                } else {
                    // Fetch from network
                    Task {
                        do {
                            let networkNonce = try await self.blockchainService.getTransactionCount(for: address)
                            self.queue.async(flags: .barrier) {
                                self.nonceCache[cacheKey] = networkNonce + 1
                            }
                            continuation.resume(returning: networkNonce)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    func resetNonce(for address: String, chain: BlockchainType) {
        let cacheKey = "\(chain.rawValue):\(address)"
        queue.async(flags: .barrier) {
            self.nonceCache.removeValue(forKey: cacheKey)
        }
    }

    func clearCache() {
        queue.async(flags: .barrier) {
            self.nonceCache.removeAll()
        }
    }
}

// MARK: - UTXO Manager
class UTXOManager {
    static let shared = UTXOManager()

    private var utxoCache: [String: [UTXOInput]] = [:]
    private let queue = DispatchQueue(label: "com.fueki.utxo", attributes: .concurrent)
    private let blockchainService: BlockchainService

    init(blockchainService: BlockchainService = .shared) {
        self.blockchainService = blockchainService
    }

    func getUTXOs(for address: String) async throws -> [UTXOInput] {
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let cachedUTXOs = self.utxoCache[address] {
                    continuation.resume(returning: cachedUTXOs)
                } else {
                    Task {
                        do {
                            let utxos = try await self.blockchainService.getUTXOs(for: address)
                            self.queue.async(flags: .barrier) {
                                self.utxoCache[address] = utxos
                            }
                            continuation.resume(returning: utxos)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }

    func markUTXOAsSpent(_ utxo: UTXOInput, for address: String) {
        queue.async(flags: .barrier) {
            if var utxos = self.utxoCache[address] {
                utxos.removeAll { $0.txid == utxo.txid && $0.vout == utxo.vout }
                self.utxoCache[address] = utxos
            }
        }
    }

    func clearCache(for address: String? = nil) {
        queue.async(flags: .barrier) {
            if let address = address {
                self.utxoCache.removeValue(forKey: address)
            } else {
                self.utxoCache.removeAll()
            }
        }
    }
}

// MARK: - Blockchain Service Protocol
protocol BlockchainServiceProtocol {
    func getTransactionCount(for address: String) async throws -> UInt64
    func getRecentBlockhash() async throws -> String
    func getUTXOs(for address: String) async throws -> [UTXOInput]
}

// MARK: - Blockchain Service
class BlockchainService: BlockchainServiceProtocol {
    static let shared = BlockchainService()

    func getTransactionCount(for address: String) async throws -> UInt64 {
        // Mock implementation - replace with actual RPC call
        return UInt64.random(in: 0...100)
    }

    func getRecentBlockhash() async throws -> String {
        // Mock implementation - replace with actual RPC call
        return String(repeating: "0", count: 32)
    }

    func getUTXOs(for address: String) async throws -> [UTXOInput] {
        // Mock implementation - replace with actual RPC call
        return []
    }
}
