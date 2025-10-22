import Foundation
import Security
import CommonCrypto

/// SSL/TLS Certificate Pinning implementation
/// Prevents man-in-the-middle attacks by validating server certificates
public class CertificatePinning: NSObject {

    // MARK: - Types

    public enum PinningMode {
        case certificate    // Pin entire certificate
        case publicKey      // Pin public key only (more flexible)
        case both           // Pin both certificate and public key
    }

    public struct PinnedHost {
        let domain: String
        let certificates: [Data]
        let publicKeyHashes: [String]
        let mode: PinningMode

        init(domain: String,
             certificates: [Data] = [],
             publicKeyHashes: [String] = [],
             mode: PinningMode = .publicKey) {
            self.domain = domain
            self.certificates = certificates
            self.publicKeyHashes = publicKeyHashes
            self.mode = mode
        }
    }

    // MARK: - Properties

    private var pinnedHosts: [String: PinnedHost] = [:]
    private let securityLogger = SecurityLogger.shared

    // MARK: - Singleton

    public static let shared = CertificatePinning()

    private override init() {
        super.init()
        configurePinnedHosts()
    }

    // MARK: - Configuration

    /// Configure pinned hosts
    private func configurePinnedHosts() {
        // Example: Pin Fueki API server
        // In production, load these from secure configuration
        addPinnedHost(
            domain: "api.fueki.io",
            publicKeyHashes: [
                "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", // Replace with actual hash
                "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB="  // Backup key
            ],
            mode: .publicKey
        )

        // Pin blockchain RPC endpoints
        addPinnedHost(
            domain: "mainnet.infura.io",
            publicKeyHashes: [
                "sha256/CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC="
            ],
            mode: .publicKey
        )
    }

    /// Add pinned host
    public func addPinnedHost(domain: String,
                             certificates: [Data] = [],
                             publicKeyHashes: [String] = [],
                             mode: PinningMode = .publicKey) {
        let host = PinnedHost(
            domain: domain,
            certificates: certificates,
            publicKeyHashes: publicKeyHashes,
            mode: mode
        )
        pinnedHosts[domain] = host
    }

    // MARK: - Certificate Validation

    /// Validate server trust for URL session
    public func validate(serverTrust: SecTrust, domain: String?) -> Bool {
        guard let domain = domain,
              let pinnedHost = pinnedHosts[domain] else {
            // No pinning configured for this domain
            securityLogger.log(
                event: .certificateValidation,
                level: .warning,
                message: "No pinning configured for domain: \(domain ?? "unknown")"
            )
            return true // Allow connection (or return false for strict mode)
        }

        // Validate based on pinning mode
        switch pinnedHost.mode {
        case .certificate:
            return validateCertificate(serverTrust: serverTrust, pinnedHost: pinnedHost)

        case .publicKey:
            return validatePublicKey(serverTrust: serverTrust, pinnedHost: pinnedHost)

        case .both:
            return validateCertificate(serverTrust: serverTrust, pinnedHost: pinnedHost) &&
                   validatePublicKey(serverTrust: serverTrust, pinnedHost: pinnedHost)
        }
    }

    // MARK: - Certificate Validation Methods

    /// Validate certificate pinning
    private func validateCertificate(serverTrust: SecTrust, pinnedHost: PinnedHost) -> Bool {
        guard !pinnedHost.certificates.isEmpty else { return false }

        // Get server certificate chain
        let serverCertificates = extractCertificates(from: serverTrust)

        // Check if any server certificate matches pinned certificates
        for serverCert in serverCertificates {
            for pinnedCert in pinnedHost.certificates {
                if serverCert == pinnedCert {
                    securityLogger.log(
                        event: .certificateValidation,
                        level: .info,
                        message: "Certificate pinning validated for \(pinnedHost.domain)"
                    )
                    return true
                }
            }
        }

        securityLogger.log(
            event: .certificateValidation,
            level: .error,
            message: "Certificate pinning failed for \(pinnedHost.domain)"
        )
        return false
    }

