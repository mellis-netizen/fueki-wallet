//
//  FraudDetectionService.swift
//  Fueki Wallet
//
//  Fraud detection and risk management for payment transactions
//

import Foundation

/// Service for fraud detection and transaction risk assessment
class FraudDetectionService {

    static let shared = FraudDetectionService()

    // MARK: - Risk Thresholds
    private let maxDailyTransactionCount = 10
    private let maxDailyTransactionAmount: Decimal = 10000
    private let suspiciousAmountThreshold: Decimal = 5000
    private let velocityCheckPeriod: TimeInterval = 3600 // 1 hour
    private let maxVelocityTransactions = 3

    // MARK: - Transaction History
    private var transactionHistory: [TransactionRecord] = []

    // MARK: - Risk Assessment

    /// Assess risk for a purchase transaction
    func assessPurchaseRisk(
        amount: Decimal,
        asset: CryptoAsset,
        userCountry: String,
        paymentMethod: PaymentMethod
    ) async -> RiskAssessment {
        var riskFactors: [RiskFactor] = []
        var riskScore: Int = 0

        // 1. Amount-based risk
        if amount > suspiciousAmountThreshold {
            riskFactors.append(.highAmount)
            riskScore += 30
        }

        // 2. Velocity check
        let recentTransactions = getRecentTransactions(within: velocityCheckPeriod)
        if recentTransactions.count >= maxVelocityTransactions {
            riskFactors.append(.highVelocity)
            riskScore += 40
        }

        // 3. Daily limits
        let todayTransactions = getTodayTransactions()
        let todayTotal = todayTransactions.reduce(Decimal(0)) { $0 + $1.amount }

        if todayTotal + amount > maxDailyTransactionAmount {
            riskFactors.append(.dailyLimitExceeded)
            riskScore += 50
        }

        if todayTransactions.count >= maxDailyTransactionCount {
            riskFactors.append(.transactionCountExceeded)
            riskScore += 40
        }

        // 4. Geographic risk
        if isHighRiskCountry(userCountry) {
            riskFactors.append(.highRiskCountry)
            riskScore += 20
        }

        // 5. Payment method risk
        if paymentMethod.id == "credit_card" && amount > 1000 {
            riskFactors.append(.cardPaymentHighAmount)
            riskScore += 15
        }

        // 6. Asset-specific risk
        if isHighRiskAsset(asset) {
            riskFactors.append(.highRiskAsset)
            riskScore += 10
        }

        let riskLevel = determineRiskLevel(score: riskScore)

        return RiskAssessment(
            riskLevel: riskLevel,
            riskScore: riskScore,
            riskFactors: riskFactors,
            shouldBlock: riskLevel == .critical,
            requiresManualReview: riskLevel == .high || riskLevel == .critical,
            recommendedAction: getRecommendedAction(for: riskLevel)
        )
    }

    /// Assess risk for a sale transaction
    func assessSaleRisk(
        amount: Decimal,
        asset: CryptoAsset,
        userCountry: String
    ) async -> RiskAssessment {
        var riskFactors: [RiskFactor] = []
        var riskScore: Int = 0

        // Sale-specific risk checks
        if amount > suspiciousAmountThreshold {
            riskFactors.append(.highAmount)
            riskScore += 35
        }

        let recentTransactions = getRecentTransactions(within: velocityCheckPeriod)
        if recentTransactions.count >= maxVelocityTransactions {
            riskFactors.append(.highVelocity)
            riskScore += 45
        }

        if isHighRiskCountry(userCountry) {
            riskFactors.append(.highRiskCountry)
            riskScore += 25
        }

        let riskLevel = determineRiskLevel(score: riskScore)

        return RiskAssessment(
            riskLevel: riskLevel,
            riskScore: riskScore,
            riskFactors: riskFactors,
            shouldBlock: riskLevel == .critical,
            requiresManualReview: riskLevel == .high || riskLevel == .critical,
            recommendedAction: getRecommendedAction(for: riskLevel)
        )
    }

    // MARK: - Rate Limiting

