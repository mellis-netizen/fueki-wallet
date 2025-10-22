# TSS (Threshold Signature Scheme) Security Requirements

**Document Version:** 1.0.0
**Last Updated:** 2025-10-21
**Classification:** CRITICAL SECURITY

---

## 1. Overview

Threshold Signature Schemes (TSS) are the cryptographic foundation of Fueki Mobile Wallet. This document defines the security requirements, implementation guidelines, and audit procedures specific to TSS implementation.

---

## 2. TSS Architecture Requirements

### 2.1 Threshold Configuration

**Required Parameters:**
```swift
struct TSSConfiguration {
    let threshold: Int       // Minimum shares required (t)
    let totalShares: Int     // Total shares created (n)
    let curve: EllipticCurve // secp256k1 or Ed25519

    // Security constraint: threshold < totalShares
    // Recommended: threshold = ceil(totalShares * 0.67)
    // Example: 2-of-3, 3-of-5, 5-of-7
}
```

**Security Requirements:**
- [ ] `threshold >= 2` (minimum for security)
- [ ] `threshold <= totalShares - 1` (at least one share redundancy)
- [ ] `totalShares <= 10` (practical upper limit for mobile)
- [ ] Configuration immutable after creation

### 2.2 Key Generation Protocol

**Phase 1: Distributed Key Generation (DKG)**

```swift
protocol DKGProtocol {
    /// Generate polynomial coefficients
    /// SECURITY: Must use cryptographically secure RNG
    func generateCoefficients() throws -> [BigInt]

    /// Create commitments for verifiable secret sharing
    /// SECURITY: Use Pedersen or Feldman commitments
    func createCommitments() throws -> [Point]

    /// Verify commitments from other participants
    /// SECURITY: All commitments must be verified before proceeding
    func verifyCommitments(_ commitments: [Point]) throws -> Bool

    /// Generate key share
    /// SECURITY: Share must never be transmitted in plaintext
    func generateKeyShare() throws -> KeyShare
}
```

**Security Checklist:**

- [ ] **Randomness Source**
  ```swift
  // ✅ REQUIRED: Use iOS SecRandomCopyBytes
  var randomBytes = [UInt8](repeating: 0, count: 32)
  let status = SecRandomCopyBytes(kSecRandomDefault, 32, &randomBytes)
  guard status == errSecSuccess else {
      throw CryptoError.randomGenerationFailed
  }
  ```
  - No use of `arc4random()` for cryptographic operations
  - No predictable seeds (timestamp, sequential IDs)
  - Minimum 256 bits of entropy per key share

- [ ] **Verifiable Secret Sharing (VSS)**
  - Feldman or Pedersen VSS implemented
  - All participants verify commitments before accepting shares
  - Abort protocol if verification fails
  - Zero-knowledge proofs for private verification

- [ ] **Participant Authentication**
  - Mutual authentication between all participants
  - Secure channel establishment (TLS 1.3+)
  - Anti-replay mechanisms (nonce-based)
  - Participant revocation support

### 2.3 Key Share Storage

**Secure Enclave Integration:**

```swift
class KeyShareStorage {
    /// Store key share in Secure Enclave (if available)
    func storeKeyShare(_ share: KeyShare) throws {
        // Check Secure Enclave availability
        guard SecureEnclave.isAvailable else {
            throw StorageError.secureEnclaveUnavailable
        }

        // Create access control
        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        )

        // Store in Secure Enclave
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: "com.fueki.wallet.keyshare",
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrAccessControl as String: access!
            ]
        ]

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError.keychainWriteFailed(status)
        }
    }
}
```

**Storage Security Requirements:**

- [ ] **Secure Enclave (Preferred)**
  - Use Secure Enclave on A7+ devices
  - Hardware-backed key storage
  - Biometric-protected access
  - Key never leaves Secure Enclave

