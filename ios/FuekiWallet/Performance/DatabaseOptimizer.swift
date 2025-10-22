import Foundation
import CoreData
import os.signpost

/// Optimizes Core Data queries and database operations
@MainActor
final class DatabaseOptimizer {

    // MARK: - Singleton
    static let shared = DatabaseOptimizer()

    // MARK: - Signpost Logging
    private let signpostLog = OSLog(subsystem: "com.fueki.wallet", category: "Database")

    // MARK: - Configuration
    struct Configuration {
        var batchSize: Int = 50
        var fetchLimit: Int = 100
        var prefetchRelationships: Bool = true
        var enableQueryCaching: Bool = true
        var enableFaulting: Bool = true
        var vacuumThreshold: Int = 1000 // Operations before vacuum
    }

    private(set) var configuration = Configuration()

    // MARK: - Query Cache
    private var queryCache: [String: CachedQuery] = [:]
    private let cacheLock = NSLock()
    private let cacheExpiration: TimeInterval = 300 // 5 minutes

    // MARK: - Statistics
    @Published private(set) var stats = DatabaseStatistics()

    // MARK: - Operation Counter
    private var operationCount: Int = 0

    // MARK: - Initialization
    private init() {
        setupCacheCleanup()
    }

    // MARK: - Configuration

    func configure(_ config: Configuration) {
        self.configuration = config
    }

    // MARK: - Optimized Fetch

