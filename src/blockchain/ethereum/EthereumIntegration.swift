import Foundation
import CryptoKit

/// Complete Ethereum Blockchain Integration Module
/// Implements full Ethereum protocol support including:
/// - Proper Keccak-256 hashing
/// - RLP encoding for transactions
/// - EIP-155 transaction signing with chain ID
/// - EIP-1559 (fee market) transaction support
/// - ERC-20 token contract interaction
/// - Gas estimation and nonce management
/// - Smart contract events and logs parsing
public class EthereumIntegration {

    // MARK: - Types

    public enum Chain: UInt64 {
        case ethereum = 1
        case polygon = 137
        case binanceSmartChain = 56
        case arbitrum = 42161
        case optimism = 10
        case goerli = 5 // Testnet
        case mumbai = 80001 // Polygon testnet
        case sepolia = 11155111 // Ethereum Sepolia testnet

        var name: String {
            switch self {
            case .ethereum: return "Ethereum"
            case .polygon: return "Polygon"
            case .binanceSmartChain: return "Binance Smart Chain"
            case .arbitrum: return "Arbitrum"
            case .optimism: return "Optimism"
            case .goerli: return "Goerli"
            case .mumbai: return "Mumbai"
            case .sepolia: return "Sepolia"
            }
        }

        var rpcURL: String {
            switch self {
            case .ethereum: return "https://eth-mainnet.g.alchemy.com/v2/"
            case .polygon: return "https://polygon-mainnet.g.alchemy.com/v2/"
            case .binanceSmartChain: return "https://bsc-dataseed.binance.org/"
            case .arbitrum: return "https://arb-mainnet.g.alchemy.com/v2/"
            case .optimism: return "https://opt-mainnet.g.alchemy.com/v2/"
            case .goerli: return "https://eth-goerli.g.alchemy.com/v2/"
            case .mumbai: return "https://polygon-mumbai.g.alchemy.com/v2/"
            case .sepolia: return "https://eth-sepolia.g.alchemy.com/v2/"
            }
        }

        var supportsEIP1559: Bool {
            switch self {
            case .ethereum, .polygon, .arbitrum, .optimism, .goerli, .mumbai, .sepolia:
                return true
            case .binanceSmartChain:
                return false
            }
        }
    }

    public struct EthereumAddress {
        let address: String // 0x prefixed hex
        let publicKey: Data

        public init(address: String, publicKey: Data) {
            self.address = address
            self.publicKey = publicKey
        }

        public var checksumAddress: String {
            return EthereumIntegration.toChecksumAddress(address)
        }
    }

    public struct EthereumTransaction {
        let nonce: UInt64
        let gasPrice: UInt64? // wei (legacy transactions)
        let maxFeePerGas: UInt64? // EIP-1559
        let maxPriorityFeePerGas: UInt64? // EIP-1559
        let gasLimit: UInt64
        let to: String
        let value: UInt64 // wei
        let data: Data
        let chainId: UInt64

        public init(nonce: UInt64, gasPrice: UInt64? = nil,
                   maxFeePerGas: UInt64? = nil, maxPriorityFeePerGas: UInt64? = nil,
                   gasLimit: UInt64, to: String, value: UInt64,
                   data: Data = Data(), chainId: UInt64) {
            self.nonce = nonce
            self.gasPrice = gasPrice
            self.maxFeePerGas = maxFeePerGas
            self.maxPriorityFeePerGas = maxPriorityFeePerGas
            self.gasLimit = gasLimit
            self.to = to
            self.value = value
            self.data = data
            self.chainId = chainId
        }

        var isEIP1559: Bool {
            return maxFeePerGas != nil && maxPriorityFeePerGas != nil
        }
    }

    public struct ERC20Token {
        let contractAddress: String
        let name: String
        let symbol: String
        let decimals: UInt8

        public init(contractAddress: String, name: String,
                   symbol: String, decimals: UInt8) {
            self.contractAddress = contractAddress
            self.name = name
            self.symbol = symbol
            self.decimals = decimals
        }

