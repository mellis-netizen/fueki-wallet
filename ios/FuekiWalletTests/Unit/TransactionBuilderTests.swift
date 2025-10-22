import XCTest
@testable import FuekiWallet

final class TransactionBuilderTests: XCTestCase {

    var transactionBuilder: TransactionBuilder!
    var mockKeyManager: MockKeyManager!
    var mockNetworkClient: MockNetworkClient!

    override func setUp() {
        super.setUp()
        mockKeyManager = MockKeyManager()
        mockNetworkClient = MockNetworkClient()
        transactionBuilder = TransactionBuilder(
            keyManager: mockKeyManager,
            networkClient: mockNetworkClient
        )
    }

    override func tearDown() {
        transactionBuilder = nil
        mockKeyManager = nil
        mockNetworkClient = nil
        super.tearDown()
    }

    // MARK: - Basic Transaction Building Tests

    func testBuildTransaction_BasicTransfer_Success() throws {
        // Given
        let recipientAddress = "tb1qrecipient123"
        let amount: UInt64 = 100000 // 0.001 BTC
        let fee: UInt64 = 1000

        mockNetworkClient.mockUTXOs = [
            UTXO(txid: "abc123", vout: 0, amount: 200000, address: "tb1qsender123")
        ]
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        // When
        let transaction = try transactionBuilder.buildTransaction(
            to: recipientAddress,
            amount: amount,
            fee: fee
        )

        // Then
        XCTAssertEqual(transaction.outputs.count, 2) // payment + change
        XCTAssertEqual(transaction.outputs[0].amount, amount)
        XCTAssertEqual(transaction.outputs[0].address, recipientAddress)
        XCTAssertEqual(transaction.inputs.count, 1)
    }

    func testBuildTransaction_ExactAmount_NoChange() throws {
        // Given
        let recipientAddress = "tb1qrecipient123"
        let amount: UInt64 = 99000
        let fee: UInt64 = 1000
        let utxoAmount: UInt64 = 100000

        mockNetworkClient.mockUTXOs = [
            UTXO(txid: "abc123", vout: 0, amount: utxoAmount, address: "tb1qsender123")
        ]
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        // When
        let transaction = try transactionBuilder.buildTransaction(
            to: recipientAddress,
            amount: amount,
            fee: fee
        )

        // Then
        XCTAssertEqual(transaction.outputs.count, 1) // Only payment, no change
        XCTAssertEqual(transaction.outputs[0].amount, amount)
    }

    func testBuildTransaction_MultipleInputs_Success() throws {
        // Given
        let recipientAddress = "tb1qrecipient123"
        let amount: UInt64 = 150000
        let fee: UInt64 = 2000

        mockNetworkClient.mockUTXOs = [
            UTXO(txid: "abc123", vout: 0, amount: 80000, address: "tb1qsender123"),
            UTXO(txid: "def456", vout: 1, amount: 80000, address: "tb1qsender123")
        ]
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        // When
        let transaction = try transactionBuilder.buildTransaction(
            to: recipientAddress,
            amount: amount,
            fee: fee
        )

        // Then
        XCTAssertEqual(transaction.inputs.count, 2)
        XCTAssertEqual(transaction.outputs.count, 2) // payment + change
    }

    func testBuildTransaction_InsufficientFunds_ThrowsError() {
        // Given
        let recipientAddress = "tb1qrecipient123"
        let amount: UInt64 = 200000
        let fee: UInt64 = 1000

        mockNetworkClient.mockUTXOs = [
            UTXO(txid: "abc123", vout: 0, amount: 100000, address: "tb1qsender123")
        ]

        // When/Then
        XCTAssertThrowsError(
            try transactionBuilder.buildTransaction(to: recipientAddress, amount: amount, fee: fee)
        ) { error in
            XCTAssertTrue(error is TransactionError.insufficientFunds)
        }
    }

    func testBuildTransaction_InvalidAddress_ThrowsError() {
        // Given
        let invalidAddress = "invalid_bitcoin_address"
        let amount: UInt64 = 100000
        let fee: UInt64 = 1000

        // When/Then
        XCTAssertThrowsError(
            try transactionBuilder.buildTransaction(to: invalidAddress, amount: amount, fee: fee)
        ) { error in
            XCTAssertTrue(error is TransactionError.invalidAddress)
        }
    }

    func testBuildTransaction_ZeroAmount_ThrowsError() {
        // Given
        let recipientAddress = "tb1qrecipient123"
        let amount: UInt64 = 0
        let fee: UInt64 = 1000

        // When/Then
        XCTAssertThrowsError(
            try transactionBuilder.buildTransaction(to: recipientAddress, amount: amount, fee: fee)
        ) { error in
            XCTAssertTrue(error is TransactionError.invalidAmount)
        }
    }

    // MARK: - Fee Calculation Tests

