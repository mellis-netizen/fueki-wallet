//
//  SettingsRepository.swift
//  FuekiWallet
//
//  Repository for app settings using UserDefaults
//

import Foundation
import os.log

/// Repository pattern implementation for app settings
final class SettingsRepository {
    // MARK: - Properties
    private let userDefaults: UserDefaultsManager
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "SettingsRepository")

    // MARK: - Initialization
    init(userDefaults: UserDefaultsManager) {
        self.userDefaults = userDefaults
    }

    // MARK: - General Settings

    /// Gets or sets the app theme
    var theme: AppTheme {
        get { userDefaults.theme }
        set {
            userDefaults.theme = newValue
            logger.info("Theme changed to: \(newValue.rawValue)")
        }
    }

    /// Gets or sets the app language
    var language: String {
        get { userDefaults.language }
        set {
            userDefaults.language = newValue
            logger.info("Language changed to: \(newValue)")
        }
    }

    /// Gets or sets the default currency
    var currency: String {
        get { userDefaults.currency }
        set {
            userDefaults.currency = newValue
            logger.info("Currency changed to: \(newValue)")
        }
    }

    // MARK: - Security Settings

    /// Gets or sets biometric authentication preference
    var biometricEnabled: Bool {
        get { userDefaults.biometricEnabled }
        set {
            userDefaults.biometricEnabled = newValue
            logger.info("Biometric authentication: \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Gets or sets auto-lock timeout (in seconds)
    var autoLockTimeout: TimeInterval {
        get { userDefaults.autoLockTimeout }
        set {
            userDefaults.autoLockTimeout = newValue
            logger.info("Auto-lock timeout set to: \(newValue) seconds")
        }
    }

    /// Gets or sets transaction signing confirmation requirement
    var requireConfirmation: Bool {
        get { userDefaults.requireConfirmation }
        set {
            userDefaults.requireConfirmation = newValue
            logger.info("Transaction confirmation: \(newValue ? "required" : "not required")")
        }
    }

    // MARK: - Network Settings

    /// Gets or sets the selected network
    var selectedNetwork: Network {
        get { userDefaults.selectedNetwork }
        set {
            userDefaults.selectedNetwork = newValue
            logger.info("Network changed to: \(newValue.rawValue)")
        }
    }

    /// Gets or sets custom RPC URL
    var customRpcUrl: String? {
        get { userDefaults.customRpcUrl }
        set {
            userDefaults.customRpcUrl = newValue
            if let url = newValue {
                logger.info("Custom RPC URL set: \(url)")
            }
        }
    }

    // MARK: - Display Settings

    /// Gets or sets whether to show balance on home screen
    var showBalance: Bool {
        get { userDefaults.showBalance }
        set {
            userDefaults.showBalance = newValue
            logger.info("Show balance: \(newValue)")
        }
    }

    /// Gets or sets whether to hide small balances
    var hideSmallBalances: Bool {
        get { userDefaults.hideSmallBalances }
        set {
            userDefaults.hideSmallBalances = newValue
            logger.info("Hide small balances: \(newValue)")
        }
    }

    /// Gets or sets the minimum balance threshold for hiding
    var smallBalanceThreshold: Double {
        get { userDefaults.smallBalanceThreshold }
        set {
            userDefaults.smallBalanceThreshold = newValue
            logger.info("Small balance threshold set to: \(newValue)")
        }
    }

    // MARK: - Notification Settings

    /// Gets or sets whether push notifications are enabled
    var notificationsEnabled: Bool {
        get { userDefaults.notificationsEnabled }
        set {
            userDefaults.notificationsEnabled = newValue
            logger.info("Notifications: \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Gets or sets whether transaction notifications are enabled
    var transactionNotifications: Bool {
        get { userDefaults.transactionNotifications }
        set {
            userDefaults.transactionNotifications = newValue
            logger.info("Transaction notifications: \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Gets or sets whether price alert notifications are enabled
    var priceAlertNotifications: Bool {
        get { userDefaults.priceAlertNotifications }
        set {
            userDefaults.priceAlertNotifications = newValue
            logger.info("Price alert notifications: \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Backup Settings

    /// Gets or sets the last backup date
    var lastBackupDate: Date? {
        get { userDefaults.lastBackupDate }
        set {
            userDefaults.lastBackupDate = newValue
            if let date = newValue {
                logger.info("Last backup date: \(date)")
            }
        }
    }

    /// Gets or sets whether auto-backup is enabled
    var autoBackupEnabled: Bool {
        get { userDefaults.autoBackupEnabled }
        set {
            userDefaults.autoBackupEnabled = newValue
            logger.info("Auto-backup: \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Gets or sets auto-backup frequency (in days)
    var autoBackupFrequency: Int {
        get { userDefaults.autoBackupFrequency }
        set {
            userDefaults.autoBackupFrequency = newValue
            logger.info("Auto-backup frequency set to: every \(newValue) days")
        }
    }

    // MARK: - Analytics Settings

    /// Gets or sets whether analytics are enabled
    var analyticsEnabled: Bool {
        get { userDefaults.analyticsEnabled }
        set {
            userDefaults.analyticsEnabled = newValue
            logger.info("Analytics: \(newValue ? "enabled" : "disabled")")
        }
    }

    /// Gets or sets whether crash reporting is enabled
    var crashReportingEnabled: Bool {
        get { userDefaults.crashReportingEnabled }
        set {
            userDefaults.crashReportingEnabled = newValue
            logger.info("Crash reporting: \(newValue ? "enabled" : "disabled")")
        }
    }

    // MARK: - Onboarding

    /// Gets or sets whether onboarding has been completed
    var hasCompletedOnboarding: Bool {
        get { userDefaults.hasCompletedOnboarding }
        set {
            userDefaults.hasCompletedOnboarding = newValue
            logger.info("Onboarding completed: \(newValue)")
        }
    }

    /// Gets or sets whether backup reminder has been shown
    var hasShownBackupReminder: Bool {
        get { userDefaults.hasShownBackupReminder }
        set {
            userDefaults.hasShownBackupReminder = newValue
        }
    }

    // MARK: - Reset

    /// Resets all settings to defaults
    func resetToDefaults() {
        userDefaults.resetToDefaults()
        logger.info("All settings reset to defaults")
    }

    /// Exports settings to dictionary
    func exportSettings() -> [String: Any] {
        return [
            "theme": theme.rawValue,
            "language": language,
            "currency": currency,
            "biometricEnabled": biometricEnabled,
            "autoLockTimeout": autoLockTimeout,
            "requireConfirmation": requireConfirmation,
            "selectedNetwork": selectedNetwork.rawValue,
            "showBalance": showBalance,
            "hideSmallBalances": hideSmallBalances,
            "smallBalanceThreshold": smallBalanceThreshold,
            "notificationsEnabled": notificationsEnabled,
            "transactionNotifications": transactionNotifications,
            "priceAlertNotifications": priceAlertNotifications,
            "autoBackupEnabled": autoBackupEnabled,
            "autoBackupFrequency": autoBackupFrequency,
            "analyticsEnabled": analyticsEnabled,
            "crashReportingEnabled": crashReportingEnabled
        ]
    }

    /// Imports settings from dictionary
    func importSettings(_ settings: [String: Any]) {
        if let themeRaw = settings["theme"] as? String,
           let theme = AppTheme(rawValue: themeRaw) {
            self.theme = theme
        }

        if let language = settings["language"] as? String {
            self.language = language
        }

        if let currency = settings["currency"] as? String {
            self.currency = currency
        }

        if let biometric = settings["biometricEnabled"] as? Bool {
            self.biometricEnabled = biometric
        }

        if let timeout = settings["autoLockTimeout"] as? TimeInterval {
            self.autoLockTimeout = timeout
        }

        if let confirmation = settings["requireConfirmation"] as? Bool {
            self.requireConfirmation = confirmation
        }

        if let networkRaw = settings["selectedNetwork"] as? String,
           let network = Network(rawValue: networkRaw) {
            self.selectedNetwork = network
        }

        logger.info("Settings imported successfully")
    }
}

// MARK: - Supporting Types
enum AppTheme: String, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
}

enum Network: String, Codable {
    case mainnet = "mainnet"
    case testnet = "testnet"
    case custom = "custom"
}