        /// Convert human-readable amount to raw token units
        public func toRawAmount(_ amount: Double) -> UInt64 {
            let multiplier = pow(10.0, Double(decimals))
            return UInt64(amount * multiplier)
        }

        /// Convert raw token units to human-readable amount
        public func fromRawAmount(_ amount: UInt64) -> Double {
            let divisor = pow(10.0, Double(decimals))
            return Double(amount) / divisor
        }
    }

    public struct TransactionReceipt {
        let transactionHash: String
        let blockNumber: UInt64
        let from: String
        let to: String
        let gasUsed: UInt64
        let status: Bool
        let logs: [Log]

        public struct Log {
            let address: String
            let topics: [String]
            let data: Data
            let blockNumber: UInt64
            let transactionHash: String
            let logIndex: UInt64

            /// Decode ERC-20 Transfer event
            public var erc20Transfer: ERC20Transfer? {
                // Transfer(address indexed from, address indexed to, uint256 value)
                guard topics.count == 3,
                      topics[0] == "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef" else {
                    return nil
                }

                let from = "0x" + topics[1].suffix(40)
                let to = "0x" + topics[2].suffix(40)

                guard let value = try? ABIDecoder.decodeUInt256(data) else {
                    return nil
                }

                return ERC20Transfer(
                    tokenAddress: address,
                    from: from,
                    to: to,
                    value: value
                )
            }
        }

        public struct ERC20Transfer {
            let tokenAddress: String
            let from: String
            let to: String
            let value: UInt64
        }

        public init(transactionHash: String, blockNumber: UInt64,
                   from: String, to: String, gasUsed: UInt64,
                   status: Bool, logs: [Log] = []) {
            self.transactionHash = transactionHash
            self.blockNumber = blockNumber
            self.from = from
            self.to = to
            self.gasUsed = gasUsed
            self.status = status
            self.logs = logs
        }
    }

    public struct GasEstimate {
        let gasLimit: UInt64
        let gasPrice: UInt64?
        let maxFeePerGas: UInt64?
        let maxPriorityFeePerGas: UInt64?
        let estimatedCost: UInt64 // In wei

        public var estimatedCostInEth: Double {
            return Double(estimatedCost) / 1_000_000_000_000_000_000.0 // wei to ETH
        }
    }

    public enum EthereumError: Error {
        case invalidAddress
        case invalidChainId
        case networkError(String)
        case insufficientBalance
        case transactionFailed
        case contractCallFailed
        case invalidABI
        case rpcError(String)
        case invalidPrivateKey
        case signingFailed
        case invalidNonce
        case gasEstimationFailed
    }

    // MARK: - Properties

    public let chain: Chain
    private let web3Provider: Web3Provider
    private let addressGenerator: EthereumAddressGenerator
    private let contractInteractor: ContractInteractor
    private let nonceManager: NonceManager

    private var apiKey: String?

    // MARK: - Initialization

    public init(chain: Chain, apiKey: String? = nil) {
        self.chain = chain
        self.apiKey = apiKey
        self.web3Provider = Web3Provider(chain: chain, apiKey: apiKey)
        self.addressGenerator = EthereumAddressGenerator()
        self.contractInteractor = ContractInteractor(provider: web3Provider)
        self.nonceManager = NonceManager(provider: web3Provider)
    }

    // MARK: - Address Generation

    /// Generate Ethereum address from public key using Keccak-256
    /// - Parameter publicKey: Uncompressed public key (64 bytes, no prefix)
    /// - Returns: Ethereum address with checksum
    public func generateAddress(from publicKey: Data) throws -> EthereumAddress {
        guard publicKey.count == 64 else {
            throw EthereumError.invalidAddress
        }

        return try addressGenerator.generate(from: publicKey)
    }

    /// Generate Ethereum address from private key
    /// - Parameter privateKey: 32-byte private key
    /// - Returns: Ethereum address with checksum
    public func generateAddress(fromPrivateKey privateKey: Data) throws -> EthereumAddress {
        guard privateKey.count == 32 else {
            throw EthereumError.invalidPrivateKey
        }

        // Derive public key using secp256k1
        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: false)

