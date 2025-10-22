# Fueki Wallet - Integration Architecture

## Integration Overview

The Fueki wallet integrates with multiple external systems including blockchain networks, payment ramps, OAuth providers, and notification services. This document outlines the complete integration architecture, API designs, and communication protocols.

## Integration Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                Application Layer                         │
│            (ViewModels, Use Cases)                      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              Integration Facade Layer                    │
│         (Unified interfaces for services)               │
└─────────────────────────────────────────────────────────┘
                          ↓
        ┌─────────────────┴──────────────────┐
        ↓                  ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Blockchain   │  │  Payment     │  │   OAuth      │
│  Services    │  │   Ramps      │  │  Providers   │
└──────────────┘  └──────────────┘  └──────────────┘
        ↓                  ↓                  ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   RPC/WS     │  │   REST API   │  │   OAuth2     │
│  Clients     │  │   Clients    │  │   Clients    │
└──────────────┘  └──────────────┘  └──────────────┘
        ↓                  ↓                  ↓
┌──────────────────────────────────────────────────┐
│           External Services                       │
│  (Bitcoin/Ethereum Nodes, Stripe, Google, etc.)  │
└──────────────────────────────────────────────────┘
```

## Blockchain Integration Architecture

### Multi-Chain Support Strategy

```swift
protocol BlockchainService {
    var chainId: String { get }
    var name: String { get }

    // Wallet operations
    func createWallet() async throws -> WalletAddress
    func importWallet(privateKey: String) async throws -> WalletAddress
    func getBalance(address: String) async throws -> Balance

    // Transaction operations
    func estimateFee(transaction: UnsignedTransaction) async throws -> Fee
    func sendTransaction(_ transaction: SignedTransaction) async throws -> TransactionHash
    func getTransaction(hash: String) async throws -> Transaction
    func getTransactionReceipt(hash: String) async throws -> TransactionReceipt

    // Block operations
    func getCurrentBlock() async throws -> BlockNumber
    func subscribeToNewBlocks() -> AsyncStream<Block>

    // Token operations (EVM chains)
    func getTokenBalance(token: String, address: String) async throws -> Balance
    func getTokenInfo(token: String) async throws -> TokenInfo
}

// Blockchain service registry
class BlockchainServiceRegistry {
    private var services: [String: BlockchainService] = [:]

    static let shared = BlockchainServiceRegistry()

    func register(_ service: BlockchainService) {
        services[service.chainId] = service
    }

    func getService(for chainId: String) throws -> BlockchainService {
        guard let service = services[chainId] else {
            throw BlockchainError.unsupportedChain
        }
        return service
    }

    func getAllServices() -> [BlockchainService] {
        return Array(services.values)
    }
}
```

### Bitcoin Integration

```swift
class BitcoinService: BlockchainService {
    let chainId = "bitcoin"
    let name = "Bitcoin"

    private let rpcClient: BitcoinRPCClient
    private let networkConfig: BitcoinNetworkConfig

    init(
        rpcURL: URL,
        networkConfig: BitcoinNetworkConfig = .mainnet
    ) {
        self.rpcClient = BitcoinRPCClient(baseURL: rpcURL)
        self.networkConfig = networkConfig
    }

    func createWallet() async throws -> WalletAddress {
        // Generate BIP39 mnemonic
        let mnemonic = try Mnemonic.generate(strength: .bits256)

        // Derive BIP44 path: m/44'/0'/0'/0/0
        let seed = mnemonic.seed()
        let masterKey = try HDKey(seed: seed)
        let derivedKey = try masterKey.derive(path: "m/44'/0'/0'/0/0")

        // Generate address
        let publicKey = derivedKey.publicKey
        let address = try generateP2WPKHAddress(publicKey: publicKey)

        return WalletAddress(
            address: address,
            publicKey: publicKey.hexString,
            derivationPath: "m/44'/0'/0'/0/0"
        )
    }

    func getBalance(address: String) async throws -> Balance {
        let utxos = try await rpcClient.getUTXOs(address: address)
        let totalSatoshis = utxos.reduce(0) { $0 + $1.amount }

        return Balance(
            value: Decimal(totalSatoshis) / 100_000_000,
            currency: "BTC"
        )
    }

    func sendTransaction(_ transaction: SignedTransaction) async throws -> TransactionHash {
        let rawTx = try transaction.serialize()
        let txHash = try await rpcClient.sendRawTransaction(rawTx)
        return txHash
    }

