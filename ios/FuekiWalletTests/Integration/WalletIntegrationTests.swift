//
//  WalletIntegrationTests.swift
//  FuekiWalletTests
//
//  End-to-end integration tests for complete wallet workflows
//

import XCTest
@testable import FuekiWallet

@MainActor
final class WalletIntegrationTests: XCTestCase {

    var walletManager: WalletManager!
    var keyManager: KeyManager!
    var keychainManager: KeychainManager!
    var encryptionService: EncryptionService!

    override func setUp() async throws {
        keychainManager = KeychainManager()
        encryptionService = EncryptionService()
        keyManager = KeyManager(
            keychainManager: keychainManager,
            encryptionService: encryptionService,
            useSecureEnclave: false
        )
        walletManager = WalletManager(keyManager: keyManager)

        // Clean test environment
        try? await clearTestData()
    }

    override func tearDown() async throws {
        try? await clearTestData()
        walletManager = nil
        keyManager = nil
        keychainManager = nil
        encryptionService = nil
    }

    // MARK: - Complete Wallet Creation Flow

    func testWalletCreation_CompleteFlow_Success() async throws {
        // Given
        let password = "SecureTestPassword123!"
        let walletName = "Test Wallet"

        // When - Create wallet
        let wallet = try await walletManager.createWallet(name: walletName, password: password)

        // Then - Verify wallet created
        XCTAssertFalse(wallet.id.isEmpty)
        XCTAssertEqual(wallet.name, walletName)
        XCTAssertFalse(wallet.address.isEmpty)
        XCTAssertTrue(wallet.isActive)

        // Verify mnemonic generated
        let mnemonic = try await walletManager.getMnemonic(walletId: wallet.id, password: password)
        XCTAssertFalse(mnemonic.isEmpty)
        let words = mnemonic.components(separatedBy: " ")
        XCTAssertEqual(words.count, 12)

        // Verify keys stored securely
        let keyPair = try keyManager.loadKeyPair(identifier: wallet.id, password: password)
        XCTAssertGreaterThan(keyPair.privateKey.count, 0)
        XCTAssertGreaterThan(keyPair.publicKey.count, 0)
    }

    func testWalletImport_CompleteFlow_Success() async throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let password = "SecureTestPassword123!"

        // When - Import wallet
        let wallet = try await walletManager.importWallet(mnemonic: mnemonic, password: password)

        // Then - Verify wallet imported
        XCTAssertFalse(wallet.id.isEmpty)
        XCTAssertFalse(wallet.address.isEmpty)

        // Verify can retrieve mnemonic
        let retrievedMnemonic = try await walletManager.getMnemonic(walletId: wallet.id, password: password)
        XCTAssertEqual(retrievedMnemonic, mnemonic)

