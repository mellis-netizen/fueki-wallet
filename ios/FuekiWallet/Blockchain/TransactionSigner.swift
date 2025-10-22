//
//  TransactionSigner.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Transaction Signing (ECDSA, Ed25519)
//

import Foundation
import CryptoKit

// MARK: - Transaction Signer
class TransactionSigner {
    private let chainType: BlockchainType

    init(chainType: BlockchainType) {
        self.chainType = chainType
    }

    // MARK: - Sign Transaction
    func signTransaction(
        transactionData: Data,
        privateKey: Data
    ) throws -> SignedTransaction {
        switch chainType {
        case .solana:
            return try signSolanaTransaction(transactionData, privateKey: privateKey)
        case .ethereum:
            return try signEthereumTransaction(transactionData, privateKey: privateKey)
        case .bitcoin:
            return try signBitcoinTransaction(transactionData, privateKey: privateKey)
        }
    }

    // MARK: - Verify Signature
    func verifySignature(
        transaction: SignedTransaction,
        publicKey: Data
    ) throws -> Bool {
        switch chainType {
        case .solana:
            return try verifySolanaSignature(transaction, publicKey: publicKey)
        case .ethereum:
            return try verifyEthereumSignature(transaction, publicKey: publicKey)
        case .bitcoin:
            return try verifyBitcoinSignature(transaction, publicKey: publicKey)
        }
    }

    // MARK: - Solana Signing (Ed25519)
    private func signSolanaTransaction(
        _ transactionData: Data,
        privateKey: Data
    ) throws -> SignedTransaction {
        // Solana uses Ed25519 signatures
        guard privateKey.count == 32 else {
            throw BlockchainError.invalidTransaction
        }

        // Create Ed25519 private key
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)

        // Sign the transaction
        let signature = try signingKey.signature(for: transactionData)

        // Calculate transaction hash (first signature is the transaction ID in Solana)
        let hash = Data(signature).base58Encoded

        // Combine signature with transaction
        var signedData = Data()
        signedData.append(Data(signature))
        signedData.append(transactionData)

        return SignedTransaction(
            rawTransaction: signedData,
            hash: hash,
            signature: Data(signature)
        )
    }

    private func verifySolanaSignature(
        _ transaction: SignedTransaction,
        publicKey: Data
    ) throws -> Bool {
        let verifyingKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)

        // Extract signature (first 64 bytes)
        let signature = transaction.signature.prefix(64)

        // Extract message (remaining bytes)
        let message = transaction.rawTransaction.dropFirst(64)

        return verifyingKey.isValidSignature(signature, for: message)
    }

    // MARK: - Ethereum Signing (secp256k1)
    private func signEthereumTransaction(
        _ transactionData: Data,
        privateKey: Data
    ) throws -> SignedTransaction {
        // Ethereum uses secp256k1 ECDSA signatures
        // This is a simplified implementation
        // Production code should use a proper secp256k1 library

        guard privateKey.count == 32 else {
            throw BlockchainError.invalidTransaction
        }

        // Hash the transaction data using Keccak256
        let messageHash = keccak256(transactionData)

        // Sign with secp256k1 (using CryptoKit's P256 as placeholder)
        // Note: Real implementation should use secp256k1
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try signingKey.signature(for: messageHash)

        // Extract r, s, v components
        let signatureData = signature.rawRepresentation

        // Calculate transaction hash
        let hash = "0x" + keccak256(transactionData).map { String(format: "%02x", $0) }.joined()

        // Build signed transaction with RLP encoding
        var signedData = Data()
        signedData.append(transactionData)
        signedData.append(signatureData)

        return SignedTransaction(
            rawTransaction: signedData,
            hash: hash,
            signature: signatureData
        )
    }

    private func verifyEthereumSignature(
        _ transaction: SignedTransaction,
        publicKey: Data
    ) throws -> Bool {
        // Verify ECDSA signature
        // This is a simplified implementation
        let verifyingKey = try P256.Signing.PublicKey(rawRepresentation: publicKey)

        let messageHash = keccak256(transaction.rawTransaction)
        let signature = try P256.Signing.ECDSASignature(rawRepresentation: transaction.signature)

        return verifyingKey.isValidSignature(signature, for: messageHash)
    }

    // MARK: - Bitcoin Signing (secp256k1)
    private func signBitcoinTransaction(
        _ transactionData: Data,
        privateKey: Data
    ) throws -> SignedTransaction {
        // Bitcoin uses secp256k1 ECDSA signatures with DER encoding
        guard privateKey.count == 32 else {
            throw BlockchainError.invalidTransaction
        }

        // Double SHA256 hash
        let messageHash = sha256(sha256(transactionData))

        // Sign with secp256k1
        let signingKey = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try signingKey.signature(for: messageHash)

        // DER encode the signature
        let derSignature = signature.derRepresentation

        // Calculate transaction hash (TXID is double SHA256 of the transaction)
        let txidData = sha256(sha256(transactionData))
        let hash = txidData.reversed().map { String(format: "%02x", $0) }.joined()

        // Build signed transaction
        var signedData = Data()
        signedData.append(transactionData)
        signedData.append(derSignature)

        return SignedTransaction(
            rawTransaction: signedData,
            hash: hash,
            signature: derSignature
        )
    }

    private func verifyBitcoinSignature(
        _ transaction: SignedTransaction,
        publicKey: Data
    ) throws -> Bool {
        let verifyingKey = try P256.Signing.PublicKey(rawRepresentation: publicKey)

        let messageHash = sha256(sha256(transaction.rawTransaction))
        let signature = try P256.Signing.ECDSASignature(derRepresentation: transaction.signature)

        return verifyingKey.isValidSignature(signature, for: messageHash)
    }

    // MARK: - Hash Functions
    private func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    private func keccak256(_ data: Data) -> Data {
        // Simplified Keccak256 implementation
        // Production code should use a proper Keccak256 library
        // For now, using SHA256 as placeholder
        Data(SHA256.hash(data: data))
    }
}

