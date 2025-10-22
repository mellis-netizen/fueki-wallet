import Foundation

/// Secp256k1 wrapper for Ethereum operations
/// Provides a clean interface for the Secp256k1Bridge
public struct Secp256k1 {

    /// Sign a message hash with secp256k1
    /// - Parameters:
    ///   - hash: 32-byte message hash
    ///   - privateKey: 32-byte private key
    /// - Returns: ECDSA signature with recovery ID
    public static func sign(hash: Data, privateKey: Data) throws -> ECDSASignature {
        // Use recoverable signature from bridge
        let recoverableSignature = try Secp256k1Bridge.signRecoverable(
            messageHash: hash,
            privateKey: privateKey
        )

        guard recoverableSignature.count == 65 else {
            throw Secp256k1Bridge.Secp256k1Error.signatureCreationFailed
        }

        let r = recoverableSignature[0..<32]
        let s = recoverableSignature[32..<64]
        let v = recoverableSignature[64]

        return ECDSASignature(r: r, s: s, v: v)
    }

    /// Recover public key from signature
    /// - Parameters:
    ///   - hash: 32-byte message hash
    ///   - signature: ECDSA signature with recovery ID
    /// - Returns: 64-byte uncompressed public key
    public static func recoverPublicKey(hash: Data, signature: ECDSASignature) throws -> Data {
        // Create recoverable signature format
        var recoverableSignature = Data()
        recoverableSignature.append(signature.r)
        recoverableSignature.append(signature.s)
        recoverableSignature.append(signature.v)

        let publicKey = try Secp256k1Bridge.recoverPublicKey(
            from: recoverableSignature,
            messageHash: hash
        )

        // If we get compressed format, uncompress it
        if publicKey.count == 33 {
            // For now, throw error as recovery should return uncompressed
            throw Secp256k1Bridge.Secp256k1Error.publicKeyDerivationFailed
        }

        // Remove 0x04 prefix if present
        if publicKey.count == 65 && publicKey[0] == 0x04 {
            return publicKey.dropFirst()
        }

        return publicKey
    }

    /// Verify signature
    /// - Parameters:
    ///   - signature: ECDSA signature
    ///   - hash: 32-byte message hash
    ///   - publicKey: Public key to verify against
    /// - Returns: True if signature is valid
    public static func verify(signature: ECDSASignature, hash: Data, publicKey: Data) throws -> Bool {
        // Combine r and s for verification
        var compactSignature = Data()
        compactSignature.append(signature.r)
        compactSignature.append(signature.s)

        return try Secp256k1Bridge.verify(
            signature: compactSignature,
            messageHash: hash,
            publicKey: publicKey
        )
    }

    /// Derive public key from private key
    /// - Parameters:
    ///   - privateKey: 32-byte private key
    ///   - compressed: Whether to return compressed format
    /// - Returns: Public key
    public static func derivePublicKey(from privateKey: Data, compressed: Bool = false) throws -> Data {
        return try Secp256k1Bridge.derivePublicKey(from: privateKey, compressed: compressed)
    }
}
