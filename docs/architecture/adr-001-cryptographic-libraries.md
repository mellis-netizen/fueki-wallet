# ADR-001: Cryptographic Library Selection

## Status
**ACCEPTED** - 2025-10-21

## Context

The Fueki Mobile Wallet requires robust, production-grade cryptographic libraries for:
- Elliptic curve cryptography (secp256k1, secp256r1)
- Hash functions (SHA-256, RIPEMD-160, Keccak-256)
- Key derivation (BIP32, BIP39)
- Address encoding (Base58, Bech32, Checksums)
- Digital signatures (ECDSA, EdDSA)

### Requirements
1. **Security**: Audited, battle-tested libraries
2. **Performance**: Fast enough for mobile devices
3. **Size**: Small bundle size for mobile apps
4. **Compatibility**: Works with React Native
5. **Standards**: Implements BIPs and EIPs correctly
6. **Maintenance**: Actively maintained libraries

### Constraints
- Must run in React Native (limited Node.js APIs)
- Cannot use native addons requiring compilation
- Need TypeScript support for type safety
- Must support both iOS and Android

## Decision

We will use the **@noble cryptography suite** as our primary cryptographic library stack:

### Core Cryptographic Libraries

#### 1. **@noble/secp256k1** (Bitcoin/Ethereum curves)
```typescript
import * as secp256k1 from '@noble/secp256k1';

// Key generation
const privateKey = secp256k1.utils.randomPrivateKey();
const publicKey = secp256k1.getPublicKey(privateKey);

// Signing
const messageHash = sha256('transaction data');
const signature = await secp256k1.sign(messageHash, privateKey);
const isValid = secp256k1.verify(signature, messageHash, publicKey);
```

**Why @noble/secp256k1:**
- ✅ Audited by Trail of Bits and Cure53
- ✅ Zero dependencies
- ✅ TypeScript native
- ✅ 4.5 KB minified
- ✅ Works in React Native without polyfills
- ✅ Supports schnorr signatures (BIP-340)

#### 2. **@noble/curves** (Multi-curve support)
```typescript
import { secp256k1 } from '@noble/curves/secp256k1';
import { ed25519 } from '@noble/curves/ed25519';
import { p256 } from '@noble/curves/p256';

// Unified API across curves
const privKey = secp256k1.utils.randomPrivateKey();
const pubKey = secp256k1.getPublicKey(privKey);
```

**Why @noble/curves:**
- ✅ Supports secp256k1, ed25519, p256, p384, p521
- ✅ Unified API for all curves
- ✅ High performance with constant-time operations
- ✅ Modular imports (tree-shakeable)

#### 3. **@noble/hashes** (Hash functions)
```typescript
import { sha256, ripemd160, keccak_256 } from '@noble/hashes';
import { pbkdf2 } from '@noble/hashes/pbkdf2';

// Bitcoin address hashing
const hash160 = ripemd160(sha256(publicKey));

// Ethereum address hashing
const ethHash = keccak_256(publicKey.slice(1));
const address = ethHash.slice(-20);

// Key derivation
const derivedKey = pbkdf2(sha256, password, salt, { c: 2048, dkLen: 32 });
```

**Why @noble/hashes:**
- ✅ SHA-2, SHA-3, RIPEMD, Blake2/3, Keccak
- ✅ HMAC, HKDF, PBKDF2
- ✅ Fast and lightweight
- ✅ Constant-time operations

#### 4. **@scure/bip32** (HD Wallets)
```typescript
import { HDKey } from '@scure/bip32';

// BIP32 derivation
const masterKey = HDKey.fromMasterSeed(seed);
const account = masterKey.derive("m/44'/0'/0'/0/0");
const privateKey = account.privateKey;
const publicKey = account.publicKey;
```

**Why @scure/bip32:**
- ✅ Implements BIP-32, BIP-44, BIP-49, BIP-84
- ✅ Uses @noble/hashes and @noble/secp256k1
- ✅ Supports custom derivation paths
- ✅ TypeScript native

