import Foundation
import UIKit
import os.signpost

/// Real-time performance monitoring system with Instruments integration
@MainActor
final class PerformanceMonitor {

    // MARK: - Singleton
    static let shared = PerformanceMonitor()

    // MARK: - Signpost Logging
    private let signpostLog = OSLog(subsystem: "com.fueki.wallet", category: "Performance")
    private let performanceLog = OSLog(subsystem: "com.fueki.wallet", category: .pointsOfInterest)

    // MARK: - Metrics Storage
    private var metrics: [String: PerformanceMetric] = [:]
    private let metricsLock = NSLock()

    // MARK: - Monitoring State
    private var isMonitoring = false
    private var displayLink: CADisplayLink?
    private var frameTimestamps: [CFTimeInterval] = []
    private var currentFPS: Double = 60.0

    // MARK: - Memory Monitoring
    private var memoryWarningObserver: NSObjectProtocol?
    private var peakMemoryUsage: UInt64 = 0
    private var currentMemoryUsage: UInt64 = 0

    // MARK: - Thresholds
    struct Thresholds {
        static let targetFPS: Double = 60.0
        static let minAcceptableFPS: Double = 30.0
        static let maxMemoryMB: Double = 100.0
        static let maxLaunchTimeSeconds: Double = 2.0
        static let frameTimeBudgetMs: Double = 16.67 // 60fps = 16.67ms per frame
    }

    // MARK: - Initialization
    private init() {
        setupMemoryWarningObserver()
        setupPerformanceNotifications()
    }

    deinit {
        stopMonitoring()
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Interface

    /// Start performance monitoring
    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        os_signpost(.begin, log: signpostLog, name: "Performance Monitoring")

        startFPSMonitoring()
        startMemoryMonitoring()

        print("📊 Performance monitoring started")
    }

    /// Stop performance monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        stopFPSMonitoring()

        os_signpost(.end, log: signpostLog, name: "Performance Monitoring")

