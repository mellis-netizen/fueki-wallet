import Foundation
@testable import FuekiWallet

final class MockBlockchainProvider: BlockchainProviderProtocol {

    // MARK: - Mock Data

    var mockBalance: UInt64 = 0
    var mockTransactions: [Transaction] = []
    var mockUTXOs: [UTXO] = []
    var mockTransactionID: String = ""
    var mockFeeRates = FeeRates(fast: 50, medium: 30, slow: 10)

    // MARK: - Failure Flags

    var shouldFailGetBalance = false
    var shouldFailGetTransactions = false
    var shouldFailGetUTXOs = false
    var shouldFailBroadcast = false
    var shouldFailFeeRates = false

    // MARK: - Call Tracking

    var getBalanceWasCalled = false
    var getTransactionsWasCalled = false
    var getUTXOsWasCalled = false
    var broadcastWasCalled = false
    var getFeeRatesWasCalled = false

    var lastAddressQueried: String?
    var lastBroadcastedTransaction: Data?

    // MARK: - BlockchainProviderProtocol Implementation

    func fetchBalance(for address: String) async throws -> UInt64 {
        getBalanceWasCalled = true
        lastAddressQueried = address

        if shouldFailGetBalance {
            throw NetworkError.serverError(500)
        }

        return mockBalance
    }

    func fetchTransactionHistory(for address: String) async throws -> [Transaction] {
        getTransactionsWasCalled = true
        lastAddressQueried = address

        if shouldFailGetTransactions {
            throw NetworkError.serverError(500)
        }

        return mockTransactions
    }

    func fetchUTXOs(for address: String) async throws -> [UTXO] {
        getUTXOsWasCalled = true
        lastAddressQueried = address

        if shouldFailGetUTXOs {
            throw NetworkError.serverError(500)
        }

        return mockUTXOs
    }

    func broadcastTransaction(_ rawTransaction: Data) async throws -> String {
        broadcastWasCalled = true
        lastBroadcastedTransaction = rawTransaction

        if shouldFailBroadcast {
            throw NetworkError.serverError(500)
        }

        return mockTransactionID
    }

    func fetchFeeRates() async throws -> FeeRates {
        getFeeRatesWasCalled = true

        if shouldFailFeeRates {
            throw NetworkError.serverError(500)
        }

        return mockFeeRates
    }

    func getBlockHeight() async throws -> UInt64 {
        return 2000000 // Mock block height
    }

    func getTransactionConfirmations(txid: String) async throws -> Int {
        return 6 // Mock confirmations
    }

    // MARK: - Helper Methods

    func reset() {
        mockBalance = 0
        mockTransactions = []
        mockUTXOs = []
        mockTransactionID = ""
        mockFeeRates = FeeRates(fast: 50, medium: 30, slow: 10)

        shouldFailGetBalance = false
        shouldFailGetTransactions = false
        shouldFailGetUTXOs = false
        shouldFailBroadcast = false
        shouldFailFeeRates = false

        getBalanceWasCalled = false
        getTransactionsWasCalled = false
        getUTXOsWasCalled = false
        broadcastWasCalled = false
        getFeeRatesWasCalled = false

        lastAddressQueried = nil
        lastBroadcastedTransaction = nil
    }
}
