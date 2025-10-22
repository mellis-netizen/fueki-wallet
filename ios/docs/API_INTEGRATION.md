# Fueki Wallet - API Integration Guide

## API Overview

Fueki Wallet integrates with multiple blockchain networks and services:

1. **Blockchain RPC APIs**: Ethereum, Bitcoin, Solana
2. **Price Feed APIs**: Real-time cryptocurrency prices
3. **Transaction Broadcast**: Submit transactions to networks
4. **NFT Metadata**: Token and NFT information
5. **Gas Price Oracles**: Estimate transaction fees

## Architecture

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│           (ViewModels)                  │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         Network Manager                 │
│    (Request Building & Routing)         │
└──────────────┬──────────────────────────┘
               │
┌──────────────▼──────────────────────────┐
│         API Providers                   │
│  ┌──────────┬──────────┬──────────┐    │
│  │Ethereum  │ Bitcoin  │ Solana   │    │
│  │   RPC    │   RPC    │   RPC    │    │
│  └──────────┴──────────┴──────────┘    │
└─────────────────────────────────────────┘
```

## Network Manager

### Core Implementation

```swift
import Foundation

class NetworkManager {
    static let shared = NetworkManager()

    private let session: URLSession
    private let baseURL: URL
    private let certificatePinner: CertificatePinner?

    init(
        baseURL: URL = Configuration.apiBaseURL,
        certificatePinner: CertificatePinner? = nil
    ) {
        self.baseURL = baseURL
        self.certificatePinner = certificatePinner

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13

        self.session = URLSession(
            configuration: configuration,
            delegate: certificatePinner,
            delegateQueue: nil
        )
    }

    // MARK: - Request
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        timeout: TimeInterval? = nil
    ) async throws -> T {
        let request = try buildRequest(endpoint)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw try decodeError(from: data, statusCode: httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    // MARK: - Build Request
    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint.path)

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = endpoint.queryItems

        guard let finalURL = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout

        // Headers
        var headers = endpoint.headers
        headers["Content-Type"] = "application/json"
        headers["User-Agent"] = "FuekiWallet-iOS/\(AppVersion.current)"

        if let apiKey = Configuration.apiKey {
            headers["X-API-Key"] = apiKey
        }

        request.allHTTPHeaderFields = headers

        // Body
        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }

    // MARK: - Error Handling
    private func decodeError(from data: Data, statusCode: Int) throws -> NetworkError {
        if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
            return .apiError(apiError)
        }

        switch statusCode {
        case 400:
            return .badRequest
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 429:
            return .rateLimitExceeded
        case 500...599:
            return .serverError(statusCode)
        default:
            return .unknown(statusCode)
        }
    }
}
```

### Endpoint Definition

```swift
enum Endpoint {
    case walletBalance(address: String, network: Network)
    case sendTransaction(Transaction)
    case transactionHistory(address: String, page: Int)
    case gasPrice(network: Network)
    case tokenPrice(symbol: String)
    case nftMetadata(contract: String, tokenId: String)

    var path: String {
        switch self {
        case .walletBalance(let address, _):
            return "/wallet/\(address)/balance"
        case .sendTransaction:
            return "/transaction/send"
        case .transactionHistory(let address, _):
            return "/wallet/\(address)/transactions"
        case .gasPrice:
            return "/gas/price"
        case .tokenPrice(let symbol):
            return "/price/\(symbol)"
        case .nftMetadata(let contract, let tokenId):
            return "/nft/\(contract)/\(tokenId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .sendTransaction:
            return .post
        default:
            return .get
        }
    }

