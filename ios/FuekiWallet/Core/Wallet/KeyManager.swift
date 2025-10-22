//
//  KeyManager.swift
//  FuekiWallet
//
//  Secure key generation and storage with Secure Enclave integration
//

import Foundation
import CryptoKit
import Security

/// Manages cryptographic keys with Secure Enclave support
final class KeyManager: KeyManagementProtocol {

    // MARK: - Properties

    private let keychainManager: KeychainManager
    private let encryptionService: EncryptionService
    private let useSecureEnclave: Bool

    // MARK: - Key Storage Keys

    private enum StorageKey {
        static let masterKey = "wallet.master.key"
        static let privateKeys = "wallet.private.keys"
        static let publicKeys = "wallet.public.keys"
        static let encryptionKey = "wallet.encryption.key"
        static let keyDerivationSalt = "wallet.kdf.salt"
    }

    // MARK: - Initialization

    init(keychainManager: KeychainManager,
         encryptionService: EncryptionService,
         useSecureEnclave: Bool = true) {
        self.keychainManager = keychainManager
        self.encryptionService = encryptionService
        self.useSecureEnclave = useSecureEnclave && isSecureEnclaveAvailable()
    }

    // MARK: - KeyManagementProtocol

    func generatePrivateKey() throws -> Data {
        if useSecureEnclave {
            return try generatePrivateKeyInSecureEnclave()
        } else {
            return try generatePrivateKeyInMemory()
        }
    }

    func derivePublicKey(from privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw WalletError.publicKeyGenerationFailed
        }

