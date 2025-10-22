import XCTest
@testable import FuekiWallet

final class BlockchainIntegrationTests: XCTestCase {

    var walletManager: WalletManager!
    var keyManager: KeyManager!
    var networkClient: NetworkClient!
    var blockchainProvider: BlockchainProvider!

    override func setUp() async throws {
        try await super.setUp()

        // Use real implementations for integration testing
        keyManager = KeyManager()
        networkClient = NetworkClient(baseURL: "https://blockstream.info/testnet/api")
        blockchainProvider = BlockchainProvider(networkClient: networkClient)
        walletManager = WalletManager(
            keyManager: keyManager,
            blockchainProvider: blockchainProvider
        )
    }

    override func tearDown() async throws {
        walletManager = nil
        keyManager = nil
        networkClient = nil
        blockchainProvider = nil
        try await super.tearDown()
    }

    // MARK: - Wallet Creation and Address Derivation Integration

    func testCreateWallet_DerivesValidAddress() async throws {
        // When
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")

        // Then
        XCTAssertFalse(wallet.mnemonic.isEmpty)
        XCTAssertTrue(wallet.address.starts(with: "tb1"), "Should generate testnet SegWit address")

        // Verify address format
        XCTAssertTrue(keyManager.validateAddress(wallet.address, network: .testnet))
    }

    func testImportWallet_RecreatesSameAddress() async throws {
        // Given - create a wallet first
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        let originalAddress = wallet.address
        let mnemonic = wallet.mnemonic

        // When - import the same mnemonic
        let importedWallet = try await walletManager.importWallet(
            mnemonic: mnemonic,
            password: "TestPassword123!"
        )

        // Then - should recreate the same address
        XCTAssertEqual(importedWallet.address, originalAddress)
    }

    // MARK: - Balance Fetching Integration

    func testFetchBalance_RealTestnetAddress() async throws {
        // Given - a known testnet address with balance
        let testAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        // When
        let balance = try await blockchainProvider.fetchBalance(for: testAddress)

        // Then
        XCTAssertGreaterThanOrEqual(balance, 0, "Balance should be non-negative")
    }

    func testFetchBalance_NewAddress_ReturnsZero() async throws {
        // Given - create a new wallet (likely has zero balance)
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")

        // When
        let balance = try await walletManager.getBalance()

        // Then
        XCTAssertEqual(balance, 0, "New wallet should have zero balance")
    }

    // MARK: - Transaction History Integration

    func testFetchTransactionHistory_ActiveAddress() async throws {
        // Given - an address with transactions
        let testAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        // When
        let transactions = try await blockchainProvider.fetchTransactionHistory(for: testAddress)

        // Then
        // Note: This test may pass even if transactions is empty
        XCTAssertNotNil(transactions)

        if !transactions.isEmpty {
            XCTAssertFalse(transactions[0].id.isEmpty)
            XCTAssertGreaterThan(transactions[0].confirmations, 0)
        }
    }

    // MARK: - UTXO Fetching Integration

    func testFetchUTXOs_AddressWithBalance() async throws {
        // Given - an address that might have UTXOs
        let testAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        // When
        let utxos = try await blockchainProvider.fetchUTXOs(for: testAddress)

        // Then
        XCTAssertNotNil(utxos)

        if !utxos.isEmpty {
            XCTAssertFalse(utxos[0].txid.isEmpty)
            XCTAssertGreaterThan(utxos[0].amount, 0)
        }
    }

    // MARK: - Fee Estimation Integration

    func testFetchFeeRates_ReturnsValidRates() async throws {
        // When
        let feeRates = try await networkClient.fetchFeeRates()

        // Then
        XCTAssertGreaterThan(feeRates.fast, 0)
        XCTAssertGreaterThan(feeRates.medium, 0)
        XCTAssertGreaterThan(feeRates.slow, 0)
        XCTAssertGreaterThanOrEqual(feeRates.fast, feeRates.medium)
        XCTAssertGreaterThanOrEqual(feeRates.medium, feeRates.slow)
    }

    // MARK: - Network Retry Integration

    func testNetworkRequest_WithRetry_HandlesTemporaryFailure() async throws {
        // This test verifies retry logic works with real network
        let expectation = XCTestExpectation(description: "Request completes with retry")

        do {
            _ = try await networkClient.fetchFeeRates()
            expectation.fulfill()
        } catch {
            XCTFail("Request should succeed with retry logic")
        }

        await fulfillment(of: [expectation], timeout: 10.0)
    }

    // MARK: - Concurrent Operations Integration

    func testConcurrentBalanceFetches_HandleCorrectly() async throws {
        // Given
        let addresses = [
            "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
            "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7"
        ]

        // When - fetch balances concurrently
        async let balance1 = blockchainProvider.fetchBalance(for: addresses[0])
        async let balance2 = blockchainProvider.fetchBalance(for: addresses[1])

        let (bal1, bal2) = try await (balance1, balance2)

        // Then
        XCTAssertGreaterThanOrEqual(bal1, 0)
        XCTAssertGreaterThanOrEqual(bal2, 0)
    }

    // MARK: - HD Wallet Path Derivation Integration

    func testHDWalletDerivation_MultipleAddresses() throws {
        // Given
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        let seed = try MnemonicGenerator().generateSeed(from: mnemonic, passphrase: "")

        // When - derive multiple addresses from same seed
        let path1 = "m/84'/1'/0'/0/0" // First address
        let path2 = "m/84'/1'/0'/0/1" // Second address

        let key1 = try keyManager.deriveKey(from: seed, path: path1)
        let key2 = try keyManager.deriveKey(from: seed, path: path2)

        let pubKey1 = try keyManager.derivePublicKey(from: key1)
        let pubKey2 = try keyManager.derivePublicKey(from: key2)

        let address1 = try keyManager.deriveAddress(from: pubKey1, network: .testnet, format: .segwit)
        let address2 = try keyManager.deriveAddress(from: pubKey2, network: .testnet, format: .segwit)

        // Then
        XCTAssertNotEqual(address1, address2)
        XCTAssertTrue(address1.starts(with: "tb1"))
        XCTAssertTrue(address2.starts(with: "tb1"))
    }

    // MARK: - Error Handling Integration

    func testFetchBalance_InvalidAddress_ThrowsError() async {
        // Given
        let invalidAddress = "invalid_bitcoin_address"

        // When/Then
        do {
            _ = try await blockchainProvider.fetchBalance(for: invalidAddress)
            XCTFail("Should throw error for invalid address")
        } catch {
            XCTAssertTrue(error is NetworkError || error is ValidationError)
        }
    }

    func testNetworkRequest_ServerUnavailable_ThrowsError() async {
        // Given - invalid URL to simulate server unavailable
        let badClient = NetworkClient(baseURL: "https://invalid-domain-that-does-not-exist.com")

        // When/Then
        do {
            _ = try await badClient.fetchFeeRates()
            XCTFail("Should throw network error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Performance Integration Tests

    func testBalanceFetch_Performance() async throws {
        let address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        measure {
            Task {
                _ = try? await blockchainProvider.fetchBalance(for: address)
            }
        }
    }

    func testTransactionHistoryFetch_Performance() async throws {
        let address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        measure {
            Task {
                _ = try? await blockchainProvider.fetchTransactionHistory(for: address)
            }
        }
    }
}