    var queryItems: [URLQueryItem]? {
        switch self {
        case .walletBalance(_, let network):
            return [URLQueryItem(name: "network", value: network.rawValue)]
        case .transactionHistory(_, let page):
            return [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "20")
            ]
        case .gasPrice(let network):
            return [URLQueryItem(name: "network", value: network.rawValue)]
        default:
            return nil
        }
    }

    var body: [String: Any]? {
        switch self {
        case .sendTransaction(let transaction):
            return [
                "from": transaction.from,
                "to": transaction.to,
                "value": transaction.value.description,
                "data": transaction.data ?? "",
                "nonce": transaction.nonce,
                "gasLimit": transaction.gasLimit,
                "gasPrice": transaction.gasPrice.description
            ]
        default:
            return nil
        }
    }

    var headers: [String: String] {
        return [:]
    }

    var timeout: TimeInterval {
        switch self {
        case .sendTransaction:
            return 60
        default:
            return 30
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
```

## Blockchain Integration

### Ethereum RPC

```swift
class EthereumProvider {
    private let rpcURL: URL
    private let networkManager: NetworkManager

    init(rpcURL: URL = Configuration.ethereumRPCURL) {
        self.rpcURL = rpcURL
        self.networkManager = NetworkManager(baseURL: rpcURL)
    }

    // MARK: - Get Balance
    func getBalance(address: String) async throws -> Wei {
        let request = EthereumRPCRequest(
            method: "eth_getBalance",
            params: [address, "latest"]
        )

        let response: EthereumRPCResponse<String> = try await networkManager.request(
            .rpc(request)
        )

        guard let hexBalance = response.result else {
            throw EthereumError.invalidResponse
        }

        return try Wei(hex: hexBalance)
    }

    // MARK: - Get Transaction Count (Nonce)
    func getTransactionCount(address: String) async throws -> Int {
        let request = EthereumRPCRequest(
            method: "eth_getTransactionCount",
            params: [address, "latest"]
        )

        let response: EthereumRPCResponse<String> = try await networkManager.request(
            .rpc(request)
        )

        guard let hexCount = response.result else {
            throw EthereumError.invalidResponse
        }

        return Int(hexCount.dropFirst(2), radix: 16) ?? 0
    }

    // MARK: - Send Raw Transaction
    func sendRawTransaction(_ signedTransaction: String) async throws -> String {
        let request = EthereumRPCRequest(
            method: "eth_sendRawTransaction",
            params: [signedTransaction]
        )

        let response: EthereumRPCResponse<String> = try await networkManager.request(
            .rpc(request)
        )

        guard let txHash = response.result else {
            throw EthereumError.transactionFailed
        }

        return txHash
    }

    // MARK: - Get Transaction Receipt
    func getTransactionReceipt(hash: String) async throws -> TransactionReceipt? {
        let request = EthereumRPCRequest(
            method: "eth_getTransactionReceipt",
            params: [hash]
        )

        let response: EthereumRPCResponse<TransactionReceipt?> = try await networkManager.request(
            .rpc(request)
        )

        return response.result
    }

    // MARK: - Estimate Gas
    func estimateGas(transaction: EthereumTransaction) async throws -> Wei {
        let request = EthereumRPCRequest(
            method: "eth_estimateGas",
            params: [transaction.toRPCParams()]
        )

        let response: EthereumRPCResponse<String> = try await networkManager.request(
            .rpc(request)
        )

        guard let hexGas = response.result else {
            throw EthereumError.estimationFailed
        }

        return try Wei(hex: hexGas)
    }

    // MARK: - Get Gas Price
    func getGasPrice() async throws -> Wei {
        let request = EthereumRPCRequest(
            method: "eth_gasPrice",
            params: []
        )

        let response: EthereumRPCResponse<String> = try await networkManager.request(
            .rpc(request)
        )

        guard let hexPrice = response.result else {
            throw EthereumError.invalidResponse
        }

        return try Wei(hex: hexPrice)
    }

    // MARK: - Call Contract
    func call(to: String, data: String) async throws -> String {
        let request = EthereumRPCRequest(
            method: "eth_call",
            params: [
                ["to": to, "data": data],
                "latest"
            ]
        )

        let response: EthereumRPCResponse<String> = try await networkManager.request(
            .rpc(request)
        )

        guard let result = response.result else {
            throw EthereumError.contractCallFailed
        }

        return result
    }
}

struct EthereumRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id = UUID().uuidString
    let method: String
    let params: [Any]

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(jsonrpc, forKey: .jsonrpc)
        try container.encode(id, forKey: .id)
        try container.encode(method, forKey: .method)

        // Encode params as JSON
        let jsonData = try JSONSerialization.data(withJSONObject: params)
        let jsonString = String(data: jsonData, encoding: .utf8)
        try container.encode(jsonString, forKey: .params)
    }

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
}

struct EthereumRPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: String
    let result: T?
    let error: RPCError?
}

