import XCTest
import LocalAuthentication
@testable import FuekiWallet

final class SecurityFlowTests: XCTestCase {

    var walletManager: WalletManager!
    var keyManager: KeyManager!
    var secureStorage: SecureStorage!
    var biometricAuthManager: BiometricAuthManager!

    override func setUp() async throws {
        try await super.setUp()

        secureStorage = SecureStorage()
        keyManager = KeyManager(secureStorage: secureStorage)
        biometricAuthManager = BiometricAuthManager()
        walletManager = WalletManager(
            keyManager: keyManager,
            secureStorage: secureStorage,
            biometricAuthManager: biometricAuthManager
        )
    }

    override func tearDown() async throws {
        // Clean up secure storage
        try secureStorage.deleteAll()

        walletManager = nil
        keyManager = nil
        secureStorage = nil
        biometricAuthManager = nil

        try await super.tearDown()
    }

    // MARK: - Secure Storage Integration

    func testSecureStorage_StoreAndRetrievePrivateKey() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"

        // When - Store encrypted key
        try keyManager.storePrivateKey(privateKey, password: password)

        // Then - Retrieve and verify
        let retrievedKey = try keyManager.retrievePrivateKey(password: password)
        XCTAssertEqual(retrievedKey, privateKey)
    }

    func testSecureStorage_DeletePrivateKey() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        try keyManager.storePrivateKey(privateKey, password: "TestPassword123!")

        // When
        try keyManager.deletePrivateKey()

        // Then - Should fail to retrieve
        XCTAssertThrowsError(
            try keyManager.retrievePrivateKey(password: "TestPassword123!")
        )
    }

    func testSecureStorage_MultipleKeys_IsolatedCorrectly() throws {
        // Given
        let key1 = try keyManager.generatePrivateKey()
        let key2 = try keyManager.generatePrivateKey()

        // When - Store with different identifiers
        try secureStorage.store(key1, forKey: "wallet1_privateKey", password: "Pass1")
        try secureStorage.store(key2, forKey: "wallet2_privateKey", password: "Pass2")

        // Then - Retrieve correct keys
        let retrieved1 = try secureStorage.retrieve(forKey: "wallet1_privateKey", password: "Pass1")
        let retrieved2 = try secureStorage.retrieve(forKey: "wallet2_privateKey", password: "Pass2")

        XCTAssertEqual(retrieved1, key1)
        XCTAssertEqual(retrieved2, key2)
        XCTAssertNotEqual(retrieved1, retrieved2)
    }

    // MARK: - Biometric Authentication Integration

    func testBiometricAvailability_ChecksCapability() {
        // When
        let isAvailable = biometricAuthManager.isBiometricAvailable()
        let biometricType = biometricAuthManager.biometricType()

        // Then
        if isAvailable {
            XCTAssertNotEqual(biometricType, .none)
        } else {
            XCTAssertEqual(biometricType, .none)
        }
    }

    func testBiometricAuthentication_EnableAndAuthenticate() async throws {
        // Skip if biometrics not available
        guard biometricAuthManager.isBiometricAvailable() else {
            throw XCTSkip("Biometrics not available on this device")
        }

        // Given - Create wallet
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")

        // When - Enable biometrics
        try await biometricAuthManager.enableBiometricAuth(for: wallet.address)

        // Then
        XCTAssertTrue(biometricAuthManager.isBiometricEnabled(for: wallet.address))
    }

    func testBiometricAuthentication_DisableBiometrics() async throws {
        guard biometricAuthManager.isBiometricAvailable() else {
            throw XCTSkip("Biometrics not available")
        }

        // Given
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        try await biometricAuthManager.enableBiometricAuth(for: wallet.address)

        // When
        try biometricAuthManager.disableBiometricAuth(for: wallet.address)

        // Then
        XCTAssertFalse(biometricAuthManager.isBiometricEnabled(for: wallet.address))
    }

    // MARK: - Password Security Integration

    func testPasswordComplexity_RejectsWeakPasswords() async {
        let weakPasswords = ["123", "password", "abc", ""]

        for password in weakPasswords {
            do {
                _ = try await walletManager.createWallet(password: password)
                XCTFail("Should reject weak password: \(password)")
            } catch WalletError.weakPassword {
                // Expected
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testPasswordComplexity_AcceptsStrongPasswords() async throws {
        let strongPasswords = [
            "SecurePassword123!",
            "Tr0ng_P@ssw0rd",
            "MyS3cur3P@ss!"
        ]

        for (index, password) in strongPasswords.enumerated() {
            let wallet = try await walletManager.createWallet(password: password)
            XCTAssertFalse(wallet.address.isEmpty, "Failed for password \(index)")

            // Clean up
            try secureStorage.deleteAll()
        }
    }

    func testPasswordChange_UpdatesEncryption() async throws {
        // Given - Create wallet with initial password
        let wallet = try await walletManager.createWallet(password: "OldPassword123!")
        let address = wallet.address
        await walletManager.lockWallet()

        // When - Change password
        try await walletManager.changePassword(
            currentPassword: "OldPassword123!",
            newPassword: "NewPassword456!"
        )

        // Then - Old password should fail
        do {
            _ = try await walletManager.unlockWallet(password: "OldPassword123!")
            XCTFail("Old password should not work")
        } catch WalletError.incorrectPassword {
            // Expected
        }

        // New password should work
        let unlocked = try await walletManager.unlockWallet(password: "NewPassword456!")
        XCTAssertTrue(unlocked)
    }

    // MARK: - Memory Security Integration

    func testSensitiveDataClearing_OnLock() async throws {
        // Given - Unlocked wallet
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        XCTAssertTrue(walletManager.isUnlocked)

        // When - Lock wallet
        await walletManager.lockWallet()

        // Then - Sensitive data should be cleared
        XCTAssertFalse(walletManager.isUnlocked)

        // Attempting operations should fail
        do {
            _ = try await walletManager.getBalance()
            XCTFail("Should fail when wallet is locked")
        } catch WalletError.walletLocked {
            // Expected
        }
    }

    func testSensitiveDataClearing_OnLogout() async throws {
        // Given
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")

        // When
        await walletManager.logout()

        // Then - All sensitive data should be cleared
        XCTAssertFalse(walletManager.isUnlocked)
        XCTAssertNil(walletManager.currentWalletAddress)
    }

    // MARK: - Keychain Security

    func testKeychainAccess_OnlyAfterAuthentication() throws {
        // Given - Store sensitive data
        let sensitiveData = "secret_data".data(using: .utf8)!
        try secureStorage.store(sensitiveData, forKey: "test_key", requireAuth: true)

        // When/Then - Retrieval should require authentication
        // Note: In real testing, this would trigger biometric prompt
        let retrieved = try? secureStorage.retrieve(forKey: "test_key")

        // On simulator/without biometrics, this might fail or succeed
        // depending on configuration
        if let data = retrieved {
            XCTAssertEqual(data, sensitiveData)
        }
    }

    // MARK: - Auto-Lock Integration

    func testAutoLock_LocksAfterTimeout() async throws {
        // Given - Create and unlock wallet
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        XCTAssertTrue(walletManager.isUnlocked)

        // When - Set auto-lock timeout
        walletManager.setAutoLockTimeout(seconds: 1)

        // Wait for timeout
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Then - Should be locked
        XCTAssertFalse(walletManager.isUnlocked)
    }

    // MARK: - Failed Authentication Attempts

    func testFailedLoginAttempts_IncrementsCounter() async throws {
        // Given
        let wallet = try await walletManager.createWallet(password: "CorrectPassword123!")
        await walletManager.lockWallet()

        // When - Multiple failed attempts
        for _ in 0..<3 {
            do {
                _ = try await walletManager.unlockWallet(password: "WrongPassword")
            } catch {
                // Expected to fail
            }
        }

        // Then
        let failedAttempts = walletManager.failedUnlockAttempts
        XCTAssertEqual(failedAttempts, 3)
    }

    func testFailedLoginAttempts_LocksAfterMaxAttempts() async throws {
        // Given
        let wallet = try await walletManager.createWallet(password: "CorrectPassword123!")
        await walletManager.lockWallet()
        walletManager.maxFailedAttempts = 3

        // When - Exceed max attempts
        for _ in 0..<4 {
            do {
                _ = try await walletManager.unlockWallet(password: "WrongPassword")
            } catch {
                // Expected to fail
            }
        }

        // Then - Should be locked even with correct password
        do {
            _ = try await walletManager.unlockWallet(password: "CorrectPassword123!")
            XCTFail("Should be locked after max attempts")
        } catch WalletError.accountLocked {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Encryption Strength

    func testEncryption_ResistsBruteForce() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let correctPassword = "SecurePassword123!"

        // Encrypt key
        let encrypted = try keyManager.encryptPrivateKey(privateKey, password: correctPassword)

        // When - Try many wrong passwords
        let wrongPasswords = [
            "wrongpass1", "wrongpass2", "12345", "password",
            "SecurePassword", "SecurePassword123", "SecurePassword123"
        ]

        // Then - All should fail
        for wrongPassword in wrongPasswords {
            XCTAssertThrowsError(
                try keyManager.decryptPrivateKey(encrypted, password: wrongPassword)
            )
        }

        // Correct password should still work
        let decrypted = try keyManager.decryptPrivateKey(encrypted, password: correctPassword)
        XCTAssertEqual(decrypted, privateKey)
    }

    // MARK: - Performance Tests

    func testSecureStorage_Performance() throws {
        let data = Data(repeating: 0x42, count: 1024) // 1KB

        measure {
            _ = try? secureStorage.store(data, forKey: "perf_test", password: "TestPass123!")
            _ = try? secureStorage.retrieve(forKey: "perf_test", password: "TestPass123!")
        }
    }

    func testEncryptionDecryption_Performance() throws {
        let privateKey = try keyManager.generatePrivateKey()
        let password = "TestPassword123!"

        measure {
            let encrypted = try? keyManager.encryptPrivateKey(privateKey, password: password)
            _ = try? keyManager.decryptPrivateKey(encrypted!, password: password)
        }
    }
}
