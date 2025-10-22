//
//  PaymentModels.swift
//  Fueki Wallet
//
//  Data models for payment ramp integration
//

import Foundation

// MARK: - Payment Provider
enum PaymentProvider: String, Codable {
    case rampNetwork = "ramp_network"
    case moonPay = "moonpay"

    var displayName: String {
        switch self {
        case .rampNetwork: return "Ramp Network"
        case .moonPay: return "MoonPay"
        }
    }

    var feeRange: String {
        switch self {
        case .rampNetwork: return "0.49% - 2.9%"
        case .moonPay: return "1% - 4.5%"
        }
    }
}

// MARK: - Transaction Type
enum TransactionType: String, Codable {
    case purchase
    case sale
}

// MARK: - Purchase Request
struct PurchaseRequest: Codable {
    let cryptocurrency: String
    let fiatCurrency: String
    let fiatAmount: Decimal
    let walletAddress: String
    let paymentMethod: PaymentMethod
    let network: String
    let userCountry: String
    let timestamp: Date

    init(
        cryptocurrency: String,
        fiatCurrency: String,
        fiatAmount: Decimal,
        walletAddress: String,
        paymentMethod: PaymentMethod,
        network: String,
        userCountry: String
    ) {
        self.cryptocurrency = cryptocurrency
        self.fiatCurrency = fiatCurrency
        self.fiatAmount = fiatAmount
        self.walletAddress = walletAddress
        self.paymentMethod = paymentMethod
        self.network = network
        self.userCountry = userCountry
        self.timestamp = Date()
    }
}

// MARK: - Purchase Response
struct PurchaseResponse: Codable {
    let transactionId: String
    let status: TransactionStatus
    let redirectURL: URL?
    let estimatedCryptoAmount: Decimal
    let totalFee: Decimal
    let estimatedArrival: Date?
    let provider: PaymentProvider
}

// MARK: - Sale Request
struct SaleRequest: Codable {
    let cryptocurrency: String
    let cryptoAmount: Decimal
    let fiatCurrency: String
    let bankAccount: BankAccount
    let network: String
    let userCountry: String
    let timestamp: Date

    init(
        cryptocurrency: String,
        cryptoAmount: Decimal,
        fiatCurrency: String,
        bankAccount: BankAccount,
        network: String,
        userCountry: String
    ) {
        self.cryptocurrency = cryptocurrency
        self.cryptoAmount = cryptoAmount
        self.fiatCurrency = fiatCurrency
        self.bankAccount = bankAccount
        self.network = network
        self.userCountry = userCountry
        self.timestamp = Date()
    }
}

// MARK: - Sale Response
struct SaleResponse: Codable {
    let transactionId: String
    let status: TransactionStatus
    let estimatedFiatAmount: Decimal
    let totalFee: Decimal
    let estimatedArrival: Date
    let provider: PaymentProvider
}

// MARK: - Quote Request
struct QuoteRequest: Codable {
    let type: TransactionType
    let cryptocurrency: String
    let fiatCurrency: String
    let amount: Decimal
    let paymentMethod: PaymentMethod?
    let network: String
}

// MARK: - Quote Response
struct QuoteResponse: Codable {
    let cryptocurrency: String
    let fiatCurrency: String
    let cryptoAmount: Decimal?
    let fiatAmount: Decimal
    let exchangeRate: Decimal
    let fees: FeeBreakdown
    let total: Decimal
    let expiresAt: Date
    let provider: PaymentProvider
}

// MARK: - Fee Breakdown
struct FeeBreakdown: Codable {
    let providerFee: Decimal
    let providerFeePercentage: Decimal
    let networkFee: Decimal
    let processingFee: Decimal
    let totalFee: Decimal

    var breakdown: String {
        """
        Provider Fee: \(providerFeePercentage)% ($\(providerFee))
        Network Fee: $\(networkFee)
        Processing Fee: $\(processingFee)
        Total: $\(totalFee)
        """
    }
}

// MARK: - Transaction Status
struct TransactionStatus: Codable {
    let transactionId: String
    let status: Status
    let cryptocurrency: String?
    let amount: Decimal?
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let failureReason: String?

    enum Status: String, Codable {
        case pending
        case processing
        case waitingForPayment = "waiting_payment"
        case paymentReceived = "payment_received"
        case completed
        case failed
        case cancelled
        case expired

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .processing: return "Processing"
            case .waitingForPayment: return "Waiting for Payment"
            case .paymentReceived: return "Payment Received"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .cancelled: return "Cancelled"
            case .expired: return "Expired"
            }
        }

        var isProcessing: Bool {
            switch self {
            case .pending, .processing, .waitingForPayment, .paymentReceived:
                return true
            default:
                return false
            }
        }
    }

    var isFinal: Bool {
        switch status {
        case .completed, .failed, .cancelled, .expired:
            return true
        default:
            return false
        }
    }

    var isSuccess: Bool {
        return status == .completed
    }
}

