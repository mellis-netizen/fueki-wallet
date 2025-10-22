import SwiftUI

struct AssetRow: View {
    let asset: Asset

    var body: some View {
        HStack(spacing: 12) {
            // Asset Icon
            AssetIcon(symbol: asset.symbol, size: 40)

            // Asset Info
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(asset.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Balance and Price
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(asset.value, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.semibold)

                HStack(spacing: 4) {
                    Image(systemName: asset.changePercent24h >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(abs(asset.changePercent24h), specifier: "%.2f")%")
                        .font(.caption)
                }
                .foregroundColor(asset.changePercent24h >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Asset Icon
struct AssetIcon: View {
    let symbol: String
    let size: CGFloat

    var backgroundColor: Color {
        // Generate color based on symbol
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .indigo]
        let index = abs(symbol.hashValue) % colors.count
        return colors[index]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.opacity(0.2))
                .frame(width: size, height: size)

            Text(String(symbol.prefix(1)))
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(backgroundColor)
        }
    }
}

// MARK: - Asset Model
struct Asset: Identifiable {
    let id = UUID()
    let name: String
    let symbol: String
    let balance: Double
    let price: Double
    let changePercent24h: Double

    var value: Double {
        balance * price
    }

    static func mockAssets() -> [Asset] {
        [
            Asset(name: "Bitcoin", symbol: "BTC", balance: 0.5, price: 45000, changePercent24h: 5.2),
            Asset(name: "Ethereum", symbol: "ETH", balance: 2.5, price: 3000, changePercent24h: 3.8),
            Asset(name: "Solana", symbol: "SOL", balance: 100, price: 120, changePercent24h: -2.1),
            Asset(name: "Cardano", symbol: "ADA", balance: 5000, price: 0.65, changePercent24h: 1.5),
            Asset(name: "Polkadot", symbol: "DOT", balance: 200, price: 8.5, changePercent24h: -0.8),
            Asset(name: "Polygon", symbol: "MATIC", balance: 3000, price: 0.85, changePercent24h: 4.2)
        ]
    }
}

// MARK: - Preview
struct AssetRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ForEach(Asset.mockAssets()) { asset in
                AssetRow(asset: asset)
            }
        }
        .padding()
    }
}