    /// Check if user has exceeded rate limits
    func checkRateLimit(userId: String) -> RateLimitResult {
        let recentTransactions = getRecentTransactions(within: velocityCheckPeriod)

        if recentTransactions.count >= maxVelocityTransactions {
            let resetTime = Date().addingTimeInterval(velocityCheckPeriod)
            return RateLimitResult(
                isLimited: true,
                remainingRequests: 0,
                resetTime: resetTime,
                retryAfter: velocityCheckPeriod
            )
        }

        return RateLimitResult(
            isLimited: false,
            remainingRequests: maxVelocityTransactions - recentTransactions.count,
            resetTime: Date().addingTimeInterval(velocityCheckPeriod),
            retryAfter: 0
        )
    }

    // MARK: - Transaction Recording

    /// Record a completed transaction
    func recordTransaction(
        id: String,
        type: TransactionType,
        amount: Decimal,
        asset: String,
        timestamp: Date = Date()
    ) {
        let record = TransactionRecord(
            id: id,
            type: type,
            amount: amount,
            asset: asset,
            timestamp: timestamp
        )

        transactionHistory.append(record)

        // Clean up old records (keep last 24 hours)
        let cutoff = Date().addingTimeInterval(-86400)
        transactionHistory.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Private Methods

    private func getRecentTransactions(within period: TimeInterval) -> [TransactionRecord] {
        let cutoff = Date().addingTimeInterval(-period)
        return transactionHistory.filter { $0.timestamp > cutoff }
    }

    private func getTodayTransactions() -> [TransactionRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        return transactionHistory.filter { $0.timestamp >= startOfDay }
    }

    private func isHighRiskCountry(_ country: String) -> Bool {
        // OFAC sanctioned countries and high-risk jurisdictions
        let highRiskCountries = [
            "KP", "IR", "SY", "CU", "VE", // Sanctioned
            "MM", "ZW", "BY" // High-risk
        ]
        return highRiskCountries.contains(country)
    }

    private func isHighRiskAsset(_ asset: CryptoAsset) -> Bool {
        // Privacy coins or lesser-known tokens
        let highRiskAssets = ["XMR", "ZEC", "DASH"]
        return highRiskAssets.contains(asset.symbol.uppercased())
    }

    private func determineRiskLevel(score: Int) -> RiskLevel {
        switch score {
        case 0..<20:
            return .low
        case 20..<40:
            return .medium
        case 40..<70:
            return .high
        default:
            return .critical
        }
    }

    private func getRecommendedAction(for level: RiskLevel) -> String {
        switch level {
        case .low:
            return "Proceed with transaction"
        case .medium:
            return "Additional verification recommended"
        case .high:
            return "Enhanced due diligence required"
        case .critical:
            return "Block transaction and review manually"
        }
    }
}

// MARK: - Supporting Models

struct RiskAssessment {
    let riskLevel: RiskLevel
    let riskScore: Int
    let riskFactors: [RiskFactor]
    let shouldBlock: Bool
    let requiresManualReview: Bool
    let recommendedAction: String
}

enum RiskLevel: String {
    case low
    case medium
    case high
    case critical

    var color: String {
        switch self {
        case .low: return "green"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum RiskFactor: String {
    case highAmount
    case highVelocity
    case dailyLimitExceeded
    case transactionCountExceeded
    case highRiskCountry
    case cardPaymentHighAmount
    case highRiskAsset
    case suspiciousPattern
    case newUser
    case unusualTime

    var description: String {
        switch self {
        case .highAmount:
            return "Transaction amount exceeds normal threshold"
        case .highVelocity:
            return "Multiple transactions in short period"
        case .dailyLimitExceeded:
            return "Daily transaction limit exceeded"
        case .transactionCountExceeded:
            return "Too many transactions today"
        case .highRiskCountry:
            return "Transaction from high-risk jurisdiction"
        case .cardPaymentHighAmount:
            return "High amount card payment"
        case .highRiskAsset:
            return "High-risk cryptocurrency"
        case .suspiciousPattern:
            return "Suspicious transaction pattern detected"
        case .newUser:
            return "New user account"
        case .unusualTime:
            return "Transaction at unusual time"
        }
    }
}

struct RateLimitResult {
    let isLimited: Bool
    let remainingRequests: Int
    let resetTime: Date
    let retryAfter: TimeInterval
}

struct TransactionRecord {
    let id: String
    let type: TransactionType
    let amount: Decimal
    let asset: String
    let timestamp: Date
}
