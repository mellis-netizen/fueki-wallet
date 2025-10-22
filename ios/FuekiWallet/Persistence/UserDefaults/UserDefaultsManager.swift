//
//  UserDefaultsManager.swift
//  FuekiWallet
//
//  Type-safe UserDefaults wrapper
//

import Foundation
import os.log

/// Type-safe UserDefaults manager with observation support
final class UserDefaultsManager {
    // MARK: - Singleton
    static let shared = UserDefaultsManager()

    // MARK: - Properties
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "io.fueki.wallet", category: "UserDefaults")

    // MARK: - Keys
    private enum Keys {
        // General
        static let theme = "app.theme"
        static let language = "app.language"
        static let currency = "app.currency"

        // Security
        static let biometricEnabled = "security.biometric.enabled"
        static let autoLockTimeout = "security.autoLock.timeout"
        static let requireConfirmation = "security.requireConfirmation"

        // Network
        static let selectedNetwork = "network.selected"
        static let customRpcUrl = "network.customRpc"

        // Display
        static let showBalance = "display.showBalance"
        static let hideSmallBalances = "display.hideSmallBalances"
        static let smallBalanceThreshold = "display.smallBalanceThreshold"

        // Notifications
        static let notificationsEnabled = "notifications.enabled"
        static let transactionNotifications = "notifications.transactions"
        static let priceAlertNotifications = "notifications.priceAlerts"

        // Backup
        static let lastBackupDate = "backup.lastDate"
        static let autoBackupEnabled = "backup.auto.enabled"
        static let autoBackupFrequency = "backup.auto.frequency"

        // Analytics
        static let analyticsEnabled = "analytics.enabled"
        static let crashReportingEnabled = "analytics.crashReporting"

        // Onboarding
        static let hasCompletedOnboarding = "onboarding.completed"
        static let hasShownBackupReminder = "onboarding.backupReminder"
    }

    // MARK: - Initialization
    private init() {
        self.defaults = UserDefaults.standard
        registerDefaults()
    }

    // MARK: - General Settings

    var theme: AppTheme {
        get {
            let rawValue = defaults.string(forKey: Keys.theme) ?? AppTheme.system.rawValue
            return AppTheme(rawValue: rawValue) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.theme)
        }
    }

    var language: String {
        get { defaults.string(forKey: Keys.language) ?? "en" }
        set { defaults.set(newValue, forKey: Keys.language) }
    }

    var currency: String {
        get { defaults.string(forKey: Keys.currency) ?? "USD" }
        set { defaults.set(newValue, forKey: Keys.currency) }
    }

    // MARK: - Security Settings

    var biometricEnabled: Bool {
        get { defaults.bool(forKey: Keys.biometricEnabled) }
        set { defaults.set(newValue, forKey: Keys.biometricEnabled) }
    }

    var autoLockTimeout: TimeInterval {
        get {
            let timeout = defaults.double(forKey: Keys.autoLockTimeout)
            return timeout > 0 ? timeout : 300 // Default 5 minutes
        }
        set { defaults.set(newValue, forKey: Keys.autoLockTimeout) }
    }

    var requireConfirmation: Bool {
        get { defaults.bool(forKey: Keys.requireConfirmation) }
        set { defaults.set(newValue, forKey: Keys.requireConfirmation) }
    }

    // MARK: - Network Settings

    var selectedNetwork: Network {
        get {
            let rawValue = defaults.string(forKey: Keys.selectedNetwork) ?? Network.mainnet.rawValue
            return Network(rawValue: rawValue) ?? .mainnet
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.selectedNetwork)
        }
    }

    var customRpcUrl: String? {
        get { defaults.string(forKey: Keys.customRpcUrl) }
        set { defaults.set(newValue, forKey: Keys.customRpcUrl) }
    }

    // MARK: - Display Settings

    var showBalance: Bool {
        get { defaults.object(forKey: Keys.showBalance) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.showBalance) }
    }

    var hideSmallBalances: Bool {
        get { defaults.bool(forKey: Keys.hideSmallBalances) }
        set { defaults.set(newValue, forKey: Keys.hideSmallBalances) }
    }

    var smallBalanceThreshold: Double {
        get {
            let threshold = defaults.double(forKey: Keys.smallBalanceThreshold)
            return threshold > 0 ? threshold : 1.0 // Default $1
        }
        set { defaults.set(newValue, forKey: Keys.smallBalanceThreshold) }
    }

    // MARK: - Notification Settings

    var notificationsEnabled: Bool {
        get { defaults.object(forKey: Keys.notificationsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.notificationsEnabled) }
    }

    var transactionNotifications: Bool {
        get { defaults.object(forKey: Keys.transactionNotifications) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.transactionNotifications) }
    }

    var priceAlertNotifications: Bool {
        get { defaults.object(forKey: Keys.priceAlertNotifications) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.priceAlertNotifications) }
    }

    // MARK: - Backup Settings

    var lastBackupDate: Date? {
        get { defaults.object(forKey: Keys.lastBackupDate) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastBackupDate) }
    }

    var autoBackupEnabled: Bool {
        get { defaults.bool(forKey: Keys.autoBackupEnabled) }
        set { defaults.set(newValue, forKey: Keys.autoBackupEnabled) }
    }

    var autoBackupFrequency: Int {
        get {
            let frequency = defaults.integer(forKey: Keys.autoBackupFrequency)
            return frequency > 0 ? frequency : 7 // Default 7 days
        }
        set { defaults.set(newValue, forKey: Keys.autoBackupFrequency) }
    }

    // MARK: - Analytics Settings

    var analyticsEnabled: Bool {
        get { defaults.object(forKey: Keys.analyticsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.analyticsEnabled) }
    }

    var crashReportingEnabled: Bool {
        get { defaults.object(forKey: Keys.crashReportingEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.crashReportingEnabled) }
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    var hasShownBackupReminder: Bool {
        get { defaults.bool(forKey: Keys.hasShownBackupReminder) }
        set { defaults.set(newValue, forKey: Keys.hasShownBackupReminder) }
    }

    // MARK: - Generic Accessors

    func set<T>(_ value: T, forKey key: String) {
        defaults.set(value, forKey: key)
        logger.debug("UserDefaults set: \(key)")
    }

    func get<T>(forKey key: String) -> T? {
        return defaults.object(forKey: key) as? T
    }

    func remove(forKey key: String) {
        defaults.removeObject(forKey: key)
        logger.debug("UserDefaults removed: \(key)")
    }

    // MARK: - Array and Dictionary Support

    func setArray<T: Codable>(_ array: [T], forKey key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(array) {
            defaults.set(encoded, forKey: key)
        }
    }

    func getArray<T: Codable>(forKey key: String) -> [T]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([T].self, from: data)
    }

    func setDictionary<T: Codable>(_ dictionary: [String: T], forKey key: String) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(dictionary) {
            defaults.set(encoded, forKey: key)
        }
    }

    func getDictionary<T: Codable>(forKey key: String) -> [String: T]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([String: T].self, from: data)
    }

    // MARK: - Synchronization

    func synchronize() {
        defaults.synchronize()
        logger.info("UserDefaults synchronized")
    }

    // MARK: - Reset

    func resetToDefaults() {
        let domain = Bundle.main.bundleIdentifier!
        defaults.removePersistentDomain(forName: domain)
        registerDefaults()
        synchronize()
        logger.info("UserDefaults reset to defaults")
    }

    func resetKey(_ key: String) {
        defaults.removeObject(forKey: key)
        logger.debug("UserDefaults key reset: \(key)")
    }

    // MARK: - Private Helpers

    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            Keys.theme: AppTheme.system.rawValue,
            Keys.language: "en",
            Keys.currency: "USD",
            Keys.biometricEnabled: false,
            Keys.autoLockTimeout: 300.0,
            Keys.requireConfirmation: true,
            Keys.selectedNetwork: Network.mainnet.rawValue,
            Keys.showBalance: true,
            Keys.hideSmallBalances: false,
            Keys.smallBalanceThreshold: 1.0,
            Keys.notificationsEnabled: true,
            Keys.transactionNotifications: true,
            Keys.priceAlertNotifications: true,
            Keys.autoBackupEnabled: false,
            Keys.autoBackupFrequency: 7,
            Keys.analyticsEnabled: true,
            Keys.crashReportingEnabled: true,
            Keys.hasCompletedOnboarding: false,
            Keys.hasShownBackupReminder: false
        ]

        defaults.register(defaults: defaultValues)
        logger.info("UserDefaults defaults registered")
    }
}

// MARK: - Observation Support
extension UserDefaultsManager {
    /// Observes changes to a specific key
    func observe<T>(key: String, onChange: @escaping (T?) -> Void) -> NSKeyValueObservation {
        return defaults.observe(\.self, options: [.new]) { _, _ in
            let value = self.defaults.object(forKey: key) as? T
            onChange(value)
        }
    }
}
