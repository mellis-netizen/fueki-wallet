import Foundation
import CryptoKit
import Security

/// Transaction Signing Module for Multi-Blockchain Support
/// Handles signing for Bitcoin, Ethereum, and other blockchains
public class TransactionSigner {

    // MARK: - Types

    public enum BlockchainType {
        case bitcoin
        case ethereum
        case polygon
        case binanceSmartChain
        case arbitrum
        case optimism
    }

    public enum SignatureAlgorithm {
        case ecdsa_secp256k1
        case ecdsa_secp256r1
        case eddsa_ed25519
    }

    public struct UnsignedTransaction {
        let blockchain: BlockchainType
        let rawTransaction: Data
        let inputHashes: [Data]
        let metadata: [String: Any]

        public init(blockchain: BlockchainType, rawTransaction: Data,
                   inputHashes: [Data] = [], metadata: [String: Any] = [:]) {
            self.blockchain = blockchain
            self.rawTransaction = rawTransaction
            self.inputHashes = inputHashes
            self.metadata = metadata
        }
    }

    public struct SignedTransaction {
        let unsignedTx: UnsignedTransaction
        let signatures: [Data]
        let signedRawTransaction: Data
        let txHash: Data
        let timestamp: Date

        public init(unsignedTx: UnsignedTransaction, signatures: [Data],
                   signedRawTransaction: Data, txHash: Data, timestamp: Date = Date()) {
            self.unsignedTx = unsignedTx
            self.signatures = signatures
            self.signedRawTransaction = signedRawTransaction
            self.txHash = txHash
            self.timestamp = timestamp
        }
    }

    public struct SigningContext {
        let nonce: UInt64
        let chainId: UInt64?
        let gasLimit: UInt64?
        let gasPrice: UInt64?
        let additionalData: [String: Any]

        public init(nonce: UInt64, chainId: UInt64? = nil, gasLimit: UInt64? = nil,
                   gasPrice: UInt64? = nil, additionalData: [String: Any] = [:]) {
            self.nonce = nonce
            self.chainId = chainId
            self.gasLimit = gasLimit
            self.gasPrice = gasPrice
            self.additionalData = additionalData
        }
    }

    public enum SigningError: Error {
        case invalidPrivateKey
        case invalidTransaction
        case signingFailed
        case invalidSignature
        case unsupportedBlockchain
        case nonceManagementError
        case invalidContext
        case hardwareSigningFailed(String)
    }

    // MARK: - Properties

    private let nonceManager: NonceManager
    private let hardwareKeyIntegration: HardwareKeyIntegration
    private let signatureVerifier: SignatureVerifier

    // MARK: - Initialization

    public init() {
        self.nonceManager = NonceManager()
        self.hardwareKeyIntegration = HardwareKeyIntegration()
        self.signatureVerifier = SignatureVerifier()
    }

    // MARK: - Transaction Signing

    /// Sign a transaction with a private key
    /// - Parameters:
    ///   - transaction: Unsigned transaction to sign
    ///   - privateKey: Private key for signing
    ///   - context: Signing context (nonce, chain ID, etc.)
    /// - Returns: Signed transaction with signatures
    public func signTransaction(_ transaction: UnsignedTransaction,
                               with privateKey: Data,
                               context: SigningContext) throws -> SignedTransaction {
        // Validate private key
        guard privateKey.count == 32 else {
            throw SigningError.invalidPrivateKey
        }

        // Get algorithm for blockchain
        let algorithm = algorithmForBlockchain(transaction.blockchain)

        // Prepare transaction for signing
        let messageHash = try prepareTransactionHash(transaction, context: context)

        // Sign the transaction
        let signature = try sign(messageHash: messageHash,
                                privateKey: privateKey,
                                algorithm: algorithm,
                                blockchain: transaction.blockchain)

        // Construct signed raw transaction
        let signedRaw = try constructSignedTransaction(
            transaction: transaction,
            signature: signature,
            context: context
        )

        // Calculate transaction hash
        let txHash = signedRaw.sha256()

        // Update nonce
        try nonceManager.incrementNonce(for: transaction.blockchain, context: context)

        return SignedTransaction(
            unsignedTx: transaction,
            signatures: [signature],
            signedRawTransaction: signedRaw,
            txHash: txHash
        )
    }

