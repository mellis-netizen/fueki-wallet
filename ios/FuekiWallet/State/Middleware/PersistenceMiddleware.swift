//
//  PersistenceMiddleware.swift
//  FuekiWallet
//
//  Middleware for state persistence and restoration
//

import Foundation
import Combine

// MARK: - Persistence Middleware
func persistenceMiddleware(state: AppState, action: Action) -> AnyPublisher<Action, Never>? {
    // Persist state changes for specific actions
    if shouldPersist(action) {
        persistState(state)
    }

    return nil
}

// MARK: - Persistence Rules
private func shouldPersist(_ action: Action) -> Bool {
    switch action {

    // Wallet Actions - persist account and balance changes
    case is WalletAction:
        return true

    // Settings Actions - persist all settings
    case is SettingsAction:
        return true

    // Transaction Actions - persist only confirmed/failed
    case let action as TransactionAction:
        switch action {
        case .transactionsFetched, .transactionUpdated, .confirmPendingTransaction:
            return true
        default:
            return false
        }

    // Auth Actions - persist session info
    case let action as AuthAction:
        switch action {
        case .authenticationSucceeded, .sessionStarted, .logout:
            return true
        default:
            return false
        }

    default:
        return false
    }
}

// MARK: - State Persistence
private func persistState(_ state: AppState) {
    StatePersistenceService.shared.save(state)
}

// MARK: - State Persistence Service
final class StatePersistenceService {
    static let shared = StatePersistenceService()

    private let queue = DispatchQueue(label: "io.fueki.wallet.persistence", qos: .utility)
    private let fileManager = FileManager.default

    private var persistenceURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let walletDirectory = appSupport.appendingPathComponent("FuekiWallet", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: walletDirectory, withIntermediateDirectories: true)

        return walletDirectory.appendingPathComponent("app_state.json")
    }

    private init() {}

    // MARK: - Save
    func save(_ state: AppState) {
        queue.async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601

                let data = try encoder.encode(state)
                try data.write(to: self.persistenceURL)

                #if DEBUG
                print("💾 State persisted successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ Failed to persist state: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Load
    func load() -> AppState? {
        queue.sync {
            do {
                guard fileManager.fileExists(atPath: persistenceURL.path) else {
                    #if DEBUG
                    print("ℹ️  No persisted state found")
                    #endif
                    return nil
                }

                let data = try Data(contentsOf: persistenceURL)

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601

                let state = try decoder.decode(AppState.self, from: data)

                #if DEBUG
                print("💾 State loaded successfully")
                #endif

                return state
            } catch {
                #if DEBUG
                print("❌ Failed to load state: \(error.localizedDescription)")
                #endif
                return nil
            }
        }
    }

    // MARK: - Clear
    func clear() {
        queue.async {
            do {
                if self.fileManager.fileExists(atPath: self.persistenceURL.path) {
                    try self.fileManager.removeItem(at: self.persistenceURL)
                    #if DEBUG
                    print("💾 Persisted state cleared")
                    #endif
                }
            } catch {
                #if DEBUG
                print("❌ Failed to clear state: \(error.localizedDescription)")
                #endif
            }
        }
    }

    // MARK: - Backup
    func backup() -> URL? {
        queue.sync {
            do {
                guard fileManager.fileExists(atPath: persistenceURL.path) else {
                    return nil
                }

                let timestamp = Date().timeIntervalSince1970
                let backupURL = persistenceURL.deletingLastPathComponent()
                    .appendingPathComponent("app_state_backup_\(Int(timestamp)).json")

                try fileManager.copyItem(at: persistenceURL, to: backupURL)

                #if DEBUG
                print("💾 State backup created: \(backupURL.lastPathComponent)")
                #endif

                return backupURL
            } catch {
                #if DEBUG
                print("❌ Failed to backup state: \(error.localizedDescription)")
                #endif
                return nil
            }
        }
    }

    // MARK: - Restore from Backup
    func restore(from backupURL: URL) -> Bool {
        queue.sync {
            do {
                guard fileManager.fileExists(atPath: backupURL.path) else {
                    return false
                }

                // Validate backup
                let data = try Data(contentsOf: backupURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                _ = try decoder.decode(AppState.self, from: data)

                // Replace current state
                try fileManager.removeItem(at: persistenceURL)
                try fileManager.copyItem(at: backupURL, to: persistenceURL)

                #if DEBUG
                print("💾 State restored from backup")
                #endif

                return true
            } catch {
                #if DEBUG
                print("❌ Failed to restore state: \(error.localizedDescription)")
                #endif
                return false
            }
        }
    }
}
