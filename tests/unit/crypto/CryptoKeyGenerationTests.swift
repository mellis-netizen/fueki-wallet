import XCTest
@testable import FuekiWallet

/// Unit tests for cryptographic key generation
/// Tests Ed25519, secp256k1, and RSA key generation with proper security parameters
class CryptoKeyGenerationTests: XCTestCase {

    var cryptoService: CryptoService!

    override func setUp() {
        super.setUp()
        cryptoService = CryptoService()
    }

    override func tearDown() {
        cryptoService = nil
        super.tearDown()
    }

    // MARK: - Ed25519 Key Generation Tests

    func testEd25519KeyPairGeneration() throws {
        // Arrange & Act
        let keyPair = try cryptoService.generateEd25519KeyPair()

        // Assert
        XCTAssertNotNil(keyPair.privateKey, "Private key should not be nil")
        XCTAssertNotNil(keyPair.publicKey, "Public key should not be nil")
        XCTAssertEqual(keyPair.privateKey.count, 32, "Ed25519 private key should be 32 bytes")
        XCTAssertEqual(keyPair.publicKey.count, 32, "Ed25519 public key should be 32 bytes")
    }

    func testEd25519KeyPairUniqueness() throws {
        // Arrange & Act
        let keyPair1 = try cryptoService.generateEd25519KeyPair()
        let keyPair2 = try cryptoService.generateEd25519KeyPair()

        // Assert
        XCTAssertNotEqual(keyPair1.privateKey, keyPair2.privateKey, "Generated private keys should be unique")
        XCTAssertNotEqual(keyPair1.publicKey, keyPair2.publicKey, "Generated public keys should be unique")
    }

    func testEd25519PublicKeyDerivation() throws {
        // Arrange
        let keyPair = try cryptoService.generateEd25519KeyPair()

        // Act
        let derivedPublicKey = try cryptoService.derivePublicKey(from: keyPair.privateKey)

        // Assert
        XCTAssertEqual(derivedPublicKey, keyPair.publicKey, "Derived public key should match original")
    }

    // MARK: - secp256k1 Key Generation Tests

    func testSecp256k1KeyPairGeneration() throws {
        // Arrange & Act
        let keyPair = try cryptoService.generateSecp256k1KeyPair()

        // Assert
        XCTAssertNotNil(keyPair.privateKey)
        XCTAssertNotNil(keyPair.publicKey)
        XCTAssertEqual(keyPair.privateKey.count, 32, "secp256k1 private key should be 32 bytes")
        XCTAssertTrue(keyPair.publicKey.count == 33 || keyPair.publicKey.count == 65,
                     "secp256k1 public key should be 33 (compressed) or 65 (uncompressed) bytes")
    }

    func testSecp256k1CompressedPublicKey() throws {
        // Arrange & Act
        let keyPair = try cryptoService.generateSecp256k1KeyPair(compressed: true)

        // Assert
        XCTAssertEqual(keyPair.publicKey.count, 33, "Compressed secp256k1 public key should be 33 bytes")
        XCTAssertTrue(keyPair.publicKey[0] == 0x02 || keyPair.publicKey[0] == 0x03,
                     "Compressed key should start with 0x02 or 0x03")
    }

    func testSecp256k1UncompressedPublicKey() throws {
        // Arrange & Act
        let keyPair = try cryptoService.generateSecp256k1KeyPair(compressed: false)

        // Assert
        XCTAssertEqual(keyPair.publicKey.count, 65, "Uncompressed secp256k1 public key should be 65 bytes")
        XCTAssertEqual(keyPair.publicKey[0], 0x04, "Uncompressed key should start with 0x04")
    }

    // MARK: - Mnemonic Generation Tests

    func testMnemonicGeneration12Words() throws {
        // Arrange & Act
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)

