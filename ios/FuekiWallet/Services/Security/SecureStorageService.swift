//
//  SecureStorageService.swift
//  FuekiWallet
//
//  Production-grade secure storage using iOS Keychain Services
//  Supports Secure Enclave, biometric protection, and encrypted storage
//

import Foundation
import Security
import LocalAuthentication
import CryptoKit

/// Secure storage errors
public enum SecureStorageError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case authenticationFailed
    case operationFailed(status: OSStatus)
    case encryptionFailed
    case decryptionFailed
    case secureEnclaveNotAvailable
    case accessControlCreationFailed

    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in secure storage"
        case .duplicateItem:
            return "Item already exists in secure storage"
        case .invalidData:
            return "Invalid data format"
        case .authenticationFailed:
            return "Authentication failed"
        case .operationFailed(let status):
            return "Storage operation failed with status: \(status)"
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .secureEnclaveNotAvailable:
            return "Secure Enclave is not available on this device"
        case .accessControlCreationFailed:
            return "Failed to create access control"
        }
    }
}

/// Access control options for keychain items
public struct AccessControlOptions {
    let protection: CFString
    let flags: SecAccessControlCreateFlags

    public static let standard = AccessControlOptions(
        protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags: []
    )

    public static let biometricAny = AccessControlOptions(
        protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags: .biometryAny
    )

    public static let biometricCurrentSet = AccessControlOptions(
        protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags: .biometryCurrentSet
    )

    public static let devicePasscode = AccessControlOptions(
        protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags: .devicePasscode
    )

    public static let secureEnclaveBiometricAny = AccessControlOptions(
        protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags: [.privateKeyUsage, .biometryAny]
    )

    public static let secureEnclaveBiometricCurrentSet = AccessControlOptions(
        protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        flags: [.privateKeyUsage, .biometryCurrentSet]
    )
}

/// Secure storage service using iOS Keychain
public final class SecureStorageService {

    // MARK: - Singleton

    public static let shared = SecureStorageService()

    // MARK: - Properties

    private let serviceName = "com.fueki.wallet"
    private let accessGroup: String? = nil // Can be set for shared keychain access

    // MARK: - Initialization

    private init() {}

    // MARK: - Basic Operations

    /// Save data to keychain
    /// - Parameters:
    ///   - data: Data to save
    ///   - key: Key to store data under
    ///   - accessControl: Access control options
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func save(
        _ data: Data,
        forKey key: String,
        accessControl: AccessControlOptions = .standard
    ) -> Bool {
        // Delete existing item first
        delete(forKey: key)

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data

        // Add access control if specified
        if !accessControl.flags.isEmpty {
            guard let access = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                accessControl.protection,
                accessControl.flags,
                nil
            ) else {
                return false
            }
            query[kSecAttrAccessControl as String] = access
        } else {
            query[kSecAttrAccessible as String] = accessControl.protection
        }

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve data from keychain
    /// - Parameters:
    ///   - key: Key to retrieve data for
    ///   - context: Authentication context (optional)
    /// - Returns: Data if found, nil otherwise
    public func retrieve(
        forKey key: String,
        context: LAContext? = nil
    ) -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        if let context = context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    /// Update existing data in keychain
    /// - Parameters:
    ///   - data: New data
    ///   - key: Key to update
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func update(_ data: Data, forKey key: String) -> Bool {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        return status == errSecSuccess
    }

