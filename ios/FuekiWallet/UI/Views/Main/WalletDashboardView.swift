import SwiftUI

struct WalletDashboardView: View {
    @EnvironmentObject var walletManager: WalletManager
    @StateObject private var viewModel = WalletDashboardViewModel()
    @State private var showSend = false
    @State private var showReceive = false
    @State private var showScanner = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        WalletHeader(
                            balance: viewModel.totalBalance,
                            change24h: viewModel.change24h
                        )
                        .padding(.top, 8)

                        // Quick Actions
                        QuickActionsView(
                            onSend: { showSend = true },
                            onReceive: { showReceive = true },
                            onScan: { showScanner = true }
                        )
                        .padding(.horizontal, 24)

                        // Portfolio Chart
                        PortfolioChartCard(data: viewModel.portfolioData)
                            .padding(.horizontal, 24)

                        // Top Assets
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Top Assets")
                                    .font(.headline)
                                Spacer()
                                NavigationLink(destination: AssetsListView()) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 24)

                            ForEach(viewModel.topAssets.prefix(3)) { asset in
                                AssetRow(asset: asset)
                                    .padding(.horizontal, 24)
                            }
                        }

                        // Recent Transactions
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recent Activity")
                                    .font(.headline)
                                Spacer()
                                NavigationLink(destination: ActivityView()) {
                                    Text("See All")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 24)

                            ForEach(viewModel.recentTransactions.prefix(5)) { transaction in
                                TransactionRow(transaction: transaction)
                                    .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Fueki Wallet")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showScanner = true }) {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
            .sheet(isPresented: $showSend) {
                SendView()
            }
            .sheet(isPresented: $showReceive) {
                ReceiveView()
            }
            .sheet(isPresented: $showScanner) {
                QRCodeScannerView { result in
                    // Handle scanned result
                    showScanner = false
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - Wallet Header
struct WalletHeader: View {
    let balance: Double
    let change24h: Double

    var changeColor: Color {
        change24h >= 0 ? .green : .red
    }

    var changeIcon: String {
        change24h >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Total Balance")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("$\(balance, specifier: "%.2f")")
                .font(.system(size: 42, weight: .bold))

            HStack(spacing: 6) {
                Image(systemName: changeIcon)
                    .font(.caption)
                Text("\(abs(change24h), specifier: "%.2f")%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("24h")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .foregroundColor(changeColor)
        }
        .padding(.vertical, 20)
    }
}

// MARK: - Quick Actions
struct QuickActionsView: View {
    let onSend: () -> Void
    let onReceive: () -> Void
    let onScan: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            QuickActionButton(
                icon: "arrow.up.circle.fill",
                title: "Send",
                color: .blue,
                action: onSend
            )

            QuickActionButton(
                icon: "arrow.down.circle.fill",
                title: "Receive",
                color: .green,
                action: onReceive
            )

            QuickActionButton(
                icon: "qrcode.viewfinder",
                title: "Scan",
                color: .purple,
                action: onScan
            )
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        Circle()
                            .fill(color)
                    )

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Portfolio Chart Card
struct PortfolioChartCard: View {
    let data: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Portfolio")
                .font(.headline)

            // Simple line chart placeholder
            GeometryReader { geometry in
                Path { path in
                    guard !data.isEmpty else { return }

                    let width = geometry.size.width
                    let height = geometry.size.height
                    let maxValue = data.max() ?? 1
                    let minValue = data.min() ?? 0
                    let range = maxValue - minValue

                    let stepX = width / CGFloat(data.count - 1)

                    for (index, value) in data.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = height - ((value - minValue) / range) * height

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)
            }
            .frame(height: 120)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - View Model
class WalletDashboardViewModel: ObservableObject {
    @Published var totalBalance: Double = 0.0
    @Published var change24h: Double = 0.0
    @Published var topAssets: [Asset] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var portfolioData: [Double] = []

    func loadData() async {
        // Load wallet data
        await MainActor.run {
            // Mock data for now
            totalBalance = 12543.67
            change24h = 5.23
            topAssets = Asset.mockAssets()
            recentTransactions = Transaction.mockTransactions()
            portfolioData = [100, 120, 115, 140, 135, 160, 155]
        }
    }

    func refresh() async {
        await loadData()
    }
}

// MARK: - Preview
struct WalletDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        WalletDashboardView()
            .environmentObject(WalletManager.shared)
    }
}
