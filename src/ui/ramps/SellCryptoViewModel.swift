//
//  SellCryptoViewModel.swift
//  Fueki Wallet
//
//  View model for sell crypto functionality
//

import Foundation
import Combine

@MainActor
class SellCryptoViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var saleSuccess = false
    @Published var errorMessage: String?
    @Published var currentQuote: QuoteResponse?

    // MARK: - Data
    let bankAccounts: [BankAccount] = [
        BankAccount(
            id: "bank_1",
            bankName: "Chase Bank",
            accountType: .checking,
            lastFourDigits: "4242",
            routingNumber: "021000021",
            isVerified: true
        ),
        BankAccount(
            id: "bank_2",
            bankName: "Wells Fargo",
            accountType: .savings,
            lastFourDigits: "8888",
            routingNumber: "121000248",
            isVerified: true
        )
    ]

    // MARK: - Dependencies
    private let paymentService = PaymentRampService.shared
    private let fraudService = FraudDetectionService.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// Process cryptocurrency sale
    func processSale(
        asset: CryptoAsset,
        amount: Decimal,
        bankAccount: BankAccount
    ) async {
        isProcessing = true
        errorMessage = nil

        do {
            // 1. Validate sufficient balance
            guard amount <= asset.balance else {
                throw PaymentError.insufficientFunds
            }

            // 2. Fraud detection check
            let riskAssessment = await fraudService.assessSaleRisk(
                amount: calculateUSDValue(amount: amount, asset: asset),
                asset: asset,
                userCountry: await getUserCountry()
            )

            if riskAssessment.shouldBlock {
                throw PaymentError.transactionFailed("Transaction blocked due to security concerns")
            }

            // 3. Rate limiting check
            let rateLimitResult = fraudService.checkRateLimit(userId: "current_user")
            if rateLimitResult.isLimited {
                throw PaymentError.rateLimited
            }

            // 4. Get wallet address
            guard let walletAddress = getWalletAddress(for: asset) else {
                throw PaymentError.invalidWalletAddress
            }

            // 5. Initiate sale
            let response = try await paymentService.sellCrypto(
                asset: asset,
                cryptoAmount: amount,
                bankAccount: bankAccount,
                walletAddress: walletAddress
            )

            // 6. Record transaction
            fraudService.recordTransaction(
                id: response.transactionId,
                type: .sale,
                amount: response.estimatedFiatAmount,
                asset: asset.symbol
            )

            // 7. Monitor transaction
            monitorTransaction(response.transactionId)

            saleSuccess = true

        } catch let error as PaymentError {
            errorMessage = error.errorDescription
            saleSuccess = false
        } catch {
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
            saleSuccess = false
        }

        isProcessing = false
    }

    /// Get real-time quote for sale
    func getQuote(asset: CryptoAsset, amount: Decimal) async {
        do {
            let quote = try await paymentService.getSaleQuote(
                asset: asset,
                cryptoAmount: amount
            )

            currentQuote = quote

        } catch {
            print("Failed to get quote: \(error)")
        }
    }

    /// Calculate USD value from crypto amount
    func calculateUSDValue(amount: Decimal, asset: CryptoAsset) -> Decimal {
        if let quote = currentQuote {
            return quote.fiatAmount
        }
        return amount * asset.priceUSD
    }

    /// Calculate transaction fee
    func calculateFee(usdAmount: Decimal) -> Decimal {
        if let quote = currentQuote {
            return quote.fees.totalFee
        }
        // Default fee estimation: 2%
        return usdAmount * 0.02
    }

    // MARK: - Private Methods

    private func getWalletAddress(for asset: CryptoAsset) -> String? {
        // Same as BuyCryptoViewModel
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

    private func monitorTransaction(_ transactionId: String) {
        paymentService.monitorTransaction(transactionId, pollInterval: 5.0) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success(let status):
                    if status.isSuccess {
                        self?.saleSuccess = true
                        print("✅ Sale completed successfully!")
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