#### 5. **@scure/bip39** (Mnemonic phrases)
```typescript
import * as bip39 from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english';

// Generate mnemonic
const mnemonic = bip39.generateMnemonic(wordlist, 256); // 24 words
const isValid = bip39.validateMnemonic(mnemonic, wordlist);

// Convert to seed
const seed = await bip39.mnemonicToSeed(mnemonic, 'passphrase');
```

**Why @scure/bip39:**
- ✅ Implements BIP-39 specification
- ✅ Multiple language wordlists
- ✅ Secure random generation
- ✅ Optional passphrase support

#### 6. **@scure/base** (Encoding/Decoding)
```typescript
import { base58, base58check, bech32, bech32m } from '@scure/base';

// Base58Check (Bitcoin legacy addresses)
const address = base58check.encode(hash160);

// Bech32 (Bitcoin SegWit addresses)
const segwitAddress = bech32.encode('bc', bech32.toWords(hash));

// Bech32m (Taproot addresses)
const taprootAddress = bech32m.encode('bc', bech32m.toWords(pubkey));
```

**Why @scure/base:**
- ✅ Base58, Base58Check, Bech32, Bech32m
- ✅ Hex, Base64, UTF-8 utilities
- ✅ No dependencies
- ✅ TypeScript native

### Blockchain-Specific Libraries

#### 7. **bitcoinjs-lib** (Bitcoin transactions)
```typescript
import * as bitcoin from 'bitcoinjs-lib';

// Create transaction
const psbt = new bitcoin.Psbt({ network: bitcoin.networks.bitcoin });
psbt.addInput({ hash: txId, index: 0, witnessUtxo: { ... } });
psbt.addOutput({ address: recipientAddress, value: amount });
psbt.signInput(0, keyPair);
const tx = psbt.finalizeAllInputs().extractTransaction();
```

**Why bitcoinjs-lib:**
- ✅ Industry standard for Bitcoin
- ✅ PSBT support (BIP-174)
- ✅ SegWit and Taproot support
- ✅ Extensive testing and adoption

**Alternative considered**: @scure/btc-signer
- Lighter weight, newer library
- Use for specific advanced features

#### 8. **ethers.js v6** (Ethereum transactions)
```typescript
import { Wallet, JsonRpcProvider, parseEther } from 'ethers';

// Create wallet
const wallet = new Wallet(privateKey, provider);

// Send transaction
const tx = await wallet.sendTransaction({
  to: recipientAddress,
  value: parseEther('0.1'),
  gasLimit: 21000,
});
```

**Why ethers.js v6:**
- ✅ Full Ethereum implementation
- ✅ EIP-1559, EIP-4844 support
- ✅ TypeScript rewrite in v6
- ✅ Tree-shakeable, smaller bundle
- ✅ Strong security track record

**Alternative considered**: viem
- Modern, lightweight alternative
- Can be added later for specific use cases

### Security & Randomness

#### 9. **react-native-get-random-values** (CSPRNG)
```typescript
import 'react-native-get-random-values';

// Enables crypto.getRandomValues() in React Native
const randomBytes = crypto.getRandomValues(new Uint8Array(32));
```

**Why react-native-get-random-values:**
- ✅ Provides secure random number generation
- ✅ Uses platform native APIs (SecRandomCopyBytes on iOS, java.security.SecureRandom on Android)
- ✅ Required for @noble libraries
- ✅ Minimal overhead

### Utility Libraries

#### 10. **BigInt Native Support**
```typescript
// Use native BigInt (available in modern JS engines)
const value = BigInt('1000000000000000000'); // 1 ETH in wei
const half = value / 2n;
```

**Why Native BigInt:**
- ✅ Built into modern JavaScript
- ✅ No library needed
- ✅ Better performance
- ✅ Supported in React Native 0.70+

**Note**: For older versions or specific needs, use `big-integer` or `bn.js`

## Architecture

