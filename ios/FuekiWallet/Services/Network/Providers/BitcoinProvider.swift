//
//  BitcoinProvider.swift
//  FuekiWallet
//
//  Created by Backend API Developer
//

import Foundation

/// Bitcoin RPC provider with comprehensive Bitcoin Core API support
public actor BitcoinProvider {
    private let rpcClient: RPCClient

    public init(
        endpoint: EndpointConfiguration,
        configuration: NetworkConfiguration = .default
    ) {
        self.rpcClient = RPCClient(
            endpointConfig: endpoint,
            configuration: configuration
        )
    }

    // MARK: - Network Information

    /// Get blockchain information
    public func getBlockchainInfo() async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getblockchaininfo", params: [String]())
    }

    /// Get network information
    public func getNetworkInfo() async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getnetworkinfo", params: [String]())
    }

    /// Get current block count
    public func getBlockCount() async throws -> Int {
        try await rpcClient.request(method: "getblockcount", params: [String]())
    }

    /// Get best block hash
    public func getBestBlockHash() async throws -> String {
        try await rpcClient.request(method: "getbestblockhash", params: [String]())
    }

    /// Get difficulty
    public func getDifficulty() async throws -> Double {
        try await rpcClient.request(method: "getdifficulty", params: [String]())
    }

    // MARK: - Block Information

    /// Get block by hash
    public func getBlock(blockHash: String, verbosity: Int = 1) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getblock", params: [blockHash, verbosity])
    }

    /// Get block header
    public func getBlockHeader(blockHash: String, verbose: Bool = true) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getblockheader", params: [blockHash, verbose])
    }

    /// Get block hash by height
    public func getBlockHash(height: Int) async throws -> String {
        try await rpcClient.request(method: "getblockhash", params: [height])
    }

    /// Get block stats
    public func getBlockStats(hashOrHeight: String) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getblockstats", params: [hashOrHeight])
    }

    // MARK: - Transaction Information

    /// Get raw transaction
    public func getRawTransaction(
        txid: String,
        verbose: Bool = false,
        blockHash: String? = nil
    ) async throws -> AnyCodable {
        var params: [AnyCodable] = [AnyCodable(txid), AnyCodable(verbose)]
        if let blockHash = blockHash {
            params.append(AnyCodable(blockHash))
        }
        return try await rpcClient.request(method: "getrawtransaction", params: params)
    }

    /// Decode raw transaction
    public func decodeRawTransaction(hexString: String) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "decoderawtransaction", params: [hexString])
    }

    /// Get transaction output (UTXO)
    public func getTxOut(
        txid: String,
        n: Int,
        includeMempool: Bool = true
    ) async throws -> [String: AnyCodable]? {
        try await rpcClient.request(method: "gettxout", params: [txid, n, includeMempool])
    }

    // MARK: - Transaction Sending

    /// Send raw transaction
    public func sendRawTransaction(hexString: String) async throws -> String {
        try await rpcClient.request(method: "sendrawtransaction", params: [hexString])
    }

    /// Test mempool acceptance
    public func testMempoolAccept(rawTxs: [String]) async throws -> [[String: AnyCodable]] {
        try await rpcClient.request(method: "testmempoolaccept", params: [rawTxs])
    }

    // MARK: - Mempool Information

    /// Get mempool info
    public func getMempoolInfo() async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getmempoolinfo", params: [String]())
    }

    /// Get raw mempool
    public func getRawMempool(verbose: Bool = false) async throws -> AnyCodable {
        try await rpcClient.request(method: "getrawmempool", params: [verbose])
    }

    /// Get mempool entry
    public func getMempoolEntry(txid: String) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getmempoolentry", params: [txid])
    }

    // MARK: - Address Information

    /// Validate address
    public func validateAddress(address: String) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "validateaddress", params: [address])
    }

    /// Get address info
    public func getAddressInfo(address: String) async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "getaddressinfo", params: [address])
    }

    // MARK: - Fee Estimation

    /// Estimate smart fee
    public func estimateSmartFee(
        confTarget: Int,
        estimateMode: String = "CONSERVATIVE"
    ) async throws -> [String: AnyCodable] {
        try await rpcClient.request(
            method: "estimatesmartfee",
            params: [confTarget, estimateMode]
        )
    }

    // MARK: - UTXO Set Information

    /// Get UTXO set info
    public func getTxOutSetInfo() async throws -> [String: AnyCodable] {
        try await rpcClient.request(method: "gettxoutsetinfo", params: [String]())
    }

    // MARK: - Blockchain Analysis

    /// Get chain tips
    public func getChainTips() async throws -> [[String: AnyCodable]] {
        try await rpcClient.request(method: "getchaintips", params: [String]())
    }

    /// Get mempool ancestors
    public func getMempoolAncestors(txid: String, verbose: Bool = false) async throws -> AnyCodable {
        try await rpcClient.request(method: "getmempoolancestors", params: [txid, verbose])
    }

    /// Get mempool descendants
    public func getMempoolDescendants(txid: String, verbose: Bool = false) async throws -> AnyCodable {
        try await rpcClient.request(method: "getmempooldescendants", params: [txid, verbose])
    }

    // MARK: - Batch Requests

    /// Execute multiple requests in batch
    public func batchRequest<T: Decodable>(
        methods: [(method: String, params: [AnyCodable])]
    ) async throws -> [T] {
        try await rpcClient.batchRequest(requests: methods)
    }

    // MARK: - REST API Methods (using rawRequest)

    /// Get block via REST API
    public func getBlockRest(blockHash: String) async throws -> Data {
        try await rpcClient.rawRequest(
            method: "GET",
            path: "/rest/block/\(blockHash).bin"
        )
    }

    /// Get transaction via REST API
    public func getTransactionRest(txid: String) async throws -> Data {
        try await rpcClient.rawRequest(
            method: "GET",
            path: "/rest/tx/\(txid).bin"
        )
    }

    /// Get UTXO set via REST API
    public func getUtxosRest(
        checkmempool: Bool = false,
        outpoints: [String] = []
    ) async throws -> Data {
        let path = "/rest/getutxos/checkmempool/\(outpoints.joined(separator: "-")).json"
        return try await rpcClient.rawRequest(method: "GET", path: path)
    }
}
