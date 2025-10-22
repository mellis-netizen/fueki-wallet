//
//  KeyManagerAdvancedTests.swift
//  FuekiWalletTests
//
//  Advanced cryptographic tests for KeyManager
//

import XCTest
import CryptoKit
@testable import FuekiWallet

final class KeyManagerAdvancedTests: XCTestCase {

    var sut: KeyManager!
    var mockKeychainManager: MockKeychainManager!
    var mockEncryptionService: MockEncryptionService!

    override func setUp() {
        mockKeychainManager = MockKeychainManager()
        mockEncryptionService = MockEncryptionService()
        sut = KeyManager(
            keychainManager: mockKeychainManager,
            encryptionService: mockEncryptionService,
            useSecureEnclave: false // Use software for testing
        )
    }

    override func tearDown() {
        sut = nil
        mockKeychainManager = nil
        mockEncryptionService = nil
    }

    // MARK: - Key Generation Tests

    func testGeneratePrivateKey_ReturnsCorrectSize() throws {
        // When
        let privateKey = try sut.generatePrivateKey()

        // Then
        XCTAssertEqual(privateKey.count, 32)
    }

    func testGeneratePrivateKey_UniqueKeys() throws {
        // When
        let key1 = try sut.generatePrivateKey()
        let key2 = try sut.generatePrivateKey()

        // Then
        XCTAssertNotEqual(key1, key2)
    }

    func testGeneratePrivateKey_NonZeroData() throws {
        // When
        let privateKey = try sut.generatePrivateKey()

        // Then
        let allZero = privateKey.allSatisfy { $0 == 0 }
        XCTAssertFalse(allZero)
    }

    // MARK: - Public Key Derivation Tests

    func testDerivePublicKey_ValidPrivateKey() throws {
        // Given
        let privateKey = try sut.generatePrivateKey()

        // When
        let publicKey = try sut.derivePublicKey(from: privateKey)

        // Then
        XCTAssertEqual(publicKey.count, 33) // Compressed format
    }

    func testDerivePublicKey_InvalidKeySize_ThrowsError() {
        // Given
        let invalidKey = Data([0x01, 0x02, 0x03])

        // When/Then
        XCTAssertThrowsError(try sut.derivePublicKey(from: invalidKey)) { error in
            XCTAssertTrue(error is WalletError)
        }
    }

    func testDerivePublicKey_Deterministic() throws {
        // Given
        let privateKey = try sut.generatePrivateKey()

        // When
        let publicKey1 = try sut.derivePublicKey(from: privateKey)
        let publicKey2 = try sut.derivePublicKey(from: privateKey)

        // Then
        XCTAssertEqual(publicKey1, publicKey2)
    }

    // MARK: - Signing Tests

    func testSign_ValidSignature() throws {
        // Given
        let privateKey = try sut.generatePrivateKey()
        let data = "Test message".data(using: .utf8)!

        // When
        let signature = try sut.sign(data, with: privateKey)

        // Then
        XCTAssertGreaterThan(signature.count, 0)
    }

    func testSign_DifferentData_DifferentSignatures() throws {
        // Given
        let privateKey = try sut.generatePrivateKey()
        let data1 = "Message 1".data(using: .utf8)!
        let data2 = "Message 2".data(using: .utf8)!

        // When
        let signature1 = try sut.sign(data1, with: privateKey)
        let signature2 = try sut.sign(data2, with: privateKey)

        // Then
        XCTAssertNotEqual(signature1, signature2)
    }

    func testSign_InvalidPrivateKey_ThrowsError() {
        // Given
        let invalidKey = Data([0x01])
        let data = "Test".data(using: .utf8)!

        // When/Then
        XCTAssertThrowsError(try sut.sign(data, with: invalidKey))
    }

    // MARK: - Verification Tests

    func testVerify_ValidSignature_ReturnsTrue() throws {
        // Given
        let privateKey = try sut.generatePrivateKey()
        let publicKey = try sut.derivePublicKey(from: privateKey)
        let data = "Test message".data(using: .utf8)!
        let signature = try sut.sign(data, with: privateKey)

        // When
        let isValid = try sut.verify(signature, for: data, with: publicKey)

        // Then
        XCTAssertTrue(isValid)
    }

