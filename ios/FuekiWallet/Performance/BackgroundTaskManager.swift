import Foundation
import BackgroundTasks
import os.signpost

/// Manages background task scheduling and execution
@MainActor
final class BackgroundTaskManager {

    // MARK: - Singleton
    static let shared = BackgroundTaskManager()

    // MARK: - Signpost Logging
    private let signpostLog = OSLog(subsystem: "com.fueki.wallet", category: "BackgroundTasks")

    // MARK: - Task Identifiers
    enum TaskIdentifier: String {
        case dataSync = "com.fueki.wallet.datasync"
        case cacheCleanup = "com.fueki.wallet.cachecleanup"
        case databaseMaintenance = "com.fueki.wallet.dbmaintenance"
        case analyticsUpload = "com.fueki.wallet.analytics"
        case walletRefresh = "com.fueki.wallet.walletrefresh"
    }

    // MARK: - Registered Tasks
    private var registeredTasks: [TaskIdentifier: BackgroundTask] = [:]
    private let tasksLock = NSLock()

    // MARK: - Statistics
    @Published private(set) var stats = BackgroundTaskStatistics()

    // MARK: - Initialization
    private init() {
        registerDefaultTasks()
    }

    // MARK: - Task Registration

    /// Register background task
    func registerTask(
        identifier: TaskIdentifier,
        frequency: TimeInterval,
        requiresNetwork: Bool = false,
        requiresExternalPower: Bool = false,
        handler: @escaping () async throws -> Void
    ) {

        let task = BackgroundTask(
            identifier: identifier,
            frequency: frequency,
            requiresNetwork: requiresNetwork,
            requiresExternalPower: requiresExternalPower,
            handler: handler
        )

        tasksLock.lock()
        registeredTasks[identifier] = task
        tasksLock.unlock()

        // Register with BGTaskScheduler
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier.rawValue,
            using: nil
        ) { [weak self] bgTask in
            Task { @MainActor [weak self] in
                await self?.handleBackgroundTask(bgTask, taskIdentifier: identifier)
            }
        }

