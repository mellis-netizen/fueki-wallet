import Foundation
import os.signpost

/// Centralized performance metrics collection and reporting
@MainActor
final class PerformanceMetrics {

    // MARK: - Singleton
    static let shared = PerformanceMetrics()

    // MARK: - Signpost Logging
    private let signpostLog = OSLog(subsystem: "com.fueki.wallet", category: "Metrics")

    // MARK: - Metrics Storage
    private var metricsData: MetricsData = MetricsData()
    private let lock = NSLock()

    // MARK: - Collection State
    @Published private(set) var isCollecting = false
    private var collectionStartTime: Date?

    // MARK: - Initialization
    private init() {
        setupMetricsCollection()
    }

    // MARK: - Collection Control

    /// Start metrics collection
    func startCollection() {
        guard !isCollecting else { return }

        isCollecting = true
        collectionStartTime = Date()

        os_signpost(.begin, log: signpostLog, name: "Metrics Collection")

        // Start all subsystem monitoring
        PerformanceMonitor.shared.startMonitoring()
        MemoryManager.shared.startMonitoring()

        print("📊 Performance metrics collection started")
    }

    /// Stop metrics collection
    func stopCollection() {
        guard isCollecting else { return }

        isCollecting = false

        os_signpost(.end, log: signpostLog, name: "Metrics Collection")

        // Stop monitoring
        PerformanceMonitor.shared.stopMonitoring()
        MemoryManager.shared.stopMonitoring()

        print("📊 Performance metrics collection stopped")
    }

    // MARK: - Metrics Collection

    /// Collect all current metrics
    func collectMetrics() -> PerformanceSnapshot {
        lock.lock()
        defer { lock.unlock() }

        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            performance: collectPerformanceMetrics(),
            memory: collectMemoryMetrics(),
            database: collectDatabaseMetrics(),
            network: collectNetworkMetrics(),
            cache: collectCacheMetrics(),
            startup: collectStartupMetrics(),
            backgroundTasks: collectBackgroundTaskMetrics()
        )

        // Store snapshot
        metricsData.snapshots.append(snapshot)

        // Keep only last 100 snapshots
        if metricsData.snapshots.count > 100 {
            metricsData.snapshots.removeFirst()
        }

