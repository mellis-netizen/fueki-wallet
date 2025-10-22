import XCTest
import CryptoKit
@testable import FuekiWallet

final class CryptoTests: XCTestCase {

    // MARK: - SHA256 Tests

    func testSHA256_KnownInput_MatchesExpectedOutput() {
        // Given
        let input = "hello world".data(using: .utf8)!
        let expectedHex = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9"

        // When
        let hash = SHA256.hash(data: input)
        let hashHex = hash.compactMap { String(format: "%02x", $0) }.joined()

        // Then
        XCTAssertEqual(hashHex, expectedHex)
    }

    func testSHA256_EmptyInput_ProducesHash() {
        // Given
        let input = Data()

        // When
        let hash = SHA256.hash(data: input)

        // Then
        XCTAssertEqual(hash.count, 32)
    }

    func testSHA256_LargeInput_Success() {
        // Given
        let largeInput = Data(repeating: 0xFF, count: 1024 * 1024) // 1MB

        // When
        let hash = SHA256.hash(data: largeInput)

        // Then
        XCTAssertEqual(hash.count, 32)
    }

    // MARK: - RIPEMD160 Tests

    func testRIPEMD160_KnownInput_MatchesExpected() {
        // Given
        let input = "hello".data(using: .utf8)!
        // RIPEMD160("hello") = "108f07b8382412612c048d07d13f814118445acd"

        // When
        let hash = CryptoUtilities.ripemd160(input)
        let hashHex = hash.map { String(format: "%02x", $0) }.joined()

        // Then
        XCTAssertEqual(hashHex, "108f07b8382412612c048d07d13f814118445acd")
    }

    // MARK: - Base58 Encoding Tests

    func testBase58Encode_KnownInput_MatchesExpected() {
        // Given
        let input = Data([0x00, 0x01, 0x02, 0x03])

        // When
        let encoded = Base58.encode(input)

        // Then
        XCTAssertFalse(encoded.isEmpty)
        XCTAssertFalse(encoded.contains("0")) // Base58 doesn't use 0
        XCTAssertFalse(encoded.contains("O")) // Base58 doesn't use O
    }

    func testBase58Decode_ValidInput_ReturnsOriginal() {
        // Given
        let original = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        let encoded = Base58.encode(original)

        // When
        let decoded = Base58.decode(encoded)

        // Then
        XCTAssertEqual(decoded, original)
    }

    func testBase58Encode_LeadingZeros_Preserved() {
        // Given
        let input = Data([0x00, 0x00, 0x01, 0x02])

        // When
        let encoded = Base58.encode(input)
        let decoded = Base58.decode(encoded)

        // Then
        XCTAssertEqual(decoded, input)
    }

    // MARK: - Bech32 Encoding Tests

    func testBech32Encode_ValidData_Success() {
        // Given
        let hrp = "tb" // Testnet
        let data = Data(repeating: 0x00, count: 20)

        // When
        let encoded = Bech32.encode(hrp: hrp, data: data)

        // Then
        XCTAssertTrue(encoded.starts(with: "tb1"))
        XCTAssertGreaterThan(encoded.count, 20)
    }

    func testBech32Decode_ValidAddress_Success() {
        // Given
        let validAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        // When
        let decoded = Bech32.decode(validAddress)

        // Then
        XCTAssertNotNil(decoded)
        XCTAssertEqual(decoded?.hrp, "tb")
    }

    func testBech32Decode_InvalidChecksum_ReturnsNil() {
        // Given
        let invalidAddress = "tb1qinvalidchecksum"

        // When
        let decoded = Bech32.decode(invalidAddress)

        // Then
        XCTAssertNil(decoded)
    }

    // MARK: - HMAC Tests

    func testHMAC_SHA512_KnownVector() {
        // Given
        let key = "key".data(using: .utf8)!
        let message = "The quick brown fox jumps over the lazy dog".data(using: .utf8)!
        let expectedHex = "b42af09057bac1e2d41708e48a902e09b5ff7f12ab428a4fe86653c73dd248fb82f948a549f7b791a5b41915ee4d1ec3935357e4e2317250d0372afa2ebeeb3a"

        // When
        let hmac = CryptoUtilities.hmacSHA512(key: key, message: message)
        let hmacHex = hmac.map { String(format: "%02x", $0) }.joined()

        // Then
        XCTAssertEqual(hmacHex, expectedHex)
    }

    // MARK: - PBKDF2 Tests

