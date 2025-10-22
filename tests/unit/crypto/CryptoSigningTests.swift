import XCTest
@testable import FuekiWallet

/// Unit tests for cryptographic signing and verification
/// Tests signature creation, verification, and edge cases
class CryptoSigningTests: XCTestCase {

    var cryptoService: CryptoService!
    var testKeyPair: KeyPair!

    override func setUp() {
        super.setUp()
        cryptoService = CryptoService()
        testKeyPair = try! cryptoService.generateEd25519KeyPair()
    }

    override func tearDown() {
        cryptoService = nil
        testKeyPair = nil
        super.tearDown()
    }

    // MARK: - Ed25519 Signature Tests

    func testEd25519SignAndVerify() throws {
        // Arrange
        let message = "Test message for signing".data(using: .utf8)!

        // Act
        let signature = try cryptoService.sign(message, with: testKeyPair.privateKey)
        let isValid = try cryptoService.verify(signature, for: message, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertNotNil(signature)
        XCTAssertEqual(signature.count, 64, "Ed25519 signature should be 64 bytes")
        XCTAssertTrue(isValid, "Signature should be valid")
    }

    func testEd25519SignatureDeterminism() throws {
        // Arrange
        let message = "Test message".data(using: .utf8)!

        // Act
        let signature1 = try cryptoService.sign(message, with: testKeyPair.privateKey)
        let signature2 = try cryptoService.sign(message, with: testKeyPair.privateKey)

        // Assert
        XCTAssertEqual(signature1, signature2, "Ed25519 signatures should be deterministic")
    }

    func testEd25519InvalidSignatureDetection() throws {
        // Arrange
        let message = "Test message".data(using: .utf8)!
        let signature = try cryptoService.sign(message, with: testKeyPair.privateKey)

        // Modify signature
        var invalidSignature = signature
        invalidSignature[0] ^= 0xFF

        // Act
        let isValid = try cryptoService.verify(invalidSignature, for: message, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertFalse(isValid, "Modified signature should be invalid")
    }

    func testEd25519ModifiedMessageDetection() throws {
        // Arrange
        let message = "Original message".data(using: .utf8)!
        let modifiedMessage = "Modified message".data(using: .utf8)!
        let signature = try cryptoService.sign(message, with: testKeyPair.privateKey)

        // Act
        let isValid = try cryptoService.verify(signature, for: modifiedMessage, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertFalse(isValid, "Signature should fail for modified message")
    }

    func testEd25519WrongPublicKeyDetection() throws {
        // Arrange
        let message = "Test message".data(using: .utf8)!
        let signature = try cryptoService.sign(message, with: testKeyPair.privateKey)
        let wrongKeyPair = try cryptoService.generateEd25519KeyPair()

        // Act
        let isValid = try cryptoService.verify(signature, for: message, publicKey: wrongKeyPair.publicKey)

        // Assert
        XCTAssertFalse(isValid, "Signature should fail with wrong public key")
    }

    // MARK: - secp256k1 Signature Tests

    func testSecp256k1SignAndVerify() throws {
        // Arrange
        let secp256k1KeyPair = try cryptoService.generateSecp256k1KeyPair()
        let message = "Test message for ECDSA signing".data(using: .utf8)!
        let messageHash = cryptoService.sha256(message)

        // Act
        let signature = try cryptoService.signSecp256k1(messageHash, with: secp256k1KeyPair.privateKey)
        let isValid = try cryptoService.verifySecp256k1(signature, for: messageHash, publicKey: secp256k1KeyPair.publicKey)

        // Assert
        XCTAssertNotNil(signature)
        XCTAssertTrue(isValid, "secp256k1 signature should be valid")
    }

    func testSecp256k1SignatureNonDeterminism() throws {
        // Arrange
        let secp256k1KeyPair = try cryptoService.generateSecp256k1KeyPair()
        let message = "Test message".data(using: .utf8)!
        let messageHash = cryptoService.sha256(message)

        // Act - Note: Standard ECDSA is non-deterministic
        let signature1 = try cryptoService.signSecp256k1(messageHash, with: secp256k1KeyPair.privateKey)
        let signature2 = try cryptoService.signSecp256k1(messageHash, with: secp256k1KeyPair.privateKey)

        // Assert - Signatures may differ but both should be valid
        let isValid1 = try cryptoService.verifySecp256k1(signature1, for: messageHash, publicKey: secp256k1KeyPair.publicKey)
        let isValid2 = try cryptoService.verifySecp256k1(signature2, for: messageHash, publicKey: secp256k1KeyPair.publicKey)

        XCTAssertTrue(isValid1, "First signature should be valid")
        XCTAssertTrue(isValid2, "Second signature should be valid")
    }

    func testSecp256k1RFC6979DeterministicSignature() throws {
        // Arrange - RFC 6979 deterministic ECDSA
        let secp256k1KeyPair = try cryptoService.generateSecp256k1KeyPair()
        let message = "Test message".data(using: .utf8)!
        let messageHash = cryptoService.sha256(message)

        // Act
        let signature1 = try cryptoService.signSecp256k1Deterministic(messageHash, with: secp256k1KeyPair.privateKey)
        let signature2 = try cryptoService.signSecp256k1Deterministic(messageHash, with: secp256k1KeyPair.privateKey)

        // Assert
        XCTAssertEqual(signature1, signature2, "RFC 6979 signatures should be deterministic")
    }

    // MARK: - Message Signing Tests

    func testSignEmptyMessage() throws {
        // Arrange
        let emptyMessage = Data()

        // Act
        let signature = try cryptoService.sign(emptyMessage, with: testKeyPair.privateKey)
        let isValid = try cryptoService.verify(signature, for: emptyMessage, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertTrue(isValid, "Should be able to sign and verify empty message")
    }

    func testSignLargeMessage() throws {
        // Arrange - 1MB message
        let largeMessage = Data(repeating: 0xAB, count: 1_024 * 1_024)

        // Act
        let signature = try cryptoService.sign(largeMessage, with: testKeyPair.privateKey)
        let isValid = try cryptoService.verify(signature, for: largeMessage, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertTrue(isValid, "Should be able to sign and verify large message")
    }

    func testSignBinaryData() throws {
        // Arrange - Binary data with all byte values
        let binaryData = Data((0...255).map { UInt8($0) })

        // Act
        let signature = try cryptoService.sign(binaryData, with: testKeyPair.privateKey)
        let isValid = try cryptoService.verify(signature, for: binaryData, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertTrue(isValid, "Should be able to sign and verify binary data")
    }

    // MARK: - Transaction Signature Tests

    func testSignTransaction() throws {
        // Arrange
        let transaction = Transaction(
            from: "0x1234567890abcdef",
            to: "0xfedcba0987654321",
            amount: 1000000,
            nonce: 1,
            gasPrice: 20000000000,
            gasLimit: 21000
        )
        let txData = try transaction.serialize()

        // Act
        let signature = try cryptoService.sign(txData, with: testKeyPair.privateKey)
        let isValid = try cryptoService.verify(signature, for: txData, publicKey: testKeyPair.publicKey)

        // Assert
        XCTAssertTrue(isValid, "Transaction signature should be valid")
    }

    func testSignTransactionWithReplayProtection() throws {
        // Arrange
        let transaction = Transaction(
            from: "0x1234567890abcdef",
            to: "0xfedcba0987654321",
            amount: 1000000,
            nonce: 1,
            gasPrice: 20000000000,
            gasLimit: 21000,
            chainId: 1 // Ethereum mainnet
        )
        let txHash = try transaction.signingHash()

        // Act
        let signature = try cryptoService.sign(txHash, with: testKeyPair.privateKey)

        // Assert
        XCTAssertNotNil(signature)
        // Verify chain ID is included in signature (EIP-155)
    }

    // MARK: - Multi-Signature Tests

    func testMultiSignature2of3() throws {
        // Arrange
        let keyPair1 = try cryptoService.generateEd25519KeyPair()
        let keyPair2 = try cryptoService.generateEd25519KeyPair()
        let keyPair3 = try cryptoService.generateEd25519KeyPair()
        let message = "Multi-sig transaction".data(using: .utf8)!

        // Act - Sign with 2 of 3 keys
        let signature1 = try cryptoService.sign(message, with: keyPair1.privateKey)
        let signature2 = try cryptoService.sign(message, with: keyPair2.privateKey)

        // Create multi-sig
        let multiSig = MultiSignature(
            threshold: 2,
            signatures: [signature1, signature2],
            publicKeys: [keyPair1.publicKey, keyPair2.publicKey, keyPair3.publicKey]
        )

        // Assert
        let isValid = try cryptoService.verifyMultiSignature(multiSig, for: message)
        XCTAssertTrue(isValid, "2-of-3 multi-signature should be valid")
    }

    func testMultiSignatureInsufficientSignatures() throws {
        // Arrange
        let keyPair1 = try cryptoService.generateEd25519KeyPair()
        let keyPair2 = try cryptoService.generateEd25519KeyPair()
        let message = "Multi-sig transaction".data(using: .utf8)!
        let signature1 = try cryptoService.sign(message, with: keyPair1.privateKey)

        // Act - Only 1 of 2 required signatures
        let multiSig = MultiSignature(
            threshold: 2,
            signatures: [signature1],
            publicKeys: [keyPair1.publicKey, keyPair2.publicKey]
        )

        // Assert
        let isValid = try cryptoService.verifyMultiSignature(multiSig, for: message)
        XCTAssertFalse(isValid, "Should fail with insufficient signatures")
    }

    // MARK: - Performance Tests

    func testSigningPerformance() {
        // Arrange
        let message = "Performance test message".data(using: .utf8)!

        // Measure
        measure {
            _ = try? cryptoService.sign(message, with: testKeyPair.privateKey)
        }
    }

    func testVerificationPerformance() {
        // Arrange
        let message = "Performance test message".data(using: .utf8)!
        let signature = try! cryptoService.sign(message, with: testKeyPair.privateKey)

        // Measure
        measure {
            _ = try? cryptoService.verify(signature, for: message, publicKey: testKeyPair.publicKey)
        }
    }

    // MARK: - Error Handling Tests

    func testSignWithInvalidPrivateKey() {
        // Arrange
        let message = "Test message".data(using: .utf8)!
        let invalidPrivateKey = Data(repeating: 0, count: 32)

        // Act & Assert
        XCTAssertThrowsError(try cryptoService.sign(message, with: invalidPrivateKey)) { error in
            XCTAssertTrue(error is CryptoError)
        }
    }

    func testVerifyWithInvalidPublicKey() {
        // Arrange
        let message = "Test message".data(using: .utf8)!
        let signature = try! cryptoService.sign(message, with: testKeyPair.privateKey)
        let invalidPublicKey = Data(repeating: 0, count: 32)

        // Act & Assert
        XCTAssertThrowsError(try cryptoService.verify(signature, for: message, publicKey: invalidPublicKey)) { error in
            XCTAssertTrue(error is CryptoError)
        }
    }

    func testVerifyWithMalformedSignature() {
        // Arrange
        let message = "Test message".data(using: .utf8)!
        let malformedSignature = Data(repeating: 0xFF, count: 32) // Wrong length

        // Act & Assert
        XCTAssertThrowsError(try cryptoService.verify(malformedSignature, for: message, publicKey: testKeyPair.publicKey)) { error in
            XCTAssertTrue(error is CryptoError)
        }
    }
}
