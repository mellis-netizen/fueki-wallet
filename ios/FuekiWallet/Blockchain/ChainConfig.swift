//
//  ChainConfig.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Network Configurations
//

import Foundation

// MARK: - Chain Configuration
struct ChainConfig {
    let chainType: BlockchainType
    let network: NetworkEnvironment
    let rpcEndpoints: [String]
    let wsEndpoints: [String]
    let explorerURL: String
    let chainId: Int?
    let nativeCurrency: CurrencyInfo

    struct CurrencyInfo {
        let name: String
        let symbol: String
        let decimals: Int
    }
}

// MARK: - Configuration Manager
class ChainConfigManager {
    static let shared = ChainConfigManager()

    private init() {}

    // MARK: - Solana Configurations
    func getSolanaConfig(network: NetworkEnvironment) -> ChainConfig {
        switch network {
        case .mainnet:
            return ChainConfig(
                chainType: .solana,
                network: .mainnet,
                rpcEndpoints: [
                    "https://api.mainnet-beta.solana.com",
                    "https://solana-mainnet.g.alchemy.com/v2/YOUR-API-KEY",
                    "https://rpc.ankr.com/solana"
                ],
                wsEndpoints: [
                    "wss://api.mainnet-beta.solana.com",
                    "wss://solana-mainnet.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                explorerURL: "https://solscan.io",
                chainId: nil,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Solana",
                    symbol: "SOL",
                    decimals: 9
                )
            )

        case .testnet:
            return ChainConfig(
                chainType: .solana,
                network: .testnet,
                rpcEndpoints: [
                    "https://api.testnet.solana.com",
                    "https://solana-testnet.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                wsEndpoints: [
                    "wss://api.testnet.solana.com"
                ],
                explorerURL: "https://solscan.io?cluster=testnet",
                chainId: nil,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Solana",
                    symbol: "SOL",
                    decimals: 9
                )
            )

        case .devnet:
            return ChainConfig(
                chainType: .solana,
                network: .devnet,
                rpcEndpoints: [
                    "https://api.devnet.solana.com",
                    "https://solana-devnet.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                wsEndpoints: [
                    "wss://api.devnet.solana.com"
                ],
                explorerURL: "https://solscan.io?cluster=devnet",
                chainId: nil,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Solana",
                    symbol: "SOL",
                    decimals: 9
                )
            )
        }
    }

    // MARK: - Ethereum Configurations
    func getEthereumConfig(network: NetworkEnvironment) -> ChainConfig {
        switch network {
        case .mainnet:
            return ChainConfig(
                chainType: .ethereum,
                network: .mainnet,
                rpcEndpoints: [
                    "https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY",
                    "https://mainnet.infura.io/v3/YOUR-API-KEY",
                    "https://rpc.ankr.com/eth",
                    "https://cloudflare-eth.com"
                ],
                wsEndpoints: [
                    "wss://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY",
                    "wss://mainnet.infura.io/ws/v3/YOUR-API-KEY"
                ],
                explorerURL: "https://etherscan.io",
                chainId: 1,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Ether",
                    symbol: "ETH",
                    decimals: 18
                )
            )

        case .testnet:
            return ChainConfig(
                chainType: .ethereum,
                network: .testnet,
                rpcEndpoints: [
                    "https://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY",
                    "https://sepolia.infura.io/v3/YOUR-API-KEY",
                    "https://rpc.sepolia.org"
                ],
                wsEndpoints: [
                    "wss://eth-sepolia.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                explorerURL: "https://sepolia.etherscan.io",
                chainId: 11155111,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Sepolia Ether",
                    symbol: "ETH",
                    decimals: 18
                )
            )

        case .devnet:
            return ChainConfig(
                chainType: .ethereum,
                network: .devnet,
                rpcEndpoints: [
                    "http://localhost:8545",
                    "https://eth-goerli.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                wsEndpoints: [
                    "ws://localhost:8545"
                ],
                explorerURL: "https://goerli.etherscan.io",
                chainId: 5,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Goerli Ether",
                    symbol: "ETH",
                    decimals: 18
                )
            )
        }
    }

    // MARK: - Bitcoin Configurations
    func getBitcoinConfig(network: NetworkEnvironment) -> ChainConfig {
        switch network {
        case .mainnet:
            return ChainConfig(
                chainType: .bitcoin,
                network: .mainnet,
                rpcEndpoints: [
                    "https://blockstream.info/api",
                    "https://blockchain.info/q",
                    "https://btc-mainnet.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                wsEndpoints: [
                    "wss://blockstream.info/api/ws"
                ],
                explorerURL: "https://blockstream.info",
                chainId: nil,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Bitcoin",
                    symbol: "BTC",
                    decimals: 8
                )
            )

        case .testnet:
            return ChainConfig(
                chainType: .bitcoin,
                network: .testnet,
                rpcEndpoints: [
                    "https://blockstream.info/testnet/api",
                    "https://btc-testnet.g.alchemy.com/v2/YOUR-API-KEY"
                ],
                wsEndpoints: [
                    "wss://blockstream.info/testnet/api/ws"
                ],
                explorerURL: "https://blockstream.info/testnet",
                chainId: nil,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Test Bitcoin",
                    symbol: "tBTC",
                    decimals: 8
                )
            )

        case .devnet:
            return ChainConfig(
                chainType: .bitcoin,
                network: .devnet,
                rpcEndpoints: [
                    "http://localhost:18443",
                    "https://blockstream.info/testnet/api"
                ],
                wsEndpoints: [],
                explorerURL: "https://blockstream.info/testnet",
                chainId: nil,
                nativeCurrency: ChainConfig.CurrencyInfo(
                    name: "Regtest Bitcoin",
                    symbol: "BTC",
                    decimals: 8
                )
            )
        }
    }

    // MARK: - Get Configuration
    func getConfig(for chainType: BlockchainType, network: NetworkEnvironment) -> ChainConfig {
        switch chainType {
        case .solana:
            return getSolanaConfig(network: network)
        case .ethereum:
            return getEthereumConfig(network: network)
        case .bitcoin:
            return getBitcoinConfig(network: network)
        }
    }

    // MARK: - API Key Management
    func setAPIKey(_ key: String, for service: APIService) {
        UserDefaults.standard.set(key, forKey: "apiKey_\(service.rawValue)")
    }

    func getAPIKey(for service: APIService) -> String? {
        return UserDefaults.standard.string(forKey: "apiKey_\(service.rawValue)")
    }

    func replaceAPIKey(in endpoint: String, service: APIService) -> String {
        guard let apiKey = getAPIKey(for: service) else {
            return endpoint
        }
        return endpoint.replacingOccurrences(of: "YOUR-API-KEY", with: apiKey)
    }
}

// MARK: - API Services
enum APIService: String {
    case alchemy
    case infura
    case ankr
    case custom
}

// MARK: - Network Constants
struct NetworkConstants {
    // Solana
    static let solanaMinimumRentExempt: UInt64 = 890880
    static let solanaComputeUnitPrice: UInt64 = 1000

    // Ethereum
    static let ethereumGasLimitDefault: UInt64 = 21000
    static let ethereumGasLimitERC20: UInt64 = 65000
    static let ethereumMaxPriorityFeePerGas: Decimal = 2_000_000_000 // 2 Gwei

    // Bitcoin
    static let bitcoinDustLimit: UInt64 = 546
    static let bitcoinMinRelayFee: UInt64 = 1000
    static let bitcoinConfirmationTarget: Int = 6

    // Common
    static let defaultTimeout: TimeInterval = 30
    static let maxRetryAttempts = 3
    static let retryDelay: TimeInterval = 2
}
