import Foundation

/// Bitcoin Transaction Builder
/// Handles proper transaction construction, serialization, and signing
public class BitcoinTransactionBuilder {

    // MARK: - Types

    public struct OutPoint: Equatable {
        let txHash: Data         // 32 bytes
        let index: UInt32        // 4 bytes

        public init(txHash: Data, index: UInt32) {
            self.txHash = txHash
            self.index = index
        }

        func serialize() -> Data {
            var data = Data()
            data.append(txHash.reversed()) // Bitcoin uses reversed byte order
            data.append(contentsOf: withUnsafeBytes(of: index.littleEndian) { Data($0) })
            return data
        }
    }

    public struct TxInput {
        let previousOutput: OutPoint
        let scriptSig: Data
        let sequence: UInt32
        let amount: UInt64?           // Required for SegWit signing
        let scriptPubKey: Data?       // Required for SegWit signing

        public init(previousOutput: OutPoint,
                   scriptSig: Data = Data(),
                   sequence: UInt32 = 0xFFFFFFFF,
                   amount: UInt64? = nil,
                   scriptPubKey: Data? = nil) {
            self.previousOutput = previousOutput
            self.scriptSig = scriptSig
            self.sequence = sequence
            self.amount = amount
            self.scriptPubKey = scriptPubKey
        }

        func serialize() -> Data {
            var data = Data()
            data.append(previousOutput.serialize())
            data.append(serializeVarInt(UInt64(scriptSig.count)))
            data.append(scriptSig)
            data.append(contentsOf: withUnsafeBytes(of: sequence.littleEndian) { Data($0) })
            return data
        }
    }

    public struct TxOutput {
        let amount: UInt64           // Satoshis
        let scriptPubKey: Data

        public init(amount: UInt64, scriptPubKey: Data) {
            self.amount = amount
            self.scriptPubKey = scriptPubKey
        }

        func serialize() -> Data {
            var data = Data()
            data.append(contentsOf: withUnsafeBytes(of: amount.littleEndian) { Data($0) })
            data.append(serializeVarInt(UInt64(scriptPubKey.count)))
            data.append(scriptPubKey)
            return data
        }
    }

    public enum SigHashType: UInt32 {
        case all = 0x01
        case none = 0x02
        case single = 0x03
        case anyoneCanPay = 0x80

        // Combined flags
        case allAnyoneCanPay = 0x81
        case noneAnyoneCanPay = 0x82
        case singleAnyoneCanPay = 0x83
    }

    public struct BitcoinTransaction {
        var version: Int32
        var inputs: [TxInput]
        var outputs: [TxOutput]
        var lockTime: UInt32
        var isSegWit: Bool

        public init(version: Int32 = 2,
                   inputs: [TxInput] = [],
                   outputs: [TxOutput] = [],
                   lockTime: UInt32 = 0,
                   isSegWit: Bool = true) {
            self.version = version
            self.inputs = inputs
            self.outputs = outputs
            self.lockTime = lockTime
            self.isSegWit = isSegWit
        }
    }

    // MARK: - Serialization

    /// Serialize transaction for broadcast (with witness data if SegWit)
    public static func serialize(_ tx: BitcoinTransaction, includeWitness: Bool = true) -> Data {
        var data = Data()

        // Version
        data.append(contentsOf: withUnsafeBytes(of: tx.version.littleEndian) { Data($0) })

        // SegWit marker and flag
        if tx.isSegWit && includeWitness {
            data.append(0x00) // Marker
            data.append(0x01) // Flag
        }

        // Input count
        data.append(serializeVarInt(UInt64(tx.inputs.count)))

        // Inputs
        for input in tx.inputs {
            data.append(input.serialize())
        }

        // Output count
        data.append(serializeVarInt(UInt64(tx.outputs.count)))

        // Outputs
        for output in tx.outputs {
            data.append(output.serialize())
        }

        // Witness data (only for SegWit transactions)
        if tx.isSegWit && includeWitness {
            for input in tx.inputs {
                // For now, empty witness stack (will be filled during signing)
                data.append(0x00) // Empty witness
            }
        }

        // Locktime
        data.append(contentsOf: withUnsafeBytes(of: tx.lockTime.littleEndian) { Data($0) })

        return data
    }

    /// Serialize transaction without witness data (for TXID calculation)
    public static func serializeWithoutWitness(_ tx: BitcoinTransaction) -> Data {
        return serialize(tx, includeWitness: false)
    }

    /// Calculate transaction ID (double SHA256 of non-witness serialization)
    public static func calculateTxId(_ tx: BitcoinTransaction) -> Data {
        let serialized = serializeWithoutWitness(tx)
        return serialized.doubleSHA256()
    }