    func testCalculateFee_Standard_Success() throws {
        // Given
        let transaction = Transaction(
            inputs: [
                TransactionInput(txid: "abc123", vout: 0, amount: 100000)
            ],
            outputs: [
                TransactionOutput(address: "tb1qrecipient", amount: 90000),
                TransactionOutput(address: "tb1qchange", amount: 9000)
            ]
        )
        let feeRate: UInt64 = 10 // satoshis per byte

        // When
        let calculatedFee = try transactionBuilder.calculateFee(for: transaction, feeRate: feeRate)

        // Then
        XCTAssertGreaterThan(calculatedFee, 0)
        XCTAssertLessThan(calculatedFee, 10000) // Reasonable upper bound
    }

    func testEstimateTransactionSize_SingleInput_SingleOutput() {
        // Given
        let inputCount = 1
        let outputCount = 1

        // When
        let size = transactionBuilder.estimateTransactionSize(inputs: inputCount, outputs: outputCount)

        // Then
        XCTAssertGreaterThan(size, 0)
        XCTAssertEqual(size, 191) // Approximate size for 1-in, 1-out P2WPKH
    }

    func testEstimateTransactionSize_MultipleInputsOutputs() {
        // Given
        let inputCount = 3
        let outputCount = 2

        // When
        let size = transactionBuilder.estimateTransactionSize(inputs: inputCount, outputs: outputCount)

        // Then
        XCTAssertGreaterThan(size, 191) // Should be larger than single input/output
    }

    func testCalculateOptimalFee_LowPriority() async throws {
        // Given
        mockNetworkClient.mockFeeRates = FeeRates(
            fast: 50,
            medium: 30,
            slow: 10
        )

        // When
        let fee = try await transactionBuilder.calculateOptimalFee(
            inputs: 1,
            outputs: 2,
            priority: .low
        )

        // Then
        XCTAssertGreaterThan(fee, 0)
        XCTAssertEqual(fee, 10 * 191) // slowest rate * size
    }

    func testCalculateOptimalFee_HighPriority() async throws {
        // Given
        mockNetworkClient.mockFeeRates = FeeRates(
            fast: 50,
            medium: 30,
            slow: 10
        )

        // When
        let fee = try await transactionBuilder.calculateOptimalFee(
            inputs: 1,
            outputs: 2,
            priority: .high
        )

        // Then
        XCTAssertGreaterThan(fee, 0)
        XCTAssertEqual(fee, 50 * 191) // fastest rate * size
    }

    // MARK: - UTXO Selection Tests

    func testSelectUTXOs_GreedyAlgorithm_SelectsMinimal() throws {
        // Given
        let targetAmount: UInt64 = 100000
        let utxos = [
            UTXO(txid: "a", vout: 0, amount: 150000, address: "tb1q1"),
            UTXO(txid: "b", vout: 0, amount: 50000, address: "tb1q2"),
            UTXO(txid: "c", vout: 0, amount: 25000, address: "tb1q3")
        ]

        // When
        let selected = try transactionBuilder.selectUTXOs(
            from: utxos,
            targetAmount: targetAmount,
            feePerByte: 10
        )

        // Then
        XCTAssertGreaterThanOrEqual(selected.reduce(0) { $0 + $1.amount }, targetAmount)
        XCTAssertLessThanOrEqual(selected.count, utxos.count)
    }

    func testSelectUTXOs_InsufficientTotal_ThrowsError() {
        // Given
        let targetAmount: UInt64 = 500000
        let utxos = [
            UTXO(txid: "a", vout: 0, amount: 100000, address: "tb1q1"),
            UTXO(txid: "b", vout: 0, amount: 50000, address: "tb1q2")
        ]

        // When/Then
        XCTAssertThrowsError(
            try transactionBuilder.selectUTXOs(from: utxos, targetAmount: targetAmount, feePerByte: 10)
        ) { error in
            XCTAssertTrue(error is TransactionError.insufficientFunds)
        }
    }

    func testSelectUTXOs_EmptyList_ThrowsError() {
        // Given
        let targetAmount: UInt64 = 100000
        let utxos: [UTXO] = []

        // When/Then
        XCTAssertThrowsError(
            try transactionBuilder.selectUTXOs(from: utxos, targetAmount: targetAmount, feePerByte: 10)
        )
    }

    // MARK: - Transaction Signing Tests

    func testSignTransaction_Success() throws {
        // Given
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockSignature = Data(repeating: 0x02, count: 64)

        // When
        let signedTransaction = try transactionBuilder.signTransaction(transaction)

        // Then
        XCTAssertTrue(signedTransaction.isSigned)
        XCTAssertEqual(signedTransaction.inputs.count, transaction.inputs.count)
        XCTAssertNotNil(signedTransaction.inputs[0].signature)
    }

