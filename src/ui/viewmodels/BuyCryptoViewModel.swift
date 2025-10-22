//
//  BuyCryptoViewModel.swift
//  Fueki Wallet
//
//  Buy cryptocurrency view model with payment processing
//

import SwiftUI
import Combine

@MainActor
class BuyCryptoViewModel: ObservableObject {
    @Published var paymentMethods: [PaymentMethod] = []
    @Published var isProcessing = false
    @Published var purchaseSuccess = false
    @Published var isKYCVerified = true // For demo purposes
    @Published var errorMessage: String?

    private let rampService: RampService

    init(rampService: RampService = .shared) {
        self.rampService = rampService
        loadPaymentMethods()
    }

    // MARK: - Payment Methods

    private func loadPaymentMethods() {
        paymentMethods = PaymentMethod.samples
    }

    // MARK: - Calculations

    func calculateCryptoAmount(usd: Decimal, asset: CryptoAsset) -> Decimal {
        guard asset.priceUSD > 0 else { return 0 }
        return usd / asset.priceUSD
    }

    func calculateFee(amount: Decimal) -> Decimal {
        // 2.99% fee for card purchases
        return amount * 0.0299
    }

    // MARK: - Purchase Processing

    func processPurchase(
        asset: CryptoAsset,
        amount: Decimal,
        paymentMethod: PaymentMethod
    ) async {
        isProcessing = true
        purchaseSuccess = false
        errorMessage = nil

        do {
            let transactionId = try await rampService.processPurchase(
                asset: asset,
                usdAmount: amount,
                paymentMethod: paymentMethod
            )

            print("Purchase successful: \(transactionId)")
            purchaseSuccess = true
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }
}

// MARK: - Ramp Service
class RampService {
    static let shared = RampService()

    func processPurchase(
        asset: CryptoAsset,
        usdAmount: Decimal,
        paymentMethod: PaymentMethod
    ) async throws -> String {
        // TODO: Implement real on-ramp integration (Moonpay, Transak, etc.)
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Simulate transaction ID
        return "TXN-\(UUID().uuidString)"
    }

    func processSale(
        asset: CryptoAsset,
        amount: Decimal,
        bankAccount: BankAccount
    ) async throws -> String {
        // TODO: Implement real off-ramp integration
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Simulate transaction ID
        return "SALE-\(UUID().uuidString)"
    }
}
