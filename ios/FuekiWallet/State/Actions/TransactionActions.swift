//
//  TransactionActions.swift
//  FuekiWallet
//
//  Actions related to transaction state
//

import Foundation

// MARK: - Transaction Actions
enum TransactionAction: Action {

    // Fetch
    case fetchTransactions
    case transactionsFetched(transactions: [Transaction])
    case fetchFailed(error: ErrorState)

    // Create
    case createTransaction(type: TransactionType, amount: Decimal, to: String, memo: String?)
    case transactionCreated(transaction: Transaction)
    case transactionFailed(error: ErrorState)

    // Send
    case sendTransaction(id: String)
    case transactionSent(transaction: Transaction)
    case sendFailed(error: ErrorState)

    // Update
    case updateTransaction(id: String, status: TransactionStatus)
    case transactionUpdated(transaction: Transaction)
    case addConfirmation(id: String)

    // Filter
    case setFilter(TransactionFilter)
    case clearFilter

    // Pending
    case addPendingTransaction(transaction: Transaction)
    case removePendingTransaction(id: String)
    case confirmPendingTransaction(id: String)

    // Failed
    case addFailedTransaction(transaction: Transaction)
    case retryFailedTransaction(id: String)
    case removeFailedTransaction(id: String)

    // Loading & Errors
    case setLoading(Bool)
    case setError(ErrorState?)
    case clearError

    // Refresh
    case refreshTransactions
    case refreshCompleted(timestamp: Date)
    case refreshFailed(error: ErrorState)

    // Details
    case fetchTransactionDetails(id: String)
    case transactionDetailsFetched(transaction: Transaction)
    case detailsFetchFailed(error: ErrorState)

    // Cancel
    case cancelTransaction(id: String)
    case transactionCancelled(id: String)
    case cancelFailed(error: ErrorState)
}

// MARK: - Transaction History Actions
enum TransactionHistoryAction: Action {
    case loadMore
    case loadMoreCompleted(transactions: [Transaction])
    case loadMoreFailed(error: ErrorState)
    case clearHistory
    case exportHistory
    case historyExported(path: String)
}

// MARK: - Transaction Fee Actions
enum TransactionFeeAction: Action {
    case estimateFee(type: TransactionType, amount: Decimal)
    case feeEstimated(fee: Decimal)
    case estimationFailed(error: ErrorState)
    case updateFee(transactionId: String, fee: Decimal)
}