        print("📝 Registered background task: \(identifier.rawValue)")
    }

    // MARK: - Task Scheduling

    /// Schedule background task
    func scheduleTask(identifier: TaskIdentifier) {
        guard let task = registeredTasks[identifier] else {
            print("⚠️ Task not registered: \(identifier.rawValue)")
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: identifier.rawValue)
        request.earliestBeginDate = Date(timeIntervalSinceNow: task.frequency)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("📅 Scheduled background task: \(identifier.rawValue)")
        } catch {
            print("⚠️ Failed to schedule task \(identifier.rawValue): \(error)")
        }
    }

    /// Schedule all registered tasks
    func scheduleAllTasks() {
        tasksLock.lock()
        let identifiers = Array(registeredTasks.keys)
        tasksLock.unlock()

        for identifier in identifiers {
            scheduleTask(identifier: identifier)
        }

        print("📅 Scheduled \(identifiers.count) background tasks")
    }

    /// Cancel scheduled task
    func cancelTask(identifier: TaskIdentifier) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier.rawValue)
        print("❌ Cancelled background task: \(identifier.rawValue)")
    }

    /// Cancel all tasks
    func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("❌ Cancelled all background tasks")
    }

    // MARK: - Task Execution

    private func handleBackgroundTask(_ bgTask: BGTask, taskIdentifier: TaskIdentifier) async {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Background Task", signpostID: signpostID,
                   "Task: %{public}s", taskIdentifier.rawValue)

        print("🔄 Executing background task: \(taskIdentifier.rawValue)")

        stats.executionCount += 1
        let startTime = CFAbsoluteTimeGetCurrent()

        // Set expiration handler
        var taskCompleted = false
        bgTask.expirationHandler = { [weak self] in
            print("⏰ Background task expired: \(taskIdentifier.rawValue)")
            taskCompleted = true
            self?.stats.expiredCount += 1
        }

        // Execute task
        do {
            guard let task = registeredTasks[taskIdentifier] else {
                throw BackgroundTaskError.taskNotFound
            }

            try await task.handler()

            if !taskCompleted {
                bgTask.setTaskCompleted(success: true)
                let duration = CFAbsoluteTimeGetCurrent() - startTime

                stats.successCount += 1
                stats.totalExecutionTimeSeconds += duration

                print("✅ Background task completed: \(taskIdentifier.rawValue) in \(String(format: "%.2f", duration))s")

                // Reschedule
                scheduleTask(identifier: taskIdentifier)
            }

        } catch {
            if !taskCompleted {
                bgTask.setTaskCompleted(success: false)
                stats.failureCount += 1
                print("⚠️ Background task failed: \(taskIdentifier.rawValue) - \(error)")
            }
        }

        os_signpost(.end, log: signpostLog, name: "Background Task", signpostID: signpostID)
    }

    // MARK: - Default Tasks

    private func registerDefaultTasks() {
        // Data sync task
        registerTask(
            identifier: .dataSync,
            frequency: 900, // 15 minutes
            requiresNetwork: true
        ) {
            await self.performDataSync()
        }

        // Cache cleanup task
        registerTask(
            identifier: .cacheCleanup,
            frequency: 3600, // 1 hour
            requiresNetwork: false
        ) {
            await self.performCacheCleanup()
        }

        // Database maintenance task
        registerTask(
            identifier: .databaseMaintenance,
            frequency: 86400, // 24 hours
            requiresNetwork: false,
            requiresExternalPower: true
        ) {
            await self.performDatabaseMaintenance()
        }

        // Wallet refresh task
        registerTask(
            identifier: .walletRefresh,
            frequency: 1800, // 30 minutes
            requiresNetwork: true
        ) {
            await self.performWalletRefresh()
        }
    }

    // MARK: - Task Implementations

    private func performDataSync() async {
        print("🔄 Performing data sync...")

        // Sync transactions, balances, etc.
        // Placeholder implementation

        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate work
        print("✅ Data sync completed")
    }

    private func performCacheCleanup() async {
        print("🧹 Performing cache cleanup...")

        // Clean up image cache
        ImageCacheOptimizer.shared.clearCache()

        // Clean up network cache
        NetworkOptimizer.shared.clearCache()

        // Clean up lazy loading cache
        LazyLoadingManager.shared.clearCache()

        print("✅ Cache cleanup completed")
    }

    private func performDatabaseMaintenance() async {
        print("🔧 Performing database maintenance...")

        // Vacuum database
        await DatabaseOptimizer.shared.performVacuum()

        // Clear query cache
        DatabaseOptimizer.shared.clearQueryCache()

        print("✅ Database maintenance completed")
    }

    private func performWalletRefresh() async {
        print("💰 Performing wallet refresh...")

        // Refresh wallet balances, transactions, etc.
        // Placeholder implementation

        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate work
        print("✅ Wallet refresh completed")
    }

    // MARK: - Immediate Execution

    /// Execute task immediately (for testing)
    func executeImmediately(identifier: TaskIdentifier) async throws {
        guard let task = registeredTasks[identifier] else {
            throw BackgroundTaskError.taskNotFound
        }

        print("⚡ Executing task immediately: \(identifier.rawValue)")

        let startTime = CFAbsoluteTimeGetCurrent()
        try await task.handler()
        let duration = CFAbsoluteTimeGetCurrent() - startTime

        print("✅ Immediate execution completed in \(String(format: "%.2f", duration))s")
    }

    // MARK: - Statistics

    func getStatistics() -> BackgroundTaskStatistics {
        return stats
    }

    func resetStatistics() {
        stats = BackgroundTaskStatistics()
    }

    // MARK: - Task Information

    func getScheduledTasks() -> [TaskIdentifier] {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        return Array(registeredTasks.keys)
    }

    func getTaskInfo(identifier: TaskIdentifier) -> BackgroundTask? {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        return registeredTasks[identifier]
    }
}

// MARK: - Supporting Types

struct BackgroundTask {
    let identifier: BackgroundTaskManager.TaskIdentifier
    let frequency: TimeInterval
    let requiresNetwork: Bool
    let requiresExternalPower: Bool
    let handler: () async throws -> Void
}

struct BackgroundTaskStatistics {
    var executionCount: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var expiredCount: Int = 0
    var totalExecutionTimeSeconds: Double = 0

    var averageExecutionTimeSeconds: Double {
        guard executionCount > 0 else { return 0 }
        return totalExecutionTimeSeconds / Double(executionCount)
    }

    var successRate: Double {
        guard executionCount > 0 else { return 0 }
        return Double(successCount) / Double(executionCount)
    }
}

enum BackgroundTaskError: LocalizedError {
    case taskNotFound
    case executionFailed

    var errorDescription: String? {
        switch self {
        case .taskNotFound:
            return "Background task not found"
        case .executionFailed:
            return "Background task execution failed"
        }
    }
}

// MARK: - Info.plist Configuration Helper

extension BackgroundTaskManager {
    /// Get required Info.plist entries for background tasks
    static func getRequiredInfoPlistEntries() -> String {
        """
        Add to Info.plist:

        <key>BGTaskSchedulerPermittedIdentifiers</key>
        <array>
            <string>com.fueki.wallet.datasync</string>
            <string>com.fueki.wallet.cachecleanup</string>
            <string>com.fueki.wallet.dbmaintenance</string>
            <string>com.fueki.wallet.analytics</string>
            <string>com.fueki.wallet.walletrefresh</string>
        </array>
        """
    }
}
