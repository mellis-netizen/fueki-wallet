//
//  EthereumProvider.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Ethereum Blockchain Integration (EIP-1559)
//

import Foundation
import Combine

class EthereumProvider: BlockchainProviderProtocol {
    let chainType: BlockchainType = .ethereum
    private(set) var network: NetworkEnvironment
    private(set) var isConnected: Bool = false

    private let rpcClient: RPCClient
    private let wsClient: RPCClient
    private let config: ChainConfig
    private var subscriptions = Set<AnyCancellable>()

    // WebSocket subscriptions
    private let addressSubject = PassthroughSubject<BlockchainTransaction, Error>()
    private let blockSubject = PassthroughSubject<UInt64, Error>()

    // ERC-20 Transfer event signature
    private let transferEventSignature = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef"

    init(network: NetworkEnvironment = .mainnet) {
        self.network = network
        self.config = ChainConfigManager.shared.getEthereumConfig(network: network)

        let apiEndpoints = config.rpcEndpoints.map {
            ChainConfigManager.shared.replaceAPIKey(in: $0, service: .alchemy)
        }
        let wsEndpoints = config.wsEndpoints.map {
            ChainConfigManager.shared.replaceAPIKey(in: $0, service: .alchemy)
        }

        self.rpcClient = RPCClient(endpoints: apiEndpoints)
        self.wsClient = RPCClient(endpoints: wsEndpoints)
    }

    // MARK: - Connection Management
    func connect() async throws {
        let chainId: String = try await rpcClient.call(method: "eth_chainId")
        guard !chainId.isEmpty else {
            throw BlockchainError.notConnected
        }
        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        wsClient.disconnectWebSocket()
    }

    func switchNetwork(_ network: NetworkEnvironment) async throws {
        await disconnect()
        self.network = network
        try await connect()
    }

    // MARK: - Account Management
    func getBalance(for address: String) async throws -> BlockchainBalance {
        guard validateAddress(address) else {
            throw BlockchainError.invalidAddress
        }

        // Get ETH balance
        let balanceHex: String = try await rpcClient.call(
            method: "eth_getBalance",
            params: [address, "latest"]
        )

        guard let balance = Decimal.fromHexString(balanceHex, decimals: 18) else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        // Get ERC-20 tokens
        let tokens = try await getERC20TokensForAddress(address)

        return BlockchainBalance(
            address: address,
            nativeBalance: balance,
            tokens: tokens,
            timestamp: Date()
        )
    }

    func getTokenBalance(for address: String, tokenAddress: String) async throws -> Decimal {
        // ERC-20 balanceOf function signature
        let functionSignature = "0x70a08231"
        let paddedAddress = String(address.dropFirst(2)).leftPadding(toLength: 64, withPad: "0")
        let data = functionSignature + paddedAddress

        let balanceHex: String = try await rpcClient.call(
            method: "eth_call",
            params: [
                ["to": tokenAddress, "data": data],
                "latest"
            ]
        )

        // Get token decimals
        let decimals = try await getTokenDecimals(contractAddress: tokenAddress)

        return Decimal.fromHexString(balanceHex, decimals: decimals) ?? 0
    }

    func validateAddress(_ address: String) -> Bool {
        // Ethereum addresses are 42 characters (0x + 40 hex chars)
        guard address.count == 42, address.hasPrefix("0x") else {
            return false
        }

        let hexChars = "0123456789abcdefABCDEF"
        return address.dropFirst(2).allSatisfy { hexChars.contains($0) }
    }

    // MARK: - Transaction Management
    func getTransaction(hash: String) async throws -> BlockchainTransaction {
        let tx: EthereumModels.Transaction = try await rpcClient.call(
            method: "eth_getTransactionByHash",
            params: [hash]
        )

        let receipt: EthereumModels.TransactionReceipt = try await rpcClient.call(
            method: "eth_getTransactionReceipt",
            params: [hash]
        )

        return try convertToBlockchainTransaction(tx, receipt: receipt)
    }

