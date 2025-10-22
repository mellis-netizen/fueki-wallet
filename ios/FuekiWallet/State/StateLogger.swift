//
//  StateLogger.swift
//  FuekiWallet
//
//  Advanced logging and debugging for state changes
//

import Foundation
import Combine

// MARK: - State Logger
final class StateLogger {
    static let shared = StateLogger()

    private var cancellables = Set<AnyCancellable>()
    private var logs: [StateLogEntry] = []
    private let maxLogs = 1000
    private let queue = DispatchQueue(label: "io.fueki.wallet.state-logger", qos: .utility)

    private init() {
        setupLogging()
    }

    // MARK: - Setup
    private func setupLogging() {
        #if DEBUG
        // Observe state changes
        AppStore.shared.observeState()
            .sink { [weak self] state in
                self?.logStateChange(state)
            }
            .store(in: &cancellables)

        // Observe actions
        AppStore.shared.observeActions()
            .sink { [weak self] action in
                self?.logAction(action)
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - Log State Change
    private func logStateChange(_ state: AppState) {
        queue.async {
            let entry = StateLogEntry(
                type: .stateChange,
                timestamp: Date(),
                data: self.serializeState(state)
            )

            self.addLog(entry)
        }
    }

    // MARK: - Log Action
    private func logAction(_ action: Action) {
        queue.async {
            let entry = StateLogEntry(
                type: .action,
                timestamp: Date(),
                data: ["action": String(describing: type(of: action))]
            )

            self.addLog(entry)
        }
    }

    // MARK: - Add Log
    private func addLog(_ entry: StateLogEntry) {
        logs.append(entry)

        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }

    // MARK: - Get Logs
    func getLogs(type: LogType? = nil, limit: Int? = nil) -> [StateLogEntry] {
        queue.sync {
            var filtered = type != nil ? logs.filter { $0.type == type } : logs

            if let limit = limit {
                filtered = Array(filtered.suffix(limit))
            }

            return filtered
        }
    }

    // MARK: - Clear Logs
    func clearLogs() {
        queue.async {
            self.logs.removeAll()
        }
    }

    // MARK: - Export Logs
    func exportLogs() -> URL? {
        queue.sync {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                encoder.dateEncodingStrategy = .iso8601

                let data = try encoder.encode(logs)

                let tempDir = FileManager.default.temporaryDirectory
                let timestamp = Int(Date().timeIntervalSince1970)
                let logURL = tempDir.appendingPathComponent("state_logs_\(timestamp).json")

                try data.write(to: logURL)

                #if DEBUG
                print("📋 Logs exported to: \(logURL.lastPathComponent)")
                #endif

                return logURL
            } catch {
                #if DEBUG
                print("❌ Failed to export logs: \(error.localizedDescription)")
                #endif
                return nil
            }
        }
    }

    // MARK: - Print Summary
    func printSummary() {
        queue.async {
            print("\n📊 State Logger Summary")
            print("   Total Logs: \(self.logs.count)")

            let stateChanges = self.logs.filter { $0.type == .stateChange }.count
            let actions = self.logs.filter { $0.type == .action }.count
            let errors = self.logs.filter { $0.type == .error }.count

            print("   State Changes: \(stateChanges)")
            print("   Actions: \(actions)")
            print("   Errors: \(errors)")

            if let first = self.logs.first, let last = self.logs.last {
                print("   Time Range: \(first.timestamp.formatted()) - \(last.timestamp.formatted())")
            }
            print("")
        }
    }

    // MARK: - State Serialization
    private func serializeState(_ state: AppState) -> [String: Any] {
        [
            "wallet": [
                "accounts_count": state.wallet.accounts.count,
                "balance": state.wallet.balance.formattedAmount,
                "is_loading": state.wallet.isLoading,
                "has_error": state.wallet.error != nil
            ],
            "transactions": [
                "pending": state.transactions.pending.count,
                "confirmed": state.transactions.confirmed.count,
                "failed": state.transactions.failed.count,
                "filter": state.transactions.filter.rawValue
            ],
            "settings": [
                "currency": state.settings.currency.rawValue,
                "language": state.settings.language.rawValue,
                "theme": state.settings.theme.rawValue,
                "network": state.settings.network.rawValue
            ],
            "auth": [
                "is_authenticated": state.auth.isAuthenticated,
                "is_locked": state.auth.isLocked,
                "failed_attempts": state.auth.failedAttempts
            ]
        ]
    }
}

// MARK: - Log Entry
struct StateLogEntry: Codable {
    let type: LogType
    let timestamp: Date
    let data: [String: Any]

    enum CodingKeys: String, CodingKey {
        case type, timestamp, data
    }

    init(type: LogType, timestamp: Date, data: [String: Any]) {
        self.type = type
        self.timestamp = timestamp
        self.data = data
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)

        // Convert data to JSON-compatible format
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
        try container.encode(jsonString, forKey: .data)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(LogType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        let jsonString = try container.decode(String.self, forKey: .data)
        let jsonData = jsonString.data(using: .utf8) ?? Data()
        data = (try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]) ?? [:]
    }
}

// MARK: - Log Type
enum LogType: String, Codable {
    case stateChange = "state_change"
    case action = "action"
    case error = "error"
    case performance = "performance"
}

// MARK: - State Diff
struct StateDiff {
    let before: AppState
    let after: AppState
    let changes: [String]

    func printDiff() {
        print("\n🔍 State Diff")
        for change in changes {
            print("   • \(change)")
        }
        print("")
    }

    static func compute(before: AppState, after: AppState) -> StateDiff {
        var changes: [String] = []

        // Wallet changes
        if before.wallet.accounts.count != after.wallet.accounts.count {
            changes.append("Accounts count: \(before.wallet.accounts.count) → \(after.wallet.accounts.count)")
        }

        if before.wallet.balance.amount != after.wallet.balance.amount {
            changes.append("Balance: \(before.wallet.balance.formattedAmount) → \(after.wallet.balance.formattedAmount)")
        }

        // Transaction changes
        if before.transactions.pending.count != after.transactions.pending.count {
            changes.append("Pending transactions: \(before.transactions.pending.count) → \(after.transactions.pending.count)")
        }

        // Auth changes
        if before.auth.isAuthenticated != after.auth.isAuthenticated {
            changes.append("Authenticated: \(before.auth.isAuthenticated) → \(after.auth.isAuthenticated)")
        }

        if before.auth.isLocked != after.auth.isLocked {
            changes.append("Locked: \(before.auth.isLocked) → \(after.auth.isLocked)")
        }

        return StateDiff(before: before, after: after, changes: changes)
    }
}