        // Remove 0x04 prefix if present
        let pubKeyData = publicKey.count == 65 ? publicKey.dropFirst() : publicKey

        return try generateAddress(from: pubKeyData)
    }

    /// Validate Ethereum address format and checksum
    /// - Parameter address: Address string (with or without 0x prefix)
    /// - Returns: True if valid
    public func validateAddress(_ address: String) -> Bool {
        return addressGenerator.validate(address)
    }

    /// Convert address to EIP-55 checksum format
    /// - Parameter address: Ethereum address
    /// - Returns: Checksummed address
    public static func toChecksumAddress(_ address: String) -> String {
        let addr = address.lowercased().stripHexPrefix()

        guard let addressData = addr.data(using: .utf8) else {
            return "0x" + addr
        }

        let hash = Keccak256.hash(addressData).hexString

        var checksumAddress = "0x"
        for (i, char) in addr.enumerated() {
            if let hashChar = hash[hash.index(hash.startIndex, offsetBy: i)].hexDigitValue,
               hashChar >= 8 {
                checksumAddress += String(char).uppercased()
            } else {
                checksumAddress += String(char)
            }
        }

        return checksumAddress
    }

    // MARK: - Balance Queries

    /// Get ETH balance for address
    /// - Parameter address: Ethereum address
    /// - Returns: Balance in wei
    public func getBalance(for address: String) async throws -> UInt64 {
        return try await web3Provider.getBalance(address: address)
    }

    /// Get ETH balance in Ether (human-readable)
    /// - Parameter address: Ethereum address
    /// - Returns: Balance in ETH
    public func getBalanceInEth(for address: String) async throws -> Double {
        let wei = try await getBalance(for: address)
        return Double(wei) / 1_000_000_000_000_000_000.0
    }

    /// Get ERC-20 token balance
    /// - Parameters:
    ///   - token: ERC-20 token contract
    ///   - address: Holder address
    /// - Returns: Token balance (raw amount)
    public func getTokenBalance(token: ERC20Token, for address: String) async throws -> UInt64 {
        return try await contractInteractor.getERC20Balance(
            tokenAddress: token.contractAddress,
            holderAddress: address
        )
    }

    /// Get ERC-20 token balance (human-readable)
    /// - Parameters:
    ///   - token: ERC-20 token contract
    ///   - address: Holder address
    /// - Returns: Token balance adjusted for decimals
    public func getTokenBalanceFormatted(token: ERC20Token, for address: String) async throws -> Double {
        let rawBalance = try await getTokenBalance(token: token, for: address)
        return token.fromRawAmount(rawBalance)
    }

    // MARK: - Nonce Management

    /// Get current nonce for address
    /// - Parameter address: Ethereum address
    /// - Returns: Next nonce to use
    public func getNonce(for address: String) async throws -> UInt64 {
        return try await nonceManager.getNonce(for: address)
    }

    /// Get nonce from pending transactions (includes unconfirmed)
    /// - Parameter address: Ethereum address
    /// - Returns: Next nonce including pending transactions
    public func getPendingNonce(for address: String) async throws -> UInt64 {
        return try await nonceManager.getPendingNonce(for: address)
    }

    // MARK: - Gas Estimation

    /// Estimate gas for transaction with detailed breakdown
    /// - Parameters:
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - value: ETH value in wei
    ///   - data: Transaction data
    /// - Returns: Complete gas estimate including fees
    public func estimateGasDetailed(
        from: String,
        to: String,
        value: UInt64 = 0,
        data: Data = Data()
    ) async throws -> GasEstimate {
        let gasLimit = try await web3Provider.estimateGas(
            from: from,
            to: to,
            value: value,
            data: data
        )

        if chain.supportsEIP1559 {
            let (baseFee, priorityFee) = try await web3Provider.getFeeData()
            let maxFee = baseFee * 2 + priorityFee
            let estimatedCost = gasLimit * maxFee

            return GasEstimate(
                gasLimit: gasLimit,
                gasPrice: nil,
                maxFeePerGas: maxFee,
                maxPriorityFeePerGas: priorityFee,
                estimatedCost: estimatedCost
            )
        } else {
            let gasPrice = try await web3Provider.getGasPrice()
            let estimatedCost = gasLimit * gasPrice

            return GasEstimate(
                gasLimit: gasLimit,
                gasPrice: gasPrice,
                maxFeePerGas: nil,
                maxPriorityFeePerGas: nil,
                estimatedCost: estimatedCost
            )
        }
    }

    // MARK: - Transaction Creation

    /// Create ETH transfer transaction (auto-detects EIP-1559 support)
    /// - Parameters:
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - amount: Amount in wei
    ///   - gasLimit: Gas limit (optional, will estimate if not provided)
    /// - Returns: Unsigned transaction
    public func createTransferTransaction(
        from: String,
        to: String,
        amount: UInt64,
        gasLimit: UInt64? = nil
    ) async throws -> EthereumTransaction {
        guard validateAddress(from) && validateAddress(to) else {
            throw EthereumError.invalidAddress
        }

        let nonce = try await getNonce(for: from)

        if chain.supportsEIP1559 {
            return try await createEIP1559Transaction(
                from: from,
                to: to,
                amount: amount,
                gasLimit: gasLimit
            )
        } else {
            return try await createLegacyTransaction(
                from: from,
                to: to,
                amount: amount,
                gasLimit: gasLimit
            )
        }
    }

    /// Create legacy transaction (pre-EIP-1559)
    private func createLegacyTransaction(
        from: String,
        to: String,
        amount: UInt64,
        gasLimit: UInt64? = nil
    ) async throws -> EthereumTransaction {
        let nonce = try await getNonce(for: from)
        let gasPrice = try await web3Provider.getGasPrice()

        let gas = gasLimit ?? (try await web3Provider.estimateGas(
            from: from,
            to: to,
            value: amount
        ))

        return EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: gas,
            to: to,
            value: amount,
            chainId: chain.rawValue
        )
    }

    /// Create EIP-1559 transaction (Type 2)
    /// - Parameters:
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - amount: Amount in wei
    ///   - maxFeePerGas: Maximum fee per gas (optional)
    ///   - maxPriorityFeePerGas: Maximum priority fee (optional)
    ///   - gasLimit: Gas limit (optional)
    /// - Returns: Unsigned EIP-1559 transaction
    public func createEIP1559Transaction(
        from: String,
        to: String,
        amount: UInt64,
        maxFeePerGas: UInt64? = nil,
        maxPriorityFeePerGas: UInt64? = nil,
        gasLimit: UInt64? = nil
    ) async throws -> EthereumTransaction {
        let nonce = try await getNonce(for: from)

        // Get fee data if not provided
        let (baseFee, priorityFee) = try await web3Provider.getFeeData()

        let maxFee = maxFeePerGas ?? (baseFee * 2 + priorityFee)
        let maxPriority = maxPriorityFeePerGas ?? priorityFee

        let gas = gasLimit ?? (try await web3Provider.estimateGas(
            from: from,
            to: to,
            value: amount
        ))

        return EthereumTransaction(
            nonce: nonce,
            maxFeePerGas: maxFee,
            maxPriorityFeePerGas: maxPriority,
            gasLimit: gas,
            to: to,
            value: amount,
            chainId: chain.rawValue
        )
    }

    /// Create ERC-20 token transfer transaction
    /// - Parameters:
    ///   - token: ERC-20 token
    ///   - from: Sender address
    ///   - to: Recipient address
    ///   - amount: Token amount (raw, not adjusted for decimals)
    /// - Returns: Unsigned transaction with encoded function call
    public func createTokenTransfer(
        token: ERC20Token,
        from: String,
        to: String,
        amount: UInt64
    ) async throws -> EthereumTransaction {
        // Encode ERC-20 transfer function call
        let data = try ABIEncoder.encodeERC20Transfer(to: to, amount: amount)

        let nonce = try await getNonce(for: from)

        if chain.supportsEIP1559 {
            let (baseFee, priorityFee) = try await web3Provider.getFeeData()
            let maxFee = baseFee * 2 + priorityFee

            let gasLimit = try await web3Provider.estimateGas(
                from: from,
                to: token.contractAddress,
                value: 0,
                data: data
            )

            return EthereumTransaction(
                nonce: nonce,
                maxFeePerGas: maxFee,
                maxPriorityFeePerGas: priorityFee,
                gasLimit: gasLimit,
                to: token.contractAddress,
                value: 0,
                data: data,
                chainId: chain.rawValue
            )
        } else {
            let gasPrice = try await web3Provider.getGasPrice()
            let gasLimit = try await web3Provider.estimateGas(
                from: from,
                to: token.contractAddress,
                value: 0,
                data: data
            )

            return EthereumTransaction(
                nonce: nonce,
                gasPrice: gasPrice,
                gasLimit: gasLimit,
                to: token.contractAddress,
                value: 0,
                data: data,
                chainId: chain.rawValue
            )
        }
    }

    // MARK: - Transaction Signing

    /// Sign transaction with private key
    /// - Parameters:
    ///   - transaction: Transaction to sign
    ///   - privateKey: 32-byte private key
    /// - Returns: Signed transaction data (RLP encoded)
    public func signTransaction(
        _ transaction: EthereumTransaction,
        privateKey: Data
    ) throws -> Data {
        guard privateKey.count == 32 else {
            throw EthereumError.invalidPrivateKey
        }

        return try EthereumSigner.signTransaction(transaction, privateKey: privateKey)
    }

    // MARK: - Transaction Broadcasting

    /// Send signed transaction to network
    /// - Parameter signedTransaction: Signed transaction data (RLP encoded)
    /// - Returns: Transaction hash
    public func sendTransaction(_ signedTransaction: Data) async throws -> String {
        return try await web3Provider.sendRawTransaction(signedTransaction)
    }

    /// Sign and send transaction in one call
    /// - Parameters:
    ///   - transaction: Transaction to sign and send
    ///   - privateKey: Private key for signing
    /// - Returns: Transaction hash
    public func signAndSendTransaction(
        _ transaction: EthereumTransaction,
        privateKey: Data
    ) async throws -> String {
        let signedTx = try signTransaction(transaction, privateKey: privateKey)
        return try await sendTransaction(signedTx)
    }

    /// Wait for transaction confirmation
    /// - Parameters:
    ///   - txHash: Transaction hash
    ///   - confirmations: Number of confirmations to wait for
    ///   - timeout: Maximum time to wait in seconds
    /// - Returns: Transaction receipt
    public func waitForConfirmation(
        txHash: String,
        confirmations: UInt64 = 1,
        timeout: TimeInterval = 300
    ) async throws -> TransactionReceipt {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if let receipt = try? await web3Provider.getTransactionReceipt(txHash: txHash) {
                let currentBlock = try await web3Provider.getBlockNumber()

                if currentBlock - receipt.blockNumber >= confirmations {
                    return receipt
                }
            }

            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        }

        throw EthereumError.transactionFailed
    }

    // MARK: - Smart Contract Interaction

    /// Call smart contract view/pure function
    /// - Parameters:
    ///   - contractAddress: Contract address
    ///   - functionSignature: Function signature (e.g., "balanceOf(address)")
    ///   - parameters: Function parameters
    /// - Returns: Function call result
    public func callContractFunction(
        contractAddress: String,
        functionSignature: String,
        parameters: [ABIValue]
    ) async throws -> Data {
        let data = try ABIEncoder.encodeFunctionCall(
            functionSignature: functionSignature,
            parameters: parameters
        )

        return try await contractInteractor.call(
            contractAddress: contractAddress,
            data: data
        )
    }

    /// Get ERC-20 token information
    /// - Parameter tokenAddress: Token contract address
    /// - Returns: Token details
    public func getERC20TokenInfo(tokenAddress: String) async throws -> ERC20Token {
        // Get name
        let nameData = try await callContractFunction(
            contractAddress: tokenAddress,
            functionSignature: "name()",
            parameters: []
        )
        let name = try ABIDecoder.decodeString(nameData)

        // Get symbol
        let symbolData = try await callContractFunction(
            contractAddress: tokenAddress,
            functionSignature: "symbol()",
            parameters: []
        )
        let symbol = try ABIDecoder.decodeString(symbolData)

        // Get decimals
        let decimalsData = try await callContractFunction(
            contractAddress: tokenAddress,
            functionSignature: "decimals()",
            parameters: []
        )
        let decimals = try ABIDecoder.decodeUInt256(decimalsData)

        return ERC20Token(
            contractAddress: tokenAddress,
            name: name,
            symbol: symbol,
            decimals: UInt8(decimals)
        )
    }

    // MARK: - Transaction History

    /// Get transaction details
    /// - Parameter txHash: Transaction hash
    /// - Returns: Transaction receipt
    public func getTransactionDetails(_ txHash: String) async throws -> TransactionReceipt {
        return try await web3Provider.getTransactionReceipt(txHash: txHash)
    }

    /// Get current block number
    /// - Returns: Latest block number
    public func getBlockNumber() async throws -> UInt64 {
        return try await web3Provider.getBlockNumber()
    }
}

