//
//  PaymentRampService.swift
//  Fueki Wallet
//
//  Payment on-ramp and off-ramp integration service
//  Supports Ramp Network (primary) and MoonPay (fallback)
//

import Foundation
import Combine

// MARK: - Payment Provider Protocol
protocol PaymentProviderProtocol {
    func initiatePurchase(_ request: PurchaseRequest) async throws -> PurchaseResponse
    func initiateSale(_ request: SaleRequest) async throws -> SaleResponse
    func getTransactionStatus(_ transactionId: String) async throws -> TransactionStatus
    func getSupportedCryptocurrencies() async throws -> [SupportedCryptocurrency]
    func getPaymentMethods(for country: String) async throws -> [PaymentMethodInfo]
    func getQuote(_ quoteRequest: QuoteRequest) async throws -> QuoteResponse
}

// MARK: - Payment Ramp Service
@MainActor
class PaymentRampService: ObservableObject {
    static let shared = PaymentRampService()

    // MARK: - Published Properties
    @Published var currentProvider: PaymentProvider = .rampNetwork
    @Published var isProcessing = false
    @Published var lastError: PaymentError?

    // MARK: - Private Properties
    private var rampProvider: RampNetworkProvider
    private var moonPayProvider: MoonPayProvider
    private var cancellables = Set<AnyCancellable>()

    // Configuration
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    private let requestTimeout: TimeInterval = 30.0

    // Transaction tracking
    private var activeTransactions: [String: TransactionStatus] = [:]
    private var transactionCallbacks: [String: (Result<TransactionStatus, PaymentError>) -> Void] = [:]

    // MARK: - Initialization
    init() {
        self.rampProvider = RampNetworkProvider()
        self.moonPayProvider = MoonPayProvider()

        // Set up webhook listeners
        setupWebhookHandlers()
    }

    // MARK: - Public Methods - On-Ramp (Buy)

    /// Initiate cryptocurrency purchase
    func purchaseCrypto(
        asset: CryptoAsset,
        fiatAmount: Decimal,
        paymentMethod: PaymentMethod,
        walletAddress: String,
        userCountry: String? = nil
    ) async throws -> PurchaseResponse {
        isProcessing = true
        defer { isProcessing = false }

        // Validate inputs
        try validatePurchaseRequest(
            asset: asset,
            fiatAmount: fiatAmount,
            walletAddress: walletAddress
        )

        // Check user's country and determine best provider
        let country = userCountry ?? await getUserCountry()
        let provider = selectOptimalProvider(
            for: .purchase,
            country: country,
            asset: asset
        )

        // Build request
        let request = PurchaseRequest(
            cryptocurrency: asset.symbol,
            fiatCurrency: "USD",
            fiatAmount: fiatAmount,
            walletAddress: walletAddress,
            paymentMethod: paymentMethod,
            network: asset.network,
            userCountry: country
        )

        // Attempt purchase with retry logic
        return try await executeWithRetry {
            try await self.executePurchase(request, provider: provider)
        }
    }

    /// Get quote for purchase
    func getPurchaseQuote(
        asset: CryptoAsset,
        fiatAmount: Decimal,
        paymentMethod: PaymentMethod
    ) async throws -> QuoteResponse {
        let request = QuoteRequest(
            type: .purchase,
            cryptocurrency: asset.symbol,
            fiatCurrency: "USD",
            amount: fiatAmount,
            paymentMethod: paymentMethod,
            network: asset.network
        )

        let provider = getActiveProvider()
        return try await provider.getQuote(request)
    }

    // MARK: - Public Methods - Off-Ramp (Sell)

    /// Initiate cryptocurrency sale
    func sellCrypto(
        asset: CryptoAsset,
        cryptoAmount: Decimal,
        bankAccount: BankAccount,
        walletAddress: String,
        userCountry: String? = nil
    ) async throws -> SaleResponse {
        isProcessing = true
        defer { isProcessing = false }

        // Validate inputs
        try validateSaleRequest(
            asset: asset,
            cryptoAmount: cryptoAmount
        )

        // Check provider support for off-ramp
        let country = userCountry ?? await getUserCountry()
        let provider = selectOptimalProvider(
            for: .sale,
            country: country,
            asset: asset
        )

        // Build request
        let request = SaleRequest(
            cryptocurrency: asset.symbol,
            cryptoAmount: cryptoAmount,
            fiatCurrency: "USD",
            bankAccount: bankAccount,
            network: asset.network,
            userCountry: country
        )

        // Attempt sale with retry logic
        return try await executeWithRetry {
            try await self.executeSale(request, provider: provider)
        }
    }

