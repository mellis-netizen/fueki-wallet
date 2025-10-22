//
//  TransactionIntegrationTests.swift
//  FuekiWalletTests
//
//  End-to-end integration tests for transaction flows
//

import XCTest
@testable import FuekiWallet

@MainActor
final class TransactionIntegrationTests: XCTestCase {

    var walletManager: WalletManager!
    var transactionManager: TransactionManager!
    var keyManager: KeyManager!
    var mockProvider: MockBlockchainProvider!
    var testWallet: Wallet!
    let testPassword = "SecureTestPassword123!"

    override func setUp() async throws {
        mockProvider = MockBlockchainProvider(chainType: .ethereum)
        keychainManager = KeychainManager()
        encryptionService = EncryptionService()
        keyManager = KeyManager(
            keychainManager: keychainManager,
            encryptionService: encryptionService,
            useSecureEnclave: false
        )
        walletManager = WalletManager(keyManager: keyManager)
        transactionManager = TransactionManager(
            keyManager: keyManager,
            provider: mockProvider
        )

        // Create test wallet
        testWallet = try await walletManager.createWallet(
            name: "Test Wallet",
            password: testPassword
        )

        // Setup mock balance
        mockProvider.mockBalance = 1000000000000000000 // 1 ETH
    }

    override func tearDown() async throws {
        try? await walletManager.deleteWallet(testWallet, password: testPassword)
        testWallet = nil
        transactionManager = nil
        walletManager = nil
        keyManager = nil
        mockProvider = nil
    }

    // MARK: - Complete Send Flow

