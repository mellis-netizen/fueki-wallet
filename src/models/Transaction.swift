//
//  Transaction.swift
//  Fueki Wallet
//
//  Transaction model with status and details
//

import SwiftUI
import Foundation

struct Transaction: Identifiable, Codable {
    let id: String
    let type: TransactionType
    var asset: CryptoAsset
    let amount: Decimal
    let amountUSD: Decimal
    var fromAddress: String?
    var toAddress: String?
    let timestamp: Date
    var status: TransactionStatus
    var confirmations: Int
    let networkFee: Decimal?
    var hash: String?
    let memo: String?

    // Legacy support
    var assetSymbol: String { asset.symbol }
    var assetIcon: String { asset.icon }
    var transactionHash: String? { hash }

    var explorerURL: URL? {
        // Generate blockchain explorer URL based on asset
        guard let hash = transactionHash else { return nil }

        let baseURL: String
        switch asset.blockchain.lowercased() {
        case "bitcoin":
            baseURL = "https://blockchair.com/bitcoin/transaction"
        case "ethereum":
            baseURL = "https://etherscan.io/tx"
        case "solana":
            baseURL = "https://explorer.solana.com/tx"
        case "polygon":
            baseURL = "https://polygonscan.com/tx"
        default:
            baseURL = "https://etherscan.io/tx"
        }

        return URL(string: "\(baseURL)/\(hash)")
    }
}

enum TransactionType: String, Codable {
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
        case .send, .sell: return .red
        case .receive, .buy: return .green
        }
    }
}

enum TransactionStatus: String, Codable {
    case pending
    case confirmed
    case failed
    case cancelled

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .confirmed: return "Confirmed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock.fill"
        case .confirmed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .confirmed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}

// MARK: - Sample Data
extension Transaction {
    static let sample = Transaction(
        id: UUID().uuidString,
        type: .send,
        assetSymbol: "ETH",
        assetIcon: "e.circle.fill",
        amount: 0.5,
        amountUSD: 1100.00,
        fromAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
        toAddress: "0x1234567890abcdef1234567890abcdef12345678",
        timestamp: Date(),
        status: .confirmed,
        networkFee: 0.002,
        transactionHash: "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
        memo: nil
    )

    static let samples: [Transaction] = [
        Transaction(
            id: UUID().uuidString,
            type: .receive,
            assetSymbol: "BTC",
            assetIcon: "bitcoinsign.circle.fill",
            amount: 0.01,
            amountUSD: 430.00,
            fromAddress: "bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq",
            toAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            timestamp: Date().addingTimeInterval(-3600),
            status: .confirmed,
            networkFee: 0.0001,
            transactionHash: "abc123def456",
            memo: nil
        ),
        Transaction(
            id: UUID().uuidString,
            type: .send,
            assetSymbol: "ETH",
            assetIcon: "e.circle.fill",
            amount: 0.5,
            amountUSD: 1100.00,
            fromAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            toAddress: "0x1234567890abcdef1234567890abcdef12345678",
            timestamp: Date().addingTimeInterval(-7200),
            status: .confirmed,
            networkFee: 0.002,
            transactionHash: "def789ghi012",
            memo: "Payment for services"
        ),
        Transaction(
            id: UUID().uuidString,
            type: .buy,
            assetSymbol: "SOL",
            assetIcon: "s.circle.fill",
            amount: 5.0,
            amountUSD: 475.00,
            fromAddress: "",
            toAddress: "7v91N7iZ9mNicL8WfG6cgSCKyRXydQjLh6UYBWwm6y1Q",
            timestamp: Date().addingTimeInterval(-86400),
            status: .confirmed,
            networkFee: nil,
            transactionHash: nil,
            memo: nil
        ),
        Transaction(
            id: UUID().uuidString,
            type: .send,
            assetSymbol: "BTC",
            assetIcon: "bitcoinsign.circle.fill",
            amount: 0.002,
            amountUSD: 86.00,
            fromAddress: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh",
            toAddress: "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            timestamp: Date().addingTimeInterval(-172800),
            status: .pending,
            networkFee: 0.00005,
            transactionHash: "pending123",
            memo: nil
        )
    ]
}