// MARK: - Supporting Classes

private class EthereumAddressGenerator {
    func generate(from publicKey: Data) throws -> EthereumIntegration.EthereumAddress {
        // Ethereum address is last 20 bytes of keccak256(publicKey)
        let addressData = Keccak256.ethereumAddress(from: publicKey)
        let address = "0x" + addressData.hexString

        let checksummed = Keccak256.checksumAddress(addressData)

        return EthereumIntegration.EthereumAddress(
            address: checksummed,
            publicKey: publicKey
        )
    }

    func validate(_ address: String) -> Bool {
        let addr = address.stripHexPrefix()

        // Check length
        guard addr.count == 40 else { return false }

        // Check hex characters
        guard addr.allSatisfy({ $0.isHexDigit }) else { return false }

        // Validate checksum if mixed case
        if addr != addr.lowercased() && addr != addr.uppercased() {
            return Keccak256.isValidChecksumAddress(address)
        }

        return true
    }
}

private class NonceManager {
    let provider: Web3Provider
    private var pendingNonces: [String: UInt64] = [:]

    init(provider: Web3Provider) {
        self.provider = provider
    }

    func getNonce(for address: String) async throws -> UInt64 {
        return try await provider.getTransactionCount(address: address)
    }

    func getPendingNonce(for address: String) async throws -> UInt64 {
        return try await provider.getTransactionCount(address: address, blockTag: "pending")
    }
}