    /// Get quote for sale
    func getSaleQuote(
        asset: CryptoAsset,
        cryptoAmount: Decimal
    ) async throws -> QuoteResponse {
        let request = QuoteRequest(
            type: .sale,
            cryptocurrency: asset.symbol,
            fiatCurrency: "USD",
            amount: cryptoAmount,
            paymentMethod: nil,
            network: asset.network
        )

        let provider = getActiveProvider()
        return try await provider.getQuote(request)
    }

    // MARK: - Transaction Management

    /// Get transaction status
    func getTransactionStatus(_ transactionId: String) async throws -> TransactionStatus {
        // Check cache first
        if let cached = activeTransactions[transactionId] {
            if cached.isFinal {
                return cached
            }
        }

        // Fetch from provider
        let provider = getActiveProvider()
        let status = try await provider.getTransactionStatus(transactionId)

        // Update cache
        activeTransactions[transactionId] = status

        // Trigger callback if registered
        if let callback = transactionCallbacks[transactionId] {
            callback(.success(status))
            if status.isFinal {
                transactionCallbacks.removeValue(forKey: transactionId)
            }
        }

        return status
    }

    /// Monitor transaction status with polling
    func monitorTransaction(
        _ transactionId: String,
        pollInterval: TimeInterval = 5.0,
        completion: @escaping (Result<TransactionStatus, PaymentError>) -> Void
    ) {
        transactionCallbacks[transactionId] = completion

        Task {
            var attempts = 0
            let maxAttempts = 120 // 10 minutes with 5s interval

            while attempts < maxAttempts {
                do {
                    let status = try await getTransactionStatus(transactionId)

                    if status.isFinal {
                        completion(.success(status))
                        transactionCallbacks.removeValue(forKey: transactionId)
                        return
                    }

                } catch {
                    completion(.failure(error as? PaymentError ?? .networkError(error)))
                    transactionCallbacks.removeValue(forKey: transactionId)
                    return
                }

                try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
                attempts += 1
            }

            completion(.failure(.timeout))
            transactionCallbacks.removeValue(forKey: transactionId)
        }
    }

    // MARK: - KYC Management

    /// Check KYC status
    func checkKYCStatus() async throws -> KYCStatus {
        let provider = getActiveProvider()

        // Implementation depends on provider API
        // For now, return mock status
        return KYCStatus(
            tier: .tier2,
            isVerified: true,
            limits: KYCLimits(
                daily: 2000,
                weekly: 10000,
                monthly: 50000
            )
        )
    }

    /// Initiate KYC verification
    func initiateKYCVerification() async throws -> KYCVerificationURL {
        let provider = getActiveProvider()

        // Get verification URL from provider
        // Implementation varies by provider
        let url = URL(string: "https://verify.ramp.network")!

        return KYCVerificationURL(
            url: url,
            sessionId: UUID().uuidString,
            expiresAt: Date().addingTimeInterval(3600)
        )
    }

    // MARK: - Provider Management

    /// Get supported cryptocurrencies
    func getSupportedCryptocurrencies() async throws -> [SupportedCryptocurrency] {
        let provider = getActiveProvider()
        return try await provider.getSupportedCryptocurrencies()
    }

    /// Get available payment methods for country
    func getPaymentMethods(country: String) async throws -> [PaymentMethodInfo] {
        let provider = getActiveProvider()
        return try await provider.getPaymentMethods(for: country)
    }

    /// Switch to specific provider
    func switchProvider(_ provider: PaymentProvider) {
        currentProvider = provider
    }

    // MARK: - Private Methods

    private func executePurchase(
        _ request: PurchaseRequest,
        provider: PaymentProvider
    ) async throws -> PurchaseResponse {
        let activeProvider = getProvider(provider)

        do {
            let response = try await activeProvider.initiatePurchase(request)

            // Track transaction
            activeTransactions[response.transactionId] = response.status

            return response

        } catch {
            // Fallback to alternate provider if primary fails
            if provider == .rampNetwork {
                print("⚠️ Ramp Network failed, falling back to MoonPay")
                return try await executePurchase(request, provider: .moonPay)
            }
            throw error
        }
    }

