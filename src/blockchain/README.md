# Blockchain Integration Architecture

## Overview

The Fueki Mobile Wallet blockchain integration provides a robust, multi-chain architecture with support for Bitcoin, Ethereum, and EVM-compatible chains (Polygon, BSC, Arbitrum, Optimism).

## Architecture Components

### Core Layer (`/core`)

#### BlockchainProvider Protocol
- Defines unified interface for all blockchain integrations
- Type-safe generic protocol for addresses, transactions, and receipts
- Common operations: balance queries, transaction creation, broadcasting, history

#### RPCClient
- **Retry Logic**: Automatic retry with exponential backoff
- **Failover**: Multiple RPC endpoints with automatic rotation
- **Rate Limiting**: Built-in request throttling
- **Error Handling**: Comprehensive error classification and recovery
- **Batch Support**: Efficient batch RPC calls

#### TransactionMonitor
- **Real-time Monitoring**: Track transaction confirmations
- **Status Updates**: Combine publishers for reactive updates
- **Configurable**: Adjustable check intervals and timeouts
- **Auto-cleanup**: Removes finalized transactions after retention period

#### NetworkSwitcher
- **Multi-network**: Support for mainnet, testnet, and custom networks
- **Hot-switching**: Change networks without restart
- **Custom Networks**: User-defined network configurations
- **Persistence**: Save/restore custom network settings

### Blockchain Implementations

#### Bitcoin (`/bitcoin`)

**BitcoinIntegration.swift** (Original)
- UTXO management
- Transaction construction (legacy, SegWit, nested SegWit)
- Multi-recipient transactions
- Fee estimation
- Address generation (P2PKH, P2WPKH, P2SH-P2WPKH)

**BitcoinProvider.swift** (Enhanced)
- BlockchainProvider protocol conformance
- Integrated transaction monitoring
- Enhanced error handling
- Multiple endpoint support
- Confirmation tracking

#### Ethereum (`/ethereum`)

**EthereumIntegration.swift** (Original)
- Multi-chain support (Ethereum, Polygon, BSC, Arbitrum, Optimism)
- EIP-1559 transaction support
- ERC-20 token operations
- Smart contract interaction
- Gas estimation

**EthereumProvider.swift** (Enhanced)
- BlockchainProvider protocol conformance
- Chain-specific configurations
- Multiple RPC endpoint failover
- Token balance queries
- Advanced gas price estimation

### Multi-chain Layer (`/multichain`)

#### MultiChainWallet
- **Unified Interface**: Single API for all blockchains
- **Balance Management**: Query balances across all chains
- **Transaction Handling**: Create and broadcast transactions
- **Status Tracking**: Monitor transactions across chains
- **Fee Estimation**: Chain-specific fee calculation

## Usage Examples

### Initialize Providers

```swift
import Foundation

// Bitcoin
let bitcoinProvider = BitcoinProvider(network: .mainnet)

// Ethereum
let ethereumProvider = EthereumProvider(chain: .ethereum, apiKey: "YOUR_API_KEY")

// Polygon
let polygonProvider = EthereumProvider(chain: .polygon, apiKey: "YOUR_API_KEY")
```

### Get Balance

```swift
// Using provider directly
let balance = try await bitcoinProvider.getBalance(for: "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh")

// Using MultiChainWallet
let wallet = MultiChainWallet.shared
let balances = try await wallet.getAllBalances(address: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
```

### Create and Send Transaction

```swift
// Bitcoin
let bitcoinTx = try await bitcoinProvider.createTransaction(
    from: senderAddress,
    to: recipientAddress,
    amount: 100_000 // satoshis
)

// Sign transaction (using wallet/keychain)
let signedTx = signTransaction(bitcoinTx, with: privateKey)

// Broadcast
let txHash = try await bitcoinProvider.broadcastTransaction(signedTx)

// Monitor confirmation
let receipt = try await bitcoinProvider.waitForConfirmation(
    txHash: txHash,
    requiredConfirmations: 6,
    timeout: 3600
)
```

### ERC-20 Token Transfer

