//
//  WalletState.swift
//  Fueki Wallet
//
//  Wallet state management with multi-chain support
//

import Foundation
import Combine
import SwiftUI

@MainActor
class WalletState: ObservableObject {
    // MARK: - Published Properties
    @Published var wallets: [Wallet] = []
    @Published var activeWallet: Wallet?
    @Published var balances: [String: Balance] = [:] // assetId -> Balance
    @Published var totalValue: Decimal = 0
    @Published var preferredCurrency: Currency = .usd
    @Published var isRefreshing = false
    @Published var lastUpdate: Date?

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let balanceUpdateInterval: TimeInterval = 30 // 30 seconds
    private var balanceUpdateTimer: Timer?

    // MARK: - Initialization
    init() {
        setupBalanceMonitoring()
    }

    // MARK: - Wallet Management

    func addWallet(_ wallet: Wallet) {
        wallets.append(wallet)

        if activeWallet == nil {
            setActiveWallet(wallet)
        }

        notifyStateChange()
    }

    func removeWallet(_ walletId: String) {
        wallets.removeAll { $0.id == walletId }

        if activeWallet?.id == walletId {
            activeWallet = wallets.first
        }

        notifyStateChange()
    }

    func setActiveWallet(_ wallet: Wallet) {
        activeWallet = wallet
        Task {
            await refreshBalances()
        }
        notifyStateChange()
    }

    func updateWalletName(_ walletId: String, name: String) {
        if let index = wallets.firstIndex(where: { $0.id == walletId }) {
            wallets[index].name = name

            if activeWallet?.id == walletId {
                activeWallet?.name = name
            }

            notifyStateChange()
        }
    }

    // MARK: - Balance Management

    func refreshBalances() async {
        guard !isRefreshing else { return }

        isRefreshing = true

        do {
            // Fetch balances for all assets in active wallet
            if let wallet = activeWallet {
                let newBalances = try await fetchBalances(for: wallet)

                await MainActor.run {
                    self.balances = newBalances
                    self.calculateTotalValue()
                    self.lastUpdate = Date()
                    self.isRefreshing = false
                }
            }
        } catch {
            await MainActor.run {
                self.isRefreshing = false
            }
            print("Failed to refresh balances: \(error)")
        }
    }

    func updateBalance(assetId: String, balance: Balance) {
        balances[assetId] = balance
        calculateTotalValue()
        notifyStateChange()
    }

    // MARK: - Asset Management

    func addAsset(to walletId: String, asset: CryptoAsset) {
        if let index = wallets.firstIndex(where: { $0.id == walletId }) {
            var wallet = wallets[index]
            if !wallet.assets.contains(where: { $0.id == asset.id }) {
                wallet.assets.append(asset)
                wallets[index] = wallet

                if activeWallet?.id == walletId {
                    activeWallet = wallet
                }

                notifyStateChange()
            }
        }
    }

    func removeAsset(from walletId: String, assetId: String) {
        if let index = wallets.firstIndex(where: { $0.id == walletId }) {
            var wallet = wallets[index]
            wallet.assets.removeAll { $0.id == assetId }
            wallets[index] = wallet

            if activeWallet?.id == walletId {
                activeWallet = wallet
            }

            balances.removeValue(forKey: assetId)
            calculateTotalValue()
            notifyStateChange()
        }
    }

    // MARK: - Currency Management

    func setPreferredCurrency(_ currency: Currency) {
        preferredCurrency = currency
        calculateTotalValue()
        notifyStateChange()
    }

    // MARK: - State Management

    func reset() {
        wallets = []
        activeWallet = nil
        balances = [:]
        totalValue = 0
        isRefreshing = false
        lastUpdate = nil
        balanceUpdateTimer?.invalidate()
        balanceUpdateTimer = nil
    }

    // MARK: - Snapshot Management

    func createSnapshot() -> WalletStateSnapshot {
        WalletStateSnapshot(
            wallets: wallets,
            activeWalletId: activeWallet?.id,
            balances: balances,
            preferredCurrency: preferredCurrency,
            lastUpdate: lastUpdate
        )
    }

    func restore(from snapshot: WalletStateSnapshot) async {
        wallets = snapshot.wallets
        activeWallet = wallets.first { $0.id == snapshot.activeWalletId }
        balances = snapshot.balances
        preferredCurrency = snapshot.preferredCurrency
        lastUpdate = snapshot.lastUpdate

        calculateTotalValue()
        startBalanceUpdateTimer()
    }

    // MARK: - Private Methods

    private func setupBalanceMonitoring() {
        startBalanceUpdateTimer()
    }

    private func startBalanceUpdateTimer() {
        balanceUpdateTimer?.invalidate()

        balanceUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: balanceUpdateInterval,
            repeats: true
        ) { [weak self] _ in
            Task {
                await self?.refreshBalances()
            }
        }
    }

    private func calculateTotalValue() {
        totalValue = balances.values.reduce(0) { total, balance in
            total + balance.fiatValue(in: preferredCurrency)
        }
    }

    private func fetchBalances(for wallet: Wallet) async throws -> [String: Balance] {
        var newBalances: [String: Balance] = [:]

        for asset in wallet.assets {
            // Fetch balance from blockchain
            // In production, this would call actual blockchain APIs
            // For now, simulate with random values for testing
            let balance = Balance(
                amount: Decimal(Double.random(in: 0...10)),
                asset: asset,
                fiatPrice: Decimal(Double.random(in: 100...50000))
            )
            newBalances[asset.id] = balance
        }

        return newBalances
    }

    private func notifyStateChange() {
        NotificationCenter.default.post(
            name: .walletStateChanged,
            object: createSnapshot()
        )
    }
}

// MARK: - Supporting Types

struct Wallet: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var assets: [CryptoAsset]
    let createdAt: Date

    init(id: String = UUID().uuidString, name: String, assets: [CryptoAsset] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.assets = assets
        self.createdAt = createdAt
    }
}

struct Balance: Codable {
    let amount: Decimal
    let asset: CryptoAsset
    let fiatPrice: Decimal

    func fiatValue(in currency: Currency) -> Decimal {
        amount * fiatPrice
    }
}

enum Currency: String, Codable, CaseIterable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        }
    }
}

struct WalletStateSnapshot: Codable {
    let wallets: [Wallet]
    let activeWalletId: String?
    let balances: [String: Balance]
    let preferredCurrency: Currency
    let lastUpdate: Date?
}

// MARK: - Notifications

extension Notification.Name {
    static let walletStateChanged = Notification.Name("walletStateChanged")
    static let balanceUpdated = Notification.Name("balanceUpdated")
}
