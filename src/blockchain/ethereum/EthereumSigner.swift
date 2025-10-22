import Foundation
import CryptoKit

/// Ethereum transaction signing with EIP-155 and EIP-1559 support
public struct EthereumSigner {

    // MARK: - Transaction Signing

    /// Sign a legacy transaction (EIP-155)
    /// - Parameters:
    ///   - transaction: Transaction to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: Signed transaction data (RLP encoded)
    public static func signLegacyTransaction(
        _ transaction: EthereumTransaction,
        privateKey: Data
    ) throws -> Data {
        guard privateKey.count == 32 else {
            throw EthereumSignerError.invalidPrivateKey
        }

        // Build RLP encoding for signing (EIP-155)
        let rlpItems: [RLPEncodable] = [
            transaction.nonce,
            transaction.gasPrice ?? 0,
            transaction.gasLimit,
            Data(hex: transaction.to.stripHexPrefix()) ?? Data(),
            transaction.value,
            transaction.data,
            transaction.chainId,  // EIP-155: Include chain ID for replay protection
            UInt64(0),           // EIP-155: Empty r
            UInt64(0)            // EIP-155: Empty s
        ]

        let rlpEncoded = RLPEncoding.encodeList(rlpItems)
        let messageHash = Keccak256.hash(rlpEncoded)

        // Sign with secp256k1
        let signature = try signHash(messageHash, privateKey: privateKey)

        // Calculate v with EIP-155: v = chainId * 2 + 35 + {0, 1}
        let v = transaction.chainId * 2 + 35 + UInt64(signature.v)

        // Build final signed transaction
        let signedItems: [RLPEncodable] = [
            transaction.nonce,
            transaction.gasPrice ?? 0,
            transaction.gasLimit,
            Data(hex: transaction.to.stripHexPrefix()) ?? Data(),
            transaction.value,
            transaction.data,
            v,
            signature.r,
            signature.s
        ]

        return RLPEncoding.encodeList(signedItems)
    }

    /// Sign an EIP-1559 transaction (Type 2)
    /// - Parameters:
    ///   - transaction: EIP-1559 transaction to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: Signed transaction data (0x02 || RLP encoded)
    public static func signEIP1559Transaction(
        _ transaction: EthereumTransaction,
        privateKey: Data
    ) throws -> Data {
        guard privateKey.count == 32 else {
            throw EthereumSignerError.invalidPrivateKey
        }

        guard let maxFeePerGas = transaction.maxFeePerGas,
              let maxPriorityFeePerGas = transaction.maxPriorityFeePerGas else {
            throw EthereumSignerError.invalidTransaction
        }

        // Build RLP encoding for signing (EIP-1559)
        let rlpItems: [RLPEncodable] = [
            transaction.chainId,
            transaction.nonce,
            maxPriorityFeePerGas,
            maxFeePerGas,
            transaction.gasLimit,
            Data(hex: transaction.to.stripHexPrefix()) ?? Data(),
            transaction.value,
            transaction.data,
            [] as [Data]  // Empty access list
        ]

        let rlpEncoded = RLPEncoding.encodeList(rlpItems)

        // EIP-2718: Typed transaction envelope
        // Hash is: keccak256(0x02 || rlp([chainId, nonce, ...]))
        var messageToHash = Data([0x02])
        messageToHash.append(rlpEncoded)
        let messageHash = Keccak256.hash(messageToHash)

        // Sign with secp256k1
        let signature = try signHash(messageHash, privateKey: privateKey)

        // For EIP-1559, v is just the recovery ID (0 or 1)
        let v = UInt64(signature.v)

        // Build final signed transaction
        let signedItems: [RLPEncodable] = [
            transaction.chainId,
            transaction.nonce,
            maxPriorityFeePerGas,
            maxFeePerGas,
            transaction.gasLimit,
            Data(hex: transaction.to.stripHexPrefix()) ?? Data(),
            transaction.value,
            transaction.data,
            [] as [Data],  // Empty access list
            v,
            signature.r,
            signature.s
        ]

        // EIP-2718: 0x02 || rlp([chainId, nonce, ..., v, r, s])
        var signedTransaction = Data([0x02])
        signedTransaction.append(RLPEncoding.encodeList(signedItems))

        return signedTransaction
    }

