# Blockchain Integration - Quick Reference

## 📁 File Locations

All blockchain integration files are in:
```
/ios/FuekiWallet/Blockchain/
```

Total: **12 Swift files** | **~136 KB** | **Ready for Integration**

---

## 🗂️ File Breakdown

| File | Size | Purpose |
|------|------|---------|
| **BlockchainProviderProtocol.swift** | 6.5 KB | Common interface for all chains |
| **ChainConfig.swift** | 9.3 KB | Network configurations (mainnet/testnet/devnet) |
| **RPCClient.swift** | 11 KB | JSON-RPC client with retry logic |
| **BlockchainModels.swift** | 9.2 KB | Chain-specific data models |
| **SolanaProvider.swift** | 14 KB | Solana blockchain integration |
| **EthereumProvider.swift** | 18 KB | Ethereum blockchain integration |
| **BitcoinProvider.swift** | 16 KB | Bitcoin blockchain integration |
| **TransactionBuilder.swift** | 8.9 KB | Multi-chain transaction construction |
| **TransactionSigner.swift** | 11 KB | Transaction signing (Ed25519, secp256k1) |
| **NetworkManager.swift** | 8.4 KB | Network switching & health checks |
| **GasEstimator.swift** | 13 KB | Fee estimation for all chains |
| **TransactionMonitor.swift** | 12 KB | Transaction status tracking |

---

## 🚀 Quick Start Integration

### 1. Initialize Network Manager
```swift
import Foundation

// Network manager is a singleton
let networkManager = BlockchainNetworkManager.shared

// Set API keys
ChainConfigManager.shared.setAPIKey("your-alchemy-key", for: .alchemy)
ChainConfigManager.shared.setAPIKey("your-infura-key", for: .infura)

// Connect all chains
try await networkManager.connectAll()
```

### 2. Get a Provider
```swift
// Get Ethereum provider
guard let ethProvider = networkManager.getProvider(for: .ethereum) else {
    throw BlockchainError.notConnected
}

// Get balance
let balance = try await ethProvider.getBalance(for: "0x...")
print("ETH Balance: \(balance.nativeBalance)")
```

### 3. Send Transaction
```swift
// Build transaction
let builder = TransactionBuilder(provider: ethProvider)
let txData = try await builder.buildTransferTransaction(
    from: "0x...",
    to: "0x...",
    amount: Decimal(string: "0.1")!
)

// Sign transaction
let signer = TransactionSigner(chainType: .ethereum)
let signedTx = try signer.signTransaction(
    transactionData: txData,
    privateKey: privateKeyData
)

// Send
let txHash = try await ethProvider.sendSignedTransaction(signedTx)

// Monitor
let monitor = TransactionMonitor(provider: ethProvider)
monitor.monitorTransaction(hash: txHash)
```

### 4. Estimate Fees
```swift
let estimator = GasEstimator(provider: ethProvider)
let options = try await estimator.estimateWithSpeedOptions(
    from: "0x...",
    to: "0x...",
    amount: Decimal(1)
)

// Show user options
print("⚡ Fast: \(options.fast.estimatedTotal)")
print("🔷 Standard: \(options.standard.estimatedTotal)")
print("🐢 Slow: \(options.slow.estimatedTotal)")
```

---

## 🔗 Chain-Specific Features

### Solana
```swift
let solanaProvider = SolanaProvider(network: .mainnet)
try await solanaProvider.connect()

// Get token accounts
let balance = try await solanaProvider.getBalance(for: "...")
for token in balance.tokens {
    print("\(token.symbol): \(token.balance)")
}
```

### Ethereum
```swift
let ethProvider = EthereumProvider(network: .mainnet)
try await ethProvider.connect()

// ERC-20 token transfer
let builder = TransactionBuilder(provider: ethProvider)
let txData = try await builder.buildTokenTransferTransaction(
    from: "0x...",
    to: "0x...",
    tokenAddress: "0x...",  // USDC contract
    amount: Decimal(100),
    decimals: 6
)
```

