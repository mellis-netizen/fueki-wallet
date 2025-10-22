//
//  BlockchainProviderProtocol.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Multi-Chain Provider Interface
//

import Foundation
import Combine

// MARK: - Chain Types
enum BlockchainType: String, Codable, CaseIterable {
    case solana = "SOL"
    case ethereum = "ETH"
    case bitcoin = "BTC"

    var name: String {
        switch self {
        case .solana: return "Solana"
        case .ethereum: return "Ethereum"
        case .bitcoin: return "Bitcoin"
        }
    }

    var nativeDecimals: Int {
        switch self {
        case .solana: return 9  // lamports
        case .ethereum: return 18  // wei
        case .bitcoin: return 8  // satoshis
        }
    }
}

// MARK: - Network Environment
enum NetworkEnvironment: String, Codable {
    case mainnet
    case testnet
    case devnet

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Transaction Status
enum TransactionStatus: String, Codable {
    case pending
    case confirmed
    case finalized
    case failed
    case dropped

    var isComplete: Bool {
        switch self {
        case .finalized, .failed, .dropped:
            return true
        default:
            return false
        }
    }
}

// MARK: - Balance Information
struct BlockchainBalance: Codable {
    let address: String
    let nativeBalance: Decimal
    let tokens: [TokenBalance]
    let timestamp: Date

    struct TokenBalance: Codable {
        let contractAddress: String
        let symbol: String
        let name: String
        let balance: Decimal
        let decimals: Int
        let usdValue: Decimal?
    }
}

// MARK: - Transaction Models
struct BlockchainTransaction: Codable {
    let hash: String
    let from: String
    let to: String
    let value: Decimal
    let fee: Decimal
    let timestamp: Date
    let status: TransactionStatus
    let blockNumber: UInt64?
    let confirmations: UInt64?
    let data: Data?
    let tokenTransfers: [TokenTransfer]?

    struct TokenTransfer: Codable {
        let contractAddress: String
        let from: String
        let to: String
        let value: Decimal
        let symbol: String
    }
}

// MARK: - Transaction Request
struct TransactionRequest: Codable {
    let from: String
    let to: String
    let value: Decimal
    let data: Data?
    let gasLimit: UInt64?
    let maxFeePerGas: Decimal?
    let maxPriorityFeePerGas: Decimal?
    let nonce: UInt64?
}

// MARK: - Signed Transaction
struct SignedTransaction: Codable {
    let rawTransaction: Data
    let hash: String
    let signature: Data
}

// MARK: - Gas Estimation
struct GasEstimation: Codable {
    let gasLimit: UInt64
    let baseFee: Decimal?
    let maxFeePerGas: Decimal
    let maxPriorityFeePerGas: Decimal
    let estimatedTotal: Decimal
    let confidence: Double  // 0.0 to 1.0
}

// MARK: - Blockchain Provider Protocol
protocol BlockchainProviderProtocol: AnyObject {
    var chainType: BlockchainType { get }
    var network: NetworkEnvironment { get }
    var isConnected: Bool { get }

    // MARK: - Connection Management
    func connect() async throws
    func disconnect() async
    func switchNetwork(_ network: NetworkEnvironment) async throws

    // MARK: - Account Management
    func getBalance(for address: String) async throws -> BlockchainBalance
    func getTokenBalance(for address: String, tokenAddress: String) async throws -> Decimal
    func validateAddress(_ address: String) -> Bool

    // MARK: - Transaction Management
    func getTransaction(hash: String) async throws -> BlockchainTransaction
    func getTransactionHistory(for address: String, limit: Int) async throws -> [BlockchainTransaction]
    func estimateGas(for request: TransactionRequest) async throws -> GasEstimation

    // MARK: - Transaction Sending
    func buildTransaction(_ request: TransactionRequest) async throws -> Data
    func sendSignedTransaction(_ signedTx: SignedTransaction) async throws -> String
    func getTransactionStatus(hash: String) async throws -> TransactionStatus

    // MARK: - Block Information
    func getCurrentBlockNumber() async throws -> UInt64
    func getBlock(number: UInt64) async throws -> BlockInfo

    // MARK: - Real-time Updates
    func subscribeToAddress(_ address: String) -> AnyPublisher<BlockchainTransaction, Error>
    func subscribeToNewBlocks() -> AnyPublisher<UInt64, Error>

    // MARK: - Token Operations
    func getTokenInfo(contractAddress: String) async throws -> TokenInfo
    func getTokensForAddress(_ address: String) async throws -> [TokenInfo]
}

// MARK: - Supporting Models
struct BlockInfo: Codable {
    let number: UInt64
    let hash: String
    let timestamp: Date
    let transactionCount: Int
    let gasUsed: UInt64?
    let gasLimit: UInt64?
}

struct TokenInfo: Codable {
    let contractAddress: String
    let symbol: String
    let name: String
    let decimals: Int
    let totalSupply: Decimal?
    let logoURI: URL?
}

// MARK: - Blockchain Error
enum BlockchainError: LocalizedError {
    case notConnected
    case invalidAddress
    case insufficientBalance
    case transactionFailed(String)
    case networkError(Error)
    case invalidTransaction
    case timeout
    case rpcError(Int, String)
    case unsupportedOperation

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Not connected to blockchain network"
        case .invalidAddress:
            return "Invalid blockchain address"
        case .insufficientBalance:
            return "Insufficient balance for transaction"
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidTransaction:
            return "Invalid transaction data"
        case .timeout:
            return "Request timed out"
        case .rpcError(let code, let message):
            return "RPC Error \(code): \(message)"
        case .unsupportedOperation:
            return "Operation not supported on this chain"
        }
    }
}

// MARK: - Provider Helper Extensions
extension BlockchainProviderProtocol {
    func formatBalance(_ balance: Decimal, decimals: Int) -> String {
        let divisor = Decimal(pow(10.0, Double(decimals)))
        let formatted = balance / divisor
        return formatted.description
    }

    func parseBalance(_ string: String, decimals: Int) -> Decimal? {
        guard let value = Decimal(string: string) else { return nil }
        let multiplier = Decimal(pow(10.0, Double(decimals)))
        return value * multiplier
    }
}