// MARK: - Payment Method
struct PaymentMethod: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let fee: Decimal
    let feePercentage: Decimal
    let processingTime: String
    let limits: PaymentLimits
    let isAvailable: Bool

    static let creditCard = PaymentMethod(
        id: "credit_card",
        name: "Credit/Debit Card",
        description: "Instant purchase with card",
        icon: "creditcard.fill",
        fee: 0,
        feePercentage: 2.9,
        processingTime: "5-15 minutes",
        limits: PaymentLimits(min: 10, max: 10000),
        isAvailable: true
    )

    static let bankTransfer = PaymentMethod(
        id: "bank_transfer",
        name: "Bank Transfer",
        description: "Lower fees, 1-3 days",
        icon: "building.columns.fill",
        fee: 0,
        feePercentage: 0.49,
        processingTime: "1-3 business days",
        limits: PaymentLimits(min: 50, max: 50000),
        isAvailable: true
    )

    static let applePay = PaymentMethod(
        id: "apple_pay",
        name: "Apple Pay",
        description: "Quick checkout with Apple Pay",
        icon: "applelogo",
        fee: 0,
        feePercentage: 2.9,
        processingTime: "5-15 minutes",
        limits: PaymentLimits(min: 10, max: 5000),
        isAvailable: true
    )
}

// MARK: - Payment Limits
struct PaymentLimits: Codable, Equatable {
    let min: Decimal
    let max: Decimal
}

// MARK: - Bank Account
struct BankAccount: Identifiable, Codable, Equatable {
    let id: String
    let bankName: String
    let accountType: AccountType
    let lastFourDigits: String
    let routingNumber: String?
    let isVerified: Bool

    enum AccountType: String, Codable {
        case checking
        case savings

        var displayName: String {
            rawValue.capitalized
        }
    }
}

// MARK: - Supported Cryptocurrency
struct SupportedCryptocurrency: Codable, Identifiable {
    let id: String
    let symbol: String
    let name: String
    let networks: [String]
    let minPurchaseAmount: Decimal
    let maxPurchaseAmount: Decimal
    let icon: String
    let isAvailable: Bool
}

// MARK: - Payment Method Info
struct PaymentMethodInfo: Codable, Identifiable {
    let id: String
    let type: String
    let name: String
    let description: String
    let fee: Decimal
    let feePercentage: Decimal
    let processingTime: String
    let limits: PaymentLimits
    let supportedCountries: [String]
}

// MARK: - KYC Status
struct KYCStatus: Codable {
    let tier: KYCTier
    let isVerified: Bool
    let limits: KYCLimits
    let verificationURL: URL?
    let requiredDocuments: [String]?
    let rejectionReason: String?

    enum KYCTier: Int, Codable {
        case tier1 = 1
        case tier2 = 2
        case tier3 = 3

        var displayName: String {
            switch self {
            case .tier1: return "Basic"
            case .tier2: return "Standard"
            case .tier3: return "Enhanced"
            }
        }

        var maxDailyLimit: Decimal {
            switch self {
            case .tier1: return 200
            case .tier2: return 2000
            case .tier3: return 50000
            }
        }
    }
}

// MARK: - KYC Limits
struct KYCLimits: Codable {
    let daily: Decimal
    let weekly: Decimal
    let monthly: Decimal
}

// MARK: - KYC Verification URL
struct KYCVerificationURL: Codable {
    let url: URL
    let sessionId: String
    let expiresAt: Date
}

// MARK: - Payment Error
enum PaymentError: LocalizedError {
    case invalidAmount(String)
    case invalidWalletAddress
    case kycRequired
    case kycPending
    case kycRejected(String)
    case providerError(String)
    case networkError(Error)
    case insufficientFunds
    case transactionFailed(String)
    case timeout
    case unsupportedCountry
    case unsupportedCryptocurrency
    case rateLimited
    case unknownError

    var errorDescription: String? {
        switch self {
        case .invalidAmount(let message):
            return message
        case .invalidWalletAddress:
            return "Invalid wallet address format"
        case .kycRequired:
            return "Identity verification required to continue"
        case .kycPending:
            return "Identity verification is pending review"
        case .kycRejected(let reason):
            return "Identity verification rejected: \(reason)"
        case .providerError(let message):
            return "Payment provider error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .insufficientFunds:
            return "Insufficient funds for this transaction"
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        case .timeout:
            return "Request timed out. Please try again."
        case .unsupportedCountry:
            return "Service not available in your country"
        case .unsupportedCryptocurrency:
            return "This cryptocurrency is not supported"
        case .rateLimited:
            return "Too many requests. Please wait and try again."
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Webhook Event
struct WebhookEvent: Codable {
    let eventId: String
    let eventType: EventType
    let transactionId: String
    let status: TransactionStatus.Status
    let timestamp: Date
    let data: [String: String]?

    enum EventType: String, Codable {
        case transactionCreated = "transaction.created"
        case transactionUpdated = "transaction.updated"
        case transactionCompleted = "transaction.completed"
        case transactionFailed = "transaction.failed"
        case kycUpdated = "kyc.updated"
        case paymentReceived = "payment.received"
    }
}
