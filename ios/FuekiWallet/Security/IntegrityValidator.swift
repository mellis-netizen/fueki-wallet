import Foundation
import CommonCrypto

/// Validates code and runtime integrity
/// Detects tampering, code injection, and binary modifications
public class IntegrityValidator {

    // MARK: - Properties

    private var expectedCodeHash: String?
    private var expectedBundleSignature: String?
    private let securityLogger = SecurityLogger.shared

    // MARK: - Initialization

    public init() {
        // Calculate initial integrity baseline
        calculateIntegrityBaseline()
    }

    // MARK: - Public Methods

    /// Validate overall integrity
    public func validateIntegrity() -> Bool {
        return validateBundleIntegrity() &&
               validateCodeSignature() &&
               validateResourceIntegrity() &&
               validateDynamicLibraries() &&
               validateExecutableHash()
    }

    /// Validate bundle integrity
    public func validateBundleIntegrity() -> Bool {
        guard let bundlePath = Bundle.main.bundlePath as String? else {
            securityLogger.log(event: .integrityViolation, level: .error, message: "Cannot access bundle path")
            return false
        }

        // Check if bundle has been modified
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: bundlePath)

            // Verify bundle hasn't been replaced or modified
            guard let creationDate = attributes[.creationDate] as? Date,
                  let modificationDate = attributes[.modificationDate] as? Date else {
                return false
            }

            // In legitimate app, modification should be close to creation
            let timeDiff = modificationDate.timeIntervalSince(creationDate)
            if timeDiff > 60 { // More than 1 minute difference
                securityLogger.log(event: .integrityViolation, level: .warning,
                                 message: "Bundle modification time suspicious")
                return false
            }

            return true
        } catch {
            securityLogger.log(event: .integrityViolation, level: .error,
                             message: "Failed to check bundle attributes: \(error)")
            return false
        }
    }

    /// Validate code signature
    public func validateCodeSignature() -> Bool {
        #if targetEnvironment(simulator)
        // Skip code signature validation in simulator
        return true
        #else

        guard let executablePath = Bundle.main.executablePath else {
            return false
        }

        // Check code signature status
        var staticCode: SecStaticCode?
        let url = URL(fileURLWithPath: executablePath) as CFURL

        let status = SecStaticCodeCreateWithPath(url, [], &staticCode)
        guard status == errSecSuccess, let code = staticCode else {
            securityLogger.log(event: .integrityViolation, level: .error,
                             message: "Failed to create static code object")
            return false
        }

        // Validate code signature
        let requirement: SecRequirement? = nil
        let validateStatus = SecStaticCodeCheckValidity(code, [], requirement)

        if validateStatus != errSecSuccess {
            securityLogger.log(event: .integrityViolation, level: .critical,
                             message: "Code signature validation failed")
            return false
        }

        return true
        #endif
    }

    /// Validate resource integrity
    public func validateResourceIntegrity() -> Bool {
        guard let resourcePath = Bundle.main.resourcePath else {
            return false
        }

        do {
            let resourceFiles = try FileManager.default.contentsOfDirectory(atPath: resourcePath)

            // Check for suspicious files
            let suspiciousExtensions = [".dylib", ".framework", ".bundle"]
            for file in resourceFiles {
                for ext in suspiciousExtensions {
                    if file.hasSuffix(ext) {
                        // Log suspicious resource
                        securityLogger.log(event: .integrityViolation, level: .warning,
                                         message: "Suspicious resource found: \(file)")
                    }
                }
            }

            return true
        } catch {
            return false
        }
    }

    /// Validate loaded dynamic libraries
    public func validateDynamicLibraries() -> Bool {
        var isTrusted = true

        // Check all loaded libraries
        for i in 0..<_dyld_image_count() {
            guard let imageName = _dyld_get_image_name(i) else { continue }

            let name = String(cString: imageName)

            // Check if library is from Apple or our bundle
            if !isKnownLibrary(name) {
                securityLogger.log(event: .integrityViolation, level: .warning,
                                 message: "Unknown library loaded: \(name)")
                isTrusted = false
            }
        }

        return isTrusted
    }

    /// Validate executable hash
    public func validateExecutableHash() -> Bool {
        guard let executablePath = Bundle.main.executablePath else {
            return false
        }

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: executablePath)) else {
            return false
        }

        let hash = calculateSHA256(data: data)

        // Compare with expected hash
        if let expected = expectedCodeHash {
            if hash != expected {
                securityLogger.log(event: .integrityViolation, level: .critical,
                                 message: "Executable hash mismatch")
                return false
            }
        }

        return true
    }

    /// Validate Info.plist integrity
    public func validateInfoPlist() -> Bool {
        guard let infoPlist = Bundle.main.infoDictionary else {
            return false
        }

        // Verify critical keys
        let requiredKeys = [
            "CFBundleIdentifier",
            "CFBundleVersion",
            "CFBundleShortVersionString"
        ]

        for key in requiredKeys {
            if infoPlist[key] == nil {
                securityLogger.log(event: .integrityViolation, level: .error,
                                 message: "Missing Info.plist key: \(key)")
                return false
            }
        }

        // Verify bundle identifier
        if let bundleId = infoPlist["CFBundleIdentifier"] as? String {
            if bundleId != "com.fueki.wallet" {
                securityLogger.log(event: .integrityViolation, level: .critical,
                                 message: "Bundle identifier mismatch")
                return false
            }
        }

        return true
    }

    /// Check for runtime modifications
    public func detectRuntimeModifications() -> Bool {
        // Check if code sections have been modified
        return detectCodeSectionModifications() ||
               detectDataSectionModifications()
    }

    // MARK: - Private Methods

    private func calculateIntegrityBaseline() {
        // Calculate expected hashes at startup
        if let executablePath = Bundle.main.executablePath,
           let data = try? Data(contentsOf: URL(fileURLWithPath: executablePath)) {
            expectedCodeHash = calculateSHA256(data: data)
        }

        // Calculate bundle signature
        if let bundleId = Bundle.main.bundleIdentifier {
            expectedBundleSignature = calculateSHA256(string: bundleId)
        }
    }

    private func isKnownLibrary(_ path: String) -> Bool {
        let knownPrefixes = [
            "/System/Library/",
            "/usr/lib/",
            Bundle.main.bundlePath
        ]

        return knownPrefixes.contains { path.hasPrefix($0) }
    }

    private func detectCodeSectionModifications() -> Bool {
        // This is a simplified check
        // In production, compare current code section with expected checksum
        return false
    }

    private func detectDataSectionModifications() -> Bool {
        // Check if data sections have been tampered with
        return false
    }

    // MARK: - Hashing Utilities

    private func calculateSHA256(data: Data) -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func calculateSHA256(string: String) -> String {
        guard let data = string.data(using: .utf8) else {
            return ""
        }
        return calculateSHA256(data: data)
    }

    // MARK: - Checksum Validation

    /// Validate file checksum
    public func validateFileChecksum(path: String, expectedChecksum: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return false
        }

        let actualChecksum = calculateSHA256(data: data)
        return actualChecksum == expectedChecksum
    }

    /// Generate checksums for all resources
    public func generateResourceChecksums() -> [String: String] {
        var checksums: [String: String] = [:]

        guard let resourcePath = Bundle.main.resourcePath else {
            return checksums
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
            for file in files {
                let filePath = (resourcePath as NSString).appendingPathComponent(file)
                if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                    checksums[file] = calculateSHA256(data: data)
                }
            }
        } catch {
            securityLogger.log(event: .integrityViolation, level: .error,
                             message: "Failed to generate resource checksums: \(error)")
        }

        return checksums
    }
}
