//
//  RampNetworkProvider.swift
//  Fueki Wallet
//
//  Ramp Network payment provider implementation
//

import Foundation

class RampNetworkProvider: PaymentProviderProtocol {

    // MARK: - Configuration
    private let baseURL = "https://api.ramp.network/api/host-api"
    private let widgetURL = "https://app.ramp.network"
    private var apiKey: String {
        // In production, fetch from secure storage
        Bundle.main.object(forInfoDictionaryKey: "RampAPIKey") as? String ?? ""
    }

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    // MARK: - Initialization
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - PaymentProviderProtocol Implementation

    func initiatePurchase(_ request: PurchaseRequest) async throws -> PurchaseResponse {
        // Build Ramp widget URL with parameters
        var components = URLComponents(string: widgetURL)!

        components.queryItems = [
            URLQueryItem(name: "hostApiKey", value: apiKey),
            URLQueryItem(name: "swapAsset", value: request.cryptocurrency),
            URLQueryItem(name: "userAddress", value: request.walletAddress),
            URLQueryItem(name: "fiatCurrency", value: request.fiatCurrency),
            URLQueryItem(name: "fiatValue", value: "\(request.fiatAmount)"),
            URLQueryItem(name: "hostAppName", value: "Fueki Wallet"),
            URLQueryItem(name: "variant", value: "mobile"),
            URLQueryItem(name: "defaultFlow", value: "ONRAMP")
        ]

        guard let widgetURL = components.url else {
            throw PaymentError.providerError("Failed to build widget URL")
        }

        // Create transaction record
        let transactionId = UUID().uuidString

        // Get quote for estimated amounts
        let quote = try await getQuote(QuoteRequest(
            type: .purchase,
            cryptocurrency: request.cryptocurrency,
            fiatCurrency: request.fiatCurrency,
            amount: request.fiatAmount,
            paymentMethod: request.paymentMethod,
            network: request.network
        ))

        return PurchaseResponse(
            transactionId: transactionId,
            status: TransactionStatus(
                transactionId: transactionId,
                status: .pending,
                cryptocurrency: request.cryptocurrency,
                amount: quote.cryptoAmount,
                createdAt: Date(),
                updatedAt: Date(),
                completedAt: nil,
                failureReason: nil
            ),
            redirectURL: widgetURL,
            estimatedCryptoAmount: quote.cryptoAmount ?? 0,
            totalFee: quote.fees.totalFee,
            estimatedArrival: Date().addingTimeInterval(900), // 15 minutes
            provider: .rampNetwork
        )
    }

    func initiateSale(_ request: SaleRequest) async throws -> SaleResponse {
        // Ramp off-ramp is in beta
        // Build off-ramp widget URL
        var components = URLComponents(string: widgetURL)!

        components.queryItems = [
            URLQueryItem(name: "hostApiKey", value: apiKey),
            URLQueryItem(name: "swapAsset", value: request.cryptocurrency),
            URLQueryItem(name: "swapAmount", value: "\(request.cryptoAmount)"),
            URLQueryItem(name: "fiatCurrency", value: request.fiatCurrency),
            URLQueryItem(name: "hostAppName", value: "Fueki Wallet"),
            URLQueryItem(name: "variant", value: "mobile"),
            URLQueryItem(name: "defaultFlow", value: "OFFRAMP")
        ]

        guard components.url != nil else {
            throw PaymentError.providerError("Failed to build off-ramp URL")
        }

        let transactionId = UUID().uuidString

        // Get quote
        let quote = try await getQuote(QuoteRequest(
            type: .sale,
            cryptocurrency: request.cryptocurrency,
            fiatCurrency: request.fiatCurrency,
            amount: request.cryptoAmount,
            paymentMethod: nil,
            network: request.network
        ))

        return SaleResponse(
            transactionId: transactionId,
            status: TransactionStatus(
                transactionId: transactionId,
                status: .pending,
                cryptocurrency: request.cryptocurrency,
                amount: request.cryptoAmount,
                createdAt: Date(),
                updatedAt: Date(),
                completedAt: nil,
                failureReason: nil
            ),
            estimatedFiatAmount: quote.fiatAmount,
            totalFee: quote.fees.totalFee,
            estimatedArrival: Date().addingTimeInterval(172800), // 2 days
            provider: .rampNetwork
        )
    }

    func getTransactionStatus(_ transactionId: String) async throws -> TransactionStatus {
        let endpoint = "/purchases/\(transactionId)"

        do {
            let data = try await performRequest(endpoint: endpoint, method: "GET")
            let response = try decoder.decode(RampPurchaseResponse.self, from: data)

            return TransactionStatus(
                transactionId: transactionId,
                status: mapRampStatus(response.status),
                cryptocurrency: response.asset.symbol,
                amount: response.cryptoAmount,
                createdAt: response.createdAt,
                updatedAt: response.updatedAt,
                completedAt: response.finalizedAt,
                failureReason: response.failureReason
            )
        } catch {
            throw PaymentError.providerError("Failed to fetch transaction status: \(error.localizedDescription)")
        }
    }