// MARK: - Web3Provider

private class Web3Provider {
    let chain: EthereumIntegration.Chain
    let rpcURL: URL
    private var requestId: Int = 1

    init(chain: EthereumIntegration.Chain, apiKey: String?) {
        self.chain = chain
        var urlString = chain.rpcURL
        if let key = apiKey, !urlString.hasSuffix("/") {
            urlString += key
        } else if let key = apiKey {
            urlString = urlString + key
        }
        self.rpcURL = URL(string: urlString)!
    }

    func getBalance(address: String) async throws -> UInt64 {
        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_getBalance",
            params: [address, "latest"]
        )

        guard let hexBalance = response.result else {
            throw EthereumIntegration.EthereumError.rpcError("No balance returned")
        }

        return UInt64(hexBalance.stripHexPrefix(), radix: 16) ?? 0
    }

    func getTransactionCount(address: String, blockTag: String = "latest") async throws -> UInt64 {
        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_getTransactionCount",
            params: [address, blockTag]
        )

        guard let hexNonce = response.result else {
            throw EthereumIntegration.EthereumError.rpcError("No nonce returned")
        }

        return UInt64(hexNonce.stripHexPrefix(), radix: 16) ?? 0
    }

    func getGasPrice() async throws -> UInt64 {
        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_gasPrice",
            params: []
        )

        guard let hexGasPrice = response.result else {
            throw EthereumIntegration.EthereumError.rpcError("No gas price returned")
        }

        return UInt64(hexGasPrice.stripHexPrefix(), radix: 16) ?? 0
    }

    func getFeeData() async throws -> (baseFee: UInt64, priorityFee: UInt64) {
        // Get base fee from latest block
        let blockResponse: RPCResponse<Block> = try await rpcCall(
            method: "eth_getBlockByNumber",
            params: ["latest", false]
        )

        let baseFeeHex = blockResponse.result?.baseFeePerGas ?? "0x0"
        let baseFee = UInt64(baseFeeHex.stripHexPrefix(), radix: 16) ?? 0

        // Get priority fee
        let priorityResponse: RPCResponse<String> = try await rpcCall(
            method: "eth_maxPriorityFeePerGas",
            params: []
        )

        let priorityFee = UInt64(priorityResponse.result?.stripHexPrefix() ?? "0", radix: 16) ?? 1_000_000_000

        return (baseFee, priorityFee)
    }

    func getBlockNumber() async throws -> UInt64 {
        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_blockNumber",
            params: []
        )

        guard let hexBlock = response.result else {
            throw EthereumIntegration.EthereumError.rpcError("No block number returned")
        }

        return UInt64(hexBlock.stripHexPrefix(), radix: 16) ?? 0
    }

    func estimateGas(from: String, to: String, value: UInt64, data: Data = Data()) async throws -> UInt64 {
        var params: [String: Any] = [
            "from": from,
            "to": to
        ]

        if value > 0 {
            params["value"] = "0x" + String(value, radix: 16)
        }

        if !data.isEmpty {
            params["data"] = "0x" + data.hexString
        }

        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_estimateGas",
            params: [params]
        )

        guard let hexGas = response.result else {
            throw EthereumIntegration.EthereumError.gasEstimationFailed
        }

        return UInt64(hexGas.stripHexPrefix(), radix: 16) ?? 21000
    }

    func sendRawTransaction(_ signedTx: Data) async throws -> String {
        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_sendRawTransaction",
            params: ["0x" + signedTx.hexString]
        )

        guard let txHash = response.result else {
            if let error = response.error {
                throw EthereumIntegration.EthereumError.rpcError(error.message)
            }
            throw EthereumIntegration.EthereumError.transactionFailed
        }

        return txHash
    }

    func getTransactionReceipt(txHash: String) async throws -> EthereumIntegration.TransactionReceipt {
        let response: RPCResponse<ReceiptResponse> = try await rpcCall(
            method: "eth_getTransactionReceipt",
            params: [txHash]
        )

        guard let receipt = response.result else {
            throw EthereumIntegration.EthereumError.transactionFailed
        }

        let logs = receipt.logs.map { logResponse in
            EthereumIntegration.TransactionReceipt.Log(
                address: logResponse.address,
                topics: logResponse.topics,
                data: Data(hex: logResponse.data.stripHexPrefix()) ?? Data(),
                blockNumber: UInt64(logResponse.blockNumber.stripHexPrefix(), radix: 16) ?? 0,
                transactionHash: logResponse.transactionHash,
                logIndex: UInt64(logResponse.logIndex.stripHexPrefix(), radix: 16) ?? 0
            )
        }

        return EthereumIntegration.TransactionReceipt(
            transactionHash: receipt.transactionHash,
            blockNumber: UInt64(receipt.blockNumber.stripHexPrefix(), radix: 16) ?? 0,
            from: receipt.from,
            to: receipt.to ?? "",
            gasUsed: UInt64(receipt.gasUsed.stripHexPrefix(), radix: 16) ?? 0,
            status: receipt.status == "0x1",
            logs: logs
        )
    }

    func call(to: String, data: Data) async throws -> Data {
        let params: [String: Any] = [
            "to": to,
            "data": "0x" + data.hexString
        ]

        let response: RPCResponse<String> = try await rpcCall(
            method: "eth_call",
            params: [params, "latest"]
        )

        guard let result = response.result else {
            if let error = response.error {
                throw EthereumIntegration.EthereumError.rpcError(error.message)
            }
            throw EthereumIntegration.EthereumError.contractCallFailed
        }

        return Data(hex: result.stripHexPrefix()) ?? Data()
    }

    // MARK: - RPC Helpers

    private func rpcCall<T: Decodable>(method: String, params: [Any]) async throws -> RPCResponse<T> {
        let rpcRequest = RPCRequest(
            jsonrpc: "2.0",
            id: requestId,
            method: method,
            params: params
        )
        requestId += 1

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(AnyCodableRequest(request: rpcRequest))

        var request = URLRequest(url: rpcURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw EthereumIntegration.EthereumError.networkError("HTTP error")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(RPCResponse<T>.self, from: data)
    }

    // MARK: - RPC Types

    struct RPCRequest: Encodable {
        let jsonrpc: String
        let id: Int
        let method: String
        let params: [Any]

        enum CodingKeys: String, CodingKey {
            case jsonrpc, id, method, params
        }
    }

    struct AnyCodableRequest: Encodable {
        let request: RPCRequest

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(request.jsonrpc, forKey: .jsonrpc)
            try container.encode(request.id, forKey: .id)
            try container.encode(request.method, forKey: .method)

            var paramsContainer = container.nestedUnkeyedContainer(forKey: .params)
            for param in request.params {
                if let string = param as? String {
                    try paramsContainer.encode(string)
                } else if let dict = param as? [String: Any] {
                    try paramsContainer.encode(AnyCodableDict(dict: dict))
                } else if let bool = param as? Bool {
                    try paramsContainer.encode(bool)
                } else if let int = param as? Int {
                    try paramsContainer.encode(int)
                }
            }
        }

        enum CodingKeys: String, CodingKey {
            case jsonrpc, id, method, params
        }
    }

    struct AnyCodableDict: Encodable {
        let dict: [String: Any]

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: DynamicCodingKey.self)
            for (key, value) in dict {
                let codingKey = DynamicCodingKey(stringValue: key)
                if let string = value as? String {
                    try container.encode(string, forKey: codingKey)
                } else if let int = value as? Int {
                    try container.encode(int, forKey: codingKey)
                } else if let bool = value as? Bool {
                    try container.encode(bool, forKey: codingKey)
                }
            }
        }
    }

    struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            self.intValue = intValue
            self.stringValue = "\(intValue)"
        }
    }

    struct RPCResponse<T: Decodable>: Decodable {
        let jsonrpc: String
        let id: Int
        let result: T?
        let error: RPCError?
    }

    struct RPCError: Decodable {
        let code: Int
        let message: String
    }

    struct Block: Decodable {
        let baseFeePerGas: String?
    }

    struct ReceiptResponse: Decodable {
        let transactionHash: String
        let blockNumber: String
        let from: String
        let to: String?
        let gasUsed: String
        let status: String
        let logs: [LogResponse]
    }

    struct LogResponse: Decodable {
        let address: String
        let topics: [String]
        let data: String
        let blockNumber: String
        let transactionHash: String
        let logIndex: String
    }
}

// MARK: - ContractInteractor

private class ContractInteractor {
    let provider: Web3Provider

    init(provider: Web3Provider) {
        self.provider = provider
    }

    func getERC20Balance(tokenAddress: String, holderAddress: String) async throws -> UInt64 {
        // Encode balanceOf(address) call
        let data = try ABIEncoder.encodeERC20BalanceOf(account: holderAddress)

        // Make eth_call
        let result = try await provider.call(to: tokenAddress, data: data)

        // Decode uint256 result
        guard result.count >= 32 else {
            return 0
        }

        return try ABIDecoder.decodeUInt256(result)
    }

    func call(contractAddress: String, data: Data) async throws -> Data {
        return try await provider.call(to: contractAddress, data: data)
    }
}

// MARK: - String Extension

private extension String {
    func stripHexPrefix() -> String {
        return self.hasPrefix("0x") ? String(self.dropFirst(2)) : self
    }
}
