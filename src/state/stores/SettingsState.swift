//
//  SettingsState.swift
//  Fueki Wallet
//
//  Settings and preferences state management
//

import Foundation
import Combine
import SwiftUI

@MainActor
class SettingsState: ObservableObject {
    // MARK: - Published Properties
    @Published var biometricEnabled = false
    @Published var notificationsEnabled = true
    @Published var currency: Currency = .usd
    @Published var language: AppLanguage = .english
    @Published var theme: AppTheme = .system
    @Published var autoLockEnabled = true
    @Published var autoLockTimeout: TimeInterval = 300 // 5 minutes
    @Published var showBalances = true
    @Published var analyticsEnabled = false
    @Published var crashReportingEnabled = true

    // Security settings
    @Published var requireBiometricForTransactions = true
    @Published var transactionConfirmationEnabled = true
    @Published var maxTransactionAmount: Decimal?

    // Network settings
    @Published var preferredNetworks: [String] = []
    @Published var customRPCEndpoints: [String: String] = [:]

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let defaults = UserDefaults.standard

    // MARK: - Initialization
    init() {
        loadSettings()
        setupAutoSave()
    }

    // MARK: - Settings Management

    func updateBiometric(enabled: Bool) {
        biometricEnabled = enabled
        saveSettings()
    }

    func updateNotifications(enabled: Bool) {
        notificationsEnabled = enabled
        saveSettings()
    }

    func updateCurrency(_ currency: Currency) {
        self.currency = currency
        saveSettings()
        notifyStateChange()
    }

    func updateLanguage(_ language: AppLanguage) {
        self.language = language
        saveSettings()
        notifyStateChange()
    }

    func updateTheme(_ theme: AppTheme) {
        self.theme = theme
        saveSettings()
        applyTheme()
    }

    func updateAutoLock(enabled: Bool, timeout: TimeInterval? = nil) {
        autoLockEnabled = enabled
        if let timeout = timeout {
            autoLockTimeout = timeout
        }
        saveSettings()
    }

    func updateSecuritySettings(
        requireBiometric: Bool? = nil,
        requireConfirmation: Bool? = nil,
        maxAmount: Decimal? = nil
    ) {
        if let requireBiometric = requireBiometric {
            requireBiometricForTransactions = requireBiometric
        }
        if let requireConfirmation = requireConfirmation {
            transactionConfirmationEnabled = requireConfirmation
        }
        if let maxAmount = maxAmount {
            maxTransactionAmount = maxAmount
        }
        saveSettings()
    }

    func addPreferredNetwork(_ networkId: String) {
        if !preferredNetworks.contains(networkId) {
            preferredNetworks.append(networkId)
            saveSettings()
        }
    }

    func removePreferredNetwork(_ networkId: String) {
        preferredNetworks.removeAll { $0 == networkId }
        saveSettings()
    }

    func setCustomRPCEndpoint(_ endpoint: String, for network: String) {
        customRPCEndpoints[network] = endpoint
        saveSettings()
    }

    // MARK: - State Management

    func reset() {
        biometricEnabled = false
        notificationsEnabled = true
        currency = .usd
        language = .english
        theme = .system
        autoLockEnabled = true
        autoLockTimeout = 300
        showBalances = true
        analyticsEnabled = false
        crashReportingEnabled = true
        requireBiometricForTransactions = true
        transactionConfirmationEnabled = true
        maxTransactionAmount = nil
        preferredNetworks = []
        customRPCEndpoints = [:]

        clearSettings()
    }

    // MARK: - Snapshot Management

    func createSnapshot() -> SettingsStateSnapshot {
        SettingsStateSnapshot(
            biometricEnabled: biometricEnabled,
            notificationsEnabled: notificationsEnabled,
            currency: currency,
            language: language,
            theme: theme,
            autoLockEnabled: autoLockEnabled,
            autoLockTimeout: autoLockTimeout,
            showBalances: showBalances,
            analyticsEnabled: analyticsEnabled,
            crashReportingEnabled: crashReportingEnabled,
            requireBiometricForTransactions: requireBiometricForTransactions,
            transactionConfirmationEnabled: transactionConfirmationEnabled,
            maxTransactionAmount: maxTransactionAmount,
            preferredNetworks: preferredNetworks,
            customRPCEndpoints: customRPCEndpoints
        )
    }

    func restore(from snapshot: SettingsStateSnapshot) async {
        biometricEnabled = snapshot.biometricEnabled
        notificationsEnabled = snapshot.notificationsEnabled
        currency = snapshot.currency
        language = snapshot.language
        theme = snapshot.theme
        autoLockEnabled = snapshot.autoLockEnabled
        autoLockTimeout = snapshot.autoLockTimeout
        showBalances = snapshot.showBalances
        analyticsEnabled = snapshot.analyticsEnabled
        crashReportingEnabled = snapshot.crashReportingEnabled
        requireBiometricForTransactions = snapshot.requireBiometricForTransactions
        transactionConfirmationEnabled = snapshot.transactionConfirmationEnabled
        maxTransactionAmount = snapshot.maxTransactionAmount
        preferredNetworks = snapshot.preferredNetworks
        customRPCEndpoints = snapshot.customRPCEndpoints

        applyTheme()
    }

