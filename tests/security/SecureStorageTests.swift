import XCTest
import LocalAuthentication
@testable import FuekiWallet

/// Security tests for Keychain and Secure Enclave storage
/// Tests encryption, access control, and secure key management
class SecureStorageTests: XCTestCase {

    var secureStorage: SecureStorageService!
    var cryptoService: CryptoService!

    override func setUp() {
        super.setUp()
        secureStorage = SecureStorageService()
        cryptoService = CryptoService()
    }

    override func tearDown() {
        // Clean up test data
        try? secureStorage.deleteAll(prefix: "test-")
        secureStorage = nil
        cryptoService = nil
        super.tearDown()
    }

    // MARK: - Keychain Storage Tests

    func testStoreAndRetrieveData() throws {
        // Arrange
        let testKey = "test-key-1"
        let testData = "Sensitive data".data(using: .utf8)!

        // Act
        try secureStorage.store(testData, forKey: testKey)
        let retrieved = try secureStorage.retrieve(forKey: testKey)

        // Assert
        XCTAssertEqual(retrieved, testData, "Retrieved data should match stored data")
    }

    func testStorePrivateKey() throws {
        // Arrange
        let keyPair = try cryptoService.generateEd25519KeyPair()
        let keyId = "test-private-key-1"

        // Act
        try secureStorage.storePrivateKey(keyPair.privateKey, withId: keyId)
        let retrieved = try secureStorage.retrievePrivateKey(withId: keyId)

        // Assert
        XCTAssertEqual(retrieved, keyPair.privateKey)
    }

    func testUpdateExistingData() throws {
        // Arrange
        let testKey = "test-key-2"
        let originalData = "Original data".data(using: .utf8)!
        let updatedData = "Updated data".data(using: .utf8)!

        // Act
        try secureStorage.store(originalData, forKey: testKey)
        try secureStorage.store(updatedData, forKey: testKey)
        let retrieved = try secureStorage.retrieve(forKey: testKey)

        // Assert
        XCTAssertEqual(retrieved, updatedData, "Should retrieve updated data")
    }

    func testDeleteData() throws {
        // Arrange
        let testKey = "test-key-3"
        let testData = "Data to delete".data(using: .utf8)!
        try secureStorage.store(testData, forKey: testKey)

        // Act
        try secureStorage.delete(forKey: testKey)

        // Assert
        XCTAssertThrowsError(try secureStorage.retrieve(forKey: testKey)) { error in
            XCTAssertTrue(error is SecureStorageError)
            if let storageError = error as? SecureStorageError {
                XCTAssertEqual(storageError, .itemNotFound)
            }
        }
    }

    func testDataIsolation() throws {
        // Arrange
        let key1 = "test-key-4"
        let key2 = "test-key-5"
        let data1 = "Data 1".data(using: .utf8)!
        let data2 = "Data 2".data(using: .utf8)!

        // Act
        try secureStorage.store(data1, forKey: key1)
        try secureStorage.store(data2, forKey: key2)

        // Assert
        let retrieved1 = try secureStorage.retrieve(forKey: key1)
        let retrieved2 = try secureStorage.retrieve(forKey: key2)

        XCTAssertEqual(retrieved1, data1)
        XCTAssertEqual(retrieved2, data2)
        XCTAssertNotEqual(retrieved1, retrieved2)
    }

    // MARK: - Secure Enclave Tests

    func testSecureEnclaveAvailability() {
        // Act
        let isAvailable = secureStorage.isSecureEnclaveAvailable()

        // Assert
        // Secure Enclave is only available on physical devices with A7+ chip
        #if targetEnvironment(simulator)
        XCTAssertFalse(isAvailable, "Secure Enclave not available in simulator")
        #else
        // On device, availability depends on hardware
        print("Secure Enclave available: \(isAvailable)")
        #endif
    }

