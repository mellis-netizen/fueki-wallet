//
//  AppState.swift
//  Fueki Wallet
//
//  Core application state management with Combine
//

import Foundation
import Combine
import SwiftUI

/// Global application state
@MainActor
class AppState: ObservableObject {
    // MARK: - Singleton
    static let shared = AppState()

    // MARK: - Published State
    @Published var connectionState: ConnectionState = .unknown
    @Published var syncState: SyncState = .idle
    @Published var errorState: ErrorState?
    @Published var loadingState: LoadingState = .idle

    // MARK: - Sub-States
    @Published var authState: AuthState
    @Published var walletState: WalletState
    @Published var transactionState: TransactionState
    @Published var settingsState: SettingsState

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let stateManager: StateManager
    private let persistence: StatePersistence
    private let sync: StateSync

    // MARK: - Initialization
    private init(
        stateManager: StateManager = .shared,
        persistence: StatePersistence = .shared,
        sync: StateSync = .shared
    ) {
        self.stateManager = stateManager
        self.persistence = persistence
        self.sync = sync

        // Initialize sub-states
        self.authState = AuthState()
        self.walletState = WalletState()
        self.transactionState = TransactionState()
        self.settingsState = SettingsState()

        setupStateObservers()
        Task {
            await restoreState()
        }
    }

    // MARK: - State Management

    /// Restore persisted state
    func restoreState() async {
        loadingState = .loading(operation: "Restoring state")

        do {
            if let restoredState = try await persistence.restoreAppState() {
                await applyRestoredState(restoredState)
            }
            loadingState = .idle
        } catch {
            handleError(.persistenceError(error))
            loadingState = .idle
        }
    }

    /// Persist current state
    func persistState() async throws {
        let snapshot = createStateSnapshot()
        try await persistence.saveAppState(snapshot)
    }

    /// Reset all state to defaults
    func resetState() async {
        authState.reset()
        walletState.reset()
        transactionState.reset()
        settingsState.reset()

        errorState = nil
        loadingState = .idle
        syncState = .idle

        try? await persistence.clearAllState()
    }

    // MARK: - Connection Management

    func updateConnectionState(_ state: ConnectionState) {
        connectionState = state

        if case .online = state {
            Task {
                await startSync()
            }
        } else if case .offline = state {
            stopSync()
        }
    }

    // MARK: - Sync Management

    private func startSync() async {
        guard case .online = connectionState else { return }

        syncState = .syncing

        do {
            try await sync.syncAllStates()
            syncState = .synced(lastSync: Date())
        } catch {
            syncState = .failed(error: error)
            handleError(.syncError(error))
        }
    }

    private func stopSync() {
        sync.cancelSync()
        syncState = .idle
    }

    // MARK: - Error Handling

    func handleError(_ error: StateError) {
        errorState = ErrorState(
            error: error,
            timestamp: Date(),
            context: createErrorContext()
        )

        // Log error
        stateManager.logError(error)

        // Attempt recovery
        Task {
            await attemptErrorRecovery(error)
        }
    }

    func clearError() {
        errorState = nil
    }

    // MARK: - Private Methods

    private func setupStateObservers() {
        // Observe connection changes
        NotificationCenter.default.publisher(for: .networkStatusChanged)
            .compactMap { $0.object as? ConnectionState }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateConnectionState(state)
            }
            .store(in: &cancellables)

        // Auto-persist on state changes
        Publishers.CombineLatest4(
            authState.objectWillChange,
            walletState.objectWillChange,
            transactionState.objectWillChange,
            settingsState.objectWillChange
        )
        .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
        .sink { [weak self] _ in
            Task {
                try? await self?.persistState()
            }
        }
        .store(in: &cancellables)
    }

    private func createStateSnapshot() -> AppStateSnapshot {
        AppStateSnapshot(
            auth: authState.createSnapshot(),
            wallet: walletState.createSnapshot(),
            transactions: transactionState.createSnapshot(),
            settings: settingsState.createSnapshot(),
            timestamp: Date()
        )
    }

    func applyRestoredState(_ snapshot: AppStateSnapshot) async {
        await authState.restore(from: snapshot.auth)
        await walletState.restore(from: snapshot.wallet)
        await transactionState.restore(from: snapshot.transactions)
        await settingsState.restore(from: snapshot.settings)
    }

    private func createErrorContext() -> [String: Any] {
        [
            "connectionState": String(describing: connectionState),
            "syncState": String(describing: syncState),
            "timestamp": Date().ISO8601Format()
        ]
    }

    private func attemptErrorRecovery(_ error: StateError) async {
        switch error {
        case .syncError:
            // Retry sync after delay
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await startSync()

        case .persistenceError:
            // Attempt to restore from backup
            try? await persistence.restoreFromBackup()

        case .networkError:
            // Wait for connection to restore
            break

        case .validationError:
            // Clear invalid state
            break
        }
    }
}

// MARK: - State Enums

enum ConnectionState: Equatable {
    case unknown
    case online
    case offline
    case limited
}

enum SyncState: Equatable {
    case idle
    case syncing
    case synced(lastSync: Date)
    case failed(error: Error)

    static func == (lhs: SyncState, rhs: SyncState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing):
            return true
        case (.synced(let date1), .synced(let date2)):
            return date1 == date2
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

enum LoadingState: Equatable {
    case idle
    case loading(operation: String)
    case success
    case failed(error: String)
}

struct ErrorState: Identifiable {
    let id = UUID()
    let error: StateError
    let timestamp: Date
    let context: [String: Any]

    var message: String {
        error.localizedDescription
    }
}

// MARK: - State Errors

enum StateError: Error, LocalizedError {
    case syncError(Error)
    case persistenceError(Error)
    case networkError(String)
    case validationError(String)

    var errorDescription: String? {
        switch self {
        case .syncError(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .persistenceError(let error):
            return "Storage error: \(error.localizedDescription)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        }
    }
}

// MARK: - State Snapshot

struct AppStateSnapshot: Codable {
    let auth: AuthStateSnapshot
    let wallet: WalletStateSnapshot
    let transactions: TransactionStateSnapshot
    let settings: SettingsStateSnapshot
    let timestamp: Date
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let stateDidChange = Notification.Name("stateDidChange")
    static let syncDidComplete = Notification.Name("syncDidComplete")
}