### Bitcoin
```swift
let btcProvider = BitcoinProvider(network: .mainnet)
try await btcProvider.connect()

// UTXO-based transaction
let balance = try await btcProvider.getBalance(for: "bc1...")
print("BTC Balance: \(balance.nativeBalance) satoshis")
```

---

## 🌐 Network Switching

```swift
// Switch single chain
try await networkManager.switchNetwork(.testnet, for: .ethereum)

// Switch all chains
try await networkManager.switchNetworkForAllChains(.devnet)

// Check health
let health = await networkManager.checkAllHealth()
for (chain, isHealthy) in health {
    print("\(chain): \(isHealthy ? "✅" : "❌")")
}
```

---

## ⚙️ Configuration

### API Keys (UserDefaults)
```swift
ChainConfigManager.shared.setAPIKey("key", for: .alchemy)
ChainConfigManager.shared.setAPIKey("key", for: .infura)
```

### Custom Endpoints
```swift
let storage = NetworkConfigurationStorage()
storage.saveCustomEndpoint(
    "https://my-node.com",
    for: .ethereum,
    network: .mainnet
)
```

---

## 📊 Real-Time Updates

### Subscribe to Address
```swift
ethProvider.subscribeToAddress("0x...")
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { tx in
            print("New transaction: \(tx.hash)")
        }
    )
    .store(in: &cancellables)
```

### Subscribe to Blocks
```swift
ethProvider.subscribeToNewBlocks()
    .sink(
        receiveCompletion: { _ in },
        receiveValue: { blockNumber in
            print("New block: \(blockNumber)")
        }
    )
    .store(in: &cancellables)
```

---

## 🛡️ Error Handling

All blockchain methods throw `BlockchainError`:

```swift
do {
    let balance = try await provider.getBalance(for: address)
} catch BlockchainError.notConnected {
    // Reconnect
} catch BlockchainError.invalidAddress {
    // Show error to user
} catch BlockchainError.insufficientBalance {
    // Show balance error
} catch BlockchainError.transactionFailed(let reason) {
    print("Failed: \(reason)")
} catch {
    // Other errors
}
```

---

## 🧪 Testing Tips

### Use Testnets
```swift
// Ethereum Sepolia
let ethProvider = EthereumProvider(network: .testnet)

// Solana Devnet
let solProvider = SolanaProvider(network: .devnet)

// Bitcoin Testnet
let btcProvider = BitcoinProvider(network: .testnet)
```

### Get Test Tokens
- **Ethereum Sepolia**: https://sepoliafaucet.com/
- **Solana Devnet**: `solana airdrop 1`
- **Bitcoin Testnet**: https://testnet-faucet.mempool.co/

---

## 📦 Dependencies Needed

Add these to your project:

1. **CryptoKit** (built-in iOS 13+) ✅
2. **secp256k1.swift** (for ETH/BTC signatures) ⚠️
3. **Keccak256 library** (for Ethereum hashing) ⚠️

### Swift Package Manager
```swift
dependencies: [
    .package(url: "https://github.com/GigaBitcoin/secp256k1.swift.git", from: "0.12.0")
]
```

---

## 🎯 Integration Checklist

- [ ] Add secp256k1 dependency
- [ ] Add Keccak256 library
- [ ] Set up API keys in settings
- [ ] Connect to Security Agent for private keys
- [ ] Test on testnets
- [ ] Implement UI components
- [ ] Add transaction persistence
- [ ] Add error handling in UI
- [ ] Test network switching
- [ ] Test WebSocket subscriptions
- [ ] Add logging/analytics
- [ ] Test multi-signature flows

---

## 📞 Support & Documentation

- **Alchemy Docs**: https://docs.alchemy.com/
- **Infura Docs**: https://docs.infura.io/
- **Solana Docs**: https://docs.solana.com/
- **Ethereum Docs**: https://ethereum.org/developers
- **Bitcoin Docs**: https://developer.bitcoin.org/

---

**Ready to integrate!** 🚀
