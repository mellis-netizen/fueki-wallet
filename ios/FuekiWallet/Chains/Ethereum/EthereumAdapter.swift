//
//  EthereumAdapter.swift
//  FuekiWallet
//
//  Production-grade Ethereum blockchain adapter
//

import Foundation
import web3swift
import BigInt
import CryptoSwift

/// Production-grade Ethereum blockchain adapter
public final class EthereumAdapter {

    // MARK: - Properties

    private let rpcURL: URL
    private let chainID: BigUInt
    private let web3: Web3
    private let erc20Handler: ERC20Handler
    private let gasEstimator: GasEstimator

    // Network configurations
    public enum Network {
        case mainnet
        case goerli
        case sepolia
        case polygon
        case arbitrum
        case optimism
        case custom(rpcURL: String, chainID: Int)

        var rpcURL: String {
            switch self {
            case .mainnet: return "https://eth-mainnet.g.alchemy.com/v2/"
            case .goerli: return "https://eth-goerli.g.alchemy.com/v2/"
            case .sepolia: return "https://eth-sepolia.g.alchemy.com/v2/"
            case .polygon: return "https://polygon-mainnet.g.alchemy.com/v2/"
            case .arbitrum: return "https://arb-mainnet.g.alchemy.com/v2/"
            case .optimism: return "https://opt-mainnet.g.alchemy.com/v2/"
            case .custom(let url, _): return url
            }
        }

        var chainID: Int {
            switch self {
            case .mainnet: return 1
            case .goerli: return 5
            case .sepolia: return 11155111
            case .polygon: return 137
            case .arbitrum: return 42161
            case .optimism: return 10
            case .custom(_, let id): return id
            }
        }
    }

    // MARK: - Initialization

    public init(network: Network, apiKey: String? = nil) throws {
        var urlString = network.rpcURL
        if let apiKey = apiKey {
            urlString += apiKey
        }

        guard let url = URL(string: urlString) else {
            throw EthereumAdapterError.invalidRPCURL
        }

        self.rpcURL = url
        self.chainID = BigUInt(network.chainID)

        guard let web3Instance = Web3(url: url) else {
            throw EthereumAdapterError.web3InitializationFailed
        }

        self.web3 = web3Instance
        self.erc20Handler = ERC20Handler(web3: web3Instance)
        self.gasEstimator = GasEstimator(web3: web3Instance, chainID: self.chainID)
    }

    // MARK: - Balance Operations

