//
//  ERC20Handler.swift
//  FuekiWallet
//
//  Production-grade ERC20 token handler
//

import Foundation
import web3swift
import BigInt

/// Handles ERC20 token operations
public final class ERC20Handler {

    // MARK: - Properties

    private let web3: Web3

    // ERC20 ABI
    private let erc20ABI = """
    [
        {
            "constant": true,
            "inputs": [],
            "name": "name",
            "outputs": [{"name": "", "type": "string"}],
            "type": "function"
        },
        {
            "constant": true,
            "inputs": [],
            "name": "symbol",
            "outputs": [{"name": "", "type": "string"}],
            "type": "function"
        },
        {
            "constant": true,
            "inputs": [],
            "name": "decimals",
            "outputs": [{"name": "", "type": "uint8"}],
            "type": "function"
        },
        {
            "constant": true,
            "inputs": [],
            "name": "totalSupply",
            "outputs": [{"name": "", "type": "uint256"}],
            "type": "function"
        },
        {
            "constant": true,
            "inputs": [{"name": "_owner", "type": "address"}],
            "name": "balanceOf",
            "outputs": [{"name": "balance", "type": "uint256"}],
            "type": "function"
        },
        {
            "constant": false,
            "inputs": [
                {"name": "_to", "type": "address"},
                {"name": "_value", "type": "uint256"}
            ],
            "name": "transfer",
            "outputs": [{"name": "", "type": "bool"}],
            "type": "function"
        },
        {
            "constant": false,
            "inputs": [
                {"name": "_from", "type": "address"},
                {"name": "_to", "type": "address"},
                {"name": "_value", "type": "uint256"}
            ],
            "name": "transferFrom",
            "outputs": [{"name": "", "type": "bool"}],
            "type": "function"
        },
        {
            "constant": false,
            "inputs": [
                {"name": "_spender", "type": "address"},
                {"name": "_value", "type": "uint256"}
            ],
            "name": "approve",
            "outputs": [{"name": "", "type": "bool"}],
            "type": "function"
        },
        {
            "constant": true,
            "inputs": [
                {"name": "_owner", "type": "address"},
                {"name": "_spender", "type": "address"}
            ],
            "name": "allowance",
            "outputs": [{"name": "", "type": "uint256"}],
            "type": "function"
        },
        {
            "anonymous": false,
            "inputs": [
                {"indexed": true, "name": "from", "type": "address"},
                {"indexed": true, "name": "to", "type": "address"},
                {"indexed": false, "name": "value", "type": "uint256"}
            ],
            "name": "Transfer",
            "type": "event"
        },
        {
            "anonymous": false,
            "inputs": [
                {"indexed": true, "name": "owner", "type": "address"},
                {"indexed": true, "name": "spender", "type": "address"},
                {"indexed": false, "name": "value", "type": "uint256"}
            ],
            "name": "Approval",
            "type": "event"
        }
    ]
    """

    // MARK: - Initialization

    public init(web3: Web3) {
        self.web3 = web3
    }

    // MARK: - Token Information

    /// Get token metadata
    public func getTokenInfo(tokenAddress: String) async throws -> ERC20TokenInfo {
        guard let contractAddress = EthereumAddress(tokenAddress) else {
            throw ERC20Error.invalidTokenAddress
        }

        let contract = try createContract(address: contractAddress)

        async let name = getTokenName(contract: contract)
        async let symbol = getTokenSymbol(contract: contract)
        async let decimals = getTokenDecimals(contract: contract)
        async let totalSupply = getTotalSupply(contract: contract)

        return try await ERC20TokenInfo(
            address: tokenAddress,
            name: name,
            symbol: symbol,
            decimals: decimals,
            totalSupply: totalSupply
        )
    }

