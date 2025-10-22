//
//  WalletDashboardView.swift
//  Fueki Wallet
//
//  Main wallet dashboard with balances and quick actions
//

import SwiftUI

struct WalletDashboardView: View {
    @EnvironmentObject var walletViewModel: WalletViewModel
    @State private var showAddAsset = false
    @State private var showBuySheet = false
    @State private var showSellSheet = false
    @State private var selectedAsset: CryptoAsset?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Total Balance Card
                    TotalBalanceCard(
                        totalBalance: walletViewModel.totalBalanceUSD,
                        percentageChange: walletViewModel.portfolioChange24h,
                        isLoading: walletViewModel.isLoading
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Quick Actions
                    QuickActionsView(
                        onBuy: { showBuySheet = true },
                        onSell: { showSellSheet = true }
                    )
                    .padding(.horizontal, 16)

                    // Assets Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Your Assets")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("TextPrimary"))

                            Spacer()

                            Button(action: { showAddAsset = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add")
                                }
                                .font(.subheadline)
                                .foregroundColor(Color("AccentPrimary"))
                            }
                        }
                        .padding(.horizontal, 16)

                        if walletViewModel.isLoading {
                            ForEach(0..<3, id: \.self) { _ in
                                AssetCardSkeleton()
                                    .padding(.horizontal, 16)
                            }
                        } else if walletViewModel.assets.isEmpty {
                            EmptyAssetsView()
                                .padding(.horizontal, 16)
                        } else {
                            ForEach(walletViewModel.assets) { asset in
                                AssetCard(asset: asset)
                                    .padding(.horizontal, 16)
                                    .onTapGesture {
                                        selectedAsset = asset
                                    }
                            }
                        }
                    }

                    // Market Trends (Optional)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Market Trends")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("TextPrimary"))
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(walletViewModel.marketTrends) { trend in
                                    MarketTrendCard(trend: trend)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
            }
            .background(Color("BackgroundPrimary").ignoresSafeArea())
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await walletViewModel.refreshBalances()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(Color("AccentPrimary"))
                    }
                }
            }
            .refreshable {
                await walletViewModel.refreshBalances()
            }
            .sheet(isPresented: $showBuySheet) {
                BuyCryptoView()
            }
            .sheet(isPresented: $showSellSheet) {
                SellCryptoView()
            }
            .sheet(item: $selectedAsset) { asset in
                AssetDetailView(asset: asset)
            }
        }
    }
}

// MARK: - Total Balance Card
struct TotalBalanceCard: View {
    let totalBalance: Decimal
    let percentageChange: Double
    let isLoading: Bool
    @State private var showBalance = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Total Balance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: { showBalance.toggle() }) {
                    Image(systemName: showBalance ? "eye.fill" : "eye.slash.fill")
                        .foregroundColor(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if isLoading {
                    ProgressView()
                } else {
                    Text(showBalance ? "$\(totalBalance.formatted())" : "••••••")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(Color("TextPrimary"))

                    HStack(spacing: 4) {
                        Image(systemName: percentageChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)

                        Text("\(abs(percentageChange), specifier: "%.2f")%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(percentageChange >= 0 ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (percentageChange >= 0 ? Color.green : Color.red).opacity(0.1)
                    )
                    .cornerRadius(8)
                }
            }

            Text("Last updated: \(Date(), style: .relative)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color("CardBackground"))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Quick Actions View
struct QuickActionsView: View {
    let onBuy: () -> Void
    let onSell: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(
                title: "Buy",
                icon: "plus.circle.fill",
                color: Color("AccentPrimary"),
                action: onBuy
            )

            QuickActionButton(
                title: "Sell",
                icon: "minus.circle.fill",
                color: Color("SecondaryAccent"),
                action: onSell
            )
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)

                Text(title)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(color)
            .cornerRadius(16)
        }
    }
}

// MARK: - Asset Card
struct AssetCard: View {
    let asset: CryptoAsset

    var body: some View {
        HStack(spacing: 16) {
            // Asset Icon
            ZStack {
                Circle()
                    .fill(asset.color.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: asset.icon)
                    .font(.title3)
                    .foregroundColor(asset.color)
            }

            // Asset Info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.symbol)
                    .font(.headline)
                    .foregroundColor(Color("TextPrimary"))

                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Balance and Price
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(asset.balance.formatted()) \(asset.symbol)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextPrimary"))

                Text("$\(asset.balanceUSD.formatted())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Price Change
            HStack(spacing: 2) {
                Image(systemName: asset.priceChange24h >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2)

                Text("\(abs(asset.priceChange24h), specifier: "%.2f")%")
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .foregroundColor(asset.priceChange24h >= 0 ? .green : .red)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                (asset.priceChange24h >= 0 ? Color.green : Color.red).opacity(0.1)
            )
            .cornerRadius(6)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("CardBackground"))
        )
    }
}

// MARK: - Empty Assets View
struct EmptyAssetsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bitcoinsign.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Assets Yet")
                .font(.headline)
                .foregroundColor(Color("TextPrimary"))

            Text("Add cryptocurrency to your wallet to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Asset Card Skeleton
struct AssetCardSkeleton: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 16)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 12)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 14)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 12)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("CardBackground"))
        )
        .opacity(isAnimating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear { isAnimating = true }
    }
}

// MARK: - Market Trend Card
struct MarketTrendCard: View {
    let trend: MarketTrend

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: trend.icon)
                    .foregroundColor(trend.color)

                Text(trend.symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("TextPrimary"))
            }

            Text("$\(trend.price.formatted())")
                .font(.headline)
                .foregroundColor(Color("TextPrimary"))

            HStack(spacing: 4) {
                Image(systemName: trend.change >= 0 ? "arrow.up" : "arrow.down")
                    .font(.caption2)

                Text("\(abs(trend.change), specifier: "%.2f")%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(trend.change >= 0 ? .green : .red)
        }
        .padding(12)
        .frame(width: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("CardBackground"))
        )
    }
}

#Preview {
    WalletDashboardView()
        .environmentObject(WalletViewModel())
}
