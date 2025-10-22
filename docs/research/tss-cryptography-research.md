# TSS (Threshold Signature Scheme) Cryptography Research for iOS

## Executive Summary

Threshold Signature Scheme (TSS) enables distributed key generation and signing where multiple parties collectively control a private key without any single party having full access. This is ideal for social sign-on wallet solutions where key shares can be distributed across user devices, cloud services, and recovery mechanisms.

## Production-Ready TSS Libraries for iOS

### 1. **Web3Auth TSS SDK** ⭐ RECOMMENDED
- **Platform**: iOS (Swift), Cross-platform
- **Status**: Production-ready, actively maintained
- **Repository**: https://github.com/Web3Auth/web3auth-swift-sdk
- **Protocol**: MPC (Multi-Party Computation) based TSS
- **OAuth Integration**: ✅ Native support for Google, Apple, Facebook, Twitter, Discord, GitHub
- **License**: MIT

**Key Features**:
- Non-custodial key management with social login
- 2/3 threshold signature scheme (user device + Web3Auth nodes)
- Key reconstruction without full private key exposure
- Built-in OAuth provider integration
- Supports EVM chains, Solana, Bitcoin, etc.
- White-label customizable UI
- Session management and refresh tokens

**Implementation**:
```swift
import Web3Auth

let web3Auth = Web3Auth(
    W3AInitParams(
        clientId: "YOUR_CLIENT_ID",
        network: .mainnet,
        redirectUrl: "your-app://auth"
    )
)

// Login with Google
let result = try await web3Auth.login(
    W3ALoginParams(
        loginProvider: .GOOGLE
    )
)

// Access private key shares
let privateKey = result.privKey // Reconstructed on device
```

**Pricing**: Free tier available, scales with usage
**Documentation**: https://web3auth.io/docs/sdk/ios

---

### 2. **Fireblocks MPC SDK**
- **Platform**: iOS (Native SDK available)
- **Status**: Enterprise-grade, production
- **Protocol**: TSS with GG20 (Gennaro-Goldfeder 2020)
- **OAuth Integration**: Custom implementation required
- **License**: Commercial (requires enterprise agreement)

**Key Features**:
- Military-grade security with SGX enclaves
- 2/2, 2/3, 3/5 threshold configurations
- Hardware security module (HSM) integration
- Policy engine for transaction approval
- Multi-blockchain support (50+ chains)
- Audit trails and compliance tools

**Use Case**: Best for institutional/enterprise wallets
**Pricing**: Enterprise only (contact sales)
**Documentation**: https://developers.fireblocks.com

---

### 3. **Lit Protocol TSS SDK**
- **Platform**: iOS via React Native, JavaScript SDK
- **Status**: Production-ready, decentralized
- **Protocol**: Distributed Key Generation (DKG) with BLS signatures
- **OAuth Integration**: ✅ Via Lit Actions (supports OAuth providers)
- **License**: MIT

**Key Features**:
- Decentralized TSS network (no central authority)
- Programmable key pairs (PKPs) with conditional signing
- Social recovery and multi-factor authentication
- Cross-chain support (Ethereum, Solana, Cosmos)
- Encryption and access control
- On-chain verification

**Implementation**:
```javascript
import * as LitJsSdk from '@lit-protocol/lit-node-client';

const litClient = new LitJsSdk.LitNodeClient({
  litNetwork: 'serrano'
});
await litClient.connect();

// Generate PKP with Google OAuth
const authMethod = await LitJsSdk.authenticateWithGoogle(redirectUri);
const pkp = await litClient.mintPKP(authMethod);
```

**Pricing**: Free for developers, gas costs for minting PKPs
**Documentation**: https://developer.litprotocol.com

---

### 4. **ZenGo TSS Library (Gotham City)**
- **Platform**: Rust library (can be compiled for iOS via FFI)
- **Status**: Production-tested (powers ZenGo wallet)
- **Protocol**: 2P-ECDSA (two-party ECDSA)
- **OAuth Integration**: Manual implementation needed
- **License**: GPL-3.0

**Key Features**:
- Battle-tested in ZenGo production wallet
- 2-party computation (user + server)
- ECDSA signatures for Bitcoin, Ethereum
- Lightweight and efficient
- Threshold-optimal protocol

