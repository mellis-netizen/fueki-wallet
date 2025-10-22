//
//  CrashReporter.swift
//  FuekiWallet
//
//  Crash reporting and recovery system
//

import Foundation
import UIKit

/// Crash report structure
struct CrashReport: Codable {
    let id: UUID
    let timestamp: Date
    let exception: ExceptionInfo
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let stackTrace: [String]
    let breadcrumbs: [Breadcrumb]
    let metadata: [String: String]

    struct ExceptionInfo: Codable {
        let name: String
        let reason: String?
        let userInfo: [String: String]?
    }

    struct Breadcrumb: Codable {
        let timestamp: Date
        let category: String
        let message: String
        let level: String
    }
}

/// Crash reporter singleton
final class CrashReporter {
    static let shared = CrashReporter()

    private let logger = WalletLogger.shared
    private var breadcrumbs: [CrashReport.Breadcrumb] = []
    private let maxBreadcrumbs = 50
    private let crashReportsDirectory: URL
    private let queue = DispatchQueue(label: "com.fueki.wallet.crashreporter", qos: .utility)

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        crashReportsDirectory = documentsPath.appendingPathComponent("CrashReports", isDirectory: true)

        setupCrashReportsDirectory()
        setupExceptionHandling()
    }

    // MARK: - Setup

    private func setupCrashReportsDirectory() {
        if !FileManager.default.fileExists(atPath: crashReportsDirectory.path) {
            try? FileManager.default.createDirectory(
                at: crashReportsDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func setupExceptionHandling() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }

        // Handle signals
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGILL) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGFPE) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGBUS) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
        signal(SIGPIPE) { signal in
            CrashReporter.shared.handleSignal(signal)
        }
    }

    // MARK: - Breadcrumbs

    func leaveBreadcrumb(
        category: String,
        message: String,
        level: String = "info"
    ) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let breadcrumb = CrashReport.Breadcrumb(
                timestamp: Date(),
                category: category,
                message: message,
                level: level
            )

            self.breadcrumbs.append(breadcrumb)

            // Maintain max breadcrumbs
            if self.breadcrumbs.count > self.maxBreadcrumbs {
                self.breadcrumbs.removeFirst(self.breadcrumbs.count - self.maxBreadcrumbs)
            }
        }
    }

    // MARK: - Exception Handling

    private func handleException(_ exception: NSException) {
        logger.critical("Uncaught exception", metadata: [
            "name": exception.name.rawValue,
            "reason": exception.reason ?? "Unknown"
        ])

        let report = createCrashReport(
            name: exception.name.rawValue,
            reason: exception.reason,
            stackTrace: exception.callStackSymbols,
            userInfo: exception.userInfo as? [String: String]
        )

        saveCrashReport(report)
        notifyCrash(report)
    }

    private func handleSignal(_ signal: Int32) {
        logger.critical("Signal received", metadata: [
            "signal": signal
        ])

        let signalName = signalName(for: signal)
        let report = createCrashReport(
            name: "Signal: \(signalName)",
            reason: "Application received signal \(signal)",
            stackTrace: Thread.callStackSymbols,
            userInfo: nil
        )

        saveCrashReport(report)
        notifyCrash(report)
    }

    private func signalName(for signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        default: return "UNKNOWN(\(signal))"
        }
    }

    // MARK: - Crash Report Creation

    private func createCrashReport(
        name: String,
        reason: String?,
        stackTrace: [String],
        userInfo: [String: String]?
    ) -> CrashReport {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let osVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model

        var metadata: [String: String] = [:]
        metadata["locale"] = Locale.current.identifier
        metadata["timezone"] = TimeZone.current.identifier
        metadata["freeMemory"] = "\(getFreeMemory()) MB"
        metadata["freeDiskSpace"] = "\(getFreeDiskSpace()) MB"

        return CrashReport(
            id: UUID(),
            timestamp: Date(),
            exception: CrashReport.ExceptionInfo(
                name: name,
                reason: reason,
                userInfo: userInfo
            ),
            appVersion: appVersion,
            osVersion: osVersion,
            deviceModel: deviceModel,
            stackTrace: stackTrace,
            breadcrumbs: breadcrumbs,
            metadata: metadata
        )
    }

    // MARK: - Crash Report Persistence

    private func saveCrashReport(_ report: CrashReport) {
        let filename = "crash_\(report.id.uuidString).json"
        let fileURL = crashReportsDirectory.appendingPathComponent(filename)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            let data = try encoder.encode(report)
            try data.write(to: fileURL)

            logger.info("Crash report saved", metadata: [
                "filename": filename
            ])
        } catch {
            logger.error("Failed to save crash report", metadata: [
                "error": error.localizedDescription
            ])
        }
    }

    func getPendingCrashReports() -> [CrashReport] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: crashReportsDirectory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }

        return files.compactMap { url in
            guard url.pathExtension == "json" else { return nil }

            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                return try decoder.decode(CrashReport.self, from: data)
            } catch {
                logger.error("Failed to load crash report", metadata: [
                    "url": url.path,
                    "error": error.localizedDescription
                ])
                return nil
            }
        }
    }

    func deleteCrashReport(_ report: CrashReport) {
        let filename = "crash_\(report.id.uuidString).json"
        let fileURL = crashReportsDirectory.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: fileURL)
    }

    func deleteAllCrashReports() {
        if let files = try? FileManager.default.contentsOfDirectory(
            at: crashReportsDirectory,
            includingPropertiesForKeys: nil
        ) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    // MARK: - Crash Notification

    private func notifyCrash(_ report: CrashReport) {
        NotificationCenter.default.post(
            name: .crashOccurred,
            object: nil,
            userInfo: ["report": report]
        )
    }

    // MARK: - System Information

    private func getFreeMemory() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        return Int(info.resident_size) / 1024 / 1024
    }

    private func getFreeDiskSpace() -> Int {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Int(capacity) / 1024 / 1024
            }
        } catch {
            logger.error("Failed to get disk space", metadata: [
                "error": error.localizedDescription
            ])
        }
        return 0
    }
}

