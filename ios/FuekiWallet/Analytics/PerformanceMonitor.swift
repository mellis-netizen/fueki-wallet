import Foundation
import UIKit

/// Performance monitoring and metrics tracking
public class PerformanceMonitor {

    // MARK: - Singleton
    public static let shared = PerformanceMonitor()

    // MARK: - Properties
    private var activeTraces: [String: PerformanceTrace] = [:]
    private let queue = DispatchQueue(label: "com.fueki.performance", qos: .utility)
    private var isEnabled = true

    // Thresholds for warnings
    private let slowOperationThreshold: TimeInterval = 1.0 // 1 second
    private let criticalOperationThreshold: TimeInterval = 3.0 // 3 seconds

    // MARK: - Initialization
    private init() {
        observeMemoryWarnings()
    }

    // MARK: - Trace Management

    /// Start a performance trace
    /// - Parameter name: Name of the trace
    /// - Returns: Trace ID
    @discardableResult
    public func startTrace(_ name: String) -> String {
        let traceId = "\(name)_\(UUID().uuidString)"

        queue.async { [weak self] in
            let trace = PerformanceTrace(name: name, id: traceId)
            self?.activeTraces[traceId] = trace
        }

        Logger.shared.log("Performance trace started: \(name)", level: .debug, category: .performance)
        CrashReporter.shared.recordBreadcrumb("Trace started: \(name)", category: .system)

        return traceId
    }

    /// Stop a performance trace
    /// - Parameter traceId: ID of the trace to stop
    public func stopTrace(_ traceId: String) {
        queue.async { [weak self] in
            guard let self = self,
                  let trace = self.activeTraces[traceId] else {
                return
            }

            trace.stop()
            self.activeTraces.removeValue(forKey: traceId)

            // Log trace results
            self.logTraceResults(trace)

            // Send to analytics
            AnalyticsManager.shared.trackTiming(
                category: "performance",
                name: trace.name,
                duration: trace.duration
            )
        }
    }

    /// Add a metric to an active trace
    /// - Parameters:
    ///   - traceId: Trace ID
    ///   - metricName: Name of the metric
    ///   - value: Metric value
    public func addMetric(to traceId: String, metricName: String, value: Double) {
        queue.async { [weak self] in
            self?.activeTraces[traceId]?.addMetric(name: metricName, value: value)
        }
    }

    /// Set an attribute on an active trace
    /// - Parameters:
    ///   - traceId: Trace ID
    ///   - attribute: Attribute name
    ///   - value: Attribute value
    public func setAttribute(on traceId: String, attribute: String, value: String) {
        queue.async { [weak self] in
            self?.activeTraces[traceId]?.setAttribute(attribute, value: value)
        }
    }

    private func logTraceResults(_ trace: PerformanceTrace) {
        let duration = trace.duration
        let level: LogLevel = duration > criticalOperationThreshold ? .warning :
                               duration > slowOperationThreshold ? .info : .debug

        var metadata = trace.attributes
        metadata["duration"] = String(format: "%.3f", duration)

        for (metricName, metricValue) in trace.metrics {
            metadata[metricName] = String(format: "%.2f", metricValue)
        }

        Logger.shared.log(
            "Performance trace completed: \(trace.name)",
            level: level,
            category: .performance,
            metadata: metadata
        )

        // Warn about slow operations
        if duration > slowOperationThreshold {
            let warningMsg = "Slow operation detected: \(trace.name) took \(String(format: "%.2f", duration))s"
            Logger.shared.log(warningMsg, level: .warning, category: .performance)
            CrashReporter.shared.recordBreadcrumb(warningMsg, category: .system, level: .warning)
        }
    }

    // MARK: - Convenience Methods

    /// Measure the execution time of a block
    /// - Parameters:
    ///   - name: Name of the measurement
    ///   - block: Block to measure
    public func measure(name: String, block: () -> Void) {
        let traceId = startTrace(name)
        block()
        stopTrace(traceId)
    }