    func getSupportedCryptocurrencies() async throws -> [SupportedCryptocurrency] {
        let endpoint = "/assets"

        do {
            let data = try await performRequest(endpoint: endpoint, method: "GET")
            let response = try decoder.decode(RampAssetsResponse.self, from: data)

            return response.assets.map { asset in
                SupportedCryptocurrency(
                    id: asset.symbol,
                    symbol: asset.symbol,
                    name: asset.name,
                    networks: asset.chain.map { [$0] } ?? [],
                    minPurchaseAmount: asset.minPurchaseAmount,
                    maxPurchaseAmount: 50000,
                    icon: "bitcoinsign.circle.fill",
                    isAvailable: asset.enabled
                )
            }
        } catch {
            throw PaymentError.providerError("Failed to fetch supported assets")
        }
    }

    func getPaymentMethods(for country: String) async throws -> [PaymentMethodInfo] {
        // Ramp supports multiple payment methods
        return [
            PaymentMethodInfo(
                id: "card",
                type: "credit_card",
                name: "Credit/Debit Card",
                description: "Instant purchase with card",
                fee: 0,
                feePercentage: 2.9,
                processingTime: "5-15 minutes",
                limits: PaymentLimits(min: 10, max: 10000),
                supportedCountries: []
            ),
            PaymentMethodInfo(
                id: "bank_transfer",
                type: "bank_transfer",
                name: "Open Banking",
                description: "Lower fees via bank transfer",
                fee: 0,
                feePercentage: 0.49,
                processingTime: "1-3 days",
                limits: PaymentLimits(min: 50, max: 50000),
                supportedCountries: []
            ),
            PaymentMethodInfo(
                id: "apple_pay",
                type: "apple_pay",
                name: "Apple Pay",
                description: "Quick checkout",
                fee: 0,
                feePercentage: 2.9,
                processingTime: "5-15 minutes",
                limits: PaymentLimits(min: 10, max: 5000),
                supportedCountries: []
            )
        ]
    }

    func getQuote(_ quoteRequest: QuoteRequest) async throws -> QuoteResponse {
        // Build quote request
        let endpoint = "/quotes"

        let requestBody: [String: Any] = [
            "cryptoAssetSymbol": quoteRequest.cryptocurrency,
            "fiatCurrency": quoteRequest.fiatCurrency,
            "fiatValue": "\(quoteRequest.amount)"
        ]

        do {
            let data = try await performRequest(
                endpoint: endpoint,
                method: "POST",
                body: requestBody
            )

            let response = try decoder.decode(RampQuoteResponse.self, from: data)

            // Calculate fees
            let feePercentage: Decimal = quoteRequest.paymentMethod?.feePercentage ?? 2.9
            let providerFee = quoteRequest.amount * (feePercentage / 100)
            let networkFee: Decimal = 3.0

            return QuoteResponse(
                cryptocurrency: quoteRequest.cryptocurrency,
                fiatCurrency: quoteRequest.fiatCurrency,
                cryptoAmount: response.cryptoAmount,
                fiatAmount: quoteRequest.amount,
                exchangeRate: response.rate,
                fees: FeeBreakdown(
                    providerFee: providerFee,
                    providerFeePercentage: feePercentage,
                    networkFee: networkFee,
                    processingFee: 0,
                    totalFee: providerFee + networkFee
                ),
                total: quoteRequest.amount + providerFee + networkFee,
                expiresAt: Date().addingTimeInterval(60),
                provider: .rampNetwork
            )
        } catch {
            throw PaymentError.providerError("Failed to get quote: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func performRequest(
        endpoint: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        guard let url = URL(string: baseURL + endpoint) else {
            throw PaymentError.providerError("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw PaymentError.providerError("HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    private func mapRampStatus(_ status: String) -> TransactionStatus.Status {
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
}

// MARK: - Ramp API Response Models

private struct RampPurchaseResponse: Decodable {
    let id: String
    let status: String
    let asset: RampAsset
    let cryptoAmount: Decimal
    let fiatCurrency: String
    let fiatValue: Decimal
    let createdAt: Date
    let updatedAt: Date
    let finalizedAt: Date?
    let failureReason: String?
}

private struct RampAsset: Decodable {
    let symbol: String
    let name: String
    let chain: String?
}

private struct RampAssetsResponse: Decodable {
    let assets: [RampAssetInfo]
}

private struct RampAssetInfo: Decodable {
    let symbol: String
    let name: String
    let chain: String?
    let enabled: Bool
    let minPurchaseAmount: Decimal
}

private struct RampQuoteResponse: Decodable {
    let cryptoAmount: Decimal
    let fiatCurrency: String
    let fiatValue: Decimal
    let rate: Decimal
}