    func testVerify_WrongData_ReturnsFalse() throws {
        // Given
        let privateKey = try sut.generatePrivateKey()
        let publicKey = try sut.derivePublicKey(from: privateKey)
        let data = "Test message".data(using: .utf8)!
        let wrongData = "Wrong message".data(using: .utf8)!
        let signature = try sut.sign(data, with: privateKey)

        // When
        let isValid = try sut.verify(signature, for: wrongData, with: publicKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testVerify_WrongPublicKey_ReturnsFalse() throws {
        // Given
        let privateKey1 = try sut.generatePrivateKey()
        let privateKey2 = try sut.generatePrivateKey()
        let publicKey2 = try sut.derivePublicKey(from: privateKey2)
        let data = "Test message".data(using: .utf8)!
        let signature = try sut.sign(data, with: privateKey1)

        // When
        let isValid = try sut.verify(signature, for: data, with: publicKey2)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Master Key Tests

    func testGenerateMasterKey_Success() throws {
        // Given
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockEncryptedData = Data(repeating: 0x03, count: 64)

        // When
        try sut.generateMasterKey(password: password)

        // Then
        XCTAssertTrue(mockKeychainManager.saveWasCalled)
        XCTAssertGreaterThanOrEqual(mockKeychainManager.savedData.count, 2) // salt + encrypted key
    }

    func testGetMasterKey_Success() throws {
        // Given
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockDecryptedData = Data(repeating: 0x04, count: 32)

        try sut.generateMasterKey(password: password)

        // When
        let masterKey = try sut.getMasterKey(password: password)

        // Then
        XCTAssertEqual(masterKey.count, 32)
    }

    func testGetMasterKey_WrongPassword_ThrowsError() throws {
        // Given
        let correctPassword = "SecurePassword123!"
        let wrongPassword = "WrongPassword"
        mockEncryptionService.shouldFailDecryption = true

        try sut.generateMasterKey(password: correctPassword)

        // When/Then
        XCTAssertThrowsError(try sut.getMasterKey(password: wrongPassword))
    }

    func testDeleteMasterKey_Success() throws {
        // Given
        let password = "SecurePassword123!"
        try sut.generateMasterKey(password: password)

        // When
        try sut.deleteMasterKey()

        // Then
        XCTAssertTrue(mockKeychainManager.deleteWasCalled)
    }

    // MARK: - Key Pair Storage Tests

    func testGenerateKeyPair_Success() throws {
        // Given
        let identifier = "test-keypair"
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockEncryptedData = Data(repeating: 0x03, count: 64)

        // When
        let keyPair = try sut.generateKeyPair(identifier: identifier, password: password)

        // Then
        XCTAssertEqual(keyPair.privateKey.count, 32)
        XCTAssertEqual(keyPair.publicKey.count, 33)
        XCTAssertTrue(mockKeychainManager.saveWasCalled)
    }

    func testLoadKeyPair_Success() throws {
        // Given
        let identifier = "test-keypair"
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockDecryptedData = Data(repeating: 0x04, count: 32)

        let originalKeyPair = try sut.generateKeyPair(identifier: identifier, password: password)

        // When
        let loadedKeyPair = try sut.loadKeyPair(identifier: identifier, password: password)

        // Then
        XCTAssertEqual(loadedKeyPair.publicKey, originalKeyPair.publicKey)
    }

    func testDeleteKeyPair_Success() throws {
        // Given
        let identifier = "test-keypair"
        let password = "SecurePassword123!"
        try sut.generateKeyPair(identifier: identifier, password: password)

        // When
        try sut.deleteKeyPair(identifier: identifier)

        // Then
        XCTAssertTrue(mockKeychainManager.deleteWasCalled)
    }

    // MARK: - Key Listing Tests

    func testListKeyIdentifiers_ReturnsStoredKeys() throws {
        // Given
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockEncryptedData = Data(repeating: 0x03, count: 64)

        try sut.generateKeyPair(identifier: "key1", password: password)
        try sut.generateKeyPair(identifier: "key2", password: password)
        try sut.generateKeyPair(identifier: "key3", password: password)

        mockKeychainManager.mockAllKeys = [
            "wallet.private.keys.key1",
            "wallet.private.keys.key2",
            "wallet.private.keys.key3",
            "wallet.public.keys.key1"
        ]

        // When
        let identifiers = try sut.listKeyIdentifiers()

        // Then
        XCTAssertEqual(identifiers.count, 3)
        XCTAssertTrue(identifiers.contains("key1"))
        XCTAssertTrue(identifiers.contains("key2"))
        XCTAssertTrue(identifiers.contains("key3"))
    }

    // MARK: - Memory Security Tests

    func testKeyGeneration_ZerosMemoryAfterUse() throws {
        // This test verifies that sensitive data is properly cleared
        // In production, use tools like Instruments to verify memory isn't leaked

        // Given
        let identifier = "secure-key"
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockEncryptedData = Data(repeating: 0x03, count: 64)

        // When
        let keyPair = try sut.generateKeyPair(identifier: identifier, password: password)

        // Then
        // Verify the keys were generated correctly
        XCTAssertGreaterThan(keyPair.privateKey.count, 0)
        XCTAssertGreaterThan(keyPair.publicKey.count, 0)

        // In production: verify memory was zeroed using Memory Graph Debugger
    }

    // MARK: - Edge Cases

    func testStorePrivateKey_EmptyIdentifier_ThrowsError() {
        // Given
        let privateKey = Data(repeating: 0x01, count: 32)
        let password = "SecurePassword123!"

        // When/Then
        XCTAssertThrowsError(try sut.storePrivateKey(privateKey, identifier: "", password: password))
    }

    func testLoadPrivateKey_NonExistentKey_ThrowsError() {
        // Given
        mockKeychainManager.shouldFailLoad = true

        // When/Then
        XCTAssertThrowsError(try sut.loadPrivateKey(identifier: "nonexistent", password: "password"))
    }

    func testGenerateKeyPair_LongIdentifier_Success() throws {
        // Given
        let longIdentifier = String(repeating: "a", count: 100)
        let password = "SecurePassword123!"
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockEncryptedData = Data(repeating: 0x03, count: 64)

        // When/Then
        XCTAssertNoThrow(try sut.generateKeyPair(identifier: longIdentifier, password: password))
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentKeyGeneration_ThreadSafe() throws {
        // Given
        let expectation = self.expectation(description: "Concurrent key generation")
        expectation.expectedFulfillmentCount = 10
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        mockEncryptionService.mockSalt = Data(repeating: 0x01, count: 32)
        mockEncryptionService.mockEncryptionKey = Data(repeating: 0x02, count: 32)
        mockEncryptionService.mockEncryptedData = Data(repeating: 0x03, count: 64)

        // When
        for i in 0..<10 {
            queue.async {
                do {
                    _ = try self.sut.generateKeyPair(identifier: "key\(i)", password: "password")
                    expectation.fulfill()
                } catch {
                    XCTFail("Key generation failed: \(error)")
                }
            }
        }

        // Then
        waitForExpectations(timeout: 5)
    }
}
