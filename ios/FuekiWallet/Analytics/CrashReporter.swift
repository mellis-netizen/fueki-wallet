import Foundation
import UIKit

/// Crash reporting and exception handling
public class CrashReporter {

    // MARK: - Singleton
    public static let shared = CrashReporter()

    // MARK: - Properties
    private var breadcrumbs: [Breadcrumb] = []
    private let maxBreadcrumbs = 100
    private var customMetadata: [String: String] = [:]
    private let queue = DispatchQueue(label: "com.fueki.crashreporter", qos: .utility)

    private var isEnabled = false

    // MARK: - Initialization
    private init() {
        setupExceptionHandler()
        setupSignalHandler()
    }

    // MARK: - Configuration

    /// Initialize crash reporter
    /// This prepares the system for integration with Crashlytics/Sentry
    public func initialize() {
        isEnabled = true

        // TODO: Initialize Crashlytics when Firebase is integrated
        // FirebaseCrashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)

        // TODO: Initialize Sentry if using Sentry
        // SentrySDK.start { options in
        //     options.dsn = "YOUR_SENTRY_DSN"
        //     options.debug = true
        // }

        Logger.shared.log("Crash reporter initialized", level: .info, category: .crash)
        recordBreadcrumb("Crash reporter initialized", category: .system)
    }

    // MARK: - Breadcrumbs

    /// Record a breadcrumb for crash context
    /// - Parameters:
    ///   - message: Breadcrumb message
    ///   - category: Breadcrumb category
    ///   - level: Severity level
    ///   - metadata: Additional metadata
    public func recordBreadcrumb(
        _ message: String,
        category: BreadcrumbCategory,
        level: BreadcrumbLevel = .info,
        metadata: [String: String]? = nil
    ) {
        let breadcrumb = Breadcrumb(
            message: message,
            category: category,
            level: level,
            metadata: metadata
        )

        queue.async { [weak self] in
            guard let self = self else { return }

            self.breadcrumbs.append(breadcrumb)

            // Limit breadcrumbs
            if self.breadcrumbs.count > self.maxBreadcrumbs {
                self.breadcrumbs.removeFirst(self.breadcrumbs.count - self.maxBreadcrumbs)
            }

            // TODO: Log to Crashlytics
            // FirebaseCrashlytics.crashlytics().log(message)

            // TODO: Log to Sentry
            // let crumb = SentryBreadcrumb(level: .info, category: category.rawValue)
            // crumb.message = message
            // SentrySDK.addBreadcrumb(crumb: crumb)
        }
    }

    // MARK: - Custom Metadata

    /// Set custom key-value metadata for crash reports
    /// - Parameters:
    ///   - key: Metadata key
    ///   - value: Metadata value
    public func setCustomValue(_ value: String, forKey key: String) {
        queue.async { [weak self] in
            self?.customMetadata[key] = value

            // TODO: Set in Crashlytics
            // FirebaseCrashlytics.crashlytics().setCustomValue(value, forKey: key)

            // TODO: Set in Sentry
            // SentrySDK.setContext(value: ["value": value], key: key)
        }
    }

    /// Set user identifier (anonymized)
    /// - Parameter userId: User identifier
    public func setUserId(_ userId: String?) {
        queue.async {
            // TODO: Set in Crashlytics
            // FirebaseCrashlytics.crashlytics().setUserID(userId)

            // TODO: Set in Sentry
            // if let userId = userId {
            //     let user = Sentry.User(userId: userId)
            //     SentrySDK.setUser(user)
            // } else {
            //     SentrySDK.setUser(nil)
            // }
        }

        Logger.shared.log("Crash reporter user ID set", level: .debug, category: .crash)
    }

    // MARK: - Error Reporting

