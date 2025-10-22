# Fueki Mobile Wallet - Security Documentation

## Table of Contents
1. [Security Overview](#security-overview)
2. [Cryptographic Standards](#cryptographic-standards)
3. [Key Management](#key-management)
4. [Transaction Security](#transaction-security)
5. [Network Security](#network-security)
6. [Data Protection](#data-protection)
7. [Threat Model](#threat-model)
8. [Security Best Practices](#security-best-practices)
9. [Compliance](#compliance)
10. [Security Testing](#security-testing)

---

## Security Overview

Fueki Mobile Wallet implements industry-standard security practices for cryptocurrency wallet applications, following established BIPs (Bitcoin Improvement Proposals) and EIPs (Ethereum Improvement Proposals).

### Security Principles

1. **Defense in Depth**: Multiple layers of security
2. **Least Privilege**: Minimum necessary permissions
3. **Fail Secure**: Safe failure modes
4. **Security by Design**: Security from ground up
5. **Zero Trust**: Verify everything

### Security Boundaries

```
┌─────────────────────────────────────────┐
│         User Device (Trusted)            │
│  ┌───────────────────────────────────┐  │
│  │    Application Layer              │  │
│  │  - UI Input Validation            │  │
│  │  - Transaction Authorization      │  │
│  │  - Biometric Authentication       │  │
│  └───────────┬───────────────────────┘  │
│              │                            │
│  ┌───────────▼───────────────────────┐  │
│  │    Security Layer                 │  │
│  │  - Key Derivation (BIP32/39/44)  │  │
│  │  - Transaction Signing            │  │
│  │  - Encryption/Decryption          │  │
│  └───────────┬───────────────────────┘  │
│              │                            │
│  ┌───────────▼───────────────────────┐  │
│  │    Storage Layer                  │  │
│  │  - Secure Enclave                 │  │
│  │  - Encrypted Storage              │  │
│  │  - Keychain/Keystore              │  │
│  └───────────────────────────────────┘  │
└──────────────┬──────────────────────────┘
               │ TLS 1.3
┌──────────────▼──────────────────────────┐
│       Network (Untrusted)               │
│  - RPC Endpoints                        │
│  - Blockchain Networks                  │
└─────────────────────────────────────────┘
```

---

## Cryptographic Standards

### Supported Standards

#### Bitcoin Standards (BIPs)

**BIP32** - Hierarchical Deterministic Wallets
- Enables derivation of multiple keys from single seed
- Tree structure for key organization
- Public key derivation without private keys

**BIP39** - Mnemonic Code for Generating Seeds
- 12 or 24 word recovery phrases
- 2048-word dictionary (English)
- Built-in checksum for validation
- PBKDF2-HMAC-SHA512 for seed generation

**BIP44** - Multi-Account Hierarchy
- Standard derivation path: `m/44'/coin_type'/account'/change/address_index`
- Bitcoin: `m/44'/0'/0'/0/0`
- Testnet: `m/44'/1'/0'/0/0`
- Account isolation

#### Ethereum Standards (EIPs)

**EIP-55** - Mixed-case checksum address encoding
- Checksum validation for addresses
- Prevents copy-paste errors

**EIP-155** - Simple replay attack protection
- Chain-specific signatures
- Prevents cross-chain replay

**EIP-1559** - Fee market change
- Base fee + priority fee
- More predictable transaction costs

**EIP-2718** - Typed Transaction Envelope
- Multiple transaction types
- Extensible format

### Cryptographic Algorithms

#### Elliptic Curve Cryptography

**secp256k1 Curve**
```
Parameters:
- Prime field: 2^256 - 2^32 - 977
- Curve: y² = x³ + 7
- Generator point G
- Order n (prime)
- Cofactor h = 1
```

**Key Sizes**:
- Private key: 256 bits (32 bytes)
- Public key: 512 bits uncompressed (65 bytes)
- Public key: 264 bits compressed (33 bytes)

#### Hash Functions

**SHA-256** (Secure Hash Algorithm 256)
- Output: 256 bits
- Used for: Bitcoin addresses, transaction IDs

**Keccak-256**
- Output: 256 bits
- Used for: Ethereum addresses, transaction hashes

**RIPEMD-160**
- Output: 160 bits
- Used for: Bitcoin address generation

**PBKDF2-HMAC-SHA512**
- Key derivation from mnemonic
- 2048 iterations (BIP39)
- Salt: "mnemonic" + optional passphrase

---

## Key Management

### Mnemonic Generation

```typescript
// Security: Cryptographically secure random generation
import { generateMnemonic } from 'bip39';

// Generate 128-bit entropy → 12 words
const mnemonic12 = generateMnemonic(128);

// Generate 256-bit entropy → 24 words
const mnemonic24 = generateMnemonic(256);
```

**Security Requirements**:
- Use cryptographically secure random number generator (CSPRNG)
- Minimum 128-bit entropy (12 words)
- Recommended 256-bit entropy (24 words)
- Never reuse mnemonics across applications

### Seed Derivation

```typescript
import { mnemonicToSeedSync } from 'bip39';

// Derive 512-bit seed from mnemonic
const seed = mnemonicToSeedSync(
  mnemonic,
  passphrase // Optional extra security layer
);
```

**Security Considerations**:
- Passphrase adds additional security (25th word)
- Passphrase is case-sensitive
- Lost passphrase = lost funds
- Store separately from mnemonic

### Key Derivation (BIP32)

```typescript
import { BIP32Factory } from 'bip32';
import * as ecc from 'tiny-secp256k1';

const bip32 = BIP32Factory(ecc);
const root = bip32.fromSeed(seed);

// Derive Bitcoin key
const bitcoinPath = "m/44'/0'/0'/0/0";
const bitcoinKey = root.derivePath(bitcoinPath);

// Derive Ethereum key
const ethereumPath = "m/44'/60'/0'/0/0";
const ethereumKey = root.derivePath(ethereumPath);
```

**Derivation Levels**:
```
m / purpose' / coin_type' / account' / change / address_index

m           = Master key
purpose'    = 44' (BIP44)
coin_type'  = 0' (Bitcoin), 60' (Ethereum)
account'    = Account number (0' default)
change      = 0 (external), 1 (internal)
address_index = Address index (0, 1, 2...)

' = Hardened derivation
```

### Hardened vs Non-Hardened Derivation

**Hardened Derivation** (marked with ')
- Uses private key for derivation
- More secure
- Cannot derive child public keys from parent public key
- Used for: purpose, coin_type, account

**Non-Hardened Derivation**
- Uses public key for derivation
- Can derive child public keys
- Less secure if private key compromised
- Used for: change, address_index

### Key Storage

#### Secure Storage Options

**iOS**:
```typescript
// Use iOS Keychain
import Keychain from 'react-native-keychain';

await Keychain.setGenericPassword(
  'fueki_wallet',
  encryptedMnemonic,
  {
    service: 'com.fueki.wallet',
    accessControl: Keychain.ACCESS_CONTROL.BIOMETRY_ANY,
    accessible: Keychain.ACCESSIBLE.WHEN_UNLOCKED_THIS_DEVICE_ONLY
  }
);
```

**Android**:
```typescript
// Use Android Keystore
import EncryptedStorage from 'react-native-encrypted-storage';

await EncryptedStorage.setItem(
  'mnemonic',
  encryptedMnemonic
);
```

**Security Requirements**:
- Never store plaintext private keys
- Use device-specific encryption
- Enable biometric authentication
- Use secure enclave when available
- Implement auto-lock timeout

---

## Transaction Security

### Transaction Signing

#### Bitcoin Transaction Signing

```typescript
import * as bitcoin from 'bitcoinjs-lib';

const psbt = new bitcoin.Psbt({ network });

// Add inputs
psbt.addInput({
  hash: txid,
  index: vout,
  witnessUtxo: {
    script: Buffer.from(scriptPubKey, 'hex'),
    value: satoshis
  }
});

// Add outputs
psbt.addOutput({
  address: recipientAddress,
  value: amount
});

// Sign with private key
psbt.signInput(0, keyPair);
psbt.finalizeAllInputs();

// Extract signed transaction
const signedTx = psbt.extractTransaction().toHex();
```

**Security Checks**:
- Verify input amounts
- Validate recipient addresses
- Check fee reasonableness
- Confirm change addresses
- Verify all signatures

#### Ethereum Transaction Signing

```typescript
import { Transaction } from '@ethereumjs/tx';
import { Common } from '@ethereumjs/common';

const common = Common.custom({ chainId });

const tx = Transaction.fromTxData({
  nonce,
  gasLimit,
  gasPrice, // or maxFeePerGas + maxPriorityFeePerGas
  to: recipientAddress,
  value,
  data
}, { common });

// Sign with private key
const signedTx = tx.sign(privateKey);

// Serialize for broadcast
const serialized = signedTx.serialize().toString('hex');
```

**Security Checks**:
- Verify nonce
- Validate recipient address (EIP-55 checksum)
- Check gas limits
- Verify contract calls
- Validate signature (v, r, s)

### Replay Attack Protection

#### Bitcoin

**Mechanism**: Transaction hash includes all inputs and outputs
- Each transaction unique
- Cannot replay on same chain
- Testnet transactions invalid on mainnet (different addresses)

#### Ethereum (EIP-155)

**Mechanism**: Chain ID in signature
```typescript
// v value encodes chain ID
v = chainId * 2 + 35 + {0,1}

// Mainnet: chainId = 1 → v ∈ {37, 38}
// Sepolia: chainId = 11155111 → v ∈ {22310259, 22310260}
```

**Protection**:
- Transactions signed for specific chain
- Cannot replay across networks
- Signature validation includes chain ID

### Transaction Validation

**Pre-Broadcast Checks**:
```typescript
interface TransactionValidation {
  // Amount validation
  validateAmount(amount: bigint): boolean;

  // Address validation
  validateAddress(address: string): boolean;

  // Fee validation
  validateFee(fee: bigint): boolean;

  // Balance check
  hasSufficientBalance(amount: bigint, fee: bigint): boolean;

  // Signature validation
  validateSignature(tx: Transaction): boolean;
}
```

**Validation Rules**:
- Amount > 0 and < available balance
- Valid recipient address format
- Fee < amount (sanity check)
- All inputs signed correctly
- No duplicate inputs
- Valid nonce (Ethereum)

---

## Network Security

### TLS/SSL Encryption

**Requirements**:
- TLS 1.2 minimum (TLS 1.3 preferred)
- Valid SSL certificates
- Certificate pinning (recommended)
- Strong cipher suites

**Cipher Suites** (Recommended):
```
TLS_AES_256_GCM_SHA384
TLS_CHACHA20_POLY1305_SHA256
TLS_AES_128_GCM_SHA256
```

### Certificate Pinning

```typescript
// Pin specific certificates or public keys
const trustedCertificates = [
  'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
  'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='
];

// Validate server certificate
function validateCertificate(cert: Certificate): boolean {
  const hash = sha256(cert.publicKey);
  return trustedCertificates.includes(hash);
}
```

**Benefits**:
- Prevents MITM attacks
- Protects against compromised CAs
- Additional security layer

### API Endpoint Security

**Best Practices**:
```typescript
// Use multiple endpoints with failover
const endpoints = [
  'https://primary.example.com',
  'https://backup1.example.com',
  'https://backup2.example.com'
];

// Validate endpoint responses
function validateResponse(response: any): boolean {
  // Check response structure
  // Verify data consistency
  // Validate signatures (if applicable)
  return true;
}
```

### WebSocket Security

**Secure WebSocket (WSS)**:
```typescript
const wsClient = new WebSocketClient({
  url: 'wss://secure.example.com', // Use WSS not WS
  reconnect: true,
  pingInterval: 30000 // Detect dead connections
});
```

**Security Measures**:
- Use WSS (WebSocket over TLS)
- Implement message authentication
- Validate all incoming messages
- Rate limit subscriptions
- Timeout idle connections

### Rate Limiting

**Purpose**: Prevent abuse and DoS attacks

```typescript
const rateLimiter = new RateLimiter({
  requestsPerSecond: 10,
  burstSize: 20
});

// Enforce rate limits
await rateLimiter.waitForToken();
```

**Benefits**:
- Prevents API abuse
- Avoids account throttling
- Protects backend resources

---

## Data Protection

### Sensitive Data Categories

1. **Private Keys**: Never leave secure storage
2. **Mnemonics**: Encrypted at rest, never transmitted
3. **Passwords/PINs**: Hashed, never stored plaintext
4. **Transaction Data**: Encrypted in transit
5. **User Metadata**: Minimize collection

### Encryption at Rest

**Mnemonic Encryption**:
```typescript
import crypto from 'crypto';

// Encrypt mnemonic with user password
function encryptMnemonic(
  mnemonic: string,
  password: string
): string {
  // Derive key from password
  const salt = crypto.randomBytes(32);
  const key = crypto.pbkdf2Sync(password, salt, 100000, 32, 'sha256');

  // Encrypt with AES-256-GCM
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);

  let encrypted = cipher.update(mnemonic, 'utf8', 'hex');
  encrypted += cipher.final('hex');

  const authTag = cipher.getAuthTag();

  // Combine salt + iv + authTag + encrypted
  return Buffer.concat([
    salt,
    iv,
    authTag,
    Buffer.from(encrypted, 'hex')
  ]).toString('base64');
}
```

### Encryption in Transit

**All Network Communication**:
- HTTPS for REST APIs
- WSS for WebSocket
- TLS 1.2+ required
- Perfect Forward Secrecy (PFS)

### Memory Security

**Sensitive Data Handling**:
```typescript
class SecureBuffer {
  private buffer: Buffer;

  constructor(data: Buffer) {
    this.buffer = Buffer.from(data);
  }

  // Use the data
  use(): Buffer {
    return this.buffer;
  }

  // Securely clear memory
  clear(): void {
    if (this.buffer) {
      crypto.randomFillSync(this.buffer); // Overwrite
      this.buffer = null!;
    }
  }
}

// Usage
const privateKey = new SecureBuffer(keyData);
try {
  // Use private key
  signTransaction(privateKey.use());
} finally {
  privateKey.clear(); // Always clear
}
```

**Best Practices**:
- Clear sensitive data after use
- Avoid string copies of keys
- Use Buffer for binary data
- Overwrite before deallocation
- Minimize sensitive data lifetime

---

## Threat Model

### Threat Actors

1. **Remote Attackers**
   - Network eavesdropping
   - MITM attacks
   - Phishing
   - Malware distribution

2. **Malicious Applications**
   - Keyloggers
   - Screen capture
   - Clipboard hijacking
   - Process injection

3. **Physical Attackers**
   - Device theft
   - Shoulder surfing
   - Forensic analysis
   - Evil maid attacks

4. **Supply Chain Attacks**
   - Compromised dependencies
   - Malicious updates
   - Backdoored libraries

### Attack Vectors

#### Network Attacks

**Man-in-the-Middle (MITM)**
- **Threat**: Intercept/modify network traffic
- **Mitigation**: TLS + Certificate pinning

**DNS Spoofing**
- **Threat**: Redirect to malicious servers
- **Mitigation**: Multiple endpoints, validation

**Replay Attacks**
- **Threat**: Reuse captured transactions
- **Mitigation**: Chain-specific signatures (EIP-155)

#### Application Attacks

**Clipboard Hijacking**
- **Threat**: Replace addresses in clipboard
- **Mitigation**: Address validation, QR codes

**Phishing**
- **Threat**: Trick user into revealing mnemonic
- **Mitigation**: User education, warnings

**Transaction Manipulation**
- **Threat**: Modify transaction before signing
- **Mitigation**: Transaction preview, confirmation

#### Device Attacks

**Physical Extraction**
- **Threat**: Extract keys from stolen device
- **Mitigation**: Encryption, secure enclave

**Screen Recording**
- **Threat**: Capture sensitive information
- **Mitigation**: Secure keyboard, anti-screenshot

**Jailbreak/Root**
- **Threat**: Bypass security controls
- **Mitigation**: Detection, warnings

### Mitigations

| Threat | Mitigation | Priority |
|--------|-----------|----------|
| Private key theft | Secure enclave, encryption | Critical |
| MITM attacks | TLS, certificate pinning | Critical |
| Phishing | Address validation, warnings | High |
| Malware | Sandboxing, permissions | High |
| Physical theft | Encryption, biometrics | High |
| Replay attacks | Chain-specific signing | Medium |
| Clipboard hijacking | Address validation | Medium |

---

## Security Best Practices

### For Developers

1. **Secure Coding**
   ```typescript
   // ✓ Good: Use secure random
   const entropy = crypto.randomBytes(32);

   // ✗ Bad: Never use Math.random()
   const bad = Math.random();
   ```

2. **Input Validation**
   ```typescript
   function validateAddress(address: string): boolean {
     // Validate format
     if (!/^0x[a-fA-F0-9]{40}$/.test(address)) {
       throw new ValidationError('Invalid address format');
     }

     // Validate checksum (EIP-55)
     return isValidChecksum(address);
   }
   ```

3. **Error Handling**
   ```typescript
   try {
     await signTransaction(tx);
   } catch (error) {
     // Never log sensitive data
     logger.error('Transaction signing failed', {
       txHash: tx.hash, // OK
       // privateKey: key  // NEVER
     });
     throw error;
   }
   ```

4. **Dependency Security**
   ```bash
   # Regular dependency audits
   npm audit
   npm audit fix

   # Use lock files
   npm ci # Instead of npm install
   ```

### For Users

1. **Mnemonic Backup**
   - Write on paper, never digital
   - Store in secure location
   - Never share with anyone
   - Test recovery process

2. **Transaction Verification**
   - Always verify recipient address
   - Check amounts carefully
   - Verify network (mainnet/testnet)
   - Review transaction fees

3. **Device Security**
   - Use device lock (PIN/biometric)
   - Keep OS updated
   - Avoid jailbreak/root
   - Install from official stores only

4. **Network Security**
   - Use secure WiFi
   - Avoid public networks
   - Use VPN when necessary
   - Verify HTTPS connections

---

## Compliance

### Standards Compliance

- **BIP32/39/44**: Full compliance
- **EIP-155**: Replay protection implemented
- **EIP-55**: Address checksum validation
- **EIP-1559**: Fee market support
- **OWASP Mobile**: Security best practices

### Privacy Considerations

**Data Minimization**:
- No server-side storage of keys
- Minimal metadata collection
- No transaction history logging
- Local-first architecture

**GDPR Compliance** (if applicable):
- User data control
- Right to erasure
- Data portability
- Consent management

---

## Security Testing

### Test Coverage

The project includes comprehensive security tests:

```
tests/security/
├── crypto.test.ts          # Cryptographic operations
├── storage.test.ts         # Secure storage
├── signing.test.ts         # Transaction signing
├── replay.test.ts          # Replay attack prevention
├── biometric.test.ts       # Biometric authentication
├── memory.test.ts          # Memory security
└── penetration.test.ts     # Penetration testing

tests/vectors/
├── bitcoin/
│   ├── bip32.test.ts       # HD wallet derivation
│   ├── bip39.test.ts       # Mnemonic generation
│   ├── bip44.test.ts       # Multi-account hierarchy
│   └── transaction-signing.test.ts
├── ethereum/
│   ├── address-generation.test.ts
│   └── transaction-signing.test.ts
├── tss/
│   └── key-generation.test.ts  # Threshold signatures
└── shamir/
    └── secret-sharing.test.ts   # Secret sharing
```

### Running Security Tests

```bash
# Run all security tests
npm run test tests/security

# Run cryptographic test vectors
npm run test:vectors

# Run specific test suite
npm run test tests/security/crypto.test.ts

# Generate coverage report
npm run test:coverage
```

### Security Audit Checklist

- [ ] All private keys encrypted at rest
- [ ] TLS 1.2+ for all network communication
- [ ] Input validation on all user inputs
- [ ] Address checksum validation
- [ ] Transaction replay protection
- [ ] Rate limiting implemented
- [ ] Secure random number generation
- [ ] Memory cleared after use
- [ ] No secrets in logs
- [ ] Dependency vulnerabilities checked
- [ ] Certificate pinning enabled
- [ ] Biometric authentication supported
- [ ] Auto-lock implemented
- [ ] Recovery process tested
- [ ] Error messages don't leak info

---

## Incident Response

### Security Incident Procedures

1. **Detection**
   - Monitor for anomalies
   - User reports
   - Automated alerts

2. **Assessment**
   - Determine scope
   - Identify affected users
   - Assess impact

3. **Containment**
   - Isolate affected systems
   - Prevent further damage
   - Preserve evidence

4. **Recovery**
   - Patch vulnerabilities
   - Restore services
   - Verify integrity

5. **Communication**
   - Notify affected users
   - Public disclosure (if needed)
   - Security advisory

### Responsible Disclosure

**Security Vulnerabilities**:
- Email: security@fueki.io (example)
- PGP Key: [Public key]
- Response time: 48 hours
- Bounty program: TBD

**Please Do**:
- Report vulnerabilities privately
- Provide detailed reproduction steps
- Allow time for patches
- Act in good faith

**Please Don't**:
- Public disclosure before patch
- Test on production systems
- Access user data
- Perform DoS attacks

---

## Security Updates

This security documentation will be updated as:
- New features are added
- Vulnerabilities are discovered
- Standards are updated
- Best practices evolve

**Last Updated**: 2025-10-22
**Version**: 1.0.0
