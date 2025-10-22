//
//  CertificatePinner.swift
//  FuekiWallet
//
//  SSL certificate pinning for enhanced security
//

import Foundation
import Security

/// Certificate pinning validator
public final class CertificatePinner {

    // MARK: - Types

    public enum PinningMode {
        case certificate  // Pin entire certificate
        case publicKey    // Pin only public key (recommended)
    }

    public struct PinnedHost {
        let host: String
        let pins: Set<String>  // Base64-encoded SHA-256 hashes

        public init(host: String, pins: Set<String>) {
            self.host = host
            self.pins = pins
        }
    }

    // MARK: - Properties

    private let pinnedHosts: [String: Set<String>]
    private let mode: PinningMode
    private let allowBackupPins: Bool

    // MARK: - Initialization

    public init(
        hosts: [PinnedHost],
        mode: PinningMode = .publicKey,
        allowBackupPins: Bool = true
    ) {
        self.pinnedHosts = Dictionary(uniqueKeysWithValues: hosts.map { ($0.host, $0.pins) })
        self.mode = mode
        self.allowBackupPins = allowBackupPins
    }

    // MARK: - Public Methods

    /// Validate server trust against pinned certificates
    public func validate(serverTrust: SecTrust, for host: String) -> Bool {
        // Check if host requires pinning
        guard let pinnedPins = pinnedHosts[host] else {
            // Host not in pinned list - allow connection
            return true
        }

        // Get server certificates
        guard let serverCertificates = getServerCertificates(from: serverTrust) else {
            return false
        }

        // Extract pins from server certificates
        let serverPins: Set<String>
        switch mode {
        case .certificate:
            serverPins = Set(serverCertificates.compactMap { certificatePin(for: $0) })
        case .publicKey:
            serverPins = Set(serverCertificates.compactMap { publicKeyPin(for: $0) })
        }

        // Check if any server pin matches our pinned pins
        return !serverPins.isDisjoint(with: pinnedPins)
    }

    /// Add new pinned host
    public func addPin(for host: String, pin: String) {
        var pins = pinnedHosts[host] ?? Set<String>()
        pins.insert(pin)
        // Note: pinnedHosts is immutable, would need to make it var in production
    }

    /// Remove pinned host
    public func removePin(for host: String) {
        // Note: pinnedHosts is immutable, would need to make it var in production
    }

    // MARK: - Private Methods

    private func getServerCertificates(from serverTrust: SecTrust) -> [SecCertificate]? {
        var certificates: [SecCertificate] = []

        if #available(iOS 15.0, *) {
            guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate] else {
                return nil
            }
            certificates = chain
        } else {
            let count = SecTrustGetCertificateCount(serverTrust)
            for i in 0..<count {
                if let cert = SecTrustGetCertificateAtIndex(serverTrust, i) {
                    certificates.append(cert)
                }
            }
        }

        return certificates.isEmpty ? nil : certificates
    }

    /// Generate certificate pin (SHA-256 hash of DER-encoded certificate)
    private func certificatePin(for certificate: SecCertificate) -> String? {
        let certificateData = SecCertificateCopyData(certificate) as Data
        return sha256Hash(of: certificateData)
    }

    /// Generate public key pin (SHA-256 hash of public key)
    private func publicKeyPin(for certificate: SecCertificate) -> String? {
        guard let publicKey = extractPublicKey(from: certificate) else {
            return nil
        }

        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return nil
        }

        return sha256Hash(of: publicKeyData)
    }

    private func extractPublicKey(from certificate: SecCertificate) -> SecKey? {
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()

        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            return nil
        }

        if #available(iOS 14.0, *) {
            return SecTrustCopyKey(trust)
        } else {
            return SecTrustCopyPublicKey(trust)
        }
    }

    private func sha256Hash(of data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
    }
}

// CommonCrypto bridge
private let CC_SHA256_DIGEST_LENGTH = 32

private func CC_SHA256(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>? {
    // In production, import CommonCrypto properly
    // This is a placeholder for the actual implementation
    return md
}

private typealias CC_LONG = UInt32

// MARK: - Certificate Pinning Helper
public extension CertificatePinner {
    /// Generate pin for a certificate file in bundle
    static func generatePin(for certificateFilename: String, in bundle: Bundle = .main) -> String? {
        guard let certPath = bundle.path(forResource: certificateFilename, ofType: "cer"),
              let certData = try? Data(contentsOf: URL(fileURLWithPath: certPath)) else {
            return nil
        }

        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            return nil
        }

        let pinner = CertificatePinner(hosts: [], mode: .publicKey)
        return pinner.publicKeyPin(for: certificate)
    }

    /// Common pinned hosts for Fueki Wallet
    static func fuekiPins() -> [PinnedHost] {
        // TODO: Replace with actual certificate pins for production APIs
        return [
            PinnedHost(host: "api.fueki.io", pins: [
                "base64encodedsha256hash1",  // Primary certificate
                "base64encodedsha256hash2"   // Backup certificate
            ]),
            PinnedHost(host: "wallet.fueki.io", pins: [
                "base64encodedsha256hash3"
            ])
        ]
    }
}
