import Foundation

/// Protocol for analytics providers
public protocol AnalyticsProvider {
    /// Provider name
    var name: String { get }

    /// Enable or disable the provider
    var isEnabled: Bool { get set }

    /// Initialize the analytics provider
    func initialize()

    /// Track an event
    /// - Parameters:
    ///   - event: The event to track
    ///   - properties: Additional properties for the event
    func trackEvent(_ event: AnalyticsEvent, properties: [String: Any]?)

    /// Set user property
    /// - Parameters:
    ///   - property: Property name
    ///   - value: Property value
    func setUserProperty(_ property: String, value: String)

    /// Set user ID
    /// - Parameter userId: User identifier (anonymized)
    func setUserId(_ userId: String?)

    /// Track screen view
    /// - Parameters:
    ///   - screenName: Name of the screen
    ///   - screenClass: Class of the screen
    func trackScreen(_ screenName: String, screenClass: String?)

    /// Track timing
    /// - Parameters:
    ///   - category: Timing category
    ///   - name: Timing name
    ///   - duration: Duration in milliseconds
    func trackTiming(category: String, name: String, duration: TimeInterval)

    /// Reset user data (for logout/privacy)
    func resetUserData()
}

/// Console analytics provider for development
public class ConsoleAnalyticsProvider: AnalyticsProvider {
    public var name: String { "Console" }
    public var isEnabled: Bool = true

    public init() {}

    public func initialize() {
        print("📊 [Analytics] Console provider initialized")
    }

    public func trackEvent(_ event: AnalyticsEvent, properties: [String: Any]?) {
        var message = "📊 [Event] \(event.name)"

        var allProperties = event.parameters
        if let properties = properties {
            allProperties.merge(properties) { _, new in new }
        }

        if !allProperties.isEmpty {
            message += " - \(allProperties)"
        }

        print(message)
    }

    public func setUserProperty(_ property: String, value: String) {
        print("📊 [UserProperty] \(property) = \(value)")
    }

    public func setUserId(_ userId: String?) {
        if let userId = userId {
            print("📊 [UserId] Set to: \(userId)")
        } else {
            print("📊 [UserId] Cleared")
        }
    }

    public func trackScreen(_ screenName: String, screenClass: String?) {
        if let screenClass = screenClass {
            print("📊 [Screen] \(screenName) (\(screenClass))")
        } else {
            print("📊 [Screen] \(screenName)")
        }
    }

    public func trackTiming(category: String, name: String, duration: TimeInterval) {
        print("📊 [Timing] \(category).\(name): \(duration)ms")
    }

    public func resetUserData() {
        print("📊 [Analytics] User data reset")
    }
}

/// Firebase Analytics provider (to be implemented when Firebase is integrated)
public class FirebaseAnalyticsProvider: AnalyticsProvider {
    public var name: String { "Firebase" }
    public var isEnabled: Bool = false // Disabled until Firebase is configured

    public init() {}

    public func initialize() {
        // TODO: Initialize Firebase Analytics
        // FirebaseApp.configure()
        print("📊 [Analytics] Firebase provider ready (not configured)")
    }

    public func trackEvent(_ event: AnalyticsEvent, properties: [String: Any]?) {
        guard isEnabled else { return }

        var allProperties = event.parameters
        if let properties = properties {
            allProperties.merge(properties) { _, new in new }
        }

        // TODO: Log to Firebase
        // Analytics.logEvent(event.name, parameters: allProperties)
    }

    public func setUserProperty(_ property: String, value: String) {
        guard isEnabled else { return }
        // TODO: Set Firebase user property
        // Analytics.setUserProperty(value, forName: property)
    }

    public func setUserId(_ userId: String?) {
        guard isEnabled else { return }
        // TODO: Set Firebase user ID
        // Analytics.setUserID(userId)
    }

    public func trackScreen(_ screenName: String, screenClass: String?) {
        guard isEnabled else { return }
        // TODO: Log screen view to Firebase
        // Analytics.logEvent(AnalyticsEventScreenView, parameters: [
        //     AnalyticsParameterScreenName: screenName,
        //     AnalyticsParameterScreenClass: screenClass ?? ""
        // ])
    }

    public func trackTiming(category: String, name: String, duration: TimeInterval) {
        guard isEnabled else { return }
        // TODO: Log timing to Firebase
        // Analytics.logEvent("timing_\(category)", parameters: [
        //     "name": name,
        //     "duration": duration
        // ])
    }

    public func resetUserData() {
        guard isEnabled else { return }
        // TODO: Reset Firebase user data
        // Analytics.resetAnalyticsData()
    }
}