    // MARK: - SIGHASH Computation

    /// Compute SIGHASH for legacy transactions (pre-SegWit)
    public static func computeLegacySigHash(
        tx: BitcoinTransaction,
        inputIndex: Int,
        scriptCode: Data,
        sigHashType: SigHashType
    ) throws -> Data {
        guard inputIndex < tx.inputs.count else {
            throw SigningError.invalidInputIndex
        }

        var modifiedTx = tx
        let hashType = sigHashType.rawValue
        let baseType = hashType & 0x1F
        let anyoneCanPay = (hashType & SigHashType.anyoneCanPay.rawValue) != 0

        // Clear all input scripts
        for i in 0..<modifiedTx.inputs.count {
            modifiedTx.inputs[i] = TxInput(
                previousOutput: modifiedTx.inputs[i].previousOutput,
                scriptSig: Data(),
                sequence: modifiedTx.inputs[i].sequence
            )
        }

        // Set script for signing input
        modifiedTx.inputs[inputIndex] = TxInput(
            previousOutput: modifiedTx.inputs[inputIndex].previousOutput,
            scriptSig: scriptCode,
            sequence: modifiedTx.inputs[inputIndex].sequence
        )

        // Handle SIGHASH types
        if baseType == SigHashType.none.rawValue {
            // Clear outputs
            modifiedTx.outputs = []
            // Set all input sequences to 0 except signing input
            for i in 0..<modifiedTx.inputs.count where i != inputIndex {
                modifiedTx.inputs[i] = TxInput(
                    previousOutput: modifiedTx.inputs[i].previousOutput,
                    scriptSig: modifiedTx.inputs[i].scriptSig,
                    sequence: 0
                )
            }
        } else if baseType == SigHashType.single.rawValue {
            guard inputIndex < modifiedTx.outputs.count else {
                throw SigningError.invalidSigHashSingle
            }
            // Keep only output at same index
            let output = modifiedTx.outputs[inputIndex]
            modifiedTx.outputs = Array(repeating: TxOutput(amount: 0xFFFFFFFFFFFFFFFF, scriptPubKey: Data()), count: inputIndex)
            modifiedTx.outputs.append(output)
            // Set all input sequences to 0 except signing input
            for i in 0..<modifiedTx.inputs.count where i != inputIndex {
                modifiedTx.inputs[i] = TxInput(
                    previousOutput: modifiedTx.inputs[i].previousOutput,
                    scriptSig: modifiedTx.inputs[i].scriptSig,
                    sequence: 0
                )
            }
        }

        // ANYONECANPAY: only include signing input
        if anyoneCanPay {
            let signingInput = modifiedTx.inputs[inputIndex]
            modifiedTx.inputs = [signingInput]
        }

        // Serialize and append SIGHASH type
        var data = serialize(modifiedTx, includeWitness: false)
        data.append(contentsOf: withUnsafeBytes(of: hashType.littleEndian) { Data($0) })

        // Double SHA256
        return data.doubleSHA256()
    }

    /// Compute SIGHASH for SegWit transactions (BIP 143)
    public static func computeSegWitSigHash(
        tx: BitcoinTransaction,
        inputIndex: Int,
        scriptCode: Data,
        amount: UInt64,
        sigHashType: SigHashType
    ) throws -> Data {
        guard inputIndex < tx.inputs.count else {
            throw SigningError.invalidInputIndex
        }

        let hashType = sigHashType.rawValue
        let baseType = hashType & 0x1F
        let anyoneCanPay = (hashType & SigHashType.anyoneCanPay.rawValue) != 0

        var preimage = Data()

        // 1. nVersion (4 bytes)
        preimage.append(contentsOf: withUnsafeBytes(of: tx.version.littleEndian) { Data($0) })

        // 2. hashPrevouts (32 bytes)
        if !anyoneCanPay {
            var prevouts = Data()
            for input in tx.inputs {
                prevouts.append(input.previousOutput.serialize())
            }
            preimage.append(prevouts.doubleSHA256())
        } else {
            preimage.append(Data(count: 32)) // Zero hash
        }

        // 3. hashSequence (32 bytes)
        if !anyoneCanPay && baseType != SigHashType.single.rawValue && baseType != SigHashType.none.rawValue {
            var sequences = Data()
            for input in tx.inputs {
                sequences.append(contentsOf: withUnsafeBytes(of: input.sequence.littleEndian) { Data($0) })
            }
            preimage.append(sequences.doubleSHA256())
        } else {
            preimage.append(Data(count: 32)) // Zero hash
        }

        // 4. outpoint (36 bytes)
        preimage.append(tx.inputs[inputIndex].previousOutput.serialize())

        // 5. scriptCode
        preimage.append(serializeVarInt(UInt64(scriptCode.count)))
        preimage.append(scriptCode)

        // 6. amount (8 bytes)
        preimage.append(contentsOf: withUnsafeBytes(of: amount.littleEndian) { Data($0) })

        // 7. nSequence (4 bytes)
        preimage.append(contentsOf: withUnsafeBytes(of: tx.inputs[inputIndex].sequence.littleEndian) { Data($0) })

        // 8. hashOutputs (32 bytes)
        if baseType != SigHashType.single.rawValue && baseType != SigHashType.none.rawValue {
            var outputs = Data()
            for output in tx.outputs {
                outputs.append(output.serialize())
            }
            preimage.append(outputs.doubleSHA256())
        } else if baseType == SigHashType.single.rawValue && inputIndex < tx.outputs.count {
            let output = tx.outputs[inputIndex].serialize()
            preimage.append(output.doubleSHA256())
        } else {
            preimage.append(Data(count: 32)) // Zero hash
        }

        // 9. nLocktime (4 bytes)
        preimage.append(contentsOf: withUnsafeBytes(of: tx.lockTime.littleEndian) { Data($0) })

        // 10. sighash type (4 bytes)
        preimage.append(contentsOf: withUnsafeBytes(of: hashType.littleEndian) { Data($0) })

        // Double SHA256
        return preimage.doubleSHA256()
    }

