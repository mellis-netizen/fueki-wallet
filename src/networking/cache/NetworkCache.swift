import Foundation

/// Network response cache manager
final class NetworkCache {

    static let shared = NetworkCache()

    private let urlCache: URLCache
    private let diskCache: DiskCache
    private let memoryCache: NSCache<NSString, CachedResponse>

    struct CacheConfiguration {
        let memoryCapacity: Int
        let diskCapacity: Int
        let defaultTTL: TimeInterval

        static let `default` = CacheConfiguration(
            memoryCapacity: 50 * 1024 * 1024,  // 50 MB
            diskCapacity: 100 * 1024 * 1024,   // 100 MB
            defaultTTL: 300                     // 5 minutes
        )
    }

    private let configuration: CacheConfiguration

    // MARK: - Initialization

    init(configuration: CacheConfiguration = .default) {
        self.configuration = configuration

        // URL cache for standard HTTP caching
        self.urlCache = URLCache(
            memoryCapacity: configuration.memoryCapacity,
            diskCapacity: configuration.diskCapacity,
            diskPath: "fueki-network-cache"
        )
        URLCache.shared = urlCache

        // Custom disk cache for extended control
        self.diskCache = DiskCache(
            name: "fueki-cache",
            capacity: configuration.diskCapacity
        )

        // Memory cache for fast access
        self.memoryCache = NSCache()
        memoryCache.totalCostLimit = configuration.memoryCapacity
    }

    // MARK: - Cache Operations

    /// Store response in cache
    func store<T: Codable>(
        _ response: T,
        for key: String,
        ttl: TimeInterval? = nil
    ) throws {
        let cachedResponse = CachedResponse(
            data: response,
            timestamp: Date(),
            ttl: ttl ?? configuration.defaultTTL
        )

        // Store in memory cache
        memoryCache.setObject(cachedResponse, forKey: key as NSString)

        // Store in disk cache
        let encoder = JSONEncoder()
        let data = try encoder.encode(cachedResponse)
        try diskCache.store(data, for: key)
    }

    /// Retrieve response from cache
    func retrieve<T: Codable>(
        for key: String,
        as type: T.Type
    ) throws -> T? {
        // Check memory cache first
        if let cached = memoryCache.object(forKey: key as NSString) {
            if !cached.isExpired {
                return cached.data as? T
            } else {
                memoryCache.removeObject(forKey: key as NSString)
            }
        }

        // Check disk cache
        guard let data = try diskCache.retrieve(for: key) else {
            return nil
        }

        let decoder = JSONDecoder()
        let cached = try decoder.decode(CachedResponse.self, from: data)

        if !cached.isExpired {
            // Promote to memory cache
            memoryCache.setObject(cached, forKey: key as NSString)
            return cached.data as? T
        } else {
            // Remove expired entry
            try diskCache.remove(for: key)
            return nil
        }
    }

    /// Remove specific cache entry
    func remove(for key: String) throws {
        memoryCache.removeObject(forKey: key as NSString)
        try diskCache.remove(for: key)
    }

    /// Clear all cache
    func clearAll() throws {
        memoryCache.removeAllObjects()
        try diskCache.clearAll()
        urlCache.removeAllCachedResponses()
    }

    /// Get cache size
    func cacheSize() -> (memory: Int, disk: Int) {
        let diskSize = diskCache.totalSize()
        return (memory: 0, disk: diskSize) // Memory size tracking would require custom implementation
    }
}

// MARK: - Cached Response

final class CachedResponse: NSObject, Codable {
    let data: Any
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }

    init(data: Any, timestamp: Date, ttl: TimeInterval) {
        self.data = data
        self.timestamp = timestamp
        self.ttl = ttl
    }

    enum CodingKeys: String, CodingKey {
        case data, timestamp, ttl
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(ttl, forKey: .ttl)

        if let encodable = data as? Encodable {
            try container.encode(AnyEncodable(encodable), forKey: .data)
        }
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        ttl = try container.decode(TimeInterval.self, forKey: .ttl)

        // Decode as generic JSON
        data = try container.decode(AnyCodable.self, forKey: .data).value
    }
}

// MARK: - Helper Types

private struct AnyEncodable: Encodable {
    let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

private struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable(value: $0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable(value: $0) })
        default:
            try container.encodeNil()
        }
    }

    private init(value: Any) {
        self.value = value
    }
}