    /// Record a non-fatal error
    /// - Parameters:
    ///   - error: Error to record
    ///   - context: Additional context
    public func recordError(_ error: Error, context: String? = nil) {
        guard isEnabled else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            let errorInfo = self.buildErrorInfo(error: error, context: context)

            Logger.shared.log(
                "Non-fatal error: \(error.localizedDescription)",
                level: .error,
                category: .crash,
                metadata: errorInfo
            )

            // TODO: Record in Crashlytics
            // FirebaseCrashlytics.crashlytics().record(error: error)

            // TODO: Record in Sentry
            // SentrySDK.capture(error: error)
        }
    }

    /// Record a custom exception
    /// - Parameters:
    ///   - name: Exception name
    ///   - reason: Exception reason
    ///   - stackTrace: Stack trace
    public func recordException(name: String, reason: String, stackTrace: [String]? = nil) {
        guard isEnabled else { return }

        queue.async {
            Logger.shared.log(
                "Exception: \(name) - \(reason)",
                level: .critical,
                category: .crash
            )

            // TODO: Record in Crashlytics
            // let exceptionModel = ExceptionModel(name: name, reason: reason)
            // FirebaseCrashlytics.crashlytics().record(exceptionModel: exceptionModel)

            // TODO: Record in Sentry
            // let exception = Sentry.Exception(value: reason, type: name)
            // let event = Sentry.Event(level: .error)
            // event.exceptions = [exception]
            // SentrySDK.capture(event: event)
        }
    }

    // MARK: - Exception Handling

    private func setupExceptionHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
    }

    private func setupSignalHandler() {
        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGILL) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGFPE) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGBUS) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
    }

    private func handleException(_ exception: NSException) {
        let crashInfo = buildCrashInfo(exception: exception)

        // Log crash info
        Logger.shared.log(
            "Uncaught exception: \(exception.name.rawValue) - \(exception.reason ?? "No reason")",
            level: .critical,
            category: .crash,
            metadata: crashInfo
        )

        // Save crash info to disk
        saveCrashInfo(crashInfo)
    }

    private func handleSignal(_ signal: Int32) {
        let signalName = signalName(for: signal)

        Logger.shared.log(
            "Signal caught: \(signalName) (\(signal))",
            level: .critical,
            category: .crash
        )

        // Save crash info
        let crashInfo = buildSignalCrashInfo(signal: signal)
        saveCrashInfo(crashInfo)
    }

    // MARK: - Crash Info Building

    private func buildCrashInfo(exception: NSException) -> [String: String] {
        var info: [String: String] = [:]

        info["exception_name"] = exception.name.rawValue
        info["exception_reason"] = exception.reason ?? "Unknown"
        info["call_stack"] = exception.callStackSymbols.joined(separator: "\n")

        // Add breadcrumbs
        info["breadcrumbs"] = breadcrumbs.map { $0.description }.joined(separator: "\n")

        // Add custom metadata
        info.merge(customMetadata) { _, new in new }

        return info
    }

    private func buildSignalCrashInfo(signal: Int32) -> [String: String] {
        var info: [String: String] = [:]

        info["signal"] = "\(signal)"
        info["signal_name"] = signalName(for: signal)
        info["breadcrumbs"] = breadcrumbs.map { $0.description }.joined(separator: "\n")

        // Add custom metadata
        info.merge(customMetadata) { _, new in new }

        return info
    }

    private func buildErrorInfo(error: Error, context: String?) -> [String: String] {
        var info: [String: String] = [:]

        info["error"] = error.localizedDescription
        info["error_type"] = String(describing: type(of: error))

        if let context = context {
            info["context"] = context
        }

        // Add breadcrumbs
        let recentBreadcrumbs = breadcrumbs.suffix(10)
        info["recent_breadcrumbs"] = recentBreadcrumbs.map { $0.description }.joined(separator: "\n")

        return info
    }

    private func signalName(for signal: Int32) -> String {
        switch signal {
        case SIGSEGV: return "SIGSEGV"
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        default: return "UNKNOWN"
        }
    }

    // MARK: - Persistence

    private var crashInfoFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("crash_info.json")
    }

    private func saveCrashInfo(_ info: [String: String]) {
        guard let fileURL = crashInfoFileURL else { return }

        if let data = try? JSONSerialization.data(withJSONObject: info) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    /// Get last crash info if available
    public func getLastCrashInfo() -> [String: String]? {
        guard let fileURL = crashInfoFileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let info = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return nil
        }

        return info
    }

    /// Clear saved crash info
    public func clearCrashInfo() {
        guard let fileURL = crashInfoFileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - Supporting Types

public struct Breadcrumb {
    let timestamp: Date
    let message: String
    let category: BreadcrumbCategory
    let level: BreadcrumbLevel
    let metadata: [String: String]?

    init(
        message: String,
        category: BreadcrumbCategory,
        level: BreadcrumbLevel = .info,
        metadata: [String: String]? = nil
    ) {
        self.timestamp = Date()
        self.message = message
        self.category = category
        self.level = level
        self.metadata = metadata
    }

    var description: String {
        let dateFormatter = ISO8601DateFormatter()
        var desc = "[\(dateFormatter.string(from: timestamp))] [\(category.rawValue)] \(message)"
        if let metadata = metadata, !metadata.isEmpty {
            desc += " | \(metadata)"
        }
        return desc
    }
}

public enum BreadcrumbCategory: String {
    case navigation = "Navigation"
    case network = "Network"
    case ui = "UI"
    case user = "User"
    case system = "System"
    case state = "State"
    case transaction = "Transaction"
}

public enum BreadcrumbLevel {
    case debug
    case info
    case warning
    case error
}
