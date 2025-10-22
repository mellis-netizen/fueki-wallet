import Foundation
import UIKit
import SwiftUI
import CryptoKit

/// Optimized image caching system with memory and disk persistence
@MainActor
final class ImageCacheOptimizer: ObservableObject {

    // MARK: - Singleton
    static let shared = ImageCacheOptimizer()

    // MARK: - Configuration
    struct Configuration {
        var memoryCapacity: Int = 50 * 1024 * 1024 // 50 MB
        var diskCapacity: Int = 100 * 1024 * 1024 // 100 MB
        var maxImageDimension: CGFloat = 1024
        var compressionQuality: CGFloat = 0.8
        var prefetchCount: Int = 5
        var enableDiskCache: Bool = true
        var cacheDuration: TimeInterval = 86400 // 24 hours
    }

    private(set) var configuration = Configuration()

    // MARK: - Caches
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskCacheURL: URL
    private let fileManager = FileManager.default

    // MARK: - Loading State
    @Published private(set) var activeDownloads: Set<String> = []
    private let downloadQueue = DispatchQueue(label: "com.fueki.imagecache", attributes: .concurrent)
    private var downloadTasks: [String: Task<UIImage, Error>] = [:]

    // MARK: - Statistics
    @Published private(set) var stats = CacheStatistics()

    // MARK: - URL Session
    private let urlSession: URLSession

    // MARK: - Initialization
    private init() {
        // Setup disk cache directory
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cacheDirectory.appendingPathComponent("ImageCache")

        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)

        // Configure URL session
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(
            memoryCapacity: configuration.memoryCapacity,
            diskCapacity: configuration.diskCapacity
        )
        urlSession = URLSession(configuration: config)

        // Configure memory cache
        memoryCache.totalCostLimit = configuration.memoryCapacity
        memoryCache.countLimit = 100

