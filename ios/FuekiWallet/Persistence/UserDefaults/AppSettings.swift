//
//  AppSettings.swift
//  FuekiWallet
//
//  ObservableObject wrapper for app settings
//

import Foundation
import Combine

/// Observable app settings for SwiftUI integration
final class AppSettings: ObservableObject {
    // MARK: - Singleton
    static let shared = AppSettings()

    // MARK: - Properties
    private let manager = UserDefaultsManager.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Settings

    @Published var theme: AppTheme {
        didSet { manager.theme = theme }
    }

    @Published var language: String {
        didSet { manager.language = language }
    }

    @Published var currency: String {
        didSet { manager.currency = currency }
    }

    @Published var biometricEnabled: Bool {
        didSet { manager.biometricEnabled = biometricEnabled }
    }

    @Published var autoLockTimeout: TimeInterval {
        didSet { manager.autoLockTimeout = autoLockTimeout }
    }

    @Published var requireConfirmation: Bool {
        didSet { manager.requireConfirmation = requireConfirmation }
    }

    @Published var selectedNetwork: Network {
        didSet { manager.selectedNetwork = selectedNetwork }
    }

    @Published var customRpcUrl: String? {
        didSet { manager.customRpcUrl = customRpcUrl }
    }

    @Published var showBalance: Bool {
        didSet { manager.showBalance = showBalance }
    }

    @Published var hideSmallBalances: Bool {
        didSet { manager.hideSmallBalances = hideSmallBalances }
    }

    @Published var smallBalanceThreshold: Double {
        didSet { manager.smallBalanceThreshold = smallBalanceThreshold }
    }

    @Published var notificationsEnabled: Bool {
        didSet { manager.notificationsEnabled = notificationsEnabled }
    }

    @Published var transactionNotifications: Bool {
        didSet { manager.transactionNotifications = transactionNotifications }
    }

    @Published var priceAlertNotifications: Bool {
        didSet { manager.priceAlertNotifications = priceAlertNotifications }
    }

    @Published var lastBackupDate: Date? {
        didSet { manager.lastBackupDate = lastBackupDate }
    }

    @Published var autoBackupEnabled: Bool {
        didSet { manager.autoBackupEnabled = autoBackupEnabled }
    }

    @Published var autoBackupFrequency: Int {
        didSet { manager.autoBackupFrequency = autoBackupFrequency }
    }

    @Published var analyticsEnabled: Bool {
        didSet { manager.analyticsEnabled = analyticsEnabled }
    }

    @Published var crashReportingEnabled: Bool {
        didSet { manager.crashReportingEnabled = crashReportingEnabled }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { manager.hasCompletedOnboarding = hasCompletedOnboarding }
    }

    @Published var hasShownBackupReminder: Bool {
        didSet { manager.hasShownBackupReminder = hasShownBackupReminder }
    }

    // MARK: - Initialization
    private init() {
        // Initialize published properties from UserDefaults
        self.theme = manager.theme
        self.language = manager.language
        self.currency = manager.currency
        self.biometricEnabled = manager.biometricEnabled
        self.autoLockTimeout = manager.autoLockTimeout
        self.requireConfirmation = manager.requireConfirmation
        self.selectedNetwork = manager.selectedNetwork
        self.customRpcUrl = manager.customRpcUrl
        self.showBalance = manager.showBalance
        self.hideSmallBalances = manager.hideSmallBalances
        self.smallBalanceThreshold = manager.smallBalanceThreshold
        self.notificationsEnabled = manager.notificationsEnabled
        self.transactionNotifications = manager.transactionNotifications
        self.priceAlertNotifications = manager.priceAlertNotifications
        self.lastBackupDate = manager.lastBackupDate
        self.autoBackupEnabled = manager.autoBackupEnabled
        self.autoBackupFrequency = manager.autoBackupFrequency
        self.analyticsEnabled = manager.analyticsEnabled
        self.crashReportingEnabled = manager.crashReportingEnabled
        self.hasCompletedOnboarding = manager.hasCompletedOnboarding
        self.hasShownBackupReminder = manager.hasShownBackupReminder
    }

    // MARK: - Computed Properties

    var shouldShowBackupReminder: Bool {
        guard !hasShownBackupReminder else { return false }

        if let lastBackup = lastBackupDate {
            let daysSinceBackup = Calendar.current.dateComponents(
                [.day],
                from: lastBackup,
                to: Date()
            ).day ?? 0

            return daysSinceBackup >= autoBackupFrequency
        }

        return true // No backup exists
    }

    var isDarkMode: Bool {
        switch theme {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            // Would need UITraitCollection to determine actual system theme
            return false
        }
    }

    // MARK: - Methods

    func resetToDefaults() {
        manager.resetToDefaults()

        // Re-sync published properties
        theme = manager.theme
        language = manager.language
        currency = manager.currency
        biometricEnabled = manager.biometricEnabled
        autoLockTimeout = manager.autoLockTimeout
        requireConfirmation = manager.requireConfirmation
        selectedNetwork = manager.selectedNetwork
        customRpcUrl = manager.customRpcUrl
        showBalance = manager.showBalance
        hideSmallBalances = manager.hideSmallBalances
        smallBalanceThreshold = manager.smallBalanceThreshold
        notificationsEnabled = manager.notificationsEnabled
        transactionNotifications = manager.transactionNotifications
        priceAlertNotifications = manager.priceAlertNotifications
        lastBackupDate = manager.lastBackupDate
        autoBackupEnabled = manager.autoBackupEnabled
        autoBackupFrequency = manager.autoBackupFrequency
        analyticsEnabled = manager.analyticsEnabled
        crashReportingEnabled = manager.crashReportingEnabled
        hasCompletedOnboarding = manager.hasCompletedOnboarding
        hasShownBackupReminder = manager.hasShownBackupReminder
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func markBackupReminderShown() {
        hasShownBackupReminder = true
    }

    func recordBackup() {
        lastBackupDate = Date()
    }
}
