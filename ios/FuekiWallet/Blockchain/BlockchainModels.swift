//
//  BlockchainModels.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Data Models for All Chains
//

import Foundation

// MARK: - Solana Specific Models
struct SolanaModels {
    // Account Info
    struct AccountInfo: Codable {
        let lamports: UInt64
        let owner: String
        let executable: Bool
        let rentEpoch: UInt64
        let data: [String]  // [data, encoding]
    }

    // Transaction
    struct Transaction: Codable {
        let signatures: [String]
        let message: Message

        struct Message: Codable {
            let accountKeys: [String]
            let recentBlockhash: String
            let instructions: [Instruction]

            struct Instruction: Codable {
                let programIdIndex: UInt8
                let accounts: [UInt8]
                let data: String
            }
        }
    }

    // Token Account
    struct TokenAccount: Codable {
        let mint: String
        let owner: String
        let amount: String
        let decimals: UInt8
        let uiAmount: Double?
    }

    // Program Account
    struct ProgramAccount: Codable {
        let pubkey: String
        let account: AccountInfo
    }
}

// MARK: - Ethereum Specific Models
struct EthereumModels {
    // Block
    struct Block: Codable {
        let number: String
        let hash: String
        let parentHash: String
        let timestamp: String
        let transactions: [String]
        let gasUsed: String
        let gasLimit: String
        let baseFeePerGas: String?
        let miner: String
        let difficulty: String?
        let totalDifficulty: String?
    }

    // Transaction
    struct Transaction: Codable {
        let hash: String
        let nonce: String
        let blockHash: String?
        let blockNumber: String?
        let transactionIndex: String?
        let from: String
        let to: String?
        let value: String
        let gasPrice: String?
        let maxFeePerGas: String?
        let maxPriorityFeePerGas: String?
        let gas: String
        let input: String
        let v: String?
        let r: String?
        let s: String?
    }

    // Transaction Receipt
    struct TransactionReceipt: Codable {
        let transactionHash: String
        let transactionIndex: String
        let blockHash: String
        let blockNumber: String
        let from: String
        let to: String?
        let cumulativeGasUsed: String
        let gasUsed: String
        let contractAddress: String?
        let logs: [Log]
        let status: String
        let effectiveGasPrice: String?
    }

    // Log Entry
    struct Log: Codable {
        let address: String
        let topics: [String]
        let data: String
        let blockNumber: String
        let transactionHash: String
        let transactionIndex: String
        let blockHash: String
        let logIndex: String
        let removed: Bool
    }

    // ERC-20 Token
    struct ERC20Token: Codable {
        let contractAddress: String
        let name: String
        let symbol: String
        let decimals: Int
        let totalSupply: String
        let balance: String
    }

    // Gas Oracle
    struct GasOracle: Codable {
        let baseFee: String
        let low: GasPrice
        let medium: GasPrice
        let high: GasPrice
        let instant: GasPrice

        struct GasPrice: Codable {
            let maxPriorityFee: String
            let maxFee: String
        }
    }
}

// MARK: - Bitcoin Specific Models
struct BitcoinModels {
    // UTXO (Unspent Transaction Output)
    struct UTXO: Codable {
        let txid: String
        let vout: UInt32
        let value: UInt64
        let scriptPubKey: String
        let address: String?
        let confirmations: Int
        let spendable: Bool
    }

    // Transaction
    struct Transaction: Codable {
        let txid: String
        let version: Int
        let locktime: UInt32
        let vin: [Input]
        let vout: [Output]
        let size: Int
        let weight: Int
        let fee: UInt64
        let status: Status

        struct Input: Codable {
            let txid: String
            let vout: UInt32
            let scriptSig: String?
            let sequence: UInt32
            let witness: [String]?
            let prevout: Output?
        }

        struct Output: Codable {
            let value: UInt64
            let scriptPubKey: String
            let scriptPubKeyType: String?
            let scriptPubKeyAddress: String?
        }

        struct Status: Codable {
            let confirmed: Bool
            let blockHeight: Int?
            let blockHash: String?
            let blockTime: Int?
        }
    }

    // Address Info
    struct AddressInfo: Codable {
        let address: String
        let chainStats: Stats
        let mempoolStats: Stats