struct RPCError: Decodable {
    let code: Int
    let message: String
}
```

### Transaction Signing

```swift
import Web3Swift
import CryptoSwift

class TransactionSigner {
    private let keyManager: KeyManager

    init(keyManager: KeyManager) {
        self.keyManager = keyManager
    }

    // MARK: - Sign Ethereum Transaction
    func signEthereumTransaction(
        _ transaction: EthereumTransaction,
        privateKey: Data
    ) throws -> String {
        // Create transaction object
        let tx = EthereumSignedTransaction(
            nonce: transaction.nonce,
            gasPrice: transaction.gasPrice,
            gasLimit: transaction.gasLimit,
            to: EthereumAddress(hex: transaction.to),
            value: transaction.value,
            data: Data(hex: transaction.data ?? "0x")
        )

        // Sign transaction
        let signedTx = try tx.sign(
            using: EthereumPrivateKey(privateKey: privateKey),
            chainId: transaction.chainId
        )

        // Return RLP-encoded signed transaction
        return signedTx.rlp().toHexString()
    }

    // MARK: - Sign Message (EIP-191)
    func signMessage(_ message: String, privateKey: Data) throws -> String {
        let messageData = message.data(using: .utf8)!

        // Add Ethereum message prefix
        let prefix = "\u{19}Ethereum Signed Message:\n\(messageData.count)"
        let prefixedMessage = prefix.data(using: .utf8)! + messageData

        // Hash with Keccak256
        let hash = prefixedMessage.keccak256()

        // Sign
        let signature = try SECP256K1.sign(message: hash, privateKey: privateKey)

        return signature.toHexString()
    }

    // MARK: - Sign Typed Data (EIP-712)
    func signTypedData(
        _ typedData: TypedData,
        privateKey: Data
    ) throws -> String {
        let domainSeparator = try typedData.hashStruct(type: "EIP712Domain")
        let messageHash = try typedData.hashStruct(type: typedData.primaryType)

        let finalHash = ("\u{19}\u{01}" + domainSeparator + messageHash)
            .data(using: .utf8)!
            .keccak256()

        let signature = try SECP256K1.sign(message: finalHash, privateKey: privateKey)

        return signature.toHexString()
    }
}
```

## Price Feed Integration

```swift
class PriceFeedService {
    private let networkManager: NetworkManager

    // MARK: - Get Token Price
    func getTokenPrice(symbol: String) async throws -> TokenPrice {
        let endpoint = Endpoint.tokenPrice(symbol: symbol)
        let price: TokenPrice = try await networkManager.request(endpoint)
        return price
    }

    // MARK: - Get Multiple Prices
    func getMultiplePrices(symbols: [String]) async throws -> [String: TokenPrice] {
        try await withThrowingTaskGroup(of: (String, TokenPrice).self) { group in
            var prices: [String: TokenPrice] = [:]

            for symbol in symbols {
                group.addTask {
                    let price = try await self.getTokenPrice(symbol: symbol)
                    return (symbol, price)
                }
            }

            for try await (symbol, price) in group {
                prices[symbol] = price
            }

            return prices
        }
    }

    // MARK: - Real-time Price Updates (WebSocket)
    func subscribeToPriceUpdates(
        symbols: [String],
        onUpdate: @escaping (String, Decimal) -> Void
    ) async throws {
        let url = URL(string: "wss://api.fueki.io/prices")!
        let webSocket = URLSession.shared.webSocketTask(with: url)

        webSocket.resume()

        // Subscribe to symbols
        let subscription = [
            "type": "subscribe",
            "symbols": symbols
        ]

        let data = try JSONSerialization.data(withJSONObject: subscription)
        try await webSocket.send(.data(data))

        // Listen for updates
        while true {
            let message = try await webSocket.receive()

            switch message {
            case .data(let data):
                let update = try JSONDecoder().decode(PriceUpdate.self, from: data)
                onUpdate(update.symbol, update.price)

            case .string(let text):
                guard let data = text.data(using: .utf8) else { continue }
                let update = try JSONDecoder().decode(PriceUpdate.self, from: data)
                onUpdate(update.symbol, update.price)

            @unknown default:
                break
            }
        }
    }
}