    /// Measure the execution time of an async block
    /// - Parameters:
    ///   - name: Name of the measurement
    ///   - block: Async block to measure
    public func measure(name: String, block: () async throws -> Void) async rethrows {
        let traceId = startTrace(name)
        try await block()
        stopTrace(traceId)
    }

    // MARK: - App Performance Metrics

    /// Track app launch time
    public func trackAppLaunch() {
        let launchTrace = startTrace("app_launch")
        setAttribute(on: launchTrace, attribute: "launch_type", value: "cold_start")
    }

    /// Track screen load time
    /// - Parameter screenName: Name of the screen
    /// - Returns: Trace ID
    public func trackScreenLoad(_ screenName: String) -> String {
        let traceId = startTrace("screen_load_\(screenName)")
        setAttribute(on: traceId, attribute: "screen_name", value: screenName)
        return traceId
    }

    /// Track network request performance
    /// - Parameter endpoint: API endpoint
    /// - Returns: Trace ID
    public func trackNetworkRequest(_ endpoint: String) -> String {
        let traceId = startTrace("network_request")
        setAttribute(on: traceId, attribute: "endpoint", value: endpoint)
        return traceId
    }

    /// Track blockchain transaction performance
    /// - Parameter transactionType: Type of transaction
    /// - Returns: Trace ID
    public func trackTransaction(_ transactionType: String) -> String {
        let traceId = startTrace("transaction_\(transactionType)")
        setAttribute(on: traceId, attribute: "type", value: transactionType)
        return traceId
    }

    // MARK: - Memory Monitoring

    private func observeMemoryWarnings() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        let memoryUsage = getMemoryUsage()

        Logger.shared.log(
            "Memory warning received",
            level: .warning,
            category: .performance,
            metadata: ["memory_usage_mb": String(format: "%.2f", memoryUsage)]
        )

        CrashReporter.shared.recordBreadcrumb(
            "Memory warning: \(String(format: "%.2f", memoryUsage))MB",
            category: .system,
            level: .warning
        )

        AnalyticsManager.shared.track(
            .performanceMetric(
                name: "memory_warning",
                duration: 0,
                metadata: ["memory_usage_mb": memoryUsage]
            )
        )
    }

    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }

        return 0
    }

    /// Get current memory usage in MB
    public func getCurrentMemoryUsage() -> Double {
        return getMemoryUsage()
    }

    // MARK: - FPS Monitoring

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var currentFPS: Double = 0

    /// Start FPS monitoring
    public func startFPSMonitoring() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }

    /// Stop FPS monitoring
    public func stopFPSMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkTick(displayLink: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = displayLink.timestamp
            return
        }

        frameCount += 1
        let elapsed = displayLink.timestamp - lastTimestamp

        if elapsed >= 1.0 {
            currentFPS = Double(frameCount) / elapsed

            if currentFPS < 30 {
                Logger.shared.log(
                    "Low FPS detected: \(String(format: "%.1f", currentFPS))",
                    level: .warning,
                    category: .performance
                )
            }

            frameCount = 0
            lastTimestamp = displayLink.timestamp
        }
    }

    /// Get current FPS
    public func getCurrentFPS() -> Double {
        return currentFPS
    }
}

// MARK: - Performance Trace

private class PerformanceTrace {
    let name: String
    let id: String
    let startTime: Date
    var endTime: Date?
    var metrics: [String: Double] = [:]
    var attributes: [String: String] = [:]

    var duration: TimeInterval {
        guard let endTime = endTime else {
            return Date().timeIntervalSince(startTime)
        }
        return endTime.timeIntervalSince(startTime)
    }

    init(name: String, id: String) {
        self.name = name
        self.id = id
        self.startTime = Date()
    }

    func stop() {
        endTime = Date()
    }

    func addMetric(name: String, value: Double) {
        metrics[name] = value
    }

    func setAttribute(_ attribute: String, value: String) {
        attributes[attribute] = value
    }
}