    // MARK: - Private Methods

    private func loadSettings() {
        biometricEnabled = defaults.bool(forKey: "biometric_enabled")
        notificationsEnabled = defaults.bool(forKey: "notifications_enabled")

        if let currencyRaw = defaults.string(forKey: "currency"),
           let currency = Currency(rawValue: currencyRaw) {
            self.currency = currency
        }

        if let languageRaw = defaults.string(forKey: "language"),
           let language = AppLanguage(rawValue: languageRaw) {
            self.language = language
        }

        if let themeRaw = defaults.string(forKey: "theme"),
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }

        autoLockEnabled = defaults.bool(forKey: "auto_lock_enabled")
        autoLockTimeout = defaults.double(forKey: "auto_lock_timeout")
        showBalances = defaults.bool(forKey: "show_balances")
        analyticsEnabled = defaults.bool(forKey: "analytics_enabled")
        crashReportingEnabled = defaults.bool(forKey: "crash_reporting_enabled")
        requireBiometricForTransactions = defaults.bool(forKey: "require_biometric_transactions")
        transactionConfirmationEnabled = defaults.bool(forKey: "transaction_confirmation_enabled")

        if let maxAmount = defaults.object(forKey: "max_transaction_amount") as? Double {
            maxTransactionAmount = Decimal(maxAmount)
        }

        preferredNetworks = defaults.stringArray(forKey: "preferred_networks") ?? []
        customRPCEndpoints = defaults.dictionary(forKey: "custom_rpc_endpoints") as? [String: String] ?? [:]
    }

    private func saveSettings() {
        defaults.set(biometricEnabled, forKey: "biometric_enabled")
        defaults.set(notificationsEnabled, forKey: "notifications_enabled")
        defaults.set(currency.rawValue, forKey: "currency")
        defaults.set(language.rawValue, forKey: "language")
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(autoLockEnabled, forKey: "auto_lock_enabled")
        defaults.set(autoLockTimeout, forKey: "auto_lock_timeout")
        defaults.set(showBalances, forKey: "show_balances")
        defaults.set(analyticsEnabled, forKey: "analytics_enabled")
        defaults.set(crashReportingEnabled, forKey: "crash_reporting_enabled")
        defaults.set(requireBiometricForTransactions, forKey: "require_biometric_transactions")
        defaults.set(transactionConfirmationEnabled, forKey: "transaction_confirmation_enabled")

        if let maxAmount = maxTransactionAmount {
            defaults.set(NSDecimalNumber(decimal: maxAmount).doubleValue, forKey: "max_transaction_amount")
        }

        defaults.set(preferredNetworks, forKey: "preferred_networks")
        defaults.set(customRPCEndpoints, forKey: "custom_rpc_endpoints")
    }

    private func clearSettings() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
    }

    private func setupAutoSave() {
        // Auto-save on any change
        objectWillChange
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.saveSettings()
            }
            .store(in: &cancellables)
    }

    private func applyTheme() {
        // Apply theme to UI
        switch theme {
        case .light:
            // Set light mode
            NotificationCenter.default.post(name: .themeChanged, object: "light")

        case .dark:
            // Set dark mode
            NotificationCenter.default.post(name: .themeChanged, object: "dark")

        case .system:
            // Use system theme
            NotificationCenter.default.post(name: .themeChanged, object: "system")
        }

        notifyStateChange()
    }

    private func notifyStateChange() {
        NotificationCenter.default.post(
            name: .settingsStateChanged,
            object: createSnapshot()
        )
    }
}

// MARK: - Supporting Types

enum AppLanguage: String, Codable, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case japanese = "ja"
    case chinese = "zh"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light
    case dark
    case system

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

struct SettingsStateSnapshot: Codable {
    let biometricEnabled: Bool
    let notificationsEnabled: Bool
    let currency: Currency
    let language: AppLanguage
    let theme: AppTheme
    let autoLockEnabled: Bool
    let autoLockTimeout: TimeInterval
    let showBalances: Bool
    let analyticsEnabled: Bool
    let crashReportingEnabled: Bool
    let requireBiometricForTransactions: Bool
    let transactionConfirmationEnabled: Bool
    let maxTransactionAmount: Decimal?
    let preferredNetworks: [String]
    let customRPCEndpoints: [String: String]
}

// MARK: - Notifications

extension Notification.Name {
    static let settingsStateChanged = Notification.Name("settingsStateChanged")
    static let themeChanged = Notification.Name("themeChanged")
}
