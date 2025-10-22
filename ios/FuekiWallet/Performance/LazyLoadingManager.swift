import Foundation
import SwiftUI
import Combine

/// Manages lazy loading strategies for lists, images, and data
@MainActor
final class LazyLoadingManager: ObservableObject {

    // MARK: - Singleton
    static let shared = LazyLoadingManager()

    // MARK: - Configuration
    struct Configuration {
        var preloadThreshold: Int = 5 // Items to preload ahead
        var batchSize: Int = 20 // Items per batch
        var prefetchDistance: Int = 3 // Distance for prefetching
        var cacheTTL: TimeInterval = 3600 // 1 hour cache
        var maxConcurrentLoads: Int = 4
    }

    private(set) var configuration = Configuration()

    // MARK: - Loading State
    @Published private(set) var isLoading = false
    @Published private(set) var loadingProgress: Double = 0

    // MARK: - Cache
    private var dataCache: [String: CachedData] = [:]
    private let cacheLock = NSLock()

    // MARK: - Pagination
    private var paginationStates: [String: PaginationState] = [:]

    // MARK: - Concurrent Loading
    private var loadingSemaphore: DispatchSemaphore
    private var activeLoads: Set<String> = []
    private let loadsLock = NSLock()

    // MARK: - Initialization
    private init() {
        loadingSemaphore = DispatchSemaphore(value: configuration.maxConcurrentLoads)
        setupCacheCleanup()
    }

    // MARK: - Configuration

    func configure(_ config: Configuration) {
        self.configuration = config
        self.loadingSemaphore = DispatchSemaphore(value: config.maxConcurrentLoads)
    }

    // MARK: - Lazy Loading

    /// Load data with lazy loading strategy
    func loadData<T: Codable>(
        key: String,
        page: Int = 0,
        loader: @escaping () async throws -> T
    ) async throws -> T {

        // Check cache first
        if let cached = getCachedData(key: key, page: page) as? T {
            print("📦 Cache hit for \(key) page \(page)")
            return cached
        }

        // Prevent duplicate loads
        guard !isLoadActive(key: "\(key)_\(page)") else {
            print("⏳ Load already in progress for \(key) page \(page)")
            throw LazyLoadingError.loadInProgress
        }

        // Wait for available slot
        loadingSemaphore.wait()
        markLoadActive(key: "\(key)_\(page)")

        defer {
            markLoadInactive(key: "\(key)_\(page)")
            loadingSemaphore.signal()
        }

        do {
            isLoading = true
            let data = try await loader()

            // Cache the result
            cacheData(data, key: key, page: page)

            isLoading = false
            return data

        } catch {
            isLoading = false
            throw error
        }
    }

    /// Load data in batches
    func loadBatched<T: Codable>(
        key: String,
        totalItems: Int,
        loader: @escaping (Int, Int) async throws -> [T]
    ) async throws -> [T] {

        var allItems: [T] = []
        let batchCount = (totalItems + configuration.batchSize - 1) / configuration.batchSize

        for batchIndex in 0..<batchCount {
            let offset = batchIndex * configuration.batchSize
            let limit = min(configuration.batchSize, totalItems - offset)

            loadingProgress = Double(batchIndex) / Double(batchCount)

            let batch = try await loadData(key: "\(key)_batch_\(batchIndex)") {
                try await loader(offset, limit)
            }

            allItems.append(contentsOf: batch)
        }

        loadingProgress = 1.0
        return allItems
    }

    /// Prefetch data for upcoming items
    func prefetch<T: Codable>(
        keys: [String],
        loader: @escaping (String) async throws -> T
    ) async {

        await withTaskGroup(of: Void.self) { group in
            for key in keys.prefix(configuration.prefetchDistance) {
                group.addTask { [weak self] in
                    do {
                        _ = try await self?.loadData(key: key, loader: {
                            try await loader(key)
                        })
                    } catch {
                        print("⚠️ Prefetch failed for \(key): \(error)")
                    }
                }
            }
        }
    }

    /// Cancel prefetch for keys
    func cancelPrefetch(keys: [String]) {
        for key in keys {
            markLoadInactive(key: key)
        }
    }

    // MARK: - Pagination

    /// Initialize pagination state
    func initializePagination(key: String, pageSize: Int = 20) {
        paginationStates[key] = PaginationState(pageSize: pageSize)
    }