    func estimateFee(transaction: UnsignedTransaction) async throws -> Fee {
        // Get fee estimates for different confirmation targets
        let feeRate = try await rpcClient.estimateSmartFee(blocks: 6)

        // Calculate transaction size
        let txSize = estimateTransactionSize(transaction)

        // Calculate fee: size * fee_rate
        let feeSatoshis = Int64(Double(txSize) * feeRate.feePerByte)

        return Fee(
            value: Decimal(feeSatoshis) / 100_000_000,
            currency: "BTC",
            gasLimit: nil,
            gasPrice: nil
        )
    }

    private func generateP2WPKHAddress(publicKey: Data) throws -> String {
        // Implement P2WPKH (native SegWit) address generation
        let pubKeyHash = RIPEMD160.hash(SHA256.hash(data: publicKey))
        let witnessProgram = Data([0x00, 0x14]) + pubKeyHash
        return try Bech32.encode(hrp: networkConfig.bech32Prefix, data: witnessProgram)
    }
}

// Bitcoin RPC Client
class BitcoinRPCClient {
    private let baseURL: URL
    private let session: URLSession

    func getUTXOs(address: String) async throws -> [UTXO] {
        let request = RPCRequest(
            method: "scantxoutset",
            params: ["start", ["addr(\(address))"]]
        )
        let response: RPCResponse<UTXOResult> = try await send(request)
        return response.result.unspents
    }

    func sendRawTransaction(_ rawTx: Data) async throws -> String {
        let request = RPCRequest(
            method: "sendrawtransaction",
            params: [rawTx.hexString]
        )
        let response: RPCResponse<String> = try await send(request)
        return response.result
    }

    func estimateSmartFee(blocks: Int) async throws -> FeeEstimate {
        let request = RPCRequest(
            method: "estimatesmartfee",
            params: [blocks]
        )
        let response: RPCResponse<FeeEstimate> = try await send(request)
        return response.result
    }
}
```

### Ethereum Integration

```swift
class EthereumService: BlockchainService {
    let chainId = "1" // Ethereum mainnet
    let name = "Ethereum"

    private let web3: Web3
    private let provider: HTTPProvider

    init(rpcURL: URL) {
        self.provider = HTTPProvider(rpcURL: rpcURL)
        self.web3 = Web3(provider: provider)
    }

    func createWallet() async throws -> WalletAddress {
        // Generate private key
        let privateKey = try EthereumPrivateKey()

        // Derive address
        let address = try privateKey.address

        return WalletAddress(
            address: address.hex(eip55: true),
            publicKey: privateKey.publicKey.hex,
            derivationPath: nil
        )
    }

    func getBalance(address: String) async throws -> Balance {
        let ethAddress = try EthereumAddress(hex: address, eip55: true)
        let balanceWei = try await web3.eth.getBalance(address: ethAddress)

        return Balance(
            value: Decimal(string: balanceWei.description)! / pow(10, 18),
            currency: "ETH"
        )
    }

    func sendTransaction(_ transaction: SignedTransaction) async throws -> TransactionHash {
        let txHash = try await web3.eth.sendRawTransaction(
            transaction: transaction.rawTransaction
        )
        return txHash.hex()
    }

    func estimateFee(transaction: UnsignedTransaction) async throws -> Fee {
        // Get current gas price
        let gasPrice = try await web3.eth.gasPrice()

        // Estimate gas limit
        let gasLimit = try await web3.eth.estimateGas(transaction: transaction.toWeb3Transaction())

        return Fee(
            value: Decimal(string: (gasPrice * gasLimit).description)! / pow(10, 18),
            currency: "ETH",
            gasLimit: Int64(gasLimit.quantity),
            gasPrice: Decimal(string: gasPrice.description)! / pow(10, 18)
        )
    }

    // ERC-20 token support
    func getTokenBalance(token: String, address: String) async throws -> Balance {
        let contract = try await web3.eth.Contract(
            type: ERC20.self,
            address: EthereumAddress(hex: token, eip55: true)
        )

        let balance = try await contract.balanceOf(
            address: EthereumAddress(hex: address, eip55: true)
        ).call()

        let decimals = try await contract.decimals().call()

        return Balance(
            value: Decimal(string: balance.description)! / pow(10, Int(decimals)),
            currency: "TOKEN"
        )
    }