    /// Delete data from keychain
    /// - Parameter key: Key to delete
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func delete(forKey key: String) -> Bool {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if key exists in keychain
    /// - Parameter key: Key to check
    /// - Returns: True if exists, false otherwise
    public func exists(forKey key: String) -> Bool {
        var query = baseQuery(forKey: key)
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - String Operations

    /// Save string to keychain
    /// - Parameters:
    ///   - string: String to save
    ///   - key: Key to store string under
    ///   - accessControl: Access control options
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func saveString(
        _ string: String,
        forKey key: String,
        accessControl: AccessControlOptions = .standard
    ) -> Bool {
        guard let data = string.data(using: .utf8) else {
            return false
        }
        return save(data, forKey: key, accessControl: accessControl)
    }

    /// Retrieve string from keychain
    /// - Parameters:
    ///   - key: Key to retrieve string for
    ///   - context: Authentication context (optional)
    /// - Returns: String if found, nil otherwise
    public func retrieveString(
        forKey key: String,
        context: LAContext? = nil
    ) -> String? {
        guard let data = retrieve(forKey: key, context: context) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - Codable Operations

    /// Save Codable object to keychain
    /// - Parameters:
    ///   - object: Object to save
    ///   - key: Key to store object under
    ///   - accessControl: Access control options
    /// - Returns: Result with success or error
    public func saveCodable<T: Codable>(
        _ object: T,
        forKey key: String,
        accessControl: AccessControlOptions = .standard
    ) -> Result<Void, SecureStorageError> {
        do {
            let data = try JSONEncoder().encode(object)
            guard save(data, forKey: key, accessControl: accessControl) else {
                return .failure(.operationFailed(status: -1))
            }
            return .success(())
        } catch {
            return .failure(.invalidData)
        }
    }

    /// Retrieve Codable object from keychain
    /// - Parameters:
    ///   - type: Type of object to retrieve
    ///   - key: Key to retrieve object for
    ///   - context: Authentication context (optional)
    /// - Returns: Result with object or error
    public func retrieveCodable<T: Codable>(
        _ type: T.Type,
        forKey key: String,
        context: LAContext? = nil
    ) -> Result<T, SecureStorageError> {
        guard let data = retrieve(forKey: key, context: context) else {
            return .failure(.itemNotFound)
        }

        do {
            let object = try JSONDecoder().decode(type, from: data)
            return .success(object)
        } catch {
            return .failure(.invalidData)
        }
    }

    // MARK: - Secure Enclave Operations

    /// Generate private key in Secure Enclave
    /// - Parameters:
    ///   - tag: Tag to identify the key
    ///   - accessControl: Access control options
    /// - Returns: Result with key reference or error
    public func generateSecureEnclaveKey(
        tag: String,
        accessControl: AccessControlOptions = .secureEnclaveBiometricCurrentSet
    ) -> Result<SecKey, SecureStorageError> {
        // Check if Secure Enclave is available
        guard isSecureEnclaveAvailable else {
            return .failure(.secureEnclaveNotAvailable)
        }

        // Create access control
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            accessControl.protection,
            accessControl.flags,
            nil
        ) else {
            return .failure(.accessControlCreationFailed)
        }

        // Key attributes
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            return .failure(.operationFailed(status: -1))
        }

        return .success(privateKey)
    }

    /// Retrieve private key from Secure Enclave
    /// - Parameters:
    ///   - tag: Tag of the key to retrieve
    ///   - context: Authentication context
    /// - Returns: Result with key reference or error
    public func retrieveSecureEnclaveKey(
        tag: String,
        context: LAContext? = nil
    ) -> Result<SecKey, SecureStorageError> {
        var query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        if let context = context {
            query[kSecUseAuthenticationContext as String] = context
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let key = item as! SecKey? else {
            return .failure(.itemNotFound)
        }

        return .success(key)
    }

    /// Delete private key from Secure Enclave
    /// - Parameter tag: Tag of the key to delete
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func deleteSecureEnclaveKey(tag: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Sign data using Secure Enclave key
    /// - Parameters:
    ///   - data: Data to sign
    ///   - tag: Tag of the private key
    ///   - context: Authentication context
    /// - Returns: Result with signature or error
    public func signWithSecureEnclave(
        data: Data,
        tag: String,
        context: LAContext
    ) -> Result<Data, SecureStorageError> {
        // Retrieve private key
        guard case .success(let privateKey) = retrieveSecureEnclaveKey(tag: tag, context: context) else {
            return .failure(.itemNotFound)
        }

        // Sign data
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            data as CFData,
            &error
        ) as Data? else {
            return .failure(.operationFailed(status: -1))
        }

        return .success(signature)
    }

    // MARK: - Encrypted Storage

    /// Save encrypted data using CryptoKit
    /// - Parameters:
    ///   - data: Data to encrypt and save
    ///   - key: Key to store data under
    ///   - encryptionKey: Symmetric key for encryption
    /// - Returns: Result with success or error
    public func saveEncrypted(
        _ data: Data,
        forKey key: String,
        encryptionKey: SymmetricKey
    ) -> Result<Void, SecureStorageError> {
        do {
            // Encrypt data
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            guard let encryptedData = sealedBox.combined else {
                return .failure(.encryptionFailed)
            }

            // Save encrypted data
            guard save(encryptedData, forKey: key) else {
                return .failure(.operationFailed(status: -1))
            }

            return .success(())
        } catch {
            return .failure(.encryptionFailed)
        }
    }

    /// Retrieve and decrypt data using CryptoKit
    /// - Parameters:
    ///   - key: Key to retrieve data for
    ///   - encryptionKey: Symmetric key for decryption
    /// - Returns: Result with decrypted data or error
    public func retrieveEncrypted(
        forKey key: String,
        encryptionKey: SymmetricKey
    ) -> Result<Data, SecureStorageError> {
        guard let encryptedData = retrieve(forKey: key) else {
            return .failure(.itemNotFound)
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return .success(decryptedData)
        } catch {
            return .failure(.decryptionFailed)
        }
    }

    // MARK: - Utility Methods

    /// Clear all keychain items for this service
    /// - Returns: True if successful, false otherwise
    @discardableResult
    public func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// List all keys in keychain for this service
    /// - Returns: Array of key identifiers
    public func listAllKeys() -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            guard let accountData = item[kSecAttrAccount as String] as? Data,
                  let account = String(data: accountData, encoding: .utf8) else {
                return nil
            }
            return account
        }
    }

    /// Check if Secure Enclave is available
    public var isSecureEnclaveAvailable: Bool {
        return TARGET_OS_SIMULATOR == 0
    }

    // MARK: - Helper Methods

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }
}

// MARK: - Extensions

extension SecureStorageService {

    /// Generate encryption key from password
    /// - Parameters:
    ///   - password: Password to derive key from
    ///   - salt: Salt data
    /// - Returns: Symmetric key
    public func deriveKey(from password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        let hash = SHA256.hash(data: passwordData + salt)
        return SymmetricKey(data: hash)
    }

    /// Generate random salt
    /// - Returns: Random salt data
    public func generateSalt() -> Data {
        var salt = Data(count: 32)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return salt
    }
}