    /// Validate public key pinning
    private func validatePublicKey(serverTrust: SecTrust, pinnedHost: PinnedHost) -> Bool {
        guard !pinnedHost.publicKeyHashes.isEmpty else { return false }

        // Extract public keys from server certificates
        let serverPublicKeyHashes = extractPublicKeyHashes(from: serverTrust)

        // Check if any server public key matches pinned keys
        for serverHash in serverPublicKeyHashes {
            if pinnedHost.publicKeyHashes.contains(serverHash) {
                securityLogger.log(
                    event: .certificateValidation,
                    level: .info,
                    message: "Public key pinning validated for \(pinnedHost.domain)"
                )
                return true
            }
        }

        securityLogger.log(
            event: .certificateValidation,
            level: .error,
            message: "Public key pinning failed for \(pinnedHost.domain)"
        )
        return false
    }

    // MARK: - Certificate Extraction

    /// Extract certificates from server trust
    private func extractCertificates(from serverTrust: SecTrust) -> [Data] {
        var certificates: [Data] = []

        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i) {
                let certData = SecCertificateCopyData(certificate) as Data
                certificates.append(certData)
            }
        }

        return certificates
    }

    /// Extract public key hashes from server trust
    private func extractPublicKeyHashes(from serverTrust: SecTrust) -> [String] {
        var hashes: [String] = []

        let certificateCount = SecTrustGetCertificateCount(serverTrust)

        for i in 0..<certificateCount {
            if let certificate = SecTrustGetCertificateAtIndex(serverTrust, i),
               let publicKey = extractPublicKey(from: certificate) {
                let hash = hashPublicKey(publicKey)
                hashes.append(hash)
            }
        }

        return hashes
    }

    /// Extract public key from certificate
    private func extractPublicKey(from certificate: SecCertificate) -> SecKey? {
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()

        let status = SecTrustCreateWithCertificates(certificate, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            return nil
        }

        return SecTrustCopyKey(trust)
    }

    /// Hash public key using SHA-256
    private func hashPublicKey(_ publicKey: SecKey) -> String {
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, nil) as Data? else {
            return ""
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        publicKeyData.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(publicKeyData.count), &hash)
        }

        let base64Hash = Data(hash).base64EncodedString()
        return "sha256/\(base64Hash)"
    }

    // MARK: - Helper Methods

    /// Load certificate from bundle
    public static func loadCertificate(filename: String, bundle: Bundle = .main) -> Data? {
        guard let certPath = bundle.path(forResource: filename, ofType: "cer") else {
            return nil
        }

        return try? Data(contentsOf: URL(fileURLWithPath: certPath))
    }

    /// Generate public key hash from certificate file
    public static func generatePublicKeyHash(certificateData: Data) -> String? {
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            return nil
        }

        let pinning = CertificatePinning.shared
        guard let publicKey = pinning.extractPublicKey(from: certificate) else {
            return nil
        }

        return pinning.hashPublicKey(publicKey)
    }

    // MARK: - Reporting

    /// Get pinned hosts summary
    public func getPinnedHostsSummary() -> String {
        var summary = "=== CERTIFICATE PINNING CONFIGURATION ===\n"

        for (domain, host) in pinnedHosts {
            summary += "\nDomain: \(domain)\n"
            summary += "Mode: \(host.mode)\n"
            summary += "Certificates: \(host.certificates.count)\n"
            summary += "Public Key Hashes: \(host.publicKeyHashes.count)\n"
        }

        return summary
    }
}

// MARK: - URLSessionDelegate Integration

/// URLSession delegate for certificate pinning
public class PinningURLSessionDelegate: NSObject, URLSessionDelegate {

    public func urlSession(_ session: URLSession,
                          didReceive challenge: URLAuthenticationChallenge,
                          completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        let domain = challenge.protectionSpace.host

        // Validate certificate pinning
        if CertificatePinning.shared.validate(serverTrust: serverTrust, domain: domain) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            // Pinning validation failed
            SecurityLogger.shared.log(
                event: .certificateValidation,
                level: .critical,
                message: "Certificate pinning validation failed for \(domain)"
            )
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

// MARK: - Usage Example

/*
 // 1. Configure pinned hosts
 CertificatePinning.shared.addPinnedHost(
     domain: "api.example.com",
     publicKeyHashes: [
         "sha256/AAAAAAAAAA...",
         "sha256/BBBBBBBBBB..."
     ],
     mode: .publicKey
 )

 // 2. Create URLSession with pinning delegate
 let configuration = URLSessionConfiguration.default
 let delegate = PinningURLSessionDelegate()
 let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

 // 3. Make request
 let url = URL(string: "https://api.example.com/endpoint")!
 let task = session.dataTask(with: url) { data, response, error in
     // Handle response
 }
 task.resume()
 */
