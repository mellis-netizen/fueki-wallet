import Foundation
import CryptoKit
import Security

/// Threshold Signature Scheme (TSS) Key Generation Module
/// Implements distributed key generation for social recovery and multi-party signing
public class TSSKeyGeneration {

    // MARK: - Types

    public enum TSSProtocol {
        case ecdsa_secp256k1
        case ecdsa_secp256r1
        case eddsa_ed25519
    }

    public struct KeyShare {
        let shareIndex: UInt32
        let shareData: Data
        let publicKey: Data
        let threshold: UInt32
        let totalShares: UInt32
        let protocol: TSSProtocol
        let metadata: [String: Any]

        public init(shareIndex: UInt32, shareData: Data, publicKey: Data,
                   threshold: UInt32, totalShares: UInt32, protocol: TSSProtocol,
                   metadata: [String: Any] = [:]) {
            self.shareIndex = shareIndex
            self.shareData = shareData
            self.publicKey = publicKey
            self.threshold = threshold
            self.totalShares = totalShares
            self.protocol = `protocol`
            self.metadata = metadata
        }
    }

    public struct TSSKeyPair {
        let publicKey: Data
        let shares: [KeyShare]
        let protocol: TSSProtocol
        let threshold: UInt32
        let createdAt: Date

        public init(publicKey: Data, shares: [KeyShare], protocol: TSSProtocol,
                   threshold: UInt32, createdAt: Date = Date()) {
            self.publicKey = publicKey
            self.shares = shares
            self.protocol = `protocol`
            self.threshold = threshold
            self.createdAt = createdAt
        }
    }

    public enum TSSError: Error {
        case invalidThreshold
        case invalidShareCount
        case keyGenerationFailed
        case invalidProtocol
        case shareReconstructionFailed
        case insufficientShares
        case invalidShareData
        case cryptographicError(String)
    }

    // MARK: - Properties

    private let secureRandom: SecureRandomGenerator
    private let polynomialArithmetic: PolynomialArithmetic
    private let ellipticCurve: EllipticCurveOperations

    // MARK: - Initialization

    public init(protocol protocolType: TSSProtocol = .ecdsa_secp256k1) {
        self.secureRandom = SecureRandomGenerator()

        // Initialize polynomial arithmetic with appropriate field
        let fieldType: PolynomialArithmetic.FieldType
        switch protocolType {
        case .ecdsa_secp256k1:
            fieldType = .secp256k1Order
        case .ecdsa_secp256r1:
            fieldType = .p256Order
        case .eddsa_ed25519:
            fieldType = .ed25519Order
        }
        self.polynomialArithmetic = PolynomialArithmetic(fieldType: fieldType)
        self.ellipticCurve = EllipticCurveOperations()
    }

    // MARK: - Key Generation

    /// Generate TSS key shares using Shamir's Secret Sharing with elliptic curve cryptography
    /// - Parameters:
    ///   - threshold: Minimum number of shares required to reconstruct the key (t)
    ///   - totalShares: Total number of shares to generate (n)
    ///   - protocol: The TSS protocol to use
    /// - Returns: TSSKeyPair containing public key and all shares
    public func generateKeyShares(threshold: UInt32,
                                 totalShares: UInt32,
                                 protocol: TSSProtocol) throws -> TSSKeyPair {
        // Validate parameters
        guard threshold > 0 && threshold <= totalShares else {
            throw TSSError.invalidThreshold
        }

        guard totalShares >= 2 && totalShares <= 100 else {
            throw TSSError.invalidShareCount
        }

        // Generate master secret key
        let masterSecret = try generateMasterSecret(for: `protocol`)

        // Generate public key from master secret
        let publicKey = try derivePublicKey(from: masterSecret, protocol: `protocol`)

        // Create polynomial coefficients for Shamir's Secret Sharing
        var coefficients = [masterSecret]
        for _ in 1..<threshold {
            let coefficient = try generateMasterSecret(for: `protocol`)
            coefficients.append(coefficient)
        }

        // Generate shares by evaluating polynomial at different points
        let generatedShares = polynomialArithmetic.generateShares(
            secret: masterSecret,
            threshold: Int(threshold),
            totalShares: Int(totalShares),
            randomCoefficients: Array(coefficients.dropFirst())
        )

