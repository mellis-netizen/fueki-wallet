import Foundation

/// Enhanced Ethereum provider with BlockchainProvider protocol conformance
public class EthereumProvider: BlockchainProvider {

    // MARK: - Protocol Conformance

    public typealias Address = EthereumIntegration.EthereumAddress
    public typealias Transaction = EthereumIntegration.EthereumTransaction
    public typealias TransactionReceipt = EthereumIntegration.TransactionReceipt

    public var networkId: String {
        return "ethereum_\(integration.chain.rawValue)"
    }

    // MARK: - Properties

    private let integration: EthereumIntegration
    private let rpcClient: RPCClient
    private let monitor: TransactionMonitor

    // MARK: - Initialization

    public init(
        chain: EthereumIntegration.Chain = .ethereum,
        apiKey: String? = nil,
        monitor: TransactionMonitor = .init()
    ) {
        self.integration = EthereumIntegration(chain: chain, apiKey: apiKey)
        self.monitor = monitor

        // Setup RPC client with provider endpoints
        let endpoints = Self.getRPCEndpoints(for: chain, apiKey: apiKey)

        let config = RPCClient.Configuration(
            endpoints: endpoints,
            timeout: 30,
            maxRetries: 3,
            retryDelay: 1.5
        )
        self.rpcClient = RPCClient(configuration: config)

        // Register with BlockchainManager
        BlockchainManager.shared.registerProvider(self, for: networkId)
    }

    // MARK: - BlockchainProvider Protocol Implementation

    public func generateAddress(from publicKey: Data) throws -> EthereumIntegration.EthereumAddress {
        return try integration.generateAddress(from: publicKey)
    }

    public func validateAddress(_ address: String) -> Bool {
        return integration.validateAddress(address)
    }

    public func getBalance(for address: String) async throws -> UInt64 {
        return try await integration.getBalance(for: address)
    }

    public func createTransaction(from: String, to: String, amount: UInt64) async throws -> EthereumIntegration.EthereumTransaction {
        return try await integration.createEIP1559Transaction(
            from: from,
            to: to,
            amount: amount
        )
    }

    public func broadcastTransaction(_ signedTransaction: Data) async throws -> String {
        let txHash = try await integration.sendTransaction(signedTransaction)

        // Determine required confirmations based on chain
        let requiredConfirmations = getRequiredConfirmations()

        // Start monitoring the transaction
        monitor.monitor(txHash: txHash, blockchain: networkId, requiredConfirmations: requiredConfirmations)

        return txHash
    }

    public func getTransactionReceipt(_ txHash: String) async throws -> EthereumIntegration.TransactionReceipt {
        return try await integration.getTransactionDetails(txHash)
    }

    public func fetchTransactionHistory(for address: String, limit: Int = 50) async throws -> [String] {
        return try await integration.fetchTransactionHistory(for: address, limit: limit)
    }

    public func estimateFee(priority: FeePriority) async throws -> UInt64 {
        // For Ethereum, fee is more complex (base fee + priority fee)
        // Return estimated total gas cost
        let gasPrice = try await estimateGasPrice(priority: priority)
        let gasLimit: UInt64 = 21000 // Standard transfer

        return gasPrice * gasLimit
    }

    // MARK: - Ethereum-Specific Methods

    /// Get ERC-20 token balance
    public func getTokenBalance(
        token: EthereumIntegration.ERC20Token,
        address: String
    ) async throws -> UInt64 {
        return try await integration.getTokenBalance(token: token, for: address)
    }

    /// Create ERC-20 token transfer
    public func createTokenTransfer(
        token: EthereumIntegration.ERC20Token,
        from: String,
        to: String,
        amount: UInt64
    ) async throws -> EthereumIntegration.EthereumTransaction {
        return try await integration.createTokenTransfer(
            token: token,
            from: from,
            to: to,
            amount: amount
        )
    }

    /// Estimate gas for transaction
    public func estimateGas(
        from: String,
        to: String,
        value: UInt64 = 0,
        data: Data = Data()
    ) async throws -> UInt64 {
        return try await integration.estimateGas(
            from: from,
            to: to,
            value: value,
            data: data
        )
    }

