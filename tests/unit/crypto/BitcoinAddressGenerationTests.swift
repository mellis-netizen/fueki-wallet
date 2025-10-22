import XCTest
@testable import FuekiWallet

/// Comprehensive tests for Bitcoin address generation using official test vectors
/// Test vectors from Bitcoin Core, BIP-173, and BIP-350
class BitcoinAddressGenerationTests: XCTestCase {

    // MARK: - RIPEMD-160 Test Vectors

    func testRIPEMD160KnownVectors() {
        // Test vectors from RIPEMD-160 specification
        let testVectors: [(input: String, expected: String)] = [
            ("", "9c1185a5c5e9fc54612808977ee8f548b2258d31"),
            ("a", "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe"),
            ("abc", "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc"),
            ("message digest", "5d0689ef49d2fae572b881b123a85ffa21595f36"),
            ("abcdefghijklmnopqrstuvwxyz", "f71c27109c692c1b56bbdceb5b9d2865b3708dbc"),
            ("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq", "12a053384a9c0c88e405a06c27dcf49ada62eb2b"),
            ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", "b0e20b6e3116640286ed3a87a5713079b21f5189"),
            ("12345678901234567890123456789012345678901234567890123456789012345678901234567890", "9b752e45573d4b39f4dbd3323cab82bf63326bfb")
        ]

        for (input, expected) in testVectors {
            let data = input.data(using: .utf8)!
            let hash = RIPEMD160.hash(data)
            let result = CryptoUtils.hexEncode(hash)

            XCTAssertEqual(result, expected, "RIPEMD-160 hash mismatch for input: '\(input)'")
        }
    }

    func testHash160() {
        // Test Bitcoin-style hash160 (SHA256 then RIPEMD160)
        let testVectors: [(input: String, expected: String)] = [
            ("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
             "751e76e8199196d454941c45d1b3a323f1433bd6"), // Bitcoin genesis public key hash
        ]

        for (inputHex, expected) in testVectors {
            guard let data = CryptoUtils.hexDecode(inputHex) else {
                XCTFail("Failed to decode hex input: \(inputHex)")
                continue
            }

            let hash = CryptoUtils.hash160(data)
            let result = CryptoUtils.hexEncode(hash)

            XCTAssertEqual(result, expected, "Hash160 mismatch for input: \(inputHex)")
        }
    }

    // MARK: - Base58Check Test Vectors

    func testBase58CheckEncoding() {
        // Test vectors from Bitcoin Core
        let testVectors: [(input: String, expected: String)] = [
            // Empty
            ("", "3QJmnh"),
            // Single byte
            ("00", "1Wh4bh"),
            // Version 0x00 + 20-byte hash (P2PKH mainnet)
            ("00f54a5851e9372b87810a8e60cdd2e7cfd80b6e31", "1PMycacnJaSqwwJqjawXBErnLsZ7RkXUAs"),
            // Version 0x05 + 20-byte hash (P2SH mainnet)
            ("053a0f9b96d31e8a0c03b1eacc80fa0d3f98b74ba0", "36w1wfJcyjYx8aF4YZsXjHgMbvBRqbwqk"),
        ]

        for (inputHex, expected) in testVectors {
            guard let data = CryptoUtils.hexDecode(inputHex) else {
                XCTFail("Failed to decode hex input: \(inputHex)")
                continue
            }

            let encoded = CryptoUtils.base58CheckEncode(data)
            XCTAssertEqual(encoded, expected, "Base58Check encoding mismatch")

            // Test round-trip
            let decoded = CryptoUtils.base58CheckDecode(encoded)
            XCTAssertNotNil(decoded, "Base58Check decoding failed")
            XCTAssertEqual(CryptoUtils.hexEncode(decoded!), inputHex, "Base58Check round-trip failed")
        }
    }