    func testSendTransaction_CompleteFlow_Success() async throws {
        // Given
        let recipientAddress = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.1")! // 0.1 ETH

        mockProvider.mockTransactionHash = "0xabc123def456"
        mockProvider.mockGasEstimation = GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2),
            estimatedCost: Decimal(0.00105)
        )

        // When - Estimate gas
        let gasEstimate = try await transactionManager.estimateGas(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount
        )

        // Then - Verify gas estimation
        XCTAssertGreaterThan(gasEstimate.gasLimit, 0)
        XCTAssertGreaterThan(gasEstimate.estimatedCost, 0)

        // When - Build transaction
        let unsignedTx = try await transactionManager.buildTransaction(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount,
            gasLimit: gasEstimate.gasLimit,
            maxFeePerGas: gasEstimate.maxFeePerGas,
            maxPriorityFeePerGas: gasEstimate.maxPriorityFeePerGas
        )

        XCTAssertGreaterThan(unsignedTx.count, 0)

        // When - Sign transaction
        let signedTx = try await transactionManager.signTransaction(
            unsignedTx,
            walletId: testWallet.id,
            password: testPassword
        )

        XCTAssertGreaterThan(signedTx.count, 0)

        // When - Broadcast transaction
        let txHash = try await transactionManager.broadcastTransaction(signedTx)

        // Then - Verify transaction broadcast
        XCTAssertEqual(txHash, "0xabc123def456")

        // Verify transaction saved to history
        let history = try await transactionManager.getTransactionHistory(for: testWallet.address)
        XCTAssertGreaterThan(history.count, 0)
    }

    // MARK: - Token Transfer Flow

    func testSendTokenTransfer_CompleteFlow() async throws {
        // Given
        let recipientAddress = "0x1234567890123456789012345678901234567890"
        let tokenAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7" // USDT
        let amount = Decimal(100)
        let decimals = 6

        mockProvider.mockTransactionHash = "0xtoken123"

        // When - Build token transfer
        let unsignedTx = try await transactionManager.buildTokenTransfer(
            from: testWallet.address,
            to: recipientAddress,
            tokenAddress: tokenAddress,
            amount: amount,
            decimals: decimals
        )

        // Then - Verify transaction built
        XCTAssertGreaterThan(unsignedTx.count, 0)

        // When - Sign and broadcast
        let signedTx = try await transactionManager.signTransaction(
            unsignedTx,
            walletId: testWallet.id,
            password: testPassword
        )

        let txHash = try await transactionManager.broadcastTransaction(signedTx)

        // Then - Verify success
        XCTAssertEqual(txHash, "0xtoken123")
    }

    // MARK: - Transaction Monitoring

    func testTransactionMonitoring_PendingToConfirmed() async throws {
        // Given
        let recipientAddress = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.05")!

        mockProvider.mockTransactionHash = "0xpending123"

        // When - Send transaction
        let unsignedTx = try await transactionManager.buildTransaction(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount,
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2)
        )

        let signedTx = try await transactionManager.signTransaction(
            unsignedTx,
            walletId: testWallet.id,
            password: testPassword
        )

        let txHash = try await transactionManager.broadcastTransaction(signedTx)

        // Then - Initial status should be pending
        var status = try await transactionManager.getTransactionStatus(txHash)
        XCTAssertEqual(status, .pending)

        // Simulate confirmation
        mockProvider.mockTransactionStatus = .confirmed
        mockProvider.mockConfirmations = 6

        // When - Check status again
        status = try await transactionManager.getTransactionStatus(txHash)

        // Then - Status should be confirmed
        XCTAssertEqual(status, .confirmed)
    }

    // MARK: - Failed Transaction Handling

    func testTransactionFailure_InsufficientGas() async throws {
        // Given
        let recipientAddress = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.1")!

        mockProvider.shouldFailBroadcast = true
        mockProvider.mockError = BlockchainError.insufficientGas

        // When - Attempt to send
        let unsignedTx = try await transactionManager.buildTransaction(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount,
            gasLimit: 100, // Insufficient
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2)
        )

        let signedTx = try await transactionManager.signTransaction(
            unsignedTx,
            walletId: testWallet.id,
            password: testPassword
        )

        // Then - Should fail with appropriate error
        do {
            _ = try await transactionManager.broadcastTransaction(signedTx)
            XCTFail("Should have thrown error")
        } catch let error as BlockchainError {
            XCTAssertEqual(error, .insufficientGas)
        }
    }

    // MARK: - Nonce Management

    func testMultipleTransactions_NonceIncrement() async throws {
        // Given
        let recipient1 = "0x1111111111111111111111111111111111111111"
        let recipient2 = "0x2222222222222222222222222222222222222222"
        let amount = Decimal(string: "0.01")!

        mockProvider.mockNonce = 5

        // When - Build first transaction
        let tx1 = try await transactionManager.buildTransaction(
            from: testWallet.address,
            to: recipient1,
            amount: amount,
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2)
        )

        // Then - Verify nonce requested
        XCTAssertTrue(mockProvider.getNonceWasCalled)

        // When - Build second transaction (should increment nonce)
        mockProvider.mockNonce = 6

        let tx2 = try await transactionManager.buildTransaction(
            from: testWallet.address,
            to: recipient2,
            amount: amount,
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2)
        )

        // Then - Nonce should have incremented
        XCTAssertNotEqual(tx1, tx2)
    }

    // MARK: - Gas Price Strategy

    func testGasPrice_DynamicAdjustment() async throws {
        // Given
        let recipientAddress = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.1")!

        // When - Estimate with low priority
        mockProvider.mockGasEstimation = GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(30),
            maxPriorityFeePerGas: Decimal(1),
            estimatedCost: Decimal(0.00063)
        )

        let lowPriorityEstimate = try await transactionManager.estimateGas(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount,
            priority: .low
        )

        // When - Estimate with high priority
        mockProvider.mockGasEstimation = GasEstimation(
            gasLimit: 21000,
            maxFeePerGas: Decimal(100),
            maxPriorityFeePerGas: Decimal(5),
            estimatedCost: Decimal(0.0021)
        )

        let highPriorityEstimate = try await transactionManager.estimateGas(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount,
            priority: .high
        )

        // Then - High priority should cost more
        XCTAssertGreaterThan(
            highPriorityEstimate.estimatedCost,
            lowPriorityEstimate.estimatedCost
        )
    }

    // MARK: - Transaction History

    func testTransactionHistory_Pagination() async throws {
        // Given - Create multiple transactions
        mockProvider.mockTransactions = Array(0..<50).map { i in
            Transaction(
                id: "tx\(i)",
                hash: "0x\(i)",
                from: testWallet.address,
                to: "0x1234567890123456789012345678901234567890",
                amount: Decimal(i),
                timestamp: Date().addingTimeInterval(Double(-i * 3600)),
                status: .confirmed,
                type: .sent
            )
        }

        // When - Load first page
        let page1 = try await transactionManager.getTransactionHistory(
            for: testWallet.address,
            limit: 20,
            offset: 0
        )

        // Then - Verify first page
        XCTAssertEqual(page1.count, 20)

        // When - Load second page
        let page2 = try await transactionManager.getTransactionHistory(
            for: testWallet.address,
            limit: 20,
            offset: 20
        )

        // Then - Verify second page different
        XCTAssertEqual(page2.count, 20)
        XCTAssertNotEqual(page1.first?.id, page2.first?.id)
    }

    // MARK: - Error Recovery

    func testTransactionFailure_RetryLogic() async throws {
        // Given
        let recipientAddress = "0x1234567890123456789012345678901234567890"
        let amount = Decimal(string: "0.01")!

        // Simulate network failure
        mockProvider.shouldFailBroadcast = true
        mockProvider.mockError = NetworkError.timeout

        // When - First attempt fails
        let unsignedTx = try await transactionManager.buildTransaction(
            from: testWallet.address,
            to: recipientAddress,
            amount: amount,
            gasLimit: 21000,
            maxFeePerGas: Decimal(50),
            maxPriorityFeePerGas: Decimal(2)
        )

        let signedTx = try await transactionManager.signTransaction(
            unsignedTx,
            walletId: testWallet.id,
            password: testPassword
        )

        do {
            _ = try await transactionManager.broadcastTransaction(signedTx)
            XCTFail("Should have failed")
        } catch {
            // Expected failure
        }

        // When - Retry with network restored
        mockProvider.shouldFailBroadcast = false
        mockProvider.mockTransactionHash = "0xretry123"

        let txHash = try await transactionManager.broadcastTransaction(signedTx)

        // Then - Should succeed
        XCTAssertEqual(txHash, "0xretry123")
    }
}
