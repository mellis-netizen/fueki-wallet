import Foundation
import Combine

/// Blockchain RPC API client
final class BlockchainAPIClient {

    private let networkClient: NetworkClient
    private let webSocketClient: WebSocketClient
    private let cache: NetworkCache

    // Configuration
    private let rpcEndpoint: String
    private let wsEndpoint: String

    init(
        rpcEndpoint: String,
        wsEndpoint: String,
        networkClient: NetworkClient = .shared,
        cache: NetworkCache = .shared
    ) {
        self.rpcEndpoint = rpcEndpoint
        self.wsEndpoint = wsEndpoint
        self.networkClient = networkClient
        self.webSocketClient = WebSocketClient()
        self.cache = cache
    }

    // MARK: - RPC Requests

    /// Get account balance
    func getBalance(address: String) async throws -> String {
        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_getBalance",
            params: [address, "latest"]
        )

        let response: RPCResponse<String> = try await networkClient.execute(request)
        return response.result
    }

    /// Get transaction count (nonce)
    func getTransactionCount(address: String) async throws -> String {
        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_getTransactionCount",
            params: [address, "latest"]
        )

        let response: RPCResponse<String> = try await networkClient.execute(request)
        return response.result
    }

    /// Send raw transaction
    func sendRawTransaction(signedTx: String) async throws -> String {
        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_sendRawTransaction",
            params: [signedTx]
        )

        let response: RPCResponse<String> = try await networkClient.execute(request)
        return response.result
    }

    /// Get transaction by hash
    func getTransaction(hash: String) async throws -> TransactionResponse {
        // Try cache first
        if let cached: TransactionResponse = try? cache.retrieve(
            for: "tx-\(hash)",
            as: TransactionResponse.self
        ) {
            return cached
        }

        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_getTransactionByHash",
            params: [hash]
        )

        let response: RPCResponse<TransactionResponse> = try await networkClient.execute(request)

        // Cache successful response
        try? cache.store(response.result, for: "tx-\(hash)", ttl: 60)

        return response.result
    }

    /// Get gas price
    func getGasPrice() async throws -> String {
        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_gasPrice",
            params: []
        )

        let response: RPCResponse<String> = try await networkClient.execute(request)
        return response.result
    }

    /// Estimate gas
    func estimateGas(transaction: TransactionParams) async throws -> String {
        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_estimateGas",
            params: [transaction]
        )

        let response: RPCResponse<String> = try await networkClient.execute(request)
        return response.result
    }

    /// Get block by number
    func getBlockByNumber(number: String, fullTransactions: Bool = false) async throws -> BlockResponse {
        let request = RPCRequest(
            endpoint: rpcEndpoint,
            method: "eth_getBlockByNumber",
            params: [number, fullTransactions]
        )

        let response: RPCResponse<BlockResponse> = try await networkClient.execute(request)
        return response.result
    }

    // MARK: - WebSocket Subscriptions

    /// Subscribe to new blocks
    func subscribeToNewBlocks() -> AnyPublisher<BlockResponse, Error> {
        let subject = PassthroughSubject<BlockResponse, Error>()

        Task {
            do {
                try await webSocketClient.connect(to: URL(string: wsEndpoint)!)

                let subscription = SubscriptionRequest(
                    method: "eth_subscribe",
                    params: ["newHeads"]
                )

                try await webSocketClient.send(subscription)

                // Listen for messages
                for await message in webSocketClient.messagePublisher.values {
                    if case .data(let data) = message {
                        if let block = try? JSONDecoder().decode(BlockResponse.self, from: data) {
                            subject.send(block)
                        }
                    }
                }
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }

    /// Subscribe to pending transactions
    func subscribeToPendingTransactions() -> AnyPublisher<String, Error> {
        let subject = PassthroughSubject<String, Error>()

        Task {
            do {
                try await webSocketClient.connect(to: URL(string: wsEndpoint)!)

                let subscription = SubscriptionRequest(
                    method: "eth_subscribe",
                    params: ["newPendingTransactions"]
                )

                try await webSocketClient.send(subscription)

                for await message in webSocketClient.messagePublisher.values {
                    if case .text(let text) = message {
                        subject.send(text)
                    }
                }
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }
}

// MARK: - Request/Response Models

struct RPCRequest<Params: Encodable>: EncodableRequest {
    typealias Response = RPCResponse<String>

    let baseURL: String
    let path = ""
    let method = HTTPMethod.post
    let params: Params

    var requestBody: RPCRequestBody<Params>? {
        RPCRequestBody(
            jsonrpc: "2.0",
            method: methodName,
            params: params,
            id: 1
        )
    }

    private let endpoint: String
    private let methodName: String

    init(endpoint: String, method: String, params: Params) {
        self.baseURL = endpoint
        self.endpoint = endpoint
        self.methodName = method
        self.params = params
    }
}

struct RPCRequestBody<Params: Encodable>: Encodable {
    let jsonrpc: String
    let method: String
    let params: Params
    let id: Int
}

struct RPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: Int
    let result: T
    let error: RPCError?
}

struct RPCError: Decodable {
    let code: Int
    let message: String
}

struct TransactionParams: Encodable {
    let from: String
    let to: String
    let gas: String?
    let gasPrice: String?
    let value: String
    let data: String?
}

struct TransactionResponse: Codable {
    let hash: String
    let nonce: String
    let blockHash: String?
    let blockNumber: String?
    let from: String
    let to: String?
    let value: String
    let gas: String
    let gasPrice: String
    let input: String
}

struct BlockResponse: Codable {
    let number: String
    let hash: String
    let timestamp: String
    let transactions: [String]
    let gasLimit: String
    let gasUsed: String
}

struct SubscriptionRequest: Encodable {
    let jsonrpc = "2.0"
    let id = 1
    let method: String
    let params: [String]
}
