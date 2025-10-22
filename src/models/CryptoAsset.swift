//
//  CryptoAsset.swift
//  Fueki Wallet
//
//  Crypto asset model with balance and price information
//

import SwiftUI
import Foundation

struct CryptoAsset: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let icon: String
    let color: Color
    let address: String
    var balance: Decimal
    var balanceUSD: Decimal
    var priceUSD: Decimal
    var priceChange24h: Double
    let blockchain: String
    let decimals: Int

    var formattedBalance: String {
        balance.formatted()
    }

    var formattedBalanceUSD: String {
        "$\(balanceUSD.formatted())"
    }

    var formattedPrice: String {
        "$\(priceUSD.formatted())"
    }

    // Custom encoding/decoding for Color
    enum CodingKeys: String, CodingKey {
        case id, name, symbol, icon, address, balance, balanceUSD
        case priceUSD, priceChange24h, blockchain, decimals, colorHex
    }

    init(
        id: String,
        name: String,
        symbol: String,
        icon: String,
        color: Color,
        address: String,
        balance: Decimal,
        balanceUSD: Decimal,
        priceUSD: Decimal,
        priceChange24h: Double,
        blockchain: String,
        decimals: Int = 18
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.icon = icon
        self.color = color
        self.address = address
        self.balance = balance
        self.balanceUSD = balanceUSD
        self.priceUSD = priceUSD
        self.priceChange24h = priceChange24h
        self.blockchain = blockchain
        self.decimals = decimals
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbol = try container.decode(String.self, forKey: .symbol)
        icon = try container.decode(String.self, forKey: .icon)
        address = try container.decode(String.self, forKey: .address)
        balance = try container.decode(Decimal.self, forKey: .balance)
        balanceUSD = try container.decode(Decimal.self, forKey: .balanceUSD)
        priceUSD = try container.decode(Decimal.self, forKey: .priceUSD)
        priceChange24h = try container.decode(Double.self, forKey: .priceChange24h)
        blockchain = try container.decode(String.self, forKey: .blockchain)
        decimals = try container.decode(Int.self, forKey: .decimals)

        // Decode color from hex
        if let colorHex = try? container.decode(String.self, forKey: .colorHex) {
            color = Color(hex: colorHex) ?? .blue
        } else {
            color = .blue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(icon, forKey: .icon)
        try container.encode(address, forKey: .address)
        try container.encode(balance, forKey: .balance)
        try container.encode(balanceUSD, forKey: .balanceUSD)
        try container.encode(priceUSD, forKey: .priceUSD)
        try container.encode(priceChange24h, forKey: .priceChange24h)
        try container.encode(blockchain, forKey: .blockchain)
        try container.encode(decimals, forKey: .decimals)
        try container.encode(color.toHex(), forKey: .colorHex)
    }
}

// MARK: - Color Extensions
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components,
              components.count >= 3 else {
            return "#000000"
        }

        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Sample Data
extension CryptoAsset {
    static let sample = CryptoAsset(
        id: "bitcoin",
        name: "Bitcoin",
        symbol: "BTC",
        icon: "bitcoinsign.circle.fill",
        color: .orange,
        address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
        balance: 0.05,
        balanceUSD: 2150.00,
        priceUSD: 43000.00,
        priceChange24h: 2.5,
        blockchain: "Bitcoin",
        decimals: 8
    )

    static let samples: [CryptoAsset] = [
        CryptoAsset(
            id: "bitcoin",
            name: "Bitcoin",
            symbol: "BTC",
            icon: "bitcoinsign.circle.fill",
            color: .orange,
            address: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            balance: 0.05,
            balanceUSD: 2150.00,
            priceUSD: 43000.00,
            priceChange24h: 2.5,
            blockchain: "Bitcoin"
        ),
        CryptoAsset(
            id: "ethereum",
            name: "Ethereum",
            symbol: "ETH",
            icon: "e.circle.fill",
            color: Color(red: 0.39, green: 0.47, blue: 0.85),
            address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            balance: 1.5,
            balanceUSD: 3300.00,
            priceUSD: 2200.00,
            priceChange24h: -1.2,
            blockchain: "Ethereum"
        ),
        CryptoAsset(
            id: "solana",
            name: "Solana",
            symbol: "SOL",
            icon: "s.circle.fill",
            color: Color(red: 0.55, green: 0.95, blue: 0.77),
            address: "7v91N7iZ9mNicL8WfG6cgSCKyRXydQjLh6UYBWwm6y1Q",
            balance: 10.0,
            balanceUSD: 950.00,
            priceUSD: 95.00,
            priceChange24h: 5.8,
            blockchain: "Solana"
        )
    ]
}