        print("📊 Performance monitoring stopped")
    }

    /// Track a performance event
    func trackEvent(name: String, category: String = "general") {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.event, log: signpostLog, name: "Performance Event", signpostID: signpostID,
                   "Event: %{public}s, Category: %{public}s", name, category)

        let metric = PerformanceMetric(
            name: name,
            category: category,
            timestamp: Date(),
            value: 0,
            unit: "event"
        )

        metricsLock.lock()
        metrics["\(category).\(name)"] = metric
        metricsLock.unlock()
    }

    /// Measure execution time of a block
    func measure<T>(name: String, category: String = "timing", block: () throws -> T) rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Measure", signpostID: signpostID,
                   "%{public}s", name)

        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000 // Convert to ms
            os_signpost(.end, log: signpostLog, name: "Measure", signpostID: signpostID,
                       "Duration: %.2f ms", duration)

            let metric = PerformanceMetric(
                name: name,
                category: category,
                timestamp: Date(),
                value: duration,
                unit: "ms"
            )

            metricsLock.lock()
            metrics["\(category).\(name)"] = metric
            metricsLock.unlock()

            // Warn if execution time is excessive
            if duration > 100 {
                print("⚠️ Slow operation: \(name) took \(String(format: "%.2f", duration))ms")
            }
        }

        return try block()
    }

    /// Measure async execution time
    func measureAsync<T>(name: String, category: String = "timing", block: () async throws -> T) async rethrows -> T {
        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Measure Async", signpostID: signpostID,
                   "%{public}s", name)

        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            os_signpost(.end, log: signpostLog, name: "Measure Async", signpostID: signpostID,
                       "Duration: %.2f ms", duration)

            let metric = PerformanceMetric(
                name: name,
                category: category,
                timestamp: Date(),
                value: duration,
                unit: "ms"
            )

            metricsLock.lock()
            metrics["\(category).\(name)"] = metric
            metricsLock.unlock()
        }

        return try await block()
    }

    /// Get current FPS
    func getCurrentFPS() -> Double {
        return currentFPS
    }

    /// Get current memory usage in MB
    func getCurrentMemoryMB() -> Double {
        updateMemoryUsage()
        return Double(currentMemoryUsage) / 1024.0 / 1024.0
    }

    /// Get peak memory usage in MB
    func getPeakMemoryMB() -> Double {
        return Double(peakMemoryUsage) / 1024.0 / 1024.0
    }

    /// Get all collected metrics
    func getAllMetrics() -> [PerformanceMetric] {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return Array(metrics.values)
    }

    /// Clear all metrics
    func clearMetrics() {
        metricsLock.lock()
        metrics.removeAll()
        metricsLock.unlock()

        print("🧹 Performance metrics cleared")
    }

    /// Generate performance report
    func generateReport() -> PerformanceReport {
        metricsLock.lock()
        let allMetrics = Array(metrics.values)
        metricsLock.unlock()

        let report = PerformanceReport(
            timestamp: Date(),
            currentFPS: currentFPS,
            currentMemoryMB: getCurrentMemoryMB(),
            peakMemoryMB: getPeakMemoryMB(),
            metrics: allMetrics,
            warnings: generateWarnings()
        )

        return report
    }

    // MARK: - FPS Monitoring

    private func startFPSMonitoring() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)

        frameTimestamps.removeAll()
    }

    private func stopFPSMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
        frameTimestamps.removeAll()
    }

    @objc private func displayLinkTick(_ link: CADisplayLink) {
        let timestamp = link.timestamp
        frameTimestamps.append(timestamp)

        // Keep only last 60 frames (1 second at 60fps)
        if frameTimestamps.count > 60 {
            frameTimestamps.removeFirst()
        }

        // Calculate FPS from timestamps
        if frameTimestamps.count >= 2 {
            let timeInterval = frameTimestamps.last! - frameTimestamps.first!
            if timeInterval > 0 {
                currentFPS = Double(frameTimestamps.count - 1) / timeInterval

                // Log FPS drops
                if currentFPS < Thresholds.minAcceptableFPS {
                    os_signpost(.event, log: performanceLog, name: "FPS Drop",
                               "Current FPS: %.1f", currentFPS)
                    print("⚠️ FPS drop detected: \(String(format: "%.1f", currentFPS)) fps")
                }
            }
        }
    }

    // MARK: - Memory Monitoring

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func setupPerformanceNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func applicationDidBecomeActive() {
        startMonitoring()
    }

    @objc private func applicationDidEnterBackground() {
        stopMonitoring()
    }

    private func startMemoryMonitoring() {
        // Update memory usage immediately
        updateMemoryUsage()

        // Schedule periodic updates
        Task { [weak self] in
            while self?.isMonitoring == true {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                self?.updateMemoryUsage()
            }
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            currentMemoryUsage = info.resident_size
            peakMemoryUsage = max(peakMemoryUsage, currentMemoryUsage)

            let currentMB = Double(currentMemoryUsage) / 1024.0 / 1024.0

            // Log excessive memory usage
            if currentMB > Thresholds.maxMemoryMB {
                os_signpost(.event, log: performanceLog, name: "High Memory Usage",
                           "Current: %.2f MB", currentMB)
                print("⚠️ High memory usage: \(String(format: "%.2f", currentMB)) MB")
            }
        }
    }

    private func handleMemoryWarning() {
        os_signpost(.event, log: performanceLog, name: "Memory Warning")
        print("⚠️ Memory warning received!")

        updateMemoryUsage()

        // Post notification for cleanup
        NotificationCenter.default.post(
            name: Notification.Name("PerformanceMemoryWarning"),
            object: nil,
            userInfo: ["memoryMB": getCurrentMemoryMB()]
        )
    }

    // MARK: - Warnings Generation

    private func generateWarnings() -> [PerformanceWarning] {
        var warnings: [PerformanceWarning] = []

        // FPS warnings
        if currentFPS < Thresholds.minAcceptableFPS {
            warnings.append(PerformanceWarning(
                type: .lowFPS,
                message: "Current FPS (\(String(format: "%.1f", currentFPS))) is below minimum acceptable (\(Thresholds.minAcceptableFPS))",
                severity: .critical
            ))
        }

        // Memory warnings
        let currentMB = getCurrentMemoryMB()
        if currentMB > Thresholds.maxMemoryMB {
            warnings.append(PerformanceWarning(
                type: .highMemory,
                message: "Memory usage (\(String(format: "%.2f", currentMB)) MB) exceeds threshold (\(Thresholds.maxMemoryMB) MB)",
                severity: .warning
            ))
        }

        // Slow operations
        metricsLock.lock()
        let slowOperations = metrics.values.filter { $0.category == "timing" && $0.value > 100 }
        metricsLock.unlock()

        for operation in slowOperations {
            warnings.append(PerformanceWarning(
                type: .slowOperation,
                message: "\(operation.name) took \(String(format: "%.2f", operation.value))ms",
                severity: .warning
            ))
        }

        return warnings
    }
}

// MARK: - Supporting Types

struct PerformanceMetric {
    let name: String
    let category: String
    let timestamp: Date
    let value: Double
    let unit: String
}

struct PerformanceReport {
    let timestamp: Date
    let currentFPS: Double
    let currentMemoryMB: Double
    let peakMemoryMB: Double
    let metrics: [PerformanceMetric]
    let warnings: [PerformanceWarning]

    var isHealthy: Bool {
        warnings.filter { $0.severity == .critical }.isEmpty
    }
}

struct PerformanceWarning {
    enum WarningType {
        case lowFPS
        case highMemory
        case slowOperation
        case networkTimeout
    }

    enum Severity {
        case info
        case warning
        case critical
    }

    let type: WarningType
    let message: String
    let severity: Severity
}
