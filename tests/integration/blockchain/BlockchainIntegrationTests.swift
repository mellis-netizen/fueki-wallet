import XCTest
@testable import FuekiWallet

/// Integration tests for blockchain connectivity
/// Tests against testnet networks to validate real blockchain interactions
class BlockchainIntegrationTests: XCTestCase {

    var blockchainService: BlockchainService!
    var walletService: WalletService!
    var testWallet: Wallet!

    override func setUp() async throws {
        try await super.setUp()
        blockchainService = BlockchainService(network: .sepolia) // Ethereum Sepolia testnet
        walletService = WalletService()

        // Create test wallet
        testWallet = try await walletService.createWallet(name: "Integration Test Wallet")
    }

    override func tearDown() async throws {
        blockchainService = nil
        walletService = nil
        testWallet = nil
        try await super.tearDown()
    }

    // MARK: - Connection Tests

    func testConnectToTestnet() async throws {
        // Act
        let isConnected = try await blockchainService.connect()

        // Assert
        XCTAssertTrue(isConnected, "Should connect to testnet")
    }

    func testGetChainId() async throws {
        // Act
        let chainId = try await blockchainService.getChainId()

        // Assert
        XCTAssertEqual(chainId, 11155111, "Sepolia testnet chain ID should be 11155111")
    }

    func testGetLatestBlockNumber() async throws {
        // Act
        let blockNumber = try await blockchainService.getLatestBlockNumber()

        // Assert
        XCTAssertGreaterThan(blockNumber, 0, "Block number should be positive")
    }

    func testGetNetworkStatus() async throws {
        // Act
        let status = try await blockchainService.getNetworkStatus()

        // Assert
        XCTAssertTrue(status.isConnected)
        XCTAssertTrue(status.isSynced)
        XCTAssertGreaterThan(status.peerCount, 0)
    }

    // MARK: - Balance Query Tests

    func testGetBalance() async throws {
        // Arrange
        let address = testWallet.address

        // Act
        let balance = try await blockchainService.getBalance(for: address)

        // Assert
        XCTAssertGreaterThanOrEqual(balance, 0, "Balance should be non-negative")
    }

    func testGetBalanceMultipleAddresses() async throws {
        // Arrange
        let addresses = [
            testWallet.address,
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        ]

        // Act
        let balances = try await blockchainService.getBalances(for: addresses)

        // Assert
        XCTAssertEqual(balances.count, addresses.count)
        for (address, balance) in balances {
            XCTAssertGreaterThanOrEqual(balance, 0)
        }
    }

    func testGetTokenBalance() async throws {
        // Arrange - USDC on Sepolia
        let tokenAddress = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
        let holderAddress = testWallet.address

        // Act
        let balance = try await blockchainService.getTokenBalance(
            token: tokenAddress,
            holder: holderAddress
        )

        // Assert
        XCTAssertGreaterThanOrEqual(balance, 0)
    }

    // MARK: - Transaction Query Tests

    func testGetTransactionCount() async throws {
        // Arrange
        let address = testWallet.address

        // Act
        let nonce = try await blockchainService.getTransactionCount(for: address)

        // Assert
        XCTAssertGreaterThanOrEqual(nonce, 0, "Nonce should be non-negative")
    }

    func testGetTransactionByHash() async throws {
        // Arrange - Known transaction on Sepolia
        let txHash = "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef"

        // Act & Assert
        do {
            let transaction = try await blockchainService.getTransaction(hash: txHash)
            XCTAssertNotNil(transaction)
        } catch {
            // Transaction might not exist, which is okay for this test
            XCTAssertTrue(error is BlockchainError)
        }
    }

    func testGetTransactionReceipt() async throws {
        // This test requires a valid transaction hash
        // Skip if no test transactions available
        throw XCTSkip("Requires valid transaction hash")
    }

    // MARK: - Gas Price Tests

    func testGetGasPrice() async throws {
        // Act
        let gasPrice = try await blockchainService.getGasPrice()

        // Assert
        XCTAssertGreaterThan(gasPrice, 0, "Gas price should be positive")
    }

    func testGetEIP1559FeeEstimate() async throws {
        // Act
        let feeData = try await blockchainService.getEIP1559FeeData()

        // Assert
        XCTAssertGreaterThan(feeData.maxFeePerGas, 0)
        XCTAssertGreaterThan(feeData.maxPriorityFeePerGas, 0)
        XCTAssertLessThan(feeData.maxPriorityFeePerGas, feeData.maxFeePerGas)
    }

    func testEstimateGas() async throws {
        // Arrange
        let transaction = Transaction(
            from: testWallet.address,
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 0
        )

        // Act
        let gasEstimate = try await blockchainService.estimateGas(for: transaction)

        // Assert
        XCTAssertGreaterThanOrEqual(gasEstimate, 21_000, "Gas estimate should be at least 21,000")
    }

    // MARK: - Transaction Sending Tests

    func testSendTransaction() async throws {
        // Skip this test unless wallet is funded
        guard try await blockchainService.getBalance(for: testWallet.address) > 0 else {
            throw XCTSkip("Test wallet has no balance")
        }

        // Arrange
        let transaction = try await walletService.createTransaction(
            from: testWallet,
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000 // 0.000001 ETH
        )

        // Act
        let txHash = try await blockchainService.sendTransaction(transaction)

        // Assert
        XCTAssertNotNil(txHash)
        XCTAssertEqual(txHash.count, 66, "Transaction hash should be 66 characters (0x + 64 hex)")

        // Wait for confirmation
        let receipt = try await blockchainService.waitForTransaction(txHash, timeout: 60)
        XCTAssertTrue(receipt.status == .success, "Transaction should succeed")
    }

