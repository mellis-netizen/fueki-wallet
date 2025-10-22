//
//  WalletError.swift
//  FuekiWallet
//
//  Custom error types for comprehensive error handling
//

import Foundation

/// Base protocol for all wallet errors
protocol WalletErrorProtocol: LocalizedError {
    var errorCode: String { get }
    var errorCategory: ErrorCategory { get }
    var userMessage: String { get }
    var technicalDetails: String? { get }
    var recoverySuggestion: String? { get }
    var underlyingError: Error? { get }
}

/// Error categories for classification
enum ErrorCategory: String, Codable {
    case network = "NETWORK"
    case blockchain = "BLOCKCHAIN"
    case security = "SECURITY"
    case validation = "VALIDATION"
    case persistence = "PERSISTENCE"
    case cryptography = "CRYPTOGRAPHY"
    case transaction = "TRANSACTION"
    case authentication = "AUTHENTICATION"
    case configuration = "CONFIGURATION"
    case unknown = "UNKNOWN"

    var severity: ErrorSeverity {
        switch self {
        case .security, .cryptography, .authentication:
            return .critical
        case .blockchain, .transaction:
            return .high
        case .network, .validation:
            return .medium
        case .persistence, .configuration:
            return .low
        case .unknown:
            return .medium
        }
    }
}

/// Error severity levels
enum ErrorSeverity: String, Codable {
    case critical = "CRITICAL"
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case info = "INFO"
}

// MARK: - Wallet Error Types

/// Network-related errors
enum NetworkError: WalletErrorProtocol {
    case noConnection
    case timeout
    case invalidResponse(statusCode: Int)
    case serverError(message: String)
    case invalidURL
    case requestFailed(Error)
    case rateLimitExceeded
    case sslError

    var errorCode: String {
        switch self {
        case .noConnection: return "NET_001"
        case .timeout: return "NET_002"
        case .invalidResponse: return "NET_003"
        case .serverError: return "NET_004"
        case .invalidURL: return "NET_005"
        case .requestFailed: return "NET_006"
        case .rateLimitExceeded: return "NET_007"
        case .sslError: return "NET_008"
        }
    }

    var errorCategory: ErrorCategory { .network }

    var userMessage: String {
        switch self {
        case .noConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "Request timed out. Please try again."
        case .invalidResponse(let code):
            return "Server returned error code: \(code)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .invalidURL:
            return "Invalid network address"
        case .requestFailed:
            return "Network request failed. Please try again."
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment."
        case .sslError:
            return "Secure connection failed. Please check your settings."
        }
    }

    var technicalDetails: String? {
        switch self {
        case .invalidResponse(let code):
            return "HTTP Status Code: \(code)"
        case .requestFailed(let error):
            return error.localizedDescription
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Enable WiFi or cellular data and try again."
        case .timeout:
            return "Check your connection speed and retry."
        case .rateLimitExceeded:
            return "Wait a few minutes before trying again."
        default:
            return "Try again later or contact support if the problem persists."
        }
    }

    var underlyingError: Error? {
        if case .requestFailed(let error) = self {
            return error
        }
        return nil
    }

    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }
}

/// Blockchain-related errors
enum BlockchainError: WalletErrorProtocol {
    case invalidAddress
    case insufficientBalance
    case gasEstimationFailed
    case transactionFailed(reason: String)
    case invalidChainID
    case contractError(String)
    case nonceMismatch
    case blockNotFound
    case invalidBlock

    var errorCode: String {
        switch self {
        case .invalidAddress: return "BC_001"
        case .insufficientBalance: return "BC_002"
        case .gasEstimationFailed: return "BC_003"
        case .transactionFailed: return "BC_004"
        case .invalidChainID: return "BC_005"
        case .contractError: return "BC_006"
        case .nonceMismatch: return "BC_007"
        case .blockNotFound: return "BC_008"
        case .invalidBlock: return "BC_009"
        }
    }

    var errorCategory: ErrorCategory { .blockchain }

    var userMessage: String {
        switch self {
        case .invalidAddress:
            return "Invalid wallet address"
        case .insufficientBalance:
            return "Insufficient balance for this transaction"
        case .gasEstimationFailed:
            return "Unable to estimate transaction fee"
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        case .invalidChainID:
            return "Invalid blockchain network"
        case .contractError(let msg):
            return "Smart contract error: \(msg)"
        case .nonceMismatch:
            return "Transaction sequence error"
        case .blockNotFound:
            return "Block data not found"
        case .invalidBlock:
            return "Invalid block data"
        }
    }

