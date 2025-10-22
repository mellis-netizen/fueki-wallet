//
//  WalletViewModel.swift
//  Fueki Wallet
//
//  Wallet state management with asset and transaction handling
//

import SwiftUI
import Combine

@MainActor
class WalletViewModel: ObservableObject {
    @Published var assets: [CryptoAsset] = []
    @Published var supportedAssets: [CryptoAsset] = []
    @Published var transactions: [Transaction] = []
    @Published var marketTrends: [MarketTrend] = []
    @Published var isLoading = false
    @Published var isLoadingTransactions = false
    @Published var totalBalanceUSD: Decimal = 0
    @Published var portfolioChange24h: Double = 0
    @Published var errorMessage: String?

    private let walletService: WalletService
    private let priceService: PriceService
    private var cancellables = Set<AnyCancellable>()

    init(
        walletService: WalletService = .shared,
        priceService: PriceService = .shared
    ) {
        self.walletService = walletService
        self.priceService = priceService
    }

    // MARK: - Initialization

    func initialize() async {
        isLoading = true

        await loadAssets()
        await loadTransactions()
        await loadMarketTrends()
        calculateTotalBalance()

        isLoading = false

        // Start periodic price updates
        startPriceUpdates()
    }

    // MARK: - Asset Management

    func loadAssets() async {
        do {
            assets = try await walletService.getAssets()
            supportedAssets = try await walletService.getSupportedAssets()
        } catch {
            errorMessage = "Failed to load assets: \(error.localizedDescription)"
            // Use sample data for development
            assets = CryptoAsset.samples
            supportedAssets = CryptoAsset.samples
        }
    }

    func refreshBalances() async {
        await loadAssets()
        await updatePrices()
        calculateTotalBalance()
    }

    // MARK: - Transaction Management

    func loadTransactions() async {
        isLoadingTransactions = true

        do {
            transactions = try await walletService.getTransactions()
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
            // Use sample data for development
            transactions = Transaction.samples
        }

        isLoadingTransactions = false
    }

    func refreshTransactions() async {
        await loadTransactions()
    }

    // MARK: - Market Data

    func loadMarketTrends() async {
        do {
            marketTrends = try await priceService.getMarketTrends()
        } catch {
            // Use sample data for development
            marketTrends = MarketTrend.samples
        }
    }

    // MARK: - Price Updates

    private func startPriceUpdates() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.updatePrices()
                }
            }
            .store(in: &cancellables)
    }

    private func updatePrices() async {
        do {
            let prices = try await priceService.getPrices(
                for: assets.map { $0.symbol }
            )

            for i in 0..<assets.count {
                if let price = prices[assets[i].symbol] {
                    assets[i].priceUSD = price.usd
                    assets[i].priceChange24h = price.change24h
                    assets[i].balanceUSD = assets[i].balance * price.usd
                }
            }

            calculateTotalBalance()
        } catch {
            print("Failed to update prices: \(error)")
        }
    }

    // MARK: - Calculations

    private func calculateTotalBalance() {
        totalBalanceUSD = assets.reduce(0) { $0 + $1.balanceUSD }

        let totalChange = assets.reduce(0.0) { total, asset in
            let weight = Double(truncating: asset.balanceUSD as NSNumber) / Double(truncating: totalBalanceUSD as NSNumber)
            return total + (asset.priceChange24h * weight)
        }
        portfolioChange24h = totalChange
    }
}

// MARK: - Wallet Service
class WalletService {
    static let shared = WalletService()

    func getAssets() async throws -> [CryptoAsset] {
        // TODO: Implement real API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return CryptoAsset.samples
    }

    func getSupportedAssets() async throws -> [CryptoAsset] {
        // TODO: Implement real API call
        try await Task.sleep(nanoseconds: 500_000_000)
        return CryptoAsset.samples
    }

    func getTransactions() async throws -> [Transaction] {
        // TODO: Implement real API call
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return Transaction.samples
    }
}

// MARK: - Price Service
class PriceService {
    static let shared = PriceService()

    struct Price {
        let usd: Decimal
        let change24h: Double
    }

    func getPrices(for symbols: [String]) async throws -> [String: Price] {
        // TODO: Implement real price API (CoinGecko, etc.)
        try await Task.sleep(nanoseconds: 500_000_000)

        return [
            "BTC": Price(usd: 43000.00, change24h: 2.5),
            "ETH": Price(usd: 2200.00, change24h: -1.2),
            "SOL": Price(usd: 95.00, change24h: 5.8)
        ]
    }

    func getMarketTrends() async throws -> [MarketTrend] {
        // TODO: Implement real market data API
        try await Task.sleep(nanoseconds: 500_000_000)
        return MarketTrend.samples
    }
}
