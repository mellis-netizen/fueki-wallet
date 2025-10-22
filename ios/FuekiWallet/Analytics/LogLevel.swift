import Foundation

/// Log level definitions for the logging system
public enum LogLevel: Int, Comparable, Codable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    public var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }

    public var description: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// Log category for organizing logs
public enum LogCategory: String, Codable {
    case general = "General"
    case network = "Network"
    case blockchain = "Blockchain"
    case wallet = "Wallet"
    case security = "Security"
    case ui = "UI"
    case storage = "Storage"
    case analytics = "Analytics"
    case performance = "Performance"
    case crash = "Crash"
}

/// Log metadata for additional context
public struct LogMetadata: Codable {
    public let timestamp: Date
    public let level: LogLevel
    public let category: LogCategory
    public let file: String
    public let function: String
    public let line: Int
    public let threadName: String
    public var additionalInfo: [String: String]?

    public init(
        timestamp: Date = Date(),
        level: LogLevel,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        threadName: String = Thread.current.name ?? "main",
        additionalInfo: [String: String]? = nil
    ) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.threadName = threadName
        self.additionalInfo = additionalInfo
    }
}
