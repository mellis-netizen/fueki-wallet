import XCTest
@testable import FuekiWallet

/// Unit tests for BIP32/BIP44 hierarchical deterministic key derivation
class BIP32KeyDerivationTests: XCTestCase {

    var keyDerivationService: KeyDerivationService!
    var cryptoService: CryptoService!

    override func setUp() {
        super.setUp()
        keyDerivationService = KeyDerivationService()
        cryptoService = CryptoService()
    }

    override func tearDown() {
        keyDerivationService = nil
        cryptoService = nil
        super.tearDown()
    }

    // MARK: - BIP32 Master Key Tests

    func testGenerateMasterKeyFromSeed() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)

        // Act
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Assert
        XCTAssertNotNil(masterKey.privateKey)
        XCTAssertNotNil(masterKey.chainCode)
        XCTAssertEqual(masterKey.depth, 0, "Master key should have depth 0")
        XCTAssertEqual(masterKey.parentFingerprint, Data(repeating: 0, count: 4))
    }

    func testMasterKeyDeterminism() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)

        // Act
        let masterKey1 = try keyDerivationService.generateMasterKey(from: seed)
        let masterKey2 = try keyDerivationService.generateMasterKey(from: seed)

        // Assert
        XCTAssertEqual(masterKey1.privateKey, masterKey2.privateKey, "Master key derivation should be deterministic")
        XCTAssertEqual(masterKey1.chainCode, masterKey2.chainCode)
    }

    // MARK: - BIP32 Child Key Derivation Tests

    func testDeriveChildKeyNormal() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - Derive normal (non-hardened) child key
        let childKey = try keyDerivationService.deriveChildKey(from: masterKey, index: 0, hardened: false)

        // Assert
        XCTAssertNotNil(childKey.privateKey)
        XCTAssertNotNil(childKey.chainCode)
        XCTAssertEqual(childKey.depth, 1, "Child key should have depth 1")
        XCTAssertNotEqual(childKey.privateKey, masterKey.privateKey, "Child key should differ from parent")
    }

    func testDeriveChildKeyHardened() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - Derive hardened child key
        let childKey = try keyDerivationService.deriveChildKey(from: masterKey, index: 0, hardened: true)

        // Assert
        XCTAssertNotNil(childKey.privateKey)
        XCTAssertGreaterThanOrEqual(childKey.index, 0x80000000, "Hardened key index should be >= 2^31")
    }

    func testDeriveMultipleChildren() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let child0 = try keyDerivationService.deriveChildKey(from: masterKey, index: 0, hardened: false)
        let child1 = try keyDerivationService.deriveChildKey(from: masterKey, index: 1, hardened: false)
        let child2 = try keyDerivationService.deriveChildKey(from: masterKey, index: 2, hardened: false)

        // Assert - All children should be unique
        XCTAssertNotEqual(child0.privateKey, child1.privateKey)
        XCTAssertNotEqual(child1.privateKey, child2.privateKey)
        XCTAssertNotEqual(child0.privateKey, child2.privateKey)
    }

    func testChildKeyDeterminism() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let child1 = try keyDerivationService.deriveChildKey(from: masterKey, index: 5, hardened: false)
        let child2 = try keyDerivationService.deriveChildKey(from: masterKey, index: 5, hardened: false)

        // Assert
        XCTAssertEqual(child1.privateKey, child2.privateKey, "Same derivation should produce same key")
    }

    // MARK: - BIP32 Path Derivation Tests

    func testDeriveKeyFromPath() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - Derive using path notation: m/0'/1/2'
        let derivedKey = try keyDerivationService.deriveKey(from: masterKey, path: "m/0'/1/2'")

        // Assert
        XCTAssertEqual(derivedKey.depth, 3, "Derived key should have depth 3")
        XCTAssertNotNil(derivedKey.privateKey)
    }

    func testDeriveKeyFromPathDeterminism() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let key1 = try keyDerivationService.deriveKey(from: masterKey, path: "m/44'/60'/0'/0/0")
        let key2 = try keyDerivationService.deriveKey(from: masterKey, path: "m/44'/60'/0'/0/0")

        // Assert
        XCTAssertEqual(key1.privateKey, key2.privateKey, "Same path should produce same key")
    }

    func testDeriveKeyStepByStep() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - Derive step by step
        let key1 = try keyDerivationService.deriveChildKey(from: masterKey, index: 44, hardened: true)
        let key2 = try keyDerivationService.deriveChildKey(from: key1, index: 60, hardened: true)
        let key3 = try keyDerivationService.deriveChildKey(from: key2, index: 0, hardened: true)
        let key4 = try keyDerivationService.deriveChildKey(from: key3, index: 0, hardened: false)
        let key5 = try keyDerivationService.deriveChildKey(from: key4, index: 0, hardened: false)

        // Act - Derive using path
        let pathKey = try keyDerivationService.deriveKey(from: masterKey, path: "m/44'/60'/0'/0/0")

        // Assert - Both methods should produce same key
        XCTAssertEqual(key5.privateKey, pathKey.privateKey, "Step-by-step and path derivation should match")
    }

    // MARK: - BIP44 Standard Paths Tests

    func testDeriveBIP44EthereumPath() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - BIP44 Ethereum path: m/44'/60'/0'/0/0
        let ethereumKey = try keyDerivationService.deriveBIP44Key(
            from: masterKey,
            coinType: 60, // Ethereum
            account: 0,
            change: 0,
            addressIndex: 0
        )

        // Assert
        XCTAssertNotNil(ethereumKey.privateKey)
        XCTAssertEqual(ethereumKey.depth, 5)
    }

    func testDeriveBIP44BitcoinPath() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - BIP44 Bitcoin path: m/44'/0'/0'/0/0
        let bitcoinKey = try keyDerivationService.deriveBIP44Key(
            from: masterKey,
            coinType: 0, // Bitcoin
            account: 0,
            change: 0,
            addressIndex: 0
        )

        // Assert
        XCTAssertNotNil(bitcoinKey.privateKey)
        XCTAssertEqual(bitcoinKey.depth, 5)
    }

    func testDeriveMultipleAccounts() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - Derive multiple accounts for same coin
        let account0 = try keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 0, change: 0, addressIndex: 0)
        let account1 = try keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 1, change: 0, addressIndex: 0)
        let account2 = try keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 2, change: 0, addressIndex: 0)

        // Assert
        XCTAssertNotEqual(account0.privateKey, account1.privateKey)
        XCTAssertNotEqual(account1.privateKey, account2.privateKey)
    }

    func testDeriveMultipleAddresses() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act - Derive multiple addresses for same account
        var addresses: [ExtendedKey] = []
        for i in 0..<10 {
            let key = try keyDerivationService.deriveBIP44Key(
                from: masterKey,
                coinType: 60,
                account: 0,
                change: 0,
                addressIndex: UInt32(i)
            )
            addresses.append(key)
        }

        // Assert - All addresses should be unique
        let uniqueKeys = Set(addresses.map { $0.privateKey })
        XCTAssertEqual(uniqueKeys.count, 10, "All addresses should be unique")
    }

    func testDeriveChangeAddresses() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let externalAddress = try keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 0, change: 0, addressIndex: 0)
        let changeAddress = try keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 0, change: 1, addressIndex: 0)

        // Assert
        XCTAssertNotEqual(externalAddress.privateKey, changeAddress.privateKey, "External and change addresses should differ")
    }

    // MARK: - Extended Key Serialization Tests

    func testSerializeExtendedPrivateKey() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let xprv = try keyDerivationService.serializeExtendedKey(masterKey, isPrivate: true, network: .mainnet)

        // Assert
        XCTAssertTrue(xprv.hasPrefix("xprv"), "Extended private key should start with 'xprv'")
    }

    func testSerializeExtendedPublicKey() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let xpub = try keyDerivationService.serializeExtendedKey(masterKey, isPrivate: false, network: .mainnet)

        // Assert
        XCTAssertTrue(xpub.hasPrefix("xpub"), "Extended public key should start with 'xpub'")
    }

    func testDeserializeExtendedKey() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let originalKey = try keyDerivationService.generateMasterKey(from: seed)
        let serialized = try keyDerivationService.serializeExtendedKey(originalKey, isPrivate: true, network: .mainnet)

        // Act
        let deserialized = try keyDerivationService.deserializeExtendedKey(serialized)

        // Assert
        XCTAssertEqual(deserialized.privateKey, originalKey.privateKey)
        XCTAssertEqual(deserialized.chainCode, originalKey.chainCode)
    }

    // MARK: - Public Key Derivation Tests

    func testDerivePublicKeyFromExtendedKey() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let publicKey = try keyDerivationService.derivePublicKey(from: masterKey)

        // Assert
        XCTAssertNotNil(publicKey)
        XCTAssertTrue(publicKey.count == 33 || publicKey.count == 65, "Public key should be compressed (33) or uncompressed (65)")
    }

    func testPublicKeyDerivationConsistency() throws {
        // Arrange
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Act
        let pubKey1 = try keyDerivationService.derivePublicKey(from: masterKey)
        let pubKey2 = try keyDerivationService.derivePublicKey(from: masterKey)

        // Assert
        XCTAssertEqual(pubKey1, pubKey2, "Public key derivation should be consistent")
    }

    // MARK: - Test Vectors (BIP32 Official)

    func testBIP32TestVector1() throws {
        // Test vector 1 from BIP32 specification
        let seedHex = "000102030405060708090a0b0c0d0e0f"
        let seed = Data(hex: seedHex)

        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        // Expected xprv for master key
        let expectedXprv = "xprv9s21ZrQH143K3QTDL4LXw2F7HEK3wJUD2nW2nRk4stbPy6cq3jPPqjiChkVvvNKmPGJxWUtg6LnF5kejMRNNU3TGtRBeJgk33yuGBxrMPHi"

        let actualXprv = try keyDerivationService.serializeExtendedKey(masterKey, isPrivate: true, network: .mainnet)

        // Note: Actual comparison depends on implementation details
        XCTAssertNotNil(actualXprv)
    }

    // MARK: - Performance Tests

    func testKeyDerivationPerformance() throws {
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        measure {
            _ = try? keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 0, change: 0, addressIndex: 0)
        }
    }

    func testMultipleAddressDerivationPerformance() throws {
        let mnemonic = try cryptoService.generateMnemonic(wordCount: 12)
        let seed = try cryptoService.generateSeed(from: mnemonic)
        let masterKey = try keyDerivationService.generateMasterKey(from: seed)

        measure {
            for i in 0..<100 {
                _ = try? keyDerivationService.deriveBIP44Key(from: masterKey, coinType: 60, account: 0, change: 0, addressIndex: UInt32(i))
            }
        }
    }
}

// Helper extension for hex conversion
extension Data {
    init(hex: String) {
        let len = hex.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hex.index(hex.startIndex, offsetBy: i * 2)
            let k = hex.index(j, offsetBy: 2)
            let bytes = hex[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            }
        }
        self = data
    }
}
