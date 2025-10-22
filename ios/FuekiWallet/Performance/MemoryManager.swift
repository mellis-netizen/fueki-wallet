import Foundation
import UIKit
import os.signpost

/// Manages memory pressure and implements cleanup strategies
@MainActor
final class MemoryManager {

    // MARK: - Singleton
    static let shared = MemoryManager()

    // MARK: - Signpost Logging
    private let signpostLog = OSLog(subsystem: "com.fueki.wallet", category: "Memory")

    // MARK: - Memory State
    @Published private(set) var currentMemoryMB: Double = 0
    @Published private(set) var peakMemoryMB: Double = 0
    @Published private(set) var pressureLevel: MemoryPressureLevel = .normal

    // MARK: - Thresholds
    struct Thresholds {
        static let warningThresholdMB: Double = 75.0
        static let criticalThresholdMB: Double = 95.0
        static let targetMemoryMB: Double = 100.0
    }

    // MARK: - Registered Handlers
    private var cleanupHandlers: [String: MemoryCleanupHandler] = [:]
    private let handlersLock = NSLock()

    // MARK: - Monitoring
    private var monitoringTimer: Timer?
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Statistics
    private var cleanupStats = CleanupStatistics()

    // MARK: - Initialization
    private init() {
        setupMemoryMonitoring()
        setupMemoryWarningObserver()
        registerDefaultHandlers()
    }

    deinit {
        stopMonitoring()
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Registration

    /// Register a cleanup handler
    func registerCleanupHandler(name: String, priority: Int = 0, handler: @escaping () async -> Int) {
        handlersLock.lock()
        cleanupHandlers[name] = MemoryCleanupHandler(name: name, priority: priority, handler: handler)
        handlersLock.unlock()

        print("📝 Registered cleanup handler: \(name) (priority: \(priority))")
    }

    /// Unregister a cleanup handler
    func unregisterCleanupHandler(name: String) {
        handlersLock.lock()
        cleanupHandlers.removeValue(forKey: name)
        handlersLock.unlock()

        print("📝 Unregistered cleanup handler: \(name)")
    }

    // MARK: - Memory Monitoring

    func startMonitoring(interval: TimeInterval = 5.0) {
        guard monitoringTimer == nil else { return }

        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMemoryState()
            }
        }

