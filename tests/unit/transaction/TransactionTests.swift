import XCTest
@testable import FuekiWallet

/// Unit tests for transaction creation, serialization, and validation
class TransactionTests: XCTestCase {

    var transactionService: TransactionService!
    var cryptoService: CryptoService!

    override func setUp() {
        super.setUp()
        transactionService = TransactionService()
        cryptoService = CryptoService()
    }

    override func tearDown() {
        transactionService = nil
        cryptoService = nil
        super.tearDown()
    }

    // MARK: - Transaction Creation Tests

    func testCreateBasicTransaction() throws {
        // Arrange
        let from = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        let to = "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed"
        let amount: UInt64 = 1_000_000_000 // 1 Gwei

        // Act
        let transaction = try transactionService.createTransaction(
            from: from,
            to: to,
            amount: amount,
            nonce: 0
        )

        // Assert
        XCTAssertEqual(transaction.from, from)
        XCTAssertEqual(transaction.to, to)
        XCTAssertEqual(transaction.amount, amount)
        XCTAssertEqual(transaction.nonce, 0)
        XCTAssertNotNil(transaction.timestamp)
    }

    func testCreateTransactionWithGasParameters() throws {
        // Arrange & Act
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5,
            gasPrice: 20_000_000_000, // 20 Gwei
            gasLimit: 21_000
        )

