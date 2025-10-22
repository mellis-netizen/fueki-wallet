//
//  SolanaProvider.swift
//  FuekiWallet
//
//  Blockchain Integration Specialist - Solana Blockchain Integration
//

import Foundation
import Combine

class SolanaProvider: BlockchainProviderProtocol {
    let chainType: BlockchainType = .solana
    private(set) var network: NetworkEnvironment
    private(set) var isConnected: Bool = false

    private let rpcClient: RPCClient
    private let wsClient: RPCClient
    private let config: ChainConfig
    private var subscriptions = Set<AnyCancellable>()

    // WebSocket subscriptions
    private let addressSubject = PassthroughSubject<BlockchainTransaction, Error>()
    private let blockSubject = PassthroughSubject<UInt64, Error>()

    init(network: NetworkEnvironment = .mainnet) {
        self.network = network
        self.config = ChainConfigManager.shared.getSolanaConfig(network: network)

        // Replace API keys in endpoints
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
        // Test connection
        let version: [String: String] = try await rpcClient.call(method: "getVersion")
        guard version["solana-core"] != nil else {
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

        // Get SOL balance
        let balanceResult: UInt64 = try await rpcClient.call(
            method: "getBalance",
            params: [address]
        )

        // Get token accounts
        let tokenAccounts = try await getTokenAccounts(for: address)

        let tokens = tokenAccounts.map { account in
            BlockchainBalance.TokenBalance(
                contractAddress: account.mint,
                symbol: "SPL",
                name: "SPL Token",
                balance: Decimal(string: account.amount) ?? 0,
                decimals: Int(account.decimals),
                usdValue: nil
            )
        }

        return BlockchainBalance(
            address: address,
            nativeBalance: Decimal(balanceResult),
            tokens: tokens,
            timestamp: Date()
        )
    }

    func getTokenBalance(for address: String, tokenAddress: String) async throws -> Decimal {
        let tokenAccounts = try await getTokenAccounts(for: address)

        guard let account = tokenAccounts.first(where: { $0.mint == tokenAddress }) else {
            return 0
        }

        return Decimal(string: account.amount) ?? 0
    }

    func validateAddress(_ address: String) -> Bool {
        // Solana addresses are base58 encoded and 32-44 characters
        guard address.count >= 32 && address.count <= 44 else {
            return false
        }

        let base58Chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        return address.allSatisfy { base58Chars.contains($0) }
    }

    // MARK: - Transaction Management
    func getTransaction(hash: String) async throws -> BlockchainTransaction {
        let result: SolanaModels.Transaction = try await rpcClient.call(
            method: "getTransaction",
            params: [hash, ["encoding": "json", "maxSupportedTransactionVersion": 0]]
        )

        return try convertToBlockchainTransaction(result, hash: hash)
    }

    func getTransactionHistory(for address: String, limit: Int) async throws -> [BlockchainTransaction] {
        let signatures: [[String: Any]] = try await rpcClient.call(
            method: "getSignaturesForAddress",
            params: [address, ["limit": limit]]
        )

        var transactions: [BlockchainTransaction] = []

        for signatureInfo in signatures.prefix(limit) {
            guard let signature = signatureInfo["signature"] as? String else { continue }

            do {
                let tx = try await getTransaction(hash: signature)
                transactions.append(tx)
            } catch {
                // Continue on error to get as many transactions as possible
                continue
            }
        }

        return transactions
    }

    func estimateGas(for request: TransactionRequest) async throws -> GasEstimation {
        // Solana uses compute units, not gas
        // Base transaction cost is 5000 lamports per signature
        let baseFee = Decimal(5000)

        // Get recent prioritization fees
        let fees: [[String: UInt64]] = try await rpcClient.call(
            method: "getRecentPrioritizationFees"
        )

        let averageFee = fees.isEmpty ? 0 : fees.reduce(0) { $0 + ($1["prioritizationFee"] ?? 0) } / UInt64(fees.count)

        return GasEstimation(
            gasLimit: 200_000, // Compute units
            baseFee: baseFee,
            maxFeePerGas: Decimal(averageFee),
            maxPriorityFeePerGas: Decimal(averageFee),
            estimatedTotal: baseFee + Decimal(averageFee),
            confidence: 0.8
        )
    }

    // MARK: - Transaction Building
    func buildTransaction(_ request: TransactionRequest) async throws -> Data {
        // Get recent blockhash
        let blockhash: [String: String] = try await rpcClient.call(
            method: "getLatestBlockhash"
        )

        guard let recentBlockhash = blockhash["blockhash"] else {
            throw BlockchainError.invalidTransaction
        }

        // Build transaction message
        let message = SolanaModels.Transaction.Message(
            accountKeys: [request.from, request.to],
            recentBlockhash: recentBlockhash,
            instructions: [
                SolanaModels.Transaction.Message.Instruction(
                    programIdIndex: 0,
                    accounts: [0, 1],
                    data: request.data?.base64EncodedString() ?? ""
                )
            ]
        )

        let transaction = SolanaModels.Transaction(
            signatures: [],
            message: message
        )

        return try JSONEncoder().encode(transaction)
    }

    func sendSignedTransaction(_ signedTx: SignedTransaction) async throws -> String {
        let txBase64 = signedTx.rawTransaction.base64EncodedString()

        let signature: String = try await rpcClient.call(
            method: "sendTransaction",
            params: [txBase64, ["encoding": "base64"]]
        )

        return signature
    }

    func getTransactionStatus(hash: String) async throws -> TransactionStatus {
        let result: [String: Any] = try await rpcClient.call(
            method: "getSignatureStatuses",
            params: [[hash]]
        )

        guard let value = result["value"] as? [[String: Any]],
              let status = value.first?["confirmationStatus"] as? String else {
            return .pending
        }

        switch status {
        case "processed":
            return .pending
        case "confirmed":
            return .confirmed
        case "finalized":
            return .finalized
        default:
            return .pending
        }
    }

    // MARK: - Block Information
    func getCurrentBlockNumber() async throws -> UInt64 {
        let slot: UInt64 = try await rpcClient.call(method: "getSlot")
        return slot
    }

    func getBlock(number: UInt64) async throws -> BlockInfo {
        let block: [String: Any] = try await rpcClient.call(
            method: "getBlock",
            params: [number]
        )

        return BlockInfo(
            number: number,
            hash: block["blockhash"] as? String ?? "",
            timestamp: Date(timeIntervalSince1970: TimeInterval(block["blockTime"] as? Int ?? 0)),
            transactionCount: (block["transactions"] as? [[String: Any]])?.count ?? 0,
            gasUsed: nil,
            gasLimit: nil
        )
    }

    // MARK: - Real-time Updates
    func subscribeToAddress(_ address: String) -> AnyPublisher<BlockchainTransaction, Error> {
        // Subscribe via WebSocket
        Task {
            do {
                if wsClient.webSocketTask == nil {
                    try wsClient.connectWebSocket(endpoint: config.wsEndpoints[0])
                }

                let request = RPCRequest(
                    method: "accountSubscribe",
                    params: [address, ["encoding": "jsonParsed"]]
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
                            // Parse WebSocket data and emit transaction
                            // Implementation depends on Solana WebSocket response format
                            // This is a placeholder
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

                let request = RPCRequest(method: "slotSubscribe")
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
                               let result = json["result"] as? UInt64 {
                                self?.blockSubject.send(result)
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
        // Get token metadata from contract
        let accountInfo: SolanaModels.AccountInfo = try await rpcClient.call(
            method: "getAccountInfo",
            params: [contractAddress, ["encoding": "jsonParsed"]]
        )

        // Parse token metadata (simplified)
        return TokenInfo(
            contractAddress: contractAddress,
            symbol: "SPL",
            name: "SPL Token",
            decimals: 9,
            totalSupply: nil,
            logoURI: nil
        )
    }

    func getTokensForAddress(_ address: String) async throws -> [TokenInfo] {
        let accounts = try await getTokenAccounts(for: address)

        return try await withThrowingTaskGroup(of: TokenInfo?.self) { group in
            for account in accounts {
                group.addTask {
                    try? await self.getTokenInfo(contractAddress: account.mint)
                }
            }

            var tokens: [TokenInfo] = []
            for try await token in group {
                if let token = token {
                    tokens.append(token)
                }
            }
            return tokens
        }
    }

    // MARK: - Private Helpers
    private func getTokenAccounts(for address: String) async throws -> [SolanaModels.TokenAccount] {
        let result: [String: Any] = try await rpcClient.call(
            method: "getTokenAccountsByOwner",
            params: [
                address,
                ["programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"],
                ["encoding": "jsonParsed"]
            ]
        )

        guard let value = result["value"] as? [[String: Any]] else {
            return []
        }

        // Parse token accounts (simplified)
        return value.compactMap { accountData -> SolanaModels.TokenAccount? in
            guard let account = accountData["account"] as? [String: Any],
                  let data = account["data"] as? [String: Any],
                  let parsed = data["parsed"] as? [String: Any],
                  let info = parsed["info"] as? [String: Any],
                  let tokenAmount = info["tokenAmount"] as? [String: Any] else {
                return nil
            }

            return SolanaModels.TokenAccount(
                mint: info["mint"] as? String ?? "",
                owner: info["owner"] as? String ?? "",
                amount: tokenAmount["amount"] as? String ?? "0",
                decimals: tokenAmount["decimals"] as? UInt8 ?? 9,
                uiAmount: tokenAmount["uiAmount"] as? Double
            )
        }
    }

    private func convertToBlockchainTransaction(_ tx: SolanaModels.Transaction, hash: String) throws -> BlockchainTransaction {
        let accountKeys = tx.message.accountKeys

        return BlockchainTransaction(
            hash: hash,
            from: accountKeys.first ?? "",
            to: accountKeys.dropFirst().first ?? "",
            value: 0,
            fee: 0,
            timestamp: Date(),
            status: .finalized,
            blockNumber: nil,
            confirmations: nil,
            data: nil,
            tokenTransfers: nil
        )
    }

    private func handleWebSocketData(_ data: Data) {
        // Parse and handle WebSocket notifications
        // Implementation depends on Solana WebSocket response format
    }
}