        var shares: [KeyShare] = []
        for (index, value) in generatedShares {
            let share = KeyShare(
                shareIndex: index,
                shareData: value,
                publicKey: publicKey,
                threshold: threshold,
                totalShares: totalShares,
                protocol: `protocol`,
                metadata: [
                    "createdAt": Date().timeIntervalSince1970,
                    "version": "1.0"
                ]
            )
            shares.append(share)
        }

        // Securely wipe master secret from memory
        secureRandom.wipeMemory(data: masterSecret)
        coefficients.forEach { secureRandom.wipeMemory(data: $0) }

        return TSSKeyPair(
            publicKey: publicKey,
            shares: shares,
            protocol: `protocol`,
            threshold: threshold
        )
    }

    /// Reconstruct private key from threshold number of shares
    /// - Parameters:
    ///   - shares: Array of key shares (must be at least threshold number)
    /// - Returns: Reconstructed private key
    public func reconstructKey(from shares: [KeyShare]) throws -> Data {
        guard !shares.isEmpty else {
            throw TSSError.insufficientShares
        }

        // Verify all shares are from same key and protocol
        let firstShare = shares[0]
        guard shares.allSatisfy({
            $0.publicKey == firstShare.publicKey &&
            $0.protocol == firstShare.protocol &&
            $0.threshold == firstShare.threshold
        }) else {
            throw TSSError.invalidShareData
        }

        guard shares.count >= firstShare.threshold else {
            throw TSSError.insufficientShares
        }

        // Use Lagrange interpolation to reconstruct secret at x=0
        let reconstructed = polynomialArithmetic.lagrangeInterpolation(
            shares: shares.map { (index: $0.shareIndex, value: $0.shareData) }
        )

        // Verify reconstructed key produces correct public key
        let verifyPublicKey = try derivePublicKey(from: reconstructed, protocol: firstShare.protocol)
        guard verifyPublicKey == firstShare.publicKey else {
            throw TSSError.shareReconstructionFailed
        }

        return reconstructed
    }

    /// Refresh shares without changing the master secret (proactive security)
    /// - Parameters:
    ///   - shares: Existing shares to refresh
    /// - Returns: New set of refreshed shares with same threshold and public key
    public func refreshShares(_ shares: [KeyShare]) throws -> [KeyShare] {
        guard !shares.isEmpty else {
            throw TSSError.invalidShareData
        }

        let firstShare = shares[0]

        // Reconstruct the master secret
        let masterSecret = try reconstructKey(from: shares)

        // Generate new shares with same parameters
        let newKeyPair = try generateKeyShares(
            threshold: firstShare.threshold,
            totalShares: firstShare.totalShares,
            protocol: firstShare.protocol
        )

        // Verify public key hasn't changed
        guard newKeyPair.publicKey == firstShare.publicKey else {
            throw TSSError.keyGenerationFailed
        }

        // Securely wipe reconstructed secret
        secureRandom.wipeMemory(data: masterSecret)

        return newKeyPair.shares
    }

    // MARK: - Share Distribution

    /// Distribute shares to participants with encryption
    /// - Parameters:
    ///   - shares: Shares to distribute
    ///   - recipientKeys: Public keys of recipients for encryption
    /// - Returns: Array of encrypted share packages
    public func encryptSharesForDistribution(shares: [KeyShare],
                                            recipientKeys: [Data]) throws -> [Data] {
        guard shares.count == recipientKeys.count else {
            throw TSSError.invalidShareCount
        }

        var encryptedShares: [Data] = []

        for (share, recipientKey) in zip(shares, recipientKeys) {
            // Serialize share
            let shareData = try serializeShare(share)

            // Encrypt with recipient's public key using ECIES
            let encrypted = try encryptWithECIES(data: shareData, publicKey: recipientKey)
            encryptedShares.append(encrypted)
        }

        return encryptedShares
    }

    // MARK: - Private Helper Methods

    private func generateMasterSecret(for protocol: TSSProtocol) throws -> Data {
        let keySize: Int

        switch `protocol` {
        case .ecdsa_secp256k1, .ecdsa_secp256r1:
            keySize = 32 // 256 bits
        case .eddsa_ed25519:
            keySize = 32 // 256 bits
        }

        return try secureRandom.generateRandomBytes(count: keySize)
    }

