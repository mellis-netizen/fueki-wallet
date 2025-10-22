//
//  TransactionBuilderAdvancedTests.swift
//  FuekiWalletTests
//
//  Comprehensive transaction building and validation tests
//

import XCTest
@testable import FuekiWallet

final class TransactionBuilderAdvancedTests: XCTestCase {

    var ethereumBuilder: TransactionBuilder!
    var bitcoinBuilder: TransactionBuilder!
    var solanaBuilder: TransactionBuilder!
    var validator: TransactionValidator!

    var mockEthereumProvider: MockBlockchainProvider!
    var mockBitcoinProvider: MockBlockchainProvider!
    var mockSolanaProvider: MockBlockchainProvider!

    override func setUp() async throws {
        mockEthereumProvider = MockBlockchainProvider(chainType: .ethereum)
        mockBitcoinProvider = MockBlockchainProvider(chainType: .bitcoin)
        mockSolanaProvider = MockBlockchainProvider(chainType: .solana)

        ethereumBuilder = TransactionBuilder(provider: mockEthereumProvider)
        bitcoinBuilder = TransactionBuilder(provider: mockBitcoinProvider)
        solanaBuilder = TransactionBuilder(provider: mockSolanaProvider)

        validator = TransactionValidator(provider: mockEthereumProvider)
    }

    override func tearDown() {
        ethereumBuilder = nil
        bitcoinBuilder = nil
        solanaBuilder = nil
        validator = nil
        mockEthereumProvider = nil
        mockBitcoinProvider = nil
        mockSolanaProvider = nil
    }

    // MARK: - Ethereum Transaction Tests

    func testBuildEthereumTransfer_Success() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.1")!

        mockEthereumProvider.mockRawTransaction = Data([0x01, 0x02, 0x03])

        // When
        let txData = try await ethereumBuilder.buildTransferTransaction(
            from: from,
            to: to,
            amount: amount
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
        XCTAssertTrue(mockEthereumProvider.buildTransactionWasCalled)
    }

    func testBuildERC20Transfer_ValidTokenAddress() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let tokenAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7" // USDT
        let amount = Decimal(string: "100")!
        let decimals = 6

        mockEthereumProvider.mockRawTransaction = Data([0x04, 0x05, 0x06])

        // When
        let txData = try await ethereumBuilder.buildTokenTransferTransaction(
            from: from,
            to: to,
            tokenAddress: tokenAddress,
            amount: amount,
            decimals: decimals
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    func testBuildEthereumWithCustomGas_Success() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.05")!
        let gasLimit: UInt64 = 21000
        let maxFeePerGas = Decimal(string: "50")!
        let priorityFee = Decimal(string: "2")!

        mockEthereumProvider.mockRawTransaction = Data([0x07, 0x08])

        // When
        let txData = try await ethereumBuilder.buildTransactionWithCustomGas(
            from: from,
            to: to,
            amount: amount,
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            maxPriorityFeePerGas: priorityFee
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    func testEstimateGas_Success() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.1")!

        mockEthereumProvider.mockGasEstimation = GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2),
            estimatedCost: Decimal(0.00105)
        )

        // When
        let estimation = try await ethereumBuilder.estimateTransactionCost(
            from: from,
            to: to,
            amount: amount
        )

