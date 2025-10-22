//
//  WalletBackupManager.swift
//  FuekiWallet
//
//  Secure backup and restore functionality with encryption
//

import Foundation
import CryptoKit

/// Manages secure wallet backup and restore operations
final class WalletBackupManager: BackupProtocol {

    // MARK: - Properties

    private let encryptionService: EncryptionService
    private let keychainManager: KeychainManager

    // MARK: - Constants

    private enum Constants {
        static let backupVersion = "1.0.0"
        static let backupMagicBytes = Data([0x46, 0x55, 0x45, 0x4B]) // "FUEK"
    }

    // MARK: - Backup Format

    struct WalletBackup: Codable {
        let version: String
        let timestamp: TimeInterval
        let metadata: WalletMetadata
        let encryptedData: Data
        let salt: Data
        let checksum: Data

        struct EncryptedPayload: Codable {
            let mnemonic: String
            let accounts: [AccountBackup]
            let settings: WalletSettings

            struct AccountBackup: Codable {
                let index: UInt32
                let path: String
                let address: String
                let name: String?
            }

            struct WalletSettings: Codable {
                let biometricEnabled: Bool
                let autoLockTimeout: TimeInterval
                let selectedAccount: UInt32
            }
        }
    }

    // MARK: - Initialization

    init(encryptionService: EncryptionService, keychainManager: KeychainManager) {
        self.encryptionService = encryptionService
        self.keychainManager = keychainManager
    }

    // MARK: - BackupProtocol

    func createBackup(password: String) throws -> Data {
        // Validate password
        guard encryptionService.validatePassword(password) else {
            throw WalletError.passwordTooWeak
        }

        // Collect wallet data
        let payload = try collectWalletData()

        // Encode payload
        let encoder = JSONEncoder()
        let payloadData = try encoder.encode(payload)

        // Generate salt for backup
        let salt = try encryptionService.generateSalt()

        // Derive encryption key
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: salt)

        // Encrypt payload
        let encryptedData = try encryptionService.encrypt(payloadData, withKey: encryptionKey)

        // Calculate checksum
        let checksum = encryptionService.hash(payloadData)

        // Create backup structure
        let backup = WalletBackup(
            version: Constants.backupVersion,
            timestamp: Date().timeIntervalSince1970,
            metadata: WalletMetadata(),
            encryptedData: encryptedData,
            salt: salt,
            checksum: checksum
        )

        // Encode backup
        let backupData = try encoder.encode(backup)

        // Add magic bytes
        var finalData = Constants.backupMagicBytes
        finalData.append(backupData)

        // Zero out sensitive data
        var encKeyData = encryptionKey
        var payloadDataCopy = payloadData
        encKeyData.zeroMemory()
        payloadDataCopy.zeroMemory()