        struct Stats: Codable {
            let fundedTxoCount: Int
            let fundedTxoSum: UInt64
            let spentTxoCount: Int
            let spentTxoSum: UInt64
            let txCount: Int
        }
    }

    // Block
    struct Block: Codable {
        let hash: String
        let height: Int
        let version: Int
        let timestamp: Int
        let txCount: Int
        let size: Int
        let weight: Int
        let merkleRoot: String
        let previousBlockHash: String?
        let nonce: UInt32
        let bits: UInt32
        let difficulty: Double
    }

    // Fee Estimate
    struct FeeEstimate: Codable {
        let economyFee: UInt64  // satoshis per byte
        let hourFee: UInt64
        let halfHourFee: UInt64
        let fastestFee: UInt64
    }
}

// MARK: - Common Transaction Models
struct TransactionBuilder {
    // Generic Transaction Components
    struct Input {
        let address: String
        let value: Decimal
        let data: Data?
    }

    struct Output {
        let address: String
        let value: Decimal
        let data: Data?
    }

    struct Fee {
        let gasLimit: UInt64?
        let gasPrice: Decimal?
        let maxFeePerGas: Decimal?
        let maxPriorityFeePerGas: Decimal?
        let feeRate: UInt64?  // For Bitcoin (satoshis per byte)
    }
}

// MARK: - Token Standards
enum TokenStandard: String, Codable {
    case spl = "SPL"           // Solana
    case erc20 = "ERC-20"      // Ethereum
    case erc721 = "ERC-721"    // Ethereum NFT
    case erc1155 = "ERC-1155"  // Ethereum Multi-Token
    case brc20 = "BRC-20"      // Bitcoin
}

// MARK: - NFT Models
struct NFTMetadata: Codable {
    let tokenId: String
    let contractAddress: String
    let standard: TokenStandard
    let name: String
    let description: String?
    let image: URL?
    let animationUrl: URL?
    let attributes: [Attribute]?
    let owner: String

    struct Attribute: Codable {
        let traitType: String
        let value: String
        let displayType: String?
    }
}

// MARK: - Historical Data
struct PriceHistory: Codable {
    let timestamp: Date
    let price: Decimal
    let volume: Decimal
    let marketCap: Decimal?
}

struct TransactionHistory: Codable {
    let transactions: [BlockchainTransaction]
    let total: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool
}

// MARK: - WebSocket Events
struct WebSocketEvent: Codable {
    let type: EventType
    let data: Data
    let timestamp: Date

    enum EventType: String, Codable {
        case newTransaction = "new_transaction"
        case newBlock = "new_block"
        case accountUpdate = "account_update"
        case tokenTransfer = "token_transfer"
        case error = "error"
    }
}

// MARK: - Provider Status
struct ProviderStatus: Codable {
    let chainType: BlockchainType
    let network: NetworkEnvironment
    let isConnected: Bool
    let currentBlockNumber: UInt64?
    let peerCount: Int?
    let syncStatus: SyncStatus?
    let lastError: String?
    let lastUpdate: Date

    enum SyncStatus: String, Codable {
        case synced
        case syncing
        case notSynced
    }
}

// MARK: - Serialization Helpers
extension Decimal {
    func toHexString(decimals: Int) -> String {
        let multiplier = Decimal(pow(10.0, Double(decimals)))
        let value = self * multiplier
        let nsDecimal = value as NSDecimalNumber
        let uint = nsDecimal.uint64Value
        return "0x" + String(uint, radix: 16)
    }

    static func fromHexString(_ hex: String, decimals: Int) -> Decimal? {
        let cleanHex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard let value = UInt64(cleanHex, radix: 16) else { return nil }
        let divisor = Decimal(pow(10.0, Double(decimals)))
        return Decimal(value) / divisor
    }
}

extension Data {
    func toHexString() -> String {
        "0x" + map { String(format: "%02x", $0) }.joined()
    }

    static func fromHexString(_ hex: String) -> Data? {
        let cleanHex = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        var data = Data()
        var index = cleanHex.startIndex

        while index < cleanHex.endIndex {
            let nextIndex = cleanHex.index(index, offsetBy: 2)
            if let byte = UInt8(cleanHex[index..<nextIndex], radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }

        return data
    }
}