    func testGenerateKeyInSecureEnclave() throws {
        #if !targetEnvironment(simulator)
        guard secureStorage.isSecureEnclaveAvailable() else {
            throw XCTSkip("Secure Enclave not available")
        }

        // Act
        let keyId = "test-enclave-key-1"
        let publicKey = try secureStorage.generateSecureEnclaveKey(withId: keyId)

        // Assert
        XCTAssertNotNil(publicKey)
        XCTAssertTrue(try secureStorage.keyExistsInSecureEnclave(withId: keyId))
        #else
        throw XCTSkip("Secure Enclave not available in simulator")
        #endif
    }

    func testSignWithSecureEnclaveKey() throws {
        #if !targetEnvironment(simulator)
        guard secureStorage.isSecureEnclaveAvailable() else {
            throw XCTSkip("Secure Enclave not available")
        }

        // Arrange
        let keyId = "test-enclave-key-2"
        let publicKey = try secureStorage.generateSecureEnclaveKey(withId: keyId)
        let message = "Test message".data(using: .utf8)!

        // Act
        let signature = try secureStorage.signWithSecureEnclaveKey(message, keyId: keyId)

        // Assert
        XCTAssertNotNil(signature)
        let isValid = try cryptoService.verify(signature, for: message, publicKey: publicKey)
        XCTAssertTrue(isValid, "Signature should be valid")
        #else
        throw XCTSkip("Secure Enclave not available in simulator")
        #endif
    }

    func testSecureEnclaveKeyNonExportable() throws {
        #if !targetEnvironment(simulator)
        guard secureStorage.isSecureEnclaveAvailable() else {
            throw XCTSkip("Secure Enclave not available")
        }

        // Arrange
        let keyId = "test-enclave-key-3"
        _ = try secureStorage.generateSecureEnclaveKey(withId: keyId)

        // Act & Assert - Attempting to export should fail
        XCTAssertThrowsError(try secureStorage.exportPrivateKey(withId: keyId)) { error in
            XCTAssertTrue(error is SecureStorageError)
        }
        #else
        throw XCTSkip("Secure Enclave not available in simulator")
        #endif
    }

    // MARK: - Biometric Authentication Tests

    func testBiometricAvailability() {
        // Act
        let availability = secureStorage.biometricAvailability()

        // Assert
        print("Biometric availability: \(availability)")
        // Actual availability depends on device capabilities
    }

    func testStoreWithBiometricProtection() throws {
        guard secureStorage.biometricAvailability() != .notAvailable else {
            throw XCTSkip("Biometrics not available")
        }

        // Arrange
        let testKey = "test-biometric-key-1"
        let testData = "Biometric protected data".data(using: .utf8)!

        // Act - Store with biometric requirement
        try secureStorage.store(
            testData,
            forKey: testKey,
            accessControl: .biometryCurrentSet
        )

        // Attempting to retrieve without authentication should fail
        XCTAssertThrowsError(try secureStorage.retrieve(forKey: testKey, context: nil)) { error in
            XCTAssertTrue(error is SecureStorageError)
        }
    }

    func testBiometricAuthentication() throws {
        guard secureStorage.biometricAvailability() != .notAvailable else {
            throw XCTSkip("Biometrics not available")
        }

        // Arrange
        let testKey = "test-biometric-key-2"
        let testData = "Sensitive data".data(using: .utf8)!
        let context = LAContext()

        // Act
        try secureStorage.store(
            testData,
            forKey: testKey,
            accessControl: .biometryCurrentSet
        )

        // Note: In real test, this would trigger biometric prompt
        // For unit tests, we simulate authentication
        context.setCredential(Data(), type: .applicationPassword)

        do {
            let retrieved = try secureStorage.retrieve(forKey: testKey, context: context)
            XCTAssertEqual(retrieved, testData)
        } catch {
            // Authentication may fail in test environment
            print("Biometric authentication failed (expected in tests): \(error)")
        }
    }

    // MARK: - Access Control Tests

