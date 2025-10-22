import Foundation
import CSecp256k1

/// Production-grade secp256k1 elliptic curve cryptography implementation
/// Compatible with Bitcoin and Ethereum signing standards
public final class Secp256k1 {

    // MARK: - Types

    public enum Secp256k1Error: Error, LocalizedError {
        case invalidPrivateKey
        case invalidPublicKey
        case invalidSignature
        case signatureCreationFailed
        case publicKeyDerivationFailed
        case verificationFailed
        case publicKeyRecoveryFailed
        case invalidRecoveryId
        case contextCreationFailed
        case invalidKeyLength
        case invalidMessageHash
        case tweakOutOfRange

        public var errorDescription: String? {
            switch self {
            case .invalidPrivateKey:
                return "Invalid private key: must be 32 bytes in range [1, n-1]"
            case .invalidPublicKey:
                return "Invalid public key: failed curve point validation"
            case .invalidSignature:
                return "Invalid signature format or values"
            case .signatureCreationFailed:
                return "Failed to create ECDSA signature"
            case .publicKeyDerivationFailed:
                return "Failed to derive public key from private key"
            case .verificationFailed:
                return "Signature verification failed"
            case .publicKeyRecoveryFailed:
                return "Failed to recover public key from signature"
            case .invalidRecoveryId:
                return "Invalid recovery ID: must be 0-3"
            case .contextCreationFailed:
                return "Failed to create secp256k1 context"
            case .invalidKeyLength:
                return "Invalid key length"
            case .invalidMessageHash:
                return "Invalid message hash: must be 32 bytes"
            case .tweakOutOfRange:
                return "Tweak value out of valid range"
            }
        }
    }

    // MARK: - Constants

    public static let privateKeySize = 32
    public static let publicKeyCompressedSize = 33
    public static let publicKeyUncompressedSize = 65
    public static let signatureSize = 64
    public static let signatureRecoverableSize = 65
    public static let messageHashSize = 32

    /// secp256k1 curve order (n)
    /// n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
    private static let curveOrder: [UInt8] = [
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFE,
        0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B,
        0xBF, 0xD2, 0x5E, 0x8C, 0xD0, 0x36, 0x41, 0x41
    ]

    // MARK: - Context Management

    private static let context: OpaquePointer? = {
        guard let ctx = secp256k1_context_create_sign_verify() else {
            fatalError("Failed to create secp256k1 context")
        }
        return ctx
    }()

    // MARK: - Public Key Operations

    /// Derive public key from private key using elliptic curve point multiplication
    /// - Parameters:
    ///   - privateKey: 32-byte private key
    ///   - compressed: Whether to return compressed format (33 bytes) or uncompressed (65 bytes)
    /// - Returns: Public key bytes
    public static func derivePublicKey(from privateKey: Data, compressed: Bool = true) throws -> Data {
        guard privateKey.count == privateKeySize else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // Validate private key is in valid range
        guard isValidPrivateKey(privateKey) else {
            throw Secp256k1Error.invalidPrivateKey
        }

        var outputLen = compressed ? publicKeyCompressedSize : publicKeyUncompressedSize
        var output = Data(count: outputLen)

        let result = privateKey.withUnsafeBytes { privKeyPtr in
            output.withUnsafeMutableBytes { outputPtr in
                secp256k1_pubkey_create_helper(
                    context,
                    outputPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    &outputLen,
                    privKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    compressed ? 1 : 0
                )
            }
        }

        guard result == 1 else {
            throw Secp256k1Error.publicKeyDerivationFailed
        }

        return output
    }

    /// Validate that a public key is a valid point on the secp256k1 curve
    /// - Parameter publicKey: Public key to validate (33 or 65 bytes)
    /// - Returns: True if valid
    public static func isValidPublicKey(_ publicKey: Data) -> Bool {
        guard publicKey.count == publicKeyCompressedSize || publicKey.count == publicKeyUncompressedSize else {
            return false
        }

        let result = publicKey.withUnsafeBytes { pubKeyPtr in
            secp256k1_ec_pubkey_verify_helper(
                context,
                pubKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                publicKey.count
            )
        }

        return result == 1
    }

    // MARK: - Signing Operations

