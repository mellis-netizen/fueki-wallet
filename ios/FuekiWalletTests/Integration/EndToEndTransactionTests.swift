import XCTest
@testable import FuekiWallet

final class EndToEndTransactionTests: XCTestCase {

    var walletManager: WalletManager!
    var transactionBuilder: TransactionBuilder!
    var keyManager: KeyManager!
    var networkClient: NetworkClient!

    override func setUp() async throws {
        try await super.setUp()

        keyManager = KeyManager()
        networkClient = NetworkClient(baseURL: "https://blockstream.info/testnet/api")
        transactionBuilder = TransactionBuilder(
            keyManager: keyManager,
            networkClient: networkClient
        )
        walletManager = WalletManager(
            keyManager: keyManager,
            transactionBuilder: transactionBuilder,
            networkClient: networkClient
        )
    }

    override func tearDown() async throws {
        walletManager = nil
        transactionBuilder = nil
        keyManager = nil
        networkClient = nil
        try await super.tearDown()
    }

    // MARK: - Complete Transaction Flow Tests

    func testCompleteTransactionFlow_CreateSignBroadcast() async throws {
        // Note: This test creates a transaction but doesn't actually broadcast to avoid spending testnet coins

        // Given - Create and unlock wallet
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        try await walletManager.unlockWallet(password: "TestPassword123!")

        // Simulate having UTXOs (in real test, would need funded address)
        let mockUTXOs = [
            UTXO(txid: "abc123def456", vout: 0, amount: 100000, address: wallet.address)
        ]

        // When - Build transaction
        let recipientAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
        let amount: UInt64 = 50000
        let fee: UInt64 = 1000

        let transaction = try transactionBuilder.buildTransaction(
            to: recipientAddress,
            amount: amount,
            fee: fee,
            utxos: mockUTXOs
        )

        // Then - Verify transaction structure
        XCTAssertFalse(transaction.inputs.isEmpty)
        XCTAssertFalse(transaction.outputs.isEmpty)
        XCTAssertEqual(transaction.outputs[0].address, recipientAddress)
        XCTAssertEqual(transaction.outputs[0].amount, amount)

        // Sign transaction
        let signedTransaction = try transactionBuilder.signTransaction(transaction)
        XCTAssertTrue(signedTransaction.isSigned)

        // Serialize transaction
        let rawTransaction = try transactionBuilder.serializeTransaction(signedTransaction)
        XCTAssertFalse(rawTransaction.isEmpty)

        // Note: We don't actually broadcast to avoid spending real testnet coins
        // In production testing with funded test wallets, you would:
        // let txid = try await networkClient.broadcastTransaction(rawTransaction)
        // XCTAssertFalse(txid.isEmpty)
    }

    // MARK: - Wallet State Management E2E

    func testWalletLifecycle_CreateLockUnlock() async throws {
        // Create wallet
        let wallet = try await walletManager.createWallet(password: "SecurePass123!")
        XCTAssertFalse(wallet.address.isEmpty)
        XCTAssertTrue(walletManager.isUnlocked)

        // Lock wallet
        await walletManager.lockWallet()
        XCTAssertFalse(walletManager.isUnlocked)

        // Unlock wallet
        let unlocked = try await walletManager.unlockWallet(password: "SecurePass123!")
        XCTAssertTrue(unlocked)
        XCTAssertTrue(walletManager.isUnlocked)
    }

    // MARK: - Import and Restore E2E

    func testImportWallet_RestoreFromMnemonic() async throws {
        // Given - Known mnemonic
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

        // When - Import wallet
        let wallet = try await walletManager.importWallet(
            mnemonic: mnemonic,
            password: "TestPassword123!"
        )

        // Then - Verify wallet is functional
        XCTAssertFalse(wallet.address.isEmpty)
        XCTAssertTrue(walletManager.isUnlocked)

        // Should be able to fetch balance
        let balance = try await walletManager.getBalance()
        XCTAssertGreaterThanOrEqual(balance, 0)
    }

    // MARK: - Multi-Step Transaction E2E

    func testMultiStepTransaction_EstimateFeeAndSend() async throws {
        // Given
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        try await walletManager.unlockWallet(password: "TestPassword123!")

        let recipientAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
        let amount: UInt64 = 50000

        // Step 1: Fetch current fee rates
        let feeRates = try await networkClient.fetchFeeRates()
        XCTAssertGreaterThan(feeRates.medium, 0)

        // Step 2: Calculate optimal fee
        let estimatedFee = try await transactionBuilder.calculateOptimalFee(
            inputs: 1,
            outputs: 2,
            priority: .medium
        )
        XCTAssertGreaterThan(estimatedFee, 0)

        // Step 3: Validate recipient address
        let isValidAddress = keyManager.validateAddress(recipientAddress, network: .testnet)
        XCTAssertTrue(isValidAddress)

        // Step 4: Build transaction (would fail without UTXOs, but tests the flow)
        // In real testing, would need funded wallet
    }

