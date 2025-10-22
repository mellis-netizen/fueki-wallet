import Foundation

/// Analytics event definitions for the Fueki Wallet
public enum AnalyticsEvent {
    // MARK: - Wallet Events
    case walletCreated(type: WalletType)
    case walletImported(type: WalletType, method: ImportMethod)
    case walletDeleted(walletId: String)
    case walletBackedUp(walletId: String)
    case walletRestored(walletId: String)
    case walletSwitched(fromWalletId: String, toWalletId: String)

    // MARK: - Transaction Events
    case transactionInitiated(amount: String, currency: String, type: TransactionType)
    case transactionSigned(transactionId: String)
    case transactionBroadcast(transactionId: String)
    case transactionCompleted(transactionId: String, status: TransactionStatus)
    case transactionFailed(transactionId: String, error: String)

    // MARK: - Screen Events
    case screenViewed(screenName: String, source: String?)
    case screenDismissed(screenName: String, duration: TimeInterval)

    // MARK: - User Actions
    case buttonTapped(buttonName: String, screenName: String)
    case featureUsed(featureName: String, context: String?)
    case settingChanged(settingName: String, newValue: String)
    case searchPerformed(query: String, resultsCount: Int)

    // MARK: - Security Events
    case biometricAuthenticationAttempted(success: Bool)
    case pinCodeAttempted(success: Bool)
    case sessionExpired
    case securityLockEnabled
    case securityLockDisabled

    // MARK: - Error Events
    case errorOccurred(error: String, context: String, severity: ErrorSeverity)
    case networkError(endpoint: String, statusCode: Int?)
    case validationError(field: String, reason: String)

    // MARK: - Performance Events
    case performanceMetric(name: String, duration: TimeInterval, metadata: [String: Any]?)
    case apiCallCompleted(endpoint: String, duration: TimeInterval, success: Bool)

    // MARK: - Blockchain Events
    case blockchainConnected(network: String)
    case blockchainDisconnected(network: String)
    case gasEstimated(amount: String)
    case contractInteraction(contractAddress: String, method: String)

    public var name: String {
        switch self {
        case .walletCreated: return "wallet_created"
        case .walletImported: return "wallet_imported"
        case .walletDeleted: return "wallet_deleted"
        case .walletBackedUp: return "wallet_backed_up"
        case .walletRestored: return "wallet_restored"
        case .walletSwitched: return "wallet_switched"
        case .transactionInitiated: return "transaction_initiated"
        case .transactionSigned: return "transaction_signed"
        case .transactionBroadcast: return "transaction_broadcast"
        case .transactionCompleted: return "transaction_completed"
        case .transactionFailed: return "transaction_failed"
        case .screenViewed: return "screen_viewed"
        case .screenDismissed: return "screen_dismissed"
        case .buttonTapped: return "button_tapped"
        case .featureUsed: return "feature_used"
        case .settingChanged: return "setting_changed"
        case .searchPerformed: return "search_performed"
        case .biometricAuthenticationAttempted: return "biometric_auth_attempted"
        case .pinCodeAttempted: return "pin_code_attempted"
        case .sessionExpired: return "session_expired"
        case .securityLockEnabled: return "security_lock_enabled"
        case .securityLockDisabled: return "security_lock_disabled"
        case .errorOccurred: return "error_occurred"
        case .networkError: return "network_error"
        case .validationError: return "validation_error"
        case .performanceMetric: return "performance_metric"
        case .apiCallCompleted: return "api_call_completed"
        case .blockchainConnected: return "blockchain_connected"
        case .blockchainDisconnected: return "blockchain_disconnected"
        case .gasEstimated: return "gas_estimated"
        case .contractInteraction: return "contract_interaction"
        }
    }