    /// Get token balance
    public func getBalance(tokenAddress: String, walletAddress: String) async throws -> BigUInt {
        guard let contractAddress = EthereumAddress(tokenAddress),
              let walletAddr = EthereumAddress(walletAddress) else {
            throw ERC20Error.invalidAddress
        }

        let contract = try createContract(address: contractAddress)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var options = TransactionOptions.defaultOptions
                    options.from = walletAddr

                    let result = try contract.read(
                        "balanceOf",
                        parameters: [walletAddr] as [AnyObject],
                        extraData: Data(),
                        transactionOptions: options
                    )

                    guard let balance = result?["balance"] as? BigUInt else {
                        throw ERC20Error.invalidResponse
                    }

                    continuation.resume(returning: balance)
                } catch {
                    continuation.resume(throwing: ERC20Error.balanceFetchFailed(error))
                }
            }
        }
    }

    // MARK: - Transfer Operations

    /// Build ERC20 transfer transaction
    public func buildTransferTransaction(
        tokenAddress: String,
        from: String,
        to: String,
        amount: BigUInt,
        gasPrice: BigUInt? = nil,
        gasLimit: BigUInt? = nil
    ) async throws -> EthereumTransaction {

        guard let contractAddress = EthereumAddress(tokenAddress),
              let fromAddress = EthereumAddress(from),
              let toAddress = EthereumAddress(to) else {
            throw ERC20Error.invalidAddress
        }

        let contract = try createContract(address: contractAddress)

        var options = TransactionOptions.defaultOptions
        options.from = fromAddress
        options.gasPrice = .manual(gasPrice ?? BigUInt(0))
        options.gasLimit = .manual(gasLimit ?? BigUInt(100000))

        let transaction = try contract.write(
            "transfer",
            parameters: [toAddress, amount] as [AnyObject],
            extraData: Data(),
            transactionOptions: options
        )

        guard let tx = transaction else {
            throw ERC20Error.transactionBuildFailed
        }

        return tx
    }

    /// Build approve transaction
    public func buildApproveTransaction(
        tokenAddress: String,
        owner: String,
        spender: String,
        amount: BigUInt,
        gasPrice: BigUInt? = nil,
        gasLimit: BigUInt? = nil
    ) async throws -> EthereumTransaction {

        guard let contractAddress = EthereumAddress(tokenAddress),
              let ownerAddress = EthereumAddress(owner),
              let spenderAddress = EthereumAddress(spender) else {
            throw ERC20Error.invalidAddress
        }

        let contract = try createContract(address: contractAddress)

        var options = TransactionOptions.defaultOptions
        options.from = ownerAddress
        options.gasPrice = .manual(gasPrice ?? BigUInt(0))
        options.gasLimit = .manual(gasLimit ?? BigUInt(100000))

        let transaction = try contract.write(
            "approve",
            parameters: [spenderAddress, amount] as [AnyObject],
            extraData: Data(),
            transactionOptions: options
        )

        guard let tx = transaction else {
            throw ERC20Error.transactionBuildFailed
        }

        return tx
    }

    /// Get allowance
    public func getAllowance(
        tokenAddress: String,
        owner: String,
        spender: String
    ) async throws -> BigUInt {

        guard let contractAddress = EthereumAddress(tokenAddress),
              let ownerAddress = EthereumAddress(owner),
              let spenderAddress = EthereumAddress(spender) else {
            throw ERC20Error.invalidAddress
        }

        let contract = try createContract(address: contractAddress)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    var options = TransactionOptions.defaultOptions
                    options.from = ownerAddress

                    let result = try contract.read(
                        "allowance",
                        parameters: [ownerAddress, spenderAddress] as [AnyObject],
                        extraData: Data(),
                        transactionOptions: options
                    )

                    guard let allowance = result?["allowance"] as? BigUInt else {
                        throw ERC20Error.invalidResponse
                    }

                    continuation.resume(returning: allowance)
                } catch {
                    continuation.resume(throwing: ERC20Error.allowanceFetchFailed(error))
                }
            }
        }
    }

    // MARK: - Event Parsing

    /// Parse Transfer events from transaction receipt
    public func parseTransferEvents(receipt: TransactionReceipt) throws -> [ERC20Transfer] {
        var transfers: [ERC20Transfer] = []

        for log in receipt.logs {
            // Transfer event signature: Transfer(address,address,uint256)
            let transferTopic = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

            guard let firstTopic = log.topics.first?.toHexString() else {
                continue
            }

            if firstTopic == transferTopic && log.topics.count >= 3 {
                let from = EthereumAddress(log.topics[1].suffix(40))
                let to = EthereumAddress(log.topics[2].suffix(40))
                let value = BigUInt(log.data)

                let transfer = ERC20Transfer(
                    from: from?.address ?? "",
                    to: to?.address ?? "",
                    value: value,
                    tokenAddress: log.address.address
                )

                transfers.append(transfer)
            }
        }

        return transfers
    }

    // MARK: - Private Helpers

    private func createContract(address: EthereumAddress) throws -> web3.web3contract {
        guard let contract = web3.contract(erc20ABI, at: address) else {
            throw ERC20Error.contractCreationFailed
        }
        return contract
    }

    private func getTokenName(contract: web3.web3contract) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try contract.read(
                        "name",
                        parameters: [] as [AnyObject],
                        extraData: Data(),
                        transactionOptions: .defaultOptions
                    )

                    guard let name = result?["name"] as? String else {
                        throw ERC20Error.invalidResponse
                    }

                    continuation.resume(returning: name)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func getTokenSymbol(contract: web3.web3contract) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try contract.read(
                        "symbol",
                        parameters: [] as [AnyObject],
                        extraData: Data(),
                        transactionOptions: .defaultOptions
                    )

                    guard let symbol = result?["symbol"] as? String else {
                        throw ERC20Error.invalidResponse
                    }

                    continuation.resume(returning: symbol)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func getTokenDecimals(contract: web3.web3contract) async throws -> UInt8 {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try contract.read(
                        "decimals",
                        parameters: [] as [AnyObject],
                        extraData: Data(),
                        transactionOptions: .defaultOptions
                    )

                    guard let decimals = result?["decimals"] as? BigUInt else {
                        throw ERC20Error.invalidResponse
                    }

                    continuation.resume(returning: UInt8(decimals))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func getTotalSupply(contract: web3.web3contract) async throws -> BigUInt {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try contract.read(
                        "totalSupply",
                        parameters: [] as [AnyObject],
                        extraData: Data(),
                        transactionOptions: .defaultOptions
                    )

                    guard let supply = result?["totalSupply"] as? BigUInt else {
                        throw ERC20Error.invalidResponse
                    }

                    continuation.resume(returning: supply)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Models

public struct ERC20TokenInfo {
    public let address: String
    public let name: String
    public let symbol: String
    public let decimals: UInt8
    public let totalSupply: BigUInt
}

public struct ERC20Transfer {
    public let from: String
    public let to: String
    public let value: BigUInt
    public let tokenAddress: String
}

// MARK: - Errors

public enum ERC20Error: LocalizedError {
    case invalidTokenAddress
    case invalidAddress
    case contractCreationFailed
    case invalidResponse
    case balanceFetchFailed(Error)
    case allowanceFetchFailed(Error)
    case transactionBuildFailed

    public var errorDescription: String? {
        switch self {
        case .invalidTokenAddress:
            return "Invalid token contract address"
        case .invalidAddress:
            return "Invalid Ethereum address"
        case .contractCreationFailed:
            return "Failed to create contract instance"
        case .invalidResponse:
            return "Invalid response from contract"
        case .balanceFetchFailed(let error):
            return "Failed to fetch token balance: \(error.localizedDescription)"
        case .allowanceFetchFailed(let error):
            return "Failed to fetch allowance: \(error.localizedDescription)"
        case .transactionBuildFailed:
            return "Failed to build transaction"
        }
    }
}
