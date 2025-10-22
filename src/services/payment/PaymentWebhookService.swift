//
//  PaymentWebhookService.swift
//  Fueki Wallet
//
//  Backend webhook handler for payment provider callbacks
//

import Foundation
import CryptoKit

/// Service to handle incoming webhooks from payment providers
class PaymentWebhookService {

    static let shared = PaymentWebhookService()

    // MARK: - Webhook Verification

    /// Verify Ramp Network webhook signature
    func verifyRampWebhook(payload: Data, signature: String) -> Bool {
        guard let secret = getRampWebhookSecret() else {
            return false
        }

        let key = SymmetricKey(data: Data(secret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignature = Data(hmac).hexEncodedString()

        return signature.lowercased() == computedSignature.lowercased()
    }

    /// Verify MoonPay webhook signature
    func verifyMoonPayWebhook(payload: Data, signature: String) -> Bool {
        guard let secret = getMoonPayWebhookSecret() else {
            return false
        }

        let key = SymmetricKey(data: Data(secret.utf8))
        let hmac = HMAC<SHA256>.authenticationCode(for: payload, using: key)
        let computedSignature = Data(hmac).base64EncodedString()

        return signature == computedSignature
    }

    // MARK: - Webhook Processing

    /// Process incoming webhook from Ramp Network
    func processRampWebhook(_ payload: Data) throws -> WebhookEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let webhookData = try decoder.decode(RampWebhookPayload.self, from: payload)

        let event = WebhookEvent(
            eventId: UUID().uuidString,
            eventType: mapRampEventType(webhookData.type),
            transactionId: webhookData.purchase.id,
            status: mapRampPurchaseStatus(webhookData.purchase.status),
            timestamp: Date(),
            data: [
                "asset": webhookData.purchase.asset.symbol,
                "cryptoAmount": "\(webhookData.purchase.cryptoAmount ?? 0)",
                "fiatValue": "\(webhookData.purchase.fiatValue)"
            ]
        )

        // Notify app
        notifyApp(event: event)

        return event
    }

    /// Process incoming webhook from MoonPay
    func processMoonPayWebhook(_ payload: Data) throws -> WebhookEvent {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let webhookData = try decoder.decode(MoonPayWebhookPayload.self, from: payload)

        let event = WebhookEvent(
            eventId: UUID().uuidString,
            eventType: mapMoonPayEventType(webhookData.type),
            transactionId: webhookData.data.id,
            status: mapMoonPayTransactionStatus(webhookData.data.status),
            timestamp: Date(),
            data: [
                "currency": webhookData.data.currency.code,
                "cryptoAmount": "\(webhookData.data.quoteCurrencyAmount ?? 0)",
                "fiatAmount": "\(webhookData.data.baseCurrencyAmount)"
            ]
        )

        notifyApp(event: event)

        return event
    }

    // MARK: - Private Methods

    private func notifyApp(event: WebhookEvent) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .paymentWebhookReceived,
                object: nil,
                userInfo: [
                    "transactionId": event.transactionId,
                    "status": event.status
                ]
            )
        }
    }

    private func getRampWebhookSecret() -> String? {
        // In production, fetch from secure storage
        return Bundle.main.object(forInfoDictionaryKey: "RampWebhookSecret") as? String
    }

    private func getMoonPayWebhookSecret() -> String? {
        // In production, fetch from secure storage
        return Bundle.main.object(forInfoDictionaryKey: "MoonPayWebhookSecret") as? String
    }

    private func mapRampEventType(_ type: String) -> WebhookEvent.EventType {
        switch type.lowercased() {
        case "created":
            return .transactionCreated
        case "released":
            return .transactionCompleted
        case "cancelled", "expired":
            return .transactionFailed
        default:
            return .transactionUpdated
        }
    }

    private func mapRampPurchaseStatus(_ status: String) -> TransactionStatus.Status {
        switch status.uppercased() {
        case "INITIALIZED", "PENDING":
            return .pending
        case "PAYMENT_STARTED", "PAYMENT_IN_PROGRESS":
            return .processing
        case "PAYMENT_EXECUTED":
            return .paymentReceived
        case "RELEASING":
            return .processing
        case "RELEASED":
            return .completed
        case "CANCELLED":
            return .cancelled
        case "EXPIRED":
            return .expired
        case "FAILED":
            return .failed
        default:
            return .pending
        }
    }

    private func mapMoonPayEventType(_ type: String) -> WebhookEvent.EventType {
        switch type.lowercased() {
        case "transaction_created":
            return .transactionCreated
        case "transaction_updated":
            return .transactionUpdated
        case "transaction_completed":
            return .transactionCompleted
        case "transaction_failed":
            return .transactionFailed
        default:
            return .transactionUpdated
        }
    }

    private func mapMoonPayTransactionStatus(_ status: String) -> TransactionStatus.Status {
        switch status.lowercased() {
        case "waitingpayment":
            return .waitingForPayment
        case "pending":
            return .pending
        case "waitingauthorization":
            return .processing
        case "completed":
            return .completed
        case "failed":
            return .failed
        default:
            return .pending
        }
    }
}

// MARK: - Webhook Payload Models

private struct RampWebhookPayload: Decodable {
    let type: String
    let purchase: RampPurchase

    struct RampPurchase: Decodable {
        let id: String
        let status: String
        let asset: Asset
        let cryptoAmount: Decimal?
        let fiatValue: Decimal
        let fiatCurrency: String

        struct Asset: Decodable {
            let symbol: String
            let name: String
        }
    }
}

private struct MoonPayWebhookPayload: Decodable {
    let type: String
    let data: MoonPayTransaction

    struct MoonPayTransaction: Decodable {
        let id: String
        let status: String
        let currency: Currency
        let quoteCurrencyAmount: Decimal?
        let baseCurrencyAmount: Decimal

        struct Currency: Decodable {
            let code: String
            let name: String
        }
    }
}

// MARK: - Data Extension

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02hhx", $0) }.joined()
    }
}
