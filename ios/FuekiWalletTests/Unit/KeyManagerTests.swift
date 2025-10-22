import XCTest
import CryptoKit
@testable import FuekiWallet

final class KeyManagerTests: XCTestCase {

    var keyManager: KeyManager!
    var mockSecureStorage: MockSecureStorage!

    override func setUp() {
        super.setUp()
        mockSecureStorage = MockSecureStorage()
        keyManager = KeyManager(secureStorage: mockSecureStorage)
    }

    override func tearDown() {
        keyManager = nil
        mockSecureStorage = nil
        super.tearDown()
    }

    // MARK: - Key Generation Tests

    func testGeneratePrivateKey_Success() throws {
        // When
        let privateKey = try keyManager.generatePrivateKey()

        // Then
        XCTAssertEqual(privateKey.count, 32, "Private key should be 32 bytes")
        XCTAssertFalse(privateKey.allSatisfy { $0 == 0 }, "Private key should not be all zeros")
    }

    func testGeneratePrivateKey_Uniqueness() throws {
        // When
        let key1 = try keyManager.generatePrivateKey()
        let key2 = try keyManager.generatePrivateKey()

        // Then
        XCTAssertNotEqual(key1, key2, "Generated keys should be unique")
    }

    func testDerivePublicKey_FromPrivateKey_Success() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()

        // When
        let publicKey = try keyManager.derivePublicKey(from: privateKey)

