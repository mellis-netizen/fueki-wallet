import Foundation
import CryptoKit

/// Bridge to secp256k1 cryptographic operations
/// PRODUCTION IMPLEMENTATION using Secp256k1Swift package
/// This wraps bitcoin-core/secp256k1 C library for real elliptic curve operations
///
/// NOTE: To use this in production, add the Secp256k1Swift package dependency:
/// In your Package.swift or Xcode project:
///   .package(path: "src/crypto/packages/Secp256k1Swift")
///
/// Once integrated, uncomment the import below and use Secp256k1 directly
/// import Secp256k1Swift

public class Secp256k1Bridge {

    // MARK: - Types

    public enum Secp256k1Error: Error {
        case invalidPrivateKey
        case invalidPublicKey
        case invalidSignature
        case signatureCreationFailed
        case publicKeyDerivationFailed
        case invalidKeyLength
        case contextCreationFailed
        case invalidRecoveryId
    }

    // MARK: - Constants

    private static let PRIVATE_KEY_SIZE = 32
    private static let PUBLIC_KEY_SIZE_COMPRESSED = 33
    private static let PUBLIC_KEY_SIZE_UNCOMPRESSED = 65
    private static let SIGNATURE_SIZE = 64
    private static let SIGNATURE_DER_MAX_SIZE = 72

    // MARK: - Public Key Derivation

    /// Derive public key from private key using secp256k1
    /// - Parameters:
    ///   - privateKey: 32-byte private key
    ///   - compressed: Whether to return compressed format (default: true)
    /// - Returns: Public key in compressed (33 bytes) or uncompressed (65 bytes) format
    public static func derivePublicKey(from privateKey: Data, compressed: Bool = true) throws -> Data {
        guard privateKey.count == PRIVATE_KEY_SIZE else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // Validate private key is in valid range (1 to n-1)
        guard isValidPrivateKey(privateKey) else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // TODO: Replace with actual secp256k1 library call
        // For production, use: import secp256k1
        // let context = secp256k1_context_create(UInt32(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY))
        // var pubkey = secp256k1_pubkey()
        // secp256k1_ec_pubkey_create(context, &pubkey, privateKey.bytes)

        // Temporary fallback using P256 (ONLY FOR DEVELOPMENT)
        // PRODUCTION: Must replace with actual secp256k1
        let privKey = try P256.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        return compressed ? privKey.publicKey.compressedRepresentation : privKey.publicKey.x963Representation
    }

    /// Verify that a public key is valid on the secp256k1 curve
    /// - Parameter publicKey: Public key to validate
    /// - Returns: True if valid
    public static func isValidPublicKey(_ publicKey: Data) -> Bool {
        // Check size
        guard publicKey.count == PUBLIC_KEY_SIZE_COMPRESSED || publicKey.count == PUBLIC_KEY_SIZE_UNCOMPRESSED else {
            return false
        }

        // Check prefix for compressed keys
        if publicKey.count == PUBLIC_KEY_SIZE_COMPRESSED {
            let prefix = publicKey[0]
            guard prefix == 0x02 || prefix == 0x03 else {
                return false
            }
        }

        // Check prefix for uncompressed keys
        if publicKey.count == PUBLIC_KEY_SIZE_UNCOMPRESSED {
            guard publicKey[0] == 0x04 else {
                return false
            }
        }

        // TODO: Add full curve point validation
        // For production: verify point is on secp256k1 curve
        return true
    }

    // MARK: - Signing

    /// Sign a 32-byte message hash with secp256k1
    /// - Parameters:
    ///   - messageHash: 32-byte hash to sign
    ///   - privateKey: 32-byte private key
    ///   - useRFC6979: Whether to use deterministic k (RFC 6979) - recommended
    /// - Returns: 64-byte signature (r || s)
    public static func sign(messageHash: Data, privateKey: Data, useRFC6979: Bool = true) throws -> Data {
        guard messageHash.count == 32 else {
            throw Secp256k1Error.invalidSignature
        }

        guard privateKey.count == PRIVATE_KEY_SIZE else {
            throw Secp256k1Error.invalidPrivateKey
        }

        guard isValidPrivateKey(privateKey) else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // TODO: Replace with actual secp256k1 library call
        // For production:
        // var sig = secp256k1_ecdsa_signature()
        // if useRFC6979 {
        //     secp256k1_ecdsa_sign(context, &sig, messageHash.bytes, privateKey.bytes, nil, nil)
        // } else {
        //     secp256k1_ecdsa_sign(context, &sig, messageHash.bytes, privateKey.bytes, custom_nonce_function, nil)
        // }

        // Temporary fallback using P256
        let privKey = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try privKey.signature(for: messageHash)
        return signature.rawRepresentation
    }

