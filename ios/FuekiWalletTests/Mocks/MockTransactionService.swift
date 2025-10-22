//
//  MockTransactionService.swift
//  FuekiWalletTests
//
//  Mock transaction service for testing
//

import Foundation
@testable import FuekiWallet

final class MockTransactionService {

    // MARK: - Mock Data

    var mockTransactions: [Transaction] = []
    var mockTransactionID: String = "0xabc123def456"
    var updatedStatus: TransactionStatus?

    // MARK: - Call Tracking

    var sendTransactionCalled = false
    var loadTransactionsCalled = false
    var getTransactionStatusCalled = false

    // MARK: - Failure Flags

    var shouldFailSend = false
    var shouldFailLoadTransactions = false

    // MARK: - Methods

    func sendTransaction(
        from: String,
        to: String,
        amount: Decimal,
        gasLimit: UInt64?,
        maxFeePerGas: Decimal?,
        maxPriorityFeePerGas: Decimal?
    ) async throws -> String {
        sendTransactionCalled = true

        if shouldFailSend {
            throw TransactionError.sendFailed
        }

        return mockTransactionID
    }

    func loadTransactions(for address: String) async throws -> [Transaction] {
        loadTransactionsCalled = true

        if shouldFailLoadTransactions {
            throw TransactionError.loadFailed
        }

        return mockTransactions
    }

    func getTransactionStatus(hash: String) async throws -> TransactionStatus {
        getTransactionStatusCalled = true
        return updatedStatus ?? .pending
    }

    // MARK: - Helper Methods

    func reset() {
        mockTransactions = []
        mockTransactionID = "0xabc123def456"
        updatedStatus = nil

        sendTransactionCalled = false
        loadTransactionsCalled = false
        getTransactionStatusCalled = false

        shouldFailSend = false
        shouldFailLoadTransactions = false
    }
}

// MARK: - Supporting Types

enum TransactionError: Error {
    case sendFailed
    case loadFailed
    case invalidTransaction
}
