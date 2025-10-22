//
//  UndoRedoManager.swift
//  Fueki Wallet
//
//  Undo/Redo system for state management
//

import Foundation
import Combine

@MainActor
class UndoRedoManager: ObservableObject {
    // MARK: - Singleton
    static let shared = UndoRedoManager()

    // MARK: - Published Properties
    @Published var canUndo = false
    @Published var canRedo = false

    // MARK: - Properties
    private var undoStack: [StateOperation] = []
    private var redoStack: [StateOperation] = []
    private let maxStackSize = 50

    // Operations that support undo
    private var undoableOperations: Set<String> = [
        "send_transaction",
        "update_wallet_name",
        "remove_asset",
        "update_settings"
    ]

    // MARK: - Initialization
    private init() {}

    // MARK: - Operation Recording

    func recordOperation(_ operation: StateOperation) {
        guard isUndoable(operation) else { return }

        undoStack.append(operation)
        redoStack.removeAll() // Clear redo stack on new operation

        // Maintain max stack size
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }

        updateCanUndoRedo()
    }

    func undo() async throws -> StateOperation? {
        guard let operation = undoStack.popLast() else {
            return nil
        }

        // Execute undo
        try await executeUndo(operation)

        // Move to redo stack
        redoStack.append(operation)

        updateCanUndoRedo()

        return operation
    }

    func redo() async throws -> StateOperation? {
        guard let operation = redoStack.popLast() else {
            return nil
        }

        // Execute redo
        try await executeRedo(operation)

        // Move back to undo stack
        undoStack.append(operation)

        updateCanUndoRedo()

        return operation
    }

    // MARK: - State Management

    func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateCanUndoRedo()
    }

    func getUndoHistory() -> [StateOperation] {
        return undoStack
    }

    func getRedoHistory() -> [StateOperation] {
        return redoStack
    }

    // MARK: - Private Methods

    private func isUndoable(_ operation: StateOperation) -> Bool {
        return undoableOperations.contains(operation.type)
    }

    private func executeUndo(_ operation: StateOperation) async throws {
        switch operation.type {
        case "send_transaction":
            try await undoTransaction(operation)

        case "update_wallet_name":
            try await undoWalletNameUpdate(operation)

        case "remove_asset":
            try await undoAssetRemoval(operation)

        case "update_settings":
            try await undoSettingsUpdate(operation)

        default:
            break
        }
    }

    private func executeRedo(_ operation: StateOperation) async throws {
        switch operation.type {
        case "send_transaction":
            try await redoTransaction(operation)

        case "update_wallet_name":
            try await redoWalletNameUpdate(operation)

        case "remove_asset":
            try await redoAssetRemoval(operation)

        case "update_settings":
            try await redoSettingsUpdate(operation)

        default:
            break
        }
    }

    // MARK: - Specific Undo/Redo Operations

    private func undoTransaction(_ operation: StateOperation) async throws {
        // Mark transaction as cancelled
        if let transactionId = operation.data["transaction_id"] {
            let transactionState = AppState.shared.transactionState

            if let transaction = transactionState.transactions.first(where: { $0.id == transactionId }) {
                var updated = transaction
                updated.status = .cancelled
                transactionState.updateTransaction(updated)
            }
        }
    }

    private func redoTransaction(_ operation: StateOperation) async throws {
        // Re-submit transaction
        if let transactionId = operation.data["transaction_id"] {
            let transactionState = AppState.shared.transactionState

            if let transaction = transactionState.transactions.first(where: { $0.id == transactionId }) {
                var updated = transaction
                updated.status = .pending
                transactionState.updateTransaction(updated)
            }
        }
    }

    private func undoWalletNameUpdate(_ operation: StateOperation) async throws {
        guard let walletId = operation.data["wallet_id"],
              let oldName = operation.previousState["name"] else {
            return
        }

        let walletState = AppState.shared.walletState
        walletState.updateWalletName(walletId, name: oldName)
    }

    private func redoWalletNameUpdate(_ operation: StateOperation) async throws {
        guard let walletId = operation.data["wallet_id"],
              let newName = operation.newState["name"] else {
            return
        }

        let walletState = AppState.shared.walletState
        walletState.updateWalletName(walletId, name: newName)
    }

    private func undoAssetRemoval(_ operation: StateOperation) async throws {
        guard let walletId = operation.data["wallet_id"],
              let assetData = operation.previousState["asset"],
              let assetJson = assetData.data(using: .utf8),
              let asset = try? JSONDecoder().decode(CryptoAsset.self, from: assetJson) else {
            return
        }

        let walletState = AppState.shared.walletState
        walletState.addAsset(to: walletId, asset: asset)
    }

    private func redoAssetRemoval(_ operation: StateOperation) async throws {
        guard let walletId = operation.data["wallet_id"],
              let assetId = operation.data["asset_id"] else {
            return
        }

        let walletState = AppState.shared.walletState
        walletState.removeAsset(from: walletId, assetId: assetId)
    }

    private func undoSettingsUpdate(_ operation: StateOperation) async throws {
        // Restore previous settings from snapshot
        if let snapshotData = operation.previousState["snapshot"],
           let snapshotJson = snapshotData.data(using: .utf8),
           let snapshot = try? JSONDecoder().decode(SettingsStateSnapshot.self, from: snapshotJson) {
            await AppState.shared.settingsState.restore(from: snapshot)
        }
    }

    private func redoSettingsUpdate(_ operation: StateOperation) async throws {
        // Apply new settings from snapshot
        if let snapshotData = operation.newState["snapshot"],
           let snapshotJson = snapshotData.data(using: .utf8),
           let snapshot = try? JSONDecoder().decode(SettingsStateSnapshot.self, from: snapshotJson) {
            await AppState.shared.settingsState.restore(from: snapshot)
        }
    }

    private func updateCanUndoRedo() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

// MARK: - State Operation

struct StateOperation: Codable, Identifiable {
    let id: String
    let type: String
    let timestamp: Date
    let data: [String: String]
    let previousState: [String: String]
    let newState: [String: String]

    init(
        type: String,
        data: [String: String] = [:],
        previousState: [String: String] = [:],
        newState: [String: String] = [:]
    ) {
        self.id = UUID().uuidString
        self.type = type
        self.timestamp = Date()
        self.data = data
        self.previousState = previousState
        self.newState = newState
    }
}
