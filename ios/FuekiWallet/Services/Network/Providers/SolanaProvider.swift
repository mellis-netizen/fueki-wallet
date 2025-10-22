//
//  SolanaProvider.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation

/// Solana RPC provider with comprehensive Solana JSON RPC API support
public actor SolanaProvider {
    private let rpcClient: RPCClient
    private let wsClient: WebSocketClient?

    public struct Commitment {
        public static let finalized = "finalized"
        public static let confirmed = "confirmed"
        public static let processed = "processed"
    }

    public init(
        httpEndpoint: EndpointConfiguration,
        wsEndpoint: URL? = nil,
        configuration: NetworkConfiguration = .default
    ) {
        self.rpcClient = RPCClient(
            endpointConfig: httpEndpoint,
            configuration: configuration
        )

        if let wsURL = wsEndpoint {
            self.wsClient = WebSocketClient(url: wsURL, configuration: configuration)
        } else {
            self.wsClient = nil
        }
    }

    // MARK: - Network Information

    /// Get cluster version
    public func getVersion() async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getVersion", params: [String]())
    }

    /// Get genesis hash
    public func getGenesisHash() async throws -> String {
        try await rpcClient.request(method: "getGenesisHash", params: [String]())
    }

    /// Get cluster nodes
    public func getClusterNodes() async throws -> [[String: AnyCodable]] {
        try await rpcClient.request(method: "getClusterNodes", params: [String]())
    }

    /// Get health status
    public func getHealth() async throws -> String {
        try await rpcClient.request(method: "getHealth", params: [String]())
    }

    // MARK: - Slot and Block Information

    /// Get current slot
    public func getSlot(commitment: String = Commitment.finalized) async throws -> Int {
        try await rpcClient.request(
            method: "getSlot",
            params: [["commitment": commitment]]
        )
    }

    /// Get block height
    public func getBlockHeight(commitment: String = Commitment.finalized) async throws -> Int {
        try await rpcClient.request(
            method: "getBlockHeight",
            params: [["commitment": commitment]]
        )
    }

    /// Get block
    public func getBlock(
        slot: Int,
        encoding: String = "json",
        commitment: String = Commitment.finalized
    ) async throws -> [String: AnyCodable] {
        try await rpcClient.request(
            method: "getBlock",
            params: [slot, ["encoding": encoding, "commitment": commitment]]
        )
    }

    /// Get blocks
    public func getBlocks(startSlot: Int, endSlot: Int? = nil) async throws -> [Int] {
        if let endSlot = endSlot {
            return try await rpcClient.request(method: "getBlocks", params: [startSlot, endSlot])
        } else {
            return try await rpcClient.request(method: "getBlocks", params: [startSlot])
        }
    }

    /// Get block time
    public func getBlockTime(slot: Int) async throws -> Int? {
        try await rpcClient.request(method: "getBlockTime", params: [slot])
    }

    // MARK: - Account Information

    /// Get account info
    public func getAccountInfo(
        pubkey: String,
        encoding: String = "base64",
        commitment: String = Commitment.finalized
    ) async throws -> [String: AnyCodable] {
        try await rpcClient.request(
            method: "getAccountInfo",
            params: [pubkey, ["encoding": encoding, "commitment": commitment]]
        )
    }

    /// Get balance
    public func getBalance(
        pubkey: String,
        commitment: String = Commitment.finalized
    ) async throws -> Int {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getBalance",
            params: [pubkey, ["commitment": commitment]]
        )

        guard let value = result["value"]?.value as? Int else {
            throw NetworkError.invalidData
        }

        return value
    }

    /// Get multiple accounts
    public func getMultipleAccounts(
        pubkeys: [String],
        encoding: String = "base64",
        commitment: String = Commitment.finalized
    ) async throws -> [[String: AnyCodable]] {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getMultipleAccounts",
            params: [pubkeys, ["encoding": encoding, "commitment": commitment]]
        )

        guard let value = result["value"]?.value as? [[String: AnyCodable]] else {
            throw NetworkError.invalidData
        }

        return value
    }

    /// Get program accounts
    public func getProgramAccounts(
        programId: String,
        encoding: String = "base64",
        filters: [[String: Any]]? = nil,
        commitment: String = Commitment.finalized
    ) async throws -> [[String: AnyCodable]] {
        var config: [String: Any] = [
            "encoding": encoding,
            "commitment": commitment
        ]

        if let filters = filters {
            config["filters"] = filters
        }

        return try await rpcClient.request(
            method: "getProgramAccounts",
            params: [programId, config]
        )
    }

    // MARK: - Transaction Information

    /// Get transaction
    public func getTransaction(
        signature: String,
        encoding: String = "json",
        commitment: String = Commitment.finalized
    ) async throws -> [String: AnyCodable]? {
        try await rpcClient.request(
            method: "getTransaction",
            params: [signature, ["encoding": encoding, "commitment": commitment]]
        )
    }

    /// Get signatures for address
    public func getSignaturesForAddress(
        address: String,
        limit: Int? = nil,
        before: String? = nil,
        until: String? = nil,
        commitment: String = Commitment.finalized
    ) async throws -> [[String: AnyCodable]] {
        var config: [String: Any] = ["commitment": commitment]

        if let limit = limit {
            config["limit"] = limit
        }
        if let before = before {
            config["before"] = before
        }
        if let until = until {
            config["until"] = until
        }

        return try await rpcClient.request(
            method: "getSignaturesForAddress",
            params: [address, config]
        )
    }

    /// Get signature statuses
    public func getSignatureStatuses(
        signatures: [String],
        searchTransactionHistory: Bool = false
    ) async throws -> [[String: AnyCodable]?] {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getSignatureStatuses",
            params: [signatures, ["searchTransactionHistory": searchTransactionHistory]]
        )

        guard let value = result["value"]?.value as? [[String: AnyCodable]?] else {
            throw NetworkError.invalidData
        }

        return value
    }

    // MARK: - Transaction Sending

    /// Send transaction
    public func sendTransaction(
        signedTransaction: String,
        encoding: String = "base64",
        skipPreflight: Bool = false,
        preflightCommitment: String = Commitment.finalized
    ) async throws -> String {
        try await rpcClient.request(
            method: "sendTransaction",
            params: [
                signedTransaction,
                [
                    "encoding": encoding,
                    "skipPreflight": skipPreflight,
                    "preflightCommitment": preflightCommitment
                ]
            ]
        )
    }

    /// Simulate transaction
    public func simulateTransaction(
        transaction: String,
        encoding: String = "base64",
        commitment: String = Commitment.finalized
    ) async throws -> [String: AnyCodable] {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "simulateTransaction",
            params: [transaction, ["encoding": encoding, "commitment": commitment]]
        )

        guard let value = result["value"]?.value as? [String: AnyCodable] else {
            throw NetworkError.invalidData
        }

        return value
    }

    // MARK: - Fee Information

    /// Get recent blockhash (deprecated, use getLatestBlockhash)
    public func getRecentBlockhash(commitment: String = Commitment.finalized) async throws -> [String: AnyCodable] {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getRecentBlockhash",
            params: [["commitment": commitment]]
        )

        guard let value = result["value"]?.value as? [String: AnyCodable] else {
            throw NetworkError.invalidData
        }

        return value
    }

    /// Get latest blockhash
    public func getLatestBlockhash(commitment: String = Commitment.finalized) async throws -> [String: AnyCodable] {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getLatestBlockhash",
            params: [["commitment": commitment]]
        )

        guard let value = result["value"]?.value as? [String: AnyCodable] else {
            throw NetworkError.invalidData
        }

        return value
    }

    /// Get fee for message
    public func getFeeForMessage(
        message: String,
        commitment: String = Commitment.finalized
    ) async throws -> Int? {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getFeeForMessage",
            params: [message, ["commitment": commitment]]
        )

        guard let value = result["value"]?.value as? Int? else {
            throw NetworkError.invalidData
        }

        return value
    }

    /// Get recent performance samples
    public func getRecentPerformanceSamples(limit: Int? = nil) async throws -> [[String: AnyCodable]] {
        if let limit = limit {
            return try await rpcClient.request(method: "getRecentPerformanceSamples", params: [limit])
        } else {
            return try await rpcClient.request(method: "getRecentPerformanceSamples", params: [String]())
        }
    }

    // MARK: - Token Information

    /// Get token account balance
    public func getTokenAccountBalance(
        pubkey: String,
        commitment: String = Commitment.finalized
    ) async throws -> [String: AnyCodable] {
        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getTokenAccountBalance",
            params: [pubkey, ["commitment": commitment]]
        )

        guard let value = result["value"]?.value as? [String: AnyCodable] else {
            throw NetworkError.invalidData
        }

        return value
    }

    /// Get token accounts by owner
    public func getTokenAccountsByOwner(
        ownerPubkey: String,
        mint: String? = nil,
        programId: String? = nil,
        encoding: String = "jsonParsed",
        commitment: String = Commitment.finalized
    ) async throws -> [[String: AnyCodable]] {
        var filter: [String: String] = [:]

        if let mint = mint {
            filter["mint"] = mint
        } else if let programId = programId {
            filter["programId"] = programId
        }

        let result: [String: AnyCodable] = try await rpcClient.request(
            method: "getTokenAccountsByOwner",
            params: [ownerPubkey, filter, ["encoding": encoding, "commitment": commitment]]
        )

        guard let value = result["value"]?.value as? [[String: AnyCodable]] else {
            throw NetworkError.invalidData
        }

        return value
    }

    // MARK: - WebSocket Subscriptions

    /// Subscribe to account changes
    public func accountSubscribe(
        pubkey: String,
        encoding: String = "base64",
        commitment: String = Commitment.finalized,
        handler: @escaping (Data) -> Void
    ) async throws -> String? {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        return try await wsClient.subscribe(
            method: "accountSubscribe",
            params: [pubkey, "{\"encoding\":\"\(encoding)\",\"commitment\":\"\(commitment)\"}"],
            handler: handler
        )
    }

    /// Subscribe to slot changes
    public func slotSubscribe(handler: @escaping (Data) -> Void) async throws -> String? {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        return try await wsClient.subscribe(
            method: "slotSubscribe",
            params: [],
            handler: handler
        )
    }

    /// Subscribe to signature status
    public func signatureSubscribe(
        signature: String,
        commitment: String = Commitment.finalized,
        handler: @escaping (Data) -> Void
    ) async throws -> String? {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        return try await wsClient.subscribe(
            method: "signatureSubscribe",
            params: [signature, "{\"commitment\":\"\(commitment)\"}"],
            handler: handler
        )
    }

    /// Unsubscribe
    public func unsubscribe(_ subscriptionId: String, method: String = "accountUnsubscribe") async throws {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        try await wsClient.unsubscribe(subscriptionId)
    }

    // MARK: - WebSocket Connection

    /// Connect to WebSocket
    public func connectWebSocket() async throws {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        try await wsClient.connect()
    }

    /// Disconnect WebSocket
    public func disconnectWebSocket() async {
        await wsClient?.disconnect()
    }
}