struct TokenPrice: Codable {
    let symbol: String
    let price: Decimal
    let change24h: Decimal
    let marketCap: Decimal?
    let volume24h: Decimal?
    let lastUpdated: Date
}

struct PriceUpdate: Codable {
    let symbol: String
    let price: Decimal
    let timestamp: Date
}
```

## Rate Limiting

```swift
class RateLimiter {
    private var requestCounts: [String: Int] = [:]
    private var resetTimes: [String: Date] = [:]
    private let queue = DispatchQueue(label: "com.fueki.ratelimiter")

    private let maxRequests: Int
    private let timeWindow: TimeInterval

    init(maxRequests: Int = 100, timeWindow: TimeInterval = 60) {
        self.maxRequests = maxRequests
        self.timeWindow = timeWindow
    }

    func checkLimit(for key: String) async throws {
        try await queue.sync {
            let now = Date()

            // Reset if time window passed
            if let resetTime = resetTimes[key], now > resetTime {
                requestCounts[key] = 0
                resetTimes[key] = now.addingTimeInterval(timeWindow)
            }

            // Initialize if first request
            if requestCounts[key] == nil {
                requestCounts[key] = 0
                resetTimes[key] = now.addingTimeInterval(timeWindow)
            }

            // Check limit
            guard let count = requestCounts[key], count < maxRequests else {
                let resetTime = resetTimes[key]!
                let waitTime = resetTime.timeIntervalSince(now)
                throw NetworkError.rateLimitExceeded(retryAfter: waitTime)
            }

            // Increment count
            requestCounts[key]! += 1
        }
    }
}
```

## Caching

```swift
class APICache {
    private let cache = NSCache<NSString, CacheEntry>()
    private let defaultTTL: TimeInterval = 300 // 5 minutes

    func get<T: Codable>(_ key: String) -> T? {
        guard let entry = cache.object(forKey: key as NSString) else {
            return nil
        }

        // Check if expired
        if entry.expiresAt < Date() {
            cache.removeObject(forKey: key as NSString)
            return nil
        }

        return entry.value as? T
    }

    func set<T: Codable>(_ value: T, forKey key: String, ttl: TimeInterval? = nil) {
        let expiresAt = Date().addingTimeInterval(ttl ?? defaultTTL)
        let entry = CacheEntry(value: value, expiresAt: expiresAt)
        cache.setObject(entry, forKey: key as NSString)
    }

    func remove(_ key: String) {
        cache.removeObject(forKey: key as NSString)
    }

    func clear() {
        cache.removeAllObjects()
    }
}

class CacheEntry {
    let value: Any
    let expiresAt: Date

    init(value: Any, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }
}
```

## Error Handling

```swift
enum NetworkError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingFailed(Error)
    case badRequest
    case unauthorized
    case forbidden
    case notFound
    case rateLimitExceeded(retryAfter: TimeInterval)
    case serverError(Int)
    case apiError(APIError)
    case timeout
    case noConnection
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .badRequest:
            return "Bad request"
        case .unauthorized:
            return "Unauthorized - please login again"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
        case .serverError(let code):
            return "Server error (\(code))"
        case .apiError(let error):
            return error.message
        case .timeout:
            return "Request timeout"
        case .noConnection:
            return "No internet connection"
        case .unknown(let code):
            return "Unknown error (\(code))"
        }
    }
}

struct APIError: Codable, Error {
    let code: String
    let message: String
    let details: [String: String]?
}
```

## API Documentation

### Base URLs

```swift
enum Configuration {
    static let apiBaseURL = URL(string: "https://api.fueki.io/v1")!
    static let ethereumRPCURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2/\(alchemyKey)")!
    static let solanaRPCURL = URL(string: "https://api.mainnet-beta.solana.com")!
}
```

### Authentication

```swift
// API Key in headers
headers["X-API-Key"] = Configuration.apiKey

// JWT Token
headers["Authorization"] = "Bearer \(authToken)"
```

### Response Formats

All responses follow this structure:

```json
{
  "success": true,
  "data": { ... },
  "error": null,
  "timestamp": "2025-01-01T00:00:00Z"
}
```

### Endpoints

See OpenAPI specification in `/api-docs/openapi.yaml`

---

For security considerations, see [SECURITY.md](SECURITY.md).