    func getTransactionHistory(for address: String, limit: Int) async throws -> [BlockchainTransaction] {
        // Get latest block
        let latestBlock = try await getCurrentBlockNumber()
        let fromBlock = latestBlock > UInt64(limit * 1000) ? latestBlock - UInt64(limit * 1000) : 0

        // Get logs for address
        let logs: [EthereumModels.Log] = try await rpcClient.call(
            method: "eth_getLogs",
            params: [[
                "fromBlock": "0x" + String(fromBlock, radix: 16),
                "toBlock": "latest",
                "address": address
            ]]
        )

        // Convert logs to transactions
        var transactions: [BlockchainTransaction] = []
        let uniqueHashes = Set(logs.map { $0.transactionHash })

        for hash in uniqueHashes.prefix(limit) {
            do {
                let tx = try await getTransaction(hash: hash)
                transactions.append(tx)
            } catch {
                continue
            }
        }

        return transactions
    }

    func estimateGas(for request: TransactionRequest) async throws -> GasEstimation {
        // Get gas estimate
        let gasLimitHex: String = try await rpcClient.call(
            method: "eth_estimateGas",
            params: [[
                "from": request.from,
                "to": request.to,
                "value": request.value.toHexString(decimals: 18),
                "data": request.data?.toHexString() ?? "0x"
            ]]
        )

        guard let gasLimit = UInt64(gasLimitHex.dropFirst(2), radix: 16) else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        // Get current gas prices (EIP-1559)
        let feeHistory: [String: Any] = try await rpcClient.call(
            method: "eth_feeHistory",
            params: [10, "latest", [25, 50, 75]]
        )

        guard let baseFeeArray = feeHistory["baseFeePerGas"] as? [String],
              let baseFeeHex = baseFeeArray.last else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }

        let baseFee = Decimal.fromHexString(baseFeeHex, decimals: 0) ?? 0

        // Calculate priority fees based on percentiles
        let priorityFee = baseFee * Decimal(0.1) // 10% of base fee

        let maxFeePerGas = baseFee * 2 + priorityFee
        let estimatedTotal = Decimal(gasLimit) * maxFeePerGas

