//
//  WalletManager.swift
//  FuekiWallet
//
//  Main wallet orchestration and lifecycle management
//

import Foundation
import Combine

/// Main wallet manager orchestrating all wallet operations
final class WalletManager: ObservableObject {

    // MARK: - Published Properties

    @Published var isUnlocked: Bool = false
    @Published var currentAccount: WalletAccount?
    @Published var accounts: [WalletAccount] = []

    // MARK: - Components

    private let keyManager: KeyManager
    private let mnemonicGenerator: MnemonicGenerator
    private let encryptionService: EncryptionService
    private let keychainManager: KeychainManager
    private let biometricManager: BiometricAuthManager
    private let backupManager: WalletBackupManager

    private var hdWallet: HDWallet?
    private let securityConfig: SecurityConfiguration

    // MARK: - Security State

    private var authAttempts = 0
    private var lockoutEndTime: Date?
    private var autoLockTimer: Timer?

    // MARK: - Initialization

    init(securityConfig: SecurityConfiguration = .default) {
        self.securityConfig = securityConfig

        // Initialize components
        self.keychainManager = KeychainManager(
            accessLevel: securityConfig.keychainAccessLevel
        )

        self.encryptionService = EncryptionService(
            keyDerivationMethod: .scrypt
        )

        self.keyManager = KeyManager(
            keychainManager: keychainManager,
            encryptionService: encryptionService,
            useSecureEnclave: securityConfig.useSecureEnclave
        )

        self.mnemonicGenerator = MnemonicGenerator()

        self.biometricManager = BiometricAuthManager(
            maxAttempts: securityConfig.maxAuthAttempts,
            lockoutDuration: securityConfig.lockoutDuration
        )

        self.backupManager = WalletBackupManager(
            encryptionService: encryptionService,
            keychainManager: keychainManager
        )

        // Check for jailbreak
        if securityConfig.enableJailbreakDetection {
            performSecurityChecks()
        }
    }

    // MARK: - Wallet Lifecycle

    /// Create new wallet with mnemonic
    func createWallet(password: String, mnemonicStrength: MnemonicStrength = .word12) throws {
        // Validate password
        guard encryptionService.validatePassword(password) else {
            throw WalletError.passwordTooWeak
        }

        // Check if wallet already exists
        guard !walletExists() else {
            throw WalletError.walletAlreadyExists
        }

        // Generate mnemonic
        let mnemonic = try mnemonicGenerator.generate(strength: mnemonicStrength)

        // Create wallet from mnemonic
        try createWallet(mnemonic: mnemonic, password: password)
    }

    /// Create wallet from existing mnemonic
    func createWallet(mnemonic: String, password: String) throws {
        // Validate password
        guard encryptionService.validatePassword(password) else {
            throw WalletError.passwordTooWeak
        }

        // Validate mnemonic
        guard try mnemonicGenerator.validate(mnemonic) else {
            throw WalletError.invalidMnemonic
        }

        // Generate seed from mnemonic
        let seed = try mnemonicGenerator.toSeed(mnemonic)

        // Create HD wallet
        let wallet = try HDWallet(seed: seed)
        self.hdWallet = wallet

        // Store mnemonic (encrypted)
        try storeMnemonic(mnemonic, password: password)

        // Generate master key
        try keyManager.generateMasterKey(password: password)

        // Create password verifier
        let verifier = try encryptionService.createPasswordVerifier(password)
        try keychainManager.save(verifier, forKey: "wallet.password.verifier")

        // Create default account
        try createAccount(index: 0, name: "Account 1")

        // Store wallet metadata
        let metadata = WalletMetadata()
        let metadataData = try JSONEncoder().encode(metadata)
        try keychainManager.save(metadataData, forKey: "wallet.metadata")

        // Zero out sensitive data
        var seedData = seed
        seedData.zeroMemory()
    }

