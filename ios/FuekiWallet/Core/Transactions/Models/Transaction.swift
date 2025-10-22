import Foundation

// MARK: - Transaction Protocol
protocol Transaction {
    var id: String { get }
    var from: String { get }
    var to: String { get }
    var amount: Decimal { get }
    var fee: Decimal { get }
    var status: TransactionStatus { get set }
    var timestamp: Date { get }
    var chain: BlockchainType { get }

    func serialize() throws -> Data
    func hash() throws -> String
}

// MARK: - Transaction Status
enum TransactionStatus: String, Codable {
    case pending
    case broadcasting
    case confirmed
    case failed
    case dropped
}

// MARK: - Blockchain Type
enum BlockchainType: String, Codable {
    case ethereum
    case bitcoin
    case solana

    var chainId: Int? {
        switch self {
        case .ethereum: return 1 // Mainnet
        case .bitcoin, .solana: return nil
        }
    }
}

// MARK: - Ethereum Transaction (EIP-1559)
struct EthereumTransaction: Transaction, Codable {
    let id: String
    let from: String
    let to: String
    let amount: Decimal
    var fee: Decimal
    var status: TransactionStatus
    let timestamp: Date
    let chain: BlockchainType = .ethereum

    // EIP-1559 specific fields
    let nonce: UInt64
    let maxFeePerGas: Decimal
    let maxPriorityFeePerGas: Decimal
    let gasLimit: UInt64
    let data: Data?
    let chainId: Int

    // Signature components
    var v: UInt64?
    var r: Data?
    var s: Data?

    init(from: String, to: String, amount: Decimal, nonce: UInt64,
         maxFeePerGas: Decimal, maxPriorityFeePerGas: Decimal,
         gasLimit: UInt64, data: Data? = nil, chainId: Int = 1) {
        self.id = UUID().uuidString
        self.from = from
        self.to = to
        self.amount = amount
        self.nonce = nonce
        self.maxFeePerGas = maxFeePerGas
        self.maxPriorityFeePerGas = maxPriorityFeePerGas
        self.gasLimit = gasLimit
        self.data = data
        self.chainId = chainId
        self.timestamp = Date()
        self.status = .pending

        // Calculate fee
        let maxFee = maxFeePerGas * Decimal(gasLimit)
        self.fee = maxFee / Decimal(1_000_000_000_000_000_000) // Convert from wei
    }

    func serialize() throws -> Data {
        // EIP-1559 transaction encoding
        var rlpItems: [Any] = [
            chainId,
            nonce,
            maxPriorityFeePerGas.asWei(),
            maxFeePerGas.asWei(),
            gasLimit,
            to.hexToData(),
            amount.asWei(),
            data ?? Data()
        ]

        if let v = v, let r = r, let s = s {
            rlpItems.append(contentsOf: [v, r, s])
        }

        let rlpEncoded = try RLPEncoder.encode(rlpItems)

        // Add transaction type prefix (0x02 for EIP-1559)
        var result = Data([0x02])
        result.append(rlpEncoded)

        return result
    }

    func hash() throws -> String {
        let serialized = try serialize()
        return serialized.sha3(.keccak256).toHexString()
    }
}

// MARK: - Bitcoin Transaction (SegWit)
struct BitcoinTransaction: Transaction, Codable {
    let id: String
    let from: String
    let to: String
    let amount: Decimal
    var fee: Decimal
    var status: TransactionStatus
    let timestamp: Date
    let chain: BlockchainType = .bitcoin

    // Bitcoin specific fields
    let inputs: [UTXOInput]
    let outputs: [TransactionOutput]
    let version: UInt32
    let locktime: UInt32
    let isSegWit: Bool

    // Witness data for SegWit
    var witnesses: [[Data]]?

    init(from: String, to: String, amount: Decimal, inputs: [UTXOInput],
         fee: Decimal, version: UInt32 = 2, locktime: UInt32 = 0, isSegWit: Bool = true) {
        self.id = UUID().uuidString
        self.from = from
        self.to = to
        self.amount = amount
        self.fee = fee
        self.inputs = inputs
        self.version = version
        self.locktime = locktime
        self.isSegWit = isSegWit
        self.timestamp = Date()
        self.status = .pending

        // Create outputs
        let recipientOutput = TransactionOutput(
            value: amount,
            scriptPubKey: Self.createP2WPKHScript(address: to)
        )

        // Calculate change
        let totalInput = inputs.reduce(Decimal(0)) { $0 + $1.value }
        let change = totalInput - amount - fee

        var outputs = [recipientOutput]
        if change > Decimal(0.00001000) { // Dust threshold
            let changeOutput = TransactionOutput(
                value: change,
                scriptPubKey: Self.createP2WPKHScript(address: from)
            )
            outputs.append(changeOutput)
        }

        self.outputs = outputs
    }

