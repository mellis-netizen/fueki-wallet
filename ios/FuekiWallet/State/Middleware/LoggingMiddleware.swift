//
//  LoggingMiddleware.swift
//  FuekiWallet
//
//  Middleware for logging state changes and actions
//

import Foundation
import Combine

// MARK: - Logging Middleware
func loggingMiddleware(state: AppState, action: Action) -> AnyPublisher<Action, Never>? {
    #if DEBUG
    let actionType = String(describing: type(of: action))
    let timestamp = Date()

    print("🎬 [\(timestamp.formatted())] Action: \(actionType)")

    // Log specific action details
    logActionDetails(action)

    // Log state changes
    logStateSnapshot(state)

    #endif

    // Logging middleware doesn't dispatch new actions
    return nil
}

// MARK: - Action Details Logging
private func logActionDetails(_ action: Action) {
    #if DEBUG
    switch action {

    // Wallet Actions
    case let action as WalletAction:
        logWalletAction(action)

    // Transaction Actions
    case let action as TransactionAction:
        logTransactionAction(action)

    // Settings Actions
    case let action as SettingsAction:
        logSettingsAction(action)

    // Auth Actions
    case let action as AuthAction:
        logAuthAction(action)

    default:
        print("  ℹ️  Unknown action type")
    }
    #endif
}

// MARK: - Wallet Action Logging
private func logWalletAction(_ action: WalletAction) {
    #if DEBUG
    switch action {
    case .createAccount(let name):
        print("  📝 Creating account: \(name)")

    case .accountCreated(let account):
        print("  ✅ Account created: \(account.name) (\(account.id))")

    case .selectAccount(let id):
        print("  👆 Selecting account: \(id)")

    case .fetchBalance:
        print("  💰 Fetching balance...")

    case .balanceFetched(let balance):
        print("  ✅ Balance fetched: \(balance.formattedAmount) \(balance.currency.rawValue)")

    case .syncWallet:
        print("  🔄 Syncing wallet...")

    case .syncCompleted(let timestamp):
        print("  ✅ Sync completed at: \(timestamp.formatted())")

    case .syncFailed(let error):
        print("  ❌ Sync failed: \(error.message)")

    default:
        print("  ℹ️  Other wallet action")
    }
    #endif
}

// MARK: - Transaction Action Logging
private func logTransactionAction(_ action: TransactionAction) {
    #if DEBUG
    switch action {
    case .fetchTransactions:
        print("  📋 Fetching transactions...")

    case .transactionsFetched(let transactions):
        print("  ✅ Fetched \(transactions.count) transactions")

    case .createTransaction(let type, let amount, let to, _):
        print("  💸 Creating \(type.rawValue) transaction: \(amount) to \(to)")

    case .transactionCreated(let transaction):
        print("  ✅ Transaction created: \(transaction.id)")

    case .transactionSent(let transaction):
        print("  ✅ Transaction sent: \(transaction.id)")

    case .updateTransaction(let id, let status):
        print("  🔄 Updating transaction \(id) to \(status.rawValue)")

    default:
        print("  ℹ️  Other transaction action")
    }
    #endif
}

// MARK: - Settings Action Logging
private func logSettingsAction(_ action: SettingsAction) {
    #if DEBUG
    switch action {
    case .setCurrency(let currency):
        print("  💱 Setting currency: \(currency.rawValue)")

    case .setLanguage(let language):
        print("  🌐 Setting language: \(language.rawValue)")

    case .setTheme(let theme):
        print("  🎨 Setting theme: \(theme.rawValue)")

    case .enableBiometric:
        print("  🔐 Enabling biometric authentication")

    case .disableBiometric:
        print("  🔓 Disabling biometric authentication")

    case .setNetwork(let network):
        print("  🌐 Setting network: \(network.rawValue)")

    default:
        print("  ℹ️  Other settings action")
    }
    #endif
}

// MARK: - Auth Action Logging
private func logAuthAction(_ action: AuthAction) {
    #if DEBUG
    switch action {
    case .authenticate(let method):
        print("  🔐 Authenticating with: \(method.rawValue)")

    case .authenticationSucceeded(let method, _):
        print("  ✅ Authentication succeeded: \(method.rawValue)")

    case .authenticationFailed(let error):
        print("  ❌ Authentication failed: \(error.message)")

    case .lock:
        print("  🔒 Locking app")

    case .unlock:
        print("  🔓 Unlocking app")

    case .logout:
        print("  👋 Logging out")

    case .sessionExpired:
        print("  ⏰ Session expired")

    default:
        print("  ℹ️  Other auth action")
    }
    #endif
}

// MARK: - State Snapshot Logging
private func logStateSnapshot(_ state: AppState) {
    #if DEBUG
    print("  📊 State Snapshot:")
    print("    - Accounts: \(state.wallet.accounts.count)")
    print("    - Balance: \(state.wallet.balance.formattedAmount) \(state.wallet.balance.currency.rawValue)")
    print("    - Pending Transactions: \(state.transactions.pending.count)")
    print("    - Confirmed Transactions: \(state.transactions.confirmed.count)")
    print("    - Authenticated: \(state.auth.isAuthenticated)")
    print("    - Locked: \(state.auth.isLocked)")
    #endif
}

// MARK: - Performance Logging
func performanceLoggingMiddleware(state: AppState, action: Action) -> AnyPublisher<Action, Never>? {
    #if DEBUG
    let startTime = CFAbsoluteTimeGetCurrent()

    // Measure action processing time
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let actionType = String(describing: type(of: action))

        if timeElapsed > 0.1 {
            print("⚠️  Slow action detected: \(actionType) took \(String(format: "%.3f", timeElapsed))s")
        } else {
            print("⚡️ Fast action: \(actionType) took \(String(format: "%.3f", timeElapsed))s")
        }
    }
    #endif

    return nil
}
