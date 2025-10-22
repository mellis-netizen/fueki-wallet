//
//  StateSync.swift
//  Fueki Wallet
//
//  State synchronization for online/offline support
//

import Foundation
import Combine
import Network

@MainActor
class StateSync {
    // MARK: - Singleton
    static let shared = StateSync()

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.fueki.network.monitor")

    private(set) var isOnline = false
    private(set) var isSyncing = false

    // Sync queue for offline actions
    private var syncQueue: [SyncOperation] = []
    private let maxQueueSize = 100

    // Sync strategy
    private var syncStrategy: SyncStrategy = .adaptive

    // MARK: - Initialization
    private init() {
        setupNetworkMonitoring()
        loadSyncQueue()
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOnline = self?.isOnline ?? false
                self?.isOnline = path.status == .satisfied

                if !wasOnline && (self?.isOnline ?? false) {
                    // Came online, start sync
                    await self?.processSyncQueue()
                }

                // Notify connection state change
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: path.status == .satisfied ? ConnectionState.online : ConnectionState.offline
                )
            }
        }

        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Sync Management

    func syncAllStates() async throws {
        guard isOnline else {
            throw SyncError.offline
        }

        guard !isSyncing else {
            throw SyncError.alreadySyncing
        }

        isSyncing = true

        do {
            // Process queued operations
            try await processSyncQueue()

            // Sync current state
            try await syncCurrentState()

            isSyncing = false

            NotificationCenter.default.post(
                name: .syncDidComplete,
                object: Date()
            )
        } catch {
            isSyncing = false
            throw error
        }
    }

    func queueOperation(_ operation: SyncOperation) {
        syncQueue.append(operation)

        // Trim queue if needed
        if syncQueue.count > maxQueueSize {
            syncQueue.removeFirst(syncQueue.count - maxQueueSize)
        }

        // Save queue
        saveSyncQueue()

        // Try to process immediately if online
        if isOnline {
            Task {
                await processSyncQueue()
            }
        }
    }

    func cancelSync() {
        isSyncing = false
    }

    func setSyncStrategy(_ strategy: SyncStrategy) {
        syncStrategy = strategy
    }

    // MARK: - Private Methods

    private func processSyncQueue() async {
        guard isOnline, !syncQueue.isEmpty else { return }

        isSyncing = true

        var processedOperations: [SyncOperation] = []
        var failedOperations: [SyncOperation] = []

        for operation in syncQueue {
            do {
                try await processOperation(operation)
                processedOperations.append(operation)
            } catch {
                print("Failed to sync operation: \(error)")
                failedOperations.append(operation)

                // Stop on critical errors
                if case SyncError.criticalError = error {
                    break
                }
            }
        }

        // Remove processed operations
        syncQueue.removeAll { operation in
            processedOperations.contains { $0.id == operation.id }
        }

        // Save updated queue
        saveSyncQueue()

        isSyncing = false
    }

    private func processOperation(_ operation: SyncOperation) async throws {
        switch operation.type {
        case .createTransaction:
            try await syncTransaction(operation)

        case .updateWallet:
            try await syncWallet(operation)

        case .updateSettings:
            try await syncSettings(operation)

        case .authentication:
            try await syncAuthentication(operation)
        }
    }

    private func syncCurrentState() async throws {
        // Sync wallet balances
        try await syncWalletBalances()

        // Sync transaction history
        try await syncTransactionHistory()

        // Sync user preferences
        try await syncUserPreferences()
    }

    private func syncTransaction(_ operation: SyncOperation) async throws {
        // Sync transaction with backend/blockchain
        guard let transactionId = operation.data["transaction_id"] else {
            throw SyncError.operationFailed("Missing transaction ID")
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)

        logger.log("Synced transaction: \(transactionId)", level: .info)
    }

    private func syncWallet(_ operation: SyncOperation) async throws {
        // Sync wallet data with backend
        guard let walletId = operation.data["wallet_id"] else {
            throw SyncError.operationFailed("Missing wallet ID")
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 500_000_000)

        logger.log("Synced wallet: \(walletId)", level: .info)
    }

    private func syncSettings(_ operation: SyncOperation) async throws {
        // Sync settings with backend
        let settingsState = AppState.shared.settingsState
        let snapshot = settingsState.createSnapshot()

        // Simulate API call
        try await Task.sleep(nanoseconds: 300_000_000)

        logger.log("Synced settings", level: .info)
    }

    private func syncAuthentication(_ operation: SyncOperation) async throws {
        // Sync authentication state with backend
        let authState = AppState.shared.authState

        // Refresh session token if needed
        if let expiry = authState.sessionExpiry, expiry < Date().addingTimeInterval(300) {
            // Token expires in less than 5 minutes, refresh it
            let newToken = UUID().uuidString // Simulate new token
            authState.refreshSession(token: newToken)
        }

        try await Task.sleep(nanoseconds: 300_000_000)

        logger.log("Synced authentication", level: .info)
    }

    private func syncWalletBalances() async throws {
        // Fetch latest balances from blockchain
        let walletState = AppState.shared.walletState

        guard let activeWallet = walletState.activeWallet else {
            return
        }

        // Refresh balances
        await walletState.refreshBalances()

        logger.log("Synced wallet balances", level: .info)
    }

    private func syncTransactionHistory() async throws {
        // Fetch latest transactions from blockchain
        let transactionState = AppState.shared.transactionState
        let walletState = AppState.shared.walletState

        guard let activeWallet = walletState.activeWallet else {
            return
        }

        // Refresh transaction history
        await transactionState.refreshTransactionHistory(walletAddress: activeWallet.id)

        logger.log("Synced transaction history", level: .info)
    }

    private func syncUserPreferences() async throws {
        // Sync user preferences with backend
        let settingsState = AppState.shared.settingsState
        let snapshot = settingsState.createSnapshot()

        // Simulate API call to save preferences
        try await Task.sleep(nanoseconds: 500_000_000)

        logger.log("Synced user preferences", level: .info)
    }

    private let logger = StateLogger.shared

    // MARK: - Queue Persistence

    private func saveSyncQueue() {
        Task {
            do {
                try await StatePersistence.shared.saveState(syncQueue, key: "sync_queue")
            } catch {
                print("Failed to save sync queue: \(error)")
            }
        }
    }

    private func loadSyncQueue() {
        Task {
            do {
                if let queue = try await StatePersistence.shared.restoreState(
                    key: "sync_queue",
                    type: [SyncOperation].self
                ) {
                    await MainActor.run {
                        self.syncQueue = queue
                    }
                }
            } catch {
                print("Failed to load sync queue: \(error)")
            }
        }
    }
}

// MARK: - Supporting Types

struct SyncOperation: Codable, Identifiable {
    let id: String
    let type: OperationType
    let data: [String: String]
    let timestamp: Date
    let retryCount: Int

    enum OperationType: String, Codable {
        case createTransaction
        case updateWallet
        case updateSettings
        case authentication
    }

    init(type: OperationType, data: [String: String] = [:]) {
        self.id = UUID().uuidString
        self.type = type
        self.data = data
        self.timestamp = Date()
        self.retryCount = 0
    }
}

enum SyncStrategy {
    case immediate      // Sync immediately when online
    case scheduled      // Sync on schedule
    case adaptive       // Adapt based on network conditions
    case manual         // Only sync when requested
}

enum SyncError: Error, LocalizedError {
    case offline
    case alreadySyncing
    case queueFull
    case operationFailed(String)
    case criticalError(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return "Device is offline"
        case .alreadySyncing:
            return "Sync already in progress"
        case .queueFull:
            return "Sync queue is full"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .criticalError(let message):
            return "Critical error: \(message)"
        }
    }
}