### Cryptographic Layer Structure
```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│         (Wallets, Transactions, Signatures)                 │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                  Crypto Service Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Key          │  │ Signature    │  │ Hash         │     │
│  │ Management   │  │ Service      │  │ Service      │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Cryptographic Primitives Layer                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ @noble/      │  │ @scure/      │  │ @scure/      │     │
│  │ secp256k1    │  │ bip32        │  │ bip39        │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ @noble/      │  │ @scure/      │  │ ethers.js    │     │
│  │ hashes       │  │ base         │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Platform Layer                            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ react-native-get-random-values (CSPRNG)              │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Native Crypto APIs (iOS/Android)                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Implementation Pattern

```typescript
// src/core/crypto/CryptoService.ts
import * as secp256k1 from '@noble/secp256k1';
import { sha256, ripemd160, keccak_256 } from '@noble/hashes';
import { HDKey } from '@scure/bip32';
import * as bip39 from '@scure/bip39';
import { wordlist } from '@scure/bip39/wordlists/english';
import { base58check, bech32 } from '@scure/base';

export class CryptoService {
  // Mnemonic operations
  static generateMnemonic(strength: 128 | 256 = 256): string {
    return bip39.generateMnemonic(wordlist, strength);
  }

  static validateMnemonic(mnemonic: string): boolean {
    return bip39.validateMnemonic(mnemonic, wordlist);
  }

  static async mnemonicToSeed(mnemonic: string, passphrase?: string): Promise<Uint8Array> {
    return await bip39.mnemonicToSeed(mnemonic, passphrase);
  }

  // HD wallet operations
  static deriveKey(seed: Uint8Array, path: string): HDKey {
    const masterKey = HDKey.fromMasterSeed(seed);
    return masterKey.derive(path);
  }

  // Signature operations
  static async sign(messageHash: Uint8Array, privateKey: Uint8Array): Promise<Uint8Array> {
    return await secp256k1.sign(messageHash, privateKey);
  }

  static verify(signature: Uint8Array, messageHash: Uint8Array, publicKey: Uint8Array): boolean {
    return secp256k1.verify(signature, messageHash, publicKey);
  }

  // Hash operations
  static sha256(data: Uint8Array): Uint8Array {
    return sha256(data);
  }

  static hash160(data: Uint8Array): Uint8Array {
    return ripemd160(sha256(data));
  }

  static keccak256(data: Uint8Array): Uint8Array {
    return keccak_256(data);
  }

  // Address encoding
  static toBitcoinAddress(publicKey: Uint8Array, network: 'mainnet' | 'testnet' = 'mainnet'): string {
    const hash160 = this.hash160(publicKey);
    const version = network === 'mainnet' ? 0x00 : 0x6f;
    return base58check.encode(new Uint8Array([version, ...hash160]));
  }

  static toBech32Address(publicKey: Uint8Array, hrp: string = 'bc'): string {
    const hash160 = this.hash160(publicKey);
    const words = bech32.toWords(hash160);
    return bech32.encode(hrp, [0, ...words]);
  }

  static toEthereumAddress(publicKey: Uint8Array): string {
    // Public key is 65 bytes (uncompressed), remove first byte (0x04)
    const hash = keccak_256(publicKey.slice(1));
    // Take last 20 bytes
    return '0x' + Buffer.from(hash.slice(-20)).toString('hex');
  }
}
```

## Alternatives Considered

### 1. **elliptic** ❌
- **Pros**: Widely used, comprehensive
- **Cons**: Unmaintained since 2020, security concerns, larger bundle size
- **Decision**: Rejected due to maintenance concerns

### 2. **crypto-browserify** ❌
- **Pros**: Node.js crypto API compatibility
- **Cons**: Large bundle size (300+ KB), many dependencies, polyfill complexity
- **Decision**: Rejected due to size and complexity

### 3. **tweetnacl** ⚠️
- **Pros**: Tiny, audited, Ed25519 support
- **Cons**: Doesn't support secp256k1, limited to specific use cases
- **Decision**: Consider for Ed25519-only chains (Solana, etc.)

### 4. **noble-ed25519** ✅ (Future)
- **Pros**: Same author as @noble/secp256k1, audited
- **Cons**: Not needed for Bitcoin/Ethereum
- **Decision**: Use when adding Solana, Cardano, etc.

### 5. **web3.js** ❌
- **Pros**: Official Ethereum library
- **Cons**: Large bundle, older architecture, slower
- **Decision**: Rejected in favor of ethers.js

### 6. **viem** ⚠️ (Future consideration)
- **Pros**: Modern, TypeScript-first, lightweight, modular
- **Cons**: Newer, less battle-tested than ethers.js
- **Decision**: Monitor for future adoption

## Consequences

### Positive
✅ **Security**: All libraries are audited and actively maintained
✅ **Performance**: Optimized for mobile, small bundle sizes
✅ **Type Safety**: Full TypeScript support
✅ **Standards Compliance**: Correct BIP/EIP implementations
✅ **React Native Compatible**: No Node.js polyfills needed
✅ **Modular**: Tree-shakeable, import only what you need
✅ **Future-Proof**: Active development and community support

### Negative
⚠️ **Learning Curve**: Multiple libraries to understand
⚠️ **Version Management**: Need to keep libraries in sync
⚠️ **Bundle Size**: Still ~100 KB combined (acceptable for crypto wallet)

### Risks
🔴 **Library Vulnerabilities**: Must monitor security advisories
🟡 **Breaking Changes**: Major version updates may require refactoring
🟢 **React Native Compatibility**: Test thoroughly on both platforms

## Mitigation Strategies

### 1. Security Monitoring
```bash
# Regular dependency audits
npm audit
npm outdated