        return GasEstimation(
            gasLimit: gasLimit,
            baseFee: baseFee,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: priorityFee,
            estimatedTotal: estimatedTotal,
            confidence: 0.85
        )
    }

    // MARK: - Transaction Building
    func buildTransaction(_ request: TransactionRequest) async throws -> Data {
        // Get nonce if not provided
        let nonce: UInt64
        if let requestNonce = request.nonce {
            nonce = requestNonce
        } else {
            let nonceHex: String = try await rpcClient.call(
                method: "eth_getTransactionCount",
                params: [request.from, "latest"]
            )
            nonce = UInt64(nonceHex.dropFirst(2), radix: 16) ?? 0
        }

        // Get gas estimation if not provided
        let gasEstimate = try await estimateGas(for: request)

        // Build EIP-1559 transaction
        let transaction = EthereumModels.Transaction(
            hash: "",
            nonce: "0x" + String(nonce, radix: 16),
            blockHash: nil,
            blockNumber: nil,
            transactionIndex: nil,
            from: request.from,
            to: request.to,
            value: request.value.toHexString(decimals: 18),
            gasPrice: nil,
            maxFeePerGas: (request.maxFeePerGas ?? gasEstimate.maxFeePerGas).toHexString(decimals: 0),
            maxPriorityFeePerGas: (request.maxPriorityFeePerGas ?? gasEstimate.maxPriorityFeePerGas).toHexString(decimals: 0),
            gas: "0x" + String(request.gasLimit ?? gasEstimate.gasLimit, radix: 16),
            input: request.data?.toHexString() ?? "0x",
            v: nil,
            r: nil,
            s: nil
        )

        return try JSONEncoder().encode(transaction)
    }

    func sendSignedTransaction(_ signedTx: SignedTransaction) async throws -> String {
        let txHex = signedTx.rawTransaction.toHexString()

        let hash: String = try await rpcClient.call(
            method: "eth_sendRawTransaction",
            params: [txHex]
        )

        return hash
    }

    func getTransactionStatus(hash: String) async throws -> TransactionStatus {
        let receipt: EthereumModels.TransactionReceipt? = try? await rpcClient.call(
            method: "eth_getTransactionReceipt",
            params: [hash]
        )

        guard let receipt = receipt else {
            return .pending
        }

        // Check status (1 = success, 0 = failed)
        if receipt.status == "0x1" {
            // Check confirmations
            let currentBlock = try await getCurrentBlockNumber()
            guard let txBlockNumber = UInt64(receipt.blockNumber.dropFirst(2), radix: 16) else {
                return .confirmed
            }

            let confirmations = currentBlock - txBlockNumber

            return confirmations >= 12 ? .finalized : .confirmed
        } else {
            return .failed
        }
    }

    // MARK: - Block Information
    func getCurrentBlockNumber() async throws -> UInt64 {
        let blockHex: String = try await rpcClient.call(method: "eth_blockNumber")
        guard let blockNumber = UInt64(blockHex.dropFirst(2), radix: 16) else {
            throw BlockchainError.networkError(URLError(.cannotParseResponse))
        }
        return blockNumber
    }

    func getBlock(number: UInt64) async throws -> BlockInfo {
        let blockHex = "0x" + String(number, radix: 16)
        let block: EthereumModels.Block = try await rpcClient.call(
            method: "eth_getBlockByNumber",
            params: [blockHex, false]
        )

        return BlockInfo(
            number: number,
            hash: block.hash,
            timestamp: Date(timeIntervalSince1970: TimeInterval(UInt64(block.timestamp.dropFirst(2), radix: 16) ?? 0)),
            transactionCount: block.transactions.count,
            gasUsed: UInt64(block.gasUsed.dropFirst(2), radix: 16),
            gasLimit: UInt64(block.gasLimit.dropFirst(2), radix: 16)
        )
    }

    // MARK: - Real-time Updates
    func subscribeToAddress(_ address: String) -> AnyPublisher<BlockchainTransaction, Error> {
        Task {
            do {
                if wsClient.webSocketTask == nil {
                    try wsClient.connectWebSocket(endpoint: config.wsEndpoints[0])
                }

                let request = RPCRequest(
                    method: "eth_subscribe",
                    params: ["logs", ["address": address]]
                )

                try wsClient.sendWebSocketMessage(request)

                wsClient.webSocketPublisher()
                    .sink(
                        receiveCompletion: { [weak self] completion in
                            if case .failure(let error) = completion {
                                self?.addressSubject.send(completion: .failure(error))
                            }
                        },
                        receiveValue: { [weak self] data in
                            self?.handleWebSocketData(data)
                        }
                    )
                    .store(in: &subscriptions)
            } catch {
                addressSubject.send(completion: .failure(error))
            }
        }

        return addressSubject.eraseToAnyPublisher()
    }

    func subscribeToNewBlocks() -> AnyPublisher<UInt64, Error> {
        Task {
            do {
                if wsClient.webSocketTask == nil {
                    try wsClient.connectWebSocket(endpoint: config.wsEndpoints[0])
                }

                let request = RPCRequest(method: "eth_subscribe", params: ["newHeads"])
                try wsClient.sendWebSocketMessage(request)

                wsClient.webSocketPublisher()
                    .sink(
                        receiveCompletion: { [weak self] completion in
                            if case .failure(let error) = completion {
                                self?.blockSubject.send(completion: .failure(error))
                            }
                        },
                        receiveValue: { [weak self] data in
                            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let params = json["params"] as? [String: Any],
                               let result = params["result"] as? [String: String],
                               let numberHex = result["number"],
                               let number = UInt64(numberHex.dropFirst(2), radix: 16) {
                                self?.blockSubject.send(number)
                            }
                        }
                    )
                    .store(in: &subscriptions)
            } catch {
                blockSubject.send(completion: .failure(error))
            }
        }

        return blockSubject.eraseToAnyPublisher()
    }

    // MARK: - Token Operations
    func getTokenInfo(contractAddress: String) async throws -> TokenInfo {
        let decimals = try await getTokenDecimals(contractAddress: contractAddress)
        let symbol = try await callTokenFunction(contractAddress: contractAddress, function: "symbol")
        let name = try await callTokenFunction(contractAddress: contractAddress, function: "name")

        return TokenInfo(
            contractAddress: contractAddress,
            symbol: symbol,
            name: name,
            decimals: decimals,
            totalSupply: nil,
            logoURI: nil
        )
    }

    func getTokensForAddress(_ address: String) async throws -> [TokenInfo] {
        // This would typically query a token list service
        // For now, return empty array
        return []
    }

    // MARK: - Private Helpers
    private func getTokenDecimals(contractAddress: String) async throws -> Int {
        let data = "0x313ce567" // decimals() function signature

        let result: String = try await rpcClient.call(
            method: "eth_call",
            params: [
                ["to": contractAddress, "data": data],
                "latest"
            ]
        )

        return Int(result.dropFirst(2), radix: 16) ?? 18
    }

    private func callTokenFunction(contractAddress: String, function: String) async throws -> String {
        let signatures = [
            "name": "0x06fdde03",
            "symbol": "0x95d89b41"
        ]

        guard let data = signatures[function] else {
            throw BlockchainError.invalidTransaction
        }

        let result: String = try await rpcClient.call(
            method: "eth_call",
            params: [
                ["to": contractAddress, "data": data],
                "latest"
            ]
        )

        // Decode string from ABI encoding
        return decodeString(from: result)
    }

    private func decodeString(from hex: String) -> String {
        // Simplified ABI string decoding
        let cleanHex = String(hex.dropFirst(2))
        guard cleanHex.count >= 128 else { return "" }

        let dataStart = cleanHex.index(cleanHex.startIndex, offsetBy: 128)
        let dataHex = String(cleanHex[dataStart...])

        guard let data = Data.fromHexString(dataHex) else { return "" }

        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? ""
    }

    private func getERC20TokensForAddress(_ address: String) async throws -> [BlockchainBalance.TokenBalance] {
        // This would typically query Alchemy or similar service for token balances
        // Placeholder implementation
        return []
    }

    private func convertToBlockchainTransaction(
        _ tx: EthereumModels.Transaction,
        receipt: EthereumModels.TransactionReceipt
    ) throws -> BlockchainTransaction {
        let value = Decimal.fromHexString(tx.value, decimals: 18) ?? 0
        let gasUsed = UInt64(receipt.gasUsed.dropFirst(2), radix: 16) ?? 0
        let effectiveGasPrice = Decimal.fromHexString(receipt.effectiveGasPrice ?? "0x0", decimals: 0) ?? 0
        let fee = Decimal(gasUsed) * effectiveGasPrice / Decimal(pow(10.0, 18.0))

        let status: TransactionStatus = receipt.status == "0x1" ? .confirmed : .failed

        return BlockchainTransaction(
            hash: tx.hash,
            from: tx.from,
            to: tx.to ?? "",
            value: value,
            fee: fee,
            timestamp: Date(),
            status: status,
            blockNumber: UInt64(receipt.blockNumber.dropFirst(2), radix: 16),
            confirmations: nil,
            data: Data.fromHexString(tx.input),
            tokenTransfers: nil
        )
    }

    private func handleWebSocketData(_ data: Data) {
        // Parse and handle WebSocket notifications
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let params = json["params"] as? [String: Any],
              let result = params["result"] as? [String: String],
              let txHash = result["transactionHash"] else {
            return
        }

        Task {
            do {
                let tx = try await getTransaction(hash: txHash)
                addressSubject.send(tx)
            } catch {
                addressSubject.send(completion: .failure(error))
            }
        }
    }
}

// MARK: - String Extension
private extension String {
    func leftPadding(toLength: Int, withPad: Character) -> String {
        let padLength = max(0, toLength - count)
        return String(repeating: withPad, count: padLength) + self
    }
}
