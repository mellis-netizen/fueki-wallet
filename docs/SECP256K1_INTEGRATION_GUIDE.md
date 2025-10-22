# secp256k1 Integration Guide

Quick start guide for integrating the production secp256k1 implementation into Fueki Mobile Wallet.

## Prerequisites

- Xcode 15.0+
- Swift 5.9+
- iOS 14.0+ / macOS 11.0+

## Step-by-Step Integration

### 1. Add Swift Package Dependency

#### Option A: Swift Package Manager (CLI)

Add to your `Package.swift`:

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FuekiWallet",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    dependencies: [
        // Add secp256k1 dependency
        .package(url: "https://github.com/bitcoin-core/secp256k1.git", branch: "master"),
        .package(path: "src/crypto/packages/Secp256k1Swift")
    ],
    targets: [
        .target(
            name: "FuekiWallet",
            dependencies: [
                "Secp256k1Swift"
            ]
        )
    ]
)
```

#### Option B: Xcode Project

1. Open your Xcode project
2. File → Add Package Dependencies
3. Add local package: `src/crypto/packages/Secp256k1Swift`
4. Select your target and add `Secp256k1Swift` to frameworks

### 2. Update Secp256k1Bridge.swift

Replace the fallback implementation with real secp256k1:

```swift
import Foundation
import CryptoKit
import Secp256k1Swift  // Add this import

public class Secp256k1Bridge {

    // ... existing error types ...

    public static func derivePublicKey(from privateKey: Data, compressed: Bool = true) throws -> Data {
        // Use production secp256k1
        do {
            return try Secp256k1.derivePublicKey(from: privateKey, compressed: compressed)
        } catch let error as Secp256k1.Secp256k1Error {
            throw Secp256k1Error.publicKeyDerivationFailed
        } catch {
            throw Secp256k1Error.publicKeyDerivationFailed
        }
    }

    public static func sign(messageHash: Data, privateKey: Data, useRFC6979: Bool = true) throws -> Data {
        // Use production secp256k1 (always uses RFC6979)
        do {
            return try Secp256k1.sign(messageHash: messageHash, with: privateKey)
        } catch {
            throw Secp256k1Error.signatureCreationFailed
        }
    }

    public static func signRecoverable(messageHash: Data, privateKey: Data) throws -> Data {
        // Use production secp256k1
        do {
            return try Secp256k1.signRecoverable(messageHash: messageHash, with: privateKey)
        } catch {
            throw Secp256k1Error.signatureCreationFailed
        }
    }

    public static func verify(signature: Data, messageHash: Data, publicKey: Data) throws -> Bool {
        // Use production secp256k1
        do {
            return try Secp256k1.verify(signature: signature, messageHash: messageHash, publicKey: publicKey)
        } catch {
            return false
        }
    }

    public static func recoverPublicKey(from signature: Data, messageHash: Data) throws -> Data {
        // Use production secp256k1
        do {
            return try Secp256k1.recoverPublicKey(from: signature, messageHash: messageHash, compressed: false)
        } catch {
            throw Secp256k1Error.publicKeyDerivationFailed
        }
    }

    // Key operations for HD wallets
    public static func privateKeyAdd(_ key1: Data, _ key2: Data) throws -> Data {
        do {
            return try Secp256k1.privateKeyAdd(key1, tweak: key2)
        } catch {
            throw Secp256k1Error.invalidPrivateKey
        }
    }

    public static func privateKeyMultiply(_ privateKey: Data, by scalar: Data) throws -> Data {
        do {
            return try Secp256k1.privateKeyMultiply(privateKey, by: scalar)
        } catch {
            throw Secp256k1Error.invalidPrivateKey
        }
    }

    // Validation
    public static func isValidPrivateKey(_ privateKey: Data) -> Bool {
        return Secp256k1.isValidPrivateKey(privateKey)
    }

    public static func isValidPublicKey(_ publicKey: Data) -> Bool {
        return Secp256k1.isValidPublicKey(publicKey)
    }
}
```

### 3. Build the Project

```bash
# Clean build
swift build --clean

# Build with optimization
swift build -c release

# Run tests
swift test
```

### 4. Verify Integration

Create a simple test to verify everything works:

```swift
import XCTest
import Secp256k1Swift

class IntegrationTests: XCTestCase {

    func testSecp256k1Integration() throws {
        // Generate a private key
        var privateKey = Data(count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, 32, &privateKey.withUnsafeMutableBytes { $0.baseAddress! })
        XCTAssertEqual(status, errSecSuccess)

        // Derive public key
        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)
        XCTAssertEqual(publicKey.count, 33)

        // Sign a message
        let messageHash = Data(count: 32)
        let signature = try Secp256k1.sign(messageHash: messageHash, with: privateKey)
        XCTAssertEqual(signature.count, 64)

        // Verify signature
        let isValid = try Secp256k1.verify(signature: signature, messageHash: messageHash, publicKey: publicKey)
        XCTAssertTrue(isValid)

        print("✅ secp256k1 integration successful!")
    }
}
```

## Common Use Cases

### Bitcoin Transaction Signing

```swift
import Secp256k1Swift

