import Foundation
import UIKit

/// Manages user properties for analytics
public class UserPropertyManager {

    // MARK: - Singleton
    public static let shared = UserPropertyManager()

    // MARK: - Properties
    private let queue = DispatchQueue(label: "com.fueki.userproperties", qos: .utility)
    private var properties: [String: String] = [:]

    // MARK: - Standard Properties

    public enum StandardProperty: String {
        case userId = "user_id"
        case deviceId = "device_id"
        case appVersion = "app_version"
        case osVersion = "os_version"
        case deviceModel = "device_model"
        case language = "language"
        case timezone = "timezone"
        case walletCount = "wallet_count"
        case preferredCurrency = "preferred_currency"
        case networkType = "network_type"
        case isPremiumUser = "is_premium_user"
        case signupDate = "signup_date"
        case lastActiveDate = "last_active_date"
    }

    // MARK: - Initialization
    private init() {
        loadProperties()
        setupDefaultProperties()
    }

    // MARK: - Property Management

    /// Set a user property
    /// - Parameters:
    ///   - property: Property key
    ///   - value: Property value
    public func setProperty(_ property: String, value: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.properties[property] = value
            self.saveProperties()

            // Update in analytics
            AnalyticsManager.shared.setUserProperty(property, value: value)

            Logger.shared.log(
                "User property set: \(property) = \(value)",
                level: .debug,
                category: .analytics
            )
        }
    }

    /// Set a standard user property
    /// - Parameters:
    ///   - property: Standard property
    ///   - value: Property value
    public func setProperty(_ property: StandardProperty, value: String) {
        setProperty(property.rawValue, value: value)
    }

    /// Get a user property
    /// - Parameter property: Property key
    /// - Returns: Property value if exists
    public func getProperty(_ property: String) -> String? {
        return queue.sync {
            properties[property]
        }
    }

    /// Get a standard user property
    /// - Parameter property: Standard property
    /// - Returns: Property value if exists
    public func getProperty(_ property: StandardProperty) -> String? {
        return getProperty(property.rawValue)
    }

    /// Remove a user property
    /// - Parameter property: Property key
    public func removeProperty(_ property: String) {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.properties.removeValue(forKey: property)
            self.saveProperties()

            Logger.shared.log(
                "User property removed: \(property)",
                level: .debug,
                category: .analytics
            )
        }
    }

    /// Get all user properties
    /// - Returns: Dictionary of all properties
    public func getAllProperties() -> [String: String] {
        return queue.sync {
            properties
        }
    }

    /// Clear all user properties (for logout)
    public func clearAllProperties() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.properties.removeAll()
            self.saveProperties()
            self.setupDefaultProperties()

            Logger.shared.log(
                "All user properties cleared",
                level: .info,
                category: .analytics
            )
        }
    }

    // MARK: - Default Properties

    private func setupDefaultProperties() {
        // Device properties
        setProperty(.deviceId, value: getDeviceId())
        setProperty(.deviceModel, value: UIDevice.current.model)
        setProperty(.osVersion, value: UIDevice.current.systemVersion)

        // App properties
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            setProperty(.appVersion, value: appVersion)
        }

        // Locale properties
        setProperty(.language, value: Locale.current.languageCode ?? "unknown")
        setProperty(.timezone, value: TimeZone.current.identifier)

        // Update last active date
        setProperty(.lastActiveDate, value: ISO8601DateFormatter().string(from: Date()))
    }

    private func getDeviceId() -> String {
        // Get or create persistent device ID
        let key = "device_id_persistent"

        if let existingId = UserDefaults.standard.string(forKey: key) {
            return existingId
        }

        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    // MARK: - Wallet Properties

    /// Update wallet count
    /// - Parameter count: Number of wallets
    public func updateWalletCount(_ count: Int) {
        setProperty(.walletCount, value: "\(count)")
    }

    /// Set preferred currency
    /// - Parameter currency: Currency code
    public func setPreferredCurrency(_ currency: String) {
        setProperty(.preferredCurrency, value: currency)
    }

    /// Set network type (mainnet/testnet)
    /// - Parameter network: Network type
    public func setNetworkType(_ network: String) {
        setProperty(.networkType, value: network)
    }

    /// Set premium user status
    /// - Parameter isPremium: Whether user is premium
    public func setPremiumStatus(_ isPremium: Bool) {
        setProperty(.isPremiumUser, value: isPremium ? "true" : "false")
    }

    // MARK: - User Lifecycle

    /// Mark user signup
    public func recordSignup() {
        let signupDate = ISO8601DateFormatter().string(from: Date())
        setProperty(.signupDate, value: signupDate)

        AnalyticsManager.shared.track(.walletCreated(type: .hd))
    }

    /// Update last active timestamp
    public func updateLastActive() {
        let now = ISO8601DateFormatter().string(from: Date())
        setProperty(.lastActiveDate, value: now)
    }

    // MARK: - Anonymized User ID

    /// Set anonymized user ID
    /// - Parameter userId: User identifier (will be hashed)
    public func setAnonymizedUserId(_ userId: String) {
        // Hash the user ID for privacy
        let hashedId = hashUserId(userId)
        setProperty(.userId, value: hashedId)

        // Update in analytics and crash reporter
        AnalyticsManager.shared.setUserId(hashedId)
        CrashReporter.shared.setUserId(hashedId)
    }

    private func hashUserId(_ userId: String) -> String {
        // Simple SHA256 hash for privacy
        // In production, use a more secure hashing method
        return userId.data(using: .utf8)?
            .base64EncodedString()
            .prefix(32)
            .description ?? userId
    }

    // MARK: - Persistence

    private var propertiesFileURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("user_properties.json")
    }

    private func saveProperties() {
        guard let fileURL = propertiesFileURL else { return }

        if let data = try? JSONEncoder().encode(properties) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func loadProperties() {
        guard let fileURL = propertiesFileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let props = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }

        properties = props
    }
}

// MARK: - Convenience Extensions

public extension UserPropertyManager {
    /// Increment a numeric property
    /// - Parameters:
    ///   - property: Property key
    ///   - by: Amount to increment
    func incrementProperty(_ property: String, by amount: Int = 1) {
        queue.async { [weak self] in
            guard let self = self else { return }

            let currentValue = Int(self.properties[property] ?? "0") ?? 0
            let newValue = currentValue + amount

            self.setProperty(property, value: "\(newValue)")
        }
    }

    /// Track a feature flag state
    /// - Parameters:
    ///   - feature: Feature name
    ///   - enabled: Whether feature is enabled
    func setFeatureFlag(_ feature: String, enabled: Bool) {
        setProperty("feature_\(feature)", value: enabled ? "enabled" : "disabled")
    }
}
