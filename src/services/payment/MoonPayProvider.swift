//
//  MoonPayProvider.swift
//  Fueki Wallet
//
//  MoonPay payment provider implementation (fallback provider)
//

import Foundation

class MoonPayProvider: PaymentProviderProtocol {

    // MARK: - Configuration
    private let baseURL = "https://api.moonpay.com/v3"
    private let widgetURL = "https://buy.moonpay.com"
    private var apiKey: String {
        // In production, fetch from secure storage
        Bundle.main.object(forInfoDictionaryKey: "MoonPayAPIKey") as? String ?? ""
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
        // Build MoonPay widget URL
        var components = URLComponents(string: widgetURL)!

        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "currencyCode", value: request.cryptocurrency.lowercased()),
            URLQueryItem(name: "walletAddress", value: request.walletAddress),
            URLQueryItem(name: "baseCurrencyCode", value: request.fiatCurrency.lowercased()),
            URLQueryItem(name: "baseCurrencyAmount", value: "\(request.fiatAmount)"),
            URLQueryItem(name: "colorCode", value: "4F46E5"),
            URLQueryItem(name: "redirectURL", value: "fueki://payment-complete")
        ]

        guard let widgetURL = components.url else {
            throw PaymentError.providerError("Failed to build widget URL")
        }

        let transactionId = UUID().uuidString

        // Get quote
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
            estimatedArrival: Date().addingTimeInterval(600), // 10 minutes
            provider: .moonPay
        )
    }

    func initiateSale(_ request: SaleRequest) async throws -> SaleResponse {
        // MoonPay sell API
        var components = URLComponents(string: "https://sell.moonpay.com")!

        components.queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "currencyCode", value: request.cryptocurrency.lowercased()),
            URLQueryItem(name: "quoteCurrencyAmount", value: "\(request.cryptoAmount)"),
            URLQueryItem(name: "baseCurrencyCode", value: request.fiatCurrency.lowercased()),
            URLQueryItem(name: "refundWalletAddress", value: ""), // User's wallet for refunds
            URLQueryItem(name: "redirectURL", value: "fueki://payment-complete")
        ]

        guard components.url != nil else {
            throw PaymentError.providerError("Failed to build sell URL")
        }

        let transactionId = UUID().uuidString

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
            estimatedArrival: Date().addingTimeInterval(259200), // 3 days
            provider: .moonPay
        )
    }

    func getTransactionStatus(_ transactionId: String) async throws -> TransactionStatus {
        let endpoint = "/transactions/\(transactionId)"

        do {
            let data = try await performRequest(endpoint: endpoint, method: "GET")
            let response = try decoder.decode(MoonPayTransactionResponse.self, from: data)

            return TransactionStatus(
                transactionId: response.id,
                status: mapMoonPayStatus(response.status),
                cryptocurrency: response.currencyId,
                amount: response.quoteCurrencyAmount,
                createdAt: response.createdAt,
                updatedAt: response.updatedAt,
                completedAt: response.completedAt,
                failureReason: response.failureReason
            )
        } catch {
            throw PaymentError.providerError("Failed to fetch transaction status")
        }
    }

    func getSupportedCryptocurrencies() async throws -> [SupportedCryptocurrency] {
        let endpoint = "/currencies"

        do {
            let data = try await performRequest(endpoint: endpoint, method: "GET")
            let currencies = try decoder.decode([MoonPayCurrency].self, from: data)

            return currencies
                .filter { $0.type == "crypto" }
                .map { currency in
                    SupportedCryptocurrency(
                        id: currency.code,
                        symbol: currency.code.uppercased(),
                        name: currency.name,
                        networks: [currency.code],
                        minPurchaseAmount: currency.minBuyAmount ?? 10,
                        maxPurchaseAmount: currency.maxBuyAmount ?? 50000,
                        icon: "bitcoinsign.circle.fill",
                        isAvailable: currency.isSupportedInUS
                    )
                }
        } catch {
            throw PaymentError.providerError("Failed to fetch currencies")
        }
    }

    func getPaymentMethods(for country: String) async throws -> [PaymentMethodInfo] {
        // MoonPay payment methods
        return [
            PaymentMethodInfo(
                id: "credit_debit_card",
                type: "card",
                name: "Credit/Debit Card",
                description: "Instant purchase",
                fee: 0,
                feePercentage: 4.5,
                processingTime: "5-10 minutes",
                limits: PaymentLimits(min: 10, max: 10000),
                supportedCountries: []
            ),
            PaymentMethodInfo(
                id: "bank_transfer",
                type: "bank_transfer",
                name: "ACH Transfer",
                description: "Lower fees, slower",
                fee: 0,
                feePercentage: 1.0,
                processingTime: "1-3 days",
                limits: PaymentLimits(min: 50, max: 50000),
                supportedCountries: []
            ),
            PaymentMethodInfo(
                id: "apple_pay",
                type: "apple_pay",
                name: "Apple Pay",
                description: "Quick purchase",
                fee: 0,
                feePercentage: 4.5,
                processingTime: "5-10 minutes",
                limits: PaymentLimits(min: 10, max: 5000),
                supportedCountries: []
            )
        ]
    }

    func getQuote(_ quoteRequest: QuoteRequest) async throws -> QuoteResponse {
        // MoonPay uses different endpoints for buy/sell quotes
        let isBuy = quoteRequest.type == .purchase

        var queryItems = [
            URLQueryItem(name: "apiKey", value: apiKey),
            URLQueryItem(name: "baseCurrencyCode", value: quoteRequest.fiatCurrency.lowercased()),
            URLQueryItem(name: "currencyCode", value: quoteRequest.cryptocurrency.lowercased())
        ]

        if isBuy {
            queryItems.append(URLQueryItem(
                name: "baseCurrencyAmount",
                value: "\(quoteRequest.amount)"
            ))
        } else {
            queryItems.append(URLQueryItem(
                name: "quoteCurrencyAmount",
                value: "\(quoteRequest.amount)"
            ))
        }

        var components = URLComponents(string: baseURL + "/currencies/\(quoteRequest.cryptocurrency.lowercased())/buy_quote")!
        components.queryItems = queryItems

        guard let url = components.url else {
            throw PaymentError.providerError("Invalid quote URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw PaymentError.providerError("Quote request failed")
        }

        let quoteResponse = try decoder.decode(MoonPayQuoteResponse.self, from: data)

        // Calculate fees
        let feePercentage: Decimal = quoteRequest.paymentMethod?.feePercentage ?? 4.5
        let providerFee = quoteRequest.amount * (feePercentage / 100)
        let networkFee: Decimal = quoteResponse.networkFeeAmount ?? 5.0

        return QuoteResponse(
            cryptocurrency: quoteRequest.cryptocurrency,
            fiatCurrency: quoteRequest.fiatCurrency,
            cryptoAmount: isBuy ? quoteResponse.quoteCurrencyAmount : nil,
            fiatAmount: quoteRequest.amount,
            exchangeRate: quoteResponse.quoteCurrencyPrice ?? 1,
            fees: FeeBreakdown(
                providerFee: providerFee,
                providerFeePercentage: feePercentage,
                networkFee: networkFee,
                processingFee: 0,
                totalFee: providerFee + networkFee
            ),
            total: quoteRequest.amount + providerFee + networkFee,
            expiresAt: Date().addingTimeInterval(60),
            provider: .moonPay
        )
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
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PaymentError.networkError(URLError(.badServerResponse))
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 429 {
                throw PaymentError.rateLimited
            }
            throw PaymentError.providerError("HTTP \(httpResponse.statusCode)")
        }

        return data
    }

    private func mapMoonPayStatus(_ status: String) -> TransactionStatus.Status {
        switch status.lowercased() {
        case "waitingpayment":
            return .waitingForPayment
        case "pending":
            return .pending
        case "waitingauthorization", "pending3dsverification":
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

// MARK: - MoonPay API Response Models

private struct MoonPayTransactionResponse: Decodable {
    let id: String
    let status: String
    let currencyId: String
    let quoteCurrencyAmount: Decimal?
    let baseCurrencyAmount: Decimal
    let createdAt: Date
    let updatedAt: Date
    let completedAt: Date?
    let failureReason: String?
}

private struct MoonPayCurrency: Decodable {
    let code: String
    let name: String
    let type: String
    let minBuyAmount: Decimal?
    let maxBuyAmount: Decimal?
    let isSupportedInUS: Bool
}

private struct MoonPayQuoteResponse: Decodable {
    let baseCurrencyAmount: Decimal
    let quoteCurrencyAmount: Decimal?
    let quoteCurrencyPrice: Decimal?
    let feeAmount: Decimal?
    let networkFeeAmount: Decimal?
    let extraFeeAmount: Decimal?
    let totalAmount: Decimal
}