**Use Case**: For teams comfortable with Rust FFI integration
**Repository**: https://github.com/ZenGo-X/gotham-city
**Documentation**: https://github.com/ZenGo-X/multi-party-ecdsa

---

### 5. **Torus (Web3Auth's predecessor)**
- **Platform**: iOS SDK available
- **Status**: Mature, being superseded by Web3Auth
- **Protocol**: DKG with Shamir Secret Sharing
- **OAuth Integration**: ✅ Native Google, Facebook, Apple
- **License**: MIT

**Note**: Web3Auth is the evolution of Torus with better features. Recommend Web3Auth for new projects.

---

## TSS Protocol Comparison

| Feature | Web3Auth | Fireblocks | Lit Protocol | ZenGo/Gotham |
|---------|----------|------------|--------------|--------------|
| **Threshold** | 2/3, 3/5 | 2/2, 2/3, 3/5 | N/N (flexible) | 2/2 |
| **OAuth Native** | ✅ Yes | ❌ No | ✅ Yes | ❌ No |
| **iOS SDK** | ✅ Native Swift | ✅ Native | ⚠️ React Native | ⚠️ FFI Rust |
| **Decentralized** | Partial | ❌ No | ✅ Yes | ⚠️ 2-party |
| **Cost** | Free/Paid | Enterprise | Free/Gas | Open Source |
| **Setup Time** | 1-2 days | 2-4 weeks | 3-5 days | 1-2 weeks |
| **Production Ready** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |

---

## Key Generation and Signing Protocols

### 1. **Distributed Key Generation (DKG)**
```
Phase 1: Commitment
- Each party generates a random polynomial
- Commits to coefficients using Pedersen commitments

Phase 2: Sharing
- Each party creates secret shares for others
- Shares are encrypted and distributed

Phase 3: Verification
- Parties verify received shares against commitments
- Invalid shares trigger complaint protocol

Result: No single party knows the full private key
```

### 2. **Threshold Signing (TSS)**
```
Phase 1: Signing Request
- Transaction hash is distributed to threshold parties

Phase 2: Partial Signatures
- Each party generates a partial signature using their share

Phase 3: Aggregation
- Partial signatures are combined
- Final signature is mathematically equivalent to single-key signature

Result: Valid signature without reconstructing private key
```

### 3. **Social Sign-On Integration Pattern**

```
User Authentication Flow:
1. User clicks "Sign in with Google"
2. OAuth redirect to Google
3. Google returns ID token
4. ID token sent to TSS coordinator
5. Coordinator initiates DKG with:
   - User device (share 1)
   - TSS server node 1 (share 2)
   - TSS server node 2 (share 3)
6. Private key generated across shares
7. User device stores share in Secure Enclave
8. Future transactions require 2/3 threshold
```

---

## Best Practices for Distributed Key Management

### 1. **Key Share Distribution**
- ✅ Store one share in iOS Secure Enclave (biometric protected)
- ✅ Store one share on TSS infrastructure (encrypted at rest)
- ✅ Store recovery share with encrypted cloud backup (iCloud Keychain)
- ❌ Never store all shares on same device
- ❌ Never transmit shares in plaintext

### 2. **Security Recommendations**
```swift
// iOS Secure Enclave Storage
let access = SecAccessControlCreateWithFlags(
    nil,
    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
    [.privateKeyUsage, .biometryCurrentSet],
    nil
)

let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "com.fueki.tss.keyshare",
        kSecAttrAccessControl as String: access
    ]
]
```

### 3. **Recovery Mechanisms**
- **Social Recovery**: Assign key shares to trusted contacts
- **Time-locked Recovery**: Backup share unlocks after 48 hours
- **Multi-factor**: Require email + SMS verification for recovery
- **Backup Encryption**: Use user password + device TEE key

### 4. **Audit and Monitoring**
- Log all signing requests (not signatures)
- Monitor failed authentication attempts
- Implement rate limiting on signing operations
- Alert on suspicious geographic patterns
- Track key refresh cycles

### 5. **Compliance Considerations**
- GDPR: Ensure user consent for key share storage
- SOC 2: Implement access controls and audit logs
- ISO 27001: Encrypt all key material at rest
- CCPA: Allow user data deletion (key share revocation)