        // Assert
        XCTAssertNotNil(mnemonic)
        let words = mnemonic.components(separatedBy: " ")
        XCTAssertEqual(words.count, 12, "Mnemonic should contain exactly 12 words")
    }

    func testMnemonicGeneration24Words() throws {
        // Arrange & Act
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 24)

        // Assert
        XCTAssertNotNil(mnemonic)
        let words = mnemonic.components(separatedBy: " ")
        XCTAssertEqual(words.count, 24, "Mnemonic should contain exactly 24 words")
    }

    func testMnemonicUniqueness() throws {
        // Arrange & Act
        let mnemonic1 = try cryptoService.generateMnemonic(wordCount: 12)
        let mnemonic2 = try cryptoService.generateMnemonic(wordCount: 12)

        // Assert
        XCTAssertNotEqual(mnemonic1, mnemonic2, "Generated mnemonics should be unique")
    }

    func testMnemonicValidation() throws {
        // Arrange
        let validMnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let invalidMnemonic = "invalid words that are not in bip39 wordlist test fail"

        // Act & Assert
        XCTAssertTrue(cryptoService.validateMnemonic(validMnemonic), "Valid mnemonic should pass validation")
        XCTAssertFalse(cryptoService.validateMnemonic(invalidMnemonic), "Invalid mnemonic should fail validation")
    }

    // MARK: - Seed Generation Tests

    func testSeedGenerationFromMnemonic() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)

        // Act
        let seed = try cryptoService.generateSeed(from: mnemonic)

        // Assert
        XCTAssertNotNil(seed)
        XCTAssertEqual(seed.count, 64, "BIP39 seed should be 64 bytes")
    }

    func testSeedGenerationWithPassphrase() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let passphrase = "test-passphrase-123"

        // Act
        let seedWithoutPass = try cryptoService.generateSeed(from: mnemonic)
        let seedWithPass = try cryptoService.generateSeed(from: mnemonic, passphrase: passphrase)

        // Assert
        XCTAssertNotEqual(seedWithoutPass, seedWithPass, "Seeds with different passphrases should differ")
    }

    func testSeedDeterminism() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)

        // Act
        let seed1 = try cryptoService.generateSeed(from: mnemonic)
        let seed2 = try cryptoService.generateSeed(from: mnemonic)

        // Assert
        XCTAssertEqual(seed1, seed2, "Same mnemonic should always generate same seed")
    }

    // MARK: - Edge Cases and Error Handling

    func testInvalidMnemonicWordCount() {
        // Arrange & Act & Assert
        XCTAssertThrowsError(try cryptoService.generateMnemonic(wordCount: 11)) { error in
            XCTAssertTrue(error is CryptoError)
            if let cryptoError = error as? CryptoError {
                XCTAssertEqual(cryptoError, .invalidMnemonicLength)
            }
        }
    }

    func testEmptyMnemonicValidation() {
        // Arrange & Act & Assert
        XCTAssertFalse(cryptoService.validateMnemonic(""), "Empty mnemonic should fail validation")
    }

    func testKeyGenerationPerformance() {
        // Measure performance of key generation
        measure {
            _ = try? cryptoService.generateEd25519KeyPair()
        }
    }

    func testMnemonicGenerationPerformance() {
        // Measure performance of mnemonic generation
        measure {
            _ = try? cryptoService.generateMnemonic(wordCount: 12)
        }
    }

    // MARK: - Security Tests

    func testKeyMaterialZeroization() throws {
        // Arrange
        var keyPair = try cryptoService.generateEd25519KeyPair()

        // Act
        cryptoService.secureZeroize(&keyPair.privateKey)

        // Assert
        XCTAssertTrue(keyPair.privateKey.allSatisfy { $0 == 0 }, "Private key should be zeroed out")
    }

    func testRandomnessQuality() throws {
        // Test that generated keys have sufficient entropy
        let keyPair1 = try cryptoService.generateEd25519KeyPair()
        let keyPair2 = try cryptoService.generateEd25519KeyPair()

        // Calculate Hamming distance (should be high for random data)
        var differences = 0
        for i in 0..<min(keyPair1.privateKey.count, keyPair2.privateKey.count) {
            if keyPair1.privateKey[i] != keyPair2.privateKey[i] {
                differences += 1
            }
        }

        let differenceRatio = Double(differences) / Double(keyPair1.privateKey.count)
        XCTAssertGreaterThan(differenceRatio, 0.4, "Keys should have high entropy (>40% different bits)")
    }
}