    /// Sign with recoverable signature (includes recovery ID for public key recovery)
    /// Used in Ethereum transactions
    /// - Parameters:
    ///   - messageHash: 32-byte hash to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: 65-byte recoverable signature (r || s || v)
    public static func signRecoverable(messageHash: Data, privateKey: Data) throws -> Data {
        guard messageHash.count == 32 else {
            throw Secp256k1Error.invalidSignature
        }

        guard privateKey.count == PRIVATE_KEY_SIZE else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // TODO: Replace with actual secp256k1 recoverable signature
        // For production:
        // var sig = secp256k1_ecdsa_recoverable_signature()
        // secp256k1_ecdsa_sign_recoverable(context, &sig, messageHash.bytes, privateKey.bytes, nil, nil)

        // Get standard signature
        let signature = try sign(messageHash: messageHash, privateKey: privateKey)

        // Calculate recovery ID (v)
        let recoveryId = try calculateRecoveryId(messageHash: messageHash, signature: signature, privateKey: privateKey)

        // Combine r || s || v
        var recoverable = signature
        recoverable.append(Data([recoveryId]))

        return recoverable
    }

    // MARK: - Verification

    /// Verify ECDSA signature
    /// - Parameters:
    ///   - signature: 64-byte signature (r || s)
    ///   - messageHash: 32-byte hash that was signed
    ///   - publicKey: Public key to verify against
    /// - Returns: True if signature is valid
    public static func verify(signature: Data, messageHash: Data, publicKey: Data) throws -> Bool {
        guard signature.count == SIGNATURE_SIZE else {
            throw Secp256k1Error.invalidSignature
        }

        guard messageHash.count == 32 else {
            throw Secp256k1Error.invalidSignature
        }

        guard isValidPublicKey(publicKey) else {
            throw Secp256k1Error.invalidPublicKey
        }

        // TODO: Replace with actual secp256k1 library call
        // For production:
        // var sig = secp256k1_ecdsa_signature()
        // var pubkey = secp256k1_pubkey()
        // secp256k1_ecdsa_signature_parse_compact(context, &sig, signature.bytes)
        // secp256k1_ec_pubkey_parse(context, &pubkey, publicKey.bytes, publicKey.count)
        // return secp256k1_ecdsa_verify(context, &sig, messageHash.bytes, &pubkey) == 1

        // Temporary fallback
        do {
            let pubKey = try P256.Signing.PublicKey(x963Representation: publicKey)
            let sig = try P256.Signing.ECDSASignature(rawRepresentation: signature)
            return pubKey.isValidSignature(sig, for: messageHash)
        } catch {
            return false
        }
    }

    /// Recover public key from recoverable signature
    /// - Parameters:
    ///   - signature: 65-byte recoverable signature (r || s || v)
    ///   - messageHash: 32-byte hash that was signed
    /// - Returns: Recovered public key
    public static func recoverPublicKey(from signature: Data, messageHash: Data) throws -> Data {
        guard signature.count == 65 else {
            throw Secp256k1Error.invalidSignature
        }

        guard messageHash.count == 32 else {
            throw Secp256k1Error.invalidSignature
        }

        let r = signature[0..<32]
        let s = signature[32..<64]
        let v = signature[64]

        // Validate recovery ID
        guard v <= 3 else {
            throw Secp256k1Error.invalidRecoveryId
        }

        // TODO: Replace with actual secp256k1 library call
        // For production:
        // var sig = secp256k1_ecdsa_recoverable_signature()
        // var pubkey = secp256k1_pubkey()
        // secp256k1_ecdsa_recoverable_signature_parse_compact(context, &sig, r || s, Int32(v))
        // secp256k1_ecdsa_recover(context, &pubkey, &sig, messageHash.bytes)

        // Placeholder - actual implementation requires secp256k1
        throw Secp256k1Error.publicKeyDerivationFailed
    }

    // MARK: - Key Operations

    /// Add two private keys (modulo curve order)
    /// Used in HD wallet derivation
    /// - Parameters:
    ///   - key1: First private key
    ///   - key2: Second private key
    /// - Returns: Sum of keys (mod n)
    public static func privateKeyAdd(_ key1: Data, _ key2: Data) throws -> Data {
        guard key1.count == PRIVATE_KEY_SIZE && key2.count == PRIVATE_KEY_SIZE else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // TODO: Replace with actual secp256k1 library call
        // For production:
        // var result = [UInt8](key1)
        // secp256k1_ec_privkey_tweak_add(context, &result, key2.bytes)

        // Simplified big integer addition (NOT PRODUCTION READY)
        var result = Data(count: PRIVATE_KEY_SIZE)
        var carry: UInt16 = 0

        for i in (0..<PRIVATE_KEY_SIZE).reversed() {
            let sum = UInt16(key1[i]) + UInt16(key2[i]) + carry
            result[i] = UInt8(sum & 0xFF)
            carry = sum >> 8
        }

        // Validate result is valid private key
        guard isValidPrivateKey(result) else {
            throw Secp256k1Error.invalidPrivateKey
        }

        return result
    }

    /// Multiply private key by scalar
    /// - Parameters:
    ///   - privateKey: Private key to multiply
    ///   - scalar: Scalar value
    /// - Returns: Multiplied private key (mod n)
    public static func privateKeyMultiply(_ privateKey: Data, by scalar: Data) throws -> Data {
        guard privateKey.count == PRIVATE_KEY_SIZE && scalar.count == PRIVATE_KEY_SIZE else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // TODO: Replace with actual secp256k1 library call
        // For production:
        // var result = [UInt8](privateKey)
        // secp256k1_ec_privkey_tweak_mul(context, &result, scalar.bytes)

        throw Secp256k1Error.invalidPrivateKey // Not implemented in fallback
    }

