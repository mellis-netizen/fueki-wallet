import Foundation
import os.log

/// Centralized security event logging system
/// Tracks security events, threats, and audits
public class SecurityLogger {

    // MARK: - Singleton

    public static let shared = SecurityLogger()

    // MARK: - Types

    public enum SecurityEvent: String {
        // System Events
        case systemInitialized = "SYSTEM_INITIALIZED"
        case systemShutdown = "SYSTEM_SHUTDOWN"
        case memoryPressure = "MEMORY_PRESSURE"

        // Security Threats
        case jailbreakDetected = "JAILBREAK_DETECTED"
        case debuggerDetected = "DEBUGGER_DETECTED"
        case tamperingDetected = "TAMPERING_DETECTED"
        case hookingDetected = "HOOKING_DETECTED"
        case integrityViolation = "INTEGRITY_VIOLATION"
        case criticalThreat = "CRITICAL_THREAT"

        // Authentication Events
        case authenticationSuccess = "AUTHENTICATION_SUCCESS"
        case authenticationFailure = "AUTHENTICATION_FAILURE"
        case biometricAuthSuccess = "BIOMETRIC_AUTH_SUCCESS"
        case biometricAuthFailure = "BIOMETRIC_AUTH_FAILURE"
        case passcodeAuthSuccess = "PASSCODE_AUTH_SUCCESS"
        case passcodeAuthFailure = "PASSCODE_AUTH_FAILURE"

        // Cryptographic Events
        case keyGenerated = "KEY_GENERATED"
        case keyStored = "KEY_STORED"
        case keyRetrieved = "KEY_RETRIEVED"
        case keyDeleted = "KEY_DELETED"
        case encryptionSuccess = "ENCRYPTION_SUCCESS"
        case decryptionSuccess = "DECRYPTION_SUCCESS"
        case encryptionFailure = "ENCRYPTION_FAILURE"
        case decryptionFailure = "DECRYPTION_FAILURE"

        // Network Events
        case networkRequestMade = "NETWORK_REQUEST_MADE"
        case certificateValidation = "CERTIFICATE_VALIDATION"
        case certificatePinningFailed = "CERTIFICATE_PINNING_FAILED"
        case tlsHandshakeSuccess = "TLS_HANDSHAKE_SUCCESS"
        case tlsHandshakeFailure = "TLS_HANDSHAKE_FAILURE"

        // Transaction Events
        case transactionSigned = "TRANSACTION_SIGNED"
        case transactionBroadcast = "TRANSACTION_BROADCAST"
        case transactionConfirmed = "TRANSACTION_CONFIRMED"
        case transactionFailed = "TRANSACTION_FAILED"

        // Access Control
        case unauthorizedAccess = "UNAUTHORIZED_ACCESS"
        case permissionDenied = "PERMISSION_DENIED"
        case accessGranted = "ACCESS_GRANTED"

        // Data Protection
        case sensitiveDataAccessed = "SENSITIVE_DATA_ACCESSED"
        case sensitiveDataModified = "SENSITIVE_DATA_MODIFIED"
        case sensitiveDataDeleted = "SENSITIVE_DATA_DELETED"
        case dataWiped = "DATA_WIPED"
    }

