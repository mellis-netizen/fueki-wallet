//
//  BlockchainProvidersTests.swift
//  FuekiWalletTests
//
//  Comprehensive tests for Ethereum, Bitcoin, and Solana providers
//

import XCTest
@testable import FuekiWallet

final class EthereumProviderTests: XCTestCase {

    var sut: EthereumProvider!
    var mockNetworkClient: MockNetworkClient!

    override func setUp() {
        mockNetworkClient = MockNetworkClient()
        sut = EthereumProvider(
            rpcURL: "https://mainnet.infura.io/v3/test",
            networkClient: mockNetworkClient
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
    }

    // MARK: - Balance Tests

    func testFetchBalance_Success() async throws {
        // Given
        mockNetworkClient.mockBalance = "0x16345785d8a0000" // 0.1 ETH in hex wei

        // When
        let balance = try await sut.fetchBalance(for: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        // Then
        XCTAssertGreaterThan(balance, 0)
    }

    func testFetchBalance_NetworkError() async {
        // Given
        mockNetworkClient.shouldFailBalance = true

        // When/Then
        do {
            _ = try await sut.fetchBalance(for: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Transaction History Tests

    func testFetchTransactionHistory_Success() async throws {
        // Given
        mockNetworkClient.mockTransactions = [
            ["hash": "0xabc", "from": "0x123", "to": "0x456", "value": "0x1"],
            ["hash": "0xdef", "from": "0x789", "to": "0x123", "value": "0x2"]
        ]

        // When
        let transactions = try await sut.fetchTransactionHistory(for: "0x123")

        // Then
        XCTAssertEqual(transactions.count, 2)
    }

    // MARK: - Gas Estimation Tests

    func testEstimateGas_SimpleTransfer() async throws {
        // Given
        mockNetworkClient.mockGasEstimate = "0x5208" // 21000 in hex

        let request = TransactionRequest(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x1234567890123456789012345678901234567890",
            value: Decimal(string: "0.1")!,
            data: nil,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        // When
        let estimation = try await sut.estimateGas(for: request)

        // Then
        XCTAssertEqual(estimation.gasLimit, 21000)
    }

    // MARK: - Build Transaction Tests

    func testBuildTransaction_EIP1559() async throws {
        // Given
        mockNetworkClient.mockNonce = 5
        mockNetworkClient.mockChainId = 1

        let request = TransactionRequest(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x1234567890123456789012345678901234567890",
            value: Decimal(string: "0.1")!,
            data: nil,
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2),
            nonce: nil
        )

        // When
        let txData = try await sut.buildTransaction(request)

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    // MARK: - Address Validation Tests

    func testValidateAddress_ValidChecksum() {
        // Given
        let validAddress = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"

        // When
        let isValid = sut.validateAddress(validAddress)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateAddress_InvalidFormat() {
        // Given
        let invalidAddress = "not_an_address"

        // When
        let isValid = sut.validateAddress(invalidAddress)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateAddress_WrongLength() {
        // Given
        let wrongLength = "0x123"

        // When
        let isValid = sut.validateAddress(wrongLength)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Broadcast Transaction Tests

    func testBroadcastTransaction_Success() async throws {
        // Given
        let signedTx = Data([0x01, 0x02, 0x03])
        mockNetworkClient.mockTransactionHash = "0xabc123"

        // When
        let txHash = try await sut.broadcastTransaction(signedTx)

        // Then
        XCTAssertEqual(txHash, "0xabc123")
    }
}

final class BitcoinProviderTests: XCTestCase {

    var sut: BitcoinProvider!
    var mockNetworkClient: MockNetworkClient!

    override func setUp() {
        mockNetworkClient = MockNetworkClient()
        sut = BitcoinProvider(
            rpcURL: "https://blockstream.info/api",
            networkClient: mockNetworkClient,
            network: .testnet
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
    }

    // MARK: - Balance Tests

    func testFetchBalance_Success() async throws {
        // Given
        mockNetworkClient.mockUTXOs = [
            ["value": 100000],
            ["value": 200000],
            ["value": 50000]
        ]

        // When
        let balance = try await sut.fetchBalance(for: "tb1qtest")

        // Then
        XCTAssertEqual(balance, 350000) // satoshis
    }

    // MARK: - UTXO Tests

    func testFetchUTXOs_Success() async throws {
        // Given
        mockNetworkClient.mockUTXOs = [
            ["txid": "abc", "vout": 0, "value": 100000],
            ["txid": "def", "vout": 1, "value": 200000]
        ]

        // When
        let utxos = try await sut.fetchUTXOs(for: "tb1qtest")

        // Then
        XCTAssertEqual(utxos.count, 2)
        XCTAssertEqual(utxos[0].value, 100000)
        XCTAssertEqual(utxos[1].value, 200000)
    }

    // MARK: - Address Validation Tests

    func testValidateAddress_ValidBech32() {
        // Given
        let validAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"

        // When
        let isValid = sut.validateAddress(validAddress)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateAddress_ValidLegacy() {
        // Given
        let validAddress = "mhfJsQNnrXB3uuYZqvywARTDfuvyjg4RBh"

        // When
        let isValid = sut.validateAddress(validAddress)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateAddress_Invalid() {
        // Given
        let invalidAddress = "invalid_btc_address"

        // When
        let isValid = sut.validateAddress(invalidAddress)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Transaction Building Tests

    func testBuildTransaction_SingleInput() async throws {
        // Given
        mockNetworkClient.mockUTXOs = [
            ["txid": "abc123", "vout": 0, "value": 1000000]
        ]

        let request = TransactionRequest(
            from: "tb1qsender",
            to: "tb1qrecipient",
            value: Decimal(500000),
            data: nil,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        // When
        let txData = try await sut.buildTransaction(request)

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    // MARK: - Fee Estimation Tests

    func testEstimateFees_Success() async throws {
        // Given
        mockNetworkClient.mockFeeRates = [
            "fastestFee": 50,
            "halfHourFee": 30,
            "hourFee": 10
        ]

        // When
        let feeRates = try await sut.fetchFeeRates()

        // Then
        XCTAssertEqual(feeRates.fast, 50)
        XCTAssertEqual(feeRates.medium, 30)
        XCTAssertEqual(feeRates.slow, 10)
    }
}

final class SolanaProviderTests: XCTestCase {

    var sut: SolanaProvider!
    var mockNetworkClient: MockNetworkClient!

    override func setUp() {
        mockNetworkClient = MockNetworkClient()
        sut = SolanaProvider(
            rpcURL: "https://api.devnet.solana.com",
            networkClient: mockNetworkClient
        )
    }

    override func tearDown() {
        sut = nil
        mockNetworkClient = nil
    }

    // MARK: - Balance Tests

    func testFetchBalance_Success() async throws {
        // Given
        mockNetworkClient.mockBalance = "1500000000" // 1.5 SOL in lamports

        // When
        let balance = try await sut.fetchBalance(for: "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK")

        // Then
        XCTAssertEqual(balance, 1500000000)
    }

    // MARK: - Transaction History Tests

    func testFetchTransactionHistory_Success() async throws {
        // Given
        mockNetworkClient.mockTransactions = [
            ["signature": "sig1", "slot": 100],
            ["signature": "sig2", "slot": 101]
        ]

        // When
        let transactions = try await sut.fetchTransactionHistory(
            for: "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK"
        )

        // Then
        XCTAssertEqual(transactions.count, 2)
    }

    // MARK: - Address Validation Tests

    func testValidateAddress_Valid() {
        // Given
        let validAddress = "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK"

        // When
        let isValid = sut.validateAddress(validAddress)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateAddress_Invalid() {
        // Given
        let invalidAddress = "invalid_solana_address"

        // When
        let isValid = sut.validateAddress(invalidAddress)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Transaction Building Tests

    func testBuildTransaction_SOLTransfer() async throws {
        // Given
        mockNetworkClient.mockRecentBlockhash = "BlockhashABC123"

        let request = TransactionRequest(
            from: "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK",
            to: "FWXJnF8y6r4TfCpKqQ5YC1PBv3wz3bJfJSqRuqPvmNmV",
            value: Decimal(string: "1.5")!,
            data: nil,
            gasLimit: nil,
            maxFeePerGas: nil,
            maxPriorityFeePerGas: nil,
            nonce: nil
        )

        // When
        let txData = try await sut.buildTransaction(request)

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    // MARK: - Rent Estimation Tests

    func testCalculateRentExemption_Success() async throws {
        // Given
        mockNetworkClient.mockRentExemption = 2039280 // lamports

        // When
        let rentExemption = try await sut.calculateRentExemption(dataLength: 165)

        // Then
        XCTAssertEqual(rentExemption, 2039280)
    }

    // MARK: - Broadcast Transaction Tests

    func testBroadcastTransaction_Success() async throws {
        // Given
        let signedTx = Data([0x01, 0x02, 0x03])
        mockNetworkClient.mockTransactionSignature = "5VERv8NMvzbJMEkV8xnrLkEaWRtSz9CosKDYjCJjBRnbJLgp8uirBgmQpjKhoR4tjF3ZpRzrFmBV6UjKdiSZkQUW"

        // When
        let signature = try await sut.broadcastTransaction(signedTx)

        // Then
        XCTAssertGreaterThan(signature.count, 0)
    }
}
