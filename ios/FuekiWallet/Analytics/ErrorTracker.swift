import Foundation

/// Error tracking and categorization system
public class ErrorTracker {

    // MARK: - Singleton
    public static let shared = ErrorTracker()

    // MARK: - Properties
    private var errorHistory: [TrackedError] = []
    private let maxErrorHistory = 100
    private let queue = DispatchQueue(label: "com.fueki.errortracker", qos: .utility)

    // MARK: - Initialization
    private init() {}

    // MARK: - Error Tracking

    /// Track an error
    /// - Parameters:
    ///   - error: The error to track
    ///   - category: Error category
    ///   - severity: Error severity
    ///   - context: Additional context
    ///   - metadata: Additional metadata
    public func track(
        error: Error,
        category: ErrorCategory,
        severity: ErrorSeverity = .medium,
        context: String? = nil,
        metadata: [String: String]? = nil
    ) {
        let trackedError = TrackedError(
            error: error,
            category: category,
            severity: severity,
            context: context,
            metadata: metadata
        )

        queue.async { [weak self] in
            guard let self = self else { return }

            // Add to history
            self.errorHistory.append(trackedError)
            if self.errorHistory.count > self.maxErrorHistory {
                self.errorHistory.removeFirst()
            }

            // Log the error
            self.logError(trackedError)

            // Report to crash reporter for severe errors
            if severity >= .high {
                CrashReporter.shared.recordError(error, context: context)
            }

            // Report to analytics
            AnalyticsManager.shared.track(
                .errorOccurred(
                    error: error.localizedDescription,
                    context: context ?? category.rawValue,
                    severity: severity
                )
            )
        }
    }

    /// Track a custom error message
    /// - Parameters:
    ///   - message: Error message
    ///   - category: Error category
    ///   - severity: Error severity
    ///   - context: Additional context
    public func track(
        message: String,
        category: ErrorCategory,
        severity: ErrorSeverity = .medium,
        context: String? = nil
    ) {
        let error = CustomError(message: message, category: category)
        track(error: error, category: category, severity: severity, context: context)
    }

    private func logError(_ trackedError: TrackedError) {
        let logLevel: LogLevel = {
            switch trackedError.severity {
            case .low: return .warning
            case .medium: return .error
            case .high: return .error
            case .critical: return .critical
            }
        }()

        var metadata: [String: String] = [
            "category": trackedError.category.rawValue,
            "severity": trackedError.severity.rawValue
        ]

        if let context = trackedError.context {
            metadata["context"] = context
        }

        if let additionalMetadata = trackedError.metadata {
            metadata.merge(additionalMetadata) { _, new in new }
        }

        Logger.shared.log(
            trackedError.error.localizedDescription,
            level: logLevel,
            category: .general,
            metadata: metadata
        )

        // Add breadcrumb
        let breadcrumbLevel: BreadcrumbLevel = {
            switch trackedError.severity {
            case .low: return .info
            case .medium: return .warning
            case .high, .critical: return .error
            }
        }()

        CrashReporter.shared.recordBreadcrumb(
            "Error: \(trackedError.error.localizedDescription)",
            category: .system,
            level: breadcrumbLevel
        )
    }

    // MARK: - Error Analysis

    /// Get error history
    /// - Parameter limit: Maximum number of errors to return
    /// - Returns: Array of tracked errors
    public func getErrorHistory(limit: Int? = nil) -> [TrackedError] {
        return queue.sync {
            if let limit = limit {
                return Array(errorHistory.suffix(limit))
            }
            return errorHistory
        }
    }

    /// Get errors by category
    /// - Parameter category: Error category to filter by
    /// - Returns: Array of tracked errors in the category
    public func getErrors(for category: ErrorCategory) -> [TrackedError] {
        return queue.sync {
            errorHistory.filter { $0.category == category }
        }
    }

    /// Get errors by severity
    /// - Parameter severity: Error severity to filter by
    /// - Returns: Array of tracked errors with the severity
    public func getErrors(withSeverity severity: ErrorSeverity) -> [TrackedError] {
        return queue.sync {
            errorHistory.filter { $0.severity == severity }
        }
    }

    /// Get error statistics
    /// - Returns: Error statistics
    public func getStatistics() -> ErrorStatistics {
        return queue.sync {
            var stats = ErrorStatistics()

            for error in errorHistory {
                stats.totalErrors += 1

                switch error.severity {
                case .low: stats.lowSeverityCount += 1
                case .medium: stats.mediumSeverityCount += 1
                case .high: stats.highSeverityCount += 1
                case .critical: stats.criticalSeverityCount += 1
                }

                stats.errorsByCategory[error.category, default: 0] += 1
            }

            return stats
        }
    }

    /// Clear error history
    public func clearHistory() {
        queue.async { [weak self] in
            self?.errorHistory.removeAll()
        }
    }
}

// MARK: - Supporting Types

/// Tracked error with metadata
public struct TrackedError {
    public let id: UUID
    public let timestamp: Date
    public let error: Error
    public let category: ErrorCategory
    public let severity: ErrorSeverity
    public let context: String?
    public let metadata: [String: String]?

    init(
        error: Error,
        category: ErrorCategory,
        severity: ErrorSeverity,
        context: String?,
        metadata: [String: String]?
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.error = error
        self.category = category
        self.severity = severity
        self.context = context
        self.metadata = metadata
    }
}

/// Error category
public enum ErrorCategory: String {
    case network = "Network"
    case blockchain = "Blockchain"
    case wallet = "Wallet"
    case security = "Security"
    case storage = "Storage"
    case validation = "Validation"
    case ui = "UI"
    case unknown = "Unknown"
}

/// Custom error type
public struct CustomError: Error, LocalizedError {
    public let message: String
    public let category: ErrorCategory

    public var errorDescription: String? {
        return message
    }
}

/// Error statistics
public struct ErrorStatistics {
    public var totalErrors: Int = 0
    public var lowSeverityCount: Int = 0
    public var mediumSeverityCount: Int = 0
    public var highSeverityCount: Int = 0
    public var criticalSeverityCount: Int = 0
    public var errorsByCategory: [ErrorCategory: Int] = [:]
}
