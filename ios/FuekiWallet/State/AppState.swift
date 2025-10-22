//
//  AppState.swift
//  FuekiWallet
//
//  Root application state - immutable data structure
//

import Foundation
import Combine

// MARK: - AppState
/// Root state for the entire application
/// All state changes flow through this immutable structure
struct AppState: Equatable, Codable {
    var wallet: WalletState
    var transactions: TransactionState
    var settings: SettingsState
    var auth: AuthState
    var ui: UIState

    // MARK: - Initialization
    init(
        wallet: WalletState = WalletState(),
        transactions: TransactionState = TransactionState(),
        settings: SettingsState = SettingsState(),
        auth: AuthState = AuthState(),
        ui: UIState = UIState()
    ) {
        self.wallet = wallet
        self.transactions = transactions
        self.settings = settings
        self.auth = auth
        self.ui = ui
    }

    // MARK: - Factory
    static var initial: AppState {
        AppState()
    }
}

// MARK: - WalletState
struct WalletState: Equatable, Codable {
    var accounts: [WalletAccount] = []
    var selectedAccountId: String?
    var balance: Balance = Balance()
    var isLoading: Bool = false
    var error: ErrorState?
    var lastSyncTimestamp: Date?

    var selectedAccount: WalletAccount? {
        guard let id = selectedAccountId else { return nil }
        return accounts.first { $0.id == id }
    }
}

// MARK: - TransactionState
struct TransactionState: Equatable, Codable {
    var pending: [Transaction] = []
    var confirmed: [Transaction] = []
    var failed: [Transaction] = []
    var isLoading: Bool = false
    var error: ErrorState?
    var lastFetchTimestamp: Date?
    var filter: TransactionFilter = .all

    var allTransactions: [Transaction] {
        (pending + confirmed + failed).sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - SettingsState
struct SettingsState: Equatable, Codable {
    var currency: Currency = .usd
    var language: Language = .english
    var theme: Theme = .system
    var biometricEnabled: Bool = false
    var notificationsEnabled: Bool = true
    var autoLockTimeout: TimeInterval = 300 // 5 minutes
    var network: Network = .mainnet
    var isLoading: Bool = false
    var error: ErrorState?
}

// MARK: - AuthState
struct AuthState: Equatable, Codable {
    var isAuthenticated: Bool = false
    var authMethod: AuthMethod?
    var lastAuthTimestamp: Date?
    var sessionExpiry: Date?
    var biometricType: BiometricType?
    var isLocked: Bool = true
    var failedAttempts: Int = 0
    var error: ErrorState?

    var requiresAuth: Bool {
        guard let expiry = sessionExpiry else { return true }
        return Date() >= expiry
    }
}

// MARK: - UIState
struct UIState: Equatable, Codable {
    var isOnboardingComplete: Bool = false
    var activeSheet: SheetType?
    var activeAlert: AlertType?
    var isLoading: Bool = false
    var loadingMessage: String?
    var toast: ToastMessage?
}

// MARK: - Supporting Types
struct WalletAccount: Equatable, Codable, Identifiable {
    let id: String
    var name: String
    var address: String
    var balance: Balance
    var createdAt: Date
    var lastUsed: Date
}

struct Balance: Equatable, Codable {
    var amount: Decimal = 0
    var currency: Currency = .usd
    var lastUpdated: Date?

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        return formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
    }
}

struct Transaction: Equatable, Codable, Identifiable {
    let id: String
    var type: TransactionType
    var amount: Decimal
    var currency: Currency
    var fromAddress: String
    var toAddress: String
    var timestamp: Date
    var status: TransactionStatus
    var fee: Decimal?
    var confirmations: Int?
    var blockNumber: Int?
    var hash: String?
    var memo: String?
}

struct ErrorState: Equatable, Codable {
    var code: String
    var message: String
    var timestamp: Date
    var recoverable: Bool
}

struct ToastMessage: Equatable, Codable {
    var message: String
    var type: ToastType
    var duration: TimeInterval
    var timestamp: Date
}

// MARK: - Enums
enum Currency: String, Codable, CaseIterable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case btc = "BTC"
    case eth = "ETH"
}

enum Language: String, Codable, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case chinese = "zh"
}

enum Theme: String, Codable, CaseIterable {
    case light
    case dark
    case system
}

enum Network: String, Codable, CaseIterable {
    case mainnet
    case testnet
    case devnet
}

enum AuthMethod: String, Codable {
    case biometric
    case passcode
    case none
}

enum BiometricType: String, Codable {
    case faceID
    case touchID
    case none
}

enum TransactionType: String, Codable {
    case send
    case receive
    case swap
    case stake
    case unstake
}

enum TransactionStatus: String, Codable {
    case pending
    case confirmed
    case failed
    case cancelled
}

enum TransactionFilter: String, Codable {
    case all
    case sent
    case received
    case pending
    case failed
}

enum SheetType: String, Codable {
    case send
    case receive
    case swap
    case settings
    case accountDetails
    case transactionDetails
}

enum AlertType: String, Codable {
    case error
    case warning
    case success
    case confirmation
}

enum ToastType: String, Codable {
    case success
    case error
    case warning
    case info
}