    func testPBKDF2_KnownVector_MatchesExpected() {
        // Given
        let password = "password".data(using: .utf8)!
        let salt = "salt".data(using: .utf8)!
        let iterations = 1
        let keyLength = 64

        // When
        let derived = CryptoUtilities.pbkdf2(
            password: password,
            salt: salt,
            iterations: iterations,
            keyLength: keyLength
        )

        // Then
        XCTAssertEqual(derived.count, keyLength)
    }

    func testPBKDF2_HighIterations_Success() {
        // Given
        let password = "secure_password".data(using: .utf8)!
        let salt = "random_salt".data(using: .utf8)!
        let iterations = 10000

        // When
        let derived = CryptoUtilities.pbkdf2(
            password: password,
            salt: salt,
            iterations: iterations,
            keyLength: 64
        )

        // Then
        XCTAssertEqual(derived.count, 64)
    }

    // MARK: - AES Encryption Tests

    func testAESEncryption_RoundTrip_Success() throws {
        // Given
        let plaintext = "Secret message".data(using: .utf8)!
        let password = "encryption_password"

        // When
        let encrypted = try CryptoUtilities.aesEncrypt(plaintext, password: password)
        let decrypted = try CryptoUtilities.aesDecrypt(encrypted, password: password)

        // Then
        XCTAssertEqual(decrypted, plaintext)
    }

    func testAESEncryption_WrongPassword_ThrowsError() throws {
        // Given
        let plaintext = "Secret message".data(using: .utf8)!
        let encrypted = try CryptoUtilities.aesEncrypt(plaintext, password: "password1")

        // When/Then
        XCTAssertThrowsError(
            try CryptoUtilities.aesDecrypt(encrypted, password: "password2")
        )
    }

    func testAESEncryption_LargeData_Success() throws {
        // Given
        let largeData = Data(repeating: 0x42, count: 1024 * 100) // 100KB
        let password = "test_password"

        // When
        let encrypted = try CryptoUtilities.aesEncrypt(largeData, password: password)
        let decrypted = try CryptoUtilities.aesDecrypt(encrypted, password: password)

        // Then
        XCTAssertEqual(decrypted, largeData)
    }

    // MARK: - Elliptic Curve Tests

    func testECDSA_SignAndVerify_Success() throws {
        // Given
        let privateKey = P256.Signing.PrivateKey()
        let message = "Test message".data(using: .utf8)!

        // When
        let signature = try privateKey.signature(for: message)
        let isValid = privateKey.publicKey.isValidSignature(signature, for: message)

        // Then
        XCTAssertTrue(isValid)
    }

    func testECDSA_ModifiedMessage_FailsVerification() throws {
        // Given
        let privateKey = P256.Signing.PrivateKey()
        let originalMessage = "Original message".data(using: .utf8)!
        let modifiedMessage = "Modified message".data(using: .utf8)!

        // When
        let signature = try privateKey.signature(for: originalMessage)
        let isValid = privateKey.publicKey.isValidSignature(signature, for: modifiedMessage)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Random Number Generation Tests

    func testSecureRandomBytes_ProducesUniqueValues() {
        // When
        let random1 = CryptoUtilities.secureRandomBytes(count: 32)
        let random2 = CryptoUtilities.secureRandomBytes(count: 32)

        // Then
        XCTAssertNotEqual(random1, random2)
        XCTAssertEqual(random1.count, 32)
        XCTAssertEqual(random2.count, 32)
    }

    func testSecureRandomBytes_LargeSize_Success() {
        // When
        let random = CryptoUtilities.secureRandomBytes(count: 1024)

        // Then
        XCTAssertEqual(random.count, 1024)
        XCTAssertFalse(random.allSatisfy { $0 == 0 })
    }

    // MARK: - Performance Tests

    func testSHA256Performance() {
        let data = Data(repeating: 0xFF, count: 1024 * 1024) // 1MB

        measure {
            _ = SHA256.hash(data: data)
        }
    }

    func testAESEncryptionPerformance() throws {
        let data = Data(repeating: 0x42, count: 1024 * 100) // 100KB
        let password = "test_password"

        measure {
            _ = try? CryptoUtilities.aesEncrypt(data, password: password)
        }
    }

    func testPBKDF2Performance() {
        let password = "test_password".data(using: .utf8)!
        let salt = "salt".data(using: .utf8)!

        measure {
            _ = CryptoUtilities.pbkdf2(
                password: password,
                salt: salt,
                iterations: 10000,
                keyLength: 64
            )
        }
    }
}
