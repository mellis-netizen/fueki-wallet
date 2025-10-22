//
//  SecureStorageProtocol.swift
//  FuekiWallet
//
//  Protocol definitions for secure storage operations
//

import Foundation

/// Protocol for secure storage implementations
protocol SecureStorageProtocol {
    /// Save data securely
    func save(_ data: Data, forKey key: String) throws

    /// Load data securely
    func load(forKey key: String) throws -> Data

    /// Delete data securely
    func delete(forKey key: String) throws

    /// Check if key exists
    func exists(forKey key: String) -> Bool

    /// Clear all stored data
    func clearAll() throws
}

/// Protocol for encryption operations
protocol EncryptionProtocol {
    /// Encrypt data
    func encrypt(_ data: Data, withKey key: Data) throws -> Data

    /// Decrypt data
    func decrypt(_ data: Data, withKey key: Data) throws -> Data

    /// Generate encryption key
    func generateKey() throws -> Data

    /// Derive key from password
    func deriveKey(from password: String, salt: Data) throws -> Data
}

/// Protocol for biometric authentication
protocol BiometricAuthProtocol {
    /// Check if biometric authentication is available
    var isAvailable: Bool { get }

    /// Check if biometric is enrolled
    var isEnrolled: Bool { get }

    /// Get biometric type
    var biometricType: BiometricType { get }

    /// Authenticate with biometric
    func authenticate(reason: String) async throws -> Bool
}

/// Protocol for key management
protocol KeyManagementProtocol {
    /// Generate new private key
    func generatePrivateKey() throws -> Data

    /// Derive public key from private key
    func derivePublicKey(from privateKey: Data) throws -> Data

    /// Sign data with private key
    func sign(_ data: Data, with privateKey: Data) throws -> Data

    /// Verify signature
    func verify(_ signature: Data, for data: Data, with publicKey: Data) throws -> Bool
}

/// Protocol for mnemonic operations
protocol MnemonicProtocol {
    /// Generate mnemonic phrase
    func generate(strength: MnemonicStrength) throws -> String

    /// Validate mnemonic phrase
    func validate(_ mnemonic: String) throws -> Bool

    /// Convert mnemonic to seed
    func toSeed(_ mnemonic: String, passphrase: String) throws -> Data
}

/// Protocol for HD wallet operations
protocol HDWalletProtocol {
    /// Derive child key at path
    func deriveKey(at path: String) throws -> Data

    /// Get address at path
    func getAddress(at path: String) throws -> String

    /// Get master key
    var masterKey: Data { get }
}

/// Protocol for backup operations
protocol BackupProtocol {
    /// Create encrypted backup
    func createBackup(password: String) throws -> Data

    /// Restore from encrypted backup
    func restoreBackup(_ data: Data, password: String) throws

    /// Validate backup data
    func validateBackup(_ data: Data) -> Bool
}

// MARK: - Supporting Types

/// Biometric authentication types
enum BiometricType {
    case none
    case touchID
    case faceID

    var description: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        }
    }
}

/// Mnemonic strength options
enum MnemonicStrength: Int {
    case word12 = 128  // 12 words
    case word15 = 160  // 15 words
    case word18 = 192  // 18 words
    case word21 = 224  // 21 words
    case word24 = 256  // 24 words

    var wordCount: Int {
        switch self {
        case .word12: return 12
        case .word15: return 15
        case .word18: return 18
        case .word21: return 21
        case .word24: return 24
        }
    }

    var entropyBits: Int {
        return self.rawValue
    }
}

/// Keychain access level
enum KeychainAccessLevel {
    case whenUnlocked
    case afterFirstUnlock
    case whenPasscodeSet
    case whenUnlockedThisDeviceOnly
    case afterFirstUnlockThisDeviceOnly

    var rawValue: String {
        switch self {
        case .whenUnlocked:
            return String(kSecAttrAccessibleWhenUnlocked)
        case .afterFirstUnlock:
            return String(kSecAttrAccessibleAfterFirstUnlock)
        case .whenPasscodeSet:
            return String(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
        case .whenUnlockedThisDeviceOnly:
            return String(kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
        case .afterFirstUnlockThisDeviceOnly:
            return String(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
        }
    }
}

/// Security configuration
struct SecurityConfiguration {
    /// Use Secure Enclave if available
    let useSecureEnclave: Bool

    /// Require biometric authentication
    let requireBiometric: Bool

    /// Keychain access level
    let keychainAccessLevel: KeychainAccessLevel

    /// Password minimum length
    let passwordMinLength: Int

    /// Maximum authentication attempts
    let maxAuthAttempts: Int

    /// Lockout duration after max attempts (seconds)
    let lockoutDuration: TimeInterval

    /// Enable jailbreak detection
    let enableJailbreakDetection: Bool

    /// Default secure configuration
    static let `default` = SecurityConfiguration(
        useSecureEnclave: true,
        requireBiometric: false,
        keychainAccessLevel: .whenUnlockedThisDeviceOnly,
        passwordMinLength: 8,
        maxAuthAttempts: 5,
        lockoutDuration: 300, // 5 minutes
        enableJailbreakDetection: true
    )
}

/// Wallet metadata
struct WalletMetadata: Codable {
    let id: UUID
    let createdAt: Date
    let version: String
    let hasBiometric: Bool
    let encryptionAlgorithm: String

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         version: String = "1.0.0",
         hasBiometric: Bool = false,
         encryptionAlgorithm: String = "AES-256-GCM") {
        self.id = id
        self.createdAt = createdAt
        self.version = version
        self.hasBiometric = hasBiometric
        self.encryptionAlgorithm = encryptionAlgorithm
    }
}