# Use Dependabot or Renovate for automated updates
```

### 2. Version Pinning
```json
{
  "dependencies": {
    "@noble/secp256k1": "2.0.0",
    "@noble/curves": "1.3.0",
    "@noble/hashes": "1.4.0",
    "@scure/bip32": "1.4.0",
    "@scure/bip39": "1.3.0",
    "@scure/base": "1.1.6"
  }
}
```

### 3. Testing Strategy
- Unit tests for all crypto operations
- Property-based testing with known test vectors
- Cross-reference with reference implementations
- Platform-specific tests (iOS/Android)

### 4. Performance Monitoring
- Benchmark crypto operations on target devices
- Profile memory usage
- Monitor bundle size impact
- Use native modules if performance issues arise

## Implementation Plan

### Phase 1: Core Setup (Week 1)
1. Install @noble and @scure libraries
2. Setup react-native-get-random-values
3. Create CryptoService abstraction
4. Write unit tests with test vectors

### Phase 2: Bitcoin Support (Week 2)
1. Integrate bitcoinjs-lib
2. Implement address generation
3. Transaction signing
4. Test on testnet

### Phase 3: Ethereum Support (Week 3)
1. Integrate ethers.js
2. Implement address generation
3. Transaction signing
4. Test on testnet

### Phase 4: Testing & Optimization (Week 4)
1. Cross-platform testing
2. Performance benchmarking
3. Security review
4. Documentation

## References

### Libraries
- [@noble/secp256k1](https://github.com/paulmillr/noble-secp256k1)
- [@noble/curves](https://github.com/paulmillr/noble-curves)
- [@noble/hashes](https://github.com/paulmillr/noble-hashes)
- [@scure/bip32](https://github.com/paulmillr/scure-bip32)
- [@scure/bip39](https://github.com/paulmillr/scure-bip39)
- [@scure/base](https://github.com/paulmillr/scure-base)
- [bitcoinjs-lib](https://github.com/bitcoinjs/bitcoinjs-lib)
- [ethers.js](https://github.com/ethers-io/ethers.js)

### Security Audits
- [Trail of Bits Audit - @noble/secp256k1](https://github.com/trailofbits/publications/blob/master/reviews/2022-10-secp256k1-securityreview.pdf)
- [Cure53 Audit - @noble libraries](https://github.com/paulmillr/noble-curves/blob/main/audit/2023-01-noble-report.pdf)

### Standards
- [BIP-32: HD Wallets](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
- [BIP-39: Mnemonic Code](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki)
- [BIP-44: Multi-Account Hierarchy](https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki)

---

**Related ADRs:**
- [ADR-002: Key Management Architecture](./adr-002-key-management.md)
- [ADR-007: Transaction Architecture](./adr-007-transaction-architecture.md)