- [ ] **Keychain (Fallback)**
  - `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  - `kSecAttrSynchronizable: false` (never sync to iCloud)
  - Access control with biometrics or device passcode
  - Encryption using device UID + passcode

- [ ] **Prohibited Storage Locations**
  - ❌ UserDefaults
  - ❌ Core Data (unencrypted)
  - ❌ File system (even encrypted)
  - ❌ In-memory beyond active use
  - ❌ Clipboard
  - ❌ Logs or crash reports

- [ ] **Memory Management**
  ```swift
  // ✅ REQUIRED: Zero out sensitive data
  defer {
      privateKey.resetBytes(in: 0..<privateKey.count)
  }
  ```

---

## 3. Signature Generation Security

### 3.1 Signing Protocol

**Multi-Party Signing Ceremony:**

```swift
protocol TSSSigningProtocol {
    /// Step 1: Generate ephemeral key pairs (r_i)
    /// SECURITY: Fresh randomness required for each signature
    func generateEphemeralKeys() throws -> (private: BigInt, public: Point)

    /// Step 2: Compute partial signatures
    /// SECURITY: Must use constant-time operations
    func computePartialSignature(
        message: Data,
        ephemeralPrivate: BigInt,
        keyShare: KeyShare
    ) throws -> PartialSignature

    /// Step 3: Aggregate partial signatures
    /// SECURITY: Verify all partial signatures before aggregation
    func aggregateSignatures(
        _ partialSignatures: [PartialSignature]
    ) throws -> Signature

    /// Step 4: Verify final signature
    /// SECURITY: Always verify before broadcasting
    func verifySignature(
        _ signature: Signature,
        message: Data,
        publicKey: Point
    ) throws -> Bool
}
```

**Security Requirements:**

- [ ] **Nonce Generation**
  ```swift
  // ✅ REQUIRED: Deterministic nonce (RFC 6979)
  func generateNonce(privateKey: BigInt, message: Data) -> BigInt {
      // Use HMAC-based deterministic nonce generation
      // NEVER reuse nonces - leads to private key recovery!
      let hmac = HMAC<SHA256>.authenticationCode(
          for: message,
          using: SymmetricKey(data: privateKey.serialize())
      )
      return BigInt(Data(hmac)) % curve.order
  }
  ```
  - Deterministic nonce generation (RFC 6979) or
  - Secure random nonce with anti-reuse checks
  - Nonce verification across all participants
  - Nonce never reused (catastrophic failure)

- [ ] **Side-Channel Protection**
  ```swift
  // ✅ REQUIRED: Constant-time comparison
  func constantTimeCompare(_ a: Data, _ b: Data) -> Bool {
      guard a.count == b.count else { return false }

      var result = 0
      for i in 0..<a.count {
          result |= Int(a[i] ^ b[i])
      }
      return result == 0
  }
  ```
  - Constant-time operations for secret-dependent operations
  - No branching on secret data
  - Timing attack mitigations
  - Power analysis resistance (hardware-level)

- [ ] **Partial Signature Verification**
  - Each partial signature verified before aggregation
  - Invalid partial signatures rejected
  - Threshold check enforced (t signatures minimum)
  - Signature malleability prevented

### 3.2 Signature Verification

**Verification Requirements:**

```swift
func verifySignature(
    signature: Signature,
    message: Data,
    publicKey: Point
) throws -> Bool {
    // 1. Validate signature components
    guard signature.r > 0 && signature.r < curve.order else {
        throw VerificationError.invalidR
    }
    guard signature.s > 0 && signature.s < curve.order else {
        throw VerificationError.invalidS
    }

    // 2. Verify signature equation
    // For ECDSA: Verify that R = (s^-1 * H(m) * G) + (s^-1 * r * Q)
    let sInv = signature.s.modInverse(curve.order)
    let u1 = (messageHash(message) * sInv) % curve.order
    let u2 = (signature.r * sInv) % curve.order

    let point = (curve.generator * u1) + (publicKey * u2)

    // 3. Check result
    return point.x % curve.order == signature.r
}
```

**Checklist:**
- [ ] Signature components validated (r, s in valid range)
- [ ] Message hash computed correctly
- [ ] Verification equation checked
- [ ] Low-S malleability protection (enforce s < order/2)
- [ ] No signature reuse allowed across different messages

---

## 4. Security Threat Model

### 4.1 Adversary Capabilities

| Threat Actor | Capabilities | Mitigation |
|--------------|-------------|------------|
| **Malicious Participant** | Control < threshold shares | VSS verification, zero-knowledge proofs |
| **Network Attacker** | MitM, replay attacks | TLS 1.3, nonce-based authentication |
| **Device Compromise** | Physical access to device | Secure Enclave, biometric protection |
| **Malware** | Memory inspection, keylogging | Memory wiping, code obfuscation |
| **Side-Channel Attacker** | Timing, power analysis | Constant-time implementations |

### 4.2 Attack Scenarios

**Scenario 1: Nonce Reuse Attack**

```
Attack: Attacker obtains two signatures with same nonce
Impact: CRITICAL - Private key recovery possible
Mitigation:
  - Use deterministic nonce (RFC 6979)
  - Implement nonce tracking/verification
  - Multi-party nonce generation