        // Use P256 (NIST) curve
        let key = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        return key.publicKey.compressedRepresentation
    }

    func sign(_ data: Data, with privateKey: Data) throws -> Data {
        guard privateKey.count == 32 else {
            throw WalletError.invalidData
        }

        let key = try P256.Signing.PrivateKey(rawRepresentation: privateKey)
        let signature = try key.signature(for: data)
        return signature.rawRepresentation
    }

    func verify(_ signature: Data, for data: Data, with publicKey: Data) throws -> Bool {
        let key = try P256.Signing.PublicKey(compressedRepresentation: publicKey)
        let sig = try P256.Signing.ECDSASignature(rawRepresentation: signature)

        return key.isValidSignature(sig, for: data)
    }

    // MARK: - Secure Enclave Key Generation

    private func generatePrivateKeyInSecureEnclave() throws -> Data {
        // Create access control for Secure Enclave
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            throw WalletError.secureEnclaveKeyGenerationFailed
        }

        // Generate unique tag
        let tag = "wallet.secureenclave.key.\(UUID().uuidString)".data(using: .utf8)!

        // Key attributes
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error = error?.takeRetainedValue() {
                throw WalletError.secureEnclaveOperationFailed(String(describing: error))
            }
            throw WalletError.secureEnclaveKeyGenerationFailed
        }

        // Get key representation
        // Note: Secure Enclave keys cannot be exported, only references are stored
        return tag
    }

    private func generatePrivateKeyInMemory() throws -> Data {
        var keyData = Data(count: 32)
        let result = keyData.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }

        guard result == errSecSuccess else {
            throw WalletError.keyGenerationFailed
        }

        return keyData
    }

    // MARK: - Master Key Management

    /// Generate and store master key
    func generateMasterKey(password: String) throws {
        // Generate encryption key from password
        let salt = try encryptionService.generateSalt()
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: salt)

        // Store salt
        try keychainManager.save(salt, forKey: StorageKey.keyDerivationSalt)

        // Generate master key
        let masterKey = try generatePrivateKey()

        // Encrypt and store master key
        let encryptedMasterKey = try encryptionService.encrypt(masterKey, withKey: encryptionKey)
        try keychainManager.save(encryptedMasterKey, forKey: StorageKey.masterKey)

        // Zero out sensitive data
        var encKeyData = encryptionKey
        var masterKeyData = masterKey
        encKeyData.zeroMemory()
        masterKeyData.zeroMemory()
    }

    /// Retrieve master key
    func getMasterKey(password: String) throws -> Data {
        // Get salt
        let salt = try keychainManager.load(forKey: StorageKey.keyDerivationSalt)

        // Derive encryption key
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: salt)

        // Load and decrypt master key
        let encryptedMasterKey = try keychainManager.load(forKey: StorageKey.masterKey)
        let masterKey = try encryptionService.decrypt(encryptedMasterKey, withKey: encryptionKey)

        // Zero out encryption key
        var encKeyData = encryptionKey
        encKeyData.zeroMemory()

        return masterKey
    }

    /// Delete master key
    func deleteMasterKey() throws {
        try keychainManager.delete(forKey: StorageKey.masterKey)
        try keychainManager.delete(forKey: StorageKey.keyDerivationSalt)
    }

    // MARK: - Private Key Storage

    /// Store private key securely
    func storePrivateKey(_ key: Data, identifier: String, password: String) throws {
        // Derive encryption key
        let salt = try keychainManager.load(forKey: StorageKey.keyDerivationSalt)
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: salt)

        // Encrypt private key
        let encrypted = try encryptionService.encrypt(key, withKey: encryptionKey)

        // Store
        let storageKey = "\(StorageKey.privateKeys).\(identifier)"
        try keychainManager.save(encrypted, forKey: storageKey)

        // Zero out sensitive data
        var encKeyData = encryptionKey
        encKeyData.zeroMemory()
    }

    /// Load private key
    func loadPrivateKey(identifier: String, password: String) throws -> Data {
        // Derive encryption key
        let salt = try keychainManager.load(forKey: StorageKey.keyDerivationSalt)
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: salt)

        // Load and decrypt
        let storageKey = "\(StorageKey.privateKeys).\(identifier)"
        let encrypted = try keychainManager.load(forKey: storageKey)
        let privateKey = try encryptionService.decrypt(encrypted, withKey: encryptionKey)

        // Zero out encryption key
        var encKeyData = encryptionKey
        encKeyData.zeroMemory()

        return privateKey
    }

    /// Delete private key
    func deletePrivateKey(identifier: String) throws {
        let storageKey = "\(StorageKey.privateKeys).\(identifier)"
        try keychainManager.delete(forKey: storageKey)
    }

    // MARK: - Public Key Storage

    /// Store public key
    func storePublicKey(_ key: Data, identifier: String) throws {
        let storageKey = "\(StorageKey.publicKeys).\(identifier)"
        try keychainManager.save(key, forKey: storageKey)
    }

    /// Load public key
    func loadPublicKey(identifier: String) throws -> Data {
        let storageKey = "\(StorageKey.publicKeys).\(identifier)"
        return try keychainManager.load(forKey: storageKey)
    }

    // MARK: - Key Pair Management

    /// Generate and store key pair
    func generateKeyPair(identifier: String, password: String) throws -> KeyPair {
        // Generate private key
        let privateKey = try generatePrivateKey()

        // Derive public key
        let publicKey = try derivePublicKey(from: privateKey)

        // Store keys
        try storePrivateKey(privateKey, identifier: identifier, password: password)
        try storePublicKey(publicKey, identifier: identifier)

        let keyPair = KeyPair(privateKey: privateKey, publicKey: publicKey)

        // Zero out private key
        var privKeyData = privateKey
        privKeyData.zeroMemory()

        return keyPair
    }

    /// Load key pair
    func loadKeyPair(identifier: String, password: String) throws -> KeyPair {
        let privateKey = try loadPrivateKey(identifier: identifier, password: password)
        let publicKey = try loadPublicKey(identifier: identifier)

        return KeyPair(privateKey: privateKey, publicKey: publicKey)
    }

    /// Delete key pair
    func deleteKeyPair(identifier: String) throws {
        try deletePrivateKey(identifier: identifier)
        try keychainManager.delete(forKey: "\(StorageKey.publicKeys).\(identifier)")
    }

    // MARK: - Utility Methods

    private func isSecureEnclaveAvailable() -> Bool {
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        ) else {
            return false
        }

        let tag = "test.secure.enclave".data(using: .utf8)!
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false,
                kSecAttrApplicationTag as String: tag,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let _ = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return false
        }

        return true
    }

    /// List all stored key identifiers
    func listKeyIdentifiers() throws -> [String] {
        let allKeys = try keychainManager.allKeys()

        let prefix = StorageKey.privateKeys + "."
        return allKeys
            .filter { $0.hasPrefix(prefix) }
            .map { String($0.dropFirst(prefix.count)) }
    }
}

// MARK: - Supporting Types

struct KeyPair {
    let privateKey: Data
    let publicKey: Data

    /// Get address from public key
    func address() -> String {
        // Simple hex representation
        return "0x" + publicKey.map { String(format: "%02x", $0) }.joined()
    }
}