    func getTokenInfo(token: String) async throws -> TokenInfo {
        let contract = try await web3.eth.Contract(
            type: ERC20.self,
            address: EthereumAddress(hex: token, eip55: true)
        )

        let name = try await contract.name().call()
        let symbol = try await contract.symbol().call()
        let decimals = try await contract.decimals().call()
        let totalSupply = try await contract.totalSupply().call()

        return TokenInfo(
            name: name,
            symbol: symbol,
            decimals: Int(decimals),
            totalSupply: Decimal(string: totalSupply.description)!,
            contractAddress: token
        )
    }
}

// ERC-20 Contract ABI
protocol ERC20 {
    func name() -> String
    func symbol() -> String
    func decimals() -> UInt8
    func totalSupply() -> BigUInt
    func balanceOf(address: EthereumAddress) -> BigUInt
    func transfer(to: EthereumAddress, value: BigUInt) -> Bool
}
```

### WebSocket Integration for Real-Time Updates

```swift
class BlockchainWebSocketService {
    private var socket: WebSocket?
    private let url: URL
    private var subscriptions: [String: AsyncStream<BlockchainEvent>.Continuation] = [:]

    init(url: URL) {
        self.url = url
    }

    func connect() async throws {
        let socket = WebSocket(url: url)
        self.socket = socket

        socket.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }

        try await socket.connect()
    }

    func subscribeToBlocks() -> AsyncStream<Block> {
        return AsyncStream { continuation in
            let subscriptionId = UUID().uuidString

            Task {
                try await sendSubscription(
                    method: "eth_subscribe",
                    params: ["newHeads"],
                    id: subscriptionId
                )
            }

            subscriptions[subscriptionId] = continuation
        }
    }

    func subscribeToTransactions(address: String) -> AsyncStream<Transaction> {
        return AsyncStream { continuation in
            let subscriptionId = UUID().uuidString

            Task {
                try await sendSubscription(
                    method: "eth_subscribe",
                    params: ["logs", ["address": address]],
                    id: subscriptionId
                )
            }

            subscriptions[subscriptionId] = continuation
        }
    }

    private func handleEvent(_ event: WebSocket.Event) {
        switch event {
        case .text(let text):
            if let data = text.data(using: .utf8),
               let notification = try? JSONDecoder().decode(WebSocketNotification.self, from: data) {
                handleNotification(notification)
            }
        default:
            break
        }
    }

    private func handleNotification(_ notification: WebSocketNotification) {
        guard let continuation = subscriptions[notification.subscription] else {
            return
        }

        // Parse and yield event
        // continuation.yield(event)
    }
}
```

## Payment Ramp Integration

### Payment Ramp Service Interface

```swift
protocol PaymentRampService {
    var name: String { get }
    var supportedCurrencies: [String] { get }
    var supportedCryptos: [String] { get }

    func initiateBuyTransaction(
        amount: Decimal,
        currency: String,
        crypto: String,
        walletAddress: String
    ) async throws -> PaymentSession

    func initiateSellTransaction(
        amount: Decimal,
        crypto: String,
        currency: String,
        bankAccount: BankAccount
    ) async throws -> PaymentSession

    func getPaymentStatus(sessionId: String) async throws -> PaymentStatus
    func getSupportedPaymentMethods() async throws -> [PaymentMethod]
}

struct PaymentSession {
    let id: String
    let url: URL?
    let status: PaymentStatus
    let expiresAt: Date
}

enum PaymentStatus {
    case initiated
    case pending
    case processing
    case completed
    case failed(reason: String)
    case cancelled
}
```

### Stripe Integration Example

```swift
class StripePaymentRampService: PaymentRampService {
    let name = "Stripe"
    let supportedCurrencies = ["USD", "EUR", "GBP"]
    let supportedCryptos = ["BTC", "ETH", "USDC"]

    private let apiKey: String
    private let client: HTTPClient

    init(apiKey: String) {
        self.apiKey = apiKey
        self.client = HTTPClient(baseURL: URL(string: "https://api.stripe.com")!)
    }

    func initiateBuyTransaction(
        amount: Decimal,
        currency: String,
        crypto: String,
        walletAddress: String
    ) async throws -> PaymentSession {
        let request = StripeCheckoutRequest(
            amount: Int(amount * 100), // Convert to cents
            currency: currency.lowercased(),
            cryptoCurrency: crypto,
            destinationAddress: walletAddress,
            successURL: "fueki://payment/success",
            cancelURL: "fueki://payment/cancel"
        )

        let response: StripeCheckoutResponse = try await client.post(
            "/v1/crypto/onramp_sessions",
            body: request,
            headers: [
                "Authorization": "Bearer \(apiKey)"
            ]
        )

        return PaymentSession(
            id: response.id,
            url: URL(string: response.url),
            status: .initiated,
            expiresAt: Date(timeIntervalSince1970: TimeInterval(response.expiresAt))
        )
    }