// MARK: - Crash Recovery

final class CrashRecoveryManager {
    static let shared = CrashRecoveryManager()

    private let crashReporter = CrashReporter.shared
    private let logger = WalletLogger.shared
    private let userDefaults = UserDefaults.standard

    private let lastCrashTimeKey = "lastCrashTime"
    private let consecutiveCrashCountKey = "consecutiveCrashCount"
    private let crashRecoveryModeKey = "crashRecoveryMode"

    private init() {}

    func checkForCrashes() {
        let reports = crashReporter.getPendingCrashReports()

        guard !reports.isEmpty else {
            resetConsecutiveCrashCount()
            return
        }

        logger.warning("Found \(reports.count) pending crash reports")

        incrementConsecutiveCrashCount()
        recordLastCrashTime()

        if shouldEnterRecoveryMode() {
            enterRecoveryMode()
        }

        // Upload reports if analytics enabled
        uploadCrashReports(reports)
    }

    private func shouldEnterRecoveryMode() -> Bool {
        let consecutiveCrashes = getConsecutiveCrashCount()
        return consecutiveCrashes >= 3
    }

    private func enterRecoveryMode() {
        logger.critical("Entering crash recovery mode")
        userDefaults.set(true, forKey: crashRecoveryModeKey)

        // Could implement:
        // - Reset to safe defaults
        // - Clear caches
        // - Disable problematic features
        // - Show recovery UI
    }

    func exitRecoveryMode() {
        logger.info("Exiting crash recovery mode")
        userDefaults.set(false, forKey: crashRecoveryModeKey)
        resetConsecutiveCrashCount()
    }

    func isInRecoveryMode() -> Bool {
        userDefaults.bool(forKey: crashRecoveryModeKey)
    }

    private func uploadCrashReports(_ reports: [CrashReport]) {
        // Implement crash report upload to your backend
        // For now, just log and delete
        for report in reports {
            logger.info("Processing crash report", metadata: [
                "id": report.id.uuidString,
                "timestamp": report.timestamp.description
            ])

            // After successful upload, delete the report
            crashReporter.deleteCrashReport(report)
        }
    }

    // MARK: - Crash Count Management

    private func getConsecutiveCrashCount() -> Int {
        userDefaults.integer(forKey: consecutiveCrashCountKey)
    }

    private func incrementConsecutiveCrashCount() {
        let current = getConsecutiveCrashCount()
        userDefaults.set(current + 1, forKey: consecutiveCrashCountKey)
    }

    private func resetConsecutiveCrashCount() {
        userDefaults.set(0, forKey: consecutiveCrashCountKey)
    }

    private func recordLastCrashTime() {
        userDefaults.set(Date(), forKey: lastCrashTimeKey)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let crashOccurred = Notification.Name("crashOccurred")
}

// MARK: - Logging Extensions

extension WalletLogger {
    func recordBreadcrumb(
        category: String,
        message: String,
        level: LogLevel = .info
    ) {
        CrashReporter.shared.leaveBreadcrumb(
            category: category,
            message: message,
            level: level.rawValue.lowercased()
        )
    }
}