        return snapshot
    }

    private func collectPerformanceMetrics() -> PerformanceMetricsData {
        let report = PerformanceMonitor.shared.generateReport()

        return PerformanceMetricsData(
            currentFPS: report.currentFPS,
            averageFPS: report.currentFPS,
            minFPS: report.currentFPS,
            frameDrops: 0,
            slowOperations: report.warnings.filter { $0.type == .slowOperation }.count
        )
    }

    private func collectMemoryMetrics() -> MemoryMetricsData {
        let info = MemoryManager.shared.getMemoryInfo()
        let breakdown = MemoryManager.shared.getMemoryBreakdown()

        return MemoryMetricsData(
            currentMB: info.currentMB,
            peakMB: info.peakMB,
            residentMB: breakdown.residentMB,
            virtualMB: breakdown.virtualMB,
            pressureLevel: info.pressureLevel.description,
            cleanupCount: info.statistics.cleanupCount,
            totalFreedMB: info.statistics.totalFreedMB
        )
    }

    private func collectDatabaseMetrics() -> DatabaseMetricsData {
        let stats = DatabaseOptimizer.shared.getStatistics()

        return DatabaseMetricsData(
            queryCount: stats.queryCount,
            cacheHitRate: stats.cacheHitRate,
            averageQueryTimeMs: stats.averageQueryTimeMs,
            slowQueries: stats.slowQueries,
            batchOperations: stats.batchOperations
        )
    }

    private func collectNetworkMetrics() -> NetworkMetricsData {
        let stats = NetworkOptimizer.shared.getStatistics()

        return NetworkMetricsData(
            totalRequests: stats.totalRequests,
            cacheHitRate: stats.cacheHitRate,
            deduplicatedRequests: stats.deduplicatedRequests,
            averageRequestTimeMs: stats.averageRequestTimeMs,
            failedRequests: stats.failedRequests,
            successRate: stats.successRate
        )
    }

    private func collectCacheMetrics() -> CacheMetricsData {
        let imageStats = ImageCacheOptimizer.shared.getStatistics()

        return CacheMetricsData(
            imageCacheHitRate: imageStats.hitRate,
            imageCacheSizeMB: Double(imageStats.memoryCacheSize + imageStats.diskCacheSize) / 1024.0 / 1024.0,
            networkCacheHits: NetworkOptimizer.shared.getStatistics().cacheHits,
            databaseCacheHits: DatabaseOptimizer.shared.getStatistics().cacheHits
        )
    }

    private func collectStartupMetrics() -> StartupMetricsData {
        let stats = StartupOptimizer.shared.getStatistics()
        let phaseTiming = StartupOptimizer.shared.getPhaseTiming()

        return StartupMetricsData(
            lastLaunchTimeSeconds: stats.lastLaunchTimeSeconds,
            averageLaunchTimeSeconds: stats.averageLaunchTimeSeconds,
            launchCount: stats.launchCount,
            phaseTiming: phaseTiming.mapValues { $0 }
        )
    }

    private func collectBackgroundTaskMetrics() -> BackgroundTaskMetricsData {
        let stats = BackgroundTaskManager.shared.getStatistics()

        return BackgroundTaskMetricsData(
            executionCount: stats.executionCount,
            successRate: stats.successRate,
            averageExecutionTimeSeconds: stats.averageExecutionTimeSeconds,
            expiredCount: stats.expiredCount
        )
    }

    // MARK: - Reporting

    /// Generate comprehensive performance report
    func generateReport() -> PerformanceReport {
        let snapshot = collectMetrics()

        lock.lock()
        let allSnapshots = metricsData.snapshots
        lock.unlock()

        let recommendations = generateRecommendations(snapshot: snapshot)
        let trends = analyzeTrends(snapshots: allSnapshots)

        return PerformanceReport(
            currentSnapshot: snapshot,
            recommendations: recommendations,
            trends: trends,
            healthScore: calculateHealthScore(snapshot: snapshot)
        )
    }

    /// Generate optimization recommendations
    private func generateRecommendations(snapshot: PerformanceSnapshot) -> [Recommendation] {
        var recommendations: [Recommendation] = []

        // FPS recommendations
        if snapshot.performance.currentFPS < 30 {
            recommendations.append(Recommendation(
                category: "Performance",
                priority: .high,
                title: "Low Frame Rate",
                description: "Current FPS (\(String(format: "%.1f", snapshot.performance.currentFPS))) is below 30fps",
                action: "Optimize UI rendering, reduce complex views"
            ))
        }

        // Memory recommendations
        if snapshot.memory.currentMB > 95 {
            recommendations.append(Recommendation(
                category: "Memory",
                priority: .critical,
                title: "High Memory Usage",
                description: "Memory usage (\(String(format: "%.2f", snapshot.memory.currentMB))MB) is near limit",
                action: "Clear caches, reduce object retention"
            ))
        }

        // Database recommendations
        if snapshot.database.slowQueries > 5 {
            recommendations.append(Recommendation(
                category: "Database",
                priority: .medium,
                title: "Slow Database Queries",
                description: "\(snapshot.database.slowQueries) slow queries detected",
                action: "Review query optimization, add indexes"
            ))
        }

        // Network recommendations
        if snapshot.network.failedRequests > 10 {
            recommendations.append(Recommendation(
                category: "Network",
                priority: .medium,
                title: "High Network Failure Rate",
                description: "\(snapshot.network.failedRequests) failed requests",
                action: "Check network connectivity, implement better error handling"
            ))
        }

        // Cache recommendations
        if snapshot.cache.imageCacheHitRate < 0.5 {
            recommendations.append(Recommendation(
                category: "Cache",
                priority: .low,
                title: "Low Cache Hit Rate",
                description: "Image cache hit rate is only \(String(format: "%.1f", snapshot.cache.imageCacheHitRate * 100))%",
                action: "Increase cache size or adjust eviction policy"
            ))
        }

        // Startup recommendations
        if snapshot.startup.lastLaunchTimeSeconds > 2.0 {
            recommendations.append(Recommendation(
                category: "Startup",
                priority: .high,
                title: "Slow App Launch",
                description: "Launch time (\(String(format: "%.2f", snapshot.startup.lastLaunchTimeSeconds))s) exceeds 2s target",
                action: "Defer non-critical initialization, optimize startup sequence"
            ))
        }

        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }

    /// Analyze performance trends
    private func analyzeTrends(snapshots: [PerformanceSnapshot]) -> PerformanceTrends {
        guard snapshots.count >= 2 else {
            return PerformanceTrends()
        }

        let recentSnapshots = snapshots.suffix(10)

        let fpsValues = recentSnapshots.map { $0.performance.currentFPS }
        let memoryValues = recentSnapshots.map { $0.memory.currentMB }

        return PerformanceTrends(
            fpsAverage: fpsValues.reduce(0, +) / Double(fpsValues.count),
            fpsTrend: calculateTrend(values: fpsValues),
            memoryAverage: memoryValues.reduce(0, +) / Double(memoryValues.count),
            memoryTrend: calculateTrend(values: memoryValues),
            snapshotCount: snapshots.count
        )
    }

    private func calculateTrend(values: [Double]) -> String {
        guard values.count >= 2 else { return "stable" }

        let first = values.first!
        let last = values.last!
        let change = ((last - first) / first) * 100

        if change > 10 {
            return "increasing"
        } else if change < -10 {
            return "decreasing"
        } else {
            return "stable"
        }
    }

    /// Calculate overall health score (0-100)
    private func calculateHealthScore(snapshot: PerformanceSnapshot) -> Int {
        var score = 100

        // FPS impact (max -30 points)
        if snapshot.performance.currentFPS < 60 {
            let fpsScore = (snapshot.performance.currentFPS / 60.0) * 30
            score -= Int(30 - fpsScore)
        }

        // Memory impact (max -25 points)
        if snapshot.memory.currentMB > 50 {
            let memoryScore = ((100 - snapshot.memory.currentMB) / 50.0) * 25
            score -= Int(25 - max(0, memoryScore))
        }

        // Database impact (max -15 points)
        if snapshot.database.slowQueries > 0 {
            score -= min(15, snapshot.database.slowQueries * 3)
        }

        // Network impact (max -15 points)
        let networkFailureRate = snapshot.network.totalRequests > 0 ?
            Double(snapshot.network.failedRequests) / Double(snapshot.network.totalRequests) : 0
        score -= Int(networkFailureRate * 15)

        // Startup impact (max -15 points)
        if snapshot.startup.lastLaunchTimeSeconds > 2.0 {
            let startupScore = (2.0 / snapshot.startup.lastLaunchTimeSeconds) * 15
            score -= Int(15 - startupScore)
        }

        return max(0, min(100, score))
    }

    // MARK: - Export

    /// Export metrics to JSON
    func exportMetrics() -> String? {
        lock.lock()
        let data = metricsData
        lock.unlock()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

    /// Reset all metrics
    func resetMetrics() {
        lock.lock()
        metricsData = MetricsData()
        lock.unlock()

        // Reset subsystem statistics
        PerformanceMonitor.shared.clearMetrics()
        MemoryManager.shared.resetStatistics()
        DatabaseOptimizer.shared.resetStatistics()
        NetworkOptimizer.shared.resetStatistics()
        ImageCacheOptimizer.shared.resetStatistics()
        StartupOptimizer.shared.getStatistics()
        BackgroundTaskManager.shared.resetStatistics()

        print("🧹 All performance metrics reset")
    }

    // MARK: - Setup

    private func setupMetricsCollection() {
        // Automatically collect metrics periodically
        Task {
            while !Task.isCancelled {
                if isCollecting {
                    _ = collectMetrics()
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
}

// MARK: - Supporting Types

struct MetricsData: Codable {
    var snapshots: [PerformanceSnapshot] = []
}

struct PerformanceSnapshot: Codable {
    let timestamp: Date
    let performance: PerformanceMetricsData
    let memory: MemoryMetricsData
    let database: DatabaseMetricsData
    let network: NetworkMetricsData
    let cache: CacheMetricsData
    let startup: StartupMetricsData
    let backgroundTasks: BackgroundTaskMetricsData
}

struct PerformanceMetricsData: Codable {
    let currentFPS: Double
    let averageFPS: Double
    let minFPS: Double
    let frameDrops: Int
    let slowOperations: Int
}

struct MemoryMetricsData: Codable {
    let currentMB: Double
    let peakMB: Double
    let residentMB: Double
    let virtualMB: Double
    let pressureLevel: String
    let cleanupCount: Int
    let totalFreedMB: Double
}

struct DatabaseMetricsData: Codable {
    let queryCount: Int
    let cacheHitRate: Double
    let averageQueryTimeMs: Double
    let slowQueries: Int
    let batchOperations: Int
}

struct NetworkMetricsData: Codable {
    let totalRequests: Int
    let cacheHitRate: Double
    let deduplicatedRequests: Int
    let averageRequestTimeMs: Double
    let failedRequests: Int
    let successRate: Double
}

struct CacheMetricsData: Codable {
    let imageCacheHitRate: Double
    let imageCacheSizeMB: Double
    let networkCacheHits: Int
    let databaseCacheHits: Int
}

struct StartupMetricsData: Codable {
    let lastLaunchTimeSeconds: Double
    let averageLaunchTimeSeconds: Double
    let launchCount: Int
    let phaseTiming: [StartupPhase: TimeInterval]
}

struct BackgroundTaskMetricsData: Codable {
    let executionCount: Int
    let successRate: Double
    let averageExecutionTimeSeconds: Double
    let expiredCount: Int
}

struct PerformanceReport {
    let currentSnapshot: PerformanceSnapshot
    let recommendations: [Recommendation]
    let trends: PerformanceTrends
    let healthScore: Int

    var healthLevel: String {
        switch healthScore {
        case 90...100: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "Fair"
        case 40..<60: return "Poor"
        default: return "Critical"
        }
    }
}

struct Recommendation {
    enum Priority: Int {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
    }

    let category: String
    let priority: Priority
    let title: String
    let description: String
    let action: String
}

struct PerformanceTrends {
    var fpsAverage: Double = 0
    var fpsTrend: String = "unknown"
    var memoryAverage: Double = 0
    var memoryTrend: String = "unknown"
    var snapshotCount: Int = 0
}
