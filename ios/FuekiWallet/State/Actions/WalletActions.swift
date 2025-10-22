//
//  WalletActions.swift
//  FuekiWallet
//
//  Actions related to wallet state
//

import Foundation

// MARK: - Wallet Actions
enum WalletAction: Action {

    // Account Management
    case createAccount(name: String)
    case accountCreated(account: WalletAccount)
    case deleteAccount(id: String)
    case accountDeleted(id: String)
    case selectAccount(id: String)
    case updateAccountName(id: String, name: String)

    // Balance
    case fetchBalance
    case balanceFetched(balance: Balance)
    case updateBalance(amount: Decimal, currency: Currency)

    // Sync
    case syncWallet
    case syncStarted
    case syncCompleted(timestamp: Date)
    case syncFailed(error: ErrorState)

    // Loading & Errors
    case setLoading(Bool)
    case setError(ErrorState?)
    case clearError

    // Import/Export
    case importWallet(mnemonic: String)
    case walletImported(account: WalletAccount)
    case exportWallet(id: String)
    case walletExported(mnemonic: String)

    // Backup
    case backupWallet
    case backupCompleted
    case backupFailed(error: ErrorState)

    // Recovery
    case recoverWallet(mnemonic: String)
    case recoveryCompleted(account: WalletAccount)
    case recoveryFailed(error: ErrorState)
}

// MARK: - Account Actions
enum AccountAction: Action {
    case updateLastUsed(id: String, date: Date)
    case updateAddress(id: String, address: String)
    case setActive(id: String)
    case setInactive(id: String)
}

// MARK: - Balance Actions
enum BalanceAction: Action {
    case refresh
    case refreshCompleted(balance: Balance)
    case refreshFailed(error: ErrorState)
    case setCurrency(Currency)
    case updateAmount(Decimal)
}