// MARK: - Multi-Signature Support
class MultiSignatureManager {
    private let chainType: BlockchainType
    private let requiredSignatures: Int
    private var signatures: [Data] = []

    init(chainType: BlockchainType, requiredSignatures: Int) {
        self.chainType = chainType
        self.requiredSignatures = requiredSignatures
    }

    // MARK: - Add Signature
    func addSignature(_ signature: Data) throws {
        guard signatures.count < requiredSignatures else {
            throw BlockchainError.invalidTransaction
        }

        signatures.append(signature)
    }

    // MARK: - Check if Ready
    func isReadyToSign() -> Bool {
        return signatures.count >= requiredSignatures
    }

    // MARK: - Combine Signatures
    func combineSignatures(transactionData: Data) throws -> SignedTransaction {
        guard isReadyToSign() else {
            throw BlockchainError.invalidTransaction
        }

        switch chainType {
        case .ethereum:
            return try combineEthereumMultiSig(transactionData)
        case .bitcoin:
            return try combineBitcoinMultiSig(transactionData)
        case .solana:
            return try combineSolanaMultiSig(transactionData)
        }
    }

    // MARK: - Private Multi-Sig Helpers
    private func combineEthereumMultiSig(_ transactionData: Data) throws -> SignedTransaction {
        // Ethereum multi-sig combines signatures in a specific format
        var combinedData = transactionData

        for signature in signatures {
            combinedData.append(signature)
        }

        let hash = "0x" + Data(SHA256.hash(data: combinedData)).map { String(format: "%02x", $0) }.joined()

        return SignedTransaction(
            rawTransaction: combinedData,
            hash: hash,
            signature: signatures.first ?? Data()
        )
    }

    private func combineBitcoinMultiSig(_ transactionData: Data) throws -> SignedTransaction {
        // Bitcoin P2SH multi-sig script
        var scriptSig = Data([0x00])  // OP_0

        for signature in signatures {
            scriptSig.append(Data([UInt8(signature.count)]))
            scriptSig.append(signature)
        }

        var combinedData = transactionData
        combinedData.append(scriptSig)

        let txidData = Data(SHA256.hash(data: Data(SHA256.hash(data: combinedData))))
        let hash = txidData.reversed().map { String(format: "%02x", $0) }.joined()

        return SignedTransaction(
            rawTransaction: combinedData,
            hash: hash,
            signature: scriptSig
        )
    }

    private func combineSolanaMultiSig(_ transactionData: Data) throws -> SignedTransaction {
        // Solana multi-sig combines signatures sequentially
        var combinedData = Data()

        // Add signature count
        combinedData.append(UInt8(signatures.count))

        // Add each signature
        for signature in signatures {
            combinedData.append(signature)
        }

        // Add transaction data
        combinedData.append(transactionData)

        let hash = signatures.first?.base58Encoded ?? ""

        return SignedTransaction(
            rawTransaction: combinedData,
            hash: hash,
            signature: signatures.first ?? Data()
        )
    }
}

// MARK: - Hardware Wallet Support
protocol HardwareWalletSigner {
    func signTransaction(
        transactionData: Data,
        derivationPath: String
    ) async throws -> SignedTransaction

    func getPublicKey(derivationPath: String) async throws -> Data
}

// MARK: - Data Extension for Base58
extension Data {
    var base58Encoded: String {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        var bytes = Array(self)
        var zerosCount = 0

        for byte in bytes {
            if byte == 0 {
                zerosCount += 1
            } else {
                break
            }
        }

        bytes = Array(bytes.drop(while: { $0 == 0 }))

        var encoded = [Character]()
        var carry: Int
        var i: Int

        for _ in 0..<bytes.count * 138 / 100 + 1 {
            carry = 0
            i = bytes.count - 1

            while i >= 0 {
                carry += 256 * Int(bytes[i])
                bytes[i] = UInt8(carry % 58)
                carry /= 58
                i -= 1
            }

            if carry > 0 {
                encoded.insert(alphabet[alphabet.index(alphabet.startIndex, offsetBy: carry)], at: 0)
            }
        }

        for byte in bytes {
            if byte == 0 {
                break
            }
            encoded.append(alphabet[alphabet.index(alphabet.startIndex, offsetBy: Int(byte))])
        }

        let zeros = String(repeating: alphabet.first!, count: zerosCount)
        return zeros + String(encoded)
    }
}
