//
//  MarketTrend.swift
//  Fueki Wallet
//
//  Market trend data model
//

import SwiftUI
import Foundation

struct MarketTrend: Identifiable, Codable {
    let id: String
    let symbol: String
    let name: String
    let icon: String
    let color: Color
    let price: Decimal
    let change: Double
    let volume24h: Decimal
    let marketCap: Decimal

    // Custom encoding/decoding for Color
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, icon, price, change, volume24h, marketCap, colorHex
    }

    init(
        id: String,
        symbol: String,
        name: String,
        icon: String,
        color: Color,
        price: Decimal,
        change: Double,
        volume24h: Decimal,
        marketCap: Decimal
    ) {
        self.id = id
        self.symbol = symbol
        self.name = name
        self.icon = icon
        self.color = color
        self.price = price
        self.change = change
        self.volume24h = volume24h
        self.marketCap = marketCap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        symbol = try container.decode(String.self, forKey: .symbol)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        price = try container.decode(Decimal.self, forKey: .price)
        change = try container.decode(Double.self, forKey: .change)
        volume24h = try container.decode(Decimal.self, forKey: .volume24h)
        marketCap = try container.decode(Decimal.self, forKey: .marketCap)

        if let colorHex = try? container.decode(String.self, forKey: .colorHex) {
            color = Color(hex: colorHex) ?? .blue
        } else {
            color = .blue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(price, forKey: .price)
        try container.encode(change, forKey: .change)
        try container.encode(volume24h, forKey: .volume24h)
        try container.encode(marketCap, forKey: .marketCap)
        try container.encode(color.toHex(), forKey: .colorHex)
    }
}

// MARK: - Sample Data
extension MarketTrend {
    static let samples: [MarketTrend] = [
        MarketTrend(
            id: "bitcoin",
            symbol: "BTC",
            name: "Bitcoin",
            icon: "bitcoinsign.circle.fill",
            color: .orange,
            price: 43000.00,
            change: 2.5,
            volume24h: 25000000000,
            marketCap: 840000000000
        ),
        MarketTrend(
            id: "ethereum",
            symbol: "ETH",
            name: "Ethereum",
            icon: "e.circle.fill",
            color: Color(red: 0.39, green: 0.47, blue: 0.85),
            price: 2200.00,
            change: -1.2,
            volume24h: 15000000000,
            marketCap: 260000000000
        ),
        MarketTrend(
            id: "solana",
            symbol: "SOL",
            name: "Solana",
            icon: "s.circle.fill",
            color: Color(red: 0.55, green: 0.95, blue: 0.77),
            price: 95.00,
            change: 5.8,
            volume24h: 2500000000,
            marketCap: 42000000000
        )
    ]
}