    /// Sign a transaction (automatically detects type)
    /// - Parameters:
    ///   - transaction: Transaction to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: Signed transaction data (RLP encoded)
    public static func signTransaction(
        _ transaction: EthereumTransaction,
        privateKey: Data
    ) throws -> Data {
        // Detect transaction type
        if transaction.maxFeePerGas != nil && transaction.maxPriorityFeePerGas != nil {
            // EIP-1559 transaction
            return try signEIP1559Transaction(transaction, privateKey: privateKey)
        } else {
            // Legacy transaction
            return try signLegacyTransaction(transaction, privateKey: privateKey)
        }
    }

    // MARK: - Message Signing

    /// Sign an arbitrary message hash with secp256k1
    /// - Parameters:
    ///   - hash: 32-byte message hash
    ///   - privateKey: 32-byte private key
    /// - Returns: ECDSA signature
    public static func signHash(_ hash: Data, privateKey: Data) throws -> ECDSASignature {
        guard hash.count == 32 else {
            throw EthereumSignerError.invalidHash
        }

        guard privateKey.count == 32 else {
            throw EthereumSignerError.invalidPrivateKey
        }

        // Use secp256k1 signing
        return try Secp256k1.sign(hash: hash, privateKey: privateKey)
    }

    /// Sign an Ethereum personal message (EIP-191)
    /// - Parameters:
    ///   - message: Message to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: ECDSA signature
    public static func signPersonalMessage(_ message: Data, privateKey: Data) throws -> ECDSASignature {
        // EIP-191: "\x19Ethereum Signed Message:\n" + len(message) + message
        let prefix = "\u{19}Ethereum Signed Message:\n\(message.count)"
        var messageToSign = Data(prefix.utf8)
        messageToSign.append(message)

        let messageHash = Keccak256.hash(messageToSign)
        return try signHash(messageHash, privateKey: privateKey)
    }

    // MARK: - Signature Recovery

    /// Recover public key from signature
    /// - Parameters:
    ///   - hash: 32-byte message hash
    ///   - signature: ECDSA signature
    /// - Returns: 64-byte uncompressed public key
    public static func recoverPublicKey(hash: Data, signature: ECDSASignature) throws -> Data {
        guard hash.count == 32 else {
            throw EthereumSignerError.invalidHash
        }

        return try Secp256k1.recoverPublicKey(hash: hash, signature: signature)
    }

    /// Recover Ethereum address from signature
    /// - Parameters:
    ///   - hash: 32-byte message hash
    ///   - signature: ECDSA signature
    /// - Returns: 20-byte Ethereum address
    public static func recoverAddress(hash: Data, signature: ECDSASignature) throws -> Data {
        let publicKey = try recoverPublicKey(hash: hash, signature: signature)
        return Keccak256.ethereumAddress(from: publicKey)
    }
}

// MARK: - Supporting Types

public struct ECDSASignature {
    public let r: Data  // 32 bytes
    public let s: Data  // 32 bytes
    public let v: UInt8 // Recovery ID (0 or 1)

    public init(r: Data, s: Data, v: UInt8) {
        self.r = r
        self.s = s
        self.v = v
    }

    /// Create signature from 65-byte compact format (r || s || v)
    public init?(compact: Data) {
        guard compact.count == 65 else { return nil }

        self.r = compact[0..<32]
        self.s = compact[32..<64]
        self.v = compact[64]
    }

    /// Convert to 65-byte compact format (r || s || v)
    public var compact: Data {
        var data = Data()
        data.append(r)
        data.append(s)
        data.append(v)
        return data
    }
}

public enum EthereumSignerError: Error {
    case invalidPrivateKey
    case invalidHash
    case invalidTransaction
    case signingFailed
    case recoveryFailed
}

// MARK: - String Extension

private extension String {
    func stripHexPrefix() -> String {
        return self.hasPrefix("0x") ? String(self.dropFirst(2)) : self
    }
}