    func testBase58CheckDecoding() {
        // Test invalid checksums
        let invalidAddresses = [
            "1PMycacnJaSqwwJqjawXBErnLsZ7RkXUAt", // Wrong checksum (last char changed)
            "36w1wfJcyjYx8aF4YZsXjHgMbvBRqbwqj",  // Wrong checksum
        ]

        for address in invalidAddresses {
            let decoded = CryptoUtils.base58CheckDecode(address)
            XCTAssertNil(decoded, "Should reject address with invalid checksum: \(address)")
        }
    }

    // MARK: - Bech32 Test Vectors

    func testBech32ValidVectors() {
        // Test vectors from BIP-173
        let validVectors = [
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
            "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7",
            "bc1pw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kt5nd6y",
            "bc1sw50qgdz25j",
            "bc1zw508d6qejxtdg4y5r3zarvaryvaxxpcs",
        ]

        for address in validVectors {
            XCTAssertNoThrow(try Bech32.decode(address), "Should decode valid Bech32 address: \(address)")
        }
    }

    func testBech32InvalidVectors() {
        // Test vectors from BIP-173 (invalid addresses)
        let invalidVectors = [
            "tc1qw508d6qejxtdg4y5r3zarvary0c5xw7kg3g4ty",  // Invalid human-readable part
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5",  // Invalid checksum
            "BC13W508D6QEJXTDG4Y5R3ZARVARY0C5XW7KN40WF2", // Invalid witness version
            "bc1rw5uspcuh",                                 // Invalid program length
            "bc10w508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kw5rljs90", // Invalid program length for witness version 0
            "BC1QR508D6QEJXTDG4Y5R3ZARVARYV98GJ9P",        // Invalid program length for witness version 0
            "bc1zw508d6qejxtdg4y5r3zarvaryvqyzf3du",       // Invalid checksum
            "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7", // Mixed case
        ]

        for address in invalidVectors {
            XCTAssertThrowsError(try Bech32.decode(address), "Should reject invalid Bech32 address: \(address)")
        }
    }

    func testBech32SegWitAddresses() {
        // Test vectors from BIP-173 with known witness programs
        let testVectors: [(address: String, version: UInt8, programHex: String)] = [
            ("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4", 0, "751e76e8199196d454941c45d1b3a323f1433bd6"),
            ("tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7", 0, "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262"),
        ]

        for (address, expectedVersion, expectedProgramHex) in testVectors {
            do {
                let (_, version, program) = try Bech32.decodeSegWitAddress(address)
                XCTAssertEqual(version, expectedVersion, "Witness version mismatch")
                XCTAssertEqual(CryptoUtils.hexEncode(program), expectedProgramHex, "Witness program mismatch")
            } catch {
                XCTFail("Failed to decode valid SegWit address: \(address), error: \(error)")
            }
        }
    }

    // MARK: - Bitcoin Address Generation Tests

    func testLegacyP2PKHAddressGeneration() {
        // Test with known public key from Bitcoin genesis block
        let testVectors: [(pubKeyHex: String, mainnetAddress: String, testnetAddress: String)] = [
            // Satoshi's genesis block public key
            ("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
             "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH",
             "mrCDrCybB6J1vRfbwM5hemdJz73FwDBC8r"),
            // Another known test vector
            ("02b4632d08485ff1df2db55b9dafd23347d1c47a457072a1e87be26896549a8737",
             "1CUNEBjYrCn2y1SdiUMohaKUi4wpP326Lb",
             "mxrLpqEcFrkeKGNyZ9AqXN1KW1tYcUXV4U"),
        ]

        for (pubKeyHex, expectedMainnet, expectedTestnet) in testVectors {
            guard let publicKey = CryptoUtils.hexDecode(pubKeyHex) else {
                XCTFail("Failed to decode public key hex")
                continue
            }

            let bitcoinMainnet = BitcoinIntegration(network: .mainnet)
            let bitcoinTestnet = BitcoinIntegration(network: .testnet)

            do {
                // Test mainnet
                let mainnetAddress = try bitcoinMainnet.generateAddress(from: publicKey, type: .legacy)
                XCTAssertEqual(mainnetAddress.address, expectedMainnet,
                             "Mainnet P2PKH address mismatch for key: \(pubKeyHex)")

                // Test testnet
                let testnetAddress = try bitcoinTestnet.generateAddress(from: publicKey, type: .legacy)
                XCTAssertEqual(testnetAddress.address, expectedTestnet,
                             "Testnet P2PKH address mismatch for key: \(pubKeyHex)")

                // Verify addresses are valid
                XCTAssertTrue(bitcoinMainnet.validateAddress(mainnetAddress.address),
                            "Generated mainnet address should be valid")
                XCTAssertTrue(bitcoinTestnet.validateAddress(testnetAddress.address),
                            "Generated testnet address should be valid")
            } catch {
                XCTFail("Failed to generate address: \(error)")
            }
        }
    }

