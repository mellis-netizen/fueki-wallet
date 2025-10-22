//
//  KeychainManager.swift
//  FuekiWallet
//
//  iOS Keychain wrapper for secure storage with Secure Enclave support
//

import Foundation
import Security

/// Manages secure storage using iOS Keychain with Secure Enclave integration
final class KeychainManager: SecureStorageProtocol {

    // MARK: - Properties

    private let service: String
    private let accessGroup: String?
    private let accessLevel: KeychainAccessLevel

    // MARK: - Initialization

    init(service: String = Bundle.main.bundleIdentifier ?? "com.fueki.wallet",
         accessGroup: String? = nil,
         accessLevel: KeychainAccessLevel = .whenUnlockedThisDeviceOnly) {
        self.service = service
        self.accessGroup = accessGroup
        self.accessLevel = accessLevel
    }

    // MARK: - SecureStorageProtocol

    func save(_ data: Data, forKey key: String) throws {
        // Delete existing item if present
        try? delete(forKey: key)

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = accessLevel.rawValue

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw WalletError.keychainSaveFailed(status)
        }
    }

    func load(forKey key: String) throws -> Data {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw WalletError.keychainItemNotFound
            }
            throw WalletError.keychainLoadFailed(status)
        }

        guard let data = result as? Data else {
            throw WalletError.invalidData
        }

        return data
    }

    func delete(forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.keychainDeleteFailed(status)
        }
    }

    func exists(forKey key: String) -> Bool {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = false

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func clearAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw WalletError.keychainDeleteFailed(status)
        }
    }

    // MARK: - Secure Enclave Operations

    /// Save data with Secure Enclave protection (requires biometric authentication)
    func saveWithSecureEnclave(_ data: Data, forKey key: String, reason: String) throws {
        guard isSecureEnclaveAvailable() else {
            throw WalletError.secureEnclaveNotAvailable
        }

        // Delete existing item
        try? delete(forKey: key)

        // Create access control with biometric requirement
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            nil
        ) else {
            throw WalletError.secureEnclaveOperationFailed("Failed to create access control")
        }

        var query = baseQuery(forKey: key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessControl as String] = access
        query[kSecUseAuthenticationContext as String] = reason

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            throw WalletError.keychainSaveFailed(status)
        }
    }

    /// Load data protected by Secure Enclave (requires biometric authentication)
    func loadWithSecureEnclave(forKey key: String, reason: String) throws -> Data {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseOperationPrompt as String] = reason

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw WalletError.keychainItemNotFound
            }
            if status == errSecUserCanceled {
                throw WalletError.biometricCancelled
            }
            throw WalletError.keychainLoadFailed(status)
        }

        guard let data = result as? Data else {
            throw WalletError.invalidData
        }

        return data
    }

    // MARK: - Helper Methods

    private func baseQuery(forKey key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private func isSecureEnclaveAvailable() -> Bool {
        // Check if device supports Secure Enclave
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .privateKeyUsage,
            nil
        ) else {
            return false
        }

        // Try to create a key in Secure Enclave
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

    // MARK: - Utility Methods

    /// Update existing keychain item
    func update(_ data: Data, forKey key: String) throws {
        let query = baseQuery(forKey: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // Item doesn't exist, save it
                try save(data, forKey: key)
                return
            }
            throw WalletError.keychainSaveFailed(status)
        }
    }

    /// Get all keys in keychain
    func allKeys() throws -> [String] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        if let accessGroup = accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                return []
            }
            throw WalletError.keychainLoadFailed(status)
        }

        guard let items = result as? [[String: Any]] else {
            return []
        }

        return items.compactMap { $0[kSecAttrAccount as String] as? String }
    }
}

// MARK: - Memory Zeroing Extension

extension Data {
    /// Securely zero out data in memory
    mutating func zeroMemory() {
        self.withUnsafeMutableBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            memset(baseAddress, 0, buffer.count)
        }
    }
}
