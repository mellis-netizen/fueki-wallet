import Foundation

/// Protocol defining common blockchain operations across all chains
public protocol BlockchainProvider {
    associatedtype Address
    associatedtype Transaction
    associatedtype TransactionReceipt

    /// Blockchain network identifier
    var networkId: String { get }

    /// Generate address from public key
    func generateAddress(from publicKey: Data) throws -> Address

    /// Validate address format
    func validateAddress(_ address: String) -> Bool

    /// Get balance for address
    func getBalance(for address: String) async throws -> UInt64

    /// Create transaction
    func createTransaction(from: String, to: String, amount: UInt64) async throws -> Transaction

    /// Broadcast signed transaction
    func broadcastTransaction(_ signedTransaction: Data) async throws -> String

    /// Get transaction receipt
    func getTransactionReceipt(_ txHash: String) async throws -> TransactionReceipt

    /// Fetch transaction history
    func fetchTransactionHistory(for address: String, limit: Int) async throws -> [String]

    /// Estimate transaction fee
    func estimateFee(priority: FeePriority) async throws -> UInt64
}

/// Fee priority levels across all blockchains
public enum FeePriority {
    case low
    case medium
    case high
    case custom(UInt64)
}

/// Common blockchain errors
public enum BlockchainError: Error, LocalizedError {
    case invalidAddress(String)
    case insufficientBalance
    case invalidTransaction
    case networkError(String)
    case broadcastFailed(String)
    case transactionNotFound
    case timeout
    case rateLimitExceeded
    case invalidChainId
    case unsupportedOperation

    public var errorDescription: String? {
        switch self {
        case .invalidAddress(let addr):
            return "Invalid address: \(addr)"
        case .insufficientBalance:
            return "Insufficient balance for transaction"
        case .invalidTransaction:
            return "Invalid transaction data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .broadcastFailed(let reason):
            return "Failed to broadcast transaction: \(reason)"
        case .transactionNotFound:
            return "Transaction not found"
        case .timeout:
            return "Request timed out"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .invalidChainId:
            return "Invalid chain ID"
        case .unsupportedOperation:
            return "Operation not supported on this chain"
        }
    }
}

/// Network configuration for blockchain providers
public struct NetworkConfiguration {
    public let chainId: String
    public let name: String
    public let rpcEndpoints: [String]
    public let explorerURL: String
    public let nativeCurrency: Currency
    public let isTestnet: Bool

    public struct Currency {
        public let name: String
        public let symbol: String
        public let decimals: UInt8

        public init(name: String, symbol: String, decimals: UInt8) {
            self.name = name
            self.symbol = symbol
            self.decimals = decimals
        }
    }

    public init(chainId: String, name: String, rpcEndpoints: [String],
                explorerURL: String, nativeCurrency: Currency, isTestnet: Bool = false) {
        self.chainId = chainId
        self.name = name
        self.rpcEndpoints = rpcEndpoints
        self.explorerURL = explorerURL
        self.nativeCurrency = nativeCurrency
        self.isTestnet = isTestnet
    }
}

/// Multi-chain blockchain manager
public class BlockchainManager {

    // MARK: - Properties

    private var providers: [String: Any] = [:]
    private let queue = DispatchQueue(label: "io.fueki.blockchain.manager", attributes: .concurrent)

    public static let shared = BlockchainManager()

    // MARK: - Initialization

    private init() {
        setupDefaultProviders()
    }

    // MARK: - Provider Registration

    /// Register a blockchain provider
    public func registerProvider<P: BlockchainProvider>(_ provider: P, for networkId: String) {
        queue.async(flags: .barrier) {
            self.providers[networkId] = provider
        }
    }

    /// Get registered provider
    public func getProvider<P: BlockchainProvider>(for networkId: String) -> P? {
        return queue.sync {
            providers[networkId] as? P
        }
    }

    /// Check if provider exists
    public func hasProvider(for networkId: String) -> Bool {
        return queue.sync {
            providers[networkId] != nil
        }
    }

    /// Remove provider
    public func removeProvider(for networkId: String) {
        queue.async(flags: .barrier) {
            self.providers.removeValue(forKey: networkId)
        }
    }

    /// Get all registered network IDs
    public func registeredNetworks() -> [String] {
        return queue.sync {
            Array(providers.keys)
        }
    }

    // MARK: - Private Setup

    private func setupDefaultProviders() {
        // Default providers can be registered here
        // This is called during initialization
    }
}
