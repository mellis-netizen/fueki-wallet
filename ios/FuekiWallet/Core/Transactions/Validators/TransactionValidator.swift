import Foundation

// MARK: - Transaction Validator
class TransactionValidator {
    static let shared = TransactionValidator()

    private let balanceChecker: BalanceChecker

    init(balanceChecker: BalanceChecker = .shared) {
        self.balanceChecker = balanceChecker
    }

    // MARK: - Generic Validation
    func validate(_ transaction: any Transaction) throws {
        // Common validations
        try validateAmount(transaction.amount)
        try validateFee(transaction.fee)

        // Chain-specific validations
        switch transaction.chain {
        case .ethereum:
            if let ethTx = transaction as? EthereumTransaction {
                try validate(ethTx)
            }
        case .bitcoin:
            if let btcTx = transaction as? BitcoinTransaction {
                try validate(btcTx)
            }
        case .solana:
            if let solTx = transaction as? SolanaTransaction {
                try validate(solTx)
            }
        }
    }

    // MARK: - Ethereum Validation
    func validate(_ transaction: EthereumTransaction) throws {
        // Validate addresses
        try validateEthereumAddress(transaction.from)
        try validateEthereumAddress(transaction.to)

        // Validate nonce
        try validateNonce(transaction.nonce)

        // Validate gas parameters
        try validateGasLimit(transaction.gasLimit)
        try validateFeePerGas(transaction.maxFeePerGas)
        try validateFeePerGas(transaction.maxPriorityFeePerGas)

        // Validate EIP-1559 constraints
        guard transaction.maxPriorityFeePerGas <= transaction.maxFeePerGas else {
            throw ValidationError.invalidGasPrice("Priority fee cannot exceed max fee")
        }

        // Validate chain ID
        guard transaction.chainId > 0 else {
            throw ValidationError.invalidChainId
        }

        // Validate total cost
        let totalCost = transaction.amount + transaction.fee
        try validateTotalCost(totalCost, for: transaction.from, chain: .ethereum)

        // Validate data if present
        if let data = transaction.data, !data.isEmpty {
            try validateContractData(data)
        }
    }

    // MARK: - Bitcoin Validation
    func validate(_ transaction: BitcoinTransaction) throws {
        // Validate addresses
        try validateBitcoinAddress(transaction.from)
        try validateBitcoinAddress(transaction.to)

        // Validate inputs
        guard !transaction.inputs.isEmpty else {
            throw ValidationError.noInputs
        }

        try transaction.inputs.forEach { try validateUTXO($0) }

        // Validate outputs
        guard !transaction.outputs.isEmpty else {
            throw ValidationError.noOutputs
        }

        try transaction.outputs.forEach { try validateOutput($0) }

        // Validate input/output balance
        let totalInput = transaction.inputs.reduce(Decimal(0)) { $0 + $1.value }
        let totalOutput = transaction.outputs.reduce(Decimal(0)) { $0 + $1.value }

        guard totalInput >= totalOutput else {
            throw ValidationError.insufficientInputs
        }

        let calculatedFee = totalInput - totalOutput

        // Validate fee is reasonable (not too high)
        guard calculatedFee <= totalInput * Decimal(0.1) else { // Max 10% fee
            throw ValidationError.excessiveFee
        }

        // Validate fee is sufficient (dust threshold)
        guard calculatedFee >= Decimal(0.00001000) else { // 1000 satoshis minimum
            throw ValidationError.insufficientFee
        }

        // Validate transaction size
        let txSize = try transaction.serialize().count
        guard txSize <= 100_000 else { // 100KB max
            throw ValidationError.transactionTooLarge
        }
    }

    // MARK: - Solana Validation
    func validate(_ transaction: SolanaTransaction) throws {
        // Validate addresses
        try validateSolanaAddress(transaction.from)
        try validateSolanaAddress(transaction.to)

        // Validate blockhash
        try validateBlockhash(transaction.recentBlockhash)

        // Validate instructions
        guard !transaction.instructions.isEmpty else {
            throw ValidationError.noInstructions
        }

        // Validate amount (minimum 1 lamport)
        guard transaction.amount >= Decimal(0.000000001) else {
            throw ValidationError.amountTooSmall
        }

        // Validate total cost
        let totalCost = transaction.amount + transaction.fee
        try validateTotalCost(totalCost, for: transaction.from, chain: .solana)

        // Validate transaction size (max 1232 bytes)
        let txSize = try transaction.serialize().count
        guard txSize <= 1232 else {
            throw ValidationError.transactionTooLarge
        }
    }

