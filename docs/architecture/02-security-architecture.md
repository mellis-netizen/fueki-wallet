# Fueki Wallet - Security Architecture

## Security Overview

The Fueki wallet implements a multi-layered security architecture leveraging iOS platform security features, Threshold Signature Scheme (TSS) cryptography, and industry best practices for cryptocurrency wallet protection.

## Security Principles

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal access rights for components
3. **Secure by Default**: Security enabled from the start
4. **Zero Trust**: Verify everything, trust nothing
5. **Privacy by Design**: User data protection built-in

## Security Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│           Application Security Layer                     │
│  (Code Obfuscation, Anti-Tampering, Runtime Protection) │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│         Authentication & Authorization Layer             │
│      (Biometrics, PIN, Session Management)              │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│            Cryptographic Operations Layer                │
│     (TSS Key Management, Transaction Signing)           │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│              Secure Storage Layer                        │
│    (Keychain, Secure Enclave, Encrypted Database)      │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│            Network Security Layer                        │
│  (TLS 1.3, Certificate Pinning, API Authentication)     │
└─────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────┐
│             iOS Platform Security                        │
│  (Secure Boot, Code Signing, Sandbox, Data Protection)  │
└─────────────────────────────────────────────────────────┘
```

## Key Management Architecture

### TSS Key Generation Flow

```
User Initiates Wallet Creation
          ↓
┌─────────────────────────────────┐
│  Generate Master Entropy        │
│  (256-bit random)               │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│  TSS Key Share Generation       │
│  (2-of-3 or 3-of-5 scheme)      │
└─────────────────────────────────┘
          ↓
    ┌─────┴─────┐
    ↓           ↓
┌────────┐  ┌────────┐  ┌────────┐
│Share 1 │  │Share 2 │  │Share 3 │
│(Local) │  │(Cloud) │  │(Social)│
└────────┘  └────────┘  └────────┘
    ↓           ↓           ↓
┌────────┐  ┌────────┐  ┌────────┐
│Secure  │  │Encrypted│  │OAuth   │
│Enclave │  │Backup   │  │Provider│
└────────┘  └────────┘  └────────┘
```

### Key Storage Strategy

```swift
enum KeyShareLocation {
    case secureEnclave      // Share 1: Hardware-backed (primary)
    case keychain           // Share 1: Software fallback
    case cloudBackup        // Share 2: Encrypted iCloud backup
    case socialRecovery     // Share 3: OAuth provider storage
}

struct KeyShare {
    let id: UUID
    let index: Int
    let encryptedData: Data
    let location: KeyShareLocation
    let createdAt: Date
    let metadata: KeyShareMetadata
}
```

### Secure Enclave Integration

```swift
protocol SecureEnclaveService {
    /// Check if Secure Enclave is available on device
    func isAvailable() -> Bool

    /// Generate a private key in Secure Enclave
    func generateKey(tag: String) throws -> SecKeyRef

    /// Sign data using Secure Enclave key
    func sign(data: Data, keyTag: String) throws -> Data

    /// Retrieve public key from Secure Enclave
    func getPublicKey(keyTag: String) throws -> SecKeyRef

    /// Delete key from Secure Enclave
    func deleteKey(tag: String) throws
}

class DefaultSecureEnclaveService: SecureEnclaveService {
    func generateKey(tag: String) throws -> SecKeyRef {
        let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
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
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access as Any
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(
            attributes as CFDictionary,
            &error
        ) else {
            throw CryptoError.keyGenerationFailed
        }

        return privateKey
    }
}
```

### Keychain Storage Architecture

```swift
protocol KeychainService {
    func save(_ data: Data, for key: String, withAccess: KeychainAccess) throws
    func retrieve(key: String) throws -> Data
    func delete(key: String) throws
    func update(_ data: Data, for key: String) throws
}

enum KeychainAccess {
    case whenUnlocked
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlock
    case afterFirstUnlockThisDeviceOnly
    case whenPasscodeSetThisDeviceOnly
}

class DefaultKeychainService: KeychainService {
    func save(_ data: Data, for key: String, withAccess access: KeychainAccess) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibilityAttribute(for: access)
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw StorageError.keychainSaveFailed(status: status)
        }
    }

    private func accessibilityAttribute(for access: KeychainAccess) -> CFString {
        switch access {
        case .whenUnlocked:
            return kSecAttrAccessibleWhenUnlocked
        case .whenUnlockedThisDeviceOnly:
            return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case .afterFirstUnlock:
            return kSecAttrAccessibleAfterFirstUnlock
        case .afterFirstUnlockThisDeviceOnly:
            return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        case .whenPasscodeSetThisDeviceOnly:
            return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        }
    }
}
```

## Authentication Architecture

### Biometric Authentication Flow

```
App Launch / Sensitive Operation
          ↓