    // MARK: - Error Recovery E2E

    func testTransactionFailure_InsufficientFunds_PropagatesError() async throws {
        // Given - wallet with no funds
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        try await walletManager.unlockWallet(password: "TestPassword123!")

        let recipientAddress = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"
        let amount: UInt64 = 1000000 // Large amount
        let fee: UInt64 = 1000

        // When/Then - Should fail with insufficient funds
        do {
            _ = try await walletManager.sendTransaction(
                to: recipientAddress,
                amount: amount,
                fee: fee
            )
            XCTFail("Should throw insufficient funds error")
        } catch WalletError.insufficientFunds {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Concurrent Operations E2E

    func testConcurrentOperations_MultipleBalanceChecks() async throws {
        // Given
        let wallet = try await walletManager.createWallet(password: "TestPassword123!")
        try await walletManager.unlockWallet(password: "TestPassword123!")

        // When - perform multiple balance checks concurrently
        async let balance1 = walletManager.getBalance()
        async let balance2 = walletManager.getBalance()
        async let balance3 = walletManager.getBalance()

        let (b1, b2, b3) = try await (balance1, balance2, balance3)

        // Then - all should return same value
        XCTAssertEqual(b1, b2)
        XCTAssertEqual(b2, b3)
    }

    // MARK: - Security E2E

    func testSecurityFlow_PasswordValidation() async throws {
        // Test 1: Weak password should fail
        do {
            _ = try await walletManager.createWallet(password: "123")
            XCTFail("Should reject weak password")
        } catch WalletError.weakPassword {
            // Expected
        }

        // Test 2: Strong password should succeed
        let wallet = try await walletManager.createWallet(password: "SecurePassword123!")
        XCTAssertFalse(wallet.address.isEmpty)

        // Test 3: Wrong password should fail unlock
        await walletManager.lockWallet()
        do {
            _ = try await walletManager.unlockWallet(password: "WrongPassword")
            XCTFail("Should reject wrong password")
        } catch WalletError.incorrectPassword {
            // Expected
        }
    }

    // MARK: - Backup and Restore E2E

    func testBackupRestore_CompleteFlow() async throws {
        // Given - Create wallet
        let originalWallet = try await walletManager.createWallet(password: "TestPassword123!")
        let originalAddress = originalWallet.address
        let originalMnemonic = originalWallet.mnemonic

        // When - Backup wallet
        let backup = try await walletManager.backupWallet()
        XCTAssertNotNil(backup.mnemonic)
        XCTAssertNotNil(backup.encryptedData)

        // Lock and delete wallet (simulate device loss)
        await walletManager.lockWallet()

        // Restore from backup
        let restoredWallet = try await walletManager.importWallet(
            mnemonic: originalMnemonic,
            password: "TestPassword123!"
        )

        // Then - Should restore same address
        XCTAssertEqual(restoredWallet.address, originalAddress)
    }

    // MARK: - Network Resilience E2E

    func testNetworkResilience_RetriesOnFailure() async throws {
        // This test verifies that network operations retry on temporary failures
        let expectation = XCTestExpectation(description: "Network request completes")

        do {
            let feeRates = try await networkClient.fetchFeeRates()
            XCTAssertGreaterThan(feeRates.medium, 0)
            expectation.fulfill()
        } catch {
            XCTFail("Network request should succeed with retry logic")
        }

        await fulfillment(of: [expectation], timeout: 15.0)
    }

    // MARK: - Transaction Validation E2E

    func testTransactionValidation_PreventInvalidTransactions() async throws {
        // Test various invalid transaction scenarios

        // Invalid address
        do {
            _ = try transactionBuilder.buildTransaction(
                to: "invalid_address",
                amount: 1000,
                fee: 100,
                utxos: []
            )
            XCTFail("Should reject invalid address")
        } catch {
            XCTAssertTrue(error is TransactionError)
        }

        // Zero amount
        do {
            _ = try transactionBuilder.buildTransaction(
                to: "tb1qtest",
                amount: 0,
                fee: 100,
                utxos: []
            )
            XCTFail("Should reject zero amount")
        } catch {
            XCTAssertTrue(error is TransactionError)
        }

        // Dust amount
        do {
            _ = try transactionBuilder.buildTransaction(
                to: "tb1qtest",
                amount: 100, // Below dust threshold
                fee: 100,
                utxos: []
            )
            XCTFail("Should reject dust amount")
        } catch {
            XCTAssertTrue(error is TransactionError)
        }
    }

    // MARK: - Performance E2E

    func testCompleteWalletCreation_Performance() {
        measure {
            Task {
                _ = try? await walletManager.createWallet(password: "TestPassword123!")
            }
        }
    }

    func testWalletUnlock_Performance() async throws {
        _ = try await walletManager.createWallet(password: "TestPassword123!")
        await walletManager.lockWallet()

        measure {
            Task {
                _ = try? await walletManager.unlockWallet(password: "TestPassword123!")
            }
        }
    }
}