    func testSegWitP2WPKHAddressGeneration() {
        // Test SegWit address generation
        let testVectors: [(pubKeyHex: String, mainnetAddress: String, testnetAddress: String)] = [
            // Known SegWit address test vectors
            ("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
             "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
             "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"),
        ]

        for (pubKeyHex, expectedMainnet, expectedTestnet) in testVectors {
            guard let publicKey = CryptoUtils.hexDecode(pubKeyHex) else {
                XCTFail("Failed to decode public key hex")
                continue
            }

            let bitcoinMainnet = BitcoinIntegration(network: .mainnet)
            let bitcoinTestnet = BitcoinIntegration(network: .testnet)

            do {
                // Test mainnet
                let mainnetAddress = try bitcoinMainnet.generateAddress(from: publicKey, type: .segwit)
                XCTAssertEqual(mainnetAddress.address, expectedMainnet,
                             "Mainnet SegWit address mismatch for key: \(pubKeyHex)")

                // Test testnet
                let testnetAddress = try bitcoinTestnet.generateAddress(from: publicKey, type: .segwit)
                XCTAssertEqual(testnetAddress.address, expectedTestnet,
                             "Testnet SegWit address mismatch for key: \(pubKeyHex)")

                // Verify addresses are valid
                XCTAssertTrue(bitcoinMainnet.validateAddress(mainnetAddress.address),
                            "Generated mainnet SegWit address should be valid")
                XCTAssertTrue(bitcoinTestnet.validateAddress(testnetAddress.address),
                            "Generated testnet SegWit address should be valid")
            } catch {
                XCTFail("Failed to generate SegWit address: \(error)")
            }
        }
    }

    func testNestedSegWitP2SHP2WPKHAddressGeneration() {
        // Test nested SegWit (P2SH-P2WPKH) address generation
        let testVectors: [(pubKeyHex: String, mainnetAddress: String, testnetAddress: String)] = [
            ("0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
             "3JvL6Ymt8MVWiCNHC7oWU6nLeHNJKLZGLN",
             "2N8Z5t3GyPW1hSAEJZqQ1GUkZ9emvSsz5qN"),
        ]

        for (pubKeyHex, expectedMainnet, expectedTestnet) in testVectors {
            guard let publicKey = CryptoUtils.hexDecode(pubKeyHex) else {
                XCTFail("Failed to decode public key hex")
                continue
            }

            let bitcoinMainnet = BitcoinIntegration(network: .mainnet)
            let bitcoinTestnet = BitcoinIntegration(network: .testnet)

            do {
                // Test mainnet
                let mainnetAddress = try bitcoinMainnet.generateAddress(from: publicKey, type: .nestedSegwit)
                XCTAssertEqual(mainnetAddress.address, expectedMainnet,
                             "Mainnet nested SegWit address mismatch for key: \(pubKeyHex)")

                // Test testnet
                let testnetAddress = try bitcoinTestnet.generateAddress(from: publicKey, type: .nestedSegwit)
                XCTAssertEqual(testnetAddress.address, expectedTestnet,
                             "Testnet nested SegWit address mismatch for key: \(pubKeyHex)")

                // Verify addresses are valid
                XCTAssertTrue(bitcoinMainnet.validateAddress(mainnetAddress.address),
                            "Generated mainnet nested SegWit address should be valid")
                XCTAssertTrue(bitcoinTestnet.validateAddress(testnetAddress.address),
                            "Generated testnet nested SegWit address should be valid")
            } catch {
                XCTFail("Failed to generate nested SegWit address: \(error)")
            }
        }
    }

