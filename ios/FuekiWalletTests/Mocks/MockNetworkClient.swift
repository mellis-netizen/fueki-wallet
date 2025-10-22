import Foundation
@testable import FuekiWallet

final class MockNetworkClient: NetworkClientProtocol {

    // MARK: - Mock Data

    var mockUTXOs: [UTXO] = []
    var mockBalance: UInt64 = 0
    var mockTransactions: [Transaction] = []
    var mockFeeRates = FeeRates(fast: 50, medium: 30, slow: 10)
    var mockTransactionID = "mocktxid123"

    // MARK: - Failure Flags

    var shouldFail = false
    var errorToThrow: Error = NetworkError.serverError(500)
    var delaySeconds: TimeInterval = 0
    var failureCount = 0 // For retry testing

    // MARK: - Call Tracking

    var requestCount = 0
    var lastEndpoint: String?
    var lastMethod: HTTPMethod?

    // MARK: - NetworkClientProtocol Implementation

    func fetchBalance(for address: String) async throws -> UInt64 {
        requestCount += 1

        if shouldFail {
            throw errorToThrow
        }

        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        return mockBalance
    }

    func fetchTransactionHistory(for address: String) async throws -> [Transaction] {
        requestCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return mockTransactions
    }

    func fetchUTXOs(for address: String) async throws -> [UTXO] {
        requestCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return mockUTXOs
    }

    func broadcastTransaction(_ rawTransaction: Data) async throws -> String {
        requestCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return mockTransactionID
    }

    func fetchFeeRates() async throws -> FeeRates {
        requestCount += 1

        if shouldFail {
            throw errorToThrow
        }

        return mockFeeRates
    }

    func request(
        endpoint: String,
        method: HTTPMethod,
        body: Data? = nil,
        maxRetries: Int = 0
    ) async throws -> Data {
        requestCount += 1
        lastEndpoint = endpoint
        lastMethod = method

        // Simulate retry logic
        if failureCount > 0 {
            failureCount -= 1
            throw errorToThrow
        }

        if shouldFail {
            throw errorToThrow
        }

        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        return Data()
    }

    // MARK: - Helper Methods

    func reset() {
        mockUTXOs = []
        mockBalance = 0
        mockTransactions = []
        mockFeeRates = FeeRates(fast: 50, medium: 30, slow: 10)
        mockTransactionID = "mocktxid123"

        shouldFail = false
        errorToThrow = NetworkError.serverError(500)
        delaySeconds = 0
        failureCount = 0

        requestCount = 0
        lastEndpoint = nil
        lastMethod = nil
    }
}

// MARK: - Mock URL Session

final class MockURLSession: URLSessionProtocol {

    var mockResponse: Data?
    var mockStatusCode: Int = 200
    var mockError: Error?
    var shouldFail = false
    var delaySeconds: TimeInterval = 0
    var failureCount = 0

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        if failureCount > 0 {
            failureCount -= 1
            throw mockError ?? URLError(.networkConnectionLost)
        }

        if shouldFail {
            throw mockError ?? URLError(.networkConnectionLost)
        }

        if delaySeconds > 0 {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: mockStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!

        return (mockResponse ?? Data(), response)
    }
}
