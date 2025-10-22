import Foundation
import Security
import CryptoKit

/// SSL certificate pinning for enhanced security
final class CertificatePinner {

    private let pinnedCertificates: [String: Data]
    private let pinnedPublicKeyHashes: [String: Set<String>]

    init(certificates: [String: Data]) {
        self.pinnedCertificates = certificates
        self.pinnedPublicKeyHashes = certificates.mapValues { cert in
            Set(CertificatePinner.extractPublicKeyHashes(from: cert))
        }
    }

    /// Validate SSL challenge against pinned certificates
    func validate(challenge: URLAuthenticationChallenge) -> Bool {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust,
              let host = challenge.protectionSpace.host as String? else {
            return false
        }

        // If no pins for this host, allow connection
        guard let expectedHashes = pinnedPublicKeyHashes[host] else {
            return true
        }

        // Extract server certificate chain
        let certificateCount = SecTrustGetCertificateCount(serverTrust)
        guard certificateCount > 0 else { return false }

        // Check each certificate in the chain
        for index in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, index),
               let certificateData = SecCertificateCopyData(certificate) as Data? {

                let actualHashes = CertificatePinner.extractPublicKeyHashes(from: certificateData)

                // If any hash matches, validation succeeds
                if !expectedHashes.isDisjoint(with: actualHashes) {
                    return true
                }
            }
        }

        return false
    }

    /// Extract public key hashes from certificate data
    private static func extractPublicKeyHashes(from certificateData: Data) -> [String] {
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData),
              let publicKey = SecCertificateCopyKey(certificate) else {
            return []
        }

        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return []
        }

        // Generate SHA-256 hash of public key
        let hash = SHA256.hash(data: publicKeyData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        return [hashString]
    }
}

/// Certificate pinning configuration builder
struct CertificatePinningConfiguration {
    var pins: [String: Data] = [:]

    mutating func addCertificate(for host: String, certificateData: Data) {
        pins[host] = certificateData
    }

    mutating func addCertificate(for host: String, fromBundle bundleName: String) throws {
        guard let path = Bundle.main.path(forResource: bundleName, ofType: "cer"),
              let certificateData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw NetworkError.invalidURL("Certificate not found: \(bundleName)")
        }
        pins[host] = certificateData
    }

    func build() -> CertificatePinner {
        CertificatePinner(certificates: pins)
    }
}