    private func executeSale(
        _ request: SaleRequest,
        provider: PaymentProvider
    ) async throws -> SaleResponse {
        let activeProvider = getProvider(provider)

        do {
            let response = try await activeProvider.initiateSale(request)

            // Track transaction
            activeTransactions[response.transactionId] = response.status

            return response

        } catch {
            // Fallback logic
            if provider == .rampNetwork {
                print("⚠️ Ramp Network off-ramp failed, falling back to MoonPay")
                return try await executeSale(request, provider: .moonPay)
            }
            throw error
        }
    }

    private func getProvider(_ provider: PaymentProvider) -> PaymentProviderProtocol {
        switch provider {
        case .rampNetwork:
            return rampProvider
        case .moonPay:
            return moonPayProvider
        }
    }

    private func getActiveProvider() -> PaymentProviderProtocol {
        return getProvider(currentProvider)
    }

    private func selectOptimalProvider(
        for operation: TransactionType,
        country: String,
        asset: CryptoAsset
    ) -> PaymentProvider {
        // Provider selection logic based on:
        // 1. Geographic coverage
        // 2. Fee structure
        // 3. Asset support
        // 4. Operation type (buy/sell)

        // Ramp Network has better fees and broader coverage
        // Use MoonPay for countries not supported by Ramp

        let unsupportedRampCountries = ["CN"] // Example

        if unsupportedRampCountries.contains(country) {
            return .moonPay
        }

        // Off-ramp: Check if Ramp supports it (beta)
        if operation == .sale {
            // MoonPay has more mature off-ramp
            return .moonPay
        }

        return .rampNetwork
    }

    private func validatePurchaseRequest(
        asset: CryptoAsset,
        fiatAmount: Decimal,
        walletAddress: String
    ) throws {
        // Minimum purchase amount
        guard fiatAmount >= 10 else {
            throw PaymentError.invalidAmount("Minimum purchase amount is $10")
        }

        // Maximum per transaction (KYC dependent)
        guard fiatAmount <= 10000 else {
            throw PaymentError.invalidAmount("Maximum purchase amount is $10,000 per transaction")
        }

        // Validate wallet address
        guard validateAddress(walletAddress, for: asset) else {
            throw PaymentError.invalidWalletAddress
        }
    }

    private func validateSaleRequest(
        asset: CryptoAsset,
        cryptoAmount: Decimal
    ) throws {
        guard cryptoAmount > 0 else {
            throw PaymentError.invalidAmount("Amount must be greater than 0")
        }
    }

    private func validateAddress(_ address: String, for asset: CryptoAsset) -> Bool {
        // Basic validation - can be enhanced
        switch asset.network.lowercased() {
        case "ethereum", "polygon", "arbitrum", "optimism":
            return address.hasPrefix("0x") && address.count == 42
        case "bitcoin":
            return address.count >= 26 && address.count <= 35
        case "solana":
            return address.count >= 32 && address.count <= 44
        default:
            return !address.isEmpty
        }
    }

    private func getUserCountry() async -> String {
        // Get user's country from IP or device settings
        if let countryCode = Locale.current.region?.identifier {
            return countryCode
        }
        return "US"
    }

    private func executeWithRetry<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxRetryAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry on validation errors
                if let paymentError = error as? PaymentError {
                    switch paymentError {
                    case .invalidAmount, .invalidWalletAddress, .kycRequired:
                        throw paymentError
                    default:
                        break
                    }
                }

                if attempt < maxRetryAttempts {
                    print("⚠️ Attempt \(attempt) failed, retrying in \(retryDelay)s...")
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? PaymentError.unknownError
    }

    private func setupWebhookHandlers() {
        // Webhook handler setup
        // In production, this would connect to a backend server
        // that receives webhooks from payment providers

        NotificationCenter.default.publisher(for: .paymentWebhookReceived)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let transactionId = userInfo["transactionId"] as? String,
                      let status = userInfo["status"] as? TransactionStatus else {
                    return
                }

                Task { @MainActor in
                    self.activeTransactions[transactionId] = status

                    if let callback = self.transactionCallbacks[transactionId] {
                        callback(.success(status))
                        if status.isFinal {
                            self.transactionCallbacks.removeValue(forKey: transactionId)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let paymentWebhookReceived = Notification.Name("paymentWebhookReceived")
}