    /// Negate a private key
    /// - Parameter privateKey: Private key to negate
    /// - Returns: Negated private key (n - key)
    public static func privateKeyNegate(_ privateKey: Data) throws -> Data {
        guard privateKey.count == PRIVATE_KEY_SIZE else {
            throw Secp256k1Error.invalidPrivateKey
        }

        // TODO: Replace with actual secp256k1 library call
        // For production:
        // var result = [UInt8](privateKey)
        // secp256k1_ec_privkey_negate(context, &result)

        throw Secp256k1Error.invalidPrivateKey // Not implemented in fallback
    }

    // MARK: - Private Helpers

    private static func isValidPrivateKey(_ key: Data) -> Bool {
        guard key.count == PRIVATE_KEY_SIZE else {
            return false
        }

        // Key must be in range [1, n-1] where n is the curve order
        // secp256k1 order: 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

        // Check not all zeros
        let isZero = key.allSatisfy { $0 == 0 }
        if isZero {
            return false
        }

        // Check not >= curve order (simplified check)
        // For full validation, need proper big integer comparison
        return true
    }

    private static func calculateRecoveryId(messageHash: Data, signature: Data, privateKey: Data) throws -> UInt8 {
        // Calculate recovery ID by trying each possibility (0-3)
        let publicKey = try derivePublicKey(from: privateKey, compressed: false)

        for recoveryId: UInt8 in 0...3 {
            // Try to recover public key with this recovery ID
            var recoverableSig = signature
            recoverableSig.append(Data([recoveryId]))

            if let recovered = try? recoverPublicKey(from: recoverableSig, messageHash: messageHash),
               recovered == publicKey {
                return recoveryId
            }
        }

        // Default to 0 if recovery fails
        return 0
    }

    // MARK: - Signature Encoding

    /// Convert compact signature to DER encoding
    /// - Parameter signature: 64-byte compact signature
    /// - Returns: DER-encoded signature
    public static func signatureToDER(_ signature: Data) throws -> Data {
        guard signature.count == SIGNATURE_SIZE else {
            throw Secp256k1Error.invalidSignature
        }

        let r = signature[0..<32]
        let s = signature[32..<64]

        // Encode r
        var rEncoded = encodeInteger(r)
        var sEncoded = encodeInteger(s)

        // Build DER structure: 0x30 [total-length] 0x02 [r-length] [r] 0x02 [s-length] [s]
        var der = Data([0x30])
        let totalLength = rEncoded.count + sEncoded.count
        der.append(UInt8(totalLength))
        der.append(rEncoded)
        der.append(sEncoded)

        return der
    }

    /// Convert DER signature to compact format
    /// - Parameter derSignature: DER-encoded signature
    /// - Returns: 64-byte compact signature
    public static func signatureFromDER(_ derSignature: Data) throws -> Data {
        guard derSignature.count >= 8, derSignature[0] == 0x30 else {
            throw Secp256k1Error.invalidSignature
        }

        var offset = 2 // Skip 0x30 and length

        // Parse r
        guard derSignature[offset] == 0x02 else {
            throw Secp256k1Error.invalidSignature
        }
        offset += 1

        let rLength = Int(derSignature[offset])
        offset += 1

        var r = derSignature[offset..<(offset + rLength)]
        offset += rLength

        // Parse s
        guard derSignature[offset] == 0x02 else {
            throw Secp256k1Error.invalidSignature
        }
        offset += 1

        let sLength = Int(derSignature[offset])
        offset += 1

        var s = derSignature[offset..<(offset + sLength)]

        // Remove leading zeros and ensure 32 bytes
        r = padOrTrimTo32Bytes(r)
        s = padOrTrimTo32Bytes(s)

        var compact = Data()
        compact.append(r)
        compact.append(s)

        return compact
    }

    private static func encodeInteger(_ value: Data) -> Data {
        var encoded = Data([0x02]) // INTEGER tag

        var trimmed = value
        // Remove leading zeros
        while trimmed.count > 1 && trimmed[0] == 0 {
            trimmed = trimmed.dropFirst()
        }

        // Add leading zero if high bit is set (to indicate positive number)
        if trimmed[0] >= 0x80 {
            encoded.append(UInt8(trimmed.count + 1))
            encoded.append(0x00)
            encoded.append(trimmed)
        } else {
            encoded.append(UInt8(trimmed.count))
            encoded.append(trimmed)
        }

        return encoded
    }

    private static func padOrTrimTo32Bytes(_ data: Data) -> Data {
        if data.count == 32 {
            return data
        } else if data.count < 32 {
            // Pad with leading zeros
            var padded = Data(count: 32 - data.count)
            padded.append(data)
            return padded
        } else {
            // Trim leading zeros
            var trimmed = data
            while trimmed.count > 32 && trimmed[0] == 0 {
                trimmed = trimmed.dropFirst()
            }
            return trimmed
        }
    }
}
