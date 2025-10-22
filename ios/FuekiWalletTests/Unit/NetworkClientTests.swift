import XCTest
@testable import FuekiWallet

final class NetworkClientTests: XCTestCase {

    var networkClient: NetworkClient!
    var mockURLSession: MockURLSession!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        networkClient = NetworkClient(urlSession: mockURLSession)
    }

    override func tearDown() {
        networkClient = nil
        mockURLSession = nil
        super.tearDown()
    }

    // MARK: - Balance Fetching Tests

    func testFetchBalance_Success() async throws {
        // Given
        let address = "tb1qtest123"
        let expectedBalance: UInt64 = 100000000
        mockURLSession.mockResponse = """
        {"address": "\(address)", "balance": \(expectedBalance)}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let balance = try await networkClient.fetchBalance(for: address)

        // Then
        XCTAssertEqual(balance, expectedBalance)
    }

    func testFetchBalance_NetworkError_ThrowsError() async {
        // Given
        let address = "tb1qtest123"
        mockURLSession.shouldFail = true

        // When/Then
        do {
            _ = try await networkClient.fetchBalance(for: address)
            XCTFail("Should throw network error")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    func testFetchBalance_InvalidResponse_ThrowsError() async {
        // Given
        let address = "tb1qtest123"
        mockURLSession.mockResponse = "invalid json".data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When/Then
        do {
            _ = try await networkClient.fetchBalance(for: address)
            XCTFail("Should throw parsing error")
        } catch {
            XCTAssertTrue(error is NetworkError.invalidResponse)
        }
    }

    func testFetchBalance_ServerError_ThrowsError() async {
        // Given
        let address = "tb1qtest123"
        mockURLSession.mockStatusCode = 500

        // When/Then
        do {
            _ = try await networkClient.fetchBalance(for: address)
            XCTFail("Should throw server error")
        } catch {
            XCTAssertTrue(error is NetworkError.serverError)
        }
    }

    // MARK: - Transaction History Tests

    func testFetchTransactionHistory_Success() async throws {
        // Given
        let address = "tb1qtest123"
        mockURLSession.mockResponse = """
        {
            "transactions": [
                {"txid": "tx1", "amount": 50000, "type": "received", "timestamp": 1640000000, "confirmations": 6},
                {"txid": "tx2", "amount": 25000, "type": "sent", "timestamp": 1639900000, "confirmations": 3}
            ]
        }
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let transactions = try await networkClient.fetchTransactionHistory(for: address)

        // Then
        XCTAssertEqual(transactions.count, 2)
        XCTAssertEqual(transactions[0].txid, "tx1")
        XCTAssertEqual(transactions[0].amount, 50000)
    }

    func testFetchTransactionHistory_EmptyHistory_ReturnsEmpty() async throws {
        // Given
        let address = "tb1qtest123"
        mockURLSession.mockResponse = """
        {"transactions": []}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let transactions = try await networkClient.fetchTransactionHistory(for: address)

        // Then
        XCTAssertTrue(transactions.isEmpty)
    }

    // MARK: - UTXO Fetching Tests

    func testFetchUTXOs_Success() async throws {
        // Given
        let address = "tb1qtest123"
        mockURLSession.mockResponse = """
        {
            "utxos": [
                {"txid": "abc123", "vout": 0, "amount": 100000},
                {"txid": "def456", "vout": 1, "amount": 50000}
            ]
        }
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let utxos = try await networkClient.fetchUTXOs(for: address)

        // Then
        XCTAssertEqual(utxos.count, 2)
        XCTAssertEqual(utxos[0].txid, "abc123")
        XCTAssertEqual(utxos[0].amount, 100000)
    }

    // MARK: - Transaction Broadcasting Tests

    func testBroadcastTransaction_Success() async throws {
        // Given
        let rawTransaction = Data(repeating: 0x01, count: 250)
        mockURLSession.mockResponse = """
        {"txid": "newtxid123", "status": "broadcasted"}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let txid = try await networkClient.broadcastTransaction(rawTransaction)

        // Then
        XCTAssertEqual(txid, "newtxid123")
    }

    func testBroadcastTransaction_AlreadyInMempool_ThrowsError() async {
        // Given
        let rawTransaction = Data(repeating: 0x01, count: 250)
        mockURLSession.mockResponse = """
        {"error": "transaction already in mempool"}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 400

        // When/Then
        do {
            _ = try await networkClient.broadcastTransaction(rawTransaction)
            XCTFail("Should throw error for duplicate transaction")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Fee Estimation Tests

    func testFetchFeeRates_Success() async throws {
        // Given
        mockURLSession.mockResponse = """
        {"fast": 50, "medium": 30, "slow": 10}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let feeRates = try await networkClient.fetchFeeRates()

        // Then
        XCTAssertEqual(feeRates.fast, 50)
        XCTAssertEqual(feeRates.medium, 30)
        XCTAssertEqual(feeRates.slow, 10)
    }

    // MARK: - Retry Logic Tests

    func testRequest_WithRetry_SucceedsAfterFailure() async throws {
        // Given
        mockURLSession.failureCount = 2 // Fail twice, then succeed
        mockURLSession.mockResponse = """
        {"success": true}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        // When
        let response = try await networkClient.request(
            endpoint: "/test",
            method: .get,
            maxRetries: 3
        )

        // Then
        XCTAssertNotNil(response)
    }

    func testRequest_ExceedsMaxRetries_ThrowsError() async {
        // Given
        mockURLSession.shouldFail = true

        // When/Then
        do {
            _ = try await networkClient.request(
                endpoint: "/test",
                method: .get,
                maxRetries: 2
            )
            XCTFail("Should throw after max retries")
        } catch {
            XCTAssertTrue(error is NetworkError)
        }
    }

    // MARK: - Timeout Tests

    func testRequest_Timeout_ThrowsError() async {
        // Given
        mockURLSession.delaySeconds = 10
        networkClient.timeout = 1

        // When/Then
        do {
            _ = try await networkClient.request(endpoint: "/test", method: .get)
            XCTFail("Should throw timeout error")
        } catch {
            XCTAssertTrue(error is NetworkError.timeout)
        }
    }

    // MARK: - Performance Tests

    func testFetchBalancePerformance() async {
        mockURLSession.mockResponse = """
        {"balance": 100000}
        """.data(using: .utf8)
        mockURLSession.mockStatusCode = 200

        measure {
            Task {
                _ = try? await networkClient.fetchBalance(for: "tb1qtest")
            }
        }
    }
}