    public enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }

        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }

    public struct SecurityLogEntry {
        let timestamp: Date
        let event: SecurityEvent
        let level: LogLevel
        let message: String
        let context: [String: Any]?

        func formatted() -> String {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let timeString = dateFormatter.string(from: timestamp)

            var log = "\(level.emoji) [\(timeString)] [\(level)] \(event.rawValue)"
            log += "\n   Message: \(message)"

            if let context = context, !context.isEmpty {
                log += "\n   Context: \(context)"
            }

            return log
        }
    }

    // MARK: - Properties

    private let osLog = OSLog(subsystem: "com.fueki.wallet", category: "Security")
    private var logEntries: [SecurityLogEntry] = []
    private let maxLogEntries = 1000
    private let logQueue = DispatchQueue(label: "com.fueki.security.logger", qos: .utility)
    private var logFileURL: URL?

    // MARK: - Configuration

    public var minimumLogLevel: LogLevel = .info
    public var enableConsoleLogging = true
    public var enableFileLogging = true
    public var enableOSLogging = true

    // MARK: - Initialization

    private init() {
        setupLogFile()
        setupNotificationObservers()
    }

    private func setupLogFile() {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let logsDirectory = documentsPath.appendingPathComponent("SecurityLogs", isDirectory: true)

            if !FileManager.default.fileExists(atPath: logsDirectory.path) {
                try FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
            }

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())

            logFileURL = logsDirectory.appendingPathComponent("security-\(dateString).log")
        } catch {
            print("Failed to setup log file: \(error)")
        }
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppTermination),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    // MARK: - Logging Methods

    /// Log security event
    public func log(event: SecurityEvent,
                   level: LogLevel,
                   message: String,
                   context: [String: Any]? = nil) {

        guard level.rawValue >= minimumLogLevel.rawValue else { return }

        let entry = SecurityLogEntry(
            timestamp: Date(),
            event: event,
            level: level,
            message: message,
            context: context
        )

        logQueue.async { [weak self] in
            self?.processLogEntry(entry)
        }
    }

    private func processLogEntry(_ entry: SecurityLogEntry) {
        // Store in memory
        logEntries.append(entry)
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst()
        }

        // Console logging
        if enableConsoleLogging {
            print(entry.formatted())
        }

        // OS log
        if enableOSLogging {
            os_log("%{public}@", log: osLog, type: entry.level.osLogType, entry.formatted())
        }

        // File logging
        if enableFileLogging {
            writeToFile(entry)
        }

        // Alert for critical events
        if entry.level == .critical {
            handleCriticalEvent(entry)
        }
    }

    // MARK: - File Writing

    private func writeToFile(_ entry: SecurityLogEntry) {
        guard let fileURL = logFileURL else { return }

        let logLine = entry.formatted() + "\n"

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: fileURL)
            }
        }
    }

    // MARK: - Query Methods

    /// Get recent log entries
    public func getRecentLogs(count: Int = 100) -> [SecurityLogEntry] {
        return Array(logEntries.suffix(count))
    }

    /// Get logs by event type
    public func getLogs(forEvent event: SecurityEvent) -> [SecurityLogEntry] {
        return logEntries.filter { $0.event == event }
    }

    /// Get logs by level
    public func getLogs(forLevel level: LogLevel) -> [SecurityLogEntry] {
        return logEntries.filter { $0.level == level }
    }

    /// Get logs in time range
    public func getLogs(from startDate: Date, to endDate: Date) -> [SecurityLogEntry] {
        return logEntries.filter { entry in
            entry.timestamp >= startDate && entry.timestamp <= endDate
        }
    }

    // MARK: - Statistics

    /// Get security statistics
    public func getSecurityStatistics() -> SecurityStatistics {
        var stats = SecurityStatistics()

        for entry in logEntries {
            switch entry.level {
            case .critical:
                stats.criticalCount += 1
            case .error:
                stats.errorCount += 1
            case .warning:
                stats.warningCount += 1
            case .info:
                stats.infoCount += 1
            case .debug:
                stats.debugCount += 1
            }

            // Count threats
            switch entry.event {
            case .jailbreakDetected, .debuggerDetected, .tamperingDetected,
                 .hookingDetected, .integrityViolation, .criticalThreat:
                stats.threatCount += 1
            case .authenticationFailure, .biometricAuthFailure, .passcodeAuthFailure:
                stats.authFailureCount += 1
            default:
                break
            }
        }

        stats.totalEvents = logEntries.count
        return stats
    }

    // MARK: - Event Handling

    @objc private func handleMemoryWarning() {
        log(event: .memoryPressure, level: .warning, message: "Memory warning received")

        // Clear old logs
        if logEntries.count > 500 {
            logEntries.removeFirst(logEntries.count - 500)
        }
    }

    @objc private func handleAppTermination() {
        log(event: .systemShutdown, level: .info, message: "Application terminating")
        flushLogs()
    }

    private func handleCriticalEvent(_ entry: SecurityLogEntry) {
        // Post notification for critical events
        NotificationCenter.default.post(
            name: NSNotification.Name("CriticalSecurityEvent"),
            object: nil,
            userInfo: ["entry": entry]
        )
    }

    // MARK: - Log Management

    /// Flush logs to disk
    public func flushLogs() {
        logQueue.sync {
            // All logs are written immediately, but this ensures completion
        }
    }

    /// Clear all logs
    public func clearLogs() {
        logQueue.async { [weak self] in
            self?.logEntries.removeAll()

            if let fileURL = self?.logFileURL {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        log(event: .dataWiped, level: .info, message: "Security logs cleared")
    }

    /// Export logs
    public func exportLogs() -> String {
        return logEntries.map { $0.formatted() }.joined(separator: "\n\n")
    }

    /// Export logs to file
    public func exportLogs(to url: URL) throws {
        let logsString = exportLogs()
        try logsString.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Reporting

    /// Generate security report
    public func generateSecurityReport() -> String {
        let stats = getSecurityStatistics()

        var report = """
        === SECURITY LOG REPORT ===
        Generated: \(Date())

        STATISTICS:
        - Total Events: \(stats.totalEvents)
        - Critical: \(stats.criticalCount)
        - Errors: \(stats.errorCount)
        - Warnings: \(stats.warningCount)
        - Info: \(stats.infoCount)
        - Debug: \(stats.debugCount)

        SECURITY:
        - Threats Detected: \(stats.threatCount)
        - Auth Failures: \(stats.authFailureCount)

        """

        // Recent critical events
        let criticalEvents = getLogs(forLevel: .critical).suffix(10)
        if !criticalEvents.isEmpty {
            report += "\nRECENT CRITICAL EVENTS:\n"
            for event in criticalEvents {
                report += event.formatted() + "\n"
            }
        }

        report += "\n=== END OF REPORT ===\n"

        return report
    }
}

// MARK: - Supporting Types

public struct SecurityStatistics {
    public var totalEvents = 0
    public var criticalCount = 0
    public var errorCount = 0
    public var warningCount = 0
    public var infoCount = 0
    public var debugCount = 0
    public var threatCount = 0
    public var authFailureCount = 0
}

// MARK: - Convenience Extensions

extension SecurityLogger {
    /// Quick log methods
    public func debug(_ message: String, event: SecurityEvent = .systemInitialized) {
        log(event: event, level: .debug, message: message)
    }

    public func info(_ message: String, event: SecurityEvent = .systemInitialized) {
        log(event: event, level: .info, message: message)
    }

    public func warning(_ message: String, event: SecurityEvent = .systemInitialized) {
        log(event: event, level: .warning, message: message)
    }

    public func error(_ message: String, event: SecurityEvent = .systemInitialized) {
        log(event: event, level: .error, message: message)
    }

    public func critical(_ message: String, event: SecurityEvent = .criticalThreat) {
        log(event: event, level: .critical, message: message)
    }
}