        setupMemoryWarningHandler()
        setupCacheCleanup()
    }

    // MARK: - Configuration

    func configure(_ config: Configuration) {
        self.configuration = config
        memoryCache.totalCostLimit = config.memoryCapacity
    }

    // MARK: - Image Loading

    /// Load image from URL with caching
    func loadImage(from url: URL) async throws -> UIImage {
        let cacheKey = cacheKey(for: url)

        // Check memory cache
        if let cached = memoryCache.object(forKey: cacheKey as NSString) {
            stats.memoryHits += 1
            return cached
        }

        // Check disk cache
        if configuration.enableDiskCache,
           let cached = loadFromDiskCache(key: cacheKey) {
            stats.diskHits += 1
            // Store in memory cache
            cacheInMemory(cached, key: cacheKey)
            return cached
        }

        // Check if download is already in progress
        if let existingTask = downloadTasks[cacheKey] {
            return try await existingTask.value
        }

        // Download image
        let task = Task<UIImage, Error> {
            try await downloadImage(from: url, cacheKey: cacheKey)
        }

        downloadTasks[cacheKey] = task
        activeDownloads.insert(cacheKey)

        defer {
            downloadTasks.removeValue(forKey: cacheKey)
            activeDownloads.remove(cacheKey)
        }

        return try await task.value
    }

    /// Load image with placeholder
    func loadImage(from url: URL, placeholder: UIImage) async -> UIImage {
        do {
            return try await loadImage(from: url)
        } catch {
            print("⚠️ Failed to load image from \(url): \(error)")
            return placeholder
        }
    }

    /// Prefetch images
    func prefetch(urls: [URL]) {
        Task {
            for url in urls.prefix(configuration.prefetchCount) {
                _ = try? await loadImage(from: url)
            }
        }
    }

    /// Cancel prefetch
    func cancelPrefetch(urls: [URL]) {
        for url in urls {
            let key = cacheKey(for: url)
            downloadTasks[key]?.cancel()
            downloadTasks.removeValue(forKey: key)
            activeDownloads.remove(key)
        }
    }

    // MARK: - Private Download

    private func downloadImage(from url: URL, cacheKey: String) async throws -> UIImage {
        stats.networkRequests += 1

        let (data, response) = try await urlSession.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ImageCacheError.invalidResponse
        }

        guard let image = UIImage(data: data) else {
            throw ImageCacheError.invalidImageData
        }

        // Optimize image
        let optimized = optimizeImage(image)

        // Cache in memory
        cacheInMemory(optimized, key: cacheKey)

        // Cache on disk
        if configuration.enableDiskCache {
            saveToDiskCache(optimized, key: cacheKey)
        }

        return optimized
    }

    // MARK: - Image Optimization

    private func optimizeImage(_ image: UIImage) -> UIImage {
        guard image.size.width > configuration.maxImageDimension ||
              image.size.height > configuration.maxImageDimension else {
            return image
        }

        // Calculate new size maintaining aspect ratio
        let scale = min(
            configuration.maxImageDimension / image.size.width,
            configuration.maxImageDimension / image.size.height
        )

        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        // Resize image
        return resizeImage(image, targetSize: newSize)
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    // MARK: - Memory Cache

    private func cacheInMemory(_ image: UIImage, key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // 4 bytes per pixel
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        stats.memoryCacheSize += cost
    }

    // MARK: - Disk Cache

    private func loadFromDiskCache(key: String) -> UIImage? {
        let fileURL = diskCacheURL.appendingPathComponent(key)

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // Check if file is expired
        if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let modificationDate = attributes[.modificationDate] as? Date,
           Date().timeIntervalSince(modificationDate) > configuration.cacheDuration {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }

    private func saveToDiskCache(_ image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: configuration.compressionQuality) else {
            return
        }

        let fileURL = diskCacheURL.appendingPathComponent(key)

        do {
            try data.write(to: fileURL)
            stats.diskCacheSize += data.count
        } catch {
            print("⚠️ Failed to save image to disk cache: \(error)")
        }
    }

    // MARK: - Cache Key Generation

    private func cacheKey(for url: URL) -> String {
        let urlString = url.absoluteString
        let hash = SHA256.hash(data: Data(urlString.utf8))
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Cache Management

    func clearMemoryCache() {
        memoryCache.removeAllObjects()
        stats.memoryCacheSize = 0
        print("🧹 Memory cache cleared")
    }

    func clearDiskCache() {
        guard let contents = try? fileManager.contentsOfDirectory(at: diskCacheURL, includingPropertiesForKeys: nil) else {
            return
        }

        for fileURL in contents {
            try? fileManager.removeItem(at: fileURL)
        }

        stats.diskCacheSize = 0
        print("🧹 Disk cache cleared")
    }

    func clearCache() {
        clearMemoryCache()
        clearDiskCache()
        stats = CacheStatistics()
    }

    // MARK: - Memory Warning

    private func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        print("💾 Memory warning - clearing memory cache")
        clearMemoryCache()
    }

    // MARK: - Cache Cleanup

    private func setupCacheCleanup() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3600_000_000_000) // 1 hour
                await cleanupExpiredCache()
            }
        }
    }

    private func cleanupExpiredCache() async {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: diskCacheURL,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else {
            return
        }

        var removedCount = 0
        var freedSpace = 0

        for fileURL in contents {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modificationDate = attributes[.modificationDate] as? Date,
                  Date().timeIntervalSince(modificationDate) > configuration.cacheDuration else {
                continue
            }

            if let size = attributes[.size] as? Int {
                freedSpace += size
            }

            try? fileManager.removeItem(at: fileURL)
            removedCount += 1
        }

        if removedCount > 0 {
            stats.diskCacheSize -= freedSpace
            print("🧹 Cleaned up \(removedCount) expired images, freed \(freedSpace / 1024 / 1024) MB")
        }
    }

    // MARK: - Statistics

    func getStatistics() -> CacheStatistics {
        return stats
    }

    func resetStatistics() {
        stats = CacheStatistics()
    }
}

// MARK: - Supporting Types

struct CacheStatistics {
    var memoryHits: Int = 0
    var diskHits: Int = 0
    var networkRequests: Int = 0
    var memoryCacheSize: Int = 0
    var diskCacheSize: Int = 0

    var hitRate: Double {
        let totalRequests = memoryHits + diskHits + networkRequests
        guard totalRequests > 0 else { return 0 }
        return Double(memoryHits + diskHits) / Double(totalRequests)
    }
}

enum ImageCacheError: LocalizedError {
    case invalidResponse
    case invalidImageData
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .invalidImageData:
            return "Invalid image data"
        case .downloadFailed:
            return "Download failed"
        }
    }
}

// MARK: - SwiftUI AsyncImage Replacement

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = ImageLoader()

    init(
        url: URL?,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task {
            await loader.load(url: url)
        }
    }
}

@MainActor
private class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func load(url: URL?) async {
        guard let url = url else { return }
        image = try? await ImageCacheOptimizer.shared.loadImage(from: url)
    }
}
