//
//  WalletSelectors.swift
//  FuekiWallet
//
//  Selectors for deriving wallet state
//

import Foundation

// MARK: - Wallet Selectors
struct WalletSelectors {

    // MARK: - Account Selectors
    static func selectedAccount(from state: AppState) -> WalletAccount? {
        state.wallet.selectedAccount
    }

    static func accountById(_ id: String) -> (AppState) -> WalletAccount? {
        return { state in
            state.wallet.accounts.first { $0.id == id }
        }
    }

    static func accounts(from state: AppState) -> [WalletAccount] {
        state.wallet.accounts
    }

    static func accountCount(from state: AppState) -> Int {
        state.wallet.accounts.count
    }

    static func accountsSortedByName(from state: AppState) -> [WalletAccount] {
        state.wallet.accounts.sorted { $0.name < $1.name }
    }

    static func accountsSortedByBalance(from state: AppState) -> [WalletAccount] {
        state.wallet.accounts.sorted { $0.balance.amount > $1.balance.amount }
    }

    static func accountsSortedByLastUsed(from state: AppState) -> [WalletAccount] {
        state.wallet.accounts.sorted { $0.lastUsed > $1.lastUsed }
    }

    static func recentlyUsedAccounts(limit: Int = 5) -> (AppState) -> [WalletAccount] {
        return { state in
            Array(accountsSortedByLastUsed(from: state).prefix(limit))
        }
    }

    // MARK: - Balance Selectors
    static func currentBalance(from state: AppState) -> Balance {
        state.wallet.balance
    }

    static func formattedBalance(from state: AppState) -> String {
        state.wallet.balance.formattedAmount
    }

    static func balanceWithCurrency(from state: AppState) -> String {
        let balance = state.wallet.balance
        return "\(balance.formattedAmount) \(balance.currency.rawValue)"
    }

    static func totalBalance(from state: AppState) -> Decimal {
        state.wallet.accounts.reduce(0) { $0 + $1.balance.amount }
    }

    static func formattedTotalBalance(from state: AppState) -> String {
        let total = totalBalance(from: state)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter.string(from: total as NSDecimalNumber) ?? "0.00"
    }

    // MARK: - Status Selectors
    static func isLoading(from state: AppState) -> Bool {
        state.wallet.isLoading
    }

    static func hasError(from state: AppState) -> Bool {
        state.wallet.error != nil
    }

    static func error(from state: AppState) -> ErrorState? {
        state.wallet.error
    }

    static func lastSyncTime(from state: AppState) -> Date? {
        state.wallet.lastSyncTimestamp
    }

    static func syncStatus(from state: AppState) -> SyncStatus {
        guard let lastSync = state.wallet.lastSyncTimestamp else {
            return .never
        }

        let timeSinceSync = Date().timeIntervalSince(lastSync)

        if timeSinceSync < 60 {
            return .recent
        } else if timeSinceSync < 300 {
            return .normal
        } else {
            return .stale
        }
    }

    // MARK: - Computed Properties
    static func hasAccounts(from state: AppState) -> Bool {
        !state.wallet.accounts.isEmpty
    }

    static func hasSelectedAccount(from state: AppState) -> Bool {
        selectedAccount(from: state) != nil
    }

    static func isWalletEmpty(from state: AppState) -> Bool {
        state.wallet.accounts.isEmpty && state.wallet.balance.amount == 0
    }

    static func needsSync(from state: AppState) -> Bool {
        guard let lastSync = state.wallet.lastSyncTimestamp else {
            return true
        }
        return Date().timeIntervalSince(lastSync) > 300 // 5 minutes
    }

    // MARK: - Search & Filter
    static func accountsMatching(query: String) -> (AppState) -> [WalletAccount] {
        return { state in
            guard !query.isEmpty else { return state.wallet.accounts }

            let lowercasedQuery = query.lowercased()
            return state.wallet.accounts.filter {
                $0.name.lowercased().contains(lowercasedQuery) ||
                $0.address.lowercased().contains(lowercasedQuery)
            }
        }
    }

    static func accountsWithMinimumBalance(_ minimum: Decimal) -> (AppState) -> [WalletAccount] {
        return { state in
            state.wallet.accounts.filter { $0.balance.amount >= minimum }
        }
    }

    // MARK: - Statistics
    static func walletStatistics(from state: AppState) -> WalletStatistics {
        WalletStatistics(
            totalAccounts: state.wallet.accounts.count,
            totalBalance: totalBalance(from: state),
            averageBalance: averageBalance(from: state),
            largestBalance: largestBalance(from: state),
            smallestBalance: smallestBalance(from: state),
            lastSync: state.wallet.lastSyncTimestamp
        )
    }

    private static func averageBalance(from state: AppState) -> Decimal {
        guard !state.wallet.accounts.isEmpty else { return 0 }
        return totalBalance(from: state) / Decimal(state.wallet.accounts.count)
    }

    private static func largestBalance(from state: AppState) -> Decimal {
        state.wallet.accounts.map { $0.balance.amount }.max() ?? 0
    }

    private static func smallestBalance(from state: AppState) -> Decimal {
        state.wallet.accounts.map { $0.balance.amount }.min() ?? 0
    }
}

// MARK: - Supporting Types
enum SyncStatus {
    case never
    case recent
    case normal
    case stale
}

struct WalletStatistics {
    let totalAccounts: Int
    let totalBalance: Decimal
    let averageBalance: Decimal
    let largestBalance: Decimal
    let smallestBalance: Decimal
    let lastSync: Date?
}
