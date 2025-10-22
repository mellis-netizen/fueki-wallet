//
//  WalletReducer.swift
//  FuekiWallet
//
//  Pure reducer for wallet state transformations
//

import Foundation

// MARK: - Wallet Reducer
func walletReducer(state: inout WalletState, action: Action) {
    guard let action = action as? WalletAction else { return }

    switch action {

    // Account Management
    case .createAccount:
        state.isLoading = true
        state.error = nil

    case .accountCreated(let account):
        state.accounts.append(account)
        state.selectedAccountId = account.id
        state.isLoading = false
        state.error = nil

    case .deleteAccount(let id):
        state.accounts.removeAll { $0.id == id }
        if state.selectedAccountId == id {
            state.selectedAccountId = state.accounts.first?.id
        }

    case .accountDeleted(let id):
        state.accounts.removeAll { $0.id == id }
        if state.selectedAccountId == id {
            state.selectedAccountId = state.accounts.first?.id
        }

    case .selectAccount(let id):
        if state.accounts.contains(where: { $0.id == id }) {
            state.selectedAccountId = id
        }

    case .updateAccountName(let id, let name):
        if let index = state.accounts.firstIndex(where: { $0.id == id }) {
            state.accounts[index].name = name
        }

    // Balance
    case .fetchBalance:
        state.isLoading = true
        state.error = nil

    case .balanceFetched(let balance):
        state.balance = balance
        state.isLoading = false
        state.error = nil

    case .updateBalance(let amount, let currency):
        state.balance.amount = amount
        state.balance.currency = currency
        state.balance.lastUpdated = Date()

    // Sync
    case .syncWallet:
        state.isLoading = true
        state.error = nil

    case .syncStarted:
        state.isLoading = true
        state.error = nil

    case .syncCompleted(let timestamp):
        state.lastSyncTimestamp = timestamp
        state.isLoading = false
        state.error = nil

    case .syncFailed(let error):
        state.error = error
        state.isLoading = false

    // Loading & Errors
    case .setLoading(let loading):
        state.isLoading = loading

    case .setError(let error):
        state.error = error

    case .clearError:
        state.error = nil

    // Import/Export
    case .importWallet:
        state.isLoading = true
        state.error = nil

    case .walletImported(let account):
        state.accounts.append(account)
        state.selectedAccountId = account.id
        state.isLoading = false
        state.error = nil

    case .exportWallet:
        state.isLoading = true
        state.error = nil

    case .walletExported:
        state.isLoading = false
        state.error = nil

    // Backup
    case .backupWallet:
        state.isLoading = true
        state.error = nil

    case .backupCompleted:
        state.isLoading = false
        state.error = nil

    case .backupFailed(let error):
        state.error = error
        state.isLoading = false

    // Recovery
    case .recoverWallet:
        state.isLoading = true
        state.error = nil

    case .recoveryCompleted(let account):
        state.accounts.append(account)
        state.selectedAccountId = account.id
        state.isLoading = false
        state.error = nil

    case .recoveryFailed(let error):
        state.error = error
        state.isLoading = false
    }
}

// MARK: - Account Reducer
func accountReducer(state: inout WalletState, action: Action) {
    guard let action = action as? AccountAction else { return }

    switch action {
    case .updateLastUsed(let id, let date):
        if let index = state.accounts.firstIndex(where: { $0.id == id }) {
            state.accounts[index].lastUsed = date
        }

    case .updateAddress(let id, let address):
        if let index = state.accounts.firstIndex(where: { $0.id == id }) {
            state.accounts[index].address = address
        }

    case .setActive(let id):
        state.selectedAccountId = id
        if let index = state.accounts.firstIndex(where: { $0.id == id }) {
            state.accounts[index].lastUsed = Date()
        }

    case .setInactive:
        // Handle inactive state if needed
        break
    }
}

// MARK: - Balance Reducer
func balanceReducer(state: inout WalletState, action: Action) {
    guard let action = action as? BalanceAction else { return }

    switch action {
    case .refresh:
        state.isLoading = true
        state.error = nil

    case .refreshCompleted(let balance):
        state.balance = balance
        state.isLoading = false
        state.error = nil

    case .refreshFailed(let error):
        state.error = error
        state.isLoading = false

    case .setCurrency(let currency):
        state.balance.currency = currency

    case .updateAmount(let amount):
        state.balance.amount = amount
        state.balance.lastUpdated = Date()
    }
}
