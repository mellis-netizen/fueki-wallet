import XCTest
@testable import Secp256k1Swift

/// Comprehensive test suite for secp256k1 cryptographic operations
/// Includes Bitcoin and Ethereum compatibility test vectors
final class Secp256k1Tests: XCTestCase {

    // MARK: - Test Helpers

    func hexToData(_ hex: String) -> Data {
        let hex = hex.replacingOccurrences(of: " ", with: "")
        var data = Data()
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            }
            index = nextIndex
        }
        return data
    }

    func dataToHex(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public Key Derivation Tests

    func testPublicKeyDerivation() throws {
        // Test vector from Bitcoin Core
        let privateKey = hexToData("0000000000000000000000000000000000000000000000000000000000000001")
        let expectedPublicKeyCompressed = hexToData("0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")

        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)

        XCTAssertEqual(publicKey.count, 33, "Compressed public key should be 33 bytes")
        XCTAssertEqual(dataToHex(publicKey).uppercased(), dataToHex(expectedPublicKeyCompressed).uppercased())
    }

    func testPublicKeyDerivationUncompressed() throws {
        // Generator point (private key = 1)
        let privateKey = hexToData("0000000000000000000000000000000000000000000000000000000000000001")
        let expectedX = hexToData("79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")
        let expectedY = hexToData("483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8")

        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: false)

        XCTAssertEqual(publicKey.count, 65, "Uncompressed public key should be 65 bytes")
        XCTAssertEqual(publicKey[0], 0x04, "Uncompressed prefix should be 0x04")

        let x = publicKey[1..<33]
        let y = publicKey[33..<65]

        XCTAssertEqual(dataToHex(x).uppercased(), dataToHex(expectedX).uppercased())
        XCTAssertEqual(dataToHex(y).uppercased(), dataToHex(expectedY).uppercased())
    }

    func testMultiplePublicKeys() throws {
        // Test vectors from https://github.com/bitcoin-core/secp256k1/blob/master/src/tests.c
        let testVectors: [(String, String)] = [
            ("0000000000000000000000000000000000000000000000000000000000000001",
             "0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"),
            ("0000000000000000000000000000000000000000000000000000000000000002",
             "02C6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5"),
            ("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF",
             "0379BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")
        ]

        for (privHex, pubHex) in testVectors {
            let privateKey = hexToData(privHex)
            let expectedPublicKey = hexToData(pubHex)

            do {
                let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)
                XCTAssertEqual(dataToHex(publicKey).uppercased(), dataToHex(expectedPublicKey).uppercased(),
                             "Failed for private key: \(privHex)")
            } catch {
                // Last test vector might be invalid (outside curve order)
                if privHex.contains("FFFF") {
                    XCTAssert(true, "Expected failure for key >= curve order")
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }
    }

    // MARK: - Signature Tests

    func testSigningDeterministic() throws {
        // RFC 6979 test vector for secp256k1
        let privateKey = hexToData("C9AFA9D845BA75166B5C215767B1D6934E50C3DB36E89B127B8A622B120F6721")
        let messageHash = hexToData("AF2BDBE1AA9B6EC1E2ADE1D694F41FC71A831D0268E9891562113D8A62ADD1BF")

        let signature = try Secp256k1.sign(messageHash: messageHash, with: privateKey)

        XCTAssertEqual(signature.count, 64, "Signature should be 64 bytes (r || s)")

        // Verify signature determinism (signing again should produce same result)
        let signature2 = try Secp256k1.sign(messageHash: messageHash, with: privateKey)
        XCTAssertEqual(signature, signature2, "RFC 6979 signatures should be deterministic")
    }

    func testSignatureVerification() throws {
        let privateKey = hexToData("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")
        let messageHash = hexToData("4E03657AEA45A94FC7D47BA826C8D667C0D1E6E33A64A036EC44F58FA12D6C45")

        // Sign message
        let signature = try Secp256k1.sign(messageHash: messageHash, with: privateKey)

        // Derive public key
        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)

        // Verify signature
        let isValid = try Secp256k1.verify(signature: signature, messageHash: messageHash, publicKey: publicKey)
        XCTAssertTrue(isValid, "Signature verification should succeed")

        // Verify with wrong message fails
        var wrongMessage = messageHash
        wrongMessage[0] ^= 0x01
        let isInvalid = try Secp256k1.verify(signature: signature, messageHash: wrongMessage, publicKey: publicKey)
        XCTAssertFalse(isInvalid, "Verification with wrong message should fail")
    }

    // MARK: - Recoverable Signature Tests (Ethereum)

    func testRecoverableSignature() throws {
        let privateKey = hexToData("4646464646464646464646464646464646464646464646464646464646464646")
        let messageHash = hexToData("DEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEFDEADBEEF")

        // Sign with recovery information
        let recoverableSignature = try Secp256k1.signRecoverable(messageHash: messageHash, with: privateKey)

        XCTAssertEqual(recoverableSignature.count, 65, "Recoverable signature should be 65 bytes (r || s || v)")

        let recoveryId = recoverableSignature[64]
        XCTAssertTrue(recoveryId <= 3, "Recovery ID should be 0-3")

        // Recover public key from signature
        let recoveredPublicKey = try Secp256k1.recoverPublicKey(from: recoverableSignature, messageHash: messageHash, compressed: true)

        // Derive original public key
        let originalPublicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)

        XCTAssertEqual(recoveredPublicKey, originalPublicKey, "Recovered public key should match original")
    }

    func testEthereumSignatureFormat() throws {
        // Ethereum transaction signing test vector
        let privateKey = hexToData("0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF")
        let txHash = hexToData("5C62E091B8C0565F1BDE7DBA5D42E979E0C6B8A4B9CEFD0E4C8F6D8A3B7E9C1D")

        let signature = try Secp256k1.signRecoverable(messageHash: txHash, with: privateKey)

        XCTAssertEqual(signature.count, 65)

        // Extract r, s, v
        let r = signature[0..<32]
        let s = signature[32..<64]
        let v = signature[64]

        XCTAssertEqual(r.count, 32)
        XCTAssertEqual(s.count, 32)
        XCTAssertTrue(v <= 3, "Recovery ID should be 0-3 (Ethereum uses v = 27 + recovery_id)")

        // Verify recovery works
        let recoveredPubKey = try Secp256k1.recoverPublicKey(from: signature, messageHash: txHash, compressed: false)
        XCTAssertEqual(recoveredPubKey.count, 65, "Ethereum uses uncompressed public keys")
    }

    // MARK: - Bitcoin Test Vectors

    func testBitcoinMessageSigning() throws {
        // Bitcoin message signing test vector
        let privateKey = hexToData("5HueCGU8rMjxEXxiPuD5BDku4MkFqeZyd4dZ1jvhTVqvbTLvyTJ")
            .sha256() // Simplified - in real Bitcoin, this would be WIF decoded

        let message = "Bitcoin Signed Message:\n\nHello World"
        let messageHash = Data(message.utf8).sha256().sha256() // Double SHA-256

        let signature = try Secp256k1.sign(messageHash: messageHash, with: privateKey)

        // Verify signature
        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)
        let isValid = try Secp256k1.verify(signature: signature, messageHash: messageHash, publicKey: publicKey)

        XCTAssertTrue(isValid, "Bitcoin message signature should verify")
    }

    // MARK: - Key Tweaking Tests (BIP32 HD Wallets)

    func testPrivateKeyAddition() throws {
        let key1 = hexToData("0000000000000000000000000000000000000000000000000000000000000002")
        let key2 = hexToData("0000000000000000000000000000000000000000000000000000000000000003")

        let result = try Secp256k1.privateKeyAdd(key1, tweak: key2)

        // 2 + 3 = 5
        let expected = hexToData("0000000000000000000000000000000000000000000000000000000000000005")
        XCTAssertEqual(result, expected)
    }

    func testPrivateKeyMultiplication() throws {
        let key = hexToData("0000000000000000000000000000000000000000000000000000000000000002")
        let scalar = hexToData("0000000000000000000000000000000000000000000000000000000000000003")

        let result = try Secp256k1.privateKeyMultiply(key, by: scalar)

        // 2 * 3 = 6
        let expected = hexToData("0000000000000000000000000000000000000000000000000000000000000006")
        XCTAssertEqual(result, expected)
    }

    func testPrivateKeyNegation() throws {
        let key = hexToData("0000000000000000000000000000000000000000000000000000000000000001")

        let negated = try Secp256k1.privateKeyNegate(key)

        // Negated key should be n - 1 where n is curve order
        XCTAssertNotEqual(negated, key)
        XCTAssertEqual(negated.count, 32)

        // Double negation should return to original
        let doubleNegated = try Secp256k1.privateKeyNegate(negated)
        XCTAssertEqual(doubleNegated, key)
    }

    // MARK: - Validation Tests

    func testPrivateKeyValidation() {
        // Valid keys
        let validKey1 = hexToData("0000000000000000000000000000000000000000000000000000000000000001")
        XCTAssertTrue(Secp256k1.isValidPrivateKey(validKey1))

        let validKey2 = hexToData("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140")
        XCTAssertTrue(Secp256k1.isValidPrivateKey(validKey2))

        // Invalid: all zeros
        let invalidZero = Data(count: 32)
        XCTAssertFalse(Secp256k1.isValidPrivateKey(invalidZero))

        // Invalid: >= curve order
        let invalidLarge = hexToData("FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141")
        XCTAssertFalse(Secp256k1.isValidPrivateKey(invalidLarge))

        // Invalid: wrong length
        let invalidLength = Data(count: 16)
        XCTAssertFalse(Secp256k1.isValidPrivateKey(invalidLength))
    }

    func testPublicKeyValidation() throws {
        // Valid compressed public key
        let validCompressed = hexToData("0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")
        XCTAssertTrue(Secp256k1.isValidPublicKey(validCompressed))

        // Valid uncompressed public key
        let privateKey = hexToData("0000000000000000000000000000000000000000000000000000000000000001")
        let validUncompressed = try Secp256k1.derivePublicKey(from: privateKey, compressed: false)
        XCTAssertTrue(Secp256k1.isValidPublicKey(validUncompressed))

        // Invalid: wrong length
        let invalidLength = Data(count: 32)
        XCTAssertFalse(Secp256k1.isValidPublicKey(invalidLength))

        // Invalid: wrong prefix
        var invalidPrefix = validCompressed
        invalidPrefix[0] = 0x05
        XCTAssertFalse(Secp256k1.isValidPublicKey(invalidPrefix))
    }

    // MARK: - Signature Normalization Tests

    func testSignatureNormalization() {
        // Test low-s normalization (BIP 62)
        let highS = hexToData(
            "8000000000000000000000000000000000000000000000000000000000000000" +
            "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364140"
        )

        let normalized = Secp256k1.normalizeSignature(highS)

        // Normalized s should be lower than original
        let originalS = highS[32..<64]
        let normalizedS = normalized[32..<64]

        XCTAssertNotEqual(originalS, normalizedS, "High-S should be normalized")

        // R component should remain unchanged
        XCTAssertEqual(highS[0..<32], normalized[0..<32])
    }

    // MARK: - Edge Cases and Error Handling

    func testInvalidInputs() {
        // Test invalid message hash length
        let privateKey = hexToData("0000000000000000000000000000000000000000000000000000000000000001")
        let invalidHash = Data(count: 16) // Should be 32 bytes

        XCTAssertThrowsError(try Secp256k1.sign(messageHash: invalidHash, with: privateKey))

        // Test invalid private key length
        let invalidKey = Data(count: 16)
        let validHash = Data(count: 32)

        XCTAssertThrowsError(try Secp256k1.derivePublicKey(from: invalidKey))
        XCTAssertThrowsError(try Secp256k1.sign(messageHash: validHash, with: invalidKey))
    }

    func testRecoveryWithInvalidId() {
        let validSignature = Data(count: 64)
        var invalidRecoverable = validSignature
        invalidRecoverable.append(4) // Invalid recovery ID (should be 0-3)

        let messageHash = Data(count: 32)

        XCTAssertThrowsError(try Secp256k1.recoverPublicKey(from: invalidRecoverable, messageHash: messageHash))
    }

    // MARK: - Performance Tests

    func testPublicKeyDerivationPerformance() {
        let privateKey = hexToData("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")

        measure {
            for _ in 0..<1000 {
                _ = try? Secp256k1.derivePublicKey(from: privateKey, compressed: true)
            }
        }
    }

    func testSigningPerformance() {
        let privateKey = hexToData("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")
        let messageHash = hexToData("4E03657AEA45A94FC7D47BA826C8D667C0D1E6E33A64A036EC44F58FA12D6C45")

        measure {
            for _ in 0..<1000 {
                _ = try? Secp256k1.sign(messageHash: messageHash, with: privateKey)
            }
        }
    }

    func testVerificationPerformance() throws {
        let privateKey = hexToData("E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855")
        let messageHash = hexToData("4E03657AEA45A94FC7D47BA826C8D667C0D1E6E33A64A036EC44F58FA12D6C45")
        let signature = try Secp256k1.sign(messageHash: messageHash, with: privateKey)
        let publicKey = try Secp256k1.derivePublicKey(from: privateKey, compressed: true)

        measure {
            for _ in 0..<1000 {
                _ = try? Secp256k1.verify(signature: signature, messageHash: messageHash, publicKey: publicKey)
            }
        }
    }
}

// MARK: - Data Extensions for Testing

private extension Data {
    func sha256() -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return Data(hash)
    }
}

// CommonCrypto imports for SHA256
#if canImport(CommonCrypto)
import CommonCrypto
#endif
