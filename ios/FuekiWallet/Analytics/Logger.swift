import Foundation
import os.log

/// Logging infrastructure for the Fueki Wallet
public class Logger {

    // MARK: - Singleton
    public static let shared = Logger()

    // MARK: - Properties
    private let queue = DispatchQueue(label: "com.fueki.logger", qos: .utility)
    private var logFileURL: URL?
    private let maxLogFileSize: UInt64 = 10 * 1024 * 1024 // 10MB
    private let maxLogFiles = 5

    public var minimumLogLevel: LogLevel = {
        #if DEBUG
        return .debug
        #else
        return .info
        #endif
    }()

    private var consoleLoggingEnabled = true
    private var fileLoggingEnabled = true

    // MARK: - Initialization
    private init() {
        setupLogFile()
    }

    private func setupLogFile() {
        let fileManager = FileManager.default

        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let logsDirectory = documentsPath.appendingPathComponent("Logs", isDirectory: true)

        // Create logs directory if it doesn't exist
        if !fileManager.fileExists(atPath: logsDirectory.path) {
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        logFileURL = logsDirectory.appendingPathComponent("fueki-\(dateString).log")

        // Rotate logs if needed
        rotateLogs()
    }

    // MARK: - Logging Methods

    /// Log a message
    /// - Parameters:
    ///   - message: Message to log
    ///   - level: Log level
    ///   - category: Log category
    ///   - file: Source file
    ///   - function: Source function
    ///   - line: Source line number
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLogLevel else { return }

        let metadata = LogMetadata(
            level: level,
            category: category,
            file: file,
            function: function,
            line: line
        )

        queue.async { [weak self] in
            self?.processLog(message: message, metadata: metadata)
        }
    }

    /// Log with additional metadata
    /// - Parameters:
    ///   - message: Message to log
    ///   - level: Log level
    ///   - category: Log category
    ///   - metadata: Additional metadata
    ///   - file: Source file
    ///   - function: Source function
    ///   - line: Source line number
    public func log(
        _ message: String,
        level: LogLevel,
        category: LogCategory,
        metadata: [String: String],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLogLevel else { return }

        var logMetadata = LogMetadata(
            level: level,
            category: category,
            file: file,
            function: function,
            line: line
        )
        logMetadata.additionalInfo = metadata

        queue.async { [weak self] in
            self?.processLog(message: message, metadata: logMetadata)
        }
    }

    private func processLog(message: String, metadata: LogMetadata) {
        let formattedMessage = formatLogMessage(message: message, metadata: metadata)

        // Console logging
        if consoleLoggingEnabled {
            logToConsole(formattedMessage, level: metadata.level)
        }

        // File logging
        if fileLoggingEnabled {
            logToFile(formattedMessage)
        }

        // Critical logs go to remote logger
        if metadata.level >= .error {
            RemoteLogger.shared.log(message: message, metadata: metadata)
        }
    }

    private func formatLogMessage(message: String, metadata: LogMetadata) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let timestamp = dateFormatter.string(from: metadata.timestamp)

        var formatted = "\(timestamp) [\(metadata.level.description)] [\(metadata.category.rawValue)] "
        formatted += "[\(metadata.file):\(metadata.line)] \(metadata.function) - \(message)"

        if let additionalInfo = metadata.additionalInfo, !additionalInfo.isEmpty {
            formatted += " | Metadata: \(additionalInfo)"
        }

        return formatted
    }

    private func logToConsole(_ message: String, level: LogLevel) {
        #if DEBUG
        print("\(level.emoji) \(message)")
        #else
        if level >= .warning {
            NSLog("\(level.emoji) \(message)")
        }
        #endif
    }

    private func logToFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }

        let logLine = message + "\n"

        if let data = logLine.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()

                    // Check file size for rotation
                    checkLogFileSize()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }
        }
    }

    // MARK: - Log Management

    private func checkLogFileSize() {
        guard let logFileURL = logFileURL else { return }

        if let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let fileSize = attributes[.size] as? UInt64,
           fileSize > maxLogFileSize {
            rotateLogs()
        }
    }

    private func rotateLogs() {
        guard let logFileURL = logFileURL,
              let logsDirectory = logFileURL.deletingLastPathComponent() as URL? else {
            return
        }

        let fileManager = FileManager.default

        do {
            let logFiles = try fileManager.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { file1, file2 in
                    let date1 = try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let date2 = try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return (date1 ?? Date.distantPast) > (date2 ?? Date.distantPast)
                }

            // Remove oldest logs if we exceed max count
            if logFiles.count >= maxLogFiles {
                let filesToDelete = logFiles.dropFirst(maxLogFiles - 1)
                for file in filesToDelete {
                    try? fileManager.removeItem(at: file)
                }
            }
        } catch {
            print("Error rotating logs: \(error)")
        }
    }

    /// Get all log files
    public func getLogFiles() -> [URL] {
        guard let logFileURL = logFileURL,
              let logsDirectory = logFileURL.deletingLastPathComponent() as URL? else {
            return []
        }

        do {
            return try FileManager.default.contentsOfDirectory(at: logsDirectory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "log" }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch {
            return []
        }
    }

    /// Clear all log files
    public func clearLogs() {
        let logFiles = getLogFiles()
        for file in logFiles {
            try? FileManager.default.removeItem(at: file)
        }
        setupLogFile()
    }

    // MARK: - Configuration

    public func setConsoleLogging(enabled: Bool) {
        consoleLoggingEnabled = enabled
    }

    public func setFileLogging(enabled: Bool) {
        fileLoggingEnabled = enabled
    }
}

// MARK: - Convenience Extensions

public extension Logger {
    func verbose(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .verbose, category: category, file: file, function: function, line: line)
    }

    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }

    func critical(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
}