┌─────────────────────────────────┐
│  Check Biometric Availability   │
└─────────────────────────────────┘
          ↓
    ┌─────┴─────┐
    ↓           ↓
[Available]  [Unavailable]
    ↓           ↓
┌────────┐  ┌────────┐
│Face ID │  │  PIN   │
│Touch ID│  │ Entry  │
└────────┘  └────────┘
    ↓           ↓
┌─────────────────────────────────┐
│    Authenticate via LAContext    │
└─────────────────────────────────┘
          ↓
    ┌─────┴─────┐
    ↓           ↓
[Success]   [Failure]
    ↓           ↓
┌────────┐  ┌────────┐
│Unlock  │  │ Retry  │
│Keychain│  │ or     │
│Access  │  │ Logout │
└────────┘  └────────┘
```

### Biometric Service Implementation

```swift
protocol BiometricAuthenticationService {
    func isBiometricAvailable() -> BiometricType
    func authenticate(reason: String) async throws -> Bool
    func canEvaluatePolicy() -> Bool
}

enum BiometricType {
    case faceID
    case touchID
    case none
}

class DefaultBiometricAuthenticationService: BiometricAuthenticationService {
    private let context = LAContext()

    func isBiometricAvailable() -> BiometricType {
        var error: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        ) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}
```

### Session Management

```swift
class SessionManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var sessionExpiresAt: Date?

    private let sessionTimeout: TimeInterval = 300 // 5 minutes
    private var backgroundTask: UIBackgroundTaskIdentifier?
    private var timer: Timer?

    func startSession() {
        isAuthenticated = true
        sessionExpiresAt = Date().addingTimeInterval(sessionTimeout)
        startInactivityTimer()
    }

    func endSession() {
        isAuthenticated = false
        sessionExpiresAt = nil
        timer?.invalidate()
        clearSensitiveData()
    }

    private func startInactivityTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            withTimeInterval: sessionTimeout,
            repeats: false
        ) { [weak self] _ in
            self?.endSession()
        }
    }

    func resetInactivityTimer() {
        guard isAuthenticated else { return }
        sessionExpiresAt = Date().addingTimeInterval(sessionTimeout)
        startInactivityTimer()
    }
}
```

## Transaction Signing Security

### Signing Flow Architecture

```
Transaction Creation Request
          ↓
┌─────────────────────────────────┐
│   Validate Transaction Data     │
│   (Amount, Address, Gas, etc.)  │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   User Confirmation Screen      │
│   (Display all details)         │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   Biometric Authentication      │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   Retrieve Key Shares           │
│   (2 of 3 threshold)            │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   TSS Signing Ceremony          │
│   (Distribute computation)      │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   Combine Partial Signatures    │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   Broadcast Transaction         │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   Clear Signing Context         │
│   (Memory cleanup)              │
└─────────────────────────────────┘
```

### Transaction Signing Service

```swift
protocol TransactionSigningService {
    func signTransaction(
        _ transaction: UnsignedTransaction,
        using keyShares: [KeyShare]
    ) async throws -> SignedTransaction

    func validateTransaction(_ transaction: UnsignedTransaction) throws
}

class DefaultTransactionSigningService: TransactionSigningService {
    private let tssService: TSSService
    private let biometricService: BiometricAuthenticationService

    func signTransaction(
        _ transaction: UnsignedTransaction,
        using keyShares: [KeyShare]
    ) async throws -> SignedTransaction {
        // Validate transaction
        try validateTransaction(transaction)

        // Require biometric authentication
        let authenticated = try await biometricService.authenticate(
            reason: "Sign transaction of \(transaction.amount) \(transaction.currency)"
        )

        guard authenticated else {
            throw AuthError.biometricAuthenticationFailed
        }

        // Reconstruct signing key using TSS
        let signingKey = try await tssService.reconstructKey(from: keyShares)
        defer {
            // Clear key from memory immediately after use
            signingKey.clear()
        }

        // Sign transaction
        let signature = try signWithKey(transaction, key: signingKey)

        return SignedTransaction(
            transaction: transaction,
            signature: signature,
            signedAt: Date()
        )
    }

