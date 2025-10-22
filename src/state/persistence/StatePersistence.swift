//
//  StatePersistence.swift
//  Fueki Wallet
//
//  State persistence layer with encryption and backup
//

import Foundation
import CryptoKit

@MainActor
class StatePersistence {
    // MARK: - Singleton
    static let shared = StatePersistence()

    // MARK: - Properties
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let encryptionKey: SymmetricKey

    // File paths
    private var stateDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("State", isDirectory: true)
    }

    private var backupDirectory: URL {
        stateDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    // MARK: - Initialization
    private init() {
        // Generate or retrieve encryption key
        self.encryptionKey = Self.getOrCreateEncryptionKey()

        // Create directories
        createDirectoriesIfNeeded()

        // Setup date formatters
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - App State Persistence

    func saveAppState(_ snapshot: AppStateSnapshot) async throws {
        let data = try encoder.encode(snapshot)
        let encryptedData = try encrypt(data)

        let fileURL = stateDirectory.appendingPathComponent("app_state.dat")

        try encryptedData.write(to: fileURL, options: .atomic)

        // Create backup periodically
        await createBackupIfNeeded()
    }

    func restoreAppState() async throws -> AppStateSnapshot? {
        let fileURL = stateDirectory.appendingPathComponent("app_state.dat")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let encryptedData = try Data(contentsOf: fileURL)
        let data = try decrypt(encryptedData)

        return try decoder.decode(AppStateSnapshot.self, from: data)
    }

    // MARK: - Individual State Persistence

    func saveState<T: Codable>(_ state: T, key: String) async throws {
        let data = try encoder.encode(state)
        let encryptedData = try encrypt(data)

        let fileURL = stateDirectory.appendingPathComponent("\(key).dat")
        try encryptedData.write(to: fileURL, options: .atomic)
    }

    func restoreState<T: Codable>(key: String, type: T.Type) async throws -> T? {
        let fileURL = stateDirectory.appendingPathComponent("\(key).dat")

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let encryptedData = try Data(contentsOf: fileURL)
        let data = try decrypt(encryptedData)

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Backup Management

    func createBackup() async throws {
        let timestamp = Date().ISO8601Format()
        let backupName = "backup_\(timestamp).dat"
        let backupURL = backupDirectory.appendingPathComponent(backupName)

        // Copy current state to backup
        let currentStateURL = stateDirectory.appendingPathComponent("app_state.dat")

        if fileManager.fileExists(atPath: currentStateURL.path) {
            try fileManager.copyItem(at: currentStateURL, to: backupURL)
        }

        // Clean old backups (keep last 10)
        try cleanOldBackups(keepCount: 10)
    }

    func restoreFromBackup(backupName: String? = nil) async throws {
        let backups = try listBackups()

        guard let backupToRestore = backupName ?? backups.last else {
            throw PersistenceError.noBackupsFound
        }

        let backupURL = backupDirectory.appendingPathComponent(backupToRestore)
        let stateURL = stateDirectory.appendingPathComponent("app_state.dat")

        // Remove current state
        try? fileManager.removeItem(at: stateURL)

        // Restore from backup
        try fileManager.copyItem(at: backupURL, to: stateURL)
    }

    func listBackups() throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: []
        )

        return contents
            .filter { $0.pathExtension == "dat" }
            .sorted { url1, url2 in
                let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate
                let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate
                return (date1 ?? Date.distantPast) < (date2 ?? Date.distantPast)
            }
            .map { $0.lastPathComponent }
    }

    // MARK: - Clear State

    func clearAllState() async throws {
        // Remove all state files
        let contents = try fileManager.contentsOfDirectory(
            at: stateDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )

        for fileURL in contents where fileURL.pathExtension == "dat" && !fileURL.path.contains("Backups") {
            try fileManager.removeItem(at: fileURL)
        }
    }

    func clearBackups() async throws {
        let contents = try fileManager.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: nil,
            options: []
        )

        for fileURL in contents {
            try fileManager.removeItem(at: fileURL)
        }
    }

    // MARK: - Private Methods

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    private func createBackupIfNeeded() async {
        // Create backup once per day
        let backups = try? listBackups()
        let lastBackup = backups?.last

        let shouldBackup: Bool
        if let lastBackup = lastBackup,
           let backupDate = extractDateFromBackupName(lastBackup) {
            let daysSinceBackup = Calendar.current.dateComponents([.day], from: backupDate, to: Date()).day ?? 0
            shouldBackup = daysSinceBackup >= 1
        } else {
            shouldBackup = true
        }

        if shouldBackup {
            try? await createBackup()
        }
    }

    private func cleanOldBackups(keepCount: Int) throws {
        let backups = try listBackups()

        if backups.count > keepCount {
            let backupsToDelete = backups.dropLast(keepCount)

            for backup in backupsToDelete {
                let backupURL = backupDirectory.appendingPathComponent(backup)
                try fileManager.removeItem(at: backupURL)
            }
        }
    }

    private func extractDateFromBackupName(_ name: String) -> Date? {
        let dateString = name
            .replacingOccurrences(of: "backup_", with: "")
            .replacingOccurrences(of: ".dat", with: "")

        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateString)
    }

    // MARK: - Encryption

    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!
    }

    private func decrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: encryptionKey)
    }

    private static func getOrCreateEncryptionKey() -> SymmetricKey {
        let keyData: Data

        // Try to retrieve key from Keychain
        if let existingKey = KeychainHelper.retrieve(key: "state_encryption_key") {
            keyData = existingKey
        } else {
            // Generate new key
            keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            KeychainHelper.save(key: "state_encryption_key", data: keyData)
        }

        return SymmetricKey(data: keyData)
    }
}

// MARK: - Keychain Helper

private class KeychainHelper {
    static func save(key: String, data: Data) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func retrieve(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return data
    }
}

// MARK: - Errors

enum PersistenceError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case fileNotFound
    case noBackupsFound
    case invalidBackup

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt state data"
        case .decryptionFailed:
            return "Failed to decrypt state data"
        case .fileNotFound:
            return "State file not found"
        case .noBackupsFound:
            return "No backups available"
        case .invalidBackup:
            return "Invalid backup file"
        }
    }
}