```swift
let token = EthereumIntegration.ERC20Token(
    contractAddress: "0xdac17f958d2ee523a2206206994597c13d831ec7",
    name: "Tether USD",
    symbol: "USDT",
    decimals: 6
)

// Get token balance
let balance = try await ethereumProvider.getTokenBalance(token: token, address: userAddress)

// Create transfer transaction
let tx = try await ethereumProvider.createTokenTransfer(
    token: token,
    from: senderAddress,
    to: recipientAddress,
    amount: 1_000_000 // 1 USDT (6 decimals)
)

// Sign and broadcast
let signedTx = signTransaction(tx, with: privateKey)
let txHash = try await ethereumProvider.broadcastTransaction(signedTx)
```

### Network Switching

```swift
let switcher = NetworkSwitcher.shared

// Get available networks
let networks = switcher.getAllNetworks()

// Switch network
try switcher.switchNetwork(to: "polygon_mainnet")

// Add custom network
let customNetwork = try switcher.addCustomNetwork(
    name: "My Custom Network",
    chainId: "12345",
    rpcURL: "https://custom-rpc.example.com",
    explorerURL: "https://explorer.example.com"
)
```

### Transaction Monitoring

```swift
let monitor = TransactionMonitor()

// Start monitoring
monitor.monitor(txHash: txHash, blockchain: "ethereum_1", requiredConfirmations: 12)

// Subscribe to status updates
monitor.statusPublisher
    .sink { txHash, status in
        switch status {
        case .pending:
            print("Transaction pending...")
        case .confirming(let confirmations):
            print("Confirmations: \(confirmations)")
        case .confirmed(let confirmations):
            print("Transaction confirmed with \(confirmations) confirmations")
        case .failed(let reason):
            print("Transaction failed: \(reason)")
        case .dropped:
            print("Transaction dropped")
        }
    }
    .store(in: &cancellables)

// Wait for confirmation
let status = try await monitor.waitForConfirmation(txHash: txHash, timeout: 300)
```

### Multi-Chain Operations

```swift
let wallet = MultiChainWallet.shared

// Create transaction request
let request = MultiChainWallet.TransactionRequest(
    blockchain: "ethereum_1",
    from: senderAddress,
    to: recipientAddress,
    amount: 1_000_000_000_000_000_000, // 1 ETH in wei
    priority: .high
)

// Create transaction
let tx = try await wallet.createTransaction(request: request)

// Sign and send
let signedTx = signTransaction(tx, with: privateKey)
let txHash = try await wallet.sendTransaction(
    blockchain: "ethereum_1",
    signedTransaction: signedTx
)

// Monitor status
let status = try await wallet.waitForConfirmation(
    blockchain: "ethereum_1",
    txHash: txHash,
    timeout: 300
)
```

## Error Handling

All blockchain operations use the unified `BlockchainError` type:

```swift
do {
    let balance = try await provider.getBalance(for: address)
} catch BlockchainError.invalidAddress(let addr) {
    print("Invalid address: \(addr)")
} catch BlockchainError.networkError(let message) {
    print("Network error: \(message)")
} catch BlockchainError.rateLimitExceeded {
    print("API rate limit exceeded, retrying...")
} catch BlockchainError.timeout {
    print("Request timed out")
} catch {
    print("Unexpected error: \(error)")
}
```

## RPC Configuration

### Bitcoin Endpoints
- **Mainnet**: blockstream.info, blockchain.info, mempool.space
- **Testnet**: blockstream.info/testnet, mempool.space/testnet

### Ethereum Endpoints
- **Primary**: Alchemy (requires API key)
- **Fallback**: Cloudflare, Ankr (public endpoints)

### Configuration

```swift
let config = RPCClient.Configuration(
    endpoints: [
        URL(string: "https://primary-rpc.example.com")!,
        URL(string: "https://backup-rpc.example.com")!
    ],
    timeout: 30,
    maxRetries: 3,
    retryDelay: 2.0,
    rateLimitDelay: 2.0
)

let rpcClient = RPCClient(configuration: config)
```

## Supported Chains

### Bitcoin
- ✅ Bitcoin Mainnet
- ✅ Bitcoin Testnet