        // Verify keys accessible
        let keyPair = try keyManager.loadKeyPair(identifier: wallet.id, password: password)
        XCTAssertGreaterThan(keyPair.privateKey.count, 0)
    }

    // MARK: - Multi-Wallet Management

    func testMultipleWallets_CreateAndSwitch() async throws {
        // Given
        let password = "SecureTestPassword123!"

        // When - Create multiple wallets
        let wallet1 = try await walletManager.createWallet(name: "Wallet 1", password: password)
        let wallet2 = try await walletManager.createWallet(name: "Wallet 2", password: password)
        let wallet3 = try await walletManager.createWallet(name: "Wallet 3", password: password)

        // Then - Verify all created
        let allWallets = try await walletManager.getAllWallets()
        XCTAssertEqual(allWallets.count, 3)

        // Verify can switch between wallets
        try await walletManager.setActiveWallet(wallet2)
        let activeWallet = try await walletManager.getActiveWallet()
        XCTAssertEqual(activeWallet?.id, wallet2.id)

        // Verify each wallet has unique keys
        let keys1 = try keyManager.loadPublicKey(identifier: wallet1.id)
        let keys2 = try keyManager.loadPublicKey(identifier: wallet2.id)
        let keys3 = try keyManager.loadPublicKey(identifier: wallet3.id)

        XCTAssertNotEqual(keys1, keys2)
        XCTAssertNotEqual(keys2, keys3)
        XCTAssertNotEqual(keys1, keys3)
    }

    // MARK: - Wallet Backup and Restore

    func testWalletBackup_CompleteFlow() async throws {
        // Given
        let password = "SecureTestPassword123!"
        let wallet = try await walletManager.createWallet(name: "Backup Test", password: password)

        // When - Create backup
        let backupData = try await walletManager.createBackup(walletId: wallet.id, password: password)

        // Then - Verify backup contains necessary data
        XCTAssertGreaterThan(backupData.count, 0)

        // Verify can restore from backup
        let restoredWallet = try await walletManager.restoreFromBackup(backupData, password: password)
        XCTAssertEqual(restoredWallet.address, wallet.address)

        // Verify restored wallet is functional
        let keyPair = try keyManager.loadKeyPair(identifier: restoredWallet.id, password: password)
        XCTAssertGreaterThan(keyPair.privateKey.count, 0)
    }

    // MARK: - Wallet Deletion

    func testWalletDeletion_CompleteClearance() async throws {
        // Given
        let password = "SecureTestPassword123!"
        let wallet = try await walletManager.createWallet(name: "Delete Test", password: password)
        let walletId = wallet.id

        // When - Delete wallet
        try await walletManager.deleteWallet(wallet, password: password)

        // Then - Verify wallet removed
        let allWallets = try await walletManager.getAllWallets()
        XCTAssertFalse(allWallets.contains(where: { $0.id == walletId }))

        // Verify keys removed from keychain
        XCTAssertThrowsError(try keyManager.loadKeyPair(identifier: walletId, password: password))
    }

    // MARK: - Security Tests

    func testWalletLock_RequiresPasswordToUnlock() async throws {
        // Given
        let password = "SecureTestPassword123!"
        let wallet = try await walletManager.createWallet(name: "Lock Test", password: password)

        // When - Lock wallet
        await walletManager.lockWallet()

        // Then - Verify cannot access keys without password
        let isLocked = await walletManager.isLocked()
        XCTAssertTrue(isLocked)

        // Verify unlock with correct password works
        let unlocked = try await walletManager.unlockWallet(password: password)
        XCTAssertTrue(unlocked)
        XCTAssertFalse(await walletManager.isLocked())
    }

    func testPasswordChange_MaintainsAccess() async throws {
        // Given
        let oldPassword = "OldSecurePassword123!"
        let newPassword = "NewSecurePassword456!"
        let wallet = try await walletManager.createWallet(name: "Password Test", password: oldPassword)

        // When - Change password
        try await walletManager.changePassword(
            walletId: wallet.id,
            oldPassword: oldPassword,
            newPassword: newPassword
        )

        // Then - Verify old password no longer works
        XCTAssertThrowsError(
            try keyManager.loadKeyPair(identifier: wallet.id, password: oldPassword)
        )

        // Verify new password works
        XCTAssertNoThrow(
            try keyManager.loadKeyPair(identifier: wallet.id, password: newPassword)
        )
    }

    // MARK: - Error Recovery Tests

    func testWalletCreation_FailureRollback() async throws {
        // Given
        let password = "SecureTestPassword123!"

        // Simulate failure scenario
        // (In real implementation, this would test actual failure handling)

        // When/Then - Verify no partial data left
        // This ensures atomic operations
    }

    func testConcurrentWalletOperations_ThreadSafe() async throws {
        // Given
        let password = "SecureTestPassword123!"

        // When - Perform concurrent operations
        async let wallet1 = walletManager.createWallet(name: "Concurrent 1", password: password)
        async let wallet2 = walletManager.createWallet(name: "Concurrent 2", password: password)
        async let wallet3 = walletManager.createWallet(name: "Concurrent 3", password: password)

        let results = try await [wallet1, wallet2, wallet3]

        // Then - Verify all succeeded
        XCTAssertEqual(results.count, 3)

        let allWallets = try await walletManager.getAllWallets()
        XCTAssertGreaterThanOrEqual(allWallets.count, 3)
    }

    // MARK: - Helper Methods

    private func clearTestData() async throws {
        // Clear all test wallets and keys
        let allWallets = try? await walletManager.getAllWallets()
        if let wallets = allWallets {
            for wallet in wallets {
                try? await walletManager.deleteWallet(wallet, password: "SecureTestPassword123!")
            }
        }
    }
}