---

## iOS-Specific Implementation Considerations

### 1. **Secure Enclave Integration**
```swift
import CryptoKit
import LocalAuthentication

// Generate key in Secure Enclave
let secureEnclaveKey = try SecureEnclave.P256.Signing.PrivateKey()

// Store TSS share
let tssShare = Data(/* key share from DKG */)
let sealedBox = try AES.GCM.seal(
    tssShare,
    using: secureEnclaveKey.publicKey.compactRepresentation
)

// Save to Keychain
KeychainService.save(sealedBox.combined, for: "tss-share")
```

### 2. **Biometric Authentication**
```swift
let context = LAContext()
context.localizedReason = "Authenticate to sign transaction"

let canEvaluate = context.canEvaluatePolicy(
    .deviceOwnerAuthenticationWithBiometrics,
    error: nil
)

if canEvaluate {
    context.evaluatePolicy(
        .deviceOwnerAuthenticationWithBiometrics,
        localizedReason: "Sign transaction"
    ) { success, error in
        if success {
            // Proceed with TSS signing
        }
    }
}
```

### 3. **Network Security**
- Use Certificate Pinning for TSS coordinator communications
- Implement end-to-end encryption for share transmission
- Use TLS 1.3 minimum
- Validate server certificates

### 4. **Background Processing**
- Handle DKG in background tasks (up to 30 seconds)
- Implement retry logic for network failures
- Cache partial signatures temporarily
- Clean up cryptographic material on app termination

---

## Recommended Solution for Fueki Wallet

### **Primary Recommendation: Web3Auth TSS SDK**

**Rationale**:
1. ✅ Native iOS Swift SDK (no FFI or React Native bridge)
2. ✅ Built-in OAuth integration (Google, Apple, Facebook)
3. ✅ Production-proven (used by major dApps)
4. ✅ Free tier for development and small-scale production
5. ✅ Comprehensive documentation and support
6. ✅ Multi-chain support (Bitcoin, Ethereum, Solana)
7. ✅ White-label customization
8. ✅ Fast integration (1-2 days)

**Secondary Option: Lit Protocol** (for decentralization focus)
- More decentralized but requires React Native or JavaScript bridge
- Better for privacy-focused users
- Higher complexity for iOS integration

**Enterprise Option: Fireblocks** (for institutional clients)
- Best security and compliance
- Expensive and complex
- Overkill for consumer wallet

---

## Integration Roadmap

### Phase 1: Proof of Concept (1 week)
- Integrate Web3Auth SDK
- Implement Google OAuth login
- Test key generation and signing
- Validate Secure Enclave storage

### Phase 2: Multi-Provider Support (1 week)
- Add Apple Sign In
- Add Facebook OAuth
- Add email/passwordless login
- Implement account linking

### Phase 3: Security Hardening (2 weeks)
- Implement biometric authentication
- Add transaction confirmation UI
- Implement rate limiting
- Add security monitoring

### Phase 4: Recovery Mechanisms (1 week)
- Social recovery setup
- Cloud backup encryption
- Recovery flow testing
- Security audit

---

## Security Audit Recommendations

Before production deployment, conduct:
1. **Cryptographic Review**: Verify TSS implementation
2. **Penetration Testing**: Test key extraction attempts
3. **Code Audit**: Review Secure Enclave integration
4. **Compliance Review**: GDPR, CCPA, SOC 2 compliance
5. **Third-party Audit**: Engage firms like Trail of Bits or Cure53

---

## References and Further Reading

1. Web3Auth Documentation: https://web3auth.io/docs
2. TSS ECDSA Research Paper: https://eprint.iacr.org/2019/114.pdf
3. Gennaro-Goldfeder Protocol: https://eprint.iacr.org/2020/540.pdf
4. Apple Secure Enclave: https://support.apple.com/guide/security/secure-enclave-sec59b0b31ff
5. NIST Guidelines on Key Management: https://csrc.nist.gov/publications/detail/sp/800-57-part-1/rev-5/final

---

*Research conducted: October 21, 2025*
*Agent: CryptoResearcher*
*Project: Fueki Mobile Wallet*
