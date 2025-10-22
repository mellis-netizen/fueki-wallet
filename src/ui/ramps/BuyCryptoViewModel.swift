//
//  BuyCryptoViewModel.swift
//  Fueki Wallet
//
//  View model for buy crypto functionality
//

import Foundation
import Combine

@MainActor
class BuyCryptoViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var purchaseSuccess = false
    @Published var errorMessage: String?
    @Published var isKYCVerified = true // Mock for now
    @Published var currentQuote: QuoteResponse?

    // MARK: - Data
    let paymentMethods: [PaymentMethod] = [
        .creditCard,
        .bankTransfer,
        .applePay
    ]

    // MARK: - Dependencies
    private let paymentService = PaymentRampService.shared
    private let fraudService = FraudDetectionService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// Process cryptocurrency purchase
    func processPurchase(
        asset: CryptoAsset,
        amount: Decimal,
        paymentMethod: PaymentMethod
    ) async {
        isProcessing = true
        errorMessage = nil

        do {
            // 1. Fraud detection check
            let riskAssessment = await fraudService.assessPurchaseRisk(
                amount: amount,
                asset: asset,
                userCountry: await getUserCountry(),
                paymentMethod: paymentMethod
            )

            if riskAssessment.shouldBlock {
                throw PaymentError.transactionFailed("Transaction blocked due to security concerns")
            }

            if riskAssessment.requiresManualReview {
                print("⚠️ Transaction flagged for manual review: \(riskAssessment.riskFactors)")
            }

            // 2. Rate limiting check
            let rateLimitResult = fraudService.checkRateLimit(userId: "current_user")
            if rateLimitResult.isLimited {
                throw PaymentError.rateLimited
            }

            // 3. Get wallet address for the asset
            guard let walletAddress = getWalletAddress(for: asset) else {
                throw PaymentError.invalidWalletAddress
            }

            // 4. Initiate purchase
            let response = try await paymentService.purchaseCrypto(
                asset: asset,
                fiatAmount: amount,
                paymentMethod: paymentMethod,
                walletAddress: walletAddress
            )

            // 5. Record transaction for fraud tracking
            fraudService.recordTransaction(
                id: response.transactionId,
                type: .purchase,
                amount: amount,
                asset: asset.symbol
            )

            // 6. Open payment widget
            if let redirectURL = response.redirectURL {
                await openPaymentWidget(redirectURL)
            }

            // 7. Monitor transaction status
            monitorTransaction(response.transactionId)

            purchaseSuccess = true

        } catch let error as PaymentError {
            errorMessage = error.errorDescription
            purchaseSuccess = false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            purchaseSuccess = false
        }

        isProcessing = false
    }

    /// Get real-time quote
    func getQuote(
        asset: CryptoAsset,
        amount: Decimal,
        paymentMethod: PaymentMethod
    ) async {
        do {
            let quote = try await paymentService.getPurchaseQuote(
                asset: asset,
                fiatAmount: amount,
                paymentMethod: paymentMethod
            )

            currentQuote = quote

        } catch {
            print("Failed to get quote: \(error)")
        }
    }

    /// Calculate crypto amount from fiat
    func calculateCryptoAmount(usd: Decimal, asset: CryptoAsset) -> Decimal {
        if let quote = currentQuote {
            return quote.cryptoAmount ?? (usd / asset.priceUSD)
        }
        return usd / asset.priceUSD
    }

    /// Calculate transaction fee
    func calculateFee(amount: Decimal) -> Decimal {
        if let quote = currentQuote {
            return quote.fees.totalFee
        }
        // Default fee estimation: 2.9%
        return amount * 0.029
    }

    // MARK: - Private Methods

    private func getWalletAddress(for asset: CryptoAsset) -> String? {
        // In production, get from wallet manager
        // For now, return mock address based on network
        switch asset.network.lowercased() {
        case "ethereum", "polygon", "arbitrum", "optimism":
            return "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1"
        case "bitcoin":
            return "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
        case "solana":
            return "DYw8jCTfwHNRJhhmFcbXvVDTqWMEVFBX6ZKUmG5CNSKK"
        default:
            return nil
        }
    }

    private func getUserCountry() async -> String {
        if let countryCode = Locale.current.region?.identifier {
            return countryCode
        }
        return "US"
    }

    private func openPaymentWidget(_ url: URL) async {
        // Open URL in Safari or in-app browser
        #if canImport(UIKit)
        if await UIApplication.shared.canOpenURL(url) {
            await UIApplication.shared.open(url)
        }
        #endif
    }

    private func monitorTransaction(_ transactionId: String) {
        paymentService.monitorTransaction(transactionId, pollInterval: 5.0) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let status):
                    if status.isSuccess {
                        self?.purchaseSuccess = true
                        print("✅ Purchase completed successfully!")
                    } else if status.status == .failed {
                        self?.errorMessage = status.failureReason ?? "Transaction failed"
                    }

                case .failure(let error):
                    self?.errorMessage = error.errorDescription
                }
            }
        }
    }
}