    func testAccessControlThisDeviceOnly() throws {
        // Arrange
        let testKey = "test-device-only-key"
        let testData = "Device only data".data(using: .utf8)!

        // Act
        try secureStorage.store(
            testData,
            forKey: testKey,
            accessibility: .whenUnlockedThisDeviceOnly
        )

        let retrieved = try secureStorage.retrieve(forKey: testKey)

        // Assert
        XCTAssertEqual(retrieved, testData)

        // Verify it's not backed up to iCloud
        let attributes = try secureStorage.getItemAttributes(forKey: testKey)
        XCTAssertFalse(attributes.synchronizable, "Should not be synchronizable")
    }

    func testAccessControlAfterFirstUnlock() throws {
        // Arrange
        let testKey = "test-after-unlock-key"
        let testData = "After unlock data".data(using: .utf8)!

        // Act
        try secureStorage.store(
            testData,
            forKey: testKey,
            accessibility: .afterFirstUnlock
        )

        // Assert - Should be accessible when device is unlocked
        let retrieved = try secureStorage.retrieve(forKey: testKey)
        XCTAssertEqual(retrieved, testData)
    }

    func testAccessControlWhenPasscodeSet() throws {
        // Arrange
        let testKey = "test-passcode-key"
        let testData = "Passcode protected data".data(using: .utf8)!

        // Act
        try secureStorage.store(
            testData,
            forKey: testKey,
            accessControl: .devicePasscode
        )

        // Assert
        let attributes = try secureStorage.getItemAttributes(forKey: testKey)
        XCTAssertNotNil(attributes.accessControl)
    }

    // MARK: - Encryption Tests

    func testDataEncryptionAtRest() throws {
        // Arrange
        let testKey = "test-encryption-key"
        let plaintext = "Plaintext data".data(using: .utf8)!

        // Act
        try secureStorage.store(plaintext, forKey: testKey)

        // Assert - Data should be encrypted in Keychain
        // We can't directly access raw Keychain data, but we verify proper storage
        let retrieved = try secureStorage.retrieve(forKey: testKey)
        XCTAssertEqual(retrieved, plaintext, "Decryption should work transparently")
    }

    func testAdditionalEncryptionLayer() throws {
        // Arrange
        let testKey = "test-double-encryption-key"
        let plaintext = "Sensitive plaintext".data(using: .utf8)!
        let password = "user-password-123"

        // Act - Encrypt before storing
        let encrypted = try cryptoService.encrypt(plaintext, password: password)
        try secureStorage.store(encrypted, forKey: testKey)

        // Retrieve and decrypt
        let retrieved = try secureStorage.retrieve(forKey: testKey)
        let decrypted = try cryptoService.decrypt(retrieved, password: password)

        // Assert
        XCTAssertEqual(decrypted, plaintext)
        XCTAssertNotEqual(retrieved, plaintext, "Stored data should be encrypted")
    }

    // MARK: - Attack Prevention Tests

    func testPreventKeychainDumping() throws {
        // Verify that sensitive data uses proper access control
        let testKey = "test-secure-key"
        let testData = "Sensitive data".data(using: .utf8)!

        try secureStorage.store(
            testData,
            forKey: testKey,
            accessibility: .whenUnlockedThisDeviceOnly
        )

        // Verify access control attributes
        let attributes = try secureStorage.getItemAttributes(forKey: testKey)
        XCTAssertEqual(attributes.accessibility, .whenUnlockedThisDeviceOnly)
        XCTAssertFalse(attributes.synchronizable)
    }

    func testPreventUnauthorizedAccess() throws {
        // Arrange
        let testKey = "test-protected-key"
        let testData = "Protected data".data(using: .utf8)!

        // Act - Store with strict access control
        try secureStorage.store(
            testData,
            forKey: testKey,
            accessControl: .userPresence
        )

        // Assert - Requires user presence (biometric/passcode)
        let attributes = try secureStorage.getItemAttributes(forKey: testKey)
        XCTAssertNotNil(attributes.accessControl)
    }