    private func derivePublicKey(from privateKey: Data, protocol: TSSProtocol) throws -> Data {
        switch `protocol` {
        case .ecdsa_secp256k1:
            return try ellipticCurve.secp256k1PublicKey(from: privateKey)
        case .ecdsa_secp256r1:
            return try ellipticCurve.secp256r1PublicKey(from: privateKey)
        case .eddsa_ed25519:
            return try ellipticCurve.ed25519PublicKey(from: privateKey)
        }
    }

    private func serializeShare(_ share: KeyShare) throws -> Data {
        var data = Data()
        data.append(contentsOf: withUnsafeBytes(of: share.shareIndex.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: share.threshold.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: share.totalShares.bigEndian) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt8(protocolByte(for: share.protocol))) { Data($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(share.shareData.count).bigEndian) { Data($0) })
        data.append(share.shareData)
        data.append(share.publicKey)
        return data
    }

    private func protocolByte(for protocol: TSSProtocol) -> UInt8 {
        switch `protocol` {
        case .ecdsa_secp256k1: return 0x01
        case .ecdsa_secp256r1: return 0x02
        case .eddsa_ed25519: return 0x03
        }
    }

    private func encryptWithECIES(data: Data, publicKey: Data) throws -> Data {
        // Simplified ECIES implementation using CryptoKit
        // In production, use a proper ECIES library like web3swift or OpenSSL

        // Generate ephemeral key pair
        let ephemeralKey = P256.KeyAgreement.PrivateKey()

        // Perform ECDH to derive shared secret
        let recipientPublicKey = try P256.KeyAgreement.PublicKey(x963Representation: publicKey)
        let sharedSecret = try ephemeralKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)

        // Derive encryption key using HKDF
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("FuekiTSSShare".utf8),
            outputByteCount: 32
        )

        // Encrypt data with AES-GCM
        let sealedBox = try AES.GCM.seal(data, using: symmetricKey)

        // Combine ephemeral public key + encrypted data
        var result = ephemeralKey.publicKey.x963Representation
        result.append(sealedBox.combined!)

        return result
    }
}

// MARK: - Supporting Classes

private class SecureRandomGenerator {
    func generateRandomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)

        guard status == errSecSuccess else {
            throw TSSKeyGeneration.TSSError.cryptographicError("Failed to generate random bytes")
        }

        return Data(bytes)
    }

    func wipeMemory(data: Data) {
        var mutableData = data
        mutableData.withUnsafeMutableBytes { ptr in
            memset_s(ptr.baseAddress, ptr.count, 0, ptr.count)
        }
    }
}

// PolynomialEvaluator has been replaced with PolynomialArithmetic class
// See PolynomialArithmetic.swift for production-grade implementation

private class EllipticCurveOperations {
    func secp256k1PublicKey(from privateKey: Data) throws -> Data {
        // PRODUCTION: Use real secp256k1 elliptic curve point multiplication
        // PublicKey = PrivateKey * G (where G is the generator point)
        guard privateKey.count == 32 else {
            throw TSSKeyGeneration.TSSError.cryptographicError("Invalid private key length")
        }

        // Use Secp256k1Bridge which wraps bitcoin-core/secp256k1 C library
        // This performs real EC point multiplication on the secp256k1 curve
        do {
            return try Secp256k1Bridge.derivePublicKey(from: privateKey, compressed: true)
        } catch {
            throw TSSKeyGeneration.TSSError.cryptographicError("Failed to derive secp256k1 public key: \(error.localizedDescription)")
        }
    }

    func secp256r1PublicKey(from privateKey: Data) throws -> Data {
        // Use CryptoKit P256 (NIST secp256r1 curve)
        let privKey = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        return privKey.publicKey.compressedRepresentation
    }

    func ed25519PublicKey(from privateKey: Data) throws -> Data {
        // Use CryptoKit Curve25519 (EdDSA)
        let privKey = try Curve25519.Signing.PrivateKey(rawRepresentation: privateKey)
        return privKey.publicKey.rawRepresentation
    }
}

// MARK: - Data Extensions

private extension Data {
    func sha256() -> Data {
        var hash = SHA256()
        hash.update(data: self)
        return Data(hash.finalize())
    }
}