        // Then
        XCTAssertEqual(estimation.gasLimit, 21000)
        XCTAssertGreaterThan(estimation.estimatedCost, 0)
    }

    func testBuildContractInteraction_Success() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let contractAddress = "0x1234567890123456789012345678901234567890"
        let functionSignature = "0xa9059cbb" // transfer(address,uint256)
        let parameters: [Any] = [
            "0xRecipientAddress",
            UInt64(1000000)
        ]

        mockEthereumProvider.mockRawTransaction = Data([0x09, 0x0A])

        // When
        let txData = try await ethereumBuilder.buildContractTransaction(
            from: from,
            contractAddress: contractAddress,
            functionSignature: functionSignature,
            parameters: parameters,
            value: 0
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    // MARK: - Bitcoin Transaction Tests

    func testBuildBitcoinTransfer_Success() async throws {
        // Given
        let from = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
        let to = "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3"
        let amount = Decimal(string: "0.001")! // BTC

        mockBitcoinProvider.mockRawTransaction = Data([0x0B, 0x0C])

        // When
        let txData = try await bitcoinBuilder.buildTransferTransaction(
            from: from,
            to: to,
            amount: amount
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    func testBuildBitcoinTokenTransfer_ThrowsUnsupported() async {
        // Given
        let from = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4"
        let to = "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3"

        // When/Then
        do {
            _ = try await bitcoinBuilder.buildTokenTransferTransaction(
                from: from,
                to: to,
                tokenAddress: "invalid",
                amount: Decimal(100),
                decimals: 18
            )
            XCTFail("Should throw unsupported operation error")
        } catch let error as BlockchainError {
            XCTAssertEqual(error, .unsupportedOperation)
        }
    }

    // MARK: - Solana Transaction Tests

    func testBuildSolanaTransfer_Success() async throws {
        // Given
        let from = "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK"
        let to = "FWXJnF8y6r4TfCpKqQ5YC1PBv3wz3bJfJSqRuqPvmNmV"
        let amount = Decimal(string: "1.5")! // SOL

        mockSolanaProvider.mockRawTransaction = Data([0x0D, 0x0E])

        // When
        let txData = try await solanaBuilder.buildTransferTransaction(
            from: from,
            to: to,
            amount: amount
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    func testBuildSPLTokenTransfer_Success() async throws {
        // Given
        let from = "7EqQdEULxWcraVx3mXKFjc84LhCkMGZCkRuDpvcMwJeK"
        let to = "FWXJnF8y6r4TfCpKqQ5YC1PBv3wz3bJfJSqRuqPvmNmV"
        let tokenMint = "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v" // USDC
        let amount = Decimal(string: "100")!
        let decimals = 6

        mockSolanaProvider.mockRawTransaction = Data([0x0F, 0x10])

        // When
        let txData = try await solanaBuilder.buildTokenTransferTransaction(
            from: from,
            to: to,
            tokenAddress: tokenMint,
            amount: amount,
            decimals: decimals
        )

        // Then
        XCTAssertGreaterThan(txData.count, 0)
    }

    // MARK: - Transaction Validation Tests

    func testValidateTransaction_ValidInputs() throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.5")!
        let balance = Decimal(string: "1.0")!

        // When/Then
        XCTAssertNoThrow(try validator.validateTransaction(
            from: from,
            to: to,
            amount: amount,
            balance: balance
        ))
    }

    func testValidateTransaction_InvalidFromAddress() {
        // Given
        let from = "invalid_address"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.5")!
        let balance = Decimal(string: "1.0")!

        // When/Then
        XCTAssertThrowsError(try validator.validateTransaction(
            from: from,
            to: to,
            amount: amount,
            balance: balance
        )) { error in
            XCTAssertEqual(error as? BlockchainError, .invalidAddress)
        }
    }

    func testValidateTransaction_InvalidToAddress() {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "invalid_address"
        let amount = Decimal(string: "0.5")!
        let balance = Decimal(string: "1.0")!

        // When/Then
        XCTAssertThrowsError(try validator.validateTransaction(
            from: from,
            to: to,
            amount: amount,
            balance: balance
        )) { error in
            XCTAssertEqual(error as? BlockchainError, .invalidAddress)
        }
    }

    func testValidateTransaction_InsufficientBalance() {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "2.0")!
        let balance = Decimal(string: "1.0")!

        // When/Then
        XCTAssertThrowsError(try validator.validateTransaction(
            from: from,
            to: to,
            amount: amount,
            balance: balance
        )) { error in
            XCTAssertEqual(error as? BlockchainError, .insufficientBalance)
        }
    }

    func testValidateTransaction_NegativeAmount() {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "-0.5")!
        let balance = Decimal(string: "1.0")!

        // When/Then
        XCTAssertThrowsError(try validator.validateTransaction(
            from: from,
            to: to,
            amount: amount,
            balance: balance
        )) { error in
            XCTAssertEqual(error as? BlockchainError, .invalidTransaction)
        }
    }

    func testValidateTransaction_ZeroAmount() {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(0)
        let balance = Decimal(string: "1.0")!

        // When/Then
        XCTAssertThrowsError(try validator.validateTransaction(
            from: from,
            to: to,
            amount: amount,
            balance: balance
        )) { error in
            XCTAssertEqual(error as? BlockchainError, .invalidTransaction)
        }
    }

    // MARK: - Gas Parameter Validation Tests

    func testValidateGasParameters_SufficientBalance() async throws {
        // Given
        let gasLimit: UInt64 = 21000
        let maxFeePerGas = Decimal(50) // gwei
        let balance = Decimal(string: "0.1")! // ETH

        // When/Then
        await XCTAssertNoThrowAsync(try await validator.validateGasParameters(
            gasLimit: gasLimit,
            maxFeePerGas: maxFeePerGas,
            balance: balance
        ))
    }

    func testValidateGasParameters_InsufficientBalance() async {
        // Given
        let gasLimit: UInt64 = 21000
        let maxFeePerGas = Decimal(1000000) // Very high gas price
        let balance = Decimal(string: "0.001")! // Small balance

        // When/Then
        do {
            try await validator.validateGasParameters(
                gasLimit: gasLimit,
                maxFeePerGas: maxFeePerGas,
                balance: balance
            )
            XCTFail("Should throw insufficient balance error")
        } catch let error as BlockchainError {
            XCTAssertEqual(error, .insufficientBalance)
        }
    }

    // MARK: - Edge Cases

    func testBuildTransaction_MaxUint256Amount() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let maxAmount = Decimal(sign: .plus, exponent: 18, significand: Decimal(UInt64.max))

        mockEthereumProvider.mockRawTransaction = Data([0x11, 0x12])

        // When/Then
        XCTAssertNoThrow(try await ethereumBuilder.buildTransferTransaction(
            from: from,
            to: to,
            amount: maxAmount
        ))
    }

    func testBuildTransaction_VerySmallAmount() async throws {
        // Given
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x1234567890123456789012345678901234567890"
        let tinyAmount = Decimal(sign: .plus, exponent: -18, significand: 1) // 1 wei

        mockEthereumProvider.mockRawTransaction = Data([0x13, 0x14])

        // When/Then
        XCTAssertNoThrow(try await ethereumBuilder.buildTransferTransaction(
            from: from,
            to: to,
            amount: tinyAmount
        ))
    }

    // MARK: - Concurrent Transaction Building

    func testConcurrentTransactionBuilding_ThreadSafe() async throws {
        // Given
        let iterations = 20
        mockEthereumProvider.mockRawTransaction = Data([0x15, 0x16])

        // When
        try await withThrowingTaskGroup(of: Data.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    try await self.ethereumBuilder.buildTransferTransaction(
                        from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                        to: "0x1234567890123456789012345678901234567890",
                        amount: Decimal(i)
                    )
                }
            }

            var results: [Data] = []
            for try await result in group {
                results.append(result)
            }

            // Then
            XCTAssertEqual(results.count, iterations)
        }
    }
}

// MARK: - Helper Extension

extension XCTest {
    func XCTAssertNoThrowAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}