    /// Sign a 32-byte message hash using ECDSA with deterministic nonce (RFC 6979)
    /// - Parameters:
    ///   - messageHash: 32-byte hash to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: 64-byte signature (r || s)
    public static func sign(messageHash: Data, with privateKey: Data) throws -> Data {
        guard messageHash.count == messageHashSize else {
            throw Secp256k1Error.invalidMessageHash
        }

        guard privateKey.count == privateKeySize else {
            throw Secp256k1Error.invalidPrivateKey
        }

        guard isValidPrivateKey(privateKey) else {
            throw Secp256k1Error.invalidPrivateKey
        }

        var signature = Data(count: signatureSize)

        let result = messageHash.withUnsafeBytes { msgPtr in
            privateKey.withUnsafeBytes { privKeyPtr in
                signature.withUnsafeMutableBytes { sigPtr in
                    secp256k1_ecdsa_sign_helper(
                        context,
                        sigPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        msgPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        privKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    )
                }
            }
        }

        guard result == 1 else {
            throw Secp256k1Error.signatureCreationFailed
        }

        return signature
    }

    /// Sign with recoverable signature (includes recovery ID for public key recovery)
    /// Used in Ethereum transactions (v, r, s format)
    /// - Parameters:
    ///   - messageHash: 32-byte hash to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: 65-byte recoverable signature (r || s || v)
    public static func signRecoverable(messageHash: Data, with privateKey: Data) throws -> Data {
        guard messageHash.count == messageHashSize else {
            throw Secp256k1Error.invalidMessageHash
        }

        guard privateKey.count == privateKeySize else {
            throw Secp256k1Error.invalidPrivateKey
        }

        guard isValidPrivateKey(privateKey) else {
            throw Secp256k1Error.invalidPrivateKey
        }

        var signature = Data(count: signatureSize)
        var recoveryId: Int32 = 0

        let result = messageHash.withUnsafeBytes { msgPtr in
            privateKey.withUnsafeBytes { privKeyPtr in
                signature.withUnsafeMutableBytes { sigPtr in
                    secp256k1_ecdsa_sign_recoverable_helper(
                        context,
                        sigPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        &recoveryId,
                        msgPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        privKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
                    )
                }
            }
        }

        guard result == 1 else {
            throw Secp256k1Error.signatureCreationFailed
        }

        // Append recovery ID as last byte (Ethereum format)
        signature.append(UInt8(recoveryId))

        return signature
    }

    // MARK: - Verification Operations

    /// Verify ECDSA signature
    /// - Parameters:
    ///   - signature: 64-byte signature (r || s)
    ///   - messageHash: 32-byte hash that was signed
    ///   - publicKey: Public key to verify against (33 or 65 bytes)
    /// - Returns: True if signature is valid
    public static func verify(signature: Data, messageHash: Data, publicKey: Data) throws -> Bool {
        guard signature.count == signatureSize else {
            throw Secp256k1Error.invalidSignature
        }

        guard messageHash.count == messageHashSize else {
            throw Secp256k1Error.invalidMessageHash
        }

        guard isValidPublicKey(publicKey) else {
            throw Secp256k1Error.invalidPublicKey
        }

        let result = signature.withUnsafeBytes { sigPtr in
            messageHash.withUnsafeBytes { msgPtr in
                publicKey.withUnsafeBytes { pubKeyPtr in
                    secp256k1_ecdsa_verify_helper(
                        context,
                        sigPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        msgPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        pubKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        publicKey.count
                    )
                }
            }
        }

        return result == 1
    }

    /// Recover public key from recoverable signature
    /// - Parameters:
    ///   - signature: 65-byte recoverable signature (r || s || v)
    ///   - messageHash: 32-byte hash that was signed
    ///   - compressed: Whether to return compressed public key
    /// - Returns: Recovered public key
    public static func recoverPublicKey(from signature: Data, messageHash: Data, compressed: Bool = true) throws -> Data {
        guard signature.count == signatureRecoverableSize else {
            throw Secp256k1Error.invalidSignature
        }

        guard messageHash.count == messageHashSize else {
            throw Secp256k1Error.invalidMessageHash
        }

        // Extract recovery ID (last byte)
        let recoveryId = Int32(signature[64])
        guard recoveryId >= 0 && recoveryId <= 3 else {
            throw Secp256k1Error.invalidRecoveryId
        }

        // Extract signature (first 64 bytes)
        let sig64 = signature.prefix(signatureSize)

        var outputLen = compressed ? publicKeyCompressedSize : publicKeyUncompressedSize
        var output = Data(count: outputLen)

        let result = sig64.withUnsafeBytes { sigPtr in
            messageHash.withUnsafeBytes { msgPtr in
                output.withUnsafeMutableBytes { outputPtr in
                    secp256k1_ecdsa_recover_helper(
                        context,
                        outputPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        &outputLen,
                        sigPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        recoveryId,
                        msgPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        compressed ? 1 : 0
                    )
                }
            }
        }

        guard result == 1 else {
            throw Secp256k1Error.publicKeyRecoveryFailed
        }

        return output
    }

    // MARK: - Key Tweaking Operations (for HD Wallets)

