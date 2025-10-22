import Foundation
@testable import FuekiWallet

/// Provides reusable test data and fixtures for tests
enum TestFixtures {

    // MARK: - Mnemonics

    static let validMnemonic12Words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    static let validMnemonic24Words = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"

    static let invalidMnemonic = "invalid mnemonic phrase that does not follow BIP39"

    static let testMnemonics = [
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about",
        "legal winner thank year wave sausage worth useful legal winner thank yellow",
        "letter advice cage absurd amount doctor acoustic avoid letter advice cage above"
    ]

    // MARK: - Bitcoin Addresses

    static let testnetSegWitAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
    static let testnetSegWitAddress2 = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7"
    static let mainnetSegWitAddress = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"

    static let testnetLegacyAddress = "mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn"
    static let mainnetLegacyAddress = "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"

    static let invalidAddress = "invalid_bitcoin_address_12345"

    // MARK: - Private Keys

    static func generateTestPrivateKey() -> Data {
        return Data(repeating: 0x01, count: 32)
    }

    static func generateTestPublicKey() -> Data {
        return Data(repeating: 0x02, count: 33)
    }

    static let testPrivateKeyHex = "0000000000000000000000000000000000000000000000000000000000000001"
    static let testPublicKeyHex = "0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798"

    // MARK: - Transactions

    static func createTestUTXO(
        txid: String = "abc123def456",
        vout: UInt32 = 0,
        amount: UInt64 = 100000,
        address: String = testnetSegWitAddress
    ) -> UTXO {
        return UTXO(
            txid: txid,
            vout: vout,
            amount: amount,
            address: address
        )
    }

    static func createTestTransaction(
        id: String = "tx123",
        amount: UInt64 = 50000,
        type: TransactionType = .received,
        confirmations: Int = 6
    ) -> Transaction {
        return Transaction(
            id: id,
            amount: amount,
            type: type,
            timestamp: Date(),
            confirmations: confirmations
        )
    }

    static let testUTXOs = [
        UTXO(txid: "tx1", vout: 0, amount: 100000, address: testnetSegWitAddress),
        UTXO(txid: "tx2", vout: 1, amount: 50000, address: testnetSegWitAddress),
        UTXO(txid: "tx3", vout: 0, amount: 25000, address: testnetSegWitAddress)
    ]

    static let testTransactions = [
        Transaction(id: "tx1", amount: 100000, type: .received, timestamp: Date(), confirmations: 6),
        Transaction(id: "tx2", amount: 50000, type: .sent, timestamp: Date().addingTimeInterval(-3600), confirmations: 3),
        Transaction(id: "tx3", amount: 25000, type: .received, timestamp: Date().addingTimeInterval(-7200), confirmations: 10)
    ]

    // MARK: - Passwords

    static let strongPasswords = [
        "SecurePassword123!",
        "Tr0ng_P@ssw0rd",
        "MyS3cur3P@ss!",
        "C0mpl3x!Pass"
    ]

    static let weakPasswords = [
        "123",
        "password",
        "abc",
        "12345678",
        "qwerty"
    ]

    // MARK: - Network Data

    static let testFeeRates = FeeRates(
        fast: 50,
        medium: 30,
        slow: 10
    )

    static let testBlockHeight: UInt64 = 2_000_000

    // MARK: - Wallet Data

    static func createTestWallet(
        address: String = testnetSegWitAddress,
        mnemonic: String = validMnemonic12Words
    ) -> WalletInfo {
        return WalletInfo(
            address: address,
            mnemonic: mnemonic
        )
    }

    static func createTestBackup() -> WalletBackup {
        return WalletBackup(
            mnemonic: validMnemonic12Words,
            encryptedData: Data("encrypted_data".utf8),
            createdAt: Date()
        )
    }

    // MARK: - Crypto Data

    static func createTestSeed() -> Data {
        return Data(repeating: 0x01, count: 64)
    }

    static let testSeedHex = "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542"

    // MARK: - BIP32 Test Vectors

    static let bip32TestVectors: [(seed: String, path: String, expectedKey: String)] = [
        (
            seed: "000102030405060708090a0b0c0d0e0f",
            path: "m/0'/1/2'/2/1000000000",
            expectedKey: "test_key_1"
        )
    ]

    // MARK: - BIP39 Test Vectors

    static let bip39TestVectors: [(mnemonic: String, seed: String, passphrase: String)] = [
        (
            mnemonic: validMnemonic12Words,
            seed: "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4",
            passphrase: ""
        )
    ]

    // MARK: - Error Cases

    static let errorScenarios: [(description: String, error: Error)] = [
        ("Insufficient Funds", WalletError.insufficientFunds),
        ("Invalid Address", WalletError.invalidAddress),
        ("Wallet Locked", WalletError.walletLocked),
        ("Incorrect Password", WalletError.incorrectPassword),
        ("Weak Password", WalletError.weakPassword),
        ("Invalid Mnemonic", WalletError.invalidMnemonic)
    ]

    // MARK: - Date Helpers

    static let pastDate = Date().addingTimeInterval(-86400) // 1 day ago
    static let futureDate = Date().addingTimeInterval(86400) // 1 day from now
    static let veryOldDate = Date().addingTimeInterval(-365 * 86400) // 1 year ago

    // MARK: - Amount Helpers

    static let satoshiInBTC: UInt64 = 100_000_000
    static let dustAmount: UInt64 = 546
    static let minimumAmount: UInt64 = 1000
    static let typicalAmount: UInt64 = 100_000
    static let largeAmount: UInt64 = 1_000_000_000

    // MARK: - Network URLs

    static let testnetAPIURL = "https://blockstream.info/testnet/api"
    static let mainnetAPIURL = "https://blockstream.info/api"
    static let mockAPIURL = "https://mock.api.example.com"
}