        return finalData
    }

    func restoreBackup(_ data: Data, password: String) throws {
        // Verify magic bytes
        guard data.prefix(4) == Constants.backupMagicBytes else {
            throw WalletError.invalidBackupData
        }

        // Extract backup data
        let backupData = data.suffix(from: 4)

        // Decode backup
        let decoder = JSONDecoder()
        let backup = try decoder.decode(WalletBackup.self, from: backupData)

        // Verify version compatibility
        guard backup.version == Constants.backupVersion else {
            throw WalletError.restoreFailed("Incompatible backup version: \(backup.version)")
        }

        // Derive encryption key
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: backup.salt)

        // Decrypt payload
        let payloadData = try encryptionService.decrypt(backup.encryptedData, withKey: encryptionKey)

        // Verify checksum
        let calculatedChecksum = encryptionService.hash(payloadData)
        guard calculatedChecksum == backup.checksum else {
            throw WalletError.backupDecryptionFailed
        }

        // Decode payload
        let payload = try decoder.decode(WalletBackup.EncryptedPayload.self, from: payloadData)

        // Restore wallet data
        try restoreWalletData(payload, password: password)

        // Zero out sensitive data
        var encKeyData = encryptionKey
        var payloadDataCopy = payloadData
        encKeyData.zeroMemory()
        payloadDataCopy.zeroMemory()
    }

    func validateBackup(_ data: Data) -> Bool {
        // Check magic bytes
        guard data.count > 4 && data.prefix(4) == Constants.backupMagicBytes else {
            return false
        }

        // Try to decode backup structure
        let backupData = data.suffix(from: 4)
        let decoder = JSONDecoder()

        do {
            _ = try decoder.decode(WalletBackup.self, from: backupData)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func collectWalletData() throws -> WalletBackup.EncryptedPayload {
        // Load mnemonic from keychain
        guard let mnemonicData = try? keychainManager.load(forKey: "wallet.mnemonic"),
              let mnemonic = String(data: mnemonicData, encoding: .utf8) else {
            throw WalletError.walletNotFound
        }

        // Collect account information
        var accounts: [WalletBackup.EncryptedPayload.AccountBackup] = []

        // Load account metadata
        if let accountsData = try? keychainManager.load(forKey: "wallet.accounts"),
           let accountsJson = try? JSONDecoder().decode([AccountMetadata].self, from: accountsData) {
            accounts = accountsJson.map {
                WalletBackup.EncryptedPayload.AccountBackup(
                    index: $0.index,
                    path: $0.path,
                    address: $0.address,
                    name: $0.name
                )
            }
        }

        // Load settings
        let settings = loadWalletSettings()

        return WalletBackup.EncryptedPayload(
            mnemonic: mnemonic,
            accounts: accounts,
            settings: settings
        )
    }

    private func restoreWalletData(_ payload: WalletBackup.EncryptedPayload, password: String) throws {
        // Store mnemonic
        guard let mnemonicData = payload.mnemonic.data(using: .utf8) else {
            throw WalletError.restoreFailed("Invalid mnemonic encoding")
        }

        try keychainManager.save(mnemonicData, forKey: "wallet.mnemonic")

        // Restore accounts
        let accountsMetadata = payload.accounts.map {
            AccountMetadata(
                index: $0.index,
                path: $0.path,
                address: $0.address,
                name: $0.name
            )
        }

        let encoder = JSONEncoder()
        let accountsData = try encoder.encode(accountsMetadata)
        try keychainManager.save(accountsData, forKey: "wallet.accounts")

        // Restore settings
        try saveWalletSettings(payload.settings)
    }

    private func loadWalletSettings() -> WalletBackup.EncryptedPayload.WalletSettings {
        let defaults = UserDefaults.standard

        return WalletBackup.EncryptedPayload.WalletSettings(
            biometricEnabled: defaults.bool(forKey: "wallet.biometric.enabled"),
            autoLockTimeout: defaults.double(forKey: "wallet.autolock.timeout"),
            selectedAccount: UInt32(defaults.integer(forKey: "wallet.selected.account"))
        )
    }

    private func saveWalletSettings(_ settings: WalletBackup.EncryptedPayload.WalletSettings) throws {
        let defaults = UserDefaults.standard

        defaults.set(settings.biometricEnabled, forKey: "wallet.biometric.enabled")
        defaults.set(settings.autoLockTimeout, forKey: "wallet.autolock.timeout")
        defaults.set(settings.selectedAccount, forKey: "wallet.selected.account")
    }

    // MARK: - Export/Import

    /// Export backup as QR code data
    func exportAsQRCode(backup: Data) throws -> Data {
        // Compress backup data for QR code
        guard let compressed = try? (backup as NSData).compressed(using: .lzfse) as Data else {
            throw WalletError.backupFailed("Compression failed")
        }

        return compressed
    }

    /// Import backup from QR code data
    func importFromQRCode(_ qrData: Data) throws -> Data {
        // Decompress backup data
        guard let decompressed = try? (qrData as NSData).decompressed(using: .lzfse) as Data else {
            throw WalletError.restoreFailed("Decompression failed")
        }

        return decompressed
    }

    /// Create encrypted cloud backup (for iCloud, Dropbox, etc.)
    func createCloudBackup(password: String, additionalEncryption: Bool = true) throws -> Data {
        var backup = try createBackup(password: password)

        if additionalEncryption {
            // Add additional layer of encryption for cloud storage
            let cloudKey = try encryptionService.generateKey()
            backup = try encryptionService.encrypt(backup, withKey: cloudKey)

            // Store cloud key in keychain
            try keychainManager.save(cloudKey, forKey: "wallet.cloud.key")

            var cloudKeyData = cloudKey
            cloudKeyData.zeroMemory()
        }

        return backup
    }

    /// Restore from cloud backup
    func restoreCloudBackup(_ data: Data, password: String, hasAdditionalEncryption: Bool = true) throws {
        var backup = data

        if hasAdditionalEncryption {
            // Decrypt additional cloud encryption layer
            guard let cloudKey = try? keychainManager.load(forKey: "wallet.cloud.key") else {
                throw WalletError.restoreFailed("Cloud encryption key not found")
            }

            backup = try encryptionService.decrypt(data, withKey: cloudKey)
        }

        try restoreBackup(backup, password: password)
    }
}

// MARK: - Supporting Types

struct AccountMetadata: Codable {
    let index: UInt32
    let path: String
    let address: String
    let name: String?
}

// MARK: - Backup Verification

extension WalletBackupManager {
    /// Verify backup integrity without restoring
    func verifyBackup(_ data: Data, password: String) throws -> BackupInfo {
        guard validateBackup(data) else {
            throw WalletError.invalidBackupData
        }

        let backupData = data.suffix(from: 4)
        let decoder = JSONDecoder()
        let backup = try decoder.decode(WalletBackup.self, from: backupData)

        // Try to decrypt to verify password
        let encryptionKey = try encryptionService.deriveKey(from: password, salt: backup.salt)
        let payloadData = try encryptionService.decrypt(backup.encryptedData, withKey: encryptionKey)

        // Verify checksum
        let calculatedChecksum = encryptionService.hash(payloadData)
        guard calculatedChecksum == backup.checksum else {
            throw WalletError.backupDecryptionFailed
        }

        // Decode payload for info
        let payload = try decoder.decode(WalletBackup.EncryptedPayload.self, from: payloadData)

        var encKeyData = encryptionKey
        var payloadDataCopy = payloadData
        encKeyData.zeroMemory()
        payloadDataCopy.zeroMemory()

        return BackupInfo(
            version: backup.version,
            timestamp: Date(timeIntervalSince1970: backup.timestamp),
            accountCount: payload.accounts.count,
            hasBiometric: payload.settings.biometricEnabled
        )
    }

    struct BackupInfo {
        let version: String
        let timestamp: Date
        let accountCount: Int
        let hasBiometric: Bool
    }
}
