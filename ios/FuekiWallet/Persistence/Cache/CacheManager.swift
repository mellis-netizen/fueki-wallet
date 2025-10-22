//
//  CacheManager.swift
//  FuekiWallet
//
//  Manages both memory and disk caching
//

import Foundation
import os.log

/// Unified cache manager coordinating memory and disk caching
final class CacheManager {
    // MARK: - Singleton
    static let shared = CacheManager()

    // MARK: - Properties
    private let memoryCache: MemoryCache
    private let diskCache: DiskCache
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "CacheManager")

    // Cache configuration
    private let config: CacheConfiguration

    // MARK: - Initialization
    private init(config: CacheConfiguration = .default) {
        self.config = config
        self.memoryCache = MemoryCache(maxSize: config.memoryMaxSize)
        self.diskCache = DiskCache(maxSize: config.diskMaxSize)

        logger.info("CacheManager initialized")
    }

    // MARK: - Generic Cache Operations

    /// Retrieves a value from cache (memory first, then disk)
    func get<T: Codable>(key: String) -> T? {
        // Try memory cache first
        if let value: T = memoryCache.get(key: key) {
            logger.debug("Cache hit (memory): \(key)")
            return value
        }

        // Fall back to disk cache
        if let value: T = diskCache.get(key: key) {
            logger.debug("Cache hit (disk): \(key)")
            // Promote to memory cache
            memoryCache.set(value, key: key, ttl: config.defaultTTL)
            return value
        }

        logger.debug("Cache miss: \(key)")
        return nil
    }

    /// Stores a value in cache (both memory and disk if enabled)
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval? = nil) {
        let effectiveTTL = ttl ?? config.defaultTTL

        // Store in memory cache
        memoryCache.set(value, key: key, ttl: effectiveTTL)

        // Store in disk cache if enabled
        if config.diskCacheEnabled {
            diskCache.set(value, key: key, ttl: effectiveTTL)
        }

        logger.debug("Cache set: \(key)")
    }

    /// Removes a value from cache
    func remove(key: String) {
        memoryCache.remove(key: key)
        diskCache.remove(key: key)
        logger.debug("Cache removed: \(key)")
    }

    /// Clears all cached data
    func clearAll() {
        memoryCache.clearAll()
        diskCache.clearAll()
        logger.info("All cache cleared")
    }

    // MARK: - Specialized Cache Operations

    /// Caches an image
    func cacheImage(_ data: Data, key: String) {
        diskCache.set(data, key: "image_\(key)", ttl: config.imageTTL)
    }

    /// Retrieves a cached image
    func getImage(key: String) -> Data? {
        return diskCache.get(key: "image_\(key)")
    }

    /// Caches API response
    func cacheAPIResponse<T: Codable>(_ response: T, endpoint: String, ttl: TimeInterval? = nil) {
        let key = "api_\(endpoint)"
        set(response, key: key, ttl: ttl ?? config.apiResponseTTL)
    }

    /// Retrieves cached API response
    func getAPIResponse<T: Codable>(endpoint: String) -> T? {
        let key = "api_\(endpoint)"
        return get(key: key)
    }

    // MARK: - Cache Statistics

    /// Gets current cache statistics
    func getStatistics() -> CacheStatistics {
        let memoryStats = memoryCache.getStatistics()
        let diskStats = diskCache.getStatistics()

        return CacheStatistics(
            memorySize: memoryStats.size,
            memoryCount: memoryStats.count,
            memoryHits: memoryStats.hits,
            memoryMisses: memoryStats.misses,
            diskSize: diskStats.size,
            diskCount: diskStats.count,
            diskHits: diskStats.hits,
            diskMisses: diskStats.misses
        )
    }

    /// Prints cache statistics
    func logStatistics() {
        let stats = getStatistics()
        logger.info("""
        Cache Statistics:
        Memory: \(stats.memoryCount) items, \(stats.memorySize / 1024 / 1024)MB
        Memory Hit Rate: \(stats.memoryHitRate)%
        Disk: \(stats.diskCount) items, \(stats.diskSize / 1024 / 1024)MB
        Disk Hit Rate: \(stats.diskHitRate)%
        """)
    }

    // MARK: - Cache Maintenance

    /// Removes expired items from cache
    func removeExpiredItems() {
        memoryCache.removeExpiredItems()
        diskCache.removeExpiredItems()
        logger.info("Expired cache items removed")
    }

    /// Trims cache to maximum size
    func trim() {
        memoryCache.trim()
        diskCache.trim()
        logger.info("Cache trimmed")
    }

    /// Performs cache optimization
    func optimize() async {
        removeExpiredItems()
        trim()
        await diskCache.compact()
        logger.info("Cache optimized")
    }
}

// MARK: - Cache Configuration
struct CacheConfiguration {
    let memoryMaxSize: Int // in bytes
    let diskMaxSize: Int // in bytes
    let defaultTTL: TimeInterval
    let imageTTL: TimeInterval
    let apiResponseTTL: TimeInterval
    let diskCacheEnabled: Bool

    static let `default` = CacheConfiguration(
        memoryMaxSize: 50 * 1024 * 1024, // 50MB
        diskMaxSize: 200 * 1024 * 1024, // 200MB
        defaultTTL: 300, // 5 minutes
        imageTTL: 3600, // 1 hour
        apiResponseTTL: 60, // 1 minute
        diskCacheEnabled: true
    )
}

// MARK: - Cache Statistics
struct CacheStatistics {
    let memorySize: Int
    let memoryCount: Int
    let memoryHits: Int
    let memoryMisses: Int
    let diskSize: Int
    let diskCount: Int
    let diskHits: Int
    let diskMisses: Int

    var memoryHitRate: Double {
        let total = memoryHits + memoryMisses
        return total > 0 ? (Double(memoryHits) / Double(total)) * 100 : 0
    }

    var diskHitRate: Double {
        let total = diskHits + diskMisses
        return total > 0 ? (Double(diskHits) / Double(total)) * 100 : 0
    }
}