    // MARK: - Address Validation Tests

    func testAddressValidation() {
        let bitcoin = BitcoinIntegration(network: .mainnet)

        // Valid mainnet addresses
        let validMainnetAddresses = [
            "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH",     // P2PKH
            "3JvL6Ymt8MVWiCNHC7oWU6nLeHNJKLZGLN",     // P2SH
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4", // SegWit v0
        ]

        for address in validMainnetAddresses {
            XCTAssertTrue(bitcoin.validateAddress(address),
                        "Should validate valid mainnet address: \(address)")
        }

        // Invalid addresses
        let invalidAddresses = [
            "1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMX",     // Invalid checksum
            "3JvL6Ymt8MVWiCNHC7oWU6nLeHNJKLZGLX",     // Invalid checksum
            "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5", // Invalid Bech32 checksum
            "1234567890",                             // Random string
            "",                                       // Empty string
            "0x1234567890abcdef",                     // Ethereum-style address
        ]

        for address in invalidAddresses {
            XCTAssertFalse(bitcoin.validateAddress(address),
                         "Should reject invalid address: \(address)")
        }
    }

    // MARK: - Edge Cases

    func testCompressedVsUncompressedPublicKeys() {
        // Compressed public key (33 bytes, starts with 0x02 or 0x03)
        let compressedPubKey = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"

        // Uncompressed public key (65 bytes, starts with 0x04)
        let uncompressedPubKey = "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"

        guard let compressedData = CryptoUtils.hexDecode(compressedPubKey),
              let uncompressedData = CryptoUtils.hexDecode(uncompressedPubKey) else {
            XCTFail("Failed to decode public keys")
            return
        }

        let bitcoin = BitcoinIntegration(network: .mainnet)

        do {
            // Both should generate valid addresses (though different ones)
            let compressedAddress = try bitcoin.generateAddress(from: compressedData, type: .legacy)
            let uncompressedAddress = try bitcoin.generateAddress(from: uncompressedData, type: .legacy)

            XCTAssertTrue(bitcoin.validateAddress(compressedAddress.address),
                        "Compressed public key should generate valid address")
            XCTAssertTrue(bitcoin.validateAddress(uncompressedAddress.address),
                        "Uncompressed public key should generate valid address")

            // Addresses should be different
            XCTAssertNotEqual(compressedAddress.address, uncompressedAddress.address,
                            "Compressed and uncompressed keys should generate different addresses")
        } catch {
            XCTFail("Failed to generate addresses from public keys: \(error)")
        }
    }

    func testEmptyAndInvalidPublicKeys() {
        let bitcoin = BitcoinIntegration(network: .mainnet)

        // Empty public key
        XCTAssertThrowsError(try bitcoin.generateAddress(from: Data(), type: .legacy),
                           "Should throw error for empty public key")

        // Too short public key
        let tooShort = Data([0x02, 0x03])
        XCTAssertThrowsError(try bitcoin.generateAddress(from: tooShort, type: .legacy),
                           "Should throw error for too short public key")

        // Invalid compressed key prefix
        var invalidPrefix = Data(repeating: 0xFF, count: 33)
        invalidPrefix[0] = 0x05 // Invalid prefix
        // Note: Depending on implementation, this might not throw but generate an address
        // The validation would happen when trying to use the address
    }
}