```

**Scenario 2: Share Extraction**

```
Attack: Attacker extracts t shares from compromised devices
Impact: CRITICAL - Complete wallet compromise
Mitigation:
  - Secure Enclave storage
  - Biometric protection
  - Share rotation mechanism
  - Multi-device distribution
```

**Scenario 3: Signature Malleability**

```
Attack: Attacker modifies signature (s → -s mod n)
Impact: HIGH - Transaction replay, double-spend
Mitigation:
  - Low-S enforcement (s < order/2)
  - Canonical signature validation
  - Transaction ID based on signed data
```

**Scenario 4: Timing Side-Channel**

```
Attack: Measure signature generation time to infer key bits
Impact: MEDIUM - Partial key recovery over time
Mitigation:
  - Constant-time operations
  - Blinding techniques
  - Random delays (with caution)
```

---

## 5. Implementation Guidelines

### 5.1 Recommended Libraries

**Option 1: Custom TSS Implementation**
- ✅ Full control over security
- ✅ iOS-optimized
- ❌ Requires expert review
- ❌ Higher development risk

**Option 2: Established Libraries**
- [tss-lib](https://github.com/bnb-chain/tss-lib) - Binance TSS
- [multi-party-ecdsa](https://github.com/ZenGo-X/multi-party-ecdsa) - ZenGo MPC
- ⚠️ Audit required before use
- ⚠️ Mobile compatibility verification needed

**Security Requirements for Libraries:**
- [ ] Open source with active maintenance
- [ ] Security audit completed (by reputable firm)
- [ ] No known CVEs
- [ ] Compatible license (MIT, Apache 2.0)
- [ ] iOS compatibility verified

### 5.2 Code Review Checklist

**Before TSS Implementation:**
- [ ] Threat model documented
- [ ] Security requirements defined
- [ ] Cryptographic primitives selected
- [ ] Key management design reviewed

**During Implementation:**
- [ ] Peer review of cryptographic code
- [ ] Unit tests for all edge cases
- [ ] Fuzz testing for input validation
- [ ] Static analysis (SwiftLint, Infer)

**After Implementation:**
- [ ] External security audit
- [ ] Penetration testing
- [ ] Code signing verification
- [ ] Documentation review

---

## 6. Testing Requirements

### 6.1 Unit Tests

```swift
class TSSSecurityTests: XCTestCase {

    // Test 1: Randomness quality
    func testRandomnessUniqueness() {
        let shares = (0..<1000).map { _ in
            try! TSSKeyGenerator.generateKeyShare()
        }
        // Verify no duplicate shares
        let uniqueShares = Set(shares.map { $0.value })
        XCTAssertEqual(shares.count, uniqueShares.count)
    }

    // Test 2: Threshold enforcement
    func testThresholdEnforcement() {
        let config = TSSConfiguration(threshold: 3, totalShares: 5)

        // Should succeed with 3 shares
        XCTAssertNoThrow(
            try TSSSigner.sign(message: testData, shares: Array(shares[0..<3]))
        )

        // Should fail with 2 shares
        XCTAssertThrowsError(
            try TSSSigner.sign(message: testData, shares: Array(shares[0..<2]))
        )
    }

    // Test 3: Nonce uniqueness
    func testNonceUniqueness() {
        var nonces = Set<BigInt>()
        for _ in 0..<1000 {
            let nonce = try! TSSSigner.generateNonce()
            XCTAssertFalse(nonces.contains(nonce))
            nonces.insert(nonce)
        }
    }

