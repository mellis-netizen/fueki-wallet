# Fueki Wallet - Security Implementation

## Security Overview

Fueki Wallet implements multiple layers of security to protect user assets and data:

1. **Secure Storage**: iOS Keychain for sensitive data
2. **Biometric Authentication**: Face ID / Touch ID
3. **Network Security**: Certificate pinning, TLS 1.3
4. **Code Security**: Obfuscation, jailbreak detection
5. **Cryptography**: Industry-standard algorithms
6. **Secure Enclave**: Hardware-backed key storage

## Secure Storage

### iOS Keychain

**Implementation**:

```swift
import Security

class KeychainManager {
    static let shared = KeychainManager()

    private let service = "com.fueki.wallet"

    // MARK: - Store
    func store(_ data: Data, key: String, accessibility: CFString = kSecAttrAccessibleWhenUnlockedThisDeviceOnly) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessibility
        ]

        // Delete existing item first
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }

    // MARK: - Retrieve
    func retrieve(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.retrieveFailed(status)
        }

        return data
    }

    // MARK: - Delete
    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}
```

**Storage Items**:
- Private keys (encrypted)
- Mnemonic phrases (encrypted)
- Biometric authentication tokens
- API authentication tokens
- PIN codes (hashed)

**Accessibility Levels**:
```swift
// After first unlock (default)
kSecAttrAccessibleAfterFirstUnlock

// When unlocked only (recommended)
kSecAttrAccessibleWhenUnlockedThisDeviceOnly

// When passcode set
kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
```

### Secure Enclave

**Private Key Generation**:

```swift
import CryptoKit

class SecureEnclaveManager {
    // Generate private key in Secure Enclave
    func generatePrivateKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        let key = try SecureEnclave.P256.Signing.PrivateKey(
            compactRepresentable: false
        )
        return key
    }

    // Sign data with Secure Enclave key
    func sign(data: Data, with key: SecureEnclave.P256.Signing.PrivateKey) throws -> P256.Signing.ECDSASignature {
        let signature = try key.signature(for: data)
        return signature
    }

    // Store key reference in Keychain
    func storeKeyReference(_ key: SecureEnclave.P256.Signing.PrivateKey, identifier: String) throws {
        let keyData = key.dataRepresentation
        try KeychainManager.shared.store(
            keyData,
            key: identifier,
            accessibility: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        )
    }
}
```

## Biometric Authentication

### Face ID / Touch ID Implementation

**Info.plist**:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Fueki Wallet uses Face ID to securely access your wallet.</string>
```

**Implementation**:

```swift
import LocalAuthentication

class BiometricAuthManager {
    func authenticateUser(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }

        // Perform authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch {
            throw BiometricError.authenticationFailed(error)
        }
    }

    func getBiometricType() -> BiometricType {
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
        default:
            return .none
        }
    }
}

enum BiometricType {
    case faceID
    case touchID
    case none
}
```

**Usage**:

```swift
class WalletViewModel {
    func unlockWallet() async {
        do {
            let authenticated = try await biometricAuth.authenticateUser(
                reason: "Unlock your wallet"
            )

            if authenticated {
                // Proceed with wallet access
                await loadWallet()
            }
        } catch {
            showError("Authentication failed")
        }
    }
}
```

## Cryptography

### Key Generation

**Mnemonic (BIP39)**:

```swift
import Web3Swift
import CryptoSwift

class MnemonicManager {
    // Generate 12 or 24 word mnemonic
    func generateMnemonic(wordCount: Int = 12) throws -> String {
        let entropy = try generateEntropy(bits: wordCount * 11 - wordCount / 3)
        let mnemonic = try Mnemonic.create(entropy: entropy)
        return mnemonic.phrase
    }

    // Derive seed from mnemonic
    func seedFromMnemonic(_ mnemonic: String, passphrase: String = "") throws -> Data {
        let mnemonicObj = try Mnemonic(phrase: mnemonic)
        let seed = try mnemonicObj.seed(passphrase: passphrase)
        return seed
    }