    static func createP2WPKHScript(address: String) -> Data {
        // OP_0 <20-byte-pubkey-hash>
        guard let pubKeyHash = address.base58CheckDecode() else {
            return Data()
        }
        var script = Data([0x00, 0x14]) // OP_0 + 20 bytes length
        script.append(pubKeyHash)
        return script
    }

    func serialize() throws -> Data {
        var data = Data()

        // Version
        data.append(version.littleEndianData)

        if isSegWit {
            // Marker and flag for SegWit
            data.append(Data([0x00, 0x01]))
        }

        // Input count
        data.append(VarInt(inputs.count).encode())

        // Inputs
        for input in inputs {
            data.append(try input.serialize())
        }

        // Output count
        data.append(VarInt(outputs.count).encode())

        // Outputs
        for output in outputs {
            data.append(try output.serialize())
        }

        // Witnesses (for SegWit)
        if isSegWit, let witnesses = witnesses {
            for witness in witnesses {
                data.append(VarInt(witness.count).encode())
                for item in witness {
                    data.append(VarInt(item.count).encode())
                    data.append(item)
                }
            }
        }

        // Locktime
        data.append(locktime.littleEndianData)

        return data
    }

    func hash() throws -> String {
        let serialized = try serialize()
        return serialized.sha256().sha256().toHexString()
    }
}

// MARK: - UTXO Input
struct UTXOInput: Codable {
    let txid: String
    let vout: UInt32
    let value: Decimal
    let scriptPubKey: Data
    let sequence: UInt32
    var scriptSig: Data?

    init(txid: String, vout: UInt32, value: Decimal, scriptPubKey: Data, sequence: UInt32 = 0xfffffffd) {
        self.txid = txid
        self.vout = vout
        self.value = value
        self.scriptPubKey = scriptPubKey
        self.sequence = sequence
    }

    func serialize() throws -> Data {
        var data = Data()

        // Previous transaction hash (reversed)
        guard let txHash = txid.hexToData() else {
            throw TransactionError.invalidTxHash
        }
        data.append(Data(txHash.reversed()))

        // Output index
        data.append(vout.littleEndianData)

        // ScriptSig length and data
        let scriptSig = self.scriptSig ?? Data()
        data.append(VarInt(scriptSig.count).encode())
        data.append(scriptSig)

        // Sequence
        data.append(sequence.littleEndianData)

        return data
    }
}

// MARK: - Transaction Output
struct TransactionOutput: Codable {
    let value: Decimal
    let scriptPubKey: Data

    func serialize() throws -> Data {
        var data = Data()

        // Value in satoshis
        let satoshis = (value * Decimal(100_000_000)).uint64Value
        data.append(satoshis.littleEndianData)

        // ScriptPubKey length and data
        data.append(VarInt(scriptPubKey.count).encode())
        data.append(scriptPubKey)

        return data
    }
}

// MARK: - Solana Transaction
struct SolanaTransaction: Transaction, Codable {
    let id: String
    let from: String
    let to: String
    let amount: Decimal
    var fee: Decimal
    var status: TransactionStatus
    let timestamp: Date
    let chain: BlockchainType = .solana

    // Solana specific fields
    let recentBlockhash: String
    let instructions: [SolanaInstruction]
    var signatures: [Data]?

    init(from: String, to: String, amount: Decimal, recentBlockhash: String, fee: Decimal = 0.000005) {
        self.id = UUID().uuidString
        self.from = from
        self.to = to
        self.amount = amount
        self.fee = fee
        self.recentBlockhash = recentBlockhash
        self.timestamp = Date()
        self.status = .pending

        // Create transfer instruction
        let instruction = SolanaInstruction.createTransferInstruction(
            from: from,
            to: to,
            lamports: (amount * Decimal(1_000_000_000)).uint64Value
        )
        self.instructions = [instruction]
    }

