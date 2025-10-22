//
//  WalletViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// Main ViewModel managing wallet state and coordination
@MainActor
final class WalletViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentWallet: Wallet?
    @Published var isLocked = true
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedNetwork: Network = .mainnet

    // MARK: - Balance State

    @Published var totalBalance: Decimal = 0
    @Published var totalBalanceUSD: Decimal = 0
    @Published var balanceChange24h: Decimal = 0
    @Published var balanceChangePercentage: Double = 0

    // MARK: - UI State

    @Published var showError = false
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?

    // MARK: - Dependencies

    private let walletService: WalletServiceProtocol
    private let balanceService: BalanceServiceProtocol
    private let priceService: PriceServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Timers

    private var balanceUpdateTimer: Timer?
    private let updateInterval: TimeInterval = 30 // 30 seconds

    // MARK: - Initialization

    init(
        walletService: WalletServiceProtocol = WalletService.shared,
        balanceService: BalanceServiceProtocol = BalanceService.shared,
        priceService: PriceServiceProtocol = PriceService.shared,
        biometricService: BiometricServiceProtocol = BiometricService.shared
    ) {
        self.walletService = walletService
        self.balanceService = balanceService
        self.priceService = priceService
        self.biometricService = biometricService
        setupBindings()
    }

    deinit {
        balanceUpdateTimer?.invalidate()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Auto-refresh when network changes
        $selectedNetwork
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.refreshBalance() }
            }
            .store(in: &cancellables)

        // Update USD values when balance changes
        Publishers.CombineLatest($totalBalance, $selectedNetwork)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] balance, network in
                Task { await self?.updateUSDValue() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Wallet Management

    func loadWallet() async {
        isLoading = true
        errorMessage = nil

        do {
            currentWallet = try await walletService.loadActiveWallet()

            if currentWallet != nil {
                await refreshBalance()
                startBalanceUpdates()
            }
        } catch {
            errorMessage = "Failed to load wallet: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func unlockWallet(withBiometric: Bool = true) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            if withBiometric {
                let authenticated = try await biometricService.authenticate()
                guard authenticated else {
                    throw WalletError.authenticationFailed
                }
            }

            guard let wallet = currentWallet else {
                throw WalletError.noActiveWallet
            }

            try await walletService.unlock(wallet)
            isLocked = false

            await refreshBalance()
            startBalanceUpdates()

            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }

        isLoading = false
    }

    func lockWallet() {
        walletService.lock()
        isLocked = true
        balanceUpdateTimer?.invalidate()
    }

    func switchNetwork(_ network: Network) async {
        selectedNetwork = network
        await refreshBalance()
    }

    // MARK: - Balance Management

    func refreshBalance() async {
        guard let wallet = currentWallet else { return }

        isRefreshing = true
        errorMessage = nil

        do {
            let balance = try await balanceService.fetchBalance(
                for: wallet,
                network: selectedNetwork
            )

            totalBalance = balance.total
            await updateUSDValue()
            await calculate24hChange()

            lastUpdated = Date()
        } catch {
            errorMessage = "Failed to refresh balance: \(error.localizedDescription)"
        }

        isRefreshing = false
    }

    private func updateUSDValue() async {
        do {
            let prices = try await priceService.fetchPrices(for: selectedNetwork)
            totalBalanceUSD = totalBalance * prices.currentPrice
        } catch {
            print("Failed to fetch USD prices: \(error)")
        }
    }

    private func calculate24hChange() async {
        do {
            let prices = try await priceService.fetchPrices(for: selectedNetwork)
            let previousValue = totalBalance * prices.price24hAgo

            balanceChange24h = totalBalanceUSD - previousValue

            if previousValue > 0 {
                balanceChangePercentage = Double(truncating: (balanceChange24h / previousValue * 100) as NSNumber)
            }
        } catch {
            print("Failed to calculate 24h change: \(error)")
        }
    }

    private func startBalanceUpdates() {
        balanceUpdateTimer?.invalidate()

        balanceUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: updateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { await self?.refreshBalance() }
        }
    }

    // MARK: - Formatted Values

    var formattedTotalBalance: String {
        formatCurrency(totalBalance, symbol: selectedNetwork.symbol)
    }

    var formattedUSDBalance: String {
        formatCurrency(totalBalanceUSD, symbol: "$")
    }

    var formatted24hChange: String {
        let prefix = balanceChange24h >= 0 ? "+" : ""
        return "\(prefix)\(formatCurrency(balanceChange24h, symbol: "$"))"
    }

    var formatted24hChangePercentage: String {
        let prefix = balanceChangePercentage >= 0 ? "+" : ""
        return String(format: "\(prefix)%.2f%%", balanceChangePercentage)
    }

    var changeColor: Color {
        balanceChange24h >= 0 ? .green : .red
    }

    // MARK: - Helpers

    private func formatCurrency(_ value: Decimal, symbol: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8

        let number = NSDecimalNumber(decimal: value)
        let formatted = formatter.string(from: number) ?? "0.00"

        return "\(symbol)\(formatted)"
    }
}

// MARK: - Models

struct Wallet: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let createdAt: Date
    var isActive: Bool
}

struct Network: Codable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let chainId: Int
    let rpcURL: String
    let explorerURL: String

    static let mainnet = Network(
        id: "ethereum-mainnet",
        name: "Ethereum Mainnet",
        symbol: "ETH",
        chainId: 1,
        rpcURL: "https://mainnet.infura.io/v3/",
        explorerURL: "https://etherscan.io"
    )

    static let testnet = Network(
        id: "ethereum-sepolia",
        name: "Sepolia Testnet",
        symbol: "ETH",
        chainId: 11155111,
        rpcURL: "https://sepolia.infura.io/v3/",
        explorerURL: "https://sepolia.etherscan.io"
    )
}

enum WalletError: LocalizedError {
    case noActiveWallet
    case authenticationFailed
    case unlockFailed
    case balanceFetchFailed

    var errorDescription: String? {
        switch self {
        case .noActiveWallet:
            return "No active wallet found"
        case .authenticationFailed:
            return "Authentication failed"
        case .unlockFailed:
            return "Failed to unlock wallet"
        case .balanceFetchFailed:
            return "Failed to fetch balance"
        }
    }
}

// MARK: - Additional Service Protocols

protocol BalanceServiceProtocol {
    func fetchBalance(for wallet: Wallet, network: Network) async throws -> WalletBalance
}

protocol PriceServiceProtocol {
    func fetchPrices(for network: Network) async throws -> PriceData
}

struct WalletBalance {
    let total: Decimal
    let available: Decimal
    let locked: Decimal
}

struct PriceData {
    let currentPrice: Decimal
    let price24hAgo: Decimal
    let volume24h: Decimal
    let marketCap: Decimal
}