    var technicalDetails: String? {
        switch self {
        case .transactionFailed(let reason):
            return reason
        case .contractError(let msg):
            return msg
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidAddress:
            return "Check the address format and try again."
        case .insufficientBalance:
            return "Add funds to your wallet or reduce transaction amount."
        case .gasEstimationFailed:
            return "Try adjusting gas settings manually."
        default:
            return "Contact support if the issue persists."
        }
    }

    var underlyingError: Error? { nil }
    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }
}

/// Security and cryptography errors
enum SecurityError: WalletErrorProtocol {
    case biometricAuthFailed
    case biometricNotAvailable
    case pinAuthFailed(attemptsRemaining: Int)
    case accountLocked
    case keychainError(OSStatus)
    case encryptionFailed
    case decryptionFailed
    case invalidSignature
    case privateKeyNotFound
    case seedPhraseInvalid
    case derivationFailed

    var errorCode: String {
        switch self {
        case .biometricAuthFailed: return "SEC_001"
        case .biometricNotAvailable: return "SEC_002"
        case .pinAuthFailed: return "SEC_003"
        case .accountLocked: return "SEC_004"
        case .keychainError: return "SEC_005"
        case .encryptionFailed: return "SEC_006"
        case .decryptionFailed: return "SEC_007"
        case .invalidSignature: return "SEC_008"
        case .privateKeyNotFound: return "SEC_009"
        case .seedPhraseInvalid: return "SEC_010"
        case .derivationFailed: return "SEC_011"
        }
    }

    var errorCategory: ErrorCategory { .security }

    var userMessage: String {
        switch self {
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        case .biometricNotAvailable:
            return "Biometric authentication not available on this device"
        case .pinAuthFailed(let attempts):
            return "Incorrect PIN. \(attempts) attempts remaining."
        case .accountLocked:
            return "Account locked due to too many failed attempts"
        case .keychainError(let status):
            return "Secure storage error: \(status)"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .invalidSignature:
            return "Invalid cryptographic signature"
        case .privateKeyNotFound:
            return "Private key not found"
        case .seedPhraseInvalid:
            return "Invalid recovery phrase"
        case .derivationFailed:
            return "Key derivation failed"
        }
    }

    var technicalDetails: String? {
        switch self {
        case .keychainError(let status):
            return "OSStatus: \(status)"
        case .pinAuthFailed(let attempts):
            return "Attempts remaining: \(attempts)"
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .biometricAuthFailed:
            return "Try again or use PIN authentication."
        case .biometricNotAvailable:
            return "Set up Face ID or Touch ID in Settings."
        case .pinAuthFailed(let attempts):
            return attempts > 0 ? "Double-check your PIN and try again." : "Contact support to unlock your account."
        case .accountLocked:
            return "Wait 15 minutes or use recovery options."
        case .seedPhraseInvalid:
            return "Check your recovery phrase for typos."
        default:
            return "Contact support for assistance."
        }
    }

    var underlyingError: Error? { nil }
    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }
}

/// Validation errors
enum ValidationError: WalletErrorProtocol {
    case invalidInput(field: String, reason: String)
    case requiredFieldMissing(field: String)
    case formatError(field: String, expectedFormat: String)
    case outOfRange(field: String, min: Any?, max: Any?)
    case duplicateEntry(field: String)

    var errorCode: String {
        switch self {
        case .invalidInput: return "VAL_001"
        case .requiredFieldMissing: return "VAL_002"
        case .formatError: return "VAL_003"
        case .outOfRange: return "VAL_004"
        case .duplicateEntry: return "VAL_005"
        }
    }

    var errorCategory: ErrorCategory { .validation }

    var userMessage: String {
        switch self {
        case .invalidInput(let field, let reason):
            return "Invalid \(field): \(reason)"
        case .requiredFieldMissing(let field):
            return "\(field) is required"
        case .formatError(let field, let format):
            return "\(field) must be in \(format) format"
        case .outOfRange(let field, _, _):
            return "\(field) is out of valid range"
        case .duplicateEntry(let field):
            return "\(field) already exists"
        }
    }

    var technicalDetails: String? {
        switch self {
        case .outOfRange(_, let min, let max):
            return "Range: \(String(describing: min)) - \(String(describing: max))"
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        "Please correct the input and try again."
    }

    var underlyingError: Error? { nil }
    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }
}

/// Persistence errors
enum PersistenceError: WalletErrorProtocol {
    case databaseError(String)
    case migrationFailed
    case corruptedData
    case notFound(entity: String)
    case saveFailed
    case deleteFailed
    case fetchFailed