    // Test 4: Signature verification
    func testSignatureVerification() {
        let (signature, message, publicKey) = createTestSignature()

        // Valid signature should verify
        XCTAssertTrue(
            try TSS.verifySignature(signature, message, publicKey)
        )

        // Modified signature should fail
        var invalidSig = signature
        invalidSig.s += 1
        XCTAssertFalse(
            try TSS.verifySignature(invalidSig, message, publicKey)
        )
    }

    // Test 5: Memory wiping
    func testMemoryWiping() {
        var sensitiveData = Data(repeating: 0xFF, count: 32)
        let pointer = sensitiveData.withUnsafeMutableBytes { $0.baseAddress! }

        // Use data
        _ = try! TSS.signWithShare(sensitiveData)

        // Verify data is wiped
        let afterData = Data(bytes: pointer, count: 32)
        XCTAssertEqual(afterData, Data(repeating: 0, count: 32))
    }
}
```

### 6.2 Integration Tests

```swift
class TSSIntegrationTests: XCTestCase {

    // Test full signing ceremony
    func testFullSigningCeremony() {
        // Setup: Create 3-of-5 TSS configuration
        let participants = (0..<5).map { ParticipantMock(id: $0) }

        // Phase 1: Distributed key generation
        let keyShares = try! TSSCoordinator.performDKG(participants)
        XCTAssertEqual(keyShares.count, 5)

        // Phase 2: Sign message with threshold participants
        let signingParticipants = Array(participants[0..<3])
        let message = "Test transaction".data(using: .utf8)!
        let signature = try! TSSCoordinator.signMessage(
            message,
            participants: signingParticipants
        )

        // Phase 3: Verify signature
        XCTAssertTrue(
            try TSS.verifySignature(signature, message, keyShares.publicKey)
        )
    }

    // Test byzantine fault tolerance
    func testByzantineFaultTolerance() {
        // Create malicious participant
        let malicious = MaliciousParticipant()
        let honest = (0..<4).map { ParticipantMock(id: $0) }

        let participants = honest + [malicious]

        // Should detect and reject malicious behavior
        XCTAssertThrowsError(
            try TSSCoordinator.performDKG(participants)
        ) { error in
            XCTAssertTrue(error is TSSError.maliciousParticipant)
        }
    }
}
```

### 6.3 Security Tests

```swift
class TSSSecurityValidationTests: XCTestCase {

    // Test against known attack vectors
    func testNonceReuseDetection() {
        let nonce = try! TSSSigner.generateNonce()

        // First signature should succeed
        XCTAssertNoThrow(
            try TSSSigner.signWithNonce(message1, nonce: nonce)
        )

        // Attempt to reuse nonce should fail
        XCTAssertThrowsError(
            try TSSSigner.signWithNonce(message2, nonce: nonce)
        ) { error in
            XCTAssertTrue(error is TSSError.nonceReuse)
        }
    }

    // Test signature malleability protection
    func testSignatureMalleability() {
        let (signature, message, publicKey) = createTestSignature()

        // Original signature should verify
        XCTAssertTrue(try TSS.verify(signature, message, publicKey))

        // Malleable signature (s → -s mod n) should be rejected
        var malleable = signature
        malleable.s = curve.order - signature.s
        XCTAssertFalse(try TSS.verify(malleable, message, publicKey))
    }
}
```

---

## 7. Audit Procedures

### 7.1 Pre-Implementation Audit

**Checklist:**
- [ ] Threat model reviewed and approved
- [ ] Cryptographic design peer-reviewed
- [ ] Library selection justified
- [ ] Key management design validated
- [ ] Testing strategy defined

### 7.2 Implementation Audit

**Code Review Focus:**
- [ ] Randomness generation (use of SecRandomCopyBytes)
- [ ] Key share storage (Secure Enclave integration)
- [ ] Nonce generation (RFC 6979 compliance)
- [ ] Constant-time operations (no timing leaks)
- [ ] Memory management (sensitive data wiping)
- [ ] Error handling (no information leakage)

**Automated Tools:**
```bash
# Static analysis
swiftlint lint --config security-rules.yml