        // Then
        XCTAssertTrue(publicKey.count == 33 || publicKey.count == 65, "Public key should be 33 (compressed) or 65 (uncompressed) bytes")
    }

    func testDerivePublicKey_InvalidPrivateKey_ThrowsError() {
        // Given
        let invalidKey = Data(repeating: 0xFF, count: 16) // Too short

        // When/Then
        XCTAssertThrowsError(try keyManager.derivePublicKey(from: invalidKey)) { error in
            XCTAssertTrue(error is CryptoError)
        }
    }

    // MARK: - Address Derivation Tests

    func testDeriveAddress_FromPublicKey_TestnetSegWit() throws {
        // Given
        let publicKey = Data(hex: "0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")

        // When
        let address = try keyManager.deriveAddress(from: publicKey, network: .testnet, format: .segwit)

        // Then
        XCTAssertTrue(address.starts(with: "tb1"), "Testnet SegWit addresses should start with 'tb1'")
        XCTAssertGreaterThan(address.count, 20, "Address should have reasonable length")
    }

    func testDeriveAddress_FromPublicKey_MainnetSegWit() throws {
        // Given
        let publicKey = Data(hex: "0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")

        // When
        let address = try keyManager.deriveAddress(from: publicKey, network: .mainnet, format: .segwit)

        // Then
        XCTAssertTrue(address.starts(with: "bc1"), "Mainnet SegWit addresses should start with 'bc1'")
    }

    func testDeriveAddress_FromPublicKey_Legacy() throws {
        // Given
        let publicKey = Data(hex: "0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")

        // When
        let address = try keyManager.deriveAddress(from: publicKey, network: .testnet, format: .legacy)

        // Then
        XCTAssertTrue(address.starts(with: "m") || address.starts(with: "n"), "Testnet legacy addresses should start with 'm' or 'n'")
    }

    func testValidateAddress_ValidSegWit_ReturnsTrue() {
        // Given
        let validAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        // When
        let isValid = keyManager.validateAddress(validAddress, network: .testnet)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateAddress_InvalidChecksum_ReturnsFalse() {
        // Given
        let invalidAddress = "tb1qinvalidchecksumhere"

        // When
        let isValid = keyManager.validateAddress(invalidAddress, network: .testnet)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateAddress_WrongNetwork_ReturnsFalse() {
        // Given
        let mainnetAddress = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"

        // When
        let isValid = keyManager.validateAddress(mainnetAddress, network: .testnet)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Encryption/Decryption Tests

    func testEncryptPrivateKey_Success() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"

        // When
        let encryptedData = try keyManager.encryptPrivateKey(privateKey, password: password)

        // Then
        XCTAssertNotEqual(encryptedData, privateKey, "Encrypted data should differ from plaintext")
        XCTAssertGreaterThan(encryptedData.count, 32, "Encrypted data should include IV and MAC")
    }

    func testDecryptPrivateKey_CorrectPassword_Success() throws {
        // Given
        let originalKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"
        let encryptedData = try keyManager.encryptPrivateKey(originalKey, password: password)

        // When
        let decryptedKey = try keyManager.decryptPrivateKey(encryptedData, password: password)

        // Then
        XCTAssertEqual(decryptedKey, originalKey, "Decrypted key should match original")
    }

    func testDecryptPrivateKey_IncorrectPassword_ThrowsError() throws {
        // Given
        let originalKey = try keyManager.generatePrivateKey()
        let encryptedData = try keyManager.encryptPrivateKey(originalKey, password: "CorrectPassword")

        // When/Then
        XCTAssertThrowsError(
            try keyManager.decryptPrivateKey(encryptedData, password: "WrongPassword")
        ) { error in
            XCTAssertTrue(error is CryptoError)
        }
    }

    func testEncryptDecrypt_EmptyPassword_ThrowsError() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()

        // When/Then
        XCTAssertThrowsError(
            try keyManager.encryptPrivateKey(privateKey, password: "")
        ) { error in
            XCTAssertTrue(error is CryptoError.weakPassword)
        }
    }

    // MARK: - Signing Tests

    func testSignMessage_Success() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let message = "Test message to sign".data(using: .utf8)!

        // When
        let signature = try keyManager.sign(message, with: privateKey)

        // Then
        XCTAssertEqual(signature.count, 64, "ECDSA signature should be 64 bytes")
    }

    func testVerifySignature_ValidSignature_ReturnsTrue() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let publicKey = try keyManager.derivePublicKey(from: privateKey)
        let message = "Test message to sign".data(using: .utf8)!
        let signature = try keyManager.sign(message, with: privateKey)

        // When
        let isValid = try keyManager.verifySignature(signature, for: message, publicKey: publicKey)

        // Then
        XCTAssertTrue(isValid)
    }

    func testVerifySignature_ModifiedMessage_ReturnsFalse() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let publicKey = try keyManager.derivePublicKey(from: privateKey)
        let message = "Original message".data(using: .utf8)!
        let signature = try keyManager.sign(message, with: privateKey)
        let modifiedMessage = "Modified message".data(using: .utf8)!

        // When
        let isValid = try keyManager.verifySignature(signature, for: modifiedMessage, publicKey: publicKey)

        // Then
        XCTAssertFalse(isValid)
    }

    func testVerifySignature_WrongPublicKey_ReturnsFalse() throws {
        // Given
        let privateKey1 = try keyManager.generatePrivateKey()
        let privateKey2 = try keyManager.generatePrivateKey()
        let publicKey2 = try keyManager.derivePublicKey(from: privateKey2)
        let message = "Test message".data(using: .utf8)!
        let signature = try keyManager.sign(message, with: privateKey1)

        // When
        let isValid = try keyManager.verifySignature(signature, for: message, publicKey: publicKey2)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - HD Wallet (BIP32) Tests

    func testDerivePath_BIP44_Success() throws {
        // Given
        let seed = Data(repeating: 0x01, count: 64)
        let path = "m/44'/0'/0'/0/0" // BIP44 path for first Bitcoin address

        // When
        let derivedKey = try keyManager.deriveKey(from: seed, path: path)

        // Then
        XCTAssertEqual(derivedKey.count, 32)
    }

    func testDerivePath_BIP84_SegWit_Success() throws {
        // Given
        let seed = Data(repeating: 0x01, count: 64)
        let path = "m/84'/0'/0'/0/0" // BIP84 path for SegWit

        // When
        let derivedKey = try keyManager.deriveKey(from: seed, path: path)

        // Then
        XCTAssertEqual(derivedKey.count, 32)
    }

    func testDerivePath_InvalidPath_ThrowsError() throws {
        // Given
        let seed = Data(repeating: 0x01, count: 64)
        let invalidPath = "invalid/path"

        // When/Then
        XCTAssertThrowsError(try keyManager.deriveKey(from: seed, path: invalidPath))
    }

    func testDerivePath_HardenedAndNonHardened() throws {
        // Given
        let seed = Data(repeating: 0x01, count: 64)
        let hardenedPath = "m/44'/0'/0'" // Hardened
        let nonHardenedPath = "m/44'/0'/0'/0/0" // Mixed

        // When
        let key1 = try keyManager.deriveKey(from: seed, path: hardenedPath)
        let key2 = try keyManager.deriveKey(from: seed, path: nonHardenedPath)

        // Then
        XCTAssertNotEqual(key1, key2)
        XCTAssertEqual(key1.count, 32)
        XCTAssertEqual(key2.count, 32)
    }

    // MARK: - Key Storage Tests

    func testStorePrivateKey_Success() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"

        // When
        try keyManager.storePrivateKey(privateKey, password: password)

        // Then
        XCTAssertTrue(mockSecureStorage.storeWasCalled)
        XCTAssertNotNil(mockSecureStorage.storedData["encryptedPrivateKey"])
    }

    func testRetrievePrivateKey_Success() throws {
        // Given
        let originalKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"
        try keyManager.storePrivateKey(originalKey, password: password)

        // When
        let retrievedKey = try keyManager.retrievePrivateKey(password: password)

        // Then
        XCTAssertEqual(retrievedKey, originalKey)
    }

    func testDeletePrivateKey_Success() throws {
        // Given
        let privateKey = try keyManager.generatePrivateKey()
        try keyManager.storePrivateKey(privateKey, password: "Password123!")

        // When
        try keyManager.deletePrivateKey()

        // Then
        XCTAssertTrue(mockSecureStorage.deleteWasCalled)
    }

    // MARK: - Secure Memory Tests

    func testClearKeys_ZeroesOutMemory() {
        // Given
        var sensitiveData = Data(repeating: 0xFF, count: 32)

        // When
        keyManager.clearSensitiveData(&sensitiveData)

        // Then
        XCTAssertTrue(sensitiveData.allSatisfy { $0 == 0 }, "Sensitive data should be zeroed")
    }

    // MARK: - Edge Cases

    func testKeyGeneration_MaximumEntropy() throws {
        // Generate multiple keys and check entropy
        let keys = try (0..<100).map { _ in try keyManager.generatePrivateKey() }

        // Check uniqueness
        let uniqueKeys = Set(keys)
        XCTAssertEqual(uniqueKeys.count, keys.count, "All generated keys should be unique")
    }

    func testEncryption_LargeData() throws {
        // Given
        let largeData = Data(repeating: 0x42, count: 1024 * 1024) // 1MB
        let password = "SecurePassword123!"

        // When
        let encrypted = try keyManager.encrypt(largeData, password: password)
        let decrypted = try keyManager.decrypt(encrypted, password: password)

        // Then
        XCTAssertEqual(decrypted, largeData)
    }

    func testConcurrentKeyGeneration() throws {
        let expectation = XCTestExpectation(description: "Concurrent key generation")
        expectation.expectedFulfillmentCount = 10

        DispatchQueue.concurrentPerform(iterations: 10) { _ in
            do {
                let key = try keyManager.generatePrivateKey()
                XCTAssertEqual(key.count, 32)
                expectation.fulfill()
            } catch {
                XCTFail("Key generation failed: \(error)")
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - Performance Tests

    func testKeyGenerationPerformance() {
        measure {
            _ = try? keyManager.generatePrivateKey()
        }
    }

    func testEncryptionPerformance() throws {
        let privateKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"

        measure {
            _ = try? keyManager.encryptPrivateKey(privateKey, password: password)
        }
    }

    func testDecryptionPerformance() throws {
        let privateKey = try keyManager.generatePrivateKey()
        let password = "SecurePassword123!"
        let encrypted = try keyManager.encryptPrivateKey(privateKey, password: password)

        measure {
            _ = try? keyManager.decryptPrivateKey(encrypted, password: password)
        }
    }

    func testSigningPerformance() throws {
        let privateKey = try keyManager.generatePrivateKey()
        let message = "Test message".data(using: .utf8)!

        measure {
            _ = try? keyManager.sign(message, with: privateKey)
        }
    }

    func testVerificationPerformance() throws {
        let privateKey = try keyManager.generatePrivateKey()
        let publicKey = try keyManager.derivePublicKey(from: privateKey)
        let message = "Test message".data(using: .utf8)!
        let signature = try keyManager.sign(message, with: privateKey)

        measure {
            _ = try? keyManager.verifySignature(signature, for: message, publicKey: publicKey)
        }
    }
}

// MARK: - Data Extension for Hex Conversion

extension Data {
    init(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hex.index(hex.startIndex, offsetBy: i*2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            }
        }
        self = data
    }
}
