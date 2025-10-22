import Foundation
import UIKit
import LocalAuthentication

/// Runtime security orchestrator that performs comprehensive security checks
/// Coordinates all security subsystems and provides a unified security interface
public class SecurityAuditor {

    // MARK: - Singleton

    public static let shared = SecurityAuditor()

    // MARK: - Properties

    private let jailbreakDetector: JailbreakDetector
    private let debuggerDetector: DebuggerDetector
    private let integrityValidator: IntegrityValidator
    private let antiTampering: AntiTampering
    private let securityLogger: SecurityLogger

    private var isInitialized = false
    private var lastAuditDate: Date?
    private var securityLevel: SecurityLevel = .unknown

    // MARK: - Types

    public enum SecurityLevel {
        case unknown
        case secure
        case warning
        case compromised
        case critical
    }

    public struct SecurityAuditResult {
        let level: SecurityLevel
        let timestamp: Date
        let jailbroken: Bool
        let debuggerAttached: Bool
        let integrityValid: Bool
        let tamperingDetected: Bool
        let threats: [SecurityThreat]

        var isPassed: Bool {
            level == .secure || level == .warning
        }

        var isDeviceSecure: Bool {
            !jailbroken && !debuggerAttached && integrityValid && !tamperingDetected
        }
    }

    public enum SecurityThreat: Equatable {
        case jailbroken
        case debuggerAttached
        case hookingDetected
        case integrityCompromised
        case tamperingDetected
        case insecureEnvironment
        case suspiciousProcess
        case unauthorizedCodeInjection

        var severity: Int {
            switch self {
            case .jailbroken, .debuggerAttached, .tamperingDetected:
                return 3 // Critical
            case .hookingDetected, .unauthorizedCodeInjection:
                return 2 // High
            case .integrityCompromised, .suspiciousProcess:
                return 1 // Medium
            case .insecureEnvironment:
                return 0 // Low
            }
        }
    }

    // MARK: - Initialization

    private init() {
        self.jailbreakDetector = JailbreakDetector()
        self.debuggerDetector = DebuggerDetector()
        self.integrityValidator = IntegrityValidator()
        self.antiTampering = AntiTampering()
        self.securityLogger = SecurityLogger.shared
    }

    // MARK: - Public Methods

    /// Initialize security systems and perform initial audit
    public func initialize() throws {
        guard !isInitialized else { return }

        securityLogger.log(event: .systemInitialized, level: .info, message: "Initializing security auditor")

        // Start anti-tampering monitoring
        antiTampering.startMonitoring()

        // Start debugger detection
        debuggerDetector.startMonitoring()

        // Perform initial audit
        let result = performSecurityAudit()

        if result.level == .critical {
            securityLogger.log(event: .criticalThreat, level: .critical, message: "Critical security threat detected")
            throw SecurityError.criticalThreatDetected(threats: result.threats)
        }

        isInitialized = true
        securityLogger.log(event: .systemInitialized, level: .info, message: "Security auditor initialized successfully")
    }

    /// Perform comprehensive security audit
    @discardableResult
    public func performSecurityAudit() -> SecurityAuditResult {
        var threats: [SecurityThreat] = []

        // Check jailbreak status
        let isJailbroken = jailbreakDetector.isJailbroken()
        if isJailbroken {
            threats.append(.jailbroken)
            securityLogger.log(event: .jailbreakDetected, level: .critical, message: "Jailbreak detected")
        }

        // Check debugger status
        let isDebuggerAttached = debuggerDetector.isDebuggerAttached()
        if isDebuggerAttached {
            threats.append(.debuggerAttached)
            securityLogger.log(event: .debuggerDetected, level: .critical, message: "Debugger attached")
        }

        // Check code integrity
        let isIntegrityValid = integrityValidator.validateIntegrity()
        if !isIntegrityValid {
            threats.append(.integrityCompromised)
            securityLogger.log(event: .integrityViolation, level: .error, message: "Code integrity compromised")
        }

        // Check for tampering
        let isTampered = antiTampering.detectTampering()
        if isTampered {
            threats.append(.tamperingDetected)
            securityLogger.log(event: .tamperingDetected, level: .critical, message: "Tampering detected")
        }

        // Check for hooking
        if antiTampering.detectHooking() {
            threats.append(.hookingDetected)
            securityLogger.log(event: .hookingDetected, level: .error, message: "Method hooking detected")
        }

        // Determine security level
        let level = calculateSecurityLevel(threats: threats)

        let result = SecurityAuditResult(
            level: level,
            timestamp: Date(),
            jailbroken: isJailbroken,
            debuggerAttached: isDebuggerAttached,
            integrityValid: isIntegrityValid,
            tamperingDetected: isTampered,
            threats: threats
        )

        lastAuditDate = Date()
        securityLevel = level

        return result
    }

