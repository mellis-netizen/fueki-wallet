//
//  EnhancedComponents.swift
//  Fueki Wallet
//
//  Enhanced reusable UI components with accessibility
//

import SwiftUI

// MARK: - Transaction Models

struct Transaction: Identifiable {
    let id: String
    let type: TransactionType
    let assetSymbol: String
    let amount: Decimal
    let amountUSD: Decimal
    let timestamp: Date
    let status: TransactionStatus
    let fromAddress: String
    let toAddress: String
    let networkFee: Decimal?
    let transactionHash: String?
    let explorerURL: URL?
    let memo: String?

    init(
        id: String = UUID().uuidString,
        type: TransactionType,
        assetSymbol: String,
        amount: Decimal,
        amountUSD: Decimal,
        timestamp: Date = Date(),
        status: TransactionStatus = .confirmed,
        fromAddress: String = "",
        toAddress: String = "",
        networkFee: Decimal? = nil,
        transactionHash: String? = nil,
        explorerURL: URL? = nil,
        memo: String? = nil
    ) {
        self.id = id
        self.type = type
        self.assetSymbol = assetSymbol
        self.amount = amount
        self.amountUSD = amountUSD
        self.timestamp = timestamp
        self.status = status
        self.fromAddress = fromAddress
        self.toAddress = toAddress
        self.networkFee = networkFee
        self.transactionHash = transactionHash
        self.explorerURL = explorerURL
        self.memo = memo
    }
}

enum TransactionType {
    case send
    case receive
    case buy
    case sell

    var displayName: String {
        switch self {
        case .send: return "Sent"
        case .receive: return "Received"
        case .buy: return "Bought"
        case .sell: return "Sold"
        }
    }

    var icon: String {
        switch self {
        case .send: return "arrow.up.circle.fill"
        case .receive: return "arrow.down.circle.fill"
        case .buy: return "plus.circle.fill"
        case .sell: return "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .send: return .red
        case .receive: return .green
        case .buy: return .blue
        case .sell: return .orange
        }
    }
}

enum TransactionStatus {
    case pending
    case confirmed
    case failed

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .confirmed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Crypto Asset Model

struct CryptoAsset: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let balance: Decimal
    let priceUSD: Decimal
    let change24h: Double
    let icon: String
    let color: Color
    let blockchain: String

    var totalValueUSD: Decimal {
        balance * priceUSD
    }

    var changeColor: Color {
        change24h >= 0 ? .green : .red
    }

    var changeIcon: String {
        change24h >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    static func == (lhs: CryptoAsset, rhs: CryptoAsset) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Success Toast Component

struct SuccessToast: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack {
                Spacer()

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: isShowing)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isShowing = false
                    }
                }

                // Accessibility announcement
                AccessibilityAnnouncement.announce(message)

                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(message)
        }
    }
}

// MARK: - Asset Card Component

struct AssetCard: View {
    let asset: CryptoAsset
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
                    Text(asset.name)
                        .font(.headline)
                        .foregroundColor(Color("TextPrimary"))

                    HStack(spacing: 4) {
                        Text("\(asset.balance.formatted()) \(asset.symbol)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Image(systemName: asset.changeIcon)
                            .font(.caption2)
                            .foregroundColor(asset.changeColor)

                        Text("\(abs(asset.change24h), specifier: "%.2f")%")
                            .font(.caption)
                            .foregroundColor(asset.changeColor)
                    }
                }

                Spacer()

                // USD Value
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(asset.totalValueUSD.formatted())")
                        .font(.headline)
                        .foregroundColor(Color("TextPrimary"))

                    Text("$\(asset.priceUSD.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color("CardBackground"))
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        .accessibleButton(
            label: "\(asset.name), balance: \(asset.balance) \(asset.symbol), value: $\(asset.totalValueUSD.formatted())",
            hint: "Double tap for details"
        )
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color("TextPrimary"))
            }
        }
        .accessibleButton(
            label: title,
            hint: "Double tap to \(title.lowercased())"
        )
    }
}

// MARK: - Stats Card Component

struct StatsCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String?
    let trendValue: Double?

    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String? = nil,
        trendValue: Double? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.trendValue = trendValue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(Color("AccentPrimary"))
                }

                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                if let trend = trendValue {
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)

                        Text("\(abs(trend), specifier: "%.2f")%")
                            .font(.caption)
                    }
                    .foregroundColor(trend >= 0 ? .green : .red)
                }
            }

            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Color("TextPrimary"))
                .limitedDynamicType(max: .accessibility1)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color("CardBackground"))
        .cornerRadius(16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)" + (subtitle != nil ? ", \(subtitle!)" : ""))
    }
}

// MARK: - Input Field Component

struct InputField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(Color("TextPrimary"))

            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                }

                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                } else {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(.plain)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocapitalization)
                }
            }
            .padding(16)
            .background(Color("CardBackground"))
            .cornerRadius(12)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(text.isEmpty ? placeholder : text)")
    }
}

// MARK: - Section Header Component

struct SectionHeader: View {
    let title: String
    var action: (() -> Void)? = nil
    var actionTitle: String? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(Color("TextPrimary"))

            Spacer()

            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline)
                        .foregroundColor(Color("AccentPrimary"))
                }
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Chart Placeholder Component

struct ChartPlaceholder: View {
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let points = generateRandomPoints(width: geometry.size.width, height: height)
                path.move(to: points[0])
                for point in points.dropFirst() {
                    path.addLine(to: point)
                }
            }
            .stroke(
                LinearGradient(
                    colors: [Color("AccentPrimary"), Color("AccentPrimary").opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 2
            )
        }
        .frame(height: height)
    }

    private func generateRandomPoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let numberOfPoints = 20
        let step = width / CGFloat(numberOfPoints - 1)

        return (0..<numberOfPoints).map { index in
            CGPoint(
                x: CGFloat(index) * step,
                y: height * (0.3 + CGFloat.random(in: 0...0.4))
            )
        }
    }
}

// MARK: - Badge Component

struct Badge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .cornerRadius(6)
    }
}

// MARK: - Divider with Text

struct DividerWithText: View {
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
}

// MARK: - Preview Providers

#Preview("Asset Card") {
    AssetCard(
        asset: CryptoAsset(
            id: "btc",
            name: "Bitcoin",
            symbol: "BTC",
            balance: 0.5,
            priceUSD: 45000,
            change24h: 2.5,
            icon: "bitcoinsign.circle.fill",
            color: .orange,
            blockchain: "Bitcoin"
        ),
        onTap: {}
    )
    .padding()
}

#Preview("Stats Card") {
    StatsCard(
        title: "Total Balance",
        value: "$42,350.50",
        subtitle: "≈ 1.25 BTC",
        icon: "chart.line.uptrend.xyaxis",
        trendValue: 5.2
    )
    .padding()
}

#Preview("Action Buttons") {
    HStack(spacing: 16) {
        ActionButton(icon: "arrow.up", title: "Send", color: .red) {}
        ActionButton(icon: "arrow.down", title: "Receive", color: .green) {}
        ActionButton(icon: "arrow.2.squarepath", title: "Swap", color: .blue) {}
        ActionButton(icon: "plus", title: "Buy", color: .purple) {}
    }
    .padding()
}