    // MARK: - Address Validation
    func validateEthereumAddress(_ address: String) throws {
        // Check length (0x + 40 hex chars)
        guard address.hasPrefix("0x"), address.count == 42 else {
            throw ValidationError.invalidAddress("Invalid Ethereum address format")
        }

        // Check hex characters
        let hexPart = String(address.dropFirst(2))
        guard hexPart.allSatisfy({ $0.isHexDigit }) else {
            throw ValidationError.invalidAddress("Invalid Ethereum address characters")
        }

        // Validate checksum if mixed case
        if hexPart.lowercased() != hexPart && hexPart.uppercased() != hexPart {
            try validateEthereumChecksum(address)
        }
    }

    func validateBitcoinAddress(_ address: String) throws {
        // Check minimum length
        guard address.count >= 26, address.count <= 62 else {
            throw ValidationError.invalidAddress("Invalid Bitcoin address length")
        }

        // Validate based on address type
        if address.hasPrefix("1") {
            // P2PKH (Legacy)
            try validateBase58Address(address)
        } else if address.hasPrefix("3") {
            // P2SH
            try validateBase58Address(address)
        } else if address.hasPrefix("bc1") {
            // Bech32 (SegWit)
            try validateBech32Address(address)
        } else {
            throw ValidationError.invalidAddress("Unknown Bitcoin address type")
        }
    }

    func validateSolanaAddress(_ address: String) throws {
        // Solana addresses are base58 encoded and 32-44 characters
        guard address.count >= 32, address.count <= 44 else {
            throw ValidationError.invalidAddress("Invalid Solana address length")
        }

        // Validate base58 encoding
        guard address.allSatisfy({ Self.base58Alphabet.contains($0) }) else {
            throw ValidationError.invalidAddress("Invalid Solana address characters")
        }

        // Decode and check length (should be 32 bytes)
        guard let decoded = address.base58Decode(), decoded.count == 32 else {
            throw ValidationError.invalidAddress("Invalid Solana address encoding")
        }
    }

    // MARK: - Amount Validation
    private func validateAmount(_ amount: Decimal) throws {
        guard amount > 0 else {
            throw ValidationError.invalidAmount("Amount must be greater than zero")
        }

        guard amount < Decimal(1_000_000_000) else { // 1 billion max
            throw ValidationError.invalidAmount("Amount exceeds maximum")
        }
    }

    private func validateFee(_ fee: Decimal) throws {
        guard fee >= 0 else {
            throw ValidationError.invalidFee("Fee cannot be negative")
        }

        guard fee < Decimal(100) else { // 100 units max fee
            throw ValidationError.invalidFee("Fee exceeds maximum")
        }
    }

    // MARK: - Ethereum-specific Validation
    private func validateNonce(_ nonce: UInt64) throws {
        guard nonce < UInt64.max - 1000 else {
            throw ValidationError.invalidNonce
        }
    }

    private func validateGasLimit(_ gasLimit: UInt64) throws {
        guard gasLimit >= 21_000 else {
            throw ValidationError.invalidGasLimit("Gas limit too low")
        }

        guard gasLimit <= 30_000_000 else { // Block gas limit
            throw ValidationError.invalidGasLimit("Gas limit too high")
        }
    }

    private func validateFeePerGas(_ fee: Decimal) throws {
        guard fee > 0 else {
            throw ValidationError.invalidGasPrice("Fee per gas must be positive")
        }

        guard fee <= Decimal(10_000) else { // 10,000 Gwei max
            throw ValidationError.invalidGasPrice("Fee per gas too high")
        }
    }

    private func validateContractData(_ data: Data) throws {
        // Validate data size (max 128 KB)
        guard data.count <= 131_072 else {
            throw ValidationError.contractDataTooLarge
        }
    }

    // MARK: - Bitcoin-specific Validation
    private func validateUTXO(_ utxo: UTXOInput) throws {
        // Validate txid
        guard utxo.txid.count == 64, utxo.txid.allSatisfy({ $0.isHexDigit }) else {
            throw ValidationError.invalidTxHash
        }

        // Validate value
        guard utxo.value > 0 else {
            throw ValidationError.invalidAmount("UTXO value must be positive")
        }

        // Validate dust threshold (546 satoshis for SegWit)
        guard utxo.value >= Decimal(0.00000546) else {
            throw ValidationError.dustOutput
        }
    }

    private func validateOutput(_ output: TransactionOutput) throws {
        // Validate value
        guard output.value > 0 else {
            throw ValidationError.invalidAmount("Output value must be positive")
        }

        // Validate dust threshold
        guard output.value >= Decimal(0.00000546) else {
            throw ValidationError.dustOutput
        }

        // Validate scriptPubKey
        guard !output.scriptPubKey.isEmpty else {
            throw ValidationError.invalidScript
        }
    }