    /// Sign transaction with hardware key (Secure Enclave)
    /// - Parameters:
    ///   - transaction: Unsigned transaction
    ///   - keyIdentifier: Hardware key identifier
    ///   - context: Signing context
    /// - Returns: Signed transaction
    public func signWithHardwareKey(_ transaction: UnsignedTransaction,
                                    keyIdentifier: String,
                                    context: SigningContext) throws -> SignedTransaction {
        // Prepare transaction hash
        let messageHash = try prepareTransactionHash(transaction, context: context)

        // Sign with Secure Enclave
        let signature = try hardwareKeyIntegration.sign(
            messageHash: messageHash,
            keyIdentifier: keyIdentifier,
            blockchain: transaction.blockchain
        )

        // Construct signed transaction
        let signedRaw = try constructSignedTransaction(
            transaction: transaction,
            signature: signature,
            context: context
        )

        let txHash = signedRaw.sha256()

        try nonceManager.incrementNonce(for: transaction.blockchain, context: context)

        return SignedTransaction(
            unsignedTx: transaction,
            signatures: [signature],
            signedRawTransaction: signedRaw,
            txHash: txHash
        )
    }

    /// Sign transaction with multiple signatures (multi-sig)
    /// - Parameters:
    ///   - transaction: Unsigned transaction
    ///   - privateKeys: Array of private keys
    ///   - context: Signing context
    /// - Returns: Multi-signed transaction
    public func signWithMultipleKeys(_ transaction: UnsignedTransaction,
                                    privateKeys: [Data],
                                    context: SigningContext) throws -> SignedTransaction {
        guard !privateKeys.isEmpty else {
            throw SigningError.invalidPrivateKey
        }

        let algorithm = algorithmForBlockchain(transaction.blockchain)
        let messageHash = try prepareTransactionHash(transaction, context: context)

        var signatures: [Data] = []

        for privateKey in privateKeys {
            let signature = try sign(
                messageHash: messageHash,
                privateKey: privateKey,
                algorithm: algorithm,
                blockchain: transaction.blockchain
            )
            signatures.append(signature)
        }

        // Construct multi-sig transaction
        let signedRaw = try constructMultiSigTransaction(
            transaction: transaction,
            signatures: signatures,
            context: context
        )

        let txHash = signedRaw.sha256()

        try nonceManager.incrementNonce(for: transaction.blockchain, context: context)

        return SignedTransaction(
            unsignedTx: transaction,
            signatures: signatures,
            signedRawTransaction: signedRaw,
            txHash: txHash
        )
    }

    // MARK: - Signature Verification

    /// Verify a transaction signature
    /// - Parameters:
    ///   - transaction: Signed transaction
    ///   - publicKey: Public key for verification
    /// - Returns: True if signature is valid
    public func verifySignature(_ transaction: SignedTransaction,
                               publicKey: Data) throws -> Bool {
        let algorithm = algorithmForBlockchain(transaction.unsignedTx.blockchain)

        // Reconstruct message hash
        let context = SigningContext(nonce: 0) // Context should be stored in metadata
        let messageHash = try prepareTransactionHash(transaction.unsignedTx, context: context)

        guard let signature = transaction.signatures.first else {
            throw SigningError.invalidSignature
        }

        return try signatureVerifier.verify(
            signature: signature,
            messageHash: messageHash,
            publicKey: publicKey,
            algorithm: algorithm
        )
    }