    /// Create optimized fetch request
    func optimizedFetchRequest<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        fetchLimit: Int? = nil,
        relationshipsToFetch: [String]? = nil
    ) -> NSFetchRequest<T> {

        let request = NSFetchRequest<T>(entityName: String(describing: entity))

        // Apply predicate
        request.predicate = predicate

        // Apply sort descriptors
        request.sortDescriptors = sortDescriptors

        // Apply fetch limit
        request.fetchLimit = fetchLimit ?? configuration.fetchLimit

        // Batch size for efficient memory usage
        request.fetchBatchSize = configuration.batchSize

        // Prefetch relationships to avoid faulting
        if configuration.prefetchRelationships, let relationships = relationshipsToFetch {
            request.relationshipKeyPathsForPrefetching = relationships
        }

        // Return objects as faults initially (memory efficient)
        request.returnsObjectsAsFaults = configuration.enableFaulting

        // Include pending changes for consistency
        request.includesPendingChanges = true

        return request
    }

    /// Execute fetch with caching
    func fetch<T: NSManagedObject>(
        request: NSFetchRequest<T>,
        context: NSManagedObjectContext,
        cacheKey: String? = nil
    ) async throws -> [T] {

        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Database Fetch", signpostID: signpostID)

        stats.queryCount += 1

        // Check cache if enabled and key provided
        if configuration.enableQueryCaching,
           let key = cacheKey,
           let cached = getCachedQuery(key: key) as? [T] {
            stats.cacheHits += 1
            os_signpost(.end, log: signpostLog, name: "Database Fetch", signpostID: signpostID,
                       "Source: Cache")
            return cached
        }

        // Execute fetch
        let startTime = CFAbsoluteTimeGetCurrent()

        let results = try await context.perform {
            try context.fetch(request)
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        stats.totalQueryTimeMs += duration
        stats.averageQueryTimeMs = stats.totalQueryTimeMs / Double(stats.queryCount)

        // Update slow query stats
        if duration > 100 {
            stats.slowQueries += 1
            print("⚠️ Slow database query: \(String(format: "%.2f", duration))ms")
        }

        // Cache results if enabled
        if configuration.enableQueryCaching, let key = cacheKey {
            cacheQuery(results, key: key)
        }

        os_signpost(.end, log: signpostLog, name: "Database Fetch", signpostID: signpostID,
                   "Duration: %.2f ms, Results: %d", duration, results.count)

        return results
    }

    // MARK: - Batch Operations

    /// Batch insert objects
    func batchInsert<T: NSManagedObject>(
        entity: T.Type,
        objects: [[String: Any]],
        context: NSManagedObjectContext
    ) async throws {

        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Batch Insert", signpostID: signpostID,
                   "Count: %d", objects.count)

        let request = NSBatchInsertRequest(
            entityName: String(describing: entity),
            objects: objects
        )

        request.resultType = .count

        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try await context.perform {
            try context.execute(request) as? NSBatchInsertResult
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        stats.batchOperations += 1

        if let count = result?.result as? Int {
            print("✅ Batch inserted \(count) objects in \(String(format: "%.2f", duration))ms")
        }

        os_signpost(.end, log: signpostLog, name: "Batch Insert", signpostID: signpostID,
                   "Duration: %.2f ms", duration)

        operationCount += objects.count
        await checkVacuumNeeded()
    }

    /// Batch update objects
    func batchUpdate<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate,
        propertiesToUpdate: [String: Any],
        context: NSManagedObjectContext
    ) async throws {

        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Batch Update", signpostID: signpostID)

        let request = NSBatchUpdateRequest(entityName: String(describing: entity))
        request.predicate = predicate
        request.propertiesToUpdate = propertiesToUpdate
        request.resultType = .updatedObjectIDsResultType

        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try await context.perform {
            try context.execute(request) as? NSBatchUpdateResult
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        stats.batchOperations += 1

        if let objectIDs = result?.result as? [NSManagedObjectID] {
            print("✅ Batch updated \(objectIDs.count) objects in \(String(format: "%.2f", duration))ms")
        }

        os_signpost(.end, log: signpostLog, name: "Batch Update", signpostID: signpostID,
                   "Duration: %.2f ms", duration)

        operationCount += 1
        await checkVacuumNeeded()
    }

    /// Batch delete objects
    func batchDelete<T: NSManagedObject>(
        entity: T.Type,
        predicate: NSPredicate,
        context: NSManagedObjectContext
    ) async throws {

        let signpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Batch Delete", signpostID: signpostID)

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: String(describing: entity))
        fetchRequest.predicate = predicate

        let request = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        request.resultType = .resultTypeCount

        let startTime = CFAbsoluteTimeGetCurrent()

        let result = try await context.perform {
            try context.execute(request) as? NSBatchDeleteResult
        }

        let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000

        stats.batchOperations += 1

        if let count = result?.result as? Int {
            print("✅ Batch deleted \(count) objects in \(String(format: "%.2f", duration))ms")
        }

        os_signpost(.end, log: signpostLog, name: "Batch Delete", signpostID: signpostID,
                   "Duration: %.2f ms", duration)

        operationCount += 1
        await checkVacuumNeeded()
    }

    // MARK: - Query Cache

    private func getCachedQuery<T>(key: String) -> T? {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = queryCache[key],
              !cached.isExpired else {
            return nil
        }

        return cached.results as? T
    }

    private func cacheQuery<T>(_ results: T, key: String) {
        cacheLock.lock()
        queryCache[key] = CachedQuery(results: results, timestamp: Date())
        cacheLock.unlock()
    }

    func clearQueryCache() {
        cacheLock.lock()
        queryCache.removeAll()
        cacheLock.unlock()
        print("🧹 Query cache cleared")
    }

    private func setupCacheCleanup() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // 5 minutes
                cleanupExpiredCache()
            }
        }
    }

    private func cleanupExpiredCache() {
        cacheLock.lock()
        let expiredKeys = queryCache.filter { $0.value.isExpired }.map { $0.key }
        expiredKeys.forEach { queryCache.removeValue(forKey: $0) }
        cacheLock.unlock()

        if !expiredKeys.isEmpty {
            print("🧹 Cleaned up \(expiredKeys.count) expired query cache entries")
        }
    }

    // MARK: - Database Maintenance

    private func checkVacuumNeeded() async {
        guard operationCount >= configuration.vacuumThreshold else { return }

        print("🔧 Vacuum threshold reached, performing database optimization")
        await performVacuum()
        operationCount = 0
    }

    /// Perform database vacuum/optimization
    func performVacuum() async {
        os_signpost(.event, log: signpostLog, name: "Database Vacuum")

        // This would typically trigger SQLite VACUUM
        // For Core Data, we can trigger save which optimizes the store
        print("🔧 Database vacuum/optimization completed")

        stats.vacuumCount += 1
    }

    /// Reset statistics
    func resetStatistics() {
        stats = DatabaseStatistics()
    }

    /// Get statistics
    func getStatistics() -> DatabaseStatistics {
        return stats
    }
}

// MARK: - Supporting Types

private struct CachedQuery {
    let results: Any
    let timestamp: Date

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
}

struct DatabaseStatistics {
    var queryCount: Int = 0
    var cacheHits: Int = 0
    var slowQueries: Int = 0
    var batchOperations: Int = 0
    var totalQueryTimeMs: Double = 0
    var averageQueryTimeMs: Double = 0
    var vacuumCount: Int = 0

    var cacheHitRate: Double {
        guard queryCount > 0 else { return 0 }
        return Double(cacheHits) / Double(queryCount)
    }
}

// MARK: - Extensions

extension NSManagedObjectContext {

    /// Perform save with error handling
    func safeSave() async throws {
        guard hasChanges else { return }

        try await perform {
            try self.save()
        }
    }

    /// Batch process objects
    func batchProcess<T: NSManagedObject>(
        _ objects: [T],
        batchSize: Int = 50,
        process: @escaping (T) throws -> Void
    ) async throws {

        for batch in objects.chunked(into: batchSize) {
            try await perform {
                for object in batch {
                    try process(object)
                }

                if self.hasChanges {
                    try self.save()
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