    // Generate entropy
    private func generateEntropy(bits: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: bits / 8)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard result == errSecSuccess else {
            throw CryptoError.randomGenerationFailed
        }

        return Data(bytes)
    }
}
```

**HD Wallet (BIP32/BIP44)**:

```swift
class HDWalletManager {
    // Derive key from path (BIP44)
    // m/44'/60'/0'/0/0 for Ethereum
    func deriveKey(from seed: Data, path: String) throws -> PrivateKey {
        let masterKey = try HDPrivateKey(seed: seed)
        let derivedKey = try masterKey.derived(at: path)
        return derivedKey.privateKey
    }

    // Get Ethereum address from private key
    func getAddress(from privateKey: PrivateKey) throws -> String {
        let publicKey = privateKey.publicKey
        let address = publicKey.address.hex(eip55: true)
        return address
    }
}
```

### Encryption

**AES-256-GCM**:

```swift
import CryptoKit

class EncryptionManager {
    // Encrypt data
    func encrypt(data: Data, password: String) throws -> EncryptedData {
        // Derive key from password
        let salt = Data(randomBytes: 32)
        let key = try deriveKey(from: password, salt: salt)

        // Encrypt with AES-GCM
        let sealedBox = try AES.GCM.seal(
            data,
            using: key
        )

        return EncryptedData(
            ciphertext: sealedBox.ciphertext,
            nonce: sealedBox.nonce,
            tag: sealedBox.tag,
            salt: salt
        )
    }

    // Decrypt data
    func decrypt(encryptedData: EncryptedData, password: String) throws -> Data {
        // Derive key from password and salt
        let key = try deriveKey(from: password, salt: encryptedData.salt)

        // Create sealed box
        let sealedBox = try AES.GCM.SealedBox(
            nonce: encryptedData.nonce,
            ciphertext: encryptedData.ciphertext,
            tag: encryptedData.tag
        )

        // Decrypt
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        return decrypted
    }

    // Derive key from password using PBKDF2
    private func deriveKey(from password: String, salt: Data) throws -> SymmetricKey {
        guard let passwordData = password.data(using: .utf8) else {
            throw CryptoError.invalidPassword
        }

        let key = try PBKDF2.deriveKey(
            from: passwordData,
            salt: salt,
            iterations: 100000,
            keyLength: 32
        )

        return SymmetricKey(data: key)
    }
}

struct EncryptedData {
    let ciphertext: Data
    let nonce: AES.GCM.Nonce
    let tag: Data
    let salt: Data
}
```

## Network Security

### Certificate Pinning

**Implementation**:

```swift
class CertificatePinner: NSObject, URLSessionDelegate {
    private let pinnedCertificates: [Data]

    init(certificateNames: [String]) {
        self.pinnedCertificates = certificateNames.compactMap { name in
            guard let path = Bundle.main.path(forResource: name, ofType: "cer"),
                  let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                return nil
            }
            return data
        }
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        // Get server certificate
        guard let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let serverCertificateData = SecCertificateCopyData(serverCertificate) as Data

        // Check if server certificate matches pinned certificate
        if pinnedCertificates.contains(serverCertificateData) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
        } else {
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}
```

### TLS Configuration

```swift
class NetworkManager {
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13

        return URLSession(
            configuration: configuration,
            delegate: certificatePinner,
            delegateQueue: nil
        )
    }()
}
```

## Code Security

### Jailbreak Detection

```swift
class JailbreakDetector {
    static func isJailbroken() -> Bool {
        // Check for jailbreak files
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

        // Check if app can write outside sandbox
        let testPath = "/private/test.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Cannot write, likely not jailbroken
        }

        // Check for Cydia URL scheme
        if let url = URL(string: "cydia://package/com.example.package"),
           UIApplication.shared.canOpenURL(url) {
            return true
        }