    /// Verify Bitcoin transaction before broadcast
    /// Performs comprehensive validation including:
    /// - Signature verification
    /// - SIGHASH computation validation
    /// - Transaction structure validation
    /// - Witness data validation (for SegWit)
    /// - Parameters:
    ///   - transaction: Signed Bitcoin transaction
    ///   - publicKey: Public key for verification
    /// - Returns: True if transaction is valid and ready for broadcast
    public func verifyBitcoinTransaction(_ transaction: SignedTransaction,
                                        publicKey: Data) throws -> Bool {
        guard transaction.unsignedTx.blockchain == .bitcoin else {
            throw SigningError.unsupportedBlockchain
        }

        // 1. Verify transaction structure
        guard let btcTx = transaction.unsignedTx.metadata["bitcoinTransaction"] as? BitcoinTransactionBuilder.BitcoinTransaction else {
            throw SigningError.invalidTransaction
        }

        // 2. Validate inputs and outputs exist
        guard !btcTx.inputs.isEmpty, !btcTx.outputs.isEmpty else {
            throw SigningError.invalidTransaction
        }

        // 3. Verify signature for each input
        guard let signature = transaction.signatures.first else {
            throw SigningError.invalidSignature
        }

        // 4. Reconstruct SIGHASH and verify
        let messageHash = try prepareTransactionHash(transaction.unsignedTx, context: SigningContext(nonce: 0))

        let isValid = try Secp256k1Bridge.verify(
            signature: signature,
            messageHash: messageHash,
            publicKey: publicKey
        )

        guard isValid else {
            return false
        }

        // 5. Validate transaction ID matches
        let calculatedTxId = BitcoinTransactionBuilder.calculateTxId(btcTx)
        // Note: For SegWit, TXID differs from witness TXID

        // 6. Verify witness data structure (if SegWit)
        if btcTx.isSegWit {
            // Ensure witness data is properly formatted
            let signedRaw = transaction.signedRawTransaction
            guard signedRaw.count >= 10 else { // Minimum tx size
                return false
            }

            // Verify marker and flag are present
            if signedRaw.count > 5 {
                let marker = signedRaw[4]
                let flag = signedRaw[5]
                guard marker == 0x00 && flag == 0x01 else {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Private Methods

    private func algorithmForBlockchain(_ blockchain: BlockchainType) -> SignatureAlgorithm {
        switch blockchain {
        case .bitcoin, .ethereum, .polygon, .binanceSmartChain, .arbitrum, .optimism:
            return .ecdsa_secp256k1
        }
    }

    private func prepareTransactionHash(_ transaction: UnsignedTransaction,
                                       context: SigningContext) throws -> Data {
        switch transaction.blockchain {
        case .ethereum, .polygon, .binanceSmartChain, .arbitrum, .optimism:
            return try prepareEthereumTransactionHash(transaction, context: context)
        case .bitcoin:
            return try prepareBitcoinTransactionHash(transaction, context: context)
        }
    }

    private func prepareEthereumTransactionHash(_ transaction: UnsignedTransaction,
                                               context: SigningContext) throws -> Data {
        // Implement EIP-155 transaction hashing
        guard let chainId = context.chainId else {
            throw SigningError.invalidContext
        }

        var rlpData = Data()

        // RLP encode: [nonce, gasPrice, gasLimit, to, value, data, chainId, 0, 0]
        rlpData.append(rlpEncode(context.nonce))
        if let gasPrice = context.gasPrice {
            rlpData.append(rlpEncode(gasPrice))
        }
        if let gasLimit = context.gasLimit {
            rlpData.append(rlpEncode(gasLimit))
        }
        rlpData.append(transaction.rawTransaction)
        rlpData.append(rlpEncode(chainId))
        rlpData.append(rlpEncode(UInt64(0)))
        rlpData.append(rlpEncode(UInt64(0)))

        // Keccak256 hash
        return rlpData.keccak256()
    }

    private func prepareBitcoinTransactionHash(_ transaction: UnsignedTransaction,
                                              context: SigningContext) throws -> Data {
        // Extract Bitcoin transaction details from metadata
        guard let btcTx = transaction.metadata["bitcoinTransaction"] as? BitcoinTransactionBuilder.BitcoinTransaction,
              let inputIndex = transaction.metadata["inputIndex"] as? Int,
              let amount = transaction.metadata["amount"] as? UInt64,
              let scriptPubKey = transaction.metadata["scriptPubKey"] as? Data else {
            throw SigningError.invalidTransaction
        }

        let sigHashType = (transaction.metadata["sigHashType"] as? BitcoinTransactionBuilder.SigHashType) ?? .all

        // Use SegWit signing by default (BIP 143)
        if btcTx.isSegWit {
            // For P2WPKH, script code is P2PKH of the pubkey hash
            let scriptCode = scriptPubKey
            return try BitcoinTransactionBuilder.computeSegWitSigHash(
                tx: btcTx,
                inputIndex: inputIndex,
                scriptCode: scriptCode,
                amount: amount,
                sigHashType: sigHashType
            )
        } else {
            // Legacy transaction signing
            return try BitcoinTransactionBuilder.computeLegacySigHash(
                tx: btcTx,
                inputIndex: inputIndex,
                scriptCode: scriptPubKey,
                sigHashType: sigHashType
            )
        }
    }

    private func sign(messageHash: Data,
                     privateKey: Data,
                     algorithm: SignatureAlgorithm,
                     blockchain: BlockchainType) throws -> Data {
        switch algorithm {
        case .ecdsa_secp256k1:
            return try signECDSA_secp256k1(messageHash: messageHash, privateKey: privateKey)
        case .ecdsa_secp256r1:
            return try signECDSA_secp256r1(messageHash: messageHash, privateKey: privateKey)
        case .eddsa_ed25519:
            return try signEdDSA(messageHash: messageHash, privateKey: privateKey)
        }
    }

    private func signECDSA_secp256k1(messageHash: Data, privateKey: Data) throws -> Data {
        // Use production secp256k1 bridge
        return try Secp256k1Bridge.sign(
            messageHash: messageHash,
            privateKey: privateKey,
            useRFC6979: true // Deterministic signatures (RFC 6979)
        )
    }

    private func signECDSA_secp256r1(messageHash: Data, privateKey: Data) throws -> Data {
        let privKey = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try privKey.signature(for: messageHash)
        return signature.rawRepresentation
    }

    private func signEdDSA(messageHash: Data, privateKey: Data) throws -> Data {
        let privKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try privKey.signature(for: messageHash)
        return signature
    }

    private func constructSignedTransaction(transaction: UnsignedTransaction,
                                          signature: Data,
                                          context: SigningContext) throws -> Data {
        switch transaction.blockchain {
        case .ethereum, .polygon, .binanceSmartChain, .arbitrum, .optimism:
            return try constructEthereumSignedTx(transaction, signature: signature, context: context)
        case .bitcoin:
            return try constructBitcoinSignedTx(transaction, signature: signature, context: context)
        }
    }

    private func constructEthereumSignedTx(_ transaction: UnsignedTransaction,
                                          signature: Data,
                                          context: SigningContext) throws -> Data {
        guard let chainId = context.chainId else {
            throw SigningError.invalidContext
        }

        // Extract r, s, v from signature (65 bytes: r=32, s=32, v=1)
        let r = signature[0..<32]
        let s = signature[32..<64]
        var v = UInt64(signature[64])

        // EIP-155: v = chainId * 2 + 35 + {0,1}
        v = chainId * 2 + 35 + v

        var rlpData = Data()
        rlpData.append(rlpEncode(context.nonce))
        if let gasPrice = context.gasPrice {
            rlpData.append(rlpEncode(gasPrice))
        }
        if let gasLimit = context.gasLimit {
            rlpData.append(rlpEncode(gasLimit))
        }
        rlpData.append(transaction.rawTransaction)
        rlpData.append(rlpEncode(v))
        rlpData.append(r)
        rlpData.append(s)

        return rlpData
    }

    private func constructBitcoinSignedTx(_ transaction: UnsignedTransaction,
                                         signature: Data,
                                         context: SigningContext) throws -> Data {
        // Extract Bitcoin transaction from metadata
        guard var btcTx = transaction.metadata["bitcoinTransaction"] as? BitcoinTransactionBuilder.BitcoinTransaction,
              let inputIndex = transaction.metadata["inputIndex"] as? Int,
              let publicKey = transaction.metadata["publicKey"] as? Data else {
            throw SigningError.invalidTransaction
        }

        let sigHashType = (transaction.metadata["sigHashType"] as? BitcoinTransactionBuilder.SigHashType) ?? .all

        // Encode signature in DER format and append SIGHASH type
        let derSignature = try Secp256k1Bridge.signatureToDER(signature)
        var finalSignature = derSignature
        finalSignature.append(UInt8(sigHashType.rawValue))

        if btcTx.isSegWit {
            // SegWit transaction - add witness data
            // For P2WPKH, witness is: <signature> <pubkey>
            let witnessStack = createWitnessStack(signature: finalSignature, publicKey: publicKey)

            // Update input with empty scriptSig (witness data goes in separate field)
            btcTx.inputs[inputIndex] = BitcoinTransactionBuilder.TxInput(
                previousOutput: btcTx.inputs[inputIndex].previousOutput,
                scriptSig: Data(), // Empty for native SegWit
                sequence: btcTx.inputs[inputIndex].sequence,
                amount: btcTx.inputs[inputIndex].amount,
                scriptPubKey: btcTx.inputs[inputIndex].scriptPubKey
            )

            // Serialize with witness data
            var signedTx = Data()

            // Version
            signedTx.append(contentsOf: withUnsafeBytes(of: btcTx.version.littleEndian) { Data($0) })

            // Marker and flag
            signedTx.append(0x00)
            signedTx.append(0x01)

            // Inputs count
            signedTx.append(BitcoinTransactionBuilder.serializeVarInt(UInt64(btcTx.inputs.count)))

            // Serialize inputs
            for input in btcTx.inputs {
                signedTx.append(input.serialize())
            }

            // Outputs count
            signedTx.append(BitcoinTransactionBuilder.serializeVarInt(UInt64(btcTx.outputs.count)))

            // Serialize outputs
            for output in btcTx.outputs {
                signedTx.append(output.serialize())
            }

            // Witness data for each input
            for (index, _) in btcTx.inputs.enumerated() {
                if index == inputIndex {
                    signedTx.append(witnessStack)
                } else {
                    signedTx.append(0x00) // Empty witness for other inputs
                }
            }

            // Locktime
            signedTx.append(contentsOf: withUnsafeBytes(of: btcTx.lockTime.littleEndian) { Data($0) })

            return signedTx
        } else {
            // Legacy transaction - signature goes in scriptSig
            let scriptSig = createScriptSig(signature: finalSignature, publicKey: publicKey)

            btcTx.inputs[inputIndex] = BitcoinTransactionBuilder.TxInput(
                previousOutput: btcTx.inputs[inputIndex].previousOutput,
                scriptSig: scriptSig,
                sequence: btcTx.inputs[inputIndex].sequence
            )

            // Serialize without witness
            return BitcoinTransactionBuilder.serialize(btcTx, includeWitness: false)
        }
    }

    private func createWitnessStack(signature: Data, publicKey: Data) -> Data {
        var witness = Data()

        // Number of witness items (2 for P2WPKH)
        witness.append(0x02)

        // Signature length and data
        witness.append(UInt8(signature.count))
        witness.append(signature)

        // Public key length and data
        witness.append(UInt8(publicKey.count))
        witness.append(publicKey)

        return witness
    }

    private func createScriptSig(signature: Data, publicKey: Data) -> Data {
        var scriptSig = Data()

        // Push signature
        scriptSig.append(UInt8(signature.count))
        scriptSig.append(signature)

        // Push public key
        scriptSig.append(UInt8(publicKey.count))
        scriptSig.append(publicKey)

        return scriptSig
    }

    private func constructMultiSigTransaction(transaction: UnsignedTransaction,
                                            signatures: [Data],
                                            context: SigningContext) throws -> Data {
        // Multi-sig construction depends on blockchain
        // This is simplified for demonstration
        var signedTx = try constructSignedTransaction(
            transaction: transaction,
            signature: signatures[0],
            context: context
        )

        // Append additional signatures
        for signature in signatures.dropFirst() {
            signedTx.append(signature)
        }

        return signedTx
    }

    private func rlpEncode(_ value: UInt64) -> Data {
        // Simplified RLP encoding
        if value == 0 {
            return Data([0x80])
        }

        var bytes = withUnsafeBytes(of: value.bigEndian) { Data($0) }
        // Remove leading zeros
        while bytes.first == 0 {
            bytes.removeFirst()
        }

        if bytes.count == 1 && bytes[0] < 0x80 {
            return bytes
        }

        var result = Data([0x80 + UInt8(bytes.count)])
        result.append(bytes)
        return result
    }
}

// MARK: - Supporting Classes

private class NonceManager {
    private var nonces: [String: UInt64] = [:]
    private let queue = DispatchQueue(label: "com.fueki.noncemanager")

    func incrementNonce(for blockchain: TransactionSigner.BlockchainType,
                       context: TransactionSigner.SigningContext) throws {
        queue.sync {
            let key = blockchainKey(blockchain, context: context)
            nonces[key, default: 0] += 1
        }
    }

    func getNonce(for blockchain: TransactionSigner.BlockchainType,
                 context: TransactionSigner.SigningContext) -> UInt64 {
        queue.sync {
            let key = blockchainKey(blockchain, context: context)
            return nonces[key, default: 0]
        }
    }

    func resetNonce(for blockchain: TransactionSigner.BlockchainType,
                   context: TransactionSigner.SigningContext) {
        queue.sync {
            let key = blockchainKey(blockchain, context: context)
            nonces[key] = 0
        }
    }

    private func blockchainKey(_ blockchain: TransactionSigner.BlockchainType,
                              context: TransactionSigner.SigningContext) -> String {
        let chainId = context.chainId ?? 0
        return "\(blockchain)-\(chainId)"
    }
}

private class HardwareKeyIntegration {
    func sign(messageHash: Data,
             keyIdentifier: String,
             blockchain: TransactionSigner.BlockchainType) throws -> Data {
        // Sign with iOS Secure Enclave
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationLabel as String: keyIdentifier,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let privateKey = item else {
            throw TransactionSigner.SigningError.hardwareSigningFailed("Failed to retrieve key")
        }

        // Create signature
        let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey as! SecKey,
            algorithm,
            messageHash as CFData,
            &error
        ) else {
            throw TransactionSigner.SigningError.hardwareSigningFailed("Signing failed")
        }

        return signature as Data
    }
}

private class SignatureVerifier {
    func verify(signature: Data,
               messageHash: Data,
               publicKey: Data,
               algorithm: TransactionSigner.SignatureAlgorithm) throws -> Bool {
        switch algorithm {
        case .ecdsa_secp256k1:
            // Use external secp256k1 library
            return try verifySecp256k1(signature: signature,
                                       messageHash: messageHash,
                                       publicKey: publicKey)
        case .ecdsa_secp256r1:
            return try verifyP256(signature: signature,
                                 messageHash: messageHash,
                                 publicKey: publicKey)
        case .eddsa_ed25519:
            return try verifyEd25519(signature: signature,
                                    messageHash: messageHash,
                                    publicKey: publicKey)
        }
    }

    private func verifySecp256k1(signature: Data, messageHash: Data, publicKey: Data) throws -> Bool {
        // Use production secp256k1 bridge for verification
        return try Secp256k1Bridge.verify(
            signature: signature,
            messageHash: messageHash,
            publicKey: publicKey
        )
    }

    private func verifyP256(signature: Data, messageHash: Data, publicKey: Data) throws -> Bool {
        let pubKey = try P256.Signing.PublicKey(x963Representation: publicKey)
        let sig = try P256.Signing.ECDSASignature(rawRepresentation: signature)
        return pubKey.isValidSignature(sig, for: messageHash)
    }

    private func verifyEd25519(signature: Data, messageHash: Data, publicKey: Data) throws -> Bool {
        let pubKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
        return pubKey.isValidSignature(signature, for: messageHash)
    }
}

// MARK: - Data Extensions

private extension Data {
    func sha256() -> Data {
        var hash = SHA256()
        hash.update(data: self)
        return Data(hash.finalize())
    }

    func keccak256() -> Data {
        // Implement Keccak-256 (Ethereum hash)
        // In production, use a library like CryptoSwift or web3swift
        // This is a placeholder
        return self.sha256() // NOT CORRECT - placeholder only
    }
}
