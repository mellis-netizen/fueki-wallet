//
//  AssetViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// Comprehensive ViewModel for asset management and portfolio tracking
@MainActor
final class AssetViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var assets: [Asset] = []
    @Published var filteredAssets: [Asset] = []
    @Published var selectedAsset: Asset?

    // MARK: - Portfolio Summary

    @Published var totalPortfolioValue: Decimal = 0
    @Published var totalPortfolioValueUSD: Decimal = 0
    @Published var portfolioChange24h: Decimal = 0
    @Published var portfolioChangePercentage: Double = 0

    // MARK: - Asset Details

    @Published var assetPrice: Decimal = 0
    @Published var assetPriceChange24h: Decimal = 0
    @Published var assetPriceChangePercentage: Double = 0
    @Published var assetMarketCap: Decimal = 0
    @Published var assetVolume24h: Decimal = 0
    @Published var assetSupply: Decimal = 0
    @Published var assetRank: Int?

    // MARK: - Price History

    @Published var priceHistory: [PricePoint] = []
    @Published var selectedTimeRange: TimeRange = .day
    @Published var chartData: [ChartDataPoint] = []

    // MARK: - Token Management

    @Published var customTokens: [CustomToken] = []
    @Published var showAddToken = false
    @Published var newTokenAddress = ""
    @Published var newTokenName = ""
    @Published var newTokenSymbol = ""
    @Published var newTokenDecimals = 18

    // MARK: - Filters & Sorting

    @Published var sortOption: AssetSortOption = .balance
    @Published var filterOption: AssetFilterOption = .all
    @Published var searchQuery = ""
    @Published var hideSmallBalances = false
    @Published var smallBalanceThreshold: Decimal = 1.0

    // MARK: - UI State

    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingPriceHistory = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var lastUpdated: Date?

    // MARK: - Watchlist

    @Published var watchlist: [String] = []
    @Published var showWatchlist = false

    // MARK: - Token Discovery

    @Published var popularTokens: [TokenInfo] = []
    @Published var trendingTokens: [TokenInfo] = []
    @Published var newTokens: [TokenInfo] = []
    @Published var showTokenDiscovery = false

    // MARK: - Analytics

    @Published var portfolioAllocation: [AllocationData] = []
    @Published var topGainers: [Asset] = []
    @Published var topLosers: [Asset] = []
    @Published var showAnalytics = false

    // MARK: - Dependencies

    private let assetService: AssetServiceProtocol
    private let priceService: PriceServiceProtocol
    private let tokenService: TokenServiceProtocol
    private let chartService: ChartServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Timers

    private var priceUpdateTimer: Timer?
    private let updateInterval: TimeInterval = 30

    // MARK: - Initialization

    init(
        assetService: AssetServiceProtocol = AssetService.shared,
        priceService: PriceServiceProtocol = PriceService.shared,
        tokenService: TokenServiceProtocol = TokenService.shared,
        chartService: ChartServiceProtocol = ChartService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.assetService = assetService
        self.priceService = priceService
        self.tokenService = tokenService
        self.chartService = chartService
        self.walletViewModel = walletViewModel
        setupBindings()
    }

    deinit {
        priceUpdateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Filter and sort assets
        Publishers.CombineLatest4(
            $assets,
            $sortOption,
            $filterOption,
            $hideSmallBalances
        )
        .combineLatest($searchQuery)
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .map { [weak self] combined, search in
            let (assets, sort, filter, hideSmall) = combined
            return self?.filterAndSort(
                assets: assets,
                sort: sort,
                filter: filter,
                hideSmall: hideSmall,
                search: search
            ) ?? []
        }
        .assign(to: &$filteredAssets)

        // Calculate portfolio totals
        $assets
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] assets in
                self?.calculatePortfolioTotals(assets)
            }
            .store(in: &cancellables)

        // Update chart when time range changes
        Publishers.CombineLatest($selectedAsset, $selectedTimeRange)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] asset, timeRange in
                guard let asset = asset else { return }
                Task { await self?.loadPriceHistory(for: asset, timeRange: timeRange) }
            }
            .store(in: &cancellables)

        // Load asset details when selected
        $selectedAsset
            .dropFirst()
            .sink { [weak self] asset in
                guard let asset = asset else { return }
                Task { await self?.loadAssetDetails(asset) }
            }
            .store(in: &cancellables)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Update analytics
        $assets
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] assets in
                self?.updateAnalytics(assets)
            }
            .store(in: &cancellables)

        // Network changes reload assets
        walletViewModel.$selectedNetwork
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadAssets() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Asset Loading

    func loadAssets() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        isLoading = true
        errorMessage = nil

        do {
            let loadedAssets = try await assetService.fetchAssets(
                for: wallet,
                network: walletViewModel.selectedNetwork
            )

            assets = loadedAssets
            await loadCustomTokens()
            startPriceUpdates()

            lastUpdated = Date()
        } catch {
            errorMessage = "Failed to load assets: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func refreshAssets() async {
        isRefreshing = true

        await loadAssets()

        isRefreshing = false
    }

    private func startPriceUpdates() {
        priceUpdateTimer?.invalidate()

        priceUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.updatePrices() }
        }
    }

    private func updatePrices() async {
        guard !assets.isEmpty else { return }

        do {
            let prices = try await priceService.fetchPrices(
                for: assets.map { $0.symbol },
                network: walletViewModel.selectedNetwork
            )

            for (index, asset) in assets.enumerated() {
                if let priceData = prices[asset.symbol] {
                    assets[index].currentPrice = priceData.currentPrice
                    assets[index].priceChange24h = priceData.change24h
                    assets[index].priceChangePercentage24h = priceData.changePercentage24h
                }
            }

            lastUpdated = Date()
        } catch {
            print("Failed to update prices: \(error)")
        }
    }

    // MARK: - Asset Details

    func loadAssetDetails(_ asset: Asset) async {
        do {
            let details = try await assetService.fetchAssetDetails(
                asset: asset,
                network: walletViewModel.selectedNetwork
            )

            assetPrice = details.price
            assetPriceChange24h = details.priceChange24h
            assetPriceChangePercentage = details.priceChangePercentage24h
            assetMarketCap = details.marketCap
            assetVolume24h = details.volume24h
            assetSupply = details.circulatingSupply
            assetRank = details.marketCapRank

            await loadPriceHistory(for: asset, timeRange: selectedTimeRange)
        } catch {
            errorMessage = "Failed to load asset details: \(error.localizedDescription)"
        }
    }

    func loadPriceHistory(for asset: Asset, timeRange: TimeRange) async {
        isLoadingPriceHistory = true

        do {
            let history = try await chartService.fetchPriceHistory(
                for: asset,
                timeRange: timeRange,
                network: walletViewModel.selectedNetwork
            )

            priceHistory = history
            chartData = convertToChartData(history)
        } catch {
            errorMessage = "Failed to load price history: \(error.localizedDescription)"
        }

        isLoadingPriceHistory = false
    }

    private func convertToChartData(_ history: [PricePoint]) -> [ChartDataPoint] {
        history.map { point in
            ChartDataPoint(
                date: point.timestamp,
                value: Double(truncating: point.price as NSNumber)
            )
        }
    }

    // MARK: - Custom Tokens

    func loadCustomTokens() async {
        do {
            customTokens = try await tokenService.fetchCustomTokens()

            // Merge with assets
            for token in customTokens {
                if !assets.contains(where: { $0.contractAddress == token.address }) {
                    let asset = Asset(from: token)
                    assets.append(asset)
                }
            }
        } catch {
            print("Failed to load custom tokens: \(error)")
        }
    }

    func addCustomToken() async -> Bool {
        guard !newTokenAddress.isEmpty else {
            errorMessage = "Token address is required"
            return false
        }

        isLoading = true

        do {
            // Validate and fetch token info
            let tokenInfo = try await tokenService.validateAndFetchTokenInfo(
                address: newTokenAddress,
                network: walletViewModel.selectedNetwork
            )

            // Use fetched info or manual input
            let token = CustomToken(
                address: newTokenAddress,
                name: !newTokenName.isEmpty ? newTokenName : tokenInfo.name,
                symbol: !newTokenSymbol.isEmpty ? newTokenSymbol : tokenInfo.symbol,
                decimals: newTokenDecimals != 18 ? newTokenDecimals : tokenInfo.decimals,
                network: walletViewModel.selectedNetwork
            )

            try await tokenService.saveCustomToken(token)

            customTokens.append(token)
            assets.append(Asset(from: token))

            resetAddTokenForm()
            showAddToken = false

            return true
        } catch {
            errorMessage = "Failed to add token: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func removeCustomToken(_ token: CustomToken) async {
        do {
            try await tokenService.removeCustomToken(token)

            customTokens.removeAll { $0.id == token.id }
            assets.removeAll { $0.contractAddress == token.address }
        } catch {
            errorMessage = "Failed to remove token: \(error.localizedDescription)"
        }
    }

    private func resetAddTokenForm() {
        newTokenAddress = ""
        newTokenName = ""
        newTokenSymbol = ""
        newTokenDecimals = 18
    }

    // MARK: - Watchlist

    func addToWatchlist(_ asset: Asset) {
        if !watchlist.contains(asset.symbol) {
            watchlist.append(asset.symbol)
            saveWatchlist()
        }
    }

    func removeFromWatchlist(_ asset: Asset) {
        watchlist.removeAll { $0 == asset.symbol }
        saveWatchlist()
    }

    func isInWatchlist(_ asset: Asset) -> Bool {
        watchlist.contains(asset.symbol)
    }

    private func saveWatchlist() {
        UserDefaults.standard.set(watchlist, forKey: "asset_watchlist")
    }

    private func loadWatchlist() {
        watchlist = UserDefaults.standard.stringArray(forKey: "asset_watchlist") ?? []
    }

    // MARK: - Token Discovery

    func loadTokenDiscovery() async {
        do {
            async let popular = tokenService.fetchPopularTokens(network: walletViewModel.selectedNetwork)
            async let trending = tokenService.fetchTrendingTokens(network: walletViewModel.selectedNetwork)
            async let new = tokenService.fetchNewTokens(network: walletViewModel.selectedNetwork)

            popularTokens = try await popular
            trendingTokens = try await trending
            newTokens = try await new
        } catch {
            errorMessage = "Failed to load token discovery: \(error.localizedDescription)"
        }
    }

    func addDiscoveredToken(_ tokenInfo: TokenInfo) async {
        newTokenAddress = tokenInfo.address
        newTokenName = tokenInfo.name
        newTokenSymbol = tokenInfo.symbol
        newTokenDecimals = tokenInfo.decimals

        _ = await addCustomToken()
    }

    // MARK: - Analytics

    private func updateAnalytics(_ assets: [Asset]) {
        // Portfolio allocation
        let totalValue = assets.reduce(Decimal(0)) { $0 + $1.totalValue }

        portfolioAllocation = assets.map { asset in
            let percentage = totalValue > 0 ? (asset.totalValue / totalValue * 100) : 0
            return AllocationData(
                asset: asset,
                percentage: Double(truncating: percentage as NSNumber)
            )
        }.sorted { $0.percentage > $1.percentage }

        // Top gainers and losers
        let sortedByChange = assets.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }
        topGainers = Array(sortedByChange.prefix(5))
        topLosers = Array(sortedByChange.suffix(5).reversed())
    }

    // MARK: - Portfolio Calculations

    private func calculatePortfolioTotals(_ assets: [Asset]) {
        totalPortfolioValue = assets.reduce(0) { $0 + $1.balance }

        totalPortfolioValueUSD = assets.reduce(0) { $0 + $1.totalValue }

        let previousValue = assets.reduce(Decimal(0)) { total, asset in
            total + (asset.balance * (asset.currentPrice - asset.priceChange24h))
        }

        portfolioChange24h = totalPortfolioValueUSD - previousValue

        if previousValue > 0 {
            portfolioChangePercentage = Double(truncating: (portfolioChange24h / previousValue * 100) as NSNumber)
        }
    }

    // MARK: - Filtering & Sorting

    private func filterAndSort(
        assets: [Asset],
        sort: AssetSortOption,
        filter: AssetFilterOption,
        hideSmall: Bool,
        search: String
    ) -> [Asset] {
        var filtered = assets

        // Apply filter
        switch filter {
        case .all:
            break
        case .tokens:
            filtered = filtered.filter { $0.type == .token }
        case .nativeCoins:
            filtered = filtered.filter { $0.type == .native }
        case .stablecoins:
            filtered = filtered.filter { $0.isStablecoin }
        case .watchlist:
            filtered = filtered.filter { watchlist.contains($0.symbol) }
        }

        // Hide small balances
        if hideSmall {
            filtered = filtered.filter { $0.totalValue >= smallBalanceThreshold }
        }

        // Apply search
        if !search.isEmpty {
            filtered = filtered.filter { asset in
                asset.name.localizedCaseInsensitiveContains(search) ||
                asset.symbol.localizedCaseInsensitiveContains(search) ||
                (asset.contractAddress?.localizedCaseInsensitiveContains(search) ?? false)
            }
        }

        // Apply sort
        switch sort {
        case .balance:
            filtered.sort { $0.totalValue > $1.totalValue }
        case .name:
            filtered.sort { $0.name < $1.name }
        case .price:
            filtered.sort { $0.currentPrice > $1.currentPrice }
        case .change24h:
            filtered.sort { $0.priceChangePercentage24h > $1.priceChangePercentage24h }
        }

        return filtered
    }

    // MARK: - Formatted Values

    var formattedTotalPortfolioValue: String {
        formatCurrency(totalPortfolioValueUSD)
    }

    var formattedPortfolioChange: String {
        let prefix = portfolioChange24h >= 0 ? "+" : ""
        return "\(prefix)\(formatCurrency(portfolioChange24h))"
    }

    var formattedPortfolioChangePercentage: String {
        let prefix = portfolioChangePercentage >= 0 ? "+" : ""
        return String(format: "\(prefix)%.2f%%", portfolioChangePercentage)
    }

    var portfolioChangeColor: Color {
        portfolioChange24h >= 0 ? .green : .red
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Supporting Types

struct Asset: Identifiable, Codable {
    let id: String
    var name: String
    var symbol: String
    var balance: Decimal
    var currentPrice: Decimal
    var priceChange24h: Decimal
    var priceChangePercentage24h: Double
    var contractAddress: String?
    var decimals: Int
    var type: AssetType
    var isStablecoin: Bool

    var totalValue: Decimal {
        balance * currentPrice
    }

    init(from token: CustomToken) {
        self.id = token.id
        self.name = token.name
        self.symbol = token.symbol
        self.balance = 0
        self.currentPrice = 0
        self.priceChange24h = 0
        self.priceChangePercentage24h = 0
        self.contractAddress = token.address
        self.decimals = token.decimals
        self.type = .token
        self.isStablecoin = false
    }
}

enum AssetType: String, Codable {
    case native
    case token
}

enum AssetSortOption: String, CaseIterable {
    case balance = "Balance"
    case name = "Name"
    case price = "Price"
    case change24h = "24h Change"
}

enum AssetFilterOption: String, CaseIterable {
    case all = "All"
    case tokens = "Tokens"
    case nativeCoins = "Native Coins"
    case stablecoins = "Stablecoins"
    case watchlist = "Watchlist"
}

enum TimeRange: String, CaseIterable {
    case hour = "1H"
    case day = "24H"
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case year = "1Y"
    case all = "All"

    var interval: TimeInterval {
        switch self {
        case .hour: return 3600
        case .day: return 86400
        case .week: return 604800
        case .month: return 2592000
        case .threeMonths: return 7776000
        case .year: return 31536000
        case .all: return .greatestFiniteMagnitude
        }
    }
}

struct PricePoint: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let price: Decimal
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct CustomToken: Identifiable, Codable {
    let id = UUID().uuidString
    let address: String
    let name: String
    let symbol: String
    let decimals: Int
    let network: Network
}

struct TokenInfo: Identifiable, Codable {
    let id = UUID()
    let address: String
    let name: String
    let symbol: String
    let decimals: Int
    let logoURL: String?
    let marketCap: Decimal?
    let volume24h: Decimal?
}

struct AllocationData: Identifiable {
    let id = UUID()
    let asset: Asset
    let percentage: Double
}

struct AssetDetails {
    let price: Decimal
    let priceChange24h: Decimal
    let priceChangePercentage24h: Double
    let marketCap: Decimal
    let volume24h: Decimal
    let circulatingSupply: Decimal
    let marketCapRank: Int?
}

// MARK: - Service Protocols

protocol AssetServiceProtocol {
    func fetchAssets(for wallet: Wallet, network: Network) async throws -> [Asset]
    func fetchAssetDetails(asset: Asset, network: Network) async throws -> AssetDetails
}

protocol TokenServiceProtocol {
    func fetchCustomTokens() async throws -> [CustomToken]
    func validateAndFetchTokenInfo(address: String, network: Network) async throws -> TokenInfo
    func saveCustomToken(_ token: CustomToken) async throws
    func removeCustomToken(_ token: CustomToken) async throws
    func fetchPopularTokens(network: Network) async throws -> [TokenInfo]
    func fetchTrendingTokens(network: Network) async throws -> [TokenInfo]
    func fetchNewTokens(network: Network) async throws -> [TokenInfo]
}

protocol ChartServiceProtocol {
    func fetchPriceHistory(for asset: Asset, timeRange: TimeRange, network: Network) async throws -> [PricePoint]
}

extension PriceServiceProtocol {
    func fetchPrices(for symbols: [String], network: Network) async throws -> [String: PriceData] {
        var result: [String: PriceData] = [:]
        for symbol in symbols {
            let priceData = try await fetchPrices(for: network)
            result[symbol] = priceData
        }
        return result
    }
}
