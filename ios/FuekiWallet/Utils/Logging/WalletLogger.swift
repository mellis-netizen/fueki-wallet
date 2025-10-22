//
//  WalletLogger.swift
//  FuekiWallet
//
//  Comprehensive logging framework using OSLog
//

import Foundation
import os.log

/// Log levels matching OSLog severity
enum LogLevel: Int, Comparable, CaseIterable {
    case debug = 0
    case info = 1
    case notice = 2
    case warning = 3
    case error = 4
    case critical = 5

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .default
        case .warning: return .error
        case .error: return .error
        case .critical: return .fault
        }
    }

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .notice: return "📝"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Log categories for organized logging
enum LogCategory: String, CaseIterable {
    case general = "General"
    case network = "Network"
    case blockchain = "Blockchain"
    case security = "Security"
    case transaction = "Transaction"
    case persistence = "Persistence"
    case ui = "UI"
    case performance = "Performance"
    case analytics = "Analytics"
    case cryptography = "Cryptography"

    var subsystem: String {
        "com.fueki.wallet.\(rawValue.lowercased())"
    }
}

/// Main logger class
final class WalletLogger {
    static let shared = WalletLogger()

    private var loggers: [LogCategory: OSLog] = [:]
    private var minimumLogLevel: LogLevel
    private var isDebugMode: Bool
    private var logHistory: [LogEntry] = []
    private let historyLimit = 1000
    private let queue = DispatchQueue(label: "com.fueki.wallet.logger", qos: .utility)

    private init() {
        #if DEBUG
        self.isDebugMode = true
        self.minimumLogLevel = .debug
        #else
        self.isDebugMode = false
        self.minimumLogLevel = .info
        #endif

        setupLoggers()
    }

    private func setupLoggers() {
        for category in LogCategory.allCases {
            loggers[category] = OSLog(subsystem: category.subsystem, category: category.rawValue)
        }
    }

    // MARK: - Configuration

    func configure(minimumLevel: LogLevel, debugMode: Bool? = nil) {
        self.minimumLogLevel = minimumLevel
        if let debug = debugMode {
            self.isDebugMode = debug
        }
    }

    // MARK: - Public Logging Methods