        print("📊 Memory monitoring started")
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        print("📊 Memory monitoring stopped")
    }

    private func updateMemoryState() {
        let memoryMB = getCurrentMemoryUsageMB()
        currentMemoryMB = memoryMB
        peakMemoryMB = max(peakMemoryMB, memoryMB)

        // Update pressure level
        let newPressureLevel: MemoryPressureLevel
        if memoryMB > Thresholds.criticalThresholdMB {
            newPressureLevel = .critical
        } else if memoryMB > Thresholds.warningThresholdMB {
            newPressureLevel = .warning
        } else {
            newPressureLevel = .normal
        }

        if newPressureLevel != pressureLevel {
            pressureLevel = newPressureLevel
            handlePressureLevelChange(newPressureLevel)
        }
    }

    private func getCurrentMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard kerr == KERN_SUCCESS else {
            return 0
        }

        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    // MARK: - Memory Warning

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleMemoryWarning()
            }
        }
    }

    private func handleMemoryWarning() async {
        os_signpost(.event, log: signpostLog, name: "Memory Warning")
        print("⚠️ MEMORY WARNING RECEIVED")

        updateMemoryState()

        // Perform aggressive cleanup
        let freed = await performCleanup(aggressive: true)

        cleanupStats.warningCount += 1
        cleanupStats.totalFreedMB += freed

        print("💾 Memory warning cleanup freed \(String(format: "%.2f", freed)) MB")

        // Notify other components
        NotificationCenter.default.post(
            name: Notification.Name("MemoryWarningHandled"),
            object: nil,
            userInfo: ["freedMB": freed]
        )
    }

    private func handlePressureLevelChange(_ newLevel: MemoryPressureLevel) {
        os_signpost(.event, log: signpostLog, name: "Pressure Level Change",
                   "Level: %{public}s", newLevel.description)

        print("⚠️ Memory pressure level changed to: \(newLevel.description)")

        Task {
            switch newLevel {
            case .warning:
                _ = await performCleanup(aggressive: false)
            case .critical:
                _ = await performCleanup(aggressive: true)
            case .normal:
                break
            }
        }
    }

    // MARK: - Cleanup Execution

    /// Perform memory cleanup
    @discardableResult
    func performCleanup(aggressive: Bool = false) async -> Double {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Memory Cleanup", signpostID: signpostID,
                   "Aggressive: %{public}s", aggressive ? "YES" : "NO")

        let beforeMemory = getCurrentMemoryUsageMB()

        handlersLock.lock()
        let handlers = Array(cleanupHandlers.values).sorted { $0.priority > $1.priority }
        handlersLock.unlock()

        var totalFreed = 0

        for handler in handlers {
            let freed = await handler.handler()
            totalFreed += freed

            print("🧹 \(handler.name) freed \(freed) bytes")

            // Check if we've freed enough memory
            if !aggressive {
                let currentMemory = getCurrentMemoryUsageMB()
                if currentMemory < Thresholds.warningThresholdMB {
                    break
                }
            }
        }

        let afterMemory = getCurrentMemoryUsageMB()
        let freedMB = beforeMemory - afterMemory

        os_signpost(.end, log: signpostLog, name: "Memory Cleanup", signpostID: signpostID,
                   "Freed: %.2f MB", freedMB)

        cleanupStats.cleanupCount += 1
        cleanupStats.totalFreedMB += freedMB

        print("💾 Total cleanup freed \(String(format: "%.2f", freedMB)) MB")

        return freedMB
    }

    /// Check if cleanup is needed
    func shouldPerformCleanup() -> Bool {
        return currentMemoryMB > Thresholds.warningThresholdMB
    }

    // MARK: - Default Handlers

    private func registerDefaultHandlers() {
        // Image cache cleanup
        registerCleanupHandler(name: "ImageCache", priority: 10) {
            ImageCacheOptimizer.shared.clearMemoryCache()
            return 0 // Size tracking handled internally
        }

        // Lazy loading cache cleanup
        registerCleanupHandler(name: "LazyLoading", priority: 9) {
            LazyLoadingManager.shared.clearCache()
            return 0
        }

        // URL cache cleanup
        registerCleanupHandler(name: "URLCache", priority: 8) {
            URLCache.shared.removeAllCachedResponses()
            return 0
        }

        // Release autoreleasepool objects
        registerCleanupHandler(name: "AutoreleasePool", priority: 7) {
            autoreleasepool {
                // Force autorelease pool drain
            }
            return 0
        }
    }

    // MARK: - Statistics

    func getStatistics() -> CleanupStatistics {
        return cleanupStats
    }

    func resetStatistics() {
        cleanupStats = CleanupStatistics()
    }

    // MARK: - Memory Information

    func getMemoryInfo() -> MemoryInfo {
        return MemoryInfo(
            currentMB: currentMemoryMB,
            peakMB: peakMemoryMB,
            pressureLevel: pressureLevel,
            availableHandlers: cleanupHandlers.count,
            statistics: cleanupStats
        )
    }

    /// Get detailed memory breakdown
    func getMemoryBreakdown() -> MemoryBreakdown {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        _ = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        let residentMB = Double(info.resident_size) / 1024.0 / 1024.0
        let virtualMB = Double(info.virtual_size) / 1024.0 / 1024.0

        return MemoryBreakdown(
            residentMB: residentMB,
            virtualMB: virtualMB,
            footprintMB: residentMB, // Simplified
            limit: Thresholds.targetMemoryMB
        )
    }
}

// MARK: - Supporting Types

enum MemoryPressureLevel: CustomStringConvertible {
    case normal
    case warning
    case critical

    var description: String {
        switch self {
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

struct MemoryCleanupHandler {
    let name: String
    let priority: Int
    let handler: () async -> Int
}

struct CleanupStatistics {
    var cleanupCount: Int = 0
    var warningCount: Int = 0
    var totalFreedMB: Double = 0

    var averageFreedMB: Double {
        guard cleanupCount > 0 else { return 0 }
        return totalFreedMB / Double(cleanupCount)
    }
}

struct MemoryInfo {
    let currentMB: Double
    let peakMB: Double
    let pressureLevel: MemoryPressureLevel
    let availableHandlers: Int
    let statistics: CleanupStatistics
}

struct MemoryBreakdown {
    let residentMB: Double
    let virtualMB: Double
    let footprintMB: Double
    let limit: Double

    var usagePercentage: Double {
        (footprintMB / limit) * 100
    }
}