    /// Fetch ETH balance for an address
    public func getBalance(address: String) async throws -> BigUInt {
        guard let ethAddress = EthereumAddress(address) else {
            throw EthereumAdapterError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let balance = try self.web3.eth.getBalance(for: ethAddress)
                    continuation.resume(returning: balance)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.balanceFetchFailed(error))
                }
            }
        }
    }

    /// Fetch ERC20 token balance
    public func getTokenBalance(tokenAddress: String, walletAddress: String) async throws -> BigUInt {
        return try await erc20Handler.getBalance(tokenAddress: tokenAddress, walletAddress: walletAddress)
    }

    // MARK: - Transaction Building

    /// Build ETH transfer transaction
    public func buildTransaction(
        from: String,
        to: String,
        amount: BigUInt,
        gasPrice: BigUInt? = nil,
        gasLimit: BigUInt? = nil,
        nonce: BigUInt? = nil,
        data: Data = Data()
    ) async throws -> EthereumTransaction {

        guard let fromAddress = EthereumAddress(from),
              let toAddress = EthereumAddress(to) else {
            throw EthereumAdapterError.invalidAddress
        }

        // Fetch nonce if not provided
        let txNonce = try await nonce ?? self.getNonce(address: from)

        // Estimate gas if not provided
        let estimatedGasLimit = try await gasLimit ?? self.estimateGas(
            from: from,
            to: to,
            value: amount,
            data: data
        )

        // Get gas price if not provided
        let txGasPrice = try await gasPrice ?? self.gasEstimator.estimateGasPrice()

        // Build transaction
        var transaction = EthereumTransaction(
            nonce: txNonce,
            gasPrice: txGasPrice,
            gasLimit: estimatedGasLimit,
            to: toAddress,
            value: amount,
            data: data,
            v: BigUInt(0),
            r: BigUInt(0),
            s: BigUInt(0)
        )

        return transaction
    }

    /// Build ERC20 token transfer transaction
    public func buildTokenTransfer(
        tokenAddress: String,
        from: String,
        to: String,
        amount: BigUInt,
        gasPrice: BigUInt? = nil,
        gasLimit: BigUInt? = nil
    ) async throws -> EthereumTransaction {

        return try await erc20Handler.buildTransferTransaction(
            tokenAddress: tokenAddress,
            from: from,
            to: to,
            amount: amount,
            gasPrice: gasPrice,
            gasLimit: gasLimit
        )
    }

    // MARK: - Transaction Signing

    /// Sign transaction with private key
    public func signTransaction(
        _ transaction: inout EthereumTransaction,
        privateKey: String
    ) throws {

        guard let privateKeyData = Data.fromHex(privateKey) else {
            throw EthereumAdapterError.invalidPrivateKey
        }

        guard let keystore = try? EthereumKeystoreV3(privateKey: privateKeyData) else {
            throw EthereumAdapterError.keystoreCreationFailed
        }

        try transaction.sign(privateKey: privateKeyData, chainID: chainID)
    }

    // MARK: - Transaction Broadcasting

    /// Broadcast signed transaction to network
    public func broadcastTransaction(_ transaction: EthereumTransaction) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let txHash = try self.web3.eth.sendRawTransaction(transaction)
                    continuation.resume(returning: txHash.hash)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.broadcastFailed(error))
                }
            }
        }
    }

    /// Send ETH transaction (build, sign, broadcast)
    public func sendTransaction(
        from: String,
        to: String,
        amount: BigUInt,
        privateKey: String,
        gasPrice: BigUInt? = nil,
        gasLimit: BigUInt? = nil
    ) async throws -> String {

        var transaction = try await buildTransaction(
            from: from,
            to: to,
            amount: amount,
            gasPrice: gasPrice,
            gasLimit: gasLimit
        )

        try signTransaction(&transaction, privateKey: privateKey)
        return try await broadcastTransaction(transaction)
    }

    // MARK: - Transaction History

    /// Fetch transaction history for an address
    public func getTransactionHistory(
        address: String,
        startBlock: BigUInt? = nil,
        endBlock: BigUInt? = nil,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> [EthereumTransactionDetails] {

        guard let ethAddress = EthereumAddress(address) else {
            throw EthereumAdapterError.invalidAddress
        }

        // Fetch current block
        let currentBlock = try await getCurrentBlock()
        let start = startBlock ?? BigUInt(0)
        let end = endBlock ?? currentBlock

        // Fetch transactions in range
        var transactions: [EthereumTransactionDetails] = []

        for blockNumber in stride(from: end, through: start, by: -1) {
            if transactions.count >= pageSize {
                break
            }

            if let block = try? await getBlock(number: blockNumber) {
                let blockTxs = block.transactions.compactMap { txHash -> EthereumTransactionDetails? in
                    guard let tx = try? self.getTransactionDetails(hash: txHash) else {
                        return nil
                    }

                    // Filter for address
                    if tx.from.address.lowercased() == address.lowercased() ||
                       tx.to?.address.lowercased() == address.lowercased() {
                        return tx
                    }
                    return nil
                }

                transactions.append(contentsOf: blockTxs)
            }
        }

        // Apply pagination
        let startIndex = (page - 1) * pageSize
        let endIndex = min(startIndex + pageSize, transactions.count)

        guard startIndex < transactions.count else {
            return []
        }

        return Array(transactions[startIndex..<endIndex])
    }

    /// Get transaction details by hash
    public func getTransactionDetails(hash: String) async throws -> EthereumTransactionDetails {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let details = try self.web3.eth.getTransactionDetails(hash)
                    continuation.resume(returning: details)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.transactionFetchFailed(error))
                }
            }
        }
    }

    /// Get transaction receipt
    public func getTransactionReceipt(hash: String) async throws -> TransactionReceipt {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let receipt = try self.web3.eth.getTransactionReceipt(hash)
                    continuation.resume(returning: receipt)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.receiptFetchFailed(error))
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func getNonce(address: String) async throws -> BigUInt {
        guard let ethAddress = EthereumAddress(address) else {
            throw EthereumAdapterError.invalidAddress
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let nonce = try self.web3.eth.getTransactionCount(for: ethAddress)
                    continuation.resume(returning: nonce)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.nonceFetchFailed(error))
                }
            }
        }
    }

    private func estimateGas(from: String, to: String, value: BigUInt, data: Data) async throws -> BigUInt {
        return try await gasEstimator.estimateGas(from: from, to: to, value: value, data: data)
    }

    private func getCurrentBlock() async throws -> BigUInt {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let blockNumber = try self.web3.eth.getBlockNumber()
                    continuation.resume(returning: blockNumber)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.blockFetchFailed(error))
                }
            }
        }
    }

    private func getBlock(number: BigUInt) async throws -> Block {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: EthereumAdapterError.adapterDeallocated)
                    return
                }

                do {
                    let block = try self.web3.eth.getBlockByNumber(number)
                    continuation.resume(returning: block)
                } catch {
                    continuation.resume(throwing: EthereumAdapterError.blockFetchFailed(error))
                }
            }
        }
    }
}

// MARK: - Error Types

public enum EthereumAdapterError: LocalizedError {
    case invalidRPCURL
    case web3InitializationFailed
    case invalidAddress
    case invalidPrivateKey
    case keystoreCreationFailed
    case balanceFetchFailed(Error)
    case nonceFetchFailed(Error)
    case broadcastFailed(Error)
    case transactionFetchFailed(Error)
    case receiptFetchFailed(Error)
    case blockFetchFailed(Error)
    case adapterDeallocated

    public var errorDescription: String? {
        switch self {
        case .invalidRPCURL:
            return "Invalid RPC URL provided"
        case .web3InitializationFailed:
            return "Failed to initialize Web3 instance"
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .invalidPrivateKey:
            return "Invalid private key format"
        case .keystoreCreationFailed:
            return "Failed to create keystore"
        case .balanceFetchFailed(let error):
            return "Failed to fetch balance: \(error.localizedDescription)"
        case .nonceFetchFailed(let error):
            return "Failed to fetch nonce: \(error.localizedDescription)"
        case .broadcastFailed(let error):
            return "Failed to broadcast transaction: \(error.localizedDescription)"
        case .transactionFetchFailed(let error):
            return "Failed to fetch transaction: \(error.localizedDescription)"
        case .receiptFetchFailed(let error):
            return "Failed to fetch receipt: \(error.localizedDescription)"
        case .blockFetchFailed(let error):
            return "Failed to fetch block: \(error.localizedDescription)"
        case .adapterDeallocated:
            return "Adapter was deallocated"
        }
    }
}
