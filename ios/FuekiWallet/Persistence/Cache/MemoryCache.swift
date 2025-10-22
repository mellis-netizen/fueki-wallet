//
//  MemoryCache.swift
//  FuekiWallet
//
//  In-memory cache implementation with LRU eviction
//

import Foundation
import os.log

/// Thread-safe in-memory cache with LRU eviction policy
final class MemoryCache {
    // MARK: - Cache Entry
    private struct CacheEntry {
        let value: Any
        let expirationDate: Date
        var accessCount: Int
        var lastAccessed: Date

        var isExpired: Bool {
            return Date() > expirationDate
        }
    }

    // MARK: - Properties
    private var cache: [String: CacheEntry] = [:]
    private let queue = DispatchQueue(label: "io.fueki.wallet.memoryCache", attributes: .concurrent)
    private let maxSize: Int
    private var currentSize: Int = 0

    // Statistics
    private var hits: Int = 0
    private var misses: Int = 0

    private let logger = Logger(subsystem: "io.fueki.wallet", category: "MemoryCache")

    // MARK: - Initialization
    init(maxSize: Int) {
        self.maxSize = maxSize
    }

    // MARK: - Cache Operations

    /// Retrieves a value from cache
    func get<T>(key: String) -> T? {
        return queue.sync {
            guard var entry = cache[key], !entry.isExpired else {
                misses += 1
                if cache[key] != nil {
                    // Remove expired entry
                    cache.removeValue(forKey: key)
                }
                return nil
            }

            // Update access metadata
            entry.accessCount += 1
            entry.lastAccessed = Date()
            cache[key] = entry
            hits += 1

            return entry.value as? T
        }
    }

    /// Stores a value in cache
    func set<T>(_ value: T, key: String, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let expirationDate = Date().addingTimeInterval(ttl)
            let entry = CacheEntry(
                value: value,
                expirationDate: expirationDate,
                accessCount: 0,
                lastAccessed: Date()
            )

            // Estimate size (rough approximation)
            let estimatedSize = self.estimateSize(of: value)

            // Remove old entry size if exists
            if let oldEntry = self.cache[key] {
                let oldSize = self.estimateSize(of: oldEntry.value)
                self.currentSize -= oldSize
            }

            self.cache[key] = entry
            self.currentSize += estimatedSize

            // Evict if over capacity
            if self.currentSize > self.maxSize {
                self.evictLRU()
            }
        }
    }

    /// Removes a value from cache
    func remove(key: String) {
        queue.async(flags: .barrier) {
            if let entry = self.cache.removeValue(forKey: key) {
                let size = self.estimateSize(of: entry.value)
                self.currentSize -= size
            }
        }
    }

    /// Clears all cached data
    func clearAll() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
            self.currentSize = 0
            self.hits = 0
            self.misses = 0
        }
    }

    // MARK: - Maintenance

    /// Removes expired items
    func removeExpiredItems() {
        queue.async(flags: .barrier) {
            let expiredKeys = self.cache.filter { $0.value.isExpired }.map { $0.key }

            for key in expiredKeys {
                if let entry = self.cache.removeValue(forKey: key) {
                    let size = self.estimateSize(of: entry.value)
                    self.currentSize -= size
                }
            }

            if !expiredKeys.isEmpty {
                self.logger.info("Removed \(expiredKeys.count) expired items from memory cache")
            }
        }
    }

    /// Trims cache to maximum size using LRU eviction
    func trim() {
        queue.async(flags: .barrier) {
            while self.currentSize > self.maxSize {
                self.evictLRU()
            }
        }
    }

    // MARK: - Statistics

    /// Gets cache statistics
    func getStatistics() -> (size: Int, count: Int, hits: Int, misses: Int) {
        return queue.sync {
            return (
                size: currentSize,
                count: cache.count,
                hits: hits,
                misses: misses
            )
        }
    }

    // MARK: - Private Helpers

    /// Evicts least recently used entry
    private func evictLRU() {
        guard !cache.isEmpty else { return }

        // Find LRU entry (oldest lastAccessed date and lowest access count)
        let lruKey = cache.min { a, b in
            if a.value.accessCount == b.value.accessCount {
                return a.value.lastAccessed < b.value.lastAccessed
            }
            return a.value.accessCount < b.value.accessCount
        }?.key

        if let key = lruKey, let entry = cache.removeValue(forKey: key) {
            let size = estimateSize(of: entry.value)
            currentSize -= size
            logger.debug("Evicted LRU entry: \(key)")
        }
    }

    /// Estimates the size of a value in bytes
    private func estimateSize(of value: Any) -> Int {
        // Rough estimation based on type
        switch value {
        case is String:
            return (value as! String).utf8.count
        case is Data:
            return (value as! Data).count
        case is Int, is Double, is Float:
            return 8
        case is Bool:
            return 1
        case let array as [Any]:
            return array.reduce(0) { $0 + estimateSize(of: $1) }
        case let dict as [String: Any]:
            return dict.reduce(0) { $0 + estimateSize(of: $1.value) }
        default:
            // Default estimate for complex objects
            return 1024 // 1KB default
        }
    }
}