    var errorCode: String {
        switch self {
        case .databaseError: return "PER_001"
        case .migrationFailed: return "PER_002"
        case .corruptedData: return "PER_003"
        case .notFound: return "PER_004"
        case .saveFailed: return "PER_005"
        case .deleteFailed: return "PER_006"
        case .fetchFailed: return "PER_007"
        }
    }

    var errorCategory: ErrorCategory { .persistence }

    var userMessage: String {
        switch self {
        case .databaseError(let msg):
            return "Database error: \(msg)"
        case .migrationFailed:
            return "Failed to update wallet data"
        case .corruptedData:
            return "Data corruption detected"
        case .notFound(let entity):
            return "\(entity) not found"
        case .saveFailed:
            return "Failed to save data"
        case .deleteFailed:
            return "Failed to delete data"
        case .fetchFailed:
            return "Failed to retrieve data"
        }
    }

    var technicalDetails: String? {
        switch self {
        case .databaseError(let msg):
            return msg
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .corruptedData:
            return "You may need to restore from backup."
        case .migrationFailed:
            return "Reinstall the app or restore from backup."
        default:
            return "Try again or contact support."
        }
    }

    var underlyingError: Error? { nil }
    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }
}

/// Transaction errors
enum TransactionError: WalletErrorProtocol {
    case invalidAmount
    case invalidRecipient
    case feeTooHigh
    case transactionPending
    case transactionRejected(reason: String)
    case signatureFailed
    case broadcastFailed

    var errorCode: String {
        switch self {
        case .invalidAmount: return "TXN_001"
        case .invalidRecipient: return "TXN_002"
        case .feeTooHigh: return "TXN_003"
        case .transactionPending: return "TXN_004"
        case .transactionRejected: return "TXN_005"
        case .signatureFailed: return "TXN_006"
        case .broadcastFailed: return "TXN_007"
        }
    }

    var errorCategory: ErrorCategory { .transaction }

    var userMessage: String {
        switch self {
        case .invalidAmount:
            return "Invalid transaction amount"
        case .invalidRecipient:
            return "Invalid recipient address"
        case .feeTooHigh:
            return "Transaction fee is unusually high"
        case .transactionPending:
            return "Previous transaction still pending"
        case .transactionRejected(let reason):
            return "Transaction rejected: \(reason)"
        case .signatureFailed:
            return "Failed to sign transaction"
        case .broadcastFailed:
            return "Failed to broadcast transaction"
        }
    }

    var technicalDetails: String? {
        switch self {
        case .transactionRejected(let reason):
            return reason
        default:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidAmount:
            return "Enter a valid amount greater than zero."
        case .invalidRecipient:
            return "Check the recipient address and try again."
        case .feeTooHigh:
            return "Review the fee and adjust gas settings."
        case .transactionPending:
            return "Wait for the previous transaction to complete."
        default:
            return "Try again or contact support."
        }
    }

    var underlyingError: Error? { nil }
    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }
}

/// Generic wallet error wrapper
struct WalletError: WalletErrorProtocol {
    let errorCode: String
    let errorCategory: ErrorCategory
    let userMessage: String
    let technicalDetails: String?
    let recoverySuggestion: String?
    let underlyingError: Error?

    var errorDescription: String? { userMessage }
    var failureReason: String? { technicalDetails }
    var recoverySuggestionString: String? { recoverySuggestion }

    init(
        code: String,
        category: ErrorCategory,
        userMessage: String,
        technicalDetails: String? = nil,
        recoverySuggestion: String? = nil,
        underlyingError: Error? = nil
    ) {
        self.errorCode = code
        self.errorCategory = category
        self.userMessage = userMessage
        self.technicalDetails = technicalDetails
        self.recoverySuggestion = recoverySuggestion
        self.underlyingError = underlyingError
    }

    static func wrap(_ error: Error) -> WalletError {
        if let walletError = error as? WalletErrorProtocol {
            return WalletError(
                code: walletError.errorCode,
                category: walletError.errorCategory,
                userMessage: walletError.userMessage,
                technicalDetails: walletError.technicalDetails,
                recoverySuggestion: walletError.recoverySuggestion,
                underlyingError: walletError.underlyingError
            )
        }

        return WalletError(
            code: "ERR_999",
            category: .unknown,
            userMessage: "An unexpected error occurred",
            technicalDetails: error.localizedDescription,
            recoverySuggestion: "Please try again or contact support",
            underlyingError: error
        )
    }
}