    /// Unlock wallet with password
    func unlock(password: String) throws {
        // Check if locked out
        if let lockoutEnd = lockoutEndTime, Date() < lockoutEnd {
            throw WalletError.authenticationAttemptsExceeded
        }

        // Verify password
        guard try verifyPassword(password) else {
            authAttempts += 1

            if authAttempts >= securityConfig.maxAuthAttempts {
                lockoutEndTime = Date().addingTimeInterval(securityConfig.lockoutDuration)
                throw WalletError.authenticationAttemptsExceeded
            }

            throw WalletError.invalidPassword
        }

        // Reset auth attempts
        authAttempts = 0
        lockoutEndTime = nil

        // Load wallet
        try loadWallet(password: password)

        // Update state
        isUnlocked = true

        // Start auto-lock timer
        startAutoLockTimer()
    }

    /// Unlock with biometric authentication
    func unlockWithBiometric() async throws {
        guard biometricManager.isAvailable else {
            throw WalletError.biometricNotAvailable
        }

        // Authenticate
        let authenticated = try await biometricManager.authenticate(
            reason: "Unlock your Fueki wallet"
        )

        guard authenticated else {
            throw WalletError.biometricAuthenticationFailed
        }

        // Load password from secure storage
        guard let passwordData = try? keychainManager.loadWithSecureEnclave(
            forKey: "wallet.biometric.password",
            reason: "Access wallet password"
        ),
              let password = String(data: passwordData, encoding: .utf8) else {
            throw WalletError.privateKeyNotFound
        }

        // Unlock with password
        try unlock(password: password)
    }

    /// Lock wallet
    func lock() {
        isUnlocked = false
        currentAccount = nil
        hdWallet = nil

        // Stop auto-lock timer
        autoLockTimer?.invalidate()
        autoLockTimer = nil
    }

    /// Delete wallet completely
    func deleteWallet() throws {
        // Lock wallet
        lock()

        // Delete all keychain data
        try keychainManager.clearAll()

        // Reset state
        accounts = []
        currentAccount = nil
    }

    // MARK: - Account Management

    /// Create new account
    @discardableResult
    func createAccount(index: UInt32, name: String? = nil) throws -> WalletAccount {
        guard let wallet = hdWallet else {
            throw WalletError.walletNotFound
        }

        // Derive key for account
        let path = HDWallet.ethereumPath(account: index)
        let privateKey = try wallet.deriveKey(at: path)
        let address = try wallet.getAddress(at: path)

        // Create account
        let account = WalletAccount(
            index: index,
            name: name ?? "Account \(index + 1)",
            address: address,
            path: path
        )

        // Add to accounts list
        accounts.append(account)

        // Set as current if first account
        if currentAccount == nil {
            currentAccount = account
        }

        // Save accounts
        try saveAccounts()

        // Zero out private key
        var privKeyData = privateKey
        privKeyData.zeroMemory()

        return account
    }

    /// Switch to account
    func switchToAccount(_ account: WalletAccount) {
        currentAccount = account

        // Save selected account
        UserDefaults.standard.set(account.index, forKey: "wallet.selected.account")
    }

    /// Get private key for account
    func getPrivateKey(for account: WalletAccount, password: String) throws -> Data {
        // Verify password
        guard try verifyPassword(password) else {
            throw WalletError.invalidPassword
        }

        guard let wallet = hdWallet else {
            throw WalletError.walletNotFound
        }

        return try wallet.deriveKey(at: account.path)
    }

    // MARK: - Backup & Restore

    /// Create backup
    func createBackup(password: String) throws -> Data {
        return try backupManager.createBackup(password: password)
    }

    /// Restore from backup
    func restoreFromBackup(_ data: Data, password: String) throws {
        // Delete existing wallet if present
        if walletExists() {
            try deleteWallet()
        }

        // Restore backup
        try backupManager.restoreBackup(data, password: password)

        // Load wallet
        try loadWallet(password: password)
    }

    /// Verify backup
    func verifyBackup(_ data: Data, password: String) throws -> WalletBackupManager.BackupInfo {
        return try backupManager.verifyBackup(data, password: password)
    }

    // MARK: - Biometric Setup

