//
//  PaymentMethod.swift
//  Fueki Wallet
//
//  Payment method models for on-ramp/off-ramp
//

import Foundation

struct PaymentMethod: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let type: PaymentMethodType
    let fee: Decimal
    let processingTime: String
    let limits: PaymentLimits
    let isEnabled: Bool

    struct PaymentLimits: Codable {
        let min: Decimal
        let max: Decimal
        let daily: Decimal
    }
}

enum PaymentMethodType: String, Codable {
    case creditCard
    case debitCard
    case bankTransfer
    case applePay
    case googlePay
}

struct BankAccount: Identifiable, Codable {
    let id: String
    let bankName: String
    let accountType: String
    let lastFourDigits: String
    let isVerified: Bool
    let routingNumber: String?
}

// MARK: - Sample Data
extension PaymentMethod {
    static let samples: [PaymentMethod] = [
        PaymentMethod(
            id: "credit-card",
            name: "Credit Card",
            description: "Visa, Mastercard, AMEX",
            icon: "creditcard.fill",
            type: .creditCard,
            fee: 2.99,
            processingTime: "Instant",
            limits: PaymentLimits(min: 10, max: 10000, daily: 25000),
            isEnabled: true
        ),
        PaymentMethod(
            id: "debit-card",
            name: "Debit Card",
            description: "Visa or Mastercard debit",
            icon: "creditcard.fill",
            type: .debitCard,
            fee: 1.99,
            processingTime: "Instant",
            limits: PaymentLimits(min: 10, max: 5000, daily: 15000),
            isEnabled: true
        ),
        PaymentMethod(
            id: "bank-transfer",
            name: "Bank Transfer",
            description: "ACH transfer from your bank",
            icon: "building.columns.fill",
            type: .bankTransfer,
            fee: 0.00,
            processingTime: "3-5 business days",
            limits: PaymentLimits(min: 10, max: 50000, daily: 100000),
            isEnabled: true
        ),
        PaymentMethod(
            id: "apple-pay",
            name: "Apple Pay",
            description: "Pay with Apple Pay",
            icon: "apple.logo",
            type: .applePay,
            fee: 2.49,
            processingTime: "Instant",
            limits: PaymentLimits(min: 10, max: 5000, daily: 15000),
            isEnabled: true
        )
    ]
}

extension BankAccount {
    static let samples: [BankAccount] = [
        BankAccount(
            id: "bank-1",
            bankName: "Chase Bank",
            accountType: "Checking",
            lastFourDigits: "4523",
            isVerified: true,
            routingNumber: "021000021"
        ),
        BankAccount(
            id: "bank-2",
            bankName: "Bank of America",
            accountType: "Savings",
            lastFourDigits: "8901",
            isVerified: true,
            routingNumber: "026009593"
        )
    ]
}