    func testSignTransaction_MultipleInputs_AllSigned() throws {
        // Given
        let transaction = Transaction(
            inputs: [
                TransactionInput(txid: "abc123", vout: 0, amount: 50000),
                TransactionInput(txid: "def456", vout: 1, amount: 60000)
            ],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 100000)]
        )
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockSignature = Data(repeating: 0x02, count: 64)

        // When
        let signedTransaction = try transactionBuilder.signTransaction(transaction)

        // Then
        XCTAssertTrue(signedTransaction.isSigned)
        for input in signedTransaction.inputs {
            XCTAssertNotNil(input.signature)
        }
    }

    func testSignTransaction_NoPrivateKey_ThrowsError() {
        // Given
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        mockKeyManager.mockPrivateKey = nil

        // When/Then
        XCTAssertThrowsError(try transactionBuilder.signTransaction(transaction))
    }

    // MARK: - Transaction Serialization Tests

    func testSerializeTransaction_Success() throws {
        // Given
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockSignature = Data(repeating: 0x02, count: 64)
        let signedTransaction = try transactionBuilder.signTransaction(transaction)

        // When
        let serialized = try transactionBuilder.serializeTransaction(signedTransaction)

        // Then
        XCTAssertFalse(serialized.isEmpty)
        XCTAssertGreaterThan(serialized.count, 100) // Reasonable minimum size
    }

    func testSerializeTransaction_UnsignedTransaction_ThrowsError() {
        // Given
        let unsignedTransaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )

        // When/Then
        XCTAssertThrowsError(
            try transactionBuilder.serializeTransaction(unsignedTransaction)
        ) { error in
            XCTAssertTrue(error is TransactionError.unsignedTransaction)
        }
    }

    func testDeserializeTransaction_Success() throws {
        // Given
        let originalTransaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockSignature = Data(repeating: 0x02, count: 64)
        let signedTransaction = try transactionBuilder.signTransaction(originalTransaction)
        let serialized = try transactionBuilder.serializeTransaction(signedTransaction)

        // When
        let deserialized = try transactionBuilder.deserializeTransaction(serialized)

        // Then
        XCTAssertEqual(deserialized.inputs.count, originalTransaction.inputs.count)
        XCTAssertEqual(deserialized.outputs.count, originalTransaction.outputs.count)
    }

    // MARK: - SegWit Transaction Tests

    func testBuildSegWitTransaction_Success() throws {
        // Given
        let recipientAddress = "tb1qrecipient123"
        let amount: UInt64 = 100000
        let fee: UInt64 = 1000

        mockNetworkClient.mockUTXOs = [
            UTXO(txid: "abc123", vout: 0, amount: 200000, address: "tb1qsender123", isSegWit: true)
        ]
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        // When
        let transaction = try transactionBuilder.buildSegWitTransaction(
            to: recipientAddress,
            amount: amount,
            fee: fee
        )

        // Then
        XCTAssertTrue(transaction.isSegWit)
        XCTAssertEqual(transaction.outputs[0].amount, amount)
    }

    func testCalculateSegWitFee_LowerThanLegacy() throws {
        // Given
        let segwitTx = Transaction(
            inputs: [TransactionInput(txid: "abc", vout: 0, amount: 100000, isSegWit: true)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        let legacyTx = Transaction(
            inputs: [TransactionInput(txid: "abc", vout: 0, amount: 100000, isSegWit: false)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        let feeRate: UInt64 = 10

        // When
        let segwitFee = try transactionBuilder.calculateFee(for: segwitTx, feeRate: feeRate)
        let legacyFee = try transactionBuilder.calculateFee(for: legacyTx, feeRate: feeRate)

        // Then
        XCTAssertLessThan(segwitFee, legacyFee, "SegWit fee should be lower than legacy")
    }

    // MARK: - Transaction Validation Tests

    func testValidateTransaction_ValidTransaction_ReturnsTrue() throws {
        // Given
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockSignature = Data(repeating: 0x02, count: 64)
        let signedTransaction = try transactionBuilder.signTransaction(transaction)

        // When
        let isValid = try transactionBuilder.validateTransaction(signedTransaction)

        // Then
        XCTAssertTrue(isValid)
    }

    func testValidateTransaction_NegativeFee_ReturnsFalse() throws {
        // Given - outputs exceed inputs
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 110000)]
        )

        // When
        let isValid = try transactionBuilder.validateTransaction(transaction)

        // Then
        XCTAssertFalse(isValid)
    }

    func testValidateTransaction_DustOutput_ReturnsFalse() throws {
        // Given - output below dust threshold
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 100)] // Too small
        )

        // When
        let isValid = try transactionBuilder.validateTransaction(transaction)

        // Then
        XCTAssertFalse(isValid)
    }

    // MARK: - Performance Tests

    func testBuildTransactionPerformance() throws {
        mockNetworkClient.mockUTXOs = [
            UTXO(txid: "abc123", vout: 0, amount: 200000, address: "tb1qsender123")
        ]
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)

        measure {
            _ = try? transactionBuilder.buildTransaction(
                to: "tb1qrecipient123",
                amount: 100000,
                fee: 1000
            )
        }
    }

    func testSignTransactionPerformance() throws {
        let transaction = Transaction(
            inputs: [TransactionInput(txid: "abc123", vout: 0, amount: 100000)],
            outputs: [TransactionOutput(address: "tb1qrecipient", amount: 90000)]
        )
        mockKeyManager.mockPrivateKey = Data(repeating: 0x01, count: 32)
        mockKeyManager.mockSignature = Data(repeating: 0x02, count: 64)

        measure {
            _ = try? transactionBuilder.signTransaction(transaction)
        }
    }
}