    func getPaymentStatus(sessionId: String) async throws -> PaymentStatus {
        let response: StripeSessionStatus = try await client.get(
            "/v1/crypto/onramp_sessions/\(sessionId)",
            headers: [
                "Authorization": "Bearer \(apiKey)"
            ]
        )

        return mapStripeStatus(response.status)
    }

    private func mapStripeStatus(_ status: String) -> PaymentStatus {
        switch status {
        case "requires_payment_method", "requires_confirmation":
            return .initiated
        case "processing":
            return .processing
        case "succeeded":
            return .completed
        case "canceled":
            return .cancelled
        default:
            return .failed(reason: "Unknown status: \(status)")
        }
    }
}
```

### Ramp Network Integration

```swift
class RampNetworkService: PaymentRampService {
    let name = "Ramp Network"
    let supportedCurrencies = ["USD", "EUR", "GBP", "PLN"]
    let supportedCryptos = ["BTC", "ETH", "USDC", "USDT"]

    private let apiKey: String
    private let hostAppName = "Fueki Wallet"

    func initiateBuyTransaction(
        amount: Decimal,
        currency: String,
        crypto: String,
        walletAddress: String
    ) async throws -> PaymentSession {
        // Ramp uses a widget-based approach
        let config = RampConfiguration(
            hostApiKey: apiKey,
            hostAppName: hostAppName,
            swapAsset: crypto,
            swapAmount: amount.description,
            fiatCurrency: currency,
            userAddress: walletAddress,
            webhookStatusUrl: "https://api.fueki.com/webhooks/ramp"
        )

        // Generate widget URL
        let widgetURL = try generateRampWidgetURL(config: config)

        return PaymentSession(
            id: UUID().uuidString,
            url: widgetURL,
            status: .initiated,
            expiresAt: Date().addingTimeInterval(3600) // 1 hour
        )
    }

    private func generateRampWidgetURL(config: RampConfiguration) throws -> URL {
        var components = URLComponents(string: "https://widget.ramp.network")!

        components.queryItems = [
            URLQueryItem(name: "hostApiKey", value: config.hostApiKey),
            URLQueryItem(name: "hostAppName", value: config.hostAppName),
            URLQueryItem(name: "swapAsset", value: config.swapAsset),
            URLQueryItem(name: "swapAmount", value: config.swapAmount),
            URLQueryItem(name: "fiatCurrency", value: config.fiatCurrency),
            URLQueryItem(name: "userAddress", value: config.userAddress),
            URLQueryItem(name: "webhookStatusUrl", value: config.webhookStatusUrl)
        ]

        guard let url = components.url else {
            throw PaymentRampError.invalidConfiguration
        }

        return url
    }
}
```

## OAuth Provider Integration

### OAuth Service Interface

```swift
protocol OAuthService {
    var provider: OAuthProvider { get }

    func authenticate() async throws -> OAuthCredential
    func refreshToken(_ credential: OAuthCredential) async throws -> OAuthCredential
    func getUserInfo(_ credential: OAuthCredential) async throws -> UserInfo
    func revokeToken(_ credential: OAuthCredential) async throws
}

enum OAuthProvider: String {
    case google = "Google"
    case apple = "Apple"
    case github = "GitHub"
}

struct OAuthCredential {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
    let tokenType: String
    let scope: String
}

struct UserInfo {
    let id: String
    let email: String
    let name: String?
    let picture: URL?
}
```

### Google OAuth Implementation

```swift
class GoogleOAuthService: OAuthService {
    let provider: OAuthProvider = .google

    private let clientId: String
    private let redirectURI: String

    init(clientId: String, redirectURI: String = "fueki://oauth/callback") {
        self.clientId = clientId
        self.redirectURI = redirectURI
    }

    func authenticate() async throws -> OAuthCredential {
        // Use ASWebAuthenticationSession for OAuth flow
        let authURL = try buildAuthorizationURL()

        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "fueki"
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let callbackURL = callbackURL,
                      let code = self.extractAuthorizationCode(from: callbackURL) else {
                    continuation.resume(throwing: OAuthError.invalidCallback)
                    return
                }

                Task {
                    do {
                        let credential = try await self.exchangeCodeForToken(code)
                        continuation.resume(returning: credential)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }

            session.presentationContextProvider = // Provide context
            session.start()
        }
    }

