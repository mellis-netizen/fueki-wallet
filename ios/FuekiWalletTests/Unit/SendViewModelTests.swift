//
//  SendViewModelTests.swift
//  FuekiWalletTests
//
//  Comprehensive ViewModel tests for Send functionality
//

import XCTest
import Combine
@testable import FuekiWallet

@MainActor
final class SendViewModelTests: XCTestCase {

    var sut: SendViewModel!
    var mockWalletService: MockWalletService!
    var mockTransactionService: MockTransactionService!
    var mockNetworkClient: MockNetworkClient!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockWalletService = MockWalletService()
        mockTransactionService = MockTransactionService()
        mockNetworkClient = MockNetworkClient()
        cancellables = []

        sut = SendViewModel(
            walletService: mockWalletService,
            transactionService: mockTransactionService,
            networkClient: mockNetworkClient
        )
    }

    override func tearDown() {
        sut = nil
        mockWalletService = nil
        mockTransactionService = nil
        mockNetworkClient = nil
        cancellables = nil
    }

    // MARK: - Recipient Validation Tests

    func testRecipientAddressValidation_ValidEthereumAddress() {
        // Given
        let validAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"

        // When
        sut.recipientAddress = validAddress

        // Then
        XCTAssertTrue(sut.isValidRecipient)
        XCTAssertNil(sut.recipientError)
    }

    func testRecipientAddressValidation_InvalidAddress() {
        // Given
        let invalidAddress = "invalid_address"

        // When
        sut.recipientAddress = invalidAddress

        // Then
        XCTAssertFalse(sut.isValidRecipient)
        XCTAssertNotNil(sut.recipientError)
    }

    func testRecipientAddressValidation_EmptyAddress() {
        // Given
        let emptyAddress = ""

        // When
        sut.recipientAddress = emptyAddress

        // Then
        XCTAssertFalse(sut.isValidRecipient)
    }

    // MARK: - Amount Validation Tests

    func testAmountValidation_ValidAmount() {
        // Given
        sut.availableBalance = Decimal(1000000) // 0.01 ETH in wei

        // When
        sut.amount = "0.005"

        // Then
        XCTAssertTrue(sut.isValidAmount)
        XCTAssertNil(sut.amountError)
    }

    func testAmountValidation_ExceedsBalance() {
        // Given
        sut.availableBalance = Decimal(100000)

        // When
        sut.amount = "1.0"

        // Then
        XCTAssertFalse(sut.isValidAmount)
        XCTAssertEqual(sut.amountError, "Insufficient balance")
    }

    func testAmountValidation_NegativeAmount() {
        // Given/When
        sut.amount = "-0.5"

        // Then
        XCTAssertFalse(sut.isValidAmount)
        XCTAssertNotNil(sut.amountError)
    }

    func testAmountValidation_ZeroAmount() {
        // Given/When
        sut.amount = "0"

        // Then
        XCTAssertFalse(sut.isValidAmount)
        XCTAssertEqual(sut.amountError, "Amount must be greater than zero")
    }

    func testAmountValidation_InvalidFormat() {
        // Given/When
        sut.amount = "abc"

        // Then
        XCTAssertFalse(sut.isValidAmount)
        XCTAssertNotNil(sut.amountError)
    }

    // MARK: - Gas Estimation Tests

    func testEstimateGasFees_Success() async {
        // Given
        mockNetworkClient.mockGasEstimation = GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2),
            estimatedCost: Decimal(0.00105)
        )

        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        sut.amount = "0.1"

        // When
        await sut.estimateGasFees()

        // Then
        XCTAssertFalse(sut.isEstimatingGas)
        XCTAssertNotNil(sut.gasEstimation)
        XCTAssertEqual(sut.gasEstimation?.gasLimit, 21000)
        XCTAssertNil(sut.errorMessage)
    }

    func testEstimateGasFees_NetworkFailure() async {
        // Given
        mockNetworkClient.shouldFailGasEstimation = true
        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        sut.amount = "0.1"

        // When
        await sut.estimateGasFees()

        // Then
        XCTAssertFalse(sut.isEstimatingGas)
        XCTAssertNil(sut.gasEstimation)
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Send Transaction Tests

    func testSendTransaction_Success() async {
        // Given
        mockTransactionService.mockTransactionID = "0xabc123"
        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        sut.amount = "0.1"
        sut.availableBalance = Decimal(1000000000)

        // When
        let result = await sut.sendTransaction()

        // Then
        XCTAssertTrue(result)
        XCTAssertFalse(sut.isSending)
        XCTAssertEqual(sut.transactionID, "0xabc123")
        XCTAssertNil(sut.errorMessage)
    }

    func testSendTransaction_InvalidRecipient() async {
        // Given
        sut.recipientAddress = "invalid"
        sut.amount = "0.1"

        // When
        let result = await sut.sendTransaction()

        // Then
        XCTAssertFalse(result)
        XCTAssertFalse(sut.isSending)
        XCTAssertNil(sut.transactionID)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testSendTransaction_InsufficientBalance() async {
        // Given
        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        sut.amount = "100.0"
        sut.availableBalance = Decimal(1000)

        // When
        let result = await sut.sendTransaction()

        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertTrue(sut.errorMessage!.contains("Insufficient"))
    }

    func testSendTransaction_ServiceFailure() async {
        // Given
        mockTransactionService.shouldFailSend = true
        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        sut.amount = "0.1"
        sut.availableBalance = Decimal(1000000000)

        // When
        let result = await sut.sendTransaction()

        // Then
        XCTAssertFalse(result)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertNil(sut.transactionID)
    }

    // MARK: - Max Amount Tests

    func testSetMaxAmount_WithoutGas() {
        // Given
        sut.availableBalance = Decimal(1000000)

        // When
        sut.setMaxAmount()

        // Then
        XCTAssertNotNil(sut.amount)
        XCTAssertTrue(Decimal(string: sut.amount) ?? 0 <= sut.availableBalance)
    }

    func testSetMaxAmount_WithGasEstimation() {
        // Given
        sut.availableBalance = Decimal(1000000)
        sut.gasEstimation = GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2),
            estimatedCost: Decimal(10000)
        )

        // When
        sut.setMaxAmount()

        // Then
        let expectedMax = sut.availableBalance - Decimal(10000)
        XCTAssertEqual(Decimal(string: sut.amount), expectedMax)
    }

    // MARK: - Currency Conversion Tests

    func testUSDConversion_Updates() async {
        // Given
        mockNetworkClient.mockPriceData = PriceData(
            currentPrice: Decimal(2000),
            price24hAgo: Decimal(1950),
            volume24h: Decimal(1000000),
            marketCap: Decimal(240000000000)
        )

        sut.amount = "0.5"

        // When
        await sut.updateUSDValue()

        // Then
        XCTAssertEqual(sut.usdValue, Decimal(1000))
    }

    // MARK: - Form Reset Tests

    func testResetForm_ClearsAllFields() {
        // Given
        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        sut.amount = "0.1"
        sut.transactionID = "0xabc"
        sut.errorMessage = "Some error"

        // When
        sut.resetForm()

        // Then
        XCTAssertTrue(sut.recipientAddress.isEmpty)
        XCTAssertTrue(sut.amount.isEmpty)
        XCTAssertNil(sut.transactionID)
        XCTAssertNil(sut.errorMessage)
        XCTAssertNil(sut.gasEstimation)
    }

    // MARK: - QR Code Scanning Tests

    func testHandleQRCodeScan_ValidAddress() {
        // Given
        let scannedAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"

        // When
        sut.handleQRCodeScan(scannedAddress)

        // Then
        XCTAssertEqual(sut.recipientAddress, scannedAddress)
        XCTAssertNil(sut.recipientError)
    }

    func testHandleQRCodeScan_InvalidAddress() {
        // Given
        let scannedAddress = "invalid_qr_data"

        // When
        sut.handleQRCodeScan(scannedAddress)

        // Then
        XCTAssertNotNil(sut.errorMessage)
    }

    // MARK: - Reactive Updates Tests

    func testRecipientAddressChange_TriggersValidation() {
        // Given
        var validationTriggered = false

        sut.$isValidRecipient
            .dropFirst()
            .sink { _ in validationTriggered = true }
            .store(in: &cancellables)

        // When
        sut.recipientAddress = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"

        // Then
        XCTAssertTrue(validationTriggered)
    }

    func testAmountChange_UpdatesUSDValue() async {
        // Given
        mockNetworkClient.mockPriceData = PriceData(
            currentPrice: Decimal(2000),
            price24hAgo: Decimal(1950),
            volume24h: Decimal(1000000),
            marketCap: Decimal(240000000000)
        )

        // When
        sut.amount = "1.0"
        await sut.updateUSDValue()

        // Then
        XCTAssertEqual(sut.usdValue, Decimal(2000))
    }
}