    /// Add a tweak to a private key (for BIP32 child key derivation)
    /// Result = (privateKey + tweak) mod n
    /// - Parameters:
    ///   - privateKey: 32-byte private key
    ///   - tweak: 32-byte tweak value
    /// - Returns: Tweaked private key
    public static func privateKeyAdd(_ privateKey: Data, tweak: Data) throws -> Data {
        guard privateKey.count == privateKeySize && tweak.count == privateKeySize else {
            throw Secp256k1Error.invalidKeyLength
        }

        var result = privateKey

        let success = result.withUnsafeMutableBytes { resultPtr in
            tweak.withUnsafeBytes { tweakPtr in
                secp256k1_ec_privkey_tweak_add_helper(
                    context,
                    resultPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    tweakPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
                )
            }
        }

        guard success == 1 else {
            throw Secp256k1Error.tweakOutOfRange
        }

        return result
    }

    /// Multiply a private key by a tweak
    /// Result = (privateKey * tweak) mod n
    /// - Parameters:
    ///   - privateKey: 32-byte private key
    ///   - tweak: 32-byte tweak value
    /// - Returns: Tweaked private key
    public static func privateKeyMultiply(_ privateKey: Data, by tweak: Data) throws -> Data {
        guard privateKey.count == privateKeySize && tweak.count == privateKeySize else {
            throw Secp256k1Error.invalidKeyLength
        }

        var result = privateKey

        let success = result.withUnsafeMutableBytes { resultPtr in
            tweak.withUnsafeBytes { tweakPtr in
                secp256k1_ec_privkey_tweak_mul_helper(
                    context,
                    resultPtr.baseAddress?.assumingMemoryBound(to: UInt8.self),
                    tweakPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
                )
            }
        }

        guard success == 1 else {
            throw Secp256k1Error.tweakOutOfRange
        }

        return result
    }

    /// Negate a private key
    /// Result = (n - privateKey) mod n
    /// - Parameter privateKey: 32-byte private key
    /// - Returns: Negated private key
    public static func privateKeyNegate(_ privateKey: Data) throws -> Data {
        guard privateKey.count == privateKeySize else {
            throw Secp256k1Error.invalidKeyLength
        }

        var result = privateKey

        let success = result.withUnsafeMutableBytes { resultPtr in
            secp256k1_ec_privkey_negate_helper(
                context,
                resultPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
            )
        }

        guard success == 1 else {
            throw Secp256k1Error.invalidPrivateKey
        }

        return result
    }

    // MARK: - Validation Helpers

    /// Validate that a private key is in the valid range [1, n-1]
    /// - Parameter privateKey: 32-byte private key
    /// - Returns: True if valid
    public static func isValidPrivateKey(_ privateKey: Data) -> Bool {
        guard privateKey.count == privateKeySize else {
            return false
        }

        let result = privateKey.withUnsafeBytes { privKeyPtr in
            secp256k1_ec_seckey_verify_helper(
                context,
                privKeyPtr.baseAddress?.assumingMemoryBound(to: UInt8.self)
            )
        }

        return result == 1
    }

    // MARK: - Utility Functions

    /// Normalize signature to lower-S form (BIP 62)
    /// This prevents signature malleability
    /// - Parameter signature: 64-byte signature
    /// - Returns: Normalized signature
    public static func normalizeSignature(_ signature: Data) -> Data {
        guard signature.count == signatureSize else {
            return signature
        }

        // Extract s component (last 32 bytes)
        let s = signature.suffix(32)

        // Check if s > n/2
        if isHighS(s) {
            // Negate s: s' = n - s
            let sNegated = negateScalar(s)

            // Reconstruct signature with r || s'
            var normalized = signature.prefix(32)
            normalized.append(sNegated)
            return normalized
        }

        return signature
    }

    private static func isHighS(_ s: Data) -> Bool {
        // Compare with n/2
        let halfOrder: [UInt8] = [
            0x7F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0x5D, 0x57, 0x6E, 0x73, 0x57, 0xA4, 0x50, 0x1D,
            0xDF, 0xE9, 0x2F, 0x46, 0x68, 0x1B, 0x20, 0xA0
        ]

        for i in 0..<32 {
            if s[i] > halfOrder[i] {
                return true
            } else if s[i] < halfOrder[i] {
                return false
            }
        }
        return false
    }

    private static func negateScalar(_ scalar: Data) -> Data {
        // n - scalar
        var result = Data(count: 32)
        var borrow: UInt16 = 0

        for i in (0..<32).reversed() {
            let diff = UInt16(curveOrder[i]) - UInt16(scalar[i]) - borrow
            result[i] = UInt8(diff & 0xFF)
            borrow = diff > 0xFF ? 1 : 0
        }

        return result
    }
}
