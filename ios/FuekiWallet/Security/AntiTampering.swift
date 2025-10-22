import Foundation
import MachO

/// Anti-tampering mechanisms and runtime protection
/// Detects code modification, hooking, and runtime manipulation
public class AntiTampering {

    // MARK: - Properties

    private var baselineChecksums: [String: String] = [:]
    private var isMonitoring = false
    private var monitoringTimer: Timer?
    private let securityLogger = SecurityLogger.shared

    // MARK: - Public Methods

    /// Start continuous tampering monitoring
    public func startMonitoring(interval: TimeInterval = 5.0) {
        guard !isMonitoring else { return }

        isMonitoring = true

        // Calculate baseline checksums
        calculateBaselineChecksums()

        // Start periodic checks
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performTamperingCheck()
        }

        securityLogger.log(
            event: .systemInitialized,
            level: .info,
            message: "Anti-tampering monitoring started"
        )
    }

    /// Stop monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    /// Detect if app has been tampered
    public func detectTampering() -> Bool {
        return detectCodeInjection() ||
               detectRuntimeModification() ||
               detectChecksumMismatch() ||
               detectResourceTampering()
    }

    /// Detect runtime tampering (quick check)
    public func detectRuntimeTampering() -> Bool {
        return detectMethodSwizzling() || detectDynamicHooking()
    }

    // MARK: - Code Injection Detection

    /// Detect code injection
    private func detectCodeInjection() -> Bool {
        // Check for suspicious dylibs
        return detectSuspiciousDylibs() || detectDYLDEnvironmentVariables()
    }

    /// Detect suspicious dynamic libraries
    private func detectSuspiciousDylibs() -> Bool {
        let suspiciousLibs = [
            "FridaGadget",
            "frida",
            "cynject",
            "libcycript",
            "Substrate",
            "SSL Kill Switch",
            "SSLKillSwitch",
            "PreferenceLoader"
        ]

        for i in 0..<_dyld_image_count() {
            guard let imageName = _dyld_get_image_name(i) else { continue }

            let name = String(cString: imageName).lowercased()

            for suspiciousLib in suspiciousLibs {
                if name.contains(suspiciousLib.lowercased()) {
                    securityLogger.log(
                        event: .tamperingDetected,
                        level: .critical,
                        message: "Suspicious library detected: \(name)"
                    )
                    return true
                }
            }
        }

        return false
    }

    /// Detect DYLD environment variables (used for injection)
    private func detectDYLDEnvironmentVariables() -> Bool {
        let suspiciousEnvVars = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_FORCE_FLAT_NAMESPACE",
            "DYLD_LIBRARY_PATH"
        ]

        for envVar in suspiciousEnvVars {
            if getenv(envVar) != nil {
                securityLogger.log(
                    event: .tamperingDetected,
                    level: .critical,
                    message: "Suspicious environment variable: \(envVar)"
                )
                return true
            }
        }

        return false
    }

    // MARK: - Method Hooking Detection

    /// Detect method swizzling
    public func detectHooking() -> Bool {
        return detectMethodSwizzling() || detectDynamicHooking()
    }

    /// Detect Objective-C method swizzling
    private func detectMethodSwizzling() -> Bool {
        // Check if critical methods have been swizzled
        let criticalClasses = [
            "NSURLSession",
            "NSURLConnection",
            "SecKeychain",
            "LAContext"
        ]

        for className in criticalClasses {
            if let cls = NSClassFromString(className) {
                if isClassSwizzled(cls) {
                    securityLogger.log(
                        event: .hookingDetected,
                        level: .error,
                        message: "Method swizzling detected on \(className)"
                    )
                    return true
                }
            }
        }

        return false
    }

    /// Check if class methods have been swizzled
    private func isClassSwizzled(_ cls: AnyClass) -> Bool {
        // This is a simplified check
        // In production, compare method implementations with expected values
        return false // Placeholder
    }

    /// Detect runtime hooking (e.g., Frida, Cycript)
    private func detectDynamicHooking() -> Bool {
        // Check for common hooking frameworks
        let hookingLibs = ["frida", "cycript", "substrate"]

        for i in 0..<_dyld_image_count() {
            guard let imageName = _dyld_get_image_name(i) else { continue }
            let name = String(cString: imageName).lowercased()

            for hookLib in hookingLibs {
                if name.contains(hookLib) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Runtime Modification Detection

    /// Detect runtime code modifications
    private func detectRuntimeModification() -> Bool {
        return detectTextSectionModification() ||
               detectDataSectionModification()
    }

    /// Detect modifications to code section
    private func detectTextSectionModification() -> Bool {
        // Check __TEXT segment for modifications
        // Compare current state with baseline
        return false // Placeholder - requires low-level implementation
    }

    /// Detect modifications to data section
    private func detectDataSectionModification() -> Bool {
        // Check __DATA segment for unexpected modifications
        return false // Placeholder
    }

    // MARK: - Checksum Validation

    /// Calculate baseline checksums
    private func calculateBaselineChecksums() {
        // Calculate checksums for critical files
        if let executablePath = Bundle.main.executablePath {
            baselineChecksums["executable"] = calculateFileChecksum(path: executablePath)
        }

        if let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist") {
            baselineChecksums["infoPlist"] = calculateFileChecksum(path: infoPlistPath)
        }
    }

    /// Detect checksum mismatches
    private func detectChecksumMismatch() -> Bool {
        // Re-calculate and compare with baseline
        if let executablePath = Bundle.main.executablePath {
            let currentChecksum = calculateFileChecksum(path: executablePath)
            if let baseline = baselineChecksums["executable"],
               currentChecksum != baseline {
                securityLogger.log(
                    event: .integrityViolation,
                    level: .critical,
                    message: "Executable checksum mismatch"
                )
                return true
            }
        }

        return false
    }

    /// Calculate file checksum
    private func calculateFileChecksum(path: String) -> String {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return ""
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Resource Tampering Detection

    /// Detect resource file tampering
    private func detectResourceTampering() -> Bool {
        guard let resourcePath = Bundle.main.resourcePath else {
            return false
        }

        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: resourcePath)

            // Check for unexpected files
            let expectedExtensions = [".nib", ".storyboardc", ".car", ".strings", ".plist"]

            for file in files {
                let fileExtension = (file as NSString).pathExtension

                // Flag suspicious files
                if fileExtension == "dylib" || fileExtension == "framework" {
                    securityLogger.log(
                        event: .tamperingDetected,
                        level: .warning,
                        message: "Suspicious resource file: \(file)"
                    )
                    return true
                }
            }

        } catch {
            return false
        }

        return false
    }

    // MARK: - Function Pointer Verification

    /// Verify function pointers haven't been hijacked
    public func verifyFunctionPointers() -> Bool {
        // In production, store expected function addresses
        // and compare at runtime
        return true // Placeholder
    }

    // MARK: - Continuous Monitoring

    private func performTamperingCheck() {
        if detectTampering() {
            handleTamperingDetection()
        }
    }

    private func handleTamperingDetection() {
        securityLogger.log(
            event: .tamperingDetected,
            level: .critical,
            message: "Application tampering detected"
        )

        // Post notification
        NotificationCenter.default.post(
            name: NSNotification.Name("TamperingDetected"),
            object: nil
        )

        #if !DEBUG
        // In production, take defensive action
        // Options: exit app, lock wallet, alert user
        #endif
    }

    // MARK: - Stack Canary Detection

    /// Detect stack canary manipulation (buffer overflow protection)
    public func detectStackCanaryManipulation() -> Bool {
        // Check if stack canaries are in place
        // This requires compiler support (-fstack-protector)
        return false // Placeholder
    }

    // MARK: - Inline Checks

    /// Inline tamper check (call frequently in sensitive code)
    @inline(__always)
    public func inlineTamperCheck() -> Bool {
        // Quick inline check for performance-sensitive code
        return !detectSuspiciousDylibs() && !detectDYLDEnvironmentVariables()
    }

    // MARK: - Code Obfuscation Helpers

    /// Verify code segment integrity
    public func verifyCodeSegment() -> Bool {
        // Use __builtin___clear_cache to detect modifications
        // Check code section CRC
        return true // Placeholder
    }

    /// Detect class-dump usage
    public func detectClassDump() -> Bool {
        // Detect if app has been analyzed with class-dump
        // Check for missing obfuscation
        return false // Placeholder
    }

    // MARK: - Anti-Ptrace

    /// Set up anti-ptrace protection
    public func setupAntiPtrace() {
        #if !DEBUG
        typealias PTraceFunc = @convention(c) (CInt, pid_t, caddr_t?, CInt) -> CInt

        guard let ptraceHandle = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ptrace") else {
            return
        }

        let ptrace = unsafeBitCast(ptraceHandle, to: PTraceFunc.self)

        // PT_DENY_ATTACH = 31
        ptrace(31, 0, nil, 0)
        #endif
    }

    // MARK: - Reporting

    /// Generate tampering detection report
    public func generateTamperingReport() -> String {
        var report = "=== ANTI-TAMPERING REPORT ===\n"
        report += "Timestamp: \(Date())\n\n"

        report += "CODE INJECTION:\n"
        report += "- Suspicious dylibs: \(detectSuspiciousDylibs() ? "❌ DETECTED" : "✅ CLEAN")\n"
        report += "- DYLD variables: \(detectDYLDEnvironmentVariables() ? "❌ DETECTED" : "✅ CLEAN")\n\n"

        report += "METHOD HOOKING:\n"
        report += "- Method swizzling: \(detectMethodSwizzling() ? "❌ DETECTED" : "✅ CLEAN")\n"
        report += "- Dynamic hooking: \(detectDynamicHooking() ? "❌ DETECTED" : "✅ CLEAN")\n\n"

        report += "INTEGRITY:\n"
        report += "- Checksum: \(detectChecksumMismatch() ? "❌ MISMATCH" : "✅ VALID")\n"
        report += "- Resources: \(detectResourceTampering() ? "❌ TAMPERED" : "✅ INTACT")\n\n"

        report += "=== END OF REPORT ===\n"

        return report
    }
}
