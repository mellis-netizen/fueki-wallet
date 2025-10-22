//
//  AnalyticsMiddleware.swift
//  FuekiWallet
//
//  Middleware for analytics tracking and reporting
//

import Foundation
import Combine

// MARK: - Analytics Middleware
func analyticsMiddleware(state: AppState, action: Action) -> AnyPublisher<Action, Never>? {
    // Track action in analytics
    trackAction(action, state: state)

    // No new actions dispatched
    return nil
}

// MARK: - Action Tracking
private func trackAction(_ action: Action, state: AppState) {
    let actionType = String(describing: type(of: action))
    let timestamp = Date()

    // Create analytics event
    let event = AnalyticsEvent(
        type: actionType,
        timestamp: timestamp,
        properties: extractProperties(from: action, state: state)
    )

    // Send to analytics service
    AnalyticsService.shared.track(event)
}

// MARK: - Property Extraction
private func extractProperties(from action: Action, state: AppState) -> [String: Any] {
    var properties: [String: Any] = [:]

    // Add common properties
    properties["user_authenticated"] = state.auth.isAuthenticated
    properties["accounts_count"] = state.wallet.accounts.count
    properties["network"] = state.settings.network.rawValue

    // Extract action-specific properties
    switch action {

    // Wallet Actions
    case let action as WalletAction:
        properties.merge(walletActionProperties(action)) { _, new in new }

    // Transaction Actions
    case let action as TransactionAction:
        properties.merge(transactionActionProperties(action)) { _, new in new }

    // Settings Actions
    case let action as SettingsAction:
        properties.merge(settingsActionProperties(action)) { _, new in new }

    // Auth Actions
    case let action as AuthAction:
        properties.merge(authActionProperties(action)) { _, new in new }

    default:
        break
    }

    return properties
}

// MARK: - Wallet Action Properties
private func walletActionProperties(_ action: WalletAction) -> [String: Any] {
    var properties: [String: Any] = [:]

    switch action {
    case .createAccount(let name):
        properties["account_name"] = name

    case .accountCreated(let account):
        properties["account_id"] = account.id
        properties["account_name"] = account.name

    case .selectAccount(let id):
        properties["account_id"] = id

    case .balanceFetched(let balance):
        properties["balance_amount"] = balance.amount
        properties["balance_currency"] = balance.currency.rawValue

    case .syncCompleted(let timestamp):
        properties["sync_timestamp"] = timestamp.timeIntervalSince1970

    case .syncFailed(let error):
        properties["error_code"] = error.code
        properties["error_message"] = error.message

    default:
        break
    }

    return properties
}

// MARK: - Transaction Action Properties
private func transactionActionProperties(_ action: TransactionAction) -> [String: Any] {
    var properties: [String: Any] = [:]

    switch action {
    case .createTransaction(let type, let amount, let to, let memo):
        properties["transaction_type"] = type.rawValue
        properties["amount"] = amount
        properties["to_address"] = to
        properties["has_memo"] = memo != nil

    case .transactionCreated(let transaction):
        properties["transaction_id"] = transaction.id
        properties["transaction_type"] = transaction.type.rawValue
        properties["amount"] = transaction.amount

    case .transactionSent(let transaction):
        properties["transaction_id"] = transaction.id
        properties["transaction_hash"] = transaction.hash ?? ""

    case .updateTransaction(let id, let status):
        properties["transaction_id"] = id
        properties["status"] = status.rawValue

    case .setFilter(let filter):
        properties["filter"] = filter.rawValue

    default:
        break
    }

    return properties
}

// MARK: - Settings Action Properties
private func settingsActionProperties(_ action: SettingsAction) -> [String: Any] {
    var properties: [String: Any] = [:]

    switch action {
    case .setCurrency(let currency):
        properties["currency"] = currency.rawValue

    case .setLanguage(let language):
        properties["language"] = language.rawValue

    case .setTheme(let theme):
        properties["theme"] = theme.rawValue

    case .biometricChanged(let enabled):
        properties["biometric_enabled"] = enabled

    case .setNetwork(let network):
        properties["network"] = network.rawValue

    default:
        break
    }

    return properties
}

// MARK: - Auth Action Properties
private func authActionProperties(_ action: AuthAction) -> [String: Any] {
    var properties: [String: Any] = [:]

    switch action {
    case .authenticate(let method):
        properties["auth_method"] = method.rawValue

    case .authenticationSucceeded(let method, _):
        properties["auth_method"] = method.rawValue
        properties["success"] = true

    case .authenticationFailed(let error):
        properties["error_code"] = error.code
        properties["error_message"] = error.message
        properties["success"] = false

    case .setBiometricType(let type):
        properties["biometric_type"] = type.rawValue

    default:
        break
    }

    return properties
}

// MARK: - Analytics Event
struct AnalyticsEvent {
    let type: String
    let timestamp: Date
    let properties: [String: Any]

    var dictionary: [String: Any] {
        var dict = properties
        dict["event_type"] = type
        dict["timestamp"] = timestamp.timeIntervalSince1970
        return dict
    }
}

// MARK: - Analytics Service
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var events: [AnalyticsEvent] = []
    private let queue = DispatchQueue(label: "io.fueki.wallet.analytics", qos: .utility)

    private init() {}

    func track(_ event: AnalyticsEvent) {
        queue.async {
            self.events.append(event)
            self.sendEvent(event)
        }
    }

    private func sendEvent(_ event: AnalyticsEvent) {
        #if DEBUG
        print("📊 Analytics Event: \(event.type)")
        print("   Properties: \(event.properties)")
        #endif

        // TODO: Send to actual analytics backend
        // Examples: Firebase, Mixpanel, Amplitude, etc.
    }

    func getEvents() -> [AnalyticsEvent] {
        queue.sync {
            events
        }
    }

    func clearEvents() {
        queue.async {
            self.events.removeAll()
        }
    }
}
