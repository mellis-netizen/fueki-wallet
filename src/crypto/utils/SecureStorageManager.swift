import Foundation
import Security

/// Secure Storage Manager for iOS Keychain
/// Manages secure storage of sensitive data like private keys
public class SecureStorageManager {

    // MARK: - Types

    public enum StorageError: Error {
        case itemNotFound
        case unexpectedData
        case unableToStore
        case unableToUpdate
        case unableToDelete
        case biometricAuthRequired
        case securityError(OSStatus)
    }

    public enum AccessLevel {
        case whenUnlocked // Default - available when device is unlocked
        case afterFirstUnlock // Available after first unlock since boot
        case always // Always available (not recommended for sensitive data)
        case whenUnlockedThisDeviceOnly // When unlocked, not backed up
        case afterFirstUnlockThisDeviceOnly // After first unlock, not backed up
        case alwaysThisDeviceOnly // Always, not backed up
        case whenPasscodeSetThisDeviceOnly // Requires device passcode

        var keychainValue: CFString {
            switch self {
            case .whenUnlocked:
                return kSecAttrAccessibleWhenUnlocked
            case .afterFirstUnlock:
                return kSecAttrAccessibleAfterFirstUnlock
            case .always:
                return kSecAttrAccessibleAlways
            case .whenUnlockedThisDeviceOnly:
                return kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            case .afterFirstUnlockThisDeviceOnly:
                return kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            case .alwaysThisDeviceOnly:
                return kSecAttrAccessibleAlwaysThisDeviceOnly
            case .whenPasscodeSetThisDeviceOnly:
                return kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
            }
        }
    }

    // MARK: - Properties

    private let serviceName: String
    private let accessGroup: String?

    // MARK: - Initialization

    public init(serviceName: String = "com.fueki.wallet", accessGroup: String? = nil) {
        self.serviceName = serviceName
        self.accessGroup = accessGroup
    }

    // MARK: - Storage Operations

    /// Store data securely in keychain
    /// - Parameters:
    ///   - data: Data to store
    ///   - key: Unique key identifier
    ///   - accessLevel: Access level for the data
    ///   - requireBiometric: Whether biometric authentication is required
    public func store(_ data: Data,
                     forKey key: String,
                     accessLevel: AccessLevel = .whenUnlockedThisDeviceOnly,
                     requireBiometric: Bool = false) throws {
        // Check if item already exists
        if (try? retrieve(forKey: key)) != nil {
            // Update existing item
            try update(data, forKey: key)
            return
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessLevel.keychainValue
        ]

        if let group = accessGroup {
            query[kSecAttrAccessGroup as String] = group
        }

        if requireBiometric {
            // Create access control for biometric authentication
            var error: Unmanaged<CFError>?
            guard let accessControl = SecAccessControlCreateWithFlags(
                nil,
                accessLevel.keychainValue,
                .userPresence, // Requires Face ID, Touch ID, or passcode
                &error
            ) else {
                throw StorageError.biometricAuthRequired
            }

            query[kSecAttrAccessControl as String] = accessControl
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw StorageError.securityError(status)
        }
    }

    /// Retrieve data from keychain
    /// - Parameter key: Key identifier
    /// - Returns: Stored data
    public func retrieve(forKey key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            throw status == errSecItemNotFound ? StorageError.itemNotFound : StorageError.securityError(status)
        }

        guard let data = result as? Data else {
            throw StorageError.unexpectedData
        }

        return data
    }

    /// Update existing data in keychain
    /// - Parameters:
    ///   - data: New data
    ///   - key: Key identifier
    private func update(_ data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            throw StorageError.securityError(status)
        }
    }

    /// Delete data from keychain
    /// - Parameter key: Key identifier
    public func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.securityError(status)
        }
    }

    /// Check if key exists in keychain
    /// - Parameter key: Key identifier
    /// - Returns: True if key exists
    public func exists(forKey key: String) -> Bool {
        return (try? retrieve(forKey: key)) != nil
    }

    /// List all stored keys
    /// - Returns: Array of key identifiers
    public func allKeys() throws -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return []
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }

    /// Delete all items for this service
    public func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.securityError(status)
        }
    }

    // MARK: - Secure Enclave Operations

    /// Store private key in Secure Enclave
    /// - Parameters:
    ///   - tag: Unique tag for the key
    ///   - requireBiometric: Whether biometric authentication is required
    /// - Returns: Public key data
    @discardableResult
    public func generateSecureEnclaveKey(tag: String, requireBiometric: Bool = true) throws -> Data {
        guard SecureEnclave.isAvailable else {
            throw StorageError.unableToStore
        }

        // Create access control
        var error: Unmanaged<CFError>?
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            requireBiometric ? [.privateKeyUsage, .userPresence] : .privateKeyUsage,
            &error
        ) else {
            throw StorageError.biometricAuthRequired
        }

        // Key attributes
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
                kSecAttrAccessControl as String: accessControl
            ]
        ]

        var pubKeyError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &pubKeyError) else {
            throw StorageError.unableToStore
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw StorageError.unableToStore
        }

        var exportError: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &exportError) as Data? else {
            throw StorageError.unableToStore
        }

        return publicKeyData
    }

    /// Sign data with Secure Enclave key
    /// - Parameters:
    ///   - data: Data to sign
    ///   - tag: Key tag
    /// - Returns: Signature
    public func signWithSecureEnclaveKey(data: Data, tag: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let privateKey = item else {
            throw StorageError.itemNotFound
        }

        let algorithm: SecKeyAlgorithm = .ecdsaSignatureMessageX962SHA256

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey as! SecKey,
            algorithm,
            data as CFData,
            &error
        ) else {
            throw StorageError.unableToStore
        }

        return signature as Data
    }

    /// Delete Secure Enclave key
    /// - Parameter tag: Key tag
    public func deleteSecureEnclaveKey(tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StorageError.securityError(status)
        }
    }

    // MARK: - Convenience Methods

    /// Store string securely
    public func storeString(_ string: String, forKey key: String, accessLevel: AccessLevel = .whenUnlockedThisDeviceOnly) throws {
        guard let data = string.data(using: .utf8) else {
            throw StorageError.unexpectedData
        }
        try store(data, forKey: key, accessLevel: accessLevel)
    }

    /// Retrieve string
    public func retrieveString(forKey key: String) throws -> String {
        let data = try retrieve(forKey: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw StorageError.unexpectedData
        }
        return string
    }

    /// Store codable object
    public func storeObject<T: Encodable>(_ object: T, forKey key: String, accessLevel: AccessLevel = .whenUnlockedThisDeviceOnly) throws {
        let data = try JSONEncoder().encode(object)
        try store(data, forKey: key, accessLevel: accessLevel)
    }

    /// Retrieve codable object
    public func retrieveObject<T: Decodable>(forKey key: String, as type: T.Type) throws -> T {
        let data = try retrieve(forKey: key)
        return try JSONDecoder().decode(type, from: data)
    }
}