    // MARK: - Solana-specific Validation
    private func validateBlockhash(_ blockhash: String) throws {
        guard blockhash.count == 44 else {
            throw ValidationError.invalidBlockhash
        }

        guard blockhash.allSatisfy({ Self.base58Alphabet.contains($0) }) else {
            throw ValidationError.invalidBlockhash
        }
    }

    // MARK: - Balance Validation
    private func validateTotalCost(_ cost: Decimal, for address: String, chain: BlockchainType) throws {
        let balance = try balanceChecker.getBalance(for: address, chain: chain)

        guard balance >= cost else {
            throw ValidationError.insufficientBalance(required: cost, available: balance)
        }
    }

    // MARK: - Checksum Validation
    private func validateEthereumChecksum(_ address: String) throws {
        let addressHash = address.lowercased().dropFirst(2).data(using: .utf8)!.sha3(.keccak256)
        let addressChars = Array(address.dropFirst(2))

        for (i, char) in addressChars.enumerated() {
            let hashByte = addressHash[i / 2]
            let nibble = (i % 2 == 0) ? (hashByte >> 4) : (hashByte & 0x0f)

            if nibble >= 8 {
                guard char.isUppercase else {
                    throw ValidationError.invalidChecksum
                }
            } else {
                guard char.isLowercase else {
                    throw ValidationError.invalidChecksum
                }
            }
        }
    }

    private func validateBase58Address(_ address: String) throws {
        guard let decoded = address.base58CheckDecode() else {
            throw ValidationError.invalidAddress("Invalid base58 encoding")
        }

        guard decoded.count == 20 else {
            throw ValidationError.invalidAddress("Invalid address length")
        }
    }

    private func validateBech32Address(_ address: String) throws {
        // Simplified bech32 validation
        guard address.lowercased() == address || address.uppercased() == address else {
            throw ValidationError.invalidAddress("Mixed case not allowed in bech32")
        }

        guard address.contains("1") else {
            throw ValidationError.invalidAddress("Invalid bech32 separator")
        }
    }

    // MARK: - Constants
    private static let base58Alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
}

// MARK: - Validation Error
enum ValidationError: LocalizedError {
    case invalidAddress(String)
    case invalidAmount(String)
    case invalidFee(String)
    case invalidNonce
    case invalidGasLimit(String)
    case invalidGasPrice(String)
    case invalidChainId
    case invalidChecksum
    case invalidTxHash
    case invalidBlockhash
    case invalidScript
    case contractDataTooLarge
    case noInputs
    case noOutputs
    case noInstructions
    case insufficientInputs
    case insufficientBalance(required: Decimal, available: Decimal)
    case insufficientFee
    case excessiveFee
    case dustOutput
    case transactionTooLarge
    case amountTooSmall

    var errorDescription: String? {
        switch self {
        case .invalidAddress(let msg): return "Invalid address: \(msg)"
        case .invalidAmount(let msg): return "Invalid amount: \(msg)"
        case .invalidFee(let msg): return "Invalid fee: \(msg)"
        case .invalidNonce: return "Invalid nonce value"
        case .invalidGasLimit(let msg): return "Invalid gas limit: \(msg)"
        case .invalidGasPrice(let msg): return "Invalid gas price: \(msg)"
        case .invalidChainId: return "Invalid chain ID"
        case .invalidChecksum: return "Address checksum validation failed"
        case .invalidTxHash: return "Invalid transaction hash"
        case .invalidBlockhash: return "Invalid blockhash"
        case .invalidScript: return "Invalid script"
        case .contractDataTooLarge: return "Contract data exceeds maximum size"
        case .noInputs: return "Transaction must have at least one input"
        case .noOutputs: return "Transaction must have at least one output"
        case .noInstructions: return "Transaction must have at least one instruction"
        case .insufficientInputs: return "Input value less than output value"
        case .insufficientBalance(let required, let available):
            return "Insufficient balance. Required: \(required), Available: \(available)"
        case .insufficientFee: return "Transaction fee too low"
        case .excessiveFee: return "Transaction fee too high"
        case .dustOutput: return "Output value below dust threshold"
        case .transactionTooLarge: return "Transaction size exceeds maximum"
        case .amountTooSmall: return "Amount below minimum threshold"
        }
    }
}

// MARK: - Balance Checker
class BalanceChecker {
    static let shared = BalanceChecker()

    func getBalance(for address: String, chain: BlockchainType) throws -> Decimal {
        // Mock implementation - replace with actual balance check
        return Decimal(1.0)
    }
}