# Cryptographic validation
# (Custom tool to check for weak crypto usage)
./scripts/crypto-audit.sh

# Dependency check
dependency-check --project Fueki-TSS --scan ./
```

### 7.3 Post-Implementation Audit

**Penetration Testing:**
- [ ] Nonce reuse attack attempted
- [ ] Share extraction from memory attempted
- [ ] Timing side-channel analysis
- [ ] Malicious participant simulation
- [ ] Network MitM attacks

**Compliance Verification:**
- [ ] NIST cryptographic standards compliance
- [ ] OWASP Mobile Security guidelines
- [ ] iOS security best practices
- [ ] Industry-specific regulations (financial services)

---

## 8. Incident Response

### 8.1 Key Compromise Scenarios

**Scenario: Single Share Compromised**
```
Impact: LOW (< threshold)
Response:
  1. Revoke compromised share
  2. Generate new share for affected user
  3. Monitor for suspicious activity
  4. Document incident
```

**Scenario: Threshold Shares Compromised**
```
Impact: CRITICAL (wallet compromise)
Response:
  1. IMMEDIATELY halt all transactions
  2. Notify all users
  3. Initiate emergency key rotation
  4. Forensic investigation
  5. User fund migration to new keys
```

### 8.2 Vulnerability Disclosure

**Process:**
1. Security issue reported to security@fueki.io
2. Acknowledgment within 24 hours
3. Severity assessment within 48 hours
4. Patch development (timeline based on severity)
5. Coordinated disclosure after patch deployment
6. Post-mortem and lessons learned

---

## 9. Compliance & Standards

### 9.1 Cryptographic Standards

**NIST Requirements:**
- [ ] FIPS 186-4 (Digital Signature Standard)
- [ ] SP 800-90A (Random Number Generation)
- [ ] SP 800-56A (Key Establishment)
- [ ] SP 800-57 (Key Management)

### 9.2 Industry Best Practices

- [ ] OWASP Cryptographic Storage Cheat Sheet
- [ ] IETF RFC 6979 (Deterministic ECDSA)
- [ ] Bitcoin BIP-32/39/44 (if applicable)
- [ ] Ethereum EIP-2333 (if applicable)

---

## 10. Documentation Requirements

### 10.1 Required Documentation

- [ ] TSS protocol specification
- [ ] Key generation ceremony documentation
- [ ] Signing ceremony documentation
- [ ] Security assumptions and threat model
- [ ] Cryptographic library justification
- [ ] Audit trail for key operations

### 10.2 Code Documentation

```swift
/// Generates a TSS key share using verifiable secret sharing
///
/// - Security:
///   - Uses SecRandomCopyBytes for cryptographic randomness
///   - Implements Feldman VSS for verifiability
///   - Key share stored in Secure Enclave when available
///   - Sensitive memory zeroed after use
///
/// - Throws:
///   - `TSSError.randomGenerationFailed` if RNG fails
///   - `TSSError.vssVerificationFailed` if commitment invalid
///   - `StorageError.secureEnclaveUnavailable` if SE unavailable
///
/// - Returns: Encrypted key share with verification commitment
func generateKeyShare() throws -> KeyShare {
    // Implementation...
}
```

---

## 11. Continuous Security

### 11.1 Regular Reviews

**Schedule:**
- Weekly: Automated security scans
- Monthly: Manual code review of crypto code
- Quarterly: External security audit
- Annually: Comprehensive penetration testing

### 11.2 Security Metrics

**Key Performance Indicators:**
- Time to detect key compromise
- Time to respond to vulnerabilities
- Number of security issues in code review
- Test coverage of cryptographic code (target: 100%)
- Rate of false positives in security tools

---

## 12. References

- [NIST FIPS 186-4 - Digital Signature Standard](https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.186-4.pdf)
- [RFC 6979 - Deterministic ECDSA](https://tools.ietf.org/html/rfc6979)
- [Threshold Signatures Explained](https://eprint.iacr.org/2019/114.pdf)
- [iOS Security Guide](https://support.apple.com/guide/security/)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)

---

**Document Owner:** Security Auditor Agent
**Review Cycle:** Quarterly
**Next Review:** 2026-01-21
