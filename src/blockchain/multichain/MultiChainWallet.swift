import Foundation
import Combine

/// Unified multi-chain wallet interface
public class MultiChainWallet {

    // MARK: - Types

    public struct WalletBalance {
        public let blockchain: String
        public let balance: UInt64
        public let symbol: String
        public let decimals: UInt8

        public var displayBalance: String {
            let divisor = pow(10.0, Double(decimals))
            let value = Double(balance) / divisor
            return String(format: "%.8f", value)
        }
    }

    public struct TransactionRequest {
        public let blockchain: String
        public let from: String
        public let to: String
        public let amount: UInt64
        public let priority: FeePriority

        public init(blockchain: String, from: String, to: String,
                   amount: UInt64, priority: FeePriority = .medium) {
            self.blockchain = blockchain
            self.from = from
            self.to = to
            self.amount = amount
            self.priority = priority
        }
    }

    // MARK: - Properties

    public static let shared = MultiChainWallet()

    private let blockchainManager = BlockchainManager.shared
    private let networkSwitcher = NetworkSwitcher.shared
    private let monitor = TransactionMonitor()

    private var cancellables = Set<AnyCancellable>()

    // Publishers
    private let balanceUpdateSubject = PassthroughSubject<WalletBalance, Never>()
    public var balanceUpdatePublisher: AnyPublisher<WalletBalance, Never> {
        balanceUpdateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    private init() {
        setupProviders()
        subscribeToNetworkChanges()
    }

    // MARK: - Balance Management

    /// Get balance for address on specific blockchain
    public func getBalance(
        blockchain: String,
        address: String
    ) async throws -> WalletBalance {
        switch blockchain {
        case let id where id.contains("bitcoin"):
            guard let provider: BitcoinProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            let balance = try await provider.getBalance(for: address)
            return WalletBalance(blockchain: blockchain, balance: balance, symbol: "BTC", decimals: 8)

        case let id where id.contains("ethereum") || id.contains("polygon") || id.contains("arbitrum") || id.contains("optimism"):
            guard let provider: EthereumProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            let balance = try await provider.getBalance(for: address)
            return WalletBalance(blockchain: blockchain, balance: balance, symbol: "ETH", decimals: 18)

        default:
            throw BlockchainError.unsupportedOperation
        }
    }

    /// Get balances across all chains
    public func getAllBalances(address: String) async throws -> [WalletBalance] {
        let networks = networkSwitcher.getAllNetworks()
        var balances: [WalletBalance] = []

        for network in networks {
            do {
                let balance = try await getBalance(blockchain: network.id, address: address)
                balances.append(balance)
            } catch {
                // Continue with other chains if one fails
                print("Failed to get balance for \(network.name): \(error)")
            }
        }

        return balances
    }

    // MARK: - Transaction Management

    /// Create transaction
    public func createTransaction(
        request: TransactionRequest
    ) async throws -> Any {
        switch request.blockchain {
        case let id where id.contains("bitcoin"):
            guard let provider: BitcoinProvider = blockchainManager.getProvider(for: request.blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.createTransaction(
                from: request.from,
                to: request.to,
                amount: request.amount
            )

        case let id where id.contains("ethereum") || id.contains("polygon") || id.contains("arbitrum") || id.contains("optimism"):
            guard let provider: EthereumProvider = blockchainManager.getProvider(for: request.blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.createTransaction(
                from: request.from,
                to: request.to,
                amount: request.amount
            )

        default:
            throw BlockchainError.unsupportedOperation
        }
    }

    /// Send transaction
    public func sendTransaction(
        blockchain: String,
        signedTransaction: Data
    ) async throws -> String {
        switch blockchain {
        case let id where id.contains("bitcoin"):
            guard let provider: BitcoinProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.broadcastTransaction(signedTransaction)

        case let id where id.contains("ethereum") || id.contains("polygon") || id.contains("arbitrum") || id.contains("optimism"):
            guard let provider: EthereumProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.broadcastTransaction(signedTransaction)

        default:
            throw BlockchainError.unsupportedOperation
        }
    }

    /// Get transaction status
    public func getTransactionStatus(
        blockchain: String,
        txHash: String
    ) -> TransactionMonitor.TransactionStatus? {
        return monitor.getStatus(txHash: txHash)
    }

    /// Wait for transaction confirmation
    public func waitForConfirmation(
        blockchain: String,
        txHash: String,
        timeout: TimeInterval = 300
    ) async throws -> TransactionMonitor.TransactionStatus {
        return try await monitor.waitForConfirmation(txHash: txHash, timeout: timeout)
    }

    // MARK: - History

    /// Get transaction history
    public func getTransactionHistory(
        blockchain: String,
        address: String,
        limit: Int = 50
    ) async throws -> [String] {
        switch blockchain {
        case let id where id.contains("bitcoin"):
            guard let provider: BitcoinProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.fetchTransactionHistory(for: address, limit: limit)

        case let id where id.contains("ethereum") || id.contains("polygon") || id.contains("arbitrum") || id.contains("optimism"):
            guard let provider: EthereumProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.fetchTransactionHistory(for: address, limit: limit)

        default:
            throw BlockchainError.unsupportedOperation
        }
    }

    // MARK: - Fee Estimation

    /// Estimate transaction fee
    public func estimateFee(
        blockchain: String,
        priority: FeePriority = .medium
    ) async throws -> UInt64 {
        switch blockchain {
        case let id where id.contains("bitcoin"):
            guard let provider: BitcoinProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.estimateFee(priority: priority)

        case let id where id.contains("ethereum") || id.contains("polygon") || id.contains("arbitrum") || id.contains("optimism"):
            guard let provider: EthereumProvider = blockchainManager.getProvider(for: blockchain) else {
                throw BlockchainError.invalidChainId
            }
            return try await provider.estimateFee(priority: priority)

        default:
            throw BlockchainError.unsupportedOperation
        }
    }

    // MARK: - Network Management

    /// Switch to different network
    public func switchNetwork(to networkId: String) throws {
        try networkSwitcher.switchNetwork(to: networkId)
    }

    /// Get current network
    public func getCurrentNetwork() -> NetworkSwitcher.NetworkInfo? {
        return networkSwitcher.getCurrentNetwork()
    }

    /// Get available networks
    public func getAvailableNetworks() -> [NetworkSwitcher.NetworkInfo] {
        return networkSwitcher.getAllNetworks()
    }

    // MARK: - Private Setup

    private func setupProviders() {
        // Setup Bitcoin providers
        _ = BitcoinProvider(network: .mainnet, monitor: monitor)
        _ = BitcoinProvider(network: .testnet, monitor: monitor)

        // Setup Ethereum providers
        _ = EthereumProvider(chain: .ethereum, monitor: monitor)
        _ = EthereumProvider(chain: .goerli, monitor: monitor)

        // Setup other EVM chains
        _ = EthereumProvider(chain: .polygon, monitor: monitor)
        _ = EthereumProvider(chain: .mumbai, monitor: monitor)
        _ = EthereumProvider(chain: .binanceSmartChain, monitor: monitor)
        _ = EthereumProvider(chain: .arbitrum, monitor: monitor)
        _ = EthereumProvider(chain: .optimism, monitor: monitor)
    }

    private func subscribeToNetworkChanges() {
        networkSwitcher.networkChangePublisher
            .sink { [weak self] network in
                print("Network switched to: \(network.name)")
            }
            .store(in: &cancellables)

        monitor.statusPublisher
            .sink { [weak self] txHash, status in
                print("Transaction \(txHash) status: \(status)")
            }
            .store(in: &cancellables)
    }
}