    /// Enable biometric authentication
    func enableBiometric(password: String) throws {
        // Verify password first
        guard try verifyPassword(password) else {
            throw WalletError.invalidPassword
        }

        guard biometricManager.isAvailable else {
            throw WalletError.biometricNotAvailable
        }

        // Store password in Secure Enclave
        guard let passwordData = password.data(using: .utf8) else {
            throw WalletError.invalidPassword
        }

        try keychainManager.saveWithSecureEnclave(
            passwordData,
            forKey: "wallet.biometric.password",
            reason: "Enable biometric authentication"
        )

        // Update settings
        UserDefaults.standard.set(true, forKey: "wallet.biometric.enabled")
    }

    /// Disable biometric authentication
    func disableBiometric() throws {
        try keychainManager.delete(forKey: "wallet.biometric.password")
        UserDefaults.standard.set(false, forKey: "wallet.biometric.enabled")
    }

    // MARK: - Private Methods

    private func walletExists() -> Bool {
        return keychainManager.exists(forKey: "wallet.mnemonic")
    }

    private func storeMnemonic(_ mnemonic: String, password: String) throws {
        guard let mnemonicData = mnemonic.data(using: .utf8) else {
            throw WalletError.invalidData
        }

        let encrypted = try encryptionService.encryptWithPassword(mnemonicData, password: password)
        try keychainManager.save(encrypted, forKey: "wallet.mnemonic")
    }

    private func loadMnemonic(password: String) throws -> String {
        let encrypted = try keychainManager.load(forKey: "wallet.mnemonic")
        let decrypted = try encryptionService.decryptWithPassword(encrypted, password: password)

        guard let mnemonic = String(data: decrypted, encoding: .utf8) else {
            throw WalletError.invalidData
        }

        return mnemonic
    }

    private func verifyPassword(_ password: String) throws -> Bool {
        let verifier = try keychainManager.load(forKey: "wallet.password.verifier")
        return try encryptionService.verifyPassword(password, against: verifier)
    }

    private func loadWallet(password: String) throws {
        // Load mnemonic
        let mnemonic = try loadMnemonic(password: password)

        // Generate seed
        let seed = try mnemonicGenerator.toSeed(mnemonic)

        // Create HD wallet
        self.hdWallet = try HDWallet(seed: seed)

        // Load accounts
        try loadAccounts()

        // Zero out sensitive data
        var seedData = seed
        seedData.zeroMemory()
    }

    private func saveAccounts() throws {
        let metadata = accounts.map {
            AccountMetadata(
                index: $0.index,
                path: $0.path,
                address: $0.address,
                name: $0.name
            )
        }

        let data = try JSONEncoder().encode(metadata)
        try keychainManager.save(data, forKey: "wallet.accounts")
    }

    private func loadAccounts() throws {
        guard let data = try? keychainManager.load(forKey: "wallet.accounts") else {
            // No accounts saved, create default
            try createAccount(index: 0, name: "Account 1")
            return
        }

        let metadata = try JSONDecoder().decode([AccountMetadata].self, from: data)

        self.accounts = metadata.map {
            WalletAccount(
                index: $0.index,
                name: $0.name ?? "Account \($0.index + 1)",
                address: $0.address,
                path: $0.path
            )
        }

        // Load selected account
        let selectedIndex = UInt32(UserDefaults.standard.integer(forKey: "wallet.selected.account"))
        currentAccount = accounts.first { $0.index == selectedIndex } ?? accounts.first
    }

    private func startAutoLockTimer() {
        let timeout = UserDefaults.standard.double(forKey: "wallet.autolock.timeout")
        guard timeout > 0 else { return }

        autoLockTimer?.invalidate()
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            self?.lock()
        }
    }

    private func performSecurityChecks() {
        if isJailbroken() {
            fatalError("Security check failed: Jailbroken device detected")
        }
    }

    private func isJailbroken() -> Bool {
        // Check for jailbreak indicators
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

        // Check if can write to system
        let testPath = "/private/jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true
        } catch {
            // Cannot write, likely not jailbroken
        }

        return false
    }
}

// MARK: - Supporting Types

struct WalletAccount: Identifiable, Codable {
    let id = UUID()
    let index: UInt32
    let name: String
    let address: String
    let path: String

    enum CodingKeys: String, CodingKey {
        case index, name, address, path
    }
}