    func serialize() throws -> Data {
        var data = Data()

        // Number of signatures
        let sigCount = signatures?.count ?? 0
        data.append(VarInt(sigCount).encode())

        // Signatures
        if let signatures = signatures {
            for signature in signatures {
                data.append(signature)
            }
        }

        // Message header
        data.append(try serializeMessage())

        return data
    }

    private func serializeMessage() throws -> Data {
        var data = Data()

        // Message header (3 bytes)
        let numRequiredSignatures: UInt8 = 1
        let numReadonlySignedAccounts: UInt8 = 0
        let numReadonlyUnsignedAccounts: UInt8 = 0

        data.append(numRequiredSignatures)
        data.append(numReadonlySignedAccounts)
        data.append(numReadonlyUnsignedAccounts)

        // Account addresses
        let accounts = [from, to, SolanaInstruction.systemProgramId]
        data.append(VarInt(accounts.count).encode())

        for account in accounts {
            guard let accountData = account.base58Decode() else {
                throw TransactionError.invalidAddress
            }
            data.append(accountData)
        }

        // Recent blockhash
        guard let blockhashData = recentBlockhash.base58Decode() else {
            throw TransactionError.invalidBlockhash
        }
        data.append(blockhashData)

        // Instructions
        data.append(VarInt(instructions.count).encode())
        for instruction in instructions {
            data.append(try instruction.serialize())
        }

        return data
    }

    func hash() throws -> String {
        let serialized = try serialize()
        return serialized.sha256().toHexString()
    }
}

// MARK: - Solana Instruction
struct SolanaInstruction: Codable {
    static let systemProgramId = "11111111111111111111111111111111"

    let programIdIndex: UInt8
    let accounts: [UInt8]
    let data: Data

    static func createTransferInstruction(from: String, to: String, lamports: UInt64) -> SolanaInstruction {
        // Transfer instruction data: [2, lamports (8 bytes)]
        var instructionData = Data([2]) // Transfer instruction type
        instructionData.append(lamports.littleEndianData)

        return SolanaInstruction(
            programIdIndex: 2, // System program
            accounts: [0, 1], // From and To account indices
            data: instructionData
        )
    }

    func serialize() throws -> Data {
        var data = Data()

        // Program ID index
        data.append(programIdIndex)

        // Account indices count and data
        data.append(VarInt(accounts.count).encode())
        data.append(Data(accounts))

        // Instruction data length and data
        data.append(VarInt(self.data.count).encode())
        data.append(self.data)

        return data
    }
}

// MARK: - Transaction Error
enum TransactionError: LocalizedError {
    case invalidTxHash
    case invalidAddress
    case invalidBlockhash
    case serializationFailed
    case insufficientFunds
    case invalidNonce
    case invalidSignature

    var errorDescription: String? {
        switch self {
        case .invalidTxHash: return "Invalid transaction hash"
        case .invalidAddress: return "Invalid address format"
        case .invalidBlockhash: return "Invalid blockhash"
        case .serializationFailed: return "Transaction serialization failed"
        case .insufficientFunds: return "Insufficient funds"
        case .invalidNonce: return "Invalid nonce"
        case .invalidSignature: return "Invalid signature"
        }
    }
}

// MARK: - Helper Extensions
extension Decimal {
    func asWei() -> Data {
        let wei = (self * Decimal(1_000_000_000_000_000_000)).uint64Value
        return wei.bigEndianData
    }

    var uint64Value: UInt64 {
        return NSDecimalNumber(decimal: self).uint64Value
    }
}

extension UInt32 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

extension UInt64 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt64>.size)
    }

    var bigEndianData: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt64>.size)
    }
}

// MARK: - VarInt
struct VarInt {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    func encode() -> Data {
        if value < 0xfd {
            return Data([UInt8(value)])
        } else if value <= 0xffff {
            var data = Data([0xfd])
            data.append(UInt16(value).littleEndianData)
            return data
        } else if value <= 0xffffffff {
            var data = Data([0xfe])
            data.append(UInt32(value).littleEndianData)
            return data
        } else {
            var data = Data([0xff])
            data.append(UInt64(value).littleEndianData)
            return data
        }
    }
}

extension UInt16 {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<UInt16>.size)
    }
}
