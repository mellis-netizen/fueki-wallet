//
//  NetworkCache.swift
//  FuekiWallet
//
//  Response caching strategy for network requests
//

import Foundation

/// Network response cache
public final class NetworkCache {

    // MARK: - Types

    private struct CacheEntry {
        let data: Data
        let timestamp: Date
        let expiresAt: Date
        let etag: String?

        var isExpired: Bool {
            Date() > expiresAt
        }
    }

    public enum CachePolicy {
        case noCache
        case cacheOnly
        case networkOnly
        case cacheFirst
        case networkFirst
        case custom(maxAge: TimeInterval)
    }

    // MARK: - Properties

    private var memoryCache: [String: CacheEntry] = [:]
    private let diskCache: DiskCache
    private let queue = DispatchQueue(label: "io.fueki.wallet.cache", qos: .utility)
    private let maxMemoryCacheSize: Int
    private let maxDiskCacheSize: Int
    private let defaultTTL: TimeInterval

    // MARK: - Initialization

    public init(
        maxMemoryCacheSize: Int = 50 * 1024 * 1024, // 50 MB
        maxDiskCacheSize: Int = 200 * 1024 * 1024,   // 200 MB
        defaultTTL: TimeInterval = 300                 // 5 minutes
    ) {
        self.maxMemoryCacheSize = maxMemoryCacheSize
        self.maxDiskCacheSize = maxDiskCacheSize
        self.defaultTTL = defaultTTL
        self.diskCache = DiskCache(maxSize: maxDiskCacheSize)

        // Setup memory warnings observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - Public Methods

    /// Store response in cache
    public func store<T: Encodable>(_ object: T, for endpoint: APIEndpoint, ttl: TimeInterval? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }

            do {
                let data = try JSONEncoder().encode(object)
                let key = self.cacheKey(for: endpoint)
                let expiresAt = Date().addingTimeInterval(ttl ?? self.defaultTTL)

                let entry = CacheEntry(
                    data: data,
                    timestamp: Date(),
                    expiresAt: expiresAt,
                    etag: nil
                )

                // Store in memory
                self.memoryCache[key] = entry

                // Store on disk asynchronously
                Task {
                    await self.diskCache.store(data, for: key, expiresAt: expiresAt)
                }

                // Enforce memory limits
                self.enforceMemoryLimits()
            } catch {
                // Silently fail on encoding errors
            }
        }
    }

    /// Retrieve cached response
    public func retrieve<T: Decodable>(for endpoint: APIEndpoint) -> T? {
        let key = cacheKey(for: endpoint)

        // Check memory cache first
        if let entry = memoryCache[key], !entry.isExpired {
            return try? JSONDecoder().decode(T.self, from: entry.data)
        }

        // Check disk cache
        if let data = diskCache.retrieve(for: key) {
            let object = try? JSONDecoder().decode(T.self, from: data)

            // Promote to memory cache
            if let object = object, let encoded = try? JSONEncoder().encode(object) {
                let entry = CacheEntry(
                    data: encoded,
                    timestamp: Date(),
                    expiresAt: Date().addingTimeInterval(defaultTTL),
                    etag: nil
                )
                memoryCache[key] = entry
            }

            return object
        }

        return nil
    }

    /// Remove cached response
    public func remove(for endpoint: APIEndpoint) {
        let key = cacheKey(for: endpoint)

        queue.async { [weak self] in
            self?.memoryCache.removeValue(forKey: key)
            Task {
                await self?.diskCache.remove(for: key)
            }
        }
    }

    /// Clear all caches
    public func clear() {
        clearMemoryCache()
        Task {
            await diskCache.clear()
        }
    }

    /// Check if response is cached
    public func isCached(for endpoint: APIEndpoint) -> Bool {
        let key = cacheKey(for: endpoint)

        if let entry = memoryCache[key], !entry.isExpired {
            return true
        }

        return diskCache.exists(for: key)
    }

    // MARK: - Private Methods

    private func cacheKey(for endpoint: APIEndpoint) -> String {
        guard let url = endpoint.url else {
            return endpoint.path
        }

        // Include query parameters in key
        return url.absoluteString
    }

    @objc private func clearMemoryCache() {
        queue.async { [weak self] in
            self?.memoryCache.removeAll()
        }
    }

    private func enforceMemoryLimits() {
        let totalSize = memoryCache.values.reduce(0) { $0 + $1.data.count }

        guard totalSize > maxMemoryCacheSize else { return }

        // Remove oldest entries first
        let sorted = memoryCache.sorted { $0.value.timestamp < $1.value.timestamp }
        var currentSize = totalSize

        for (key, entry) in sorted {
            if currentSize <= maxMemoryCacheSize * 3 / 4 {
                break
            }

            memoryCache.removeValue(forKey: key)
            currentSize -= entry.data.count
        }
    }
}

// MARK: - Disk Cache
private actor DiskCache {

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxSize: Int

    init(maxSize: Int) {
        self.maxSize = maxSize

        // Setup cache directory
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        self.cacheDirectory = paths[0].appendingPathComponent("FuekiNetworkCache", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func store(_ data: Data, for key: String, expiresAt: Date) async {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())

        do {
            try data.write(to: fileURL)

            // Store expiration as extended attribute
            let expirationData = "\(expiresAt.timeIntervalSince1970)".data(using: .utf8)!
            try fileURL.setExtendedAttribute(data: expirationData, forName: "expiration")
        } catch {
            // Silently fail
        }
    }

    func retrieve(for key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // Check expiration
        if let expirationData = try? fileURL.extendedAttribute(forName: "expiration"),
           let expirationString = String(data: expirationData, encoding: .utf8),
           let expirationTimestamp = TimeInterval(expirationString) {
            let expiresAt = Date(timeIntervalSince1970: expirationTimestamp)

            if Date() > expiresAt {
                try? fileManager.removeItem(at: fileURL)
                return nil
            }
        }

        return try? Data(contentsOf: fileURL)
    }

    func remove(for key: String) async {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        try? fileManager.removeItem(at: fileURL)
    }

    func clear() async {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func exists(for key: String) -> Bool {
        let fileURL = cacheDirectory.appendingPathComponent(key.sha256())
        return fileManager.fileExists(atPath: fileURL.path)
    }
}

// MARK: - String Extensions
private extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }

        var hash = [UInt8](repeating: 0, count: Int(32))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - URL Extended Attributes
private extension URL {
    func setExtendedAttribute(data: Data, forName name: String) throws {
        try data.withUnsafeBytes { bytes in
            let result = setxattr(path, name, bytes.baseAddress, data.count, 0, 0)
            guard result >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        }
    }

    func extendedAttribute(forName name: String) throws -> Data {
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(path, name, bytes.baseAddress, data.count, 0, 0)
        }

        guard result >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        return data
    }
}

// CommonCrypto placeholder
private func CC_SHA256(_ data: UnsafeRawPointer?, _ len: CC_LONG, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>? {
    return md
}

private typealias CC_LONG = UInt32
