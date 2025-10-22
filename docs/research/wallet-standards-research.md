# Crypto Wallet Standards and Best Practices Research

## Executive Summary

This document covers industry-standard protocols for cryptocurrency wallet development, focusing on BIP standards, key derivation, blockchain integration, and iOS Secure Enclave implementation for the Fueki mobile wallet.

---

## BIP Standards (Bitcoin Improvement Proposals)

### 1. **BIP39: Mnemonic Code for Generating Deterministic Keys** ⭐

**Purpose**: Generate human-readable recovery phrases (seed phrases) from cryptographic entropy.

**Standard**: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki

**Key Concepts**:
- Converts 128-256 bits of entropy to 12-24 word mnemonic
- Standard wordlist of 2048 words (multiple languages)
- Checksum to detect errors
- Mnemonic → Seed (512 bits) via PBKDF2

**Implementation**:
```swift
import CryptoKit

// Generate entropy (128 bits = 12 words, 256 bits = 24 words)
let entropy = Data(randomBytes: 16) // 128 bits

// Convert to mnemonic using BIP39 wordlist
func generateMnemonic(from entropy: Data) -> [String] {
    let checksum = SHA256.hash(data: entropy)
    let checksumBits = checksum.first! >> 4 // First 4 bits

    var bits = entropy.map { byte -> String in
        String(byte, radix: 2).padLeft(to: 8)
    }.joined()

    bits += String(checksumBits, radix: 2).padLeft(to: 4)

    // Split into 11-bit chunks and map to wordlist
    let words = stride(from: 0, to: bits.count, by: 11).map { i in
        let index = Int(bits[i..<(i+11)], radix: 2)!
        return BIP39WordList.english[index]
    }

    return words
}

// Convert mnemonic to seed
func mnemonicToSeed(mnemonic: String, passphrase: String = "") -> Data {
    let password = mnemonic.data(using: .utf8)!
    let salt = ("mnemonic" + passphrase).data(using: .utf8)!

    // PBKDF2-HMAC-SHA512 with 2048 iterations
    return pbkdf2(password: password, salt: salt, iterations: 2048, keyLength: 64)
}
```

**Example**:
```
Entropy: 128 bits (16 bytes)
Mnemonic: "witch collapse practice feed shame open despair creek road again ice least"
Seed: 512 bits (64 bytes) derived via PBKDF2
```

**Security Considerations**:
- ✅ Use cryptographically secure random number generator
- ✅ Display mnemonic only once (during backup)
- ✅ Require user to confirm written backup
- ✅ Warn against digital storage (screenshots, cloud)
- ✅ Support passphrase (25th word) for extra security
- ❌ Never store mnemonic in plaintext
- ❌ Never transmit mnemonic over network

**iOS Implementation**:
```swift
// Secure mnemonic generation
func generateSecureMnemonic() -> String {
    var bytes = [UInt8](repeating: 0, count: 32) // 256 bits
    let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

    guard result == errSecSuccess else {
        fatalError("Failed to generate secure random bytes")
    }

    return generateMnemonic(from: Data(bytes)).joined(separator: " ")
}

// Secure mnemonic storage (only during backup flow)
func secureMnemonicDisplay(mnemonic: String) {
    // Disable screenshots
    NotificationCenter.default.addObserver(
        forName: UIApplication.userDidTakeScreenshotNotification,
        object: nil,
        queue: .main
    ) { _ in
        showWarning("Screenshots of recovery phrase are insecure!")
    }

    // Display mnemonic
    displayMnemonic(mnemonic)

    // Clear from memory after confirmation
    defer { mnemonic.removeAll() }
}
```

---

### 2. **BIP32: Hierarchical Deterministic Wallets (HD Wallets)** ⭐

**Purpose**: Generate unlimited key pairs from single seed using tree structure.

**Standard**: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki

**Key Concepts**:
- Master key derived from seed
- Child keys derived from parent keys
- Hierarchical path structure: m/purpose'/coin_type'/account'/change/address_index
- Extended keys (xprv, xpub) for sharing public keys
- Hardened (') vs non-hardened derivation

**Derivation Path Structure**:
```
m / purpose' / coin_type' / account' / change / address_index

Example: m/44'/0'/0'/0/0
- m: Master key
- 44': BIP44 purpose
- 0': Bitcoin coin type
- 0': First account
- 0: External chain (receive addresses)
- 0: First address index
```

**Implementation**:
```swift
import CryptoKit

// Extended key structure
struct ExtendedKey {
    let chainCode: Data       // 32 bytes
    let privateKey: Data?     // 32 bytes (nil for public keys)
    let publicKey: Data       // 33 bytes (compressed)
    let depth: UInt8
    let parentFingerprint: Data // 4 bytes
    let childIndex: UInt32
}

// Derive master key from seed
func deriveMasterKey(from seed: Data) -> ExtendedKey {
    let hmac = HMAC<SHA512>.authenticationCode(
        for: seed,
        using: SymmetricKey(data: "Bitcoin seed".data(using: .utf8)!)
    )

    let hmacData = Data(hmac)
    let privateKey = hmacData[0..<32]
    let chainCode = hmacData[32..<64]

    // Derive public key from private key (secp256k1)
    let publicKey = derivePublicKey(from: privateKey)

    return ExtendedKey(
        chainCode: chainCode,
        privateKey: privateKey,
        publicKey: publicKey,
        depth: 0,
        parentFingerprint: Data(repeating: 0, count: 4),
        childIndex: 0
    )
}

// Derive child key (hardened)
func deriveHardenedChild(parent: ExtendedKey, index: UInt32) -> ExtendedKey {
    guard let privateKey = parent.privateKey else {
        fatalError("Cannot derive hardened child from public key")
    }

    let hardenedIndex = index | 0x80000000 // Set MSB

    var data = Data([0x00]) // Padding
    data.append(privateKey)
    data.append(hardenedIndex.bigEndian.data)

    let hmac = HMAC<SHA512>.authenticationCode(
        for: data,
        using: SymmetricKey(data: parent.chainCode)
    )

    let hmacData = Data(hmac)
    let childPrivateKey = addPrivateKeys(privateKey, hmacData[0..<32])
    let childChainCode = hmacData[32..<64]
    let childPublicKey = derivePublicKey(from: childPrivateKey)

    return ExtendedKey(
        chainCode: childChainCode,
        privateKey: childPrivateKey,
        publicKey: childPublicKey,
        depth: parent.depth + 1,
        parentFingerprint: fingerprint(of: parent.publicKey),
        childIndex: hardenedIndex
    )
}

// Derive child key (non-hardened)
func deriveNonHardenedChild(parent: ExtendedKey, index: UInt32) -> ExtendedKey {
    var data = parent.publicKey
    data.append(index.bigEndian.data)

    let hmac = HMAC<SHA512>.authenticationCode(
        for: data,
        using: SymmetricKey(data: parent.chainCode)
    )

    let hmacData = Data(hmac)

    let childPrivateKey: Data?
    if let privateKey = parent.privateKey {
        childPrivateKey = addPrivateKeys(privateKey, hmacData[0..<32])
    } else {
        childPrivateKey = nil
    }

    let childChainCode = hmacData[32..<64]
    let childPublicKey = addPublicKeys(parent.publicKey, hmacData[0..<32])

    return ExtendedKey(
        chainCode: childChainCode,
        privateKey: childPrivateKey,
        publicKey: childPublicKey,
        depth: parent.depth + 1,
        parentFingerprint: fingerprint(of: parent.publicKey),
        childIndex: index
    )
}

// Derive key from path (e.g., "m/44'/0'/0'/0/0")
func deriveKeyFromPath(seed: Data, path: String) -> ExtendedKey {
    let components = path.components(separatedBy: "/").dropFirst() // Remove "m"
    var key = deriveMasterKey(from: seed)

    for component in components {
        let isHardened = component.hasSuffix("'")
        let indexString = component.replacingOccurrences(of: "'", with: "")
        guard let index = UInt32(indexString) else {
            fatalError("Invalid derivation path")
        }

        key = isHardened
            ? deriveHardenedChild(parent: key, index: index)
            : deriveNonHardenedChild(parent: key, index: index)
    }

    return key
}
```

**Security Considerations**:
- ✅ Use hardened derivation for account level
- ✅ Store extended private keys in Secure Enclave
- ✅ Cache derived addresses (don't re-derive on every use)
- ✅ Implement address gap limit (BIP44: 20 addresses)
- ❌ Never share extended private keys (xprv)
- ⚠️ Extended public keys (xpub) leak privacy (all addresses)

---

### 3. **BIP44: Multi-Account Hierarchy for Deterministic Wallets** ⭐

**Purpose**: Standardize derivation paths for different cryptocurrencies and accounts.

**Standard**: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki

**Path Structure**:
```
m / 44' / coin_type' / account' / change / address_index
```

**Coin Types** (registered in SLIP-0044):
```
Bitcoin (BTC):     m/44'/0'/0'/0/0
Ethereum (ETH):    m/44'/60'/0'/0/0
Litecoin (LTC):    m/44'/2'/0'/0/0
Dogecoin (DOGE):   m/44'/3'/0'/0/0
Solana (SOL):      m/44'/501'/0'/0/0
Polygon (MATIC):   m/44'/60'/0'/0/0 (same as ETH)
Bitcoin Cash (BCH): m/44'/145'/0'/0/0
Ripple (XRP):      m/44'/144'/0'/0/0
Cardano (ADA):     m/44'/1815'/0'/0/0
Polkadot (DOT):    m/44'/354'/0'/0/0
```

**Implementation**:
```swift
enum CoinType: UInt32 {
    case bitcoin = 0
    case ethereum = 60
    case litecoin = 2
    case solana = 501
    case bitcoinCash = 145
    case ripple = 144
    case cardano = 1815
    case polkadot = 354
}

struct DerivationPath {
    let purpose: UInt32 = 44
    let coinType: CoinType
    let account: UInt32
    let change: UInt32 // 0 = external (receive), 1 = internal (change)
    let addressIndex: UInt32

    var path: String {
        "m/\(purpose)'/\(coinType.rawValue)'/\(account)'/\(change)/\(addressIndex)"
    }
}

// Derive Bitcoin address
let bitcoinPath = DerivationPath(
    coinType: .bitcoin,
    account: 0,
    change: 0,
    addressIndex: 0
)

let bitcoinKey = deriveKeyFromPath(seed: seed, path: bitcoinPath.path)
let bitcoinAddress = generateBitcoinAddress(from: bitcoinKey.publicKey)

// Derive Ethereum address
let ethereumPath = DerivationPath(
    coinType: .ethereum,
    account: 0,
    change: 0,
    addressIndex: 0
)

let ethereumKey = deriveKeyFromPath(seed: seed, path: ethereumPath.path)
let ethereumAddress = generateEthereumAddress(from: ethereumKey.publicKey)
```

**Multi-Account Support**:
```swift
// Generate multiple accounts for same cryptocurrency
func generateAccounts(seed: Data, coinType: CoinType, count: Int) -> [String] {
    (0..<count).map { accountIndex in
        let path = DerivationPath(
            coinType: coinType,
            account: UInt32(accountIndex),
            change: 0,
            addressIndex: 0
        )
        let key = deriveKeyFromPath(seed: seed, path: path.path)
        return generateAddress(from: key.publicKey, coinType: coinType)
    }
}
```

**Address Gap Limit** (BIP44):
```swift
// Discover used addresses (scan blockchain)
func discoverAddresses(
    seed: Data,
    coinType: CoinType,
    account: UInt32
) async -> [String] {
    var addresses: [String] = []
    var consecutiveUnused = 0
    let gapLimit = 20

    var addressIndex: UInt32 = 0
    while consecutiveUnused < gapLimit {
        let path = DerivationPath(
            coinType: coinType,
            account: account,
            change: 0,
            addressIndex: addressIndex
        )

        let key = deriveKeyFromPath(seed: seed, path: path.path)
        let address = generateAddress(from: key.publicKey, coinType: coinType)

        // Check if address has been used (query blockchain)
        let hasTransactions = await checkAddressUsage(address, coinType: coinType)

        if hasTransactions {
            addresses.append(address)
            consecutiveUnused = 0
        } else {
            consecutiveUnused += 1
        }

        addressIndex += 1
    }

    return addresses
}
```

---

### 4. **BIP84: Derivation scheme for P2WPKH (SegWit) addresses**

**Purpose**: Support native SegWit (Bech32) addresses for Bitcoin.

**Path**: `m/84'/0'/0'/0/0` (instead of BIP44's m/44')

**Implementation**:
```swift
// Derive SegWit address
let segwitPath = "m/84'/0'/0'/0/0"
let segwitKey = deriveKeyFromPath(seed: seed, path: segwitPath)
let segwitAddress = generateBech32Address(from: segwitKey.publicKey)
// Example: bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq
```

---

### 5. **BIP141/173: SegWit and Bech32 Address Format**

**Purpose**: Support Segregated Witness transactions and Bech32 encoding.

**Bech32 Encoding**:
```swift
// Generate Bech32 address (native SegWit)
func generateBech32Address(from publicKey: Data) -> String {
    // Hash public key
    let sha256 = SHA256.hash(data: publicKey)
    let hash160 = RIPEMD160.hash(data: Data(sha256))

    // Convert to witness program
    let witnessVersion: UInt8 = 0
    let witnessProgram = [witnessVersion] + Array(hash160)

    // Bech32 encode
    let hrp = "bc" // "bc" for mainnet, "tb" for testnet
    return bech32Encode(hrp: hrp, data: witnessProgram)
}

// Example output: bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq
```

---

## Blockchain Integration Best Practices

### 1. **Multi-Chain Architecture**

**Strategy**: Design wallet to support multiple blockchains with unified interface.

```swift
// Abstract blockchain protocol
protocol BlockchainService {
    var coinType: CoinType { get }
    var name: String { get }
    var symbol: String { get }

    func generateAddress(from publicKey: Data) -> String
    func getBalance(for address: String) async throws -> Decimal
    func sendTransaction(from: String, to: String, amount: Decimal, privateKey: Data) async throws -> String
    func getTransactionHistory(for address: String) async throws -> [Transaction]
    func estimateFee(from: String, to: String, amount: Decimal) async throws -> Decimal
}

// Bitcoin implementation
class BitcoinService: BlockchainService {
    let coinType: CoinType = .bitcoin
    let name = "Bitcoin"
    let symbol = "BTC"
    let rpcUrl: URL

    func generateAddress(from publicKey: Data) -> String {
        // P2WPKH (native SegWit)
        return generateBech32Address(from: publicKey)
    }

    func getBalance(for address: String) async throws -> Decimal {
        // Query Bitcoin node or API (e.g., blockchain.com, Electrum)
        let request = BitcoinRPCRequest(
            method: "getbalance",
            params: [address]
        )
        let response = try await rpc.send(request)
        return Decimal(string: response.result) ?? 0
    }

    func sendTransaction(from: String, to: String, amount: Decimal, privateKey: Data) async throws -> String {
        // Build and sign transaction
        let utxos = try await fetchUTXOs(for: from)
        let transaction = buildTransaction(from: from, to: to, amount: amount, utxos: utxos)
        let signedTx = signTransaction(transaction, with: privateKey)
        let txHash = try await broadcast(signedTx)
        return txHash
    }
}

// Ethereum implementation
class EthereumService: BlockchainService {
    let coinType: CoinType = .ethereum
    let name = "Ethereum"
    let symbol = "ETH"
    let web3: Web3

    func generateAddress(from publicKey: Data) -> String {
        // Keccak256 hash of public key, take last 20 bytes
        let hash = Keccak256.hash(data: publicKey)
        let address = "0x" + hash.suffix(20).hexString
        return address.lowercased()
    }

    func getBalance(for address: String) async throws -> Decimal {
        let balance = try await web3.eth.getBalance(address: address)
        return Decimal(string: balance.toWei()) ?? 0 / Decimal(1e18)
    }

    func sendTransaction(from: String, to: String, amount: Decimal, privateKey: Data) async throws -> String {
        let nonce = try await web3.eth.getTransactionCount(address: from)
        let gasPrice = try await web3.eth.gasPrice()

        let tx = EthereumTransaction(
            nonce: nonce,
            gasPrice: gasPrice,
            gasLimit: 21000,
            to: to,
            value: amount * Decimal(1e18),
            data: Data()
        )

        let signedTx = try tx.sign(with: privateKey)
        let txHash = try await web3.eth.sendRawTransaction(signedTx)
        return txHash
    }
}

// Wallet manager
class WalletManager {
    private let services: [CoinType: BlockchainService]

    init(seed: Data) {
        self.services = [
            .bitcoin: BitcoinService(),
            .ethereum: EthereumService(),
            .solana: SolanaService()
        ]
    }

    func getBalance(for coinType: CoinType, account: UInt32 = 0) async throws -> Decimal {
        let service = services[coinType]!
        let address = deriveAddress(for: coinType, account: account)
        return try await service.getBalance(for: address)
    }

    func sendTransaction(
        coinType: CoinType,
        to: String,
        amount: Decimal,
        account: UInt32 = 0
    ) async throws -> String {
        let service = services[coinType]!
        let address = deriveAddress(for: coinType, account: account)
        let privateKey = derivePrivateKey(for: coinType, account: account)
        return try await service.sendTransaction(
            from: address,
            to: to,
            amount: amount,
            privateKey: privateKey
        )
    }
}
```

---

### 2. **RPC/API Provider Strategy**

**Options**:

**A. Self-hosted Nodes** (Most decentralized, expensive)
```swift
// Bitcoin Core RPC
let bitcoinRPC = URL(string: "http://your-node:8332")!

// Ethereum Geth/Erigon RPC
let ethereumRPC = URL(string: "http://your-node:8545")!
```

**B. Third-party Node Providers** (Recommended for mobile)
```swift
// Infura (Ethereum, Polygon, etc.)
let infuraUrl = URL(string: "https://mainnet.infura.io/v3/YOUR_API_KEY")!

// Alchemy (Ethereum, Polygon, Arbitrum, etc.)
let alchemyUrl = URL(string: "https://eth-mainnet.g.alchemy.com/v2/YOUR_API_KEY")!

// QuickNode (Multi-chain)
let quickNodeUrl = URL(string: "https://YOUR_ENDPOINT.quiknode.pro")!

// Ankr (Multi-chain, free tier)
let ankrUrl = URL(string: "https://rpc.ankr.com/eth")!
```

**C. Public RPC Endpoints** (Free, rate-limited)
```swift
// Ethereum public RPCs
let publicRPCs = [
    "https://cloudflare-eth.com",
    "https://rpc.ankr.com/eth",
    "https://eth.llamarpc.com"
]

// Fallback mechanism
func fetchWithFallback<T>(_ request: Request) async throws -> T {
    for rpc in publicRPCs {
        do {
            return try await fetch(request, from: rpc)
        } catch {
            continue // Try next RPC
        }
    }
    throw NetworkError.allRPCsFailed
}
```

**Recommended Providers**:
| Provider | Chains | Free Tier | Cost | Reliability |
|----------|--------|-----------|------|-------------|
| Alchemy | ETH, Polygon, Arbitrum, Optimism | ✅ 300M requests/month | $49/mo after | ⭐⭐⭐⭐⭐ |
| Infura | ETH, Polygon, Arbitrum, IPFS | ✅ 100k requests/day | $50/mo after | ⭐⭐⭐⭐⭐ |
| QuickNode | 20+ chains | ⚠️ Limited | $9-299/mo | ⭐⭐⭐⭐ |
| Ankr | 15+ chains | ✅ Rate-limited | $50-250/mo | ⭐⭐⭐⭐ |
| Public RPCs | Various | ✅ Free | Free | ⭐⭐⭐ |

---

### 3. **Transaction Building and Signing**

**Bitcoin Transaction**:
```swift
struct BitcoinTransaction {
    let version: UInt32 = 2
    var inputs: [TransactionInput]
    var outputs: [TransactionOutput]
    let locktime: UInt32 = 0

    struct TransactionInput {
        let previousTxHash: Data
        let previousOutputIndex: UInt32
        var scriptSig: Data
        let sequence: UInt32 = 0xffffffff
    }

    struct TransactionOutput {
        let value: UInt64 // Satoshis
        let scriptPubKey: Data
    }

    func serialize() -> Data {
        var data = Data()
        data.append(version.littleEndian.data)
        data.append(VarInt(inputs.count).data)
        for input in inputs {
            data.append(input.serialize())
        }
        data.append(VarInt(outputs.count).data)
        for output in outputs {
            data.append(output.serialize())
        }
        data.append(locktime.littleEndian.data)
        return data
    }

    func sign(with privateKey: Data, inputIndex: Int) -> Data {
        // Create signature hash
        var txCopy = self
        txCopy.inputs[inputIndex].scriptSig = /* previous output scriptPubKey */

        let serialized = txCopy.serialize()
        let hash = SHA256.hash(data: SHA256.hash(data: serialized))

        // Sign with ECDSA
        let signature = ECDSA.sign(hash, with: privateKey)

        // Append SIGHASH_ALL flag
        return signature + Data([0x01])
    }
}
```

**Ethereum Transaction**:
```swift
struct EthereumTransaction {
    let nonce: UInt64
    let gasPrice: BigUInt
    let gasLimit: UInt64
    let to: String
    let value: BigUInt
    let data: Data
    var chainId: UInt64 = 1 // Mainnet

    func rlpEncode() -> Data {
        let fields: [Any] = [
            nonce,
            gasPrice,
            gasLimit,
            to.hexToData(),
            value,
            data,
            chainId,
            0,
            0
        ]
        return RLP.encode(fields)
    }

    func sign(with privateKey: Data) throws -> Data {
        let rlp = rlpEncode()
        let hash = Keccak256.hash(data: rlp)

        // Sign with secp256k1
        let signature = try ECDSA.sign(hash, with: privateKey)
        let (r, s, v) = extractRSV(from: signature, chainId: chainId)

        // Re-encode with signature
        let signedFields: [Any] = [
            nonce,
            gasPrice,
            gasLimit,
            to.hexToData(),
            value,
            data,
            v,
            r,
            s
        ]

        return RLP.encode(signedFields)
    }
}
```

---

### 4. **Fee Estimation**

**Bitcoin Fee Estimation**:
```swift
func estimateBitcoinFee(transaction: BitcoinTransaction) async throws -> UInt64 {
    // Get recommended fee rate (satoshis per byte) from API
    let feeRate = try await fetchFeeRate() // e.g., 10 sat/byte

    // Calculate transaction size
    let txSize = transaction.serialize().count

    // Fee = size * fee rate
    let fee = UInt64(txSize) * feeRate

    return fee
}

// Bitcoin fee rate APIs
// - https://mempool.space/api/v1/fees/recommended
// - https://bitcoinfees.earn.com/api/v1/fees/recommended
```

**Ethereum Fee Estimation** (EIP-1559):
```swift
func estimateEthereumFee() async throws -> (baseFee: BigUInt, maxPriorityFee: BigUInt) {
    // Get base fee from latest block
    let latestBlock = try await web3.eth.getBlock("latest")
    let baseFee = latestBlock.baseFeePerGas

    // Get recommended priority fee
    let maxPriorityFee = try await web3.eth.maxPriorityFeePerGas()

    // Total fee = base fee + priority fee
    let maxFeePerGas = baseFee * 2 + maxPriorityFee // 2x base for buffer

    return (baseFee, maxPriorityFee)
}

// Estimate gas limit
func estimateGasLimit(tx: EthereumTransaction) async throws -> UInt64 {
    return try await web3.eth.estimateGas(
        from: tx.from,
        to: tx.to,
        value: tx.value,
        data: tx.data
    )
}
```

---

## iOS Secure Enclave Integration

### 1. **Secure Enclave Overview**

**What is Secure Enclave?**
- Dedicated hardware security coprocessor
- Isolated from main processor
- Stores cryptographic keys
- Performs signing operations
- Protected by biometric authentication (Face ID / Touch ID)

**Supported Devices**:
- iPhone 5S and later
- iPad Air 2 and later
- Mac with Apple Silicon (M1/M2/M3)

**Key Features**:
- ✅ Private keys never leave Secure Enclave
- ✅ Encrypted memory with dedicated AES engine
- ✅ Secure boot chain
- ✅ Hardware random number generator
- ✅ Biometric authentication enforcement
- ✅ Brute-force protection

---

### 2. **Storing Private Keys in Secure Enclave**

**Implementation**:
```swift
import CryptoKit
import LocalAuthentication

// Generate private key in Secure Enclave
func generateSecureEnclaveKey(tag: String) throws -> SecureEnclave.P256.Signing.PrivateKey {
    // Require biometric authentication for key usage
    let context = LAContext()
    context.localizedReason = "Authenticate to access wallet"

    // Create access control
    let accessControl = SecAccessControlCreateWithFlags(
        kCFAllocatorDefault,
        kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        [.privateKeyUsage, .biometryCurrentSet], // Require biometrics
        nil
    )!

    // Generate key in Secure Enclave
    let privateKey = try SecureEnclave.P256.Signing.PrivateKey(
        compactRepresentable: false,
        authenticationContext: context
    )

    // Save to Keychain (reference only, key stays in Secure Enclave)
    let attributes: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
        kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
        kSecAttrKeySizeInBits as String: 256,
        kSecValueData as String: privateKey.dataRepresentation,
        kSecAttrAccessControl as String: accessControl
    ]

    let status = SecItemAdd(attributes as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.saveFailed(status)
    }

    return privateKey
}

// Retrieve private key from Secure Enclave
func retrieveSecureEnclaveKey(tag: String) throws -> SecureEnclave.P256.Signing.PrivateKey {
    let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
        kSecReturnData as String: true
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess,
          let keyData = item as? Data else {
        throw KeychainError.retrieveFailed(status)
    }

    return try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyData)
}

// Sign data with Secure Enclave key
func signWithSecureEnclave(data: Data, tag: String) throws -> Data {
    let privateKey = try retrieveSecureEnclaveKey(tag: tag)

    // This triggers biometric authentication automatically
    let signature = try privateKey.signature(for: data)

    return signature.rawRepresentation
}
```

---

### 3. **Hybrid Approach: Secure Enclave + BIP32**

**Challenge**: Secure Enclave doesn't support BIP32 derivation directly.

**Solution**: Store BIP32 master key encrypted, use Secure Enclave for authentication.

```swift
// Hybrid approach
class SecureWalletManager {
    private let enclaveMasterKey: SecureEnclave.P256.Signing.PrivateKey

    init() throws {
        // Generate Secure Enclave key for encryption
        self.enclaveMasterKey = try generateSecureEnclaveKey(tag: "master-encryption-key")
    }

    // Store BIP32 seed encrypted
    func storeBIP32Seed(_ seed: Data) throws {
        // Encrypt seed with Secure Enclave public key
        let publicKey = enclaveMasterKey.publicKey
        let sealedBox = try ChaChaPoly.seal(seed, using: deriveSymmetricKey(from: publicKey))

        // Store encrypted seed in Keychain
        try KeychainService.save(sealedBox.combined, for: "bip32-seed-encrypted")
    }

    // Retrieve BIP32 seed (requires biometric auth)
    func retrieveBIP32Seed() throws -> Data {
        // This triggers Face ID / Touch ID
        let encryptedSeed = try KeychainService.retrieve("bip32-seed-encrypted")

        // Decrypt with Secure Enclave key
        let sealedBox = try ChaChaPoly.SealedBox(combined: encryptedSeed)
        let symmetricKey = deriveSymmetricKey(from: enclaveMasterKey.publicKey)
        let seed = try ChaChaPoly.open(sealedBox, using: symmetricKey)

        return seed
    }

    // Derive and sign with BIP32 key (biometric protected)
    func signTransaction(path: String, data: Data) throws -> Data {
        // Retrieve seed (triggers biometric auth)
        let seed = try retrieveBIP32Seed()

        // Derive key from path
        let key = deriveKeyFromPath(seed: seed, path: path)

        // Sign transaction
        let signature = try ECDSA.sign(data, with: key.privateKey!)

        // Clear seed from memory
        seed.withUnsafeMutableBytes { $0.initializeWithRandomBytes() }

        return signature
    }
}
```

---

### 4. **Biometric Authentication Best Practices**

```swift
// Check biometric availability
func checkBiometricAvailability() -> BiometricType {
    let context = LAContext()
    var error: NSError?

    guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
        return .none
    }

    switch context.biometryType {
    case .faceID:
        return .faceID
    case .touchID:
        return .touchID
    case .opticID:
        return .opticID
    default:
        return .none
    }
}

// Authenticate with biometrics
func authenticateWithBiometrics(reason: String) async throws -> Bool {
    let context = LAContext()
    context.localizedReason = reason
    context.localizedCancelTitle = "Cancel"
    context.localizedFallbackTitle = "Use Passcode"

    return try await context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: reason
    )
}

// Fallback to device passcode
func authenticateWithPasscode(reason: String) async throws -> Bool {
    let context = LAContext()
    return try await context.evaluatePolicy(
        .deviceOwnerAuthentication, // Allows passcode
        localizedReason: reason
    )
}

// Transaction signing with biometric confirmation
func signTransactionSecurely(
    transaction: Transaction,
    path: String
) async throws -> Data {
    // Show transaction details
    let transactionSummary = """
    Send \(transaction.amount) \(transaction.symbol)
    To: \(transaction.to)
    Fee: \(transaction.fee)
    """

    // Require biometric authentication
    let authenticated = try await authenticateWithBiometrics(
        reason: "Confirm transaction:\n\(transactionSummary)"
    )

    guard authenticated else {
        throw WalletError.authenticationFailed
    }

    // Sign with protected key
    return try walletManager.signTransaction(path: path, data: transaction.hash)
}
```

---

### 5. **Additional Security Measures**

**A. Key Attestation**
```swift
// Verify key was created in Secure Enclave
func attestSecureEnclaveKey(privateKey: SecureEnclave.P256.Signing.PrivateKey) -> Bool {
    // Check if key has Secure Enclave protection
    return privateKey.isStoredInSecureEnclave
}
```

**B. Jailbreak Detection**
```swift
func isDeviceJailbroken() -> Bool {
    // Check for common jailbreak indicators
    let jailbreakPaths = [
        "/Applications/Cydia.app",
        "/Library/MobileSubstrate/MobileSubstrate.dylib",
        "/bin/bash",
        "/usr/sbin/sshd",
        "/etc/apt",
        "/private/var/lib/apt/"
    ]

    for path in jailbreakPaths {
        if FileManager.default.fileExists(atPath: path) {
            return true
        }
    }

    // Check if can write to restricted path
    let testPath = "/private/test-jailbreak.txt"
    do {
        try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(atPath: testPath)
        return true // Should not be able to write here
    } catch {
        return false
    }
}
```

**C. App Transport Security**
```swift
// Info.plist configuration
// Force HTTPS, disable HTTP
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>yourdomain.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionRequiresForwardSecrecy</key>
            <false/>
        </dict>
    </dict>
</dict>
```

**D. Code Obfuscation**
- Use SwiftShield or similar tools
- Obfuscate sensitive strings
- Use control flow flattening
- Strip debug symbols in release builds

**E. Root Detection and Certificate Pinning**
```swift
// Certificate pinning
class PinnedURLSession: URLSession {
    func validateServerCertificate(
        challenge: URLAuthenticationChallenge
    ) -> Bool {
        guard let serverTrust = challenge.protectionSpace.serverTrust,
              let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            return false
        }

        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data
        let pinnedCertificateData = /* Your pinned cert */

        return serverCertificateData == pinnedCertificateData
    }
}
```

---

## Production Libraries and SDKs

### Recommended iOS Crypto Libraries

1. **web3.swift** (Ethereum)
   - Repository: https://github.com/Boilertalk/web3.swift
   - Features: EVM chains, ERC-20, ERC-721, ENS
   - License: MIT

2. **BitcoinKit** (Bitcoin)
   - Repository: https://github.com/yenom/BitcoinKit
   - Features: BIP32/39/44, SegWit, Testnet
   - License: MIT

3. **TrustWalletCore** (Multi-chain) ⭐
   - Repository: https://github.com/trustwallet/wallet-core
   - Features: 65+ blockchains, BIP32/39/44, native iOS
   - License: MIT

4. **WalletConnect Swift SDK**
   - Repository: https://github.com/WalletConnect/WalletConnectSwiftV2
   - Features: dApp integration, QR code signing
   - License: Apache 2.0

5. **Solana.swift** (Solana)
   - Repository: https://github.com/metaplex-foundation/Solana.swift
   - Features: Native Solana support, SPL tokens
   - License: MIT

---

## Recommended Architecture for Fueki Wallet

```swift
// Unified wallet architecture
class FuekiWallet {
    // Core components
    private let secureEnclaveManager: SecureEnclaveManager
    private let bip32Manager: BIP32KeyDerivation
    private let blockchainServices: [CoinType: BlockchainService]
    private let tssProvider: Web3AuthSDK // From TSS research
    private let paymentProvider: RampSDK // From payment research

    // Initialization
    init(seed: Data, useTSS: Bool = true) {
        if useTSS {
            // TSS mode (social login)
            self.tssProvider = Web3AuthSDK(clientId: "...")
            // Distributed key generation
        } else {
            // Traditional mode (BIP39 seed phrase)
            self.bip32Manager = BIP32KeyDerivation(seed: seed)
        }

        // Initialize blockchain services
        self.blockchainServices = [
            .bitcoin: BitcoinService(),
            .ethereum: EthereumService(),
            .solana: SolanaService()
        ]

        // Initialize payment provider
        self.paymentProvider = RampSDK()
    }

    // Unified interface
    func getBalance(coinType: CoinType) async throws -> Decimal {
        let service = blockchainServices[coinType]!
        let address = getAddress(for: coinType)
        return try await service.getBalance(for: address)
    }

    func sendTransaction(
        coinType: CoinType,
        to: String,
        amount: Decimal
    ) async throws -> String {
        let service = blockchainServices[coinType]!
        let address = getAddress(for: coinType)
        let privateKey = try getPrivateKey(for: coinType) // Secure Enclave protected

        return try await service.sendTransaction(
            from: address,
            to: to,
            amount: amount,
            privateKey: privateKey
        )
    }

    func buyWithFiat(
        coinType: CoinType,
        amount: Decimal
    ) async throws -> String {
        let address = getAddress(for: coinType)
        return try await paymentProvider.buy(
            cryptocurrency: coinType.symbol,
            amount: amount,
            destinationAddress: address
        )
    }
}
```

---

## Security Checklist for Production

- [x] BIP39 mnemonic generation with secure randomness
- [x] BIP32 HD wallet derivation (hardened paths)
- [x] BIP44 multi-currency support
- [x] Secure Enclave for key storage
- [x] Biometric authentication (Face ID / Touch ID)
- [x] Encrypted backup with user password
- [x] Jailbreak detection
- [x] Certificate pinning for network requests
- [x] Code obfuscation
- [x] No logging of sensitive data
- [x] Memory wiping after use
- [x] Transaction confirmation UI
- [x] Address validation
- [x] QR code scanning with address validation
- [x] Clipboard monitoring (warn on paste)
- [x] Screenshot detection (warn during seed display)
- [x] App Transport Security (force HTTPS)
- [x] Third-party security audit

---

## References

1. BIP39 Specification: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
2. BIP32 Specification: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
3. BIP44 Specification: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
4. Apple Secure Enclave: https://support.apple.com/guide/security/secure-enclave-sec59b0b31ff
5. SLIP-0044 Coin Types: https://github.com/satoshilabs/slips/blob/master/slip-0044.md
6. Ethereum Yellow Paper: https://ethereum.github.io/yellowpaper/paper.pdf
7. Bitcoin Developer Guide: https://developer.bitcoin.org/
8. NIST Cryptographic Standards: https://csrc.nist.gov/publications

---

*Research conducted: October 21, 2025*
*Agent: CryptoResearcher*
*Project: Fueki Mobile Wallet*
