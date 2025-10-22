# Test Vector Validation Suite

This directory contains comprehensive test vectors for validating the cryptographic implementations in Fueki Mobile Wallet.

## Test Categories

### 1. Bitcoin Test Vectors (`/bitcoin`)

#### BIP32 - Hierarchical Deterministic Wallets
- **File**: `bip32.test.ts`
- **Source**: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors
- **Coverage**:
  - Test Vector 1: Standard derivation paths
  - Test Vector 2: Complex derivation with large indices
  - Test Vector 3: Public key derivation
  - Hardened vs non-hardened derivation
  - Extended key import/export

#### BIP39 - Mnemonic Code for Generating Deterministic Keys
- **File**: `bip39.test.ts`
- **Source**: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki#test-vectors
- **Coverage**:
  - 24 official test vectors
  - Entropy to mnemonic conversion
  - Mnemonic to seed derivation
  - Mnemonic validation
  - Checksum verification
  - Multiple word lengths (12, 18, 24 words)

#### BIP44 - Multi-Account Hierarchy
- **File**: `bip44.test.ts`
- **Source**: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki
- **Coverage**:
  - Account discovery (m/44'/coin'/account'/change/address)
  - Bitcoin mainnet (coin_type = 0)
  - Bitcoin testnet (coin_type = 1)
  - Address gap limit (20 addresses)
  - SegWit compatibility (BIP84, BIP49)
  - Extended public key export

#### Bitcoin Transaction Signing
- **File**: `transaction-signing.test.ts`
- **Coverage**:
  - P2PKH transactions
  - P2WPKH (Native SegWit)
  - P2SH-P2WPKH (Nested SegWit)
  - Multi-input transactions
  - Change address handling
  - SIGHASH types
  - Fee calculation
  - Contract deployment
  - Transaction serialization

### 2. Ethereum Test Vectors (`/ethereum`)

#### Address Generation
- **File**: `address-generation.test.ts`
- **Coverage**:
  - BIP44 Ethereum path (m/44'/60'/0'/0/x)
  - Public key to address conversion
  - Keccak256 hashing
  - EIP-55 checksummed addresses
  - Multiple account derivation
  - Address uniqueness validation

#### Transaction Signing
- **File**: `transaction-signing.test.ts`
- **Coverage**:
  - Legacy transactions (pre-EIP-155)
  - EIP-155: Replay protection with chain ID
  - EIP-2930: Access list transactions
  - EIP-1559: Fee market transactions
  - Transaction serialization
  - Sender address recovery
  - Transaction hash calculation
  - Contract deployment
  - Multi-signature coordination

### 3. TSS Test Vectors (`/tss`)

#### Threshold Signature Scheme
- **File**: `key-generation.test.ts`
- **Coverage**:
  - Shamir Secret Sharing basics
  - Threshold enforcement (2-of-3, 3-of-5, 5-of-7, 7-of-10)
  - Distributed Key Generation (DKG)
  - Verifiable Secret Sharing (VSS)
  - Proactive Secret Sharing (share refresh)
  - Dynamic threshold changes
  - Share corruption detection
  - Large threshold scalability

### 4. Shamir's Secret Sharing (`/shamir`)

#### SLIP-39 Implementation
- **File**: `secret-sharing.test.ts`
- **Source**: https://github.com/satoshilabs/slips/blob/master/slip-0039.md
- **Coverage**:
  - GF(256) arithmetic operations
  - Polynomial evaluation in GF(256)
  - Lagrange interpolation
  - Multi-byte secret sharing
  - 16-byte and 32-byte secrets
  - Group sharing (2-of-3 groups with 2-of-3 members)
  - Share validation
  - Error detection
  - Performance testing (256-byte secrets)

## Running Tests

### Run all test vectors:
```bash
npm run test:vectors
```

### Run specific test suites:
```bash
npm run test:bitcoin      # Bitcoin test vectors
npm run test:ethereum     # Ethereum test vectors
npm run test:tss          # TSS test vectors
npm run test:shamir       # Shamir's Secret Sharing test vectors
```

### Run with coverage:
```bash
npm run test:coverage
```

### Watch mode:
```bash
npm run test:watch
```

## Test Vector Sources

All test vectors are sourced from official specifications:

1. **Bitcoin Improvement Proposals (BIPs)**
   - BIP32: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
   - BIP39: https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki
   - BIP44: https://github.com/bitcoin/bips/blob/master/bip-0044.mediawiki

2. **Ethereum Improvement Proposals (EIPs)**
   - EIP-55: Mixed-case checksum address encoding
   - EIP-155: Simple replay attack protection
   - EIP-1559: Fee market change
   - EIP-2930: Optional access lists

3. **SLIP-39**
   - Shamir's Secret Sharing for Mnemonic Codes
   - https://github.com/satoshilabs/slips/blob/master/slip-0039.md

## Success Criteria

All tests must pass with:
- ✅ 100% test success rate
- ✅ Exact match with official test vectors
- ✅ All edge cases covered
- ✅ Performance within acceptable limits

## Dependencies

The test suite requires the following packages:

- `bip32`: HD wallet key derivation
- `bip39`: Mnemonic generation and validation
- `bitcoinjs-lib`: Bitcoin transaction handling
- `@ethereumjs/tx`: Ethereum transaction handling
- `@ethereumjs/common`: Ethereum chain configuration
- `ethereumjs-util`: Ethereum utility functions
- `tiny-secp256k1`: Elliptic curve operations
- `jest`: Testing framework
- `ts-jest`: TypeScript support for Jest

## Test Results

After running the tests, you should see output similar to:

```
PASS  tests/vectors/bitcoin/bip32.test.ts
PASS  tests/vectors/bitcoin/bip39.test.ts
PASS  tests/vectors/bitcoin/bip44.test.ts
PASS  tests/vectors/bitcoin/transaction-signing.test.ts
PASS  tests/vectors/ethereum/address-generation.test.ts
PASS  tests/vectors/ethereum/transaction-signing.test.ts
PASS  tests/vectors/tss/key-generation.test.ts
PASS  tests/vectors/shamir/secret-sharing.test.ts

Test Suites: 8 passed, 8 total
Tests:       150+ passed, 150+ total
```

## Notes

- All test vectors use deterministic values for reproducibility
- Private keys in tests are for testing purposes only
- Never use test mnemonics or keys in production
- Some tests may take longer due to cryptographic operations