    private func buildAuthorizationURL() throws -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!

        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let url = components.url else {
            throw OAuthError.invalidConfiguration
        }

        return url
    }

    private func exchangeCodeForToken(_ code: String) async throws -> OAuthCredential {
        let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "client_id": clientId,
            "code": code,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        request.httpBody = body.percentEncoded()

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)

        return OAuthCredential(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn)),
            tokenType: response.tokenType,
            scope: response.scope
        )
    }

    func getUserInfo(_ credential: OAuthCredential) async throws -> UserInfo {
        let url = URL(string: "https://www.googleapis.com/oauth2/v2/userinfo")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credential.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GoogleUserInfo.self, from: data)

        return UserInfo(
            id: response.id,
            email: response.email,
            name: response.name,
            picture: response.picture
        )
    }
}
```

### Sign in with Apple Implementation

```swift
class AppleOAuthService: OAuthService {
    let provider: OAuthProvider = .apple

    func authenticate() async throws -> OAuthCredential {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        return try await withCheckedThrowingContinuation { continuation in
            let controller = ASAuthorizationController(authorizationRequests: [request])
            let delegate = AppleSignInDelegate(continuation: continuation)
            controller.delegate = delegate
            controller.presentationContextProvider = // Provide context
            controller.performRequests()
        }
    }

    func getUserInfo(_ credential: OAuthCredential) async throws -> UserInfo {
        // Apple provides user info only on first sign-in
        // Subsequent requests require using the stored data
        let provider = ASAuthorizationAppleIDProvider()

        return try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialState(forUserID: credential.accessToken) { state, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                // Retrieve cached user info
                // Apple doesn't provide an API to fetch user info after initial sign-in
                continuation.resume(returning: UserInfo(
                    id: credential.accessToken,
                    email: "", // Retrieve from Keychain
                    name: nil,
                    picture: nil
                ))
            }
        }
    }
}

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<OAuthCredential, Error>

    init(continuation: CheckedContinuation<OAuthCredential, Error>) {
        self.continuation = continuation
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: OAuthError.invalidCredential)
            return
        }

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            continuation.resume(throwing: OAuthError.invalidToken)
            return
        }

        let oauthCredential = OAuthCredential(
            accessToken: credential.user,
            refreshToken: tokenString,
            expiresAt: Date().addingTimeInterval(3600 * 24 * 30), // 30 days
            tokenType: "Bearer",
            scope: "openid email"
        )

        continuation.resume(returning: oauthCredential)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation.resume(throwing: error)
    }
}
```

## Push Notification Architecture

### Notification Service

```swift
protocol PushNotificationService {
    func requestAuthorization() async throws -> Bool
    func registerDeviceToken(_ token: Data) async throws
    func handleNotification(_ notification: UNNotification) -> NotificationAction
}

enum NotificationAction {
    case openTransaction(hash: String)
    case openWallet(id: UUID)
    case openApp
    case none
}

class DefaultPushNotificationService: NSObject, PushNotificationService, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .sound, .badge]
        return try await center.requestAuthorization(options: options)
    }

    func registerDeviceToken(_ token: Data) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()

        // Send token to backend
        try await sendTokenToBackend(tokenString)
    }

    private func sendTokenToBackend(_ token: String) async throws {
        let url = URL(string: "https://api.fueki.com/devices/register")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["device_token": token, "platform": "ios"]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NotificationError.registrationFailed
        }
    }

    func handleNotification(_ notification: UNNotification) -> NotificationAction {
        let userInfo = notification.request.content.userInfo

        if let txHash = userInfo["transaction_hash"] as? String {
            return .openTransaction(hash: txHash)
        }

        if let walletIdString = userInfo["wallet_id"] as? String,
           let walletId = UUID(uuidString: walletIdString) {
            return .openWallet(id: walletId)
        }

        return .openApp
    }

    // UNUserNotificationCenterDelegate methods
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = handleNotification(response.notification)
        // Navigate based on action
        completionHandler()
    }
}
```

### Transaction Notification Triggers

```swift
class TransactionNotificationManager {
    private let notificationService: PushNotificationService
    private let transactionRepository: TransactionRepository

    func setupTransactionMonitoring() {
        Task {
            // Monitor pending transactions
            let pendingTransactions = try await transactionRepository.fetchPendingTransactions()

            for transaction in pendingTransactions {
                await monitorTransaction(transaction)
            }
        }
    }