    func debug(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .debug, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func info(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .info, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func notice(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .notice, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func warning(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .warning, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func error(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .error, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    func critical(
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: Any]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(message, level: .critical, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Specialized Logging

    func log(
        error: WalletErrorProtocol,
        severity: ErrorSeverity,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let level = mapSeverityToLogLevel(severity)
        let category = mapErrorCategoryToLogCategory(error.errorCategory)

        var metadata: [String: Any] = [
            "errorCode": error.errorCode,
            "errorCategory": error.errorCategory.rawValue
        ]

        if let details = error.technicalDetails {
            metadata["details"] = details
        }

        if let underlying = error.underlyingError {
            metadata["underlyingError"] = String(describing: underlying)
        }

        log(
            error.userMessage,
            level: level,
            category: category,
            metadata: metadata,
            file: file,
            function: function,
            line: line
        )
    }

    func logNetworkRequest(
        url: String,
        method: String,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) {
        var metadata: [String: Any] = [
            "url": url,
            "method": method
        ]

        if let headers = headers {
            metadata["headers"] = sanitizeHeaders(headers)
        }

        if let body = body, isDebugMode {
            metadata["bodySize"] = body.count
        }

        debug("Network request", category: .network, metadata: metadata)
    }

    func logNetworkResponse(
        url: String,
        statusCode: Int,
        responseTime: TimeInterval,
        bodySize: Int? = nil
    ) {
        var metadata: [String: Any] = [
            "url": url,
            "statusCode": statusCode,
            "responseTime": String(format: "%.3fs", responseTime)
        ]

        if let size = bodySize {
            metadata["bodySize"] = size
        }

        let level: LogLevel = statusCode >= 400 ? .error : .debug
        log("Network response", level: level, category: .network, metadata: metadata)
    }

    func logTransaction(
        hash: String,
        from: String,
        to: String,
        amount: String,
        status: String
    ) {
        let metadata: [String: Any] = [
            "hash": hash,
            "from": sanitizeAddress(from),
            "to": sanitizeAddress(to),
            "amount": amount,
            "status": status
        ]

        info("Transaction", category: .transaction, metadata: metadata)
    }

    func logPerformance(
        operation: String,
        duration: TimeInterval,
        metadata: [String: Any]? = nil
    ) {
        var fullMetadata = metadata ?? [:]
        fullMetadata["duration"] = String(format: "%.3fs", duration)
        fullMetadata["operation"] = operation

        let level: LogLevel = duration > 1.0 ? .warning : .debug
        log("Performance", level: level, category: .performance, metadata: fullMetadata)
    }

    // MARK: - Core Logging

    private func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) {
        guard level >= minimumLogLevel else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            let entry = LogEntry(
                message: message,
                level: level,
                category: category,
                metadata: metadata,
                file: self.extractFileName(from: file),
                function: function,
                line: line,
                timestamp: Date()
            )

            // Add to history
            self.addToHistory(entry)

            // Log to OSLog
            self.logToOSLog(entry)

            // Log to console in debug mode
            if self.isDebugMode {
                self.logToConsole(entry)
            }
        }
    }

    private func logToOSLog(_ entry: LogEntry) {
        guard let logger = loggers[entry.category] else { return }

        let logMessage = formatOSLogMessage(entry)
        os_log("%{public}@", log: logger, type: entry.level.osLogType, logMessage)
    }

    private func logToConsole(_ entry: LogEntry) {
        let formatted = formatConsoleMessage(entry)
        print(formatted)
    }

    // MARK: - Formatting

    private func formatOSLogMessage(_ entry: LogEntry) -> String {
        var components: [String] = [entry.message]

        if let metadata = entry.metadata, !metadata.isEmpty {
            let metadataString = formatMetadata(metadata)
            components.append(metadataString)
        }

        return components.joined(separator: " | ")
    }

    private func formatConsoleMessage(_ entry: LogEntry) -> String {
        let timestamp = dateFormatter.string(from: entry.timestamp)
        var components = [
            timestamp,
            entry.level.emoji,
            "[\(entry.category.rawValue)]",
            entry.message
        ]

        if let metadata = entry.metadata, !metadata.isEmpty {
            components.append(formatMetadata(metadata))
        }

        components.append("(\(entry.file):\(entry.line))")

        return components.joined(separator: " ")
    }

    private func formatMetadata(_ metadata: [String: Any]) -> String {
        metadata
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ", ")
    }

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    // MARK: - History Management

    private func addToHistory(_ entry: LogEntry) {
        logHistory.append(entry)

        if logHistory.count > historyLimit {
            logHistory.removeFirst(logHistory.count - historyLimit)
        }
    }

    func getHistory(
        level: LogLevel? = nil,
        category: LogCategory? = nil,
        limit: Int? = nil
    ) -> [LogEntry] {
        var filtered = logHistory

        if let level = level {
            filtered = filtered.filter { $0.level >= level }
        }

        if let category = category {
            filtered = filtered.filter { $0.category == category }
        }

        if let limit = limit {
            filtered = Array(filtered.suffix(limit))
        }

        return filtered
    }

    func clearHistory() {
        queue.async { [weak self] in
            self?.logHistory.removeAll()
        }
    }

    func exportLogs() -> String {
        logHistory
            .map { formatConsoleMessage($0) }
            .joined(separator: "\n")
    }

    // MARK: - Utility Methods

    private func extractFileName(from path: String) -> String {
        return (path as NSString).lastPathComponent
    }

    private func sanitizeHeaders(_ headers: [String: String]) -> [String: String] {
        var sanitized = headers
        let sensitiveKeys = ["authorization", "api-key", "x-api-key", "token"]

        for key in sensitiveKeys {
            if let _ = sanitized[key] {
                sanitized[key] = "***REDACTED***"
            }
        }

        return sanitized
    }

    private func sanitizeAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        let start = address.prefix(6)
        let end = address.suffix(4)
        return "\(start)...\(end)"
    }

    private func mapSeverityToLogLevel(_ severity: ErrorSeverity) -> LogLevel {
        switch severity {
        case .critical: return .critical
        case .high: return .error
        case .medium: return .warning
        case .low: return .notice
        case .info: return .info
        }
    }

    private func mapErrorCategoryToLogCategory(_ category: ErrorCategory) -> LogCategory {
        switch category {
        case .network: return .network
        case .blockchain: return .blockchain
        case .security: return .security
        case .transaction: return .transaction
        case .persistence: return .persistence
        case .cryptography: return .cryptography
        default: return .general
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable {
    let id = UUID()
    let message: String
    let level: LogLevel
    let category: LogCategory
    let metadata: [String: Any]?
    let file: String
    let function: String
    let line: Int
    let timestamp: Date
}

// MARK: - Convenience Extensions

extension WalletLogger {
    /// Measure execution time of a block
    func measure<T>(
        _ operation: String,
        category: LogCategory = .performance,
        block: () throws -> T
    ) rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logPerformance(operation: operation, duration: duration)
        }
        return try block()
    }

    /// Measure async execution time
    func measure<T>(
        _ operation: String,
        category: LogCategory = .performance,
        block: () async throws -> T
    ) async rethrows -> T {
        let start = Date()
        defer {
            let duration = Date().timeIntervalSince(start)
            logPerformance(operation: operation, duration: duration)
        }
        return try await block()
    }
}
