//
//  StateLogger.swift
//  Fueki Wallet
//
//  Comprehensive state logging system
//

import Foundation
import os.log

@MainActor
class StateLogger {
    // MARK: - Singleton
    static let shared = StateLogger()

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.fueki.wallet", category: "State")
    private var actionLogs: [ActionLog] = []
    private var errorLogs: [ErrorLog] = []
    private let maxLogSize = 500

    // Performance tracking
    private var actionDurations: [String: [TimeInterval]] = [:]

    // MARK: - Initialization
    private init() {}

    // MARK: - Action Logging

    func logAction(_ action: StateAction, success: Bool, duration: TimeInterval, error: Error? = nil) {
        let log = ActionLog(
            action: action,
            success: success,
            duration: duration,
            error: error,
            timestamp: Date()
        )

        actionLogs.append(log)
        trimLogsIfNeeded()

        // Record duration for metrics
        actionDurations[action.name, default: []].append(duration)

        // Log to system
        if success {
            logger.info("✅ \(action.name) completed in \(String(format: "%.2f", duration * 1000))ms")
        } else {
            logger.error("❌ \(action.name) failed: \(error?.localizedDescription ?? "Unknown error")")
        }
    }

    func logError(_ error: StateError) {
        let log = ErrorLog(
            error: error,
            timestamp: Date(),
            stackTrace: Thread.callStackSymbols
        )

        errorLogs.append(log)
        trimLogsIfNeeded()

        logger.error("🔴 State Error: \(error.localizedDescription)")
    }

    func log(_ message: String, level: LogLevel = .info) {
        switch level {
        case .debug:
            logger.debug("\(message)")
        case .info:
            logger.info("\(message)")
        case .warning:
            logger.warning("⚠️ \(message)")
        case .error:
            logger.error("🔴 \(message)")
        case .critical:
            logger.critical("🚨 \(message)")
        }
    }

    // MARK: - Metrics

    func getMetrics() -> PerformanceMetrics {
        let totalActions = actionLogs.count
        let successfulActions = actionLogs.filter { $0.success }.count
        let failedActions = totalActions - successfulActions

        let allDurations = actionDurations.values.flatMap { $0 }
        let averageDuration = allDurations.isEmpty ? 0 : allDurations.reduce(0, +) / TimeInterval(allDurations.count)

        let slowestActions = actionDurations
            .map { (name, durations) -> (String, TimeInterval) in
                (name, durations.max() ?? 0)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }

        return PerformanceMetrics(
            totalActions: totalActions,
            successfulActions: successfulActions,
            failedActions: failedActions,
            averageDuration: averageDuration,
            slowestActions: slowestActions
        )
    }

    func getActionLogs(last count: Int = 50) -> [ActionLog] {
        return Array(actionLogs.suffix(count))
    }

    func getErrorLogs(last count: Int = 20) -> [ErrorLog] {
        return Array(errorLogs.suffix(count))
    }

    // MARK: - State Tree

    func printStateTree() {
        log("=== State Tree ===", level: .info)
        log("Total Actions: \(actionLogs.count)", level: .info)
        log("Total Errors: \(errorLogs.count)", level: .info)

        let metrics = getMetrics()
        log("Success Rate: \(String(format: "%.2f", metrics.successRate * 100))%", level: .info)
        log("Average Duration: \(String(format: "%.2f", metrics.averageDuration * 1000))ms", level: .info)

        log("\nSlowest Actions:", level: .info)
        for (name, duration) in metrics.slowestActions {
            log("  - \(name): \(String(format: "%.2f", duration * 1000))ms", level: .info)
        }

        log("\nRecent Errors:", level: .info)
        for errorLog in errorLogs.suffix(5) {
            log("  - [\(errorLog.timestamp.ISO8601Format())] \(errorLog.error.localizedDescription)", level: .error)
        }
    }

    // MARK: - Export

    func exportLogs() -> String {
        var output = "=== Fueki Wallet State Logs ===\n"
        output += "Generated: \(Date().ISO8601Format())\n\n"

        output += "=== Performance Metrics ===\n"
        let metrics = getMetrics()
        output += "Total Actions: \(metrics.totalActions)\n"
        output += "Successful: \(metrics.successfulActions)\n"
        output += "Failed: \(metrics.failedActions)\n"
        output += "Success Rate: \(String(format: "%.2f", metrics.successRate * 100))%\n"
        output += "Average Duration: \(String(format: "%.2f", metrics.averageDuration * 1000))ms\n\n"

        output += "=== Action Logs ===\n"
        for log in actionLogs.suffix(100) {
            output += log.description + "\n"
        }

        output += "\n=== Error Logs ===\n"
        for log in errorLogs.suffix(50) {
            output += log.description + "\n"
        }

        return output
    }

    // MARK: - Cleanup

    func clearLogs() {
        actionLogs.removeAll()
        errorLogs.removeAll()
        actionDurations.removeAll()
    }

    // MARK: - Private Methods

    private func trimLogsIfNeeded() {
        if actionLogs.count > maxLogSize {
            actionLogs.removeFirst(actionLogs.count - maxLogSize)
        }

        if errorLogs.count > maxLogSize {
            errorLogs.removeFirst(errorLogs.count - maxLogSize)
        }
    }
}

// MARK: - Log Structures

struct ActionLog {
    let action: StateAction
    let success: Bool
    let duration: TimeInterval
    let error: Error?
    let timestamp: Date

    var description: String {
        let status = success ? "✅" : "❌"
        let errorDesc = error != nil ? " - \(error!.localizedDescription)" : ""
        let durationMs = Int(duration * 1000)
        return "[\(timestamp.ISO8601Format())] \(status) \(action.name) (\(durationMs)ms)\(errorDesc)"
    }
}

struct ErrorLog {
    let error: StateError
    let timestamp: Date
    let stackTrace: [String]

    var description: String {
        "[\(timestamp.ISO8601Format())] 🔴 \(error.localizedDescription)"
    }
}

enum LogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}
