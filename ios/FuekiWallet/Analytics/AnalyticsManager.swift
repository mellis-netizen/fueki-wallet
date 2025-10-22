import Foundation
import UIKit

/// Main analytics manager coordinating multiple analytics providers
public class AnalyticsManager {

    // MARK: - Singleton
    public static let shared = AnalyticsManager()

    // MARK: - Properties
    private var providers: [AnalyticsProvider] = []
    private let queue = DispatchQueue(label: "com.fueki.analytics", qos: .utility)
    private var isInitialized = false

    // User consent for analytics
    public var userHasConsentedToAnalytics: Bool {
        get {
            UserDefaults.standard.bool(forKey: "analytics_consent")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "analytics_consent")
            updateProvidersState()
        }
    }

    // MARK: - Initialization
    private init() {
        setupProviders()
        observeAppLifecycle()
    }

    private func setupProviders() {
        // Add console provider for development
        #if DEBUG
        providers.append(ConsoleAnalyticsProvider())
        #endif

        // Add Firebase provider (disabled by default)
        providers.append(FirebaseAnalyticsProvider())

        // Add other providers as needed
        // providers.append(CustomAnalyticsProvider())
    }

    /// Initialize all analytics providers
    public func initialize() {
        guard !isInitialized else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                provider.initialize()
            }

            self.isInitialized = true
            Logger.shared.log("Analytics initialized with \(self.providers.count) providers", level: .info, category: .analytics)
        }
    }

    // MARK: - Event Tracking

    /// Track an analytics event
    /// - Parameters:
    ///   - event: The event to track
    ///   - properties: Additional properties
    public func track(_ event: AnalyticsEvent, properties: [String: Any]? = nil) {
        guard userHasConsentedToAnalytics else {
            Logger.shared.log("Analytics tracking skipped - no user consent", level: .debug, category: .analytics)
            return
        }

        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                guard provider.isEnabled else { return }
                provider.trackEvent(event, properties: properties)
            }
        }
    }

    /// Track screen view
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - screenClass: Class name of the screen
    public func trackScreen(_ screenName: String, screenClass: String? = nil) {
        guard userHasConsentedToAnalytics else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                guard provider.isEnabled else { return }
                provider.trackScreen(screenName, screenClass: screenClass)
            }
        }
    }

    /// Track timing event
    /// - Parameters:
    ///   - category: Category of the timing
    ///   - name: Name of the timing
    ///   - duration: Duration in seconds
    public func trackTiming(category: String, name: String, duration: TimeInterval) {
        guard userHasConsentedToAnalytics else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                guard provider.isEnabled else { return }
                provider.trackTiming(category: category, name: name, duration: duration)
            }
        }
    }

    // MARK: - User Properties

    /// Set user property
    /// - Parameters:
    ///   - property: Property name
    ///   - value: Property value
    public func setUserProperty(_ property: String, value: String) {
        guard userHasConsentedToAnalytics else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                guard provider.isEnabled else { return }
                provider.setUserProperty(property, value: value)
            }
        }
    }

    /// Set anonymized user ID
    /// - Parameter userId: User identifier (should be anonymized/hashed)
    public func setUserId(_ userId: String?) {
        guard userHasConsentedToAnalytics else { return }

        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                guard provider.isEnabled else { return }
                provider.setUserId(userId)
            }
        }
    }

    /// Reset all user data (for logout/privacy)
    public func resetUserData() {
        queue.async { [weak self] in
            guard let self = self else { return }

            self.providers.forEach { provider in
                provider.resetUserData()
            }

            Logger.shared.log("Analytics user data reset", level: .info, category: .analytics)
        }
    }

    // MARK: - Provider Management

    /// Enable or disable a specific provider
    /// - Parameters:
    ///   - providerName: Name of the provider
    ///   - enabled: Whether to enable or disable
    public func setProvider(_ providerName: String, enabled: Bool) {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let index = self.providers.firstIndex(where: { $0.name == providerName }) {
                self.providers[index].isEnabled = enabled
                Logger.shared.log("Provider \(providerName) \(enabled ? "enabled" : "disabled")", level: .info, category: .analytics)
            }
        }
    }

    private func updateProvidersState() {
        queue.async { [weak self] in
            guard let self = self else { return }

            if !self.userHasConsentedToAnalytics {
                // Disable all providers except console in debug
                self.providers.forEach { provider in
                    #if DEBUG
                    if provider.name != "Console" {
                        provider.isEnabled = false
                    }
                    #else
                    provider.isEnabled = false
                    #endif
                }
            }
        }
    }

    // MARK: - App Lifecycle

    private func observeAppLifecycle() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        track(.screenViewed(screenName: "app_active", source: nil))
    }

    @objc private func appDidEnterBackground() {
        track(.screenViewed(screenName: "app_background", source: nil))
    }
}

// MARK: - Convenience Extensions

public extension AnalyticsManager {
    /// Track button tap
    func trackButtonTap(_ buttonName: String, screenName: String) {
        track(.buttonTapped(buttonName: buttonName, screenName: screenName))
    }

    /// Track feature usage
    func trackFeature(_ featureName: String, context: String? = nil) {
        track(.featureUsed(featureName: featureName, context: context))
    }

    /// Track error
    func trackError(_ error: Error, context: String, severity: ErrorSeverity = .medium) {
        track(.errorOccurred(
            error: error.localizedDescription,
            context: context,
            severity: severity
        ))
    }
}