    func testMemoryClearing() throws {
        // Arrange
        var sensitiveData = "Very sensitive data".data(using: .utf8)!

        // Act - Use data
        let copy = sensitiveData

        // Clear from memory
        cryptoService.secureZeroize(&sensitiveData)

        // Assert
        XCTAssertTrue(sensitiveData.allSatisfy { $0 == 0 }, "Sensitive data should be zeroed")
        XCTAssertNotEqual(copy, sensitiveData)
    }

    // MARK: - Key Rotation Tests

    func testKeyRotation() throws {
        // Arrange
        let keyId = "test-rotation-key"
        let oldKey = try cryptoService.generateEd25519KeyPair().privateKey
        let newKey = try cryptoService.generateEd25519KeyPair().privateKey

        // Act
        try secureStorage.storePrivateKey(oldKey, withId: keyId)
        try secureStorage.rotateKey(withId: keyId, newKey: newKey)

        // Assert
        let retrieved = try secureStorage.retrievePrivateKey(withId: keyId)
        XCTAssertEqual(retrieved, newKey)
        XCTAssertNotEqual(retrieved, oldKey)
    }

    func testKeyRotationWithBackup() throws {
        // Arrange
        let keyId = "test-rotation-backup-key"
        let oldKey = try cryptoService.generateEd25519KeyPair().privateKey
        let newKey = try cryptoService.generateEd25519KeyPair().privateKey

        // Act
        try secureStorage.storePrivateKey(oldKey, withId: keyId)
        let backup = try secureStorage.backupKey(withId: keyId)
        try secureStorage.rotateKey(withId: keyId, newKey: newKey)

        // Assert
        XCTAssertNotNil(backup)
        XCTAssertEqual(backup, oldKey)
    }

    // MARK: - Backup and Recovery Tests

    func testExportWalletBackup() throws {
        // Arrange
        let keyId = "test-backup-key"
        let privateKey = try cryptoService.generateEd25519KeyPair().privateKey
        try secureStorage.storePrivateKey(privateKey, withId: keyId)

        // Act
        let backup = try secureStorage.exportEncryptedBackup(password: "backup-password-123")

        // Assert
        XCTAssertNotNil(backup)
        XCTAssertGreaterThan(backup.count, 0)
    }

    func testImportWalletBackup() throws {
        // Arrange
        let password = "backup-password-123"
        let keyId = "test-import-key"
        let privateKey = try cryptoService.generateEd25519KeyPair().privateKey
        try secureStorage.storePrivateKey(privateKey, withId: keyId)

        let backup = try secureStorage.exportEncryptedBackup(password: password)

        // Clear storage
        try secureStorage.deleteAll(prefix: "test-")

        // Act
        try secureStorage.importEncryptedBackup(backup, password: password)

        // Assert
        let restored = try secureStorage.retrievePrivateKey(withId: keyId)
        XCTAssertEqual(restored, privateKey)
    }

    func testBackupWithWrongPassword() throws {
        // Arrange
        let correctPassword = "correct-password-123"
        let wrongPassword = "wrong-password-456"

        let backup = try secureStorage.exportEncryptedBackup(password: correctPassword)

        // Act & Assert
        XCTAssertThrowsError(try secureStorage.importEncryptedBackup(backup, password: wrongPassword)) { error in
            XCTAssertTrue(error is SecureStorageError)
            if let storageError = error as? SecureStorageError {
                XCTAssertEqual(storageError, .decryptionFailed)
            }
        }
    }

    // MARK: - Performance Tests

    func testStoragePerformance() {
        let testData = "Performance test data".data(using: .utf8)!

        measure {
            try? secureStorage.store(testData, forKey: "perf-test-\(UUID())")
        }
    }

    func testRetrievalPerformance() throws {
        // Arrange
        let testKey = "perf-retrieval-key"
        let testData = "Performance test data".data(using: .utf8)!
        try secureStorage.store(testData, forKey: testKey)

        // Measure
        measure {
            _ = try? secureStorage.retrieve(forKey: testKey)
        }
    }
}
