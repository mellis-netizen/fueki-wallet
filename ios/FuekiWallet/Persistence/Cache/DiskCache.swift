//
//  DiskCache.swift
//  FuekiWallet
//
//  Disk-based cache implementation with file protection
//

import Foundation
import os.log

/// Thread-safe disk cache with file protection and automatic cleanup
final class DiskCache {
    // MARK: - Cache Metadata
    private struct CacheMetadata: Codable {
        let key: String
        let expirationDate: Date
        let createdDate: Date
        var lastAccessedDate: Date
        var accessCount: Int
        let fileSize: Int

        var isExpired: Bool {
            return Date() > expirationDate
        }
    }

    // MARK: - Properties
    private let cacheDirectory: URL
    private let metadataFile: URL
    private var metadata: [String: CacheMetadata] = [:]
    private let queue = DispatchQueue(label: "io.fueki.wallet.diskCache", attributes: .concurrent)
    private let fileManager = FileManager.default
    private let maxSize: Int

    // Statistics
    private var hits: Int = 0
    private var misses: Int = 0

    private let logger = Logger(subsystem: "io.fueki.wallet", category: "DiskCache")

    // MARK: - Initialization
    init(maxSize: Int) {
        self.maxSize = maxSize

        // Setup cache directory
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesURL.appendingPathComponent("FuekiWallet", isDirectory: true)
        self.metadataFile = cacheDirectory.appendingPathComponent("metadata.json")

        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Load metadata
        loadMetadata()
    }

    // MARK: - Cache Operations

    /// Retrieves a value from disk cache
    func get<T: Codable>(key: String) -> T? {
        return queue.sync {
            guard var meta = metadata[key], !meta.isExpired else {
                misses += 1
                if metadata[key] != nil {
                    // Remove expired entry
                    removeInternal(key: key)
                }
                return nil
            }

            let fileURL = getCacheFileURL(for: key)

            guard let data = try? Data(contentsOf: fileURL) else {
                misses += 1
                return nil
            }

            let decoder = JSONDecoder()
            guard let value = try? decoder.decode(T.self, from: data) else {
                misses += 1
                return nil
            }

            // Update access metadata
            meta.accessCount += 1
            meta.lastAccessedDate = Date()
            metadata[key] = meta
            saveMetadata()
            hits += 1

            return value
        }
    }

    /// Stores a value in disk cache
    func set<T: Codable>(_ value: T, key: String, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            let encoder = JSONEncoder()
            guard let data = try? encoder.encode(value) else {
                self.logger.error("Failed to encode value for key: \(key)")
                return
            }

            let fileURL = self.getCacheFileURL(for: key)

            do {
                // Write data with file protection
                try data.write(to: fileURL, options: .completeFileProtection)

                // Create metadata
                let meta = CacheMetadata(
                    key: key,
                    expirationDate: Date().addingTimeInterval(ttl),
                    createdDate: Date(),
                    lastAccessedDate: Date(),
                    accessCount: 0,
                    fileSize: data.count
                )

                self.metadata[key] = meta
                self.saveMetadata()

                // Check if we need to evict
                if self.getCurrentSize() > self.maxSize {
                    self.evictLRU()
                }
            } catch {
                self.logger.error("Failed to write cache file: \(error.localizedDescription)")
            }
        }
    }

    /// Removes a value from disk cache
    func remove(key: String) {
        queue.async(flags: .barrier) {
            self.removeInternal(key: key)
        }
    }

    /// Clears all cached data
    func clearAll() {
        queue.async(flags: .barrier) {
            do {
                // Remove all cache files
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.cacheDirectory,
                    includingPropertiesForKeys: nil
                )

                for file in contents where file != self.metadataFile {
                    try? self.fileManager.removeItem(at: file)
                }

                // Clear metadata
                self.metadata.removeAll()
                self.saveMetadata()
                self.hits = 0
                self.misses = 0

                self.logger.info("Disk cache cleared")
            } catch {
                self.logger.error("Failed to clear disk cache: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Maintenance

    /// Removes expired items
    func removeExpiredItems() {
        queue.async(flags: .barrier) {
            let expiredKeys = self.metadata.filter { $0.value.isExpired }.map { $0.key }

            for key in expiredKeys {
                self.removeInternal(key: key)
            }

            if !expiredKeys.isEmpty {
                self.logger.info("Removed \(expiredKeys.count) expired items from disk cache")
            }
        }
    }

    /// Trims cache to maximum size
    func trim() {
        queue.async(flags: .barrier) {
            while self.getCurrentSize() > self.maxSize {
                self.evictLRU()
            }
        }
    }

    /// Compacts disk cache by removing fragmentation
    func compact() async {
        await withCheckedContinuation { continuation in
            queue.async(flags: .barrier) {
                // Remove expired items
                self.removeExpiredItems()

                // Rebuild metadata file
                self.saveMetadata()

                self.logger.info("Disk cache compacted")
                continuation.resume()
            }
        }
    }

    // MARK: - Statistics

    /// Gets cache statistics
    func getStatistics() -> (size: Int, count: Int, hits: Int, misses: Int) {
        return queue.sync {
            return (
                size: getCurrentSize(),
                count: metadata.count,
                hits: hits,
                misses: misses
            )
        }
    }

    // MARK: - Private Helpers

    private func getCacheFileURL(for key: String) -> URL {
        let filename = key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
        return cacheDirectory.appendingPathComponent("\(filename).cache")
    }

    private func removeInternal(key: String) {
        let fileURL = getCacheFileURL(for: key)
        try? fileManager.removeItem(at: fileURL)
        metadata.removeValue(forKey: key)
        saveMetadata()
    }

    private func getCurrentSize() -> Int {
        return metadata.values.reduce(0) { $0 + $1.fileSize }
    }

    private func evictLRU() {
        guard !metadata.isEmpty else { return }

        // Find LRU entry
        let lruKey = metadata.min { a, b in
            if a.value.accessCount == b.value.accessCount {
                return a.value.lastAccessedDate < b.value.lastAccessedDate
            }
            return a.value.accessCount < b.value.accessCount
        }?.key

        if let key = lruKey {
            removeInternal(key: key)
            logger.debug("Evicted LRU entry from disk: \(key)")
        }
    }

    private func loadMetadata() {
        guard fileManager.fileExists(atPath: metadataFile.path) else { return }

        do {
            let data = try Data(contentsOf: metadataFile)
            let decoder = JSONDecoder()
            metadata = try decoder.decode([String: CacheMetadata].self, from: data)
            logger.info("Loaded disk cache metadata: \(metadata.count) entries")
        } catch {
            logger.error("Failed to load cache metadata: \(error.localizedDescription)")
            metadata = [:]
        }
    }

    private func saveMetadata() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(metadata)
            try data.write(to: metadataFile, options: .atomic)
        } catch {
            logger.error("Failed to save cache metadata: \(error.localizedDescription)")
        }
    }
}