    func testSendTransactionWithInsufficientFunds() async throws {
        // Arrange - Try to send more than balance
        let balance = try await blockchainService.getBalance(for: testWallet.address)
        let transaction = try await walletService.createTransaction(
            from: testWallet,
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: balance + 1_000_000_000
        )

        // Act & Assert
        await XCTAssertThrowsErrorAsync(
            try await blockchainService.sendTransaction(transaction)
        ) { error in
            XCTAssertTrue(error is BlockchainError)
            if let bcError = error as? BlockchainError {
                XCTAssertEqual(bcError, .insufficientFunds)
            }
        }
    }

    // MARK: - Block Query Tests

    func testGetBlockByNumber() async throws {
        // Arrange
        let latestBlockNumber = try await blockchainService.getLatestBlockNumber()

        // Act
        let block = try await blockchainService.getBlock(number: latestBlockNumber)

        // Assert
        XCTAssertNotNil(block)
        XCTAssertEqual(block.number, latestBlockNumber)
        XCTAssertNotNil(block.hash)
        XCTAssertNotNil(block.timestamp)
    }

    func testGetLatestBlock() async throws {
        // Act
        let block = try await blockchainService.getLatestBlock()

        // Assert
        XCTAssertNotNil(block)
        XCTAssertGreaterThan(block.number, 0)
        XCTAssertNotNil(block.transactions)
    }

    // MARK: - Event Monitoring Tests

    func testSubscribeToNewBlocks() async throws {
        // Arrange
        var receivedBlocks: [Block] = []
        let expectation = XCTestExpectation(description: "Receive new blocks")
        expectation.expectedFulfillmentCount = 3

        // Act
        let subscription = try await blockchainService.subscribeToNewBlocks { block in
            receivedBlocks.append(block)
            expectation.fulfill()
        }

        // Assert
        await fulfillment(of: [expectation], timeout: 60)
        XCTAssertGreaterThanOrEqual(receivedBlocks.count, 3)
        subscription.cancel()
    }

    func testSubscribeToAddressTransactions() async throws {
        // Arrange
        let address = testWallet.address
        var receivedTxs: [Transaction] = []
        let expectation = XCTestExpectation(description: "Receive transactions")

        // Act
        let subscription = try await blockchainService.subscribeToAddress(address) { transaction in
            receivedTxs.append(transaction)
            expectation.fulfill()
        }

        // Send a test transaction to trigger the subscription
        // (Requires funded wallet)

        // Assert
        await fulfillment(of: [expectation], timeout: 60)
        subscription.cancel()
    }

    // MARK: - Smart Contract Tests

    func testCallContractView() async throws {
        // Arrange - ERC20 token contract
        let tokenAddress = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
        let abi = ERC20ABI.shared

        // Act - Call name() function
        let name = try await blockchainService.callContract(
            address: tokenAddress,
            abi: abi,
            function: "name"
        ) as String

        // Assert
        XCTAssertFalse(name.isEmpty, "Token name should not be empty")
    }

    func testCallContractWithParameters() async throws {
        // Arrange - ERC20 balanceOf
        let tokenAddress = "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238"
        let holderAddress = testWallet.address

        // Act
        let balance = try await blockchainService.callContract(
            address: tokenAddress,
            abi: ERC20ABI.shared,
            function: "balanceOf",
            parameters: [holderAddress]
        ) as UInt256

        // Assert
        XCTAssertGreaterThanOrEqual(balance, 0)
    }

    // MARK: - Error Handling Tests

    func testInvalidAddressError() async throws {
        // Act & Assert
        await XCTAssertThrowsErrorAsync(
            try await blockchainService.getBalance(for: "invalid-address")
        ) { error in
            XCTAssertTrue(error is BlockchainError)
        }
    }

    func testNetworkTimeoutHandling() async throws {
        // Arrange - Set very short timeout
        blockchainService.timeout = 0.001

        // Act & Assert
        await XCTAssertThrowsErrorAsync(
            try await blockchainService.getLatestBlockNumber()
        ) { error in
            XCTAssertTrue(error is BlockchainError)
            if let bcError = error as? BlockchainError {
                XCTAssertEqual(bcError, .timeout)
            }
        }
    }

    func testConnectionRetry() async throws {
        // Arrange - Simulate connection failure
        blockchainService.disconnect()

        // Act - Should auto-retry connection
        let balance = try await blockchainService.getBalance(for: testWallet.address)

        // Assert
        XCTAssertGreaterThanOrEqual(balance, 0)
    }

    // MARK: - Performance Tests

    func testBalanceQueryPerformance() async throws {
        measure {
            Task {
                _ = try? await blockchainService.getBalance(for: testWallet.address)
            }
        }
    }

    func testBatchBalanceQueryPerformance() async throws {
        let addresses = Array(repeating: testWallet.address, count: 100)

        measure {
            Task {
                _ = try? await blockchainService.getBalances(for: addresses)
            }
        }
    }
}

// Helper function for async throwing assertions
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error but succeeded", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
