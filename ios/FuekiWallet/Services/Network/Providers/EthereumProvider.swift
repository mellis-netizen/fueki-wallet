//
//  EthereumProvider.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation

/// Ethereum RPC provider with comprehensive Web3 API support
public actor EthereumProvider {
    private let rpcClient: RPCClient
    private let wsClient: WebSocketClient?

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

    /// Get current network chain ID
    public func chainId() async throws -> String {
        try await rpcClient.request(method: "eth_chainId", params: [String]())
    }

    /// Get current network ID
    public func networkId() async throws -> String {
        try await rpcClient.request(method: "net_version", params: [String]())
    }

    /// Get client version
    public func clientVersion() async throws -> String {
        try await rpcClient.request(method: "web3_clientVersion", params: [String]())
    }

    /// Check if connected to network
    public func isListening() async throws -> Bool {
        try await rpcClient.request(method: "net_listening", params: [String]())
    }

    // MARK: - Account Information

    /// Get account balance in wei
    public func getBalance(address: String, blockTag: String = "latest") async throws -> String {
        try await rpcClient.request(method: "eth_getBalance", params: [address, blockTag])
    }

    /// Get transaction count (nonce) for address
    public func getTransactionCount(address: String, blockTag: String = "latest") async throws -> String {
        try await rpcClient.request(method: "eth_getTransactionCount", params: [address, blockTag])
    }

    /// Get code at address (for smart contracts)
    public func getCode(address: String, blockTag: String = "latest") async throws -> String {
        try await rpcClient.request(method: "eth_getCode", params: [address, blockTag])
    }

    // MARK: - Block Information

    /// Get current block number
    public func blockNumber() async throws -> String {
        try await rpcClient.request(method: "eth_blockNumber", params: [String]())
    }

    /// Get block by number
    public func getBlockByNumber(blockNumber: String, includeTransactions: Bool = false) async throws -> [String: AnyCodable] {
        try await rpcClient.request(
            method: "eth_getBlockByNumber",
            params: [blockNumber, includeTransactions]
        )
    }

    /// Get block by hash
    public func getBlockByHash(blockHash: String, includeTransactions: Bool = false) async throws -> [String: AnyCodable] {
        try await rpcClient.request(
            method: "eth_getBlockByHash",
            params: [blockHash, includeTransactions]
        )
    }

    /// Get block transaction count by number
    public func getBlockTransactionCountByNumber(blockNumber: String) async throws -> String {
        try await rpcClient.request(
            method: "eth_getBlockTransactionCountByNumber",
            params: [blockNumber]
        )
    }

    // MARK: - Transaction Information

    /// Get transaction by hash
    public func getTransactionByHash(txHash: String) async throws -> [String: AnyCodable]? {
        try await rpcClient.request(method: "eth_getTransactionByHash", params: [txHash])
    }

    /// Get transaction receipt
    public func getTransactionReceipt(txHash: String) async throws -> [String: AnyCodable]? {
        try await rpcClient.request(method: "eth_getTransactionReceipt", params: [txHash])
    }

    // MARK: - Transaction Sending

    /// Send raw signed transaction
    public func sendRawTransaction(signedTx: String) async throws -> String {
        try await rpcClient.request(method: "eth_sendRawTransaction", params: [signedTx])
    }

    /// Estimate gas for transaction
    public func estimateGas(transaction: [String: String]) async throws -> String {
        try await rpcClient.request(method: "eth_estimateGas", params: [transaction])
    }

    /// Get current gas price
    public func gasPrice() async throws -> String {
        try await rpcClient.request(method: "eth_gasPrice", params: [String]())
    }

    /// Get max priority fee per gas (EIP-1559)
    public func maxPriorityFeePerGas() async throws -> String {
        try await rpcClient.request(method: "eth_maxPriorityFeePerGas", params: [String]())
    }

    /// Get fee history for EIP-1559
    public func feeHistory(
        blockCount: Int,
        newestBlock: String = "latest",
        rewardPercentiles: [Double] = [25, 50, 75]
    ) async throws -> [String: AnyCodable] {
        let blockCountHex = String(format: "0x%x", blockCount)
        try await rpcClient.request(
            method: "eth_feeHistory",
            params: [blockCountHex, newestBlock, rewardPercentiles]
        )
    }

    // MARK: - Smart Contract Calls

    /// Call smart contract method (read-only)
    public func call(
        transaction: [String: String],
        blockTag: String = "latest"
    ) async throws -> String {
        try await rpcClient.request(method: "eth_call", params: [transaction, blockTag])
    }

    // MARK: - Event Logs

    /// Get logs matching filter
    public func getLogs(filter: [String: AnyCodable]) async throws -> [[String: AnyCodable]] {
        try await rpcClient.request(method: "eth_getLogs", params: [filter])
    }

    /// Create new filter for logs
    public func newFilter(filter: [String: AnyCodable]) async throws -> String {
        try await rpcClient.request(method: "eth_newFilter", params: [filter])
    }

    /// Get filter changes
    public func getFilterChanges(filterId: String) async throws -> [[String: AnyCodable]] {
        try await rpcClient.request(method: "eth_getFilterChanges", params: [filterId])
    }

    /// Uninstall filter
    public func uninstallFilter(filterId: String) async throws -> Bool {
        try await rpcClient.request(method: "eth_uninstallFilter", params: [filterId])
    }

    // MARK: - WebSocket Subscriptions

    /// Subscribe to new block headers
    public func subscribeNewHeads(
        handler: @escaping (Data) -> Void
    ) async throws -> String? {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        return try await wsClient.subscribe(
            method: "eth_subscribe",
            params: ["newHeads"],
            handler: handler
        )
    }

    /// Subscribe to pending transactions
    public func subscribeNewPendingTransactions(
        handler: @escaping (Data) -> Void
    ) async throws -> String? {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        return try await wsClient.subscribe(
            method: "eth_subscribe",
            params: ["newPendingTransactions"],
            handler: handler
        )
    }

    /// Subscribe to logs
    public func subscribeLogs(
        address: String? = nil,
        topics: [String]? = nil,
        handler: @escaping (Data) -> Void
    ) async throws -> String? {
        guard let wsClient = wsClient else {
            throw NetworkError.webSocketConnectionFailed
        }

        var params: [String] = ["logs"]

        // Add filter parameters
        var filter: [String: Any] = [:]
        if let address = address {
            filter["address"] = address
        }
        if let topics = topics {
            filter["topics"] = topics
        }

        if !filter.isEmpty {
            if let filterData = try? JSONSerialization.data(withJSONObject: filter),
               let filterString = String(data: filterData, encoding: .utf8) {
                params.append(filterString)
            }
        }

        return try await wsClient.subscribe(
            method: "eth_subscribe",
            params: params,
            handler: handler
        )
    }

    /// Unsubscribe from WebSocket subscription
    public func unsubscribe(_ subscriptionId: String) async throws {
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

    // MARK: - Batch Requests

    /// Execute multiple requests in batch
    public func batchRequest<T: Decodable>(
        methods: [(method: String, params: [String])]
    ) async throws -> [T] {
        try await rpcClient.batchRequest(requests: methods)
    }
}