        // Assert
        XCTAssertEqual(transaction.gasPrice, 20_000_000_000)
        XCTAssertEqual(transaction.gasLimit, 21_000)
    }

    func testCreateTransactionWithData() throws {
        // Arrange
        let contractData = "0xa9059cbb000000000000000000000000".data(using: .utf8)!

        // Act
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 0,
            nonce: 1,
            data: contractData
        )

        // Assert
        XCTAssertEqual(transaction.data, contractData)
    }

    func testCreateEIP1559Transaction() throws {
        // Arrange & Act - EIP-1559 with maxFeePerGas and maxPriorityFeePerGas
        let transaction = try transactionService.createEIP1559Transaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 10,
            maxFeePerGas: 30_000_000_000,
            maxPriorityFeePerGas: 2_000_000_000,
            gasLimit: 21_000
        )

        // Assert
        XCTAssertEqual(transaction.type, .eip1559)
        XCTAssertEqual(transaction.maxFeePerGas, 30_000_000_000)
        XCTAssertEqual(transaction.maxPriorityFeePerGas, 2_000_000_000)
    }

    // MARK: - Transaction Serialization Tests

    func testSerializeLegacyTransaction() throws {
        // Arrange
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5,
            gasPrice: 20_000_000_000,
            gasLimit: 21_000
        )

        // Act
        let serialized = try transactionService.serialize(transaction)

        // Assert
        XCTAssertNotNil(serialized)
        XCTAssertGreaterThan(serialized.count, 0)

        // RLP encoding should start with expected format
        // Legacy transactions: [nonce, gasPrice, gasLimit, to, value, data, v, r, s]
    }

    func testSerializeEIP1559Transaction() throws {
        // Arrange
        let transaction = try transactionService.createEIP1559Transaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 10,
            maxFeePerGas: 30_000_000_000,
            maxPriorityFeePerGas: 2_000_000_000,
            gasLimit: 21_000
        )

        // Act
        let serialized = try transactionService.serialize(transaction)

        // Assert
        XCTAssertNotNil(serialized)
        // EIP-1559 transactions start with 0x02
        XCTAssertEqual(serialized[0], 0x02)
    }

    func testDeserializeTransaction() throws {
        // Arrange
        let original = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )
        let serialized = try transactionService.serialize(original)

        // Act
        let deserialized = try transactionService.deserialize(serialized)

        // Assert
        XCTAssertEqual(deserialized.from, original.from)
        XCTAssertEqual(deserialized.to, original.to)
        XCTAssertEqual(deserialized.amount, original.amount)
        XCTAssertEqual(deserialized.nonce, original.nonce)
    }

    // MARK: - Transaction Signing Tests

    func testSignTransaction() throws {
        // Arrange
        let keyPair = try cryptoService.generateSecp256k1KeyPair()
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        // Act
        let signedTx = try transactionService.sign(transaction, with: keyPair.privateKey)

        // Assert
        XCTAssertNotNil(signedTx.signature)
        XCTAssertNotNil(signedTx.r)
        XCTAssertNotNil(signedTx.s)
        XCTAssertNotNil(signedTx.v)
    }

    func testSignTransactionWithChainId() throws {
        // Arrange - EIP-155 replay protection
        let keyPair = try cryptoService.generateSecp256k1KeyPair()
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5,
            chainId: 1 // Ethereum mainnet
        )

        // Act
        let signedTx = try transactionService.sign(transaction, with: keyPair.privateKey)

        // Assert
        XCTAssertEqual(signedTx.chainId, 1)
        // v value should include chain ID: v = chainId * 2 + 35 + {0, 1}
        XCTAssertGreaterThanOrEqual(signedTx.v!, 37) // 1 * 2 + 35 = 37
    }

    func testVerifySignedTransaction() throws {
        // Arrange
        let keyPair = try cryptoService.generateSecp256k1KeyPair()
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        // Act
        let signedTx = try transactionService.sign(transaction, with: keyPair.privateKey)
        let isValid = try transactionService.verifySignature(signedTx, publicKey: keyPair.publicKey)

        // Assert
        XCTAssertTrue(isValid, "Transaction signature should be valid")
    }

    func testRecoverSignerFromTransaction() throws {
        // Arrange
        let keyPair = try cryptoService.generateSecp256k1KeyPair()
        let address = try cryptoService.deriveAddress(from: keyPair.publicKey)
        let transaction = try transactionService.createTransaction(
            from: address,
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        // Act
        let signedTx = try transactionService.sign(transaction, with: keyPair.privateKey)
        let recoveredAddress = try transactionService.recoverSigner(from: signedTx)

        // Assert
        XCTAssertEqual(recoveredAddress.lowercased(), address.lowercased(), "Recovered address should match signer")
    }

    // MARK: - Transaction Hash Tests

    func testCalculateTransactionHash() throws {
        // Arrange
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        // Act
        let hash = try transactionService.calculateHash(transaction)

        // Assert
        XCTAssertNotNil(hash)
        XCTAssertEqual(hash.count, 32, "Transaction hash should be 32 bytes")
    }

    func testTransactionHashConsistency() throws {
        // Arrange
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        // Act
        let hash1 = try transactionService.calculateHash(transaction)
        let hash2 = try transactionService.calculateHash(transaction)

        // Assert
        XCTAssertEqual(hash1, hash2, "Hash should be deterministic")
    }

    func testDifferentTransactionsDifferentHashes() throws {
        // Arrange
        let tx1 = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        let tx2 = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 6 // Different nonce
        )

        // Act
        let hash1 = try transactionService.calculateHash(tx1)
        let hash2 = try transactionService.calculateHash(tx2)

        // Assert
        XCTAssertNotEqual(hash1, hash2, "Different transactions should have different hashes")
    }

    // MARK: - Transaction Validation Tests

    func testValidateValidTransaction() throws {
        // Arrange
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5,
            gasPrice: 20_000_000_000,
            gasLimit: 21_000
        )

        // Act
        let result = transactionService.validate(transaction)

        // Assert
        XCTAssertTrue(result.isValid, "Valid transaction should pass validation")
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testValidateInvalidAddress() throws {
        // Arrange & Act & Assert
        XCTAssertThrowsError(try transactionService.createTransaction(
            from: "invalid-address",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )) { error in
            XCTAssertTrue(error is TransactionError)
        }
    }

    func testValidateZeroAmount() throws {
        // Arrange - Zero amount is valid for contract calls
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 0,
            nonce: 5
        )

        // Act
        let result = transactionService.validate(transaction)

        // Assert
        XCTAssertTrue(result.isValid, "Zero amount should be valid")
    }

    func testValidateGasLimit() throws {
        // Arrange - Gas limit too low
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5,
            gasLimit: 10_000 // Too low for basic transfer
        )

        // Act
        let result = transactionService.validate(transaction)

        // Assert
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains { $0.contains("gas") })
    }

    // MARK: - Gas Estimation Tests

    func testEstimateGasForSimpleTransfer() {
        // Arrange
        let transaction = Transaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        // Act
        let gasEstimate = transactionService.estimateGas(for: transaction)

        // Assert
        XCTAssertEqual(gasEstimate, 21_000, "Simple transfer should use 21,000 gas")
    }

    func testEstimateGasForContractCall() {
        // Arrange
        let contractData = Data(repeating: 0x12, count: 100)
        let transaction = Transaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 0,
            nonce: 5,
            data: contractData
        )

        // Act
        let gasEstimate = transactionService.estimateGas(for: transaction)

        // Assert
        XCTAssertGreaterThan(gasEstimate, 21_000, "Contract call should use more than 21,000 gas")
    }

    // MARK: - Nonce Management Tests

    func testGetNextNonce() async throws {
        // Arrange
        let address = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"

        // Act
        let nonce = try await transactionService.getNextNonce(for: address)

        // Assert
        XCTAssertGreaterThanOrEqual(nonce, 0)
    }

    func testNonceIncrement() async throws {
        // Arrange
        let address = "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"

        // Act
        let nonce1 = try await transactionService.getNextNonce(for: address)
        let nonce2 = try await transactionService.getNextNonce(for: address, forceRefresh: true)

        // Assert - Nonce should be consistent unless transaction was sent
        XCTAssertEqual(nonce1, nonce2, "Nonce should be consistent")
    }

    // MARK: - Performance Tests

    func testTransactionCreationPerformance() {
        measure {
            _ = try? transactionService.createTransaction(
                from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
                to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
                amount: 1_000_000_000,
                nonce: 5
            )
        }
    }

    func testTransactionSerializationPerformance() throws {
        let transaction = try transactionService.createTransaction(
            from: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            to: "0x5aAeb6053F3E94C9b9A09f33669435E7Ef1BeAed",
            amount: 1_000_000_000,
            nonce: 5
        )

        measure {
            _ = try? transactionService.serialize(transaction)
        }
    }
}