    private func monitorTransaction(_ transaction: Transaction) async {
        // Poll for transaction status updates
        while true {
            do {
                let status = try await checkTransactionStatus(transaction.hash)

                if status != transaction.status {
                    await sendNotification(for: transaction, status: status)

                    // Update local database
                    try await transactionRepository.updateStatus(status, for: transaction.hash)

                    if status == .confirmed || status == .failed {
                        break
                    }
                }

                // Wait before next poll
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            } catch {
                print("Failed to check transaction status: \(error)")
                break
            }
        }
    }

    private func sendNotification(for transaction: Transaction, status: TransactionStatus) async {
        let content = UNMutableNotificationContent()

        switch status {
        case .confirmed:
            content.title = "Transaction Confirmed"
            content.body = "Your transaction of \(transaction.amount) \(transaction.currency) has been confirmed"
        case .failed:
            content.title = "Transaction Failed"
            content.body = "Your transaction of \(transaction.amount) \(transaction.currency) has failed"
        default:
            return
        }

        content.sound = .default
        content.userInfo = ["transaction_hash": transaction.hash]

        let request = UNNotificationRequest(
            identifier: transaction.hash,
            content: content,
            trigger: nil
        )

        try? await UNUserNotificationCenter.current().add(request)
    }
}
```

## API Client Architecture

### Generic HTTP Client

```swift
protocol HTTPClient {
    func get<T: Decodable>(
        _ path: String,
        headers: [String: String]?
    ) async throws -> T

    func post<T: Decodable, U: Encodable>(
        _ path: String,
        body: U?,
        headers: [String: String]?
    ) async throws -> T

    func put<T: Decodable, U: Encodable>(
        _ path: String,
        body: U?,
        headers: [String: String]?
    ) async throws -> T

    func delete(
        _ path: String,
        headers: [String: String]?
    ) async throws
}

class DefaultHTTPClient: HTTPClient {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(
        baseURL: URL,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder()
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder

        // Configure decoder
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        // Configure encoder
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
    }

    func get<T: Decodable>(
        _ path: String,
        headers: [String: String]? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        return try await performRequest(request)
    }

    func post<T: Decodable, U: Encodable>(
        _ path: String,
        body: U? = nil as Empty?,
        headers: [String: String]? = nil
    ) async throws -> T {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers?.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        if let body = body {
            request.httpBody = try encoder.encode(body)
        }

        return try await performRequest(request)
    }

    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(statusCode: httpResponse.statusCode)
        }

        return try decoder.decode(T.self, from: data)
    }
}

struct Empty: Codable {}
```

## Integration Testing Strategy

```swift
class BlockchainIntegrationTests: XCTestCase {
    var bitcoinService: BitcoinService!
    var ethereumService: EthereumService!

    func testBitcoinWalletCreation() async throws {
        let wallet = try await bitcoinService.createWallet()
        XCTAssertFalse(wallet.address.isEmpty)
        XCTAssertTrue(wallet.address.hasPrefix("bc1")) // SegWit address
    }

    func testEthereumBalanceFetch() async throws {
        let address = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb5"
        let balance = try await ethereumService.getBalance(address: address)
        XCTAssertNotNil(balance)
    }

    func testPaymentRampInitiation() async throws {
        let rampService = StripePaymentRampService(apiKey: "test_key")
        let session = try await rampService.initiateBuyTransaction(
            amount: 100,
            currency: "USD",
            crypto: "BTC",
            walletAddress: "bc1qtest..."
        )
        XCTAssertNotNil(session.url)
    }
}
```

## Monitoring and Error Handling

```swift
protocol IntegrationMonitor {
    func trackAPICall(service: String, endpoint: String, duration: TimeInterval, success: Bool)
    func trackError(service: String, error: Error)
}

class DefaultIntegrationMonitor: IntegrationMonitor {
    func trackAPICall(service: String, endpoint: String, duration: TimeInterval, success: Bool) {
        let metrics = APICallMetrics(
            service: service,
            endpoint: endpoint,
            duration: duration,
            success: success,
            timestamp: Date()
        )

        // Send to analytics
        // Log for debugging
    }

    func trackError(service: String, error: Error) {
        let errorLog = IntegrationError(
            service: service,
            error: error.localizedDescription,
            timestamp: Date()
        )

        // Send to error tracking service
        // Log locally
    }
}
```

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-21 | CryptoArchitect Agent | Initial integration architecture |
