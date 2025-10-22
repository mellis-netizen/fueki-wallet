//
//  AssetsViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine

/// ViewModel managing asset portfolio and token list
@MainActor
final class AssetsViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var assets: [Asset] = []
    @Published var filteredAssets: [Asset] = []
    @Published var searchQuery = ""
    @Published var sortOption: SortOption = .balanceDescending
    @Published var showZeroBalances = false

    // MARK: - State

    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Selection

    @Published var selectedAsset: Asset?

    // MARK: - Dependencies

    private let assetService: AssetServiceProtocol
    private let priceService: PriceServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        assetService: AssetServiceProtocol = AssetService.shared,
        priceService: PriceServiceProtocol = PriceService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.assetService = assetService
        self.priceService = priceService
        self.walletViewModel = walletViewModel
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Filter assets based on search and settings
        Publishers.CombineLatest3($assets, $searchQuery, $showZeroBalances)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .map { [weak self] assets, query, showZero in
                self?.filterAssets(assets, query: query, showZero: showZero) ?? []
            }
            .assign(to: &$filteredAssets)

        // Apply sorting
        Publishers.CombineLatest($filteredAssets, $sortOption)
            .map { [weak self] assets, option in
                self?.sortAssets(assets, by: option) ?? assets
            }
            .assign(to: &$filteredAssets)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Refresh when network changes
        walletViewModel.$selectedNetwork
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadAssets() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadAssets() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        isLoading = true
        errorMessage = nil

        do {
            let fetchedAssets = try await assetService.fetchAssets(
                for: wallet,
                network: walletViewModel.selectedNetwork
            )

            // Enrich with price data
            assets = try await enrichWithPrices(fetchedAssets)
        } catch {
            errorMessage = "Failed to load assets: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func refreshAssets() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        isRefreshing = true
        errorMessage = nil

        do {
            let fetchedAssets = try await assetService.fetchAssets(
                for: wallet,
                network: walletViewModel.selectedNetwork,
                forceRefresh: true
            )

            assets = try await enrichWithPrices(fetchedAssets)
        } catch {
            errorMessage = "Failed to refresh assets: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    private func enrichWithPrices(_ assets: [Asset]) async throws -> [Asset] {
        var enrichedAssets: [Asset] = []

        for asset in assets {
            var enriched = asset

            do {
                let priceData = try await priceService.fetchPrice(for: asset.contractAddress)
                enriched.currentPrice = priceData.currentPrice
                enriched.priceChange24h = priceData.change24h
                enriched.priceChangePercentage24h = priceData.changePercentage24h
            } catch {
                print("Failed to fetch price for \(asset.symbol): \(error)")
            }

            enrichedAssets.append(enriched)
        }

        return enrichedAssets
    }

    // MARK: - Asset Management

    func addCustomToken(contractAddress: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await assetService.addCustomToken(
                contractAddress: contractAddress,
                network: walletViewModel.selectedNetwork
            )

            assets.append(token)
        } catch {
            errorMessage = "Failed to add token: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func removeAsset(_ asset: Asset) async {
        do {
            try await assetService.removeAsset(asset)
            assets.removeAll { $0.id == asset.id }
        } catch {
            errorMessage = "Failed to remove asset: \(error.localizedDescription)"
        }
    }

    func toggleAssetVisibility(_ asset: Asset) async {
        guard let index = assets.firstIndex(where: { $0.id == asset.id }) else { return }

        assets[index].isHidden.toggle()

        do {
            try await assetService.updateAsset(assets[index])
        } catch {
            // Revert on error
            assets[index].isHidden.toggle()
            errorMessage = "Failed to update asset: \(error.localizedDescription)"
        }
    }

    // MARK: - Filtering & Sorting

    private func filterAssets(_ assets: [Asset], query: String, showZero: Bool) -> [Asset] {
        var filtered = assets

        // Filter by search query
        if !query.isEmpty {
            filtered = filtered.filter { asset in
                asset.name.localizedCaseInsensitiveContains(query) ||
                asset.symbol.localizedCaseInsensitiveContains(query) ||
                asset.contractAddress.localizedCaseInsensitiveContains(query)
            }
        }

        // Filter zero balances
        if !showZero {
            filtered = filtered.filter { $0.balance > 0 }
        }

        // Filter hidden assets
        filtered = filtered.filter { !$0.isHidden }

        return filtered
    }

    private func sortAssets(_ assets: [Asset], by option: SortOption) -> [Asset] {
        switch option {
        case .balanceDescending:
            return assets.sorted { ($0.balance * $0.currentPrice) > ($1.balance * $1.currentPrice) }
        case .balanceAscending:
            return assets.sorted { ($0.balance * $0.currentPrice) < ($1.balance * $1.currentPrice) }
        case .nameAscending:
            return assets.sorted { $0.name < $1.name }
        case .nameDescending:
            return assets.sorted { $0.name > $1.name }
        case .priceChangeDescending:
            return assets.sorted { $0.priceChangePercentage24h > $1.priceChangePercentage24h }
        case .priceChangeAscending:
            return assets.sorted { $0.priceChangePercentage24h < $1.priceChangePercentage24h }
        }
    }

    // MARK: - Computed Properties

    var totalPortfolioValue: Decimal {
        assets.reduce(0) { $0 + ($1.balance * $1.currentPrice) }
    }

    var totalPortfolioChange24h: Decimal {
        assets.reduce(0) { total, asset in
            let previousPrice = asset.currentPrice / (1 + (Decimal(asset.priceChangePercentage24h) / 100))
            let previousValue = asset.balance * previousPrice
            let currentValue = asset.balance * asset.currentPrice
            return total + (currentValue - previousValue)
        }
    }

    var totalPortfolioChangePercentage: Double {
        let currentValue = totalPortfolioValue
        let previousValue = currentValue - totalPortfolioChange24h

        guard previousValue > 0 else { return 0 }

        return Double(truncating: ((totalPortfolioChange24h / previousValue) * 100) as NSNumber)
    }
}

// MARK: - Models

struct Asset: Identifiable, Codable {
    let id: String
    let name: String
    let symbol: String
    let contractAddress: String
    let decimals: Int
    let logoURL: String?
    var balance: Decimal
    var currentPrice: Decimal
    var priceChange24h: Decimal
    var priceChangePercentage24h: Double
    var isHidden: Bool

    var balanceValue: Decimal {
        balance * currentPrice
    }

    var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8

        let number = NSDecimalNumber(decimal: balance)
        return formatter.string(from: number) ?? "0.00"
    }

    var formattedValue: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        let number = NSDecimalNumber(decimal: balanceValue)
        return formatter.string(from: number) ?? "$0.00"
    }
}

enum SortOption: String, CaseIterable {
    case balanceDescending = "Balance (High to Low)"
    case balanceAscending = "Balance (Low to High)"
    case nameAscending = "Name (A-Z)"
    case nameDescending = "Name (Z-A)"
    case priceChangeDescending = "Gainers"
    case priceChangeAscending = "Losers"
}

// MARK: - Service Protocol

protocol AssetServiceProtocol {
    func fetchAssets(for wallet: Wallet, network: Network, forceRefresh: Bool) async throws -> [Asset]
    func addCustomToken(contractAddress: String, network: Network) async throws -> Asset
    func removeAsset(_ asset: Asset) async throws
    func updateAsset(_ asset: Asset) async throws
}