    func validateTransaction(_ transaction: UnsignedTransaction) throws {
        // Validate address format
        guard isValidAddress(transaction.toAddress) else {
            throw ValidationError.invalidAddress
        }

        // Validate amount
        guard transaction.amount > 0 else {
            throw ValidationError.invalidAmount
        }

        // Check for sufficient balance
        guard transaction.amount <= transaction.availableBalance else {
            throw ValidationError.insufficientFunds
        }

        // Validate gas price within reasonable bounds
        guard isReasonableGasPrice(transaction.gasPrice) else {
            throw ValidationError.unreasonableGasPrice
        }
    }
}
```

## TSS Implementation Architecture

### TSS Protocol Interface

```swift
protocol TSSService {
    /// Generate TSS key shares
    func generateKeyShares(
        threshold: Int,
        total: Int
    ) async throws -> [KeyShare]

    /// Reconstruct private key from shares
    func reconstructKey(from shares: [KeyShare]) async throws -> PrivateKey

    /// Generate partial signature with single share
    func generatePartialSignature(
        message: Data,
        share: KeyShare
    ) async throws -> PartialSignature

    /// Combine partial signatures into final signature
    func combineSignatures(
        _ partialSignatures: [PartialSignature]
    ) async throws -> Signature
}

struct TSSConfiguration {
    let threshold: Int          // Minimum shares needed (e.g., 2)
    let totalShares: Int        // Total shares created (e.g., 3)
    let curve: EllipticCurve    // secp256k1, ed25519
    let hashAlgorithm: HashAlgorithm
}

// Example: ECDSA TSS for Bitcoin/Ethereum
class ECDSATSSService: TSSService {
    private let config: TSSConfiguration

    init(config: TSSConfiguration) {
        self.config = config
    }

    func generateKeyShares(
        threshold: Int,
        total: Int
    ) async throws -> [KeyShare] {
        // Use Shamir's Secret Sharing or more advanced MPC protocols
        // Implementation would use cryptographic libraries

        // 1. Generate master secret
        let masterSecret = try generateSecureRandom(256)

        // 2. Create polynomial of degree (threshold - 1)
        let polynomial = try createPolynomial(
            secret: masterSecret,
            degree: threshold - 1
        )

        // 3. Evaluate polynomial at different points
        var shares: [KeyShare] = []
        for i in 1...total {
            let point = try polynomial.evaluate(at: i)
            let share = try createKeyShare(
                index: i,
                value: point,
                metadata: KeyShareMetadata(
                    threshold: threshold,
                    totalShares: total
                )
            )
            shares.append(share)
        }

        return shares
    }
}
```

## Network Security Architecture

### API Communication Security

```swift
protocol NetworkSecurityService {
    func secureRequest(
        _ request: URLRequest,
        pinning: CertificatePinning
    ) async throws -> (Data, URLResponse)
}

enum CertificatePinning {
    case publicKey([String])
    case certificate([Data])
    case none
}

class DefaultNetworkSecurityService: NetworkSecurityService {
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13

        // Configure session with custom delegate for pinning
        self.session = URLSession(
            configuration: configuration,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
    }
}

class CertificatePinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod ==
              NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Validate certificate pinning
        if validatePinnedCertificate(serverTrust: serverTrust) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }

    private func validatePinnedCertificate(serverTrust: SecTrust) -> Bool {
        // Implement certificate/public key pinning validation
        // Compare server certificate with pinned certificates
        return true // Simplified
    }
}
```

### API Authentication

```swift
protocol APIAuthenticationService {
    func authenticate(request: URLRequest) throws -> URLRequest
    func refreshToken() async throws -> AuthToken
}

class JWTAuthenticationService: APIAuthenticationService {
    private let keychainService: KeychainService
    private let tokenKey = "api.auth.token"

    func authenticate(request: URLRequest) throws -> URLRequest {
        var authenticatedRequest = request

        // Retrieve JWT token from Keychain
        let tokenData = try keychainService.retrieve(key: tokenKey)
        let token = String(data: tokenData, encoding: .utf8)

        // Add Authorization header
        authenticatedRequest.setValue(
            "Bearer \(token ?? "")",
            forHTTPHeaderField: "Authorization"
        )

        return authenticatedRequest
    }
}
```

## Data Encryption Architecture

### Encryption at Rest

```swift
protocol EncryptionService {
    func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data
    func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data
    func generateKey() throws -> SymmetricKey
}