    /// Load next page
    func loadNextPage<T: Codable>(
        key: String,
        loader: @escaping (Int) async throws -> [T]
    ) async throws -> [T] {

        guard var state = paginationStates[key] else {
            throw LazyLoadingError.paginationNotInitialized
        }

        guard state.hasMorePages else {
            print("📄 No more pages for \(key)")
            return []
        }

        guard !state.isLoading else {
            print("⏳ Already loading page for \(key)")
            throw LazyLoadingError.loadInProgress
        }

        state.isLoading = true
        paginationStates[key] = state

        do {
            let items = try await loadData(key: key, page: state.currentPage) {
                try await loader(state.currentPage)
            }

            state.currentPage += 1
            state.isLoading = false
            state.hasMorePages = items.count == state.pageSize
            paginationStates[key] = state

            return items

        } catch {
            state.isLoading = false
            paginationStates[key] = state
            throw error
        }
    }

    /// Reset pagination
    func resetPagination(key: String) {
        if let state = paginationStates[key] {
            paginationStates[key] = PaginationState(pageSize: state.pageSize)
        }

        // Clear cached pages
        cacheLock.lock()
        dataCache.keys.filter { $0.hasPrefix(key) }.forEach { dataCache.removeValue(forKey: $0) }
        cacheLock.unlock()
    }

    /// Check if should load more
    func shouldLoadMore(currentIndex: Int, totalItems: Int) -> Bool {
        return currentIndex >= totalItems - configuration.preloadThreshold
    }

    // MARK: - Cache Management

    private func getCachedData<T: Codable>(key: String, page: Int) -> T? {
        let cacheKey = "\(key)_\(page)"

        cacheLock.lock()
        defer { cacheLock.unlock() }

        guard let cached = dataCache[cacheKey],
              !cached.isExpired else {
            return nil
        }

        return cached.data as? T
    }

    private func cacheData<T: Codable>(_ data: T, key: String, page: Int) {
        let cacheKey = "\(key)_\(page)"

        cacheLock.lock()
        dataCache[cacheKey] = CachedData(
            data: data,
            timestamp: Date(),
            ttl: configuration.cacheTTL
        )
        cacheLock.unlock()
    }

    func clearCache(key: String? = nil) {
        cacheLock.lock()
        if let key = key {
            dataCache.keys.filter { $0.hasPrefix(key) }.forEach { dataCache.removeValue(forKey: $0) }
        } else {
            dataCache.removeAll()
        }
        cacheLock.unlock()

        print("🧹 Cache cleared" + (key != nil ? " for \(key!)" : ""))
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
        let expiredKeys = dataCache.filter { $0.value.isExpired }.map { $0.key }
        expiredKeys.forEach { dataCache.removeValue(forKey: $0) }
        cacheLock.unlock()

        if !expiredKeys.isEmpty {
            print("🧹 Cleaned up \(expiredKeys.count) expired cache entries")
        }
    }

    // MARK: - Load Tracking

    private func isLoadActive(key: String) -> Bool {
        loadsLock.lock()
        defer { loadsLock.unlock() }
        return activeLoads.contains(key)
    }

    private func markLoadActive(key: String) {
        loadsLock.lock()
        activeLoads.insert(key)
        loadsLock.unlock()
    }

    private func markLoadInactive(key: String) {
        loadsLock.lock()
        activeLoads.remove(key)
        loadsLock.unlock()
    }

    // MARK: - Memory Pressure

    func handleMemoryPressure() {
        print("💾 Handling memory pressure - clearing cache")
        clearCache()
    }
}

// MARK: - Supporting Types

private struct CachedData {
    let data: Any
    let timestamp: Date
    let ttl: TimeInterval

    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > ttl
    }
}

private struct PaginationState {
    var currentPage: Int = 0
    var pageSize: Int
    var hasMorePages: Bool = true
    var isLoading: Bool = false
}

enum LazyLoadingError: LocalizedError {
    case loadInProgress
    case paginationNotInitialized
    case cacheExpired

    var errorDescription: String? {
        switch self {
        case .loadInProgress:
            return "Load already in progress"
        case .paginationNotInitialized:
            return "Pagination not initialized"
        case .cacheExpired:
            return "Cache expired"
        }
    }
}

// MARK: - SwiftUI Helper Views

/// Lazy loading list view
struct LazyLoadingList<Item: Identifiable & Codable, Content: View>: View {
    let items: [Item]
    let loadMore: () async -> Void
    let content: (Item) -> Content

    @StateObject private var manager = LazyLoadingManager.shared

    var body: some View {
        List {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .onAppear {
                        if manager.shouldLoadMore(currentIndex: index, totalItems: items.count) {
                            Task {
                                await loadMore()
                            }
                        }
                    }
            }

            if manager.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
        }
    }
}