    public var parameters: [String: Any] {
        var params: [String: Any] = [:]

        switch self {
        case .walletCreated(let type):
            params["wallet_type"] = type.rawValue

        case .walletImported(let type, let method):
            params["wallet_type"] = type.rawValue
            params["import_method"] = method.rawValue

        case .walletDeleted(let walletId):
            params["wallet_id"] = walletId.hashValue // Hash for privacy

        case .walletBackedUp(let walletId):
            params["wallet_id"] = walletId.hashValue

        case .walletRestored(let walletId):
            params["wallet_id"] = walletId.hashValue

        case .walletSwitched(let fromWalletId, let toWalletId):
            params["from_wallet_id"] = fromWalletId.hashValue
            params["to_wallet_id"] = toWalletId.hashValue

        case .transactionInitiated(let amount, let currency, let type):
            params["currency"] = currency
            params["transaction_type"] = type.rawValue
            // Don't log actual amount for privacy
            params["has_amount"] = !amount.isEmpty

        case .transactionSigned(let transactionId):
            params["transaction_id"] = transactionId.hashValue

        case .transactionBroadcast(let transactionId):
            params["transaction_id"] = transactionId.hashValue

        case .transactionCompleted(let transactionId, let status):
            params["transaction_id"] = transactionId.hashValue
            params["status"] = status.rawValue

        case .transactionFailed(let transactionId, let error):
            params["transaction_id"] = transactionId.hashValue
            params["error"] = error

        case .screenViewed(let screenName, let source):
            params["screen_name"] = screenName
            if let source = source {
                params["source"] = source
            }

        case .screenDismissed(let screenName, let duration):
            params["screen_name"] = screenName
            params["duration"] = duration

        case .buttonTapped(let buttonName, let screenName):
            params["button_name"] = buttonName
            params["screen_name"] = screenName

        case .featureUsed(let featureName, let context):
            params["feature_name"] = featureName
            if let context = context {
                params["context"] = context
            }

        case .settingChanged(let settingName, let newValue):
            params["setting_name"] = settingName
            params["new_value"] = newValue

        case .searchPerformed(let query, let resultsCount):
            params["query_length"] = query.count // Don't log actual query
            params["results_count"] = resultsCount

        case .biometricAuthenticationAttempted(let success):
            params["success"] = success

        case .pinCodeAttempted(let success):
            params["success"] = success

        case .sessionExpired:
            break

        case .securityLockEnabled:
            break

        case .securityLockDisabled:
            break

        case .errorOccurred(let error, let context, let severity):
            params["error"] = error
            params["context"] = context
            params["severity"] = severity.rawValue

        case .networkError(let endpoint, let statusCode):
            params["endpoint"] = endpoint
            if let statusCode = statusCode {
                params["status_code"] = statusCode
            }

        case .validationError(let field, let reason):
            params["field"] = field
            params["reason"] = reason

        case .performanceMetric(let name, let duration, let metadata):
            params["metric_name"] = name
            params["duration"] = duration
            if let metadata = metadata {
                params.merge(metadata) { _, new in new }
            }

        case .apiCallCompleted(let endpoint, let duration, let success):
            params["endpoint"] = endpoint
            params["duration"] = duration
            params["success"] = success

        case .blockchainConnected(let network):
            params["network"] = network

        case .blockchainDisconnected(let network):
            params["network"] = network

        case .gasEstimated(let amount):
            params["gas_amount"] = amount

        case .contractInteraction(let contractAddress, let method):
            params["contract_address"] = contractAddress
            params["method"] = method
        }

        return params
    }
}

// MARK: - Supporting Types

public enum WalletType: String {
    case hd = "HD"
    case imported = "Imported"
    case watchOnly = "WatchOnly"
}

public enum ImportMethod: String {
    case privateKey = "PrivateKey"
    case seedPhrase = "SeedPhrase"
    case qrCode = "QRCode"
    case file = "File"
}

public enum TransactionType: String {
    case send = "Send"
    case receive = "Receive"
    case swap = "Swap"
    case contractCall = "ContractCall"
}

public enum TransactionStatus: String {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case failed = "Failed"
    case cancelled = "Cancelled"
}

public enum ErrorSeverity: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}
