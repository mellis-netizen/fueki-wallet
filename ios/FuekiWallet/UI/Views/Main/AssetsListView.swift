import SwiftUI

struct AssetsListView: View {
    @StateObject private var viewModel = AssetsListViewModel()
    @State private var searchText = ""
    @State private var selectedAsset: Asset?

    var filteredAssets: [Asset] {
        if searchText.isEmpty {
            return viewModel.assets
        }
        return viewModel.assets.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search Bar
                    SearchBar(text: $searchText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    // Assets List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredAssets) { asset in
                                AssetRow(asset: asset)
                                    .padding(.horizontal, 16)
                                    .onTapGesture {
                                        selectedAsset = asset
                                    }
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationTitle("Assets")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedAsset) { asset in
                AssetDetailView(asset: asset)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadAssets()
            }
        }
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search assets", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
    }
}

// MARK: - Asset Detail View
struct AssetDetailView: View {
    let asset: Asset
    @Environment(\.dismiss) var dismiss
    @State private var selectedTimeframe: Timeframe = .day

    enum Timeframe: String, CaseIterable {
        case day = "1D"
        case week = "1W"
        case month = "1M"
        case year = "1Y"
        case all = "ALL"
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Asset Header
                    VStack(spacing: 12) {
                        AssetIcon(symbol: asset.symbol, size: 64)

                        Text(asset.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(asset.symbol)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Price Info
                    VStack(spacing: 8) {
                        Text("$\(asset.price, specifier: "%.2f")")
                            .font(.system(size: 36, weight: .bold))

                        HStack(spacing: 6) {
                            Image(systemName: asset.changePercent24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                            Text("\(abs(asset.changePercent24h), specifier: "%.2f")%")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(asset.changePercent24h >= 0 ? .green : .red)
                    }

                    // Timeframe Selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases, id: \.self) { timeframe in
                            Text(timeframe.rawValue).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)

                    // Holdings
                    HoldingsCard(asset: asset)
                        .padding(.horizontal, 16)

                    // Stats
                    StatsCard(asset: asset)
                        .padding(.horizontal, 16)

                    // Actions
                    HStack(spacing: 16) {
                        CustomButton(
                            title: "Send",
                            icon: "arrow.up.circle.fill",
                            style: .primary
                        ) {
                            // Handle send
                        }

                        CustomButton(
                            title: "Receive",
                            icon: "arrow.down.circle.fill",
                            style: .secondary
                        ) {
                            // Handle receive
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Holdings Card
struct HoldingsCard: View {
    let asset: Asset

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Your Holdings")
                    .font(.headline)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(asset.balance, specifier: "%.6f") \(asset.symbol)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(asset.value, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    let asset: Asset

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Statistics")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                StatRow(label: "Market Cap", value: "$1.2T")
                StatRow(label: "Volume 24h", value: "$45.6B")
                StatRow(label: "Circulating Supply", value: "19.2M")
                StatRow(label: "All Time High", value: "$69,000")
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - View Model
class AssetsListViewModel: ObservableObject {
    @Published var assets: [Asset] = []
    @Published var isLoading = false

    func loadAssets() async {
        await MainActor.run {
            assets = Asset.mockAssets()
        }
    }

    func refresh() async {
        await loadAssets()
    }
}

// MARK: - Preview
struct AssetsListView_Previews: PreviewProvider {
    static var previews: some View {
        AssetsListView()
    }
}