### Ethereum & EVM
- ✅ Ethereum Mainnet
- ✅ Ethereum Goerli (Testnet)
- ✅ Polygon (Matic)
- ✅ Polygon Mumbai (Testnet)
- ✅ Binance Smart Chain
- ✅ Arbitrum
- ✅ Optimism

## Features

### Transaction Features
- [x] Basic transfers
- [x] Multi-recipient (Bitcoin batch)
- [x] ERC-20 token transfers
- [x] EIP-1559 dynamic fees
- [x] Legacy transactions
- [x] Gas estimation
- [x] Fee estimation
- [x] UTXO selection (Bitcoin)

### Monitoring
- [x] Real-time confirmation tracking
- [x] Status notifications (Combine publishers)
- [x] Configurable confirmation requirements
- [x] Timeout handling
- [x] Transaction caching

### Network Management
- [x] Hot network switching
- [x] Custom network support
- [x] Network persistence
- [x] Multi-endpoint failover
- [x] Automatic retry logic

### Error Recovery
- [x] Automatic retries
- [x] Endpoint rotation
- [x] Rate limit handling
- [x] Timeout management
- [x] Graceful degradation

## Best Practices

### 1. Use RPC Client Properly
```swift
// ✅ Good - multiple endpoints for redundancy
let config = RPCClient.Configuration(
    endpoints: [primary, secondary, tertiary],
    maxRetries: 3
)

// ❌ Bad - single endpoint, no retry
let config = RPCClient.Configuration(
    endpoints: [singleEndpoint],
    maxRetries: 0
)
```

### 2. Handle Errors Gracefully
```swift
// ✅ Good - specific error handling
do {
    let tx = try await provider.createTransaction(...)
} catch BlockchainError.insufficientBalance {
    showInsufficientBalanceAlert()
} catch BlockchainError.networkError {
    retryWithBackoff()
}

// ❌ Bad - generic error handling
do {
    let tx = try await provider.createTransaction(...)
} catch {
    print(error)
}
```

### 3. Monitor Transactions
```swift
// ✅ Good - monitor with timeout
monitor.monitor(txHash: hash, blockchain: chain, requiredConfirmations: 12)
let status = try await monitor.waitForConfirmation(txHash: hash, timeout: 300)

// ❌ Bad - no monitoring
let hash = try await provider.broadcastTransaction(tx)
// Transaction sent, but no confirmation tracking
```

### 4. Estimate Fees Before Sending
```swift
// ✅ Good - show fee estimate to user
let fee = try await wallet.estimateFee(blockchain: chain, priority: .medium)
let approved = await showFeeConfirmation(fee)
if approved {
    // Send transaction
}

// ❌ Bad - no fee preview
try await wallet.sendTransaction(...)
```

## Testing

### Unit Tests Location
- `/tests/blockchain/BitcoinIntegrationTests.swift`
- `/tests/blockchain/EthereumIntegrationTests.swift`
- `/tests/blockchain/MultiChainWalletTests.swift`

### Test Coverage
- Address generation and validation
- Transaction creation and signing
- RPC client retry logic
- Network switching
- Transaction monitoring
- Error handling

## Performance Considerations

1. **RPC Caching**: Transaction cache reduces redundant API calls
2. **Batch Operations**: Use batch RPC calls when possible
3. **Connection Pooling**: URLSession reuses connections
4. **Rate Limiting**: Built-in throttling prevents API abuse
5. **Parallel Queries**: Async/await enables concurrent operations

## Security Notes

1. **Never log private keys**
2. **Validate all addresses** before creating transactions
3. **Use checksummed addresses** (Ethereum)
4. **Verify transaction data** before signing
5. **Store API keys securely** (Keychain, not UserDefaults)
6. **Use HTTPS** for all RPC endpoints

## Future Enhancements

- [ ] Additional chains (Solana, Cardano, etc.)
- [ ] Hardware wallet support
- [ ] Multi-sig transactions
- [ ] DeFi protocol integration
- [ ] NFT support
- [ ] Transaction history indexing
- [ ] Gas price prediction
- [ ] MEV protection

## Dependencies

- Foundation
- CryptoKit
- Combine

## License

Proprietary - Fueki Mobile Wallet

## Support

For issues or questions, contact the Fueki development team.