    /// Verify current security status
    public func verifySecurityStatus() throws {
        let result = performSecurityAudit()

        guard result.isPassed else {
            throw SecurityError.securityCheckFailed(result: result)
        }
    }

    /// Check if device is secure for sensitive operations
    public func isDeviceSecure() -> Bool {
        let result = performSecurityAudit()
        return result.isDeviceSecure
    }

    /// Get current security level
    public func getCurrentSecurityLevel() -> SecurityLevel {
        return securityLevel
    }

    /// Perform runtime security check before sensitive operation
    public func performRuntimeCheck() throws {
        // Quick runtime checks
        if debuggerDetector.isDebuggerAttached() {
            securityLogger.log(event: .debuggerDetected, level: .critical, message: "Runtime check: Debugger detected")
            throw SecurityError.debuggerDetected
        }

        if antiTampering.detectRuntimeTampering() {
            securityLogger.log(event: .tamperingDetected, level: .critical, message: "Runtime check: Tampering detected")
            throw SecurityError.tamperingDetected
        }
    }

    /// Validate app environment is secure
    public func validateEnvironment() throws {
        let result = performSecurityAudit()

        if result.jailbroken {
            throw SecurityError.jailbrokenDevice
        }

        if result.debuggerAttached {
            throw SecurityError.debuggerDetected
        }

        if !result.integrityValid {
            throw SecurityError.integrityCheckFailed
        }
    }

    // MARK: - Private Methods

    private func calculateSecurityLevel(threats: [SecurityThreat]) -> SecurityLevel {
        if threats.isEmpty {
            return .secure
        }

        let maxSeverity = threats.map { $0.severity }.max() ?? 0

        switch maxSeverity {
        case 3:
            return .critical
        case 2:
            return .compromised
        case 1:
            return .warning
        default:
            return .secure
        }
    }

    // MARK: - Continuous Monitoring

    /// Start continuous security monitoring
    public func startContinuousMonitoring(interval: TimeInterval = 60.0) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performPeriodicCheck()
        }
    }

    private func performPeriodicCheck() {
        let result = performSecurityAudit()

        if result.level == .critical || result.level == .compromised {
            NotificationCenter.default.post(
                name: NSNotification.Name("SecurityThreatDetected"),
                object: nil,
                userInfo: ["result": result]
            )
        }
    }

    // MARK: - Reporting

    public func generateSecurityReport() -> String {
        let result = performSecurityAudit()

        var report = """
        === SECURITY AUDIT REPORT ===
        Date: \(result.timestamp)
        Security Level: \(result.level)

        STATUS CHECKS:
        - Jailbreak: \(result.jailbroken ? "❌ DETECTED" : "✅ PASSED")
        - Debugger: \(result.debuggerAttached ? "❌ DETECTED" : "✅ PASSED")
        - Integrity: \(result.integrityValid ? "✅ VALID" : "❌ INVALID")
        - Tampering: \(result.tamperingDetected ? "❌ DETECTED" : "✅ PASSED")

        """

        if !result.threats.isEmpty {
            report += "\nTHREATS DETECTED:\n"
            for threat in result.threats {
                report += "- \(threat) (Severity: \(threat.severity))\n"
            }
        }

        report += "\n=== END OF REPORT ===\n"

        return report
    }
}

// MARK: - Errors

public enum SecurityError: LocalizedError {
    case criticalThreatDetected(threats: [SecurityAuditor.SecurityThreat])
    case securityCheckFailed(result: SecurityAuditor.SecurityAuditResult)
    case jailbrokenDevice
    case debuggerDetected
    case tamperingDetected
    case integrityCheckFailed
    case insecureEnvironment

    public var errorDescription: String? {
        switch self {
        case .criticalThreatDetected(let threats):
            return "Critical security threat detected: \(threats)"
        case .securityCheckFailed(let result):
            return "Security check failed with level: \(result.level)"
        case .jailbrokenDevice:
            return "Device is jailbroken"
        case .debuggerDetected:
            return "Debugger attached to process"
        case .tamperingDetected:
            return "Application tampering detected"
        case .integrityCheckFailed:
            return "Code integrity check failed"
        case .insecureEnvironment:
            return "Insecure runtime environment"
        }
    }
}
