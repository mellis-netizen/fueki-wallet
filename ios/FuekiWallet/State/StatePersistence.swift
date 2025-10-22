//
//  StatePersistence.swift
//  FuekiWallet
//
//  Utilities for state persistence and restoration
//

import Foundation
import Combine

// MARK: - State Persistence Manager
final class StatePersistence {

    // MARK: - Singleton
    static let shared = StatePersistence()

    private let service = StatePersistenceService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupAutomaticPersistence()
    }

    // MARK: - Save State
    func saveState(_ state: AppState) {
        service.save(state)
    }

    // MARK: - Load State
    func loadState() -> AppState? {
        service.load()
    }

    // MARK: - Clear State
    func clearState() {
        service.clear()
    }

    // MARK: - Backup
    func createBackup() -> URL? {
        service.backup()
    }

    func restoreFromBackup(url: URL) -> Bool {
        service.restore(from: url)
    }

    // MARK: - Automatic Persistence
    private func setupAutomaticPersistence() {
        // Observe store changes and persist automatically
        AppStore.shared.observeState()
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] state in
                self?.saveState(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - Migration
    func migrateState(from oldVersion: Int, to newVersion: Int) -> Bool {
        // TODO: Implement state migration logic
        // This would handle schema changes between app versions
        return true
    }
}

// MARK: - State Snapshot
struct StateSnapshot: Codable {
    let state: AppState
    let timestamp: Date
    let appVersion: String
    let schemaVersion: Int

    init(state: AppState, appVersion: String = "1.0.0", schemaVersion: Int = 1) {
        self.state = state
        self.timestamp = Date()
        self.appVersion = appVersion
        self.schemaVersion = schemaVersion
    }
}

// MARK: - Snapshot Manager
final class StateSnapshotManager {
    static let shared = StateSnapshotManager()

    private let fileManager = FileManager.default
    private var snapshotsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let snapshotsDir = appSupport.appendingPathComponent("FuekiWallet/Snapshots", isDirectory: true)
        try? fileManager.createDirectory(at: snapshotsDir, withIntermediateDirectories: true)
        return snapshotsDir
    }

    private init() {}

    // MARK: - Create Snapshot
    func createSnapshot(state: AppState, name: String? = nil) -> URL? {
        let snapshot = StateSnapshot(state: state)
        let fileName = name ?? "snapshot_\(Int(Date().timeIntervalSince1970)).json"
        let snapshotURL = snapshotsDirectory.appendingPathComponent(fileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(snapshot)
            try data.write(to: snapshotURL)

            #if DEBUG
            print("📸 Snapshot created: \(fileName)")
            #endif

            return snapshotURL
        } catch {
            #if DEBUG
            print("❌ Failed to create snapshot: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Load Snapshot
    func loadSnapshot(from url: URL) -> StateSnapshot? {
        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let snapshot = try decoder.decode(StateSnapshot.self, from: data)

            #if DEBUG
            print("📸 Snapshot loaded: \(url.lastPathComponent)")
            #endif

            return snapshot
        } catch {
            #if DEBUG
            print("❌ Failed to load snapshot: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - List Snapshots
    func listSnapshots() -> [URL] {
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: snapshotsDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            return contents
                .filter { $0.pathExtension == "json" }
                .sorted { url1, url2 in
                    guard let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate,
                          let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate else {
                        return false
                    }
                    return date1 > date2
                }
        } catch {
            #if DEBUG
            print("❌ Failed to list snapshots: \(error.localizedDescription)")
            #endif
            return []
        }
    }

    // MARK: - Delete Snapshot
    func deleteSnapshot(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            #if DEBUG
            print("📸 Snapshot deleted: \(url.lastPathComponent)")
            #endif
            return true
        } catch {
            #if DEBUG
            print("❌ Failed to delete snapshot: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Delete All Snapshots
    func deleteAllSnapshots() -> Bool {
        let snapshots = listSnapshots()
        var allDeleted = true

        for snapshot in snapshots {
            if !deleteSnapshot(at: snapshot) {
                allDeleted = false
            }
        }

        return allDeleted
    }
}

// MARK: - State Export/Import
extension StatePersistence {

    // MARK: - Export
    func exportState(state: AppState, to url: URL) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601

            let data = try encoder.encode(state)
            try data.write(to: url)

            #if DEBUG
            print("📤 State exported to: \(url.lastPathComponent)")
            #endif

            return true
        } catch {
            #if DEBUG
            print("❌ Failed to export state: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    // MARK: - Import
    func importState(from url: URL) -> AppState? {
        do {
            let data = try Data(contentsOf: url)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let state = try decoder.decode(AppState.self, from: data)

            #if DEBUG
            print("📥 State imported from: \(url.lastPathComponent)")
            #endif

            return state
        } catch {
            #if DEBUG
            print("❌ Failed to import state: \(error.localizedDescription)")
            #endif
            return nil
        }
    }
}