        return false
    }
}
```

### Code Obfuscation

**String Obfuscation**:

```swift
class StringObfuscator {
    static func obfuscate(_ string: String) -> String {
        let bytes = string.utf8.map { $0 ^ 0x42 }
        return Data(bytes).base64EncodedString()
    }

    static func deobfuscate(_ obfuscated: String) -> String? {
        guard let data = Data(base64Encoded: obfuscated) else {
            return nil
        }

        let bytes = data.map { $0 ^ 0x42 }
        return String(bytes: bytes, encoding: .utf8)
    }
}

// Usage
let apiKey = StringObfuscator.deobfuscate("encoded_key")
```

### Runtime Protection

```swift
class RuntimeProtection {
    // Detect debugger
    static func isDebuggerAttached() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]

        sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)

        return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    // Prevent screenshot
    static func preventScreenCapture(for view: UIView) {
        let field = UITextField()
        field.isSecureTextEntry = true
        view.addSubview(field)
        view.layer.superlayer?.addSublayer(field.layer)
        field.layer.sublayers?.first?.addSublayer(view.layer)
    }
}
```

## Data Protection

### Sensitive Data Handling

```swift
class SensitiveDataHandler {
    // Clear sensitive data from memory
    func clearSensitiveData(_ data: inout Data) {
        data.withUnsafeMutableBytes { bytes in
            memset(bytes.baseAddress, 0, bytes.count)
        }
    }

    // Secure string handling
    func secureString(_ string: inout String) {
        string = String(repeating: "0", count: string.count)
        string = ""
    }

    // Auto-lock timer
    func setupAutoLock(timeout: TimeInterval) {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleAutoLock(after: timeout)
        }
    }
}
```

### Screen Security

```swift
// Blur sensitive content in background
class ScreenSecurityManager {
    private var blurView: UIVisualEffectView?

    func setupScreenSecurity() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func applicationWillResignActive() {
        guard let window = UIApplication.shared.windows.first else { return }

        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = window.bounds
        blurView.tag = 999
        window.addSubview(blurView)

        self.blurView = blurView
    }

    @objc private func applicationDidBecomeActive() {
        blurView?.removeFromSuperview()
        blurView = nil
    }
}
```

## Security Checklist

### Development
- [ ] Enable App Transport Security (ATS)
- [ ] Implement certificate pinning
- [ ] Use Keychain for sensitive data
- [ ] Enable biometric authentication
- [ ] Implement jailbreak detection
- [ ] Obfuscate sensitive strings
- [ ] Clear sensitive data from memory
- [ ] Prevent screenshots of sensitive screens
- [ ] Implement auto-lock timer
- [ ] Use Secure Enclave for keys

### Testing
- [ ] Penetration testing
- [ ] Security audit
- [ ] Static code analysis
- [ ] Dynamic analysis
- [ ] Dependency vulnerability scan
- [ ] API security testing
- [ ] Cryptography review

### Deployment
- [ ] Code signing enabled
- [ ] Bitcode enabled
- [ ] Debug symbols stripped
- [ ] Logging disabled in production
- [ ] API keys secured
- [ ] Crash reporting configured
- [ ] Security monitoring enabled

## Security Best Practices

1. **Never hardcode secrets** in source code
2. **Validate all inputs** from users and APIs
3. **Use HTTPS** for all network communication
4. **Encrypt sensitive data** at rest and in transit
5. **Implement proper authentication** for all operations
6. **Follow principle of least privilege**
7. **Keep dependencies updated**
8. **Regular security audits**
9. **Incident response plan**
10. **User education** on security practices

## Security Incident Response

### Detection
- Monitor crash reports
- Track suspicious activities
- User reports

### Response
1. Assess severity
2. Contain the issue
3. Investigate root cause
4. Implement fix
5. Deploy update
6. Notify affected users
7. Document incident

## Compliance

- **GDPR**: Data protection and privacy
- **CCPA**: California privacy rights
- **OWASP Mobile Top 10**: Security best practices
- **Apple Security Guidelines**: Platform requirements

---

For API security documentation, see [API_INTEGRATION.md](API_INTEGRATION.md).