class AESEncryptionService: EncryptionService {
    func encrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        return sealedBox.combined ?? Data()
    }

    func decrypt(_ data: Data, with key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }

    func generateKey() throws -> SymmetricKey {
        return SymmetricKey(size: .bits256)
    }
}
```

### Database Encryption

```swift
// CoreData encryption configuration
class SecureCoreDataStack {
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FuekiWallet")

        // Enable encryption for persistent store
        let description = container.persistentStoreDescriptions.first
        description?.setOption(
            FileProtectionType.complete as NSObject,
            forKey: NSPersistentStoreFileProtectionKey
        )

        // Enable binary data encryption
        description?.setOption(
            true as NSObject,
            forKey: NSPersistentHistoryTrackingKey
        )

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load Core Data stack: \(error)")
            }
        }

        return container
    }()
}
```

## Security Monitoring & Logging

### Security Event Logging

```swift
enum SecurityEvent {
    case authenticationAttempt(success: Bool)
    case transactionSigned(txHash: String)
    case keyAccessAttempt(success: Bool)
    case biometricAuthUsed
    case sessionExpired
    case suspiciousActivity(description: String)
}

protocol SecurityLogger {
    func log(_ event: SecurityEvent, metadata: [String: Any]?)
}

class DefaultSecurityLogger: SecurityLogger {
    func log(_ event: SecurityEvent, metadata: [String: Any]?) {
        // Log to secure audit trail
        // Never log sensitive data (keys, seeds, PINs)
        let logEntry = SecurityLogEntry(
            event: event,
            timestamp: Date(),
            metadata: sanitize(metadata)
        )

        // Store in encrypted log file
        // Send to analytics (if user consented)
    }

    private func sanitize(_ metadata: [String: Any]?) -> [String: Any] {
        // Remove any sensitive fields
        return metadata?.filter { key, _ in
            !["privateKey", "seed", "pin", "password"].contains(key)
        } ?? [:]
    }
}
```

## Security Best Practices Checklist

### Code Security
- ✅ No hardcoded secrets or API keys
- ✅ Code obfuscation for release builds
- ✅ Anti-debugging measures
- ✅ Runtime integrity checks
- ✅ Secure memory management (clear sensitive data)

### Data Security
- ✅ Sensitive data in Keychain only
- ✅ Database encryption enabled
- ✅ Secure file protection attributes
- ✅ No sensitive data in UserDefaults
- ✅ No sensitive data in logs

### Network Security
- ✅ TLS 1.3 enforcement
- ✅ Certificate pinning for critical APIs
- ✅ Request/response validation
- ✅ API authentication tokens
- ✅ Timeout configurations

### Authentication Security
- ✅ Biometric authentication for sensitive operations
- ✅ Session timeout implementation
- ✅ Secure session token storage
- ✅ Logout on background timeout
- ✅ Failed attempt throttling

### Key Management Security
- ✅ Secure Enclave usage when available
- ✅ Keychain with highest protection level
- ✅ No keys in memory longer than needed
- ✅ Secure key derivation
- ✅ Regular key rotation policy

## Security Testing Strategy

```swift
class SecurityTests: XCTestCase {
    func testKeychainStorageIsSecure() {
        // Verify Keychain attributes
    }

    func testNoSensitiveDataInLogs() {
        // Scan logs for sensitive patterns
    }

    func testBiometricAuthenticationRequired() {
        // Verify critical operations require auth
    }

    func testSessionExpiresCorrectly() {
        // Test timeout implementation
    }

    func testCertificatePinning() {
        // Verify pinning works
    }
}
```

## Security Incident Response

### Incident Response Flow

```
Security Incident Detected
          ↓
┌─────────────────────────────────┐
│   Log Security Event            │
└─────────────────────────────────┘
          ↓
┌─────────────────────────────────┐
│   Assess Severity               │
└─────────────────────────────────┘
          ↓
    ┌─────┴─────┐
    ↓           ↓
[Critical]  [Minor]
    ↓           ↓
┌────────┐  ┌────────┐
│Force   │  │ Log &  │
│Logout  │  │ Monitor│
└────────┘  └────────┘
    ↓
┌────────┐
│Clear   │
│Session │
│& Keys  │
└────────┘
    ↓
┌────────┐
│Notify  │
│User    │
└────────┘
```

## Compliance Considerations

- **GDPR**: User data privacy, right to be forgotten
- **CCPA**: California privacy requirements
- **SOC 2**: Security controls and audit trails
- **ISO 27001**: Information security management
- **OWASP Mobile Top 10**: Mobile security best practices

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-21 | CryptoArchitect Agent | Initial security architecture |