    /// Wait for transaction confirmation
    public func waitForConfirmation(
        txHash: String,
        confirmations: UInt64 = 12,
        timeout: TimeInterval = 300
    ) async throws -> EthereumIntegration.TransactionReceipt {
        return try await integration.waitForConfirmation(
            txHash: txHash,
            confirmations: confirmations,
            timeout: timeout
        )
    }

    /// Call smart contract view function
    public func callContract(
        contractAddress: String,
        functionSignature: String,
        parameters: Data
    ) async throws -> Data {
        return try await integration.callContractFunction(
            contractAddress: contractAddress,
            functionSignature: functionSignature,
            parameters: parameters
        )
    }

    /// Create EIP-1559 transaction with dynamic fees
    public func createEIP1559Transaction(
        from: String,
        to: String,
        amount: UInt64,
        maxFeePerGas: UInt64? = nil,
        maxPriorityFeePerGas: UInt64? = nil
    ) async throws -> EthereumIntegration.EthereumTransaction {
        return try await integration.createEIP1559Transaction(
            from: from,
            to: to,
            amount: amount,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: maxPriorityFeePerGas
        )
    }

    /// Create legacy transaction with fixed gas price
    public func createLegacyTransaction(
        from: String,
        to: String,
        amount: UInt64,
        gasLimit: UInt64? = nil
    ) async throws -> EthereumIntegration.EthereumTransaction {
        return try await integration.createTransferTransaction(
            from: from,
            to: to,
            amount: amount,
            gasLimit: gasLimit
        )
    }

    // MARK: - Private Helpers

    private static func getRPCEndpoints(
        for chain: EthereumIntegration.Chain,
        apiKey: String?
    ) -> [URL] {
        var baseURL = chain.rpcURL

        // Add API key if provided
        if let key = apiKey, baseURL.hasSuffix("/v2/") {
            baseURL += key
        }

        var endpoints = [URL(string: baseURL)!]

        // Add fallback endpoints
        switch chain {
        case .ethereum:
            if let key = apiKey {
                endpoints.append(URL(string: "https://eth-mainnet.alchemyapi.io/v2/\(key)")!)
            }
            endpoints.append(URL(string: "https://cloudflare-eth.com")!)
            endpoints.append(URL(string: "https://rpc.ankr.com/eth")!)

        case .polygon:
            if let key = apiKey {
                endpoints.append(URL(string: "https://polygon-mainnet.g.alchemy.com/v2/\(key)")!)
            }
            endpoints.append(URL(string: "https://polygon-rpc.com")!)
            endpoints.append(URL(string: "https://rpc.ankr.com/polygon")!)

        case .binanceSmartChain:
            endpoints.append(URL(string: "https://bsc-dataseed1.binance.org/")!)
            endpoints.append(URL(string: "https://bsc-dataseed2.binance.org/")!)

        case .arbitrum:
            if let key = apiKey {
                endpoints.append(URL(string: "https://arb-mainnet.g.alchemy.com/v2/\(key)")!)
            }
            endpoints.append(URL(string: "https://arb1.arbitrum.io/rpc")!)

        case .optimism:
            if let key = apiKey {
                endpoints.append(URL(string: "https://opt-mainnet.g.alchemy.com/v2/\(key)")!)
            }
            endpoints.append(URL(string: "https://mainnet.optimism.io")!)

        default:
            break
        }

        return endpoints
    }

    private func estimateGasPrice(priority: FeePriority) async throws -> UInt64 {
        // Get base fee from latest block
        let feeData = try await rpcClient.call(
            method: "eth_feeHistory",
            params: [
                AnyCodable(1),
                AnyCodable("latest"),
                AnyCodable([25, 50, 75]) // Percentiles
            ]
        ) as [String: AnyCodable]

        // Parse fee data and calculate based on priority
        // Simplified implementation
        switch priority {
        case .low:
            return 20_000_000_000 // 20 Gwei
        case .medium:
            return 30_000_000_000 // 30 Gwei
        case .high:
            return 50_000_000_000 // 50 Gwei
        case .custom(let price):
            return price
        }
    }

    private func getRequiredConfirmations() -> Int {
        switch integration.chain {
        case .ethereum, .goerli:
            return 12
        case .polygon, .mumbai:
            return 128
        case .binanceSmartChain:
            return 15
        case .arbitrum, .optimism:
            return 1 // L2s have faster finality
        }
    }
}