func signBitcoinTransaction(_ tx: BitcoinTransaction, privateKey: Data) throws -> Data {
    // 1. Serialize transaction
    let serialized = tx.serialize()

    // 2. Double SHA-256 hash
    let hash1 = SHA256.hash(data: serialized)
    let hash2 = SHA256.hash(data: hash1)

    // 3. Sign with secp256k1
    let signature = try Secp256k1.sign(messageHash: Data(hash2), with: privateKey)

    // 4. Normalize to low-S (BIP 62)
    let normalizedSig = Secp256k1.normalizeSignature(signature)

    return normalizedSig
}
```

### Ethereum Transaction Signing

```swift
import Secp256k1Swift

func signEthereumTransaction(_ tx: EthereumTransaction, privateKey: Data) throws -> (v: UInt8, r: Data, s: Data) {
    // 1. RLP encode transaction
    let rlpEncoded = tx.rlpEncode()

    // 2. Keccak-256 hash
    let txHash = keccak256(rlpEncoded)

    // 3. Sign with recovery
    let signature = try Secp256k1.signRecoverable(messageHash: txHash, with: privateKey)

    // 4. Extract v, r, s
    let r = signature[0..<32]
    let s = signature[32..<64]
    let recoveryId = signature[64]

    // 5. Calculate Ethereum v (EIP-155)
    let chainId: UInt = 1 // Mainnet
    let v = UInt8(35 + recoveryId + (2 * chainId))

    return (v: v, r: r, s: s)
}
```

### TSS Social Recovery

```swift
import Secp256k1Swift

func deriveSharedPublicKey(from keyShares: [Data]) throws -> Data {
    // 1. Reconstruct private key from shares
    let privateKey = try reconstructPrivateKey(from: keyShares)

    // 2. Derive public key using secp256k1
    let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)

    // 3. Securely wipe private key
    secureWipe(privateKey)

    return publicKey
}
```

## Performance Optimization Tips

### 1. Reuse Context (C library only)

The underlying C library benefits from context reuse, but our Swift wrapper handles this automatically.

### 2. Batch Operations

Process multiple operations in a batch:

```swift
let privateKeys = [key1, key2, key3]
let publicKeys = try privateKeys.map { try Secp256k1.derivePublicKey(from: $0) }
```

### 3. Use Compressed Keys

Compressed keys (33 bytes) save bandwidth and storage:

```swift
let compressedPubKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)
```

## Troubleshooting

### Build Errors

**Error:** `module 'CSecp256k1' not found`

**Solution:** Ensure bitcoin-core/secp256k1 dependency is properly added and built:
```bash
swift package resolve
swift build
```

**Error:** `undefined symbol: secp256k1_context_create`

**Solution:** The C library isn't being linked. Check Package.swift dependencies.

### Runtime Errors

**Error:** `invalidPrivateKey`

**Solution:** Private key must be 32 bytes and in range [1, n-1]:
```swift
let isValid = Secp256k1.isValidPrivateKey(privateKey)
if !isValid {
    // Generate new key or handle error
}
```

**Error:** `publicKeyDerivationFailed`

**Solution:** Check that private key is valid and not zero.

### Performance Issues

If operations seem slow:

1. Ensure you're using Release build configuration
2. Check that SIMD optimizations are enabled
3. Profile with Instruments to identify bottlenecks

## Testing

Run the comprehensive test suite:

```bash
cd src/crypto/packages/Secp256k1Swift

# Run all tests
swift test

# Run specific test
swift test --filter Secp256k1Tests.testPublicKeyDerivation

# Run with verbose output
swift test --verbose

# Run performance tests
swift test --filter testPerformance
```

## Migration Checklist

- [ ] Add Secp256k1Swift package dependency
- [ ] Update Secp256k1Bridge.swift imports
- [ ] Replace all fallback implementations
- [ ] Update TSSKeyGeneration to use bridge
- [ ] Update TransactionSigner to use bridge
- [ ] Run integration tests
- [ ] Run performance benchmarks
- [ ] Update documentation
- [ ] Code review
- [ ] Security audit (if required)

## Security Considerations

### 1. Private Key Handling

**Never log or print private keys:**
```swift
// ❌ NEVER DO THIS
print("Private key: \(privateKey)")

// ✅ Do this instead
print("Private key length: \(privateKey.count) bytes")
```

### 2. Secure Memory

**Wipe sensitive data after use:**
```swift
var privateKey = generatePrivateKey()
defer {
    privateKey.resetBytes(in: 0..<privateKey.count)
}
// Use privateKey...
```

### 3. Validate All Inputs

**Always validate before cryptographic operations:**
```swift
guard Secp256k1.isValidPrivateKey(privateKey) else {
    throw CryptoError.invalidPrivateKey
}
```

### 4. Use Deterministic Signatures

**RFC 6979 is enabled by default (secure):**
```swift
// This uses RFC 6979 deterministic nonce generation
let signature = try Secp256k1.sign(messageHash: hash, with: privateKey)
```

## Support

For issues or questions:

1. Check the README: `src/crypto/packages/Secp256k1Swift/README.md`
2. Review test examples: `Tests/Secp256k1SwiftTests/Secp256k1Tests.swift`
3. Consult implementation docs: `docs/SECP256K1_IMPLEMENTATION.md`

## References

- [bitcoin-core/secp256k1](https://github.com/bitcoin-core/secp256k1)
- [RFC 6979 - Deterministic ECDSA](https://tools.ietf.org/html/rfc6979)
- [BIP 32 - HD Wallets](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
- [EIP 155 - Ethereum Transactions](https://eips.ethereum.org/EIPS/eip-155)

---

*Integration guide for production secp256k1 implementation*
