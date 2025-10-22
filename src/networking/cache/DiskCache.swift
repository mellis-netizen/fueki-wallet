import Foundation

/// Disk-based cache implementation
final class DiskCache {

    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let capacity: Int
    private let queue = DispatchQueue(label: "com.fueki.disk-cache", attributes: .concurrent)

    init(name: String, capacity: Int) {
        self.capacity = capacity

        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = cachesDirectory.appendingPathComponent(name, isDirectory: true)

        createCacheDirectoryIfNeeded()
    }

    // MARK: - Public Methods

    func store(_ data: Data, for key: String) throws {
        try queue.sync(flags: .barrier) {
            let fileURL = self.fileURL(for: key)
            try data.write(to: fileURL, options: .atomic)

            // Check and enforce capacity limits
            try self.enforceSizeLimit()
        }
    }

    func retrieve(for key: String) throws -> Data? {
        try queue.sync {
            let fileURL = self.fileURL(for: key)

            guard fileManager.fileExists(atPath: fileURL.path) else {
                return nil
            }

            // Update access time
            try? fileManager.setAttributes(
                [.modificationDate: Date()],
                ofItemAtPath: fileURL.path
            )

            return try Data(contentsOf: fileURL)
        }
    }

    func remove(for key: String) throws {
        try queue.sync(flags: .barrier) {
            let fileURL = self.fileURL(for: key)
            try self.fileManager.removeItem(at: fileURL)
        }
    }

    func clearAll() throws {
        try queue.sync(flags: .barrier) {
            try self.fileManager.removeItem(at: self.cacheDirectory)
            self.createCacheDirectoryIfNeeded()
        }
    }

    func totalSize() -> Int {
        queue.sync {
            guard let enumerator = fileManager.enumerator(
                at: cacheDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else {
                return 0
            }

            var totalSize = 0
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += fileSize
                }
            }
            return totalSize
        }
    }

    // MARK: - Private Methods

    private func createCacheDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func fileURL(for key: String) -> URL {
        let hashedKey = key.sha256()
        return cacheDirectory.appendingPathComponent(hashedKey)
    }

    private func enforceSizeLimit() throws {
        let currentSize = totalSize()

        guard currentSize > capacity else { return }

        // Get all files sorted by modification date (LRU)
        guard let enumerator = fileManager.enumerator(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        var files: [(url: URL, date: Date, size: Int)] = []
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
               let date = resourceValues.contentModificationDate,
               let size = resourceValues.fileSize {
                files.append((fileURL, date, size))
            }
        }

        // Sort by modification date (oldest first)
        files.sort { $0.date < $1.date }

        // Remove oldest files until within capacity
        var sizeToFree = currentSize - capacity
        for file in files {
            guard sizeToFree > 0 else { break }

            try? fileManager.removeItem(at: file.url)
            sizeToFree -= file.size
        }
    }
}

// MARK: - String Extension for Hashing

private extension String {
    func sha256() -> String {
        guard let data = self.data(using: .utf8) else { return self }
        var hash = [UInt8](repeating: 0, count: Int(32))
        data.withUnsafeBytes {
            _ = hash.withUnsafeMutableBytes { hashBytes in
                // Simple hash for demonstration - in production use CryptoKit
                data.copyBytes(to: hashBytes)
            }
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