    // MARK: - Helper Functions

    public static func serializeVarInt(_ value: UInt64) -> Data {
        var data = Data()

        if value < 0xFD {
            data.append(UInt8(value))
        } else if value <= 0xFFFF {
            data.append(0xFD)
            data.append(contentsOf: withUnsafeBytes(of: UInt16(value).littleEndian) { Data($0) })
        } else if value <= 0xFFFFFFFF {
            data.append(0xFE)
            data.append(contentsOf: withUnsafeBytes(of: UInt32(value).littleEndian) { Data($0) })
        } else {
            data.append(0xFF)
            data.append(contentsOf: withUnsafeBytes(of: value.littleEndian) { Data($0) })
        }

        return data
    }

    public enum SigningError: Error {
        case invalidInputIndex
        case invalidSigHashSingle
        case missingInputAmount
        case missingScriptPubKey
    }
}

// MARK: - Script Building

extension BitcoinTransactionBuilder {

    /// Create P2PKH (Pay to Public Key Hash) scriptPubKey
    public static func createP2PKHScript(publicKeyHash: Data) -> Data {
        var script = Data()
        script.append(0x76) // OP_DUP
        script.append(0xA9) // OP_HASH160
        script.append(0x14) // Push 20 bytes
        script.append(publicKeyHash)
        script.append(0x88) // OP_EQUALVERIFY
        script.append(0xAC) // OP_CHECKSIG
        return script
    }

    /// Create P2WPKH (Pay to Witness Public Key Hash) scriptPubKey
    public static func createP2WPKHScript(publicKeyHash: Data) -> Data {
        var script = Data()
        script.append(0x00) // OP_0 (witness version)
        script.append(0x14) // Push 20 bytes
        script.append(publicKeyHash)
        return script
    }

    /// Create P2SH (Pay to Script Hash) scriptPubKey
    public static func createP2SHScript(scriptHash: Data) -> Data {
        var script = Data()
        script.append(0xA9) // OP_HASH160
        script.append(0x14) // Push 20 bytes
        script.append(scriptHash)
        script.append(0x87) // OP_EQUAL
        return script
    }

    /// Create P2WSH (Pay to Witness Script Hash) scriptPubKey
    public static func createP2WSHScript(scriptHash: Data) -> Data {
        var script = Data()
        script.append(0x00) // OP_0 (witness version)
        script.append(0x20) // Push 32 bytes
        script.append(scriptHash)
        return script
    }
}

// MARK: - Data Extensions

fileprivate extension Data {
    func doubleSHA256() -> Data {
        return sha256().sha256()
    }

    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    func ripemd160() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_RIPEMD160_DIGEST_LENGTH))
        self.withUnsafeBytes { ptr in
            _ = CC_RIPEMD160(ptr.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash)
    }

    func hash160() -> Data {
        return sha256().ripemd160()
    }
}

// CommonCrypto import
import CommonCrypto

// CommonCrypto constants (for iOS compatibility)
private let CC_SHA256_DIGEST_LENGTH = 32
private let CC_RIPEMD160_DIGEST_LENGTH = 20
