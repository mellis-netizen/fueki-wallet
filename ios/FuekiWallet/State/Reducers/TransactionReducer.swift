//
//  TransactionReducer.swift
//  FuekiWallet
//
//  Pure reducer for transaction state transformations
//

import Foundation

// MARK: - Transaction Reducer
func transactionReducer(state: inout TransactionState, action: Action) {
    guard let action = action as? TransactionAction else { return }

    switch action {

    // Fetch
    case .fetchTransactions:
        state.isLoading = true
        state.error = nil

    case .transactionsFetched(let transactions):
        categorizeTransactions(state: &state, transactions: transactions)
        state.lastFetchTimestamp = Date()
        state.isLoading = false
        state.error = nil

    case .fetchFailed(let error):
        state.error = error
        state.isLoading = false

    // Create
    case .createTransaction:
        state.isLoading = true
        state.error = nil

    case .transactionCreated(let transaction):
        state.pending.append(transaction)
        state.isLoading = false
        state.error = nil

    case .transactionFailed(let error):
        state.error = error
        state.isLoading = false

    // Send
    case .sendTransaction:
        state.isLoading = true
        state.error = nil

    case .transactionSent(let transaction):
        updateOrAddTransaction(state: &state, transaction: transaction)
        state.isLoading = false
        state.error = nil

    case .sendFailed(let error):
        state.error = error
        state.isLoading = false

    // Update
    case .updateTransaction(let id, let status):
        updateTransactionStatus(state: &state, id: id, status: status)

    case .transactionUpdated(let transaction):
        updateOrAddTransaction(state: &state, transaction: transaction)

    case .addConfirmation(let id):
        incrementConfirmation(state: &state, id: id)

    // Filter
    case .setFilter(let filter):
        state.filter = filter

    case .clearFilter:
        state.filter = .all

    // Pending
    case .addPendingTransaction(let transaction):
        state.pending.append(transaction)

    case .removePendingTransaction(let id):
        state.pending.removeAll { $0.id == id }

    case .confirmPendingTransaction(let id):
        if let index = state.pending.firstIndex(where: { $0.id == id }) {
            var transaction = state.pending[index]
            transaction.status = .confirmed
            state.pending.remove(at: index)
            state.confirmed.append(transaction)
        }

    // Failed
    case .addFailedTransaction(let transaction):
        state.failed.append(transaction)

    case .retryFailedTransaction(let id):
        if let index = state.failed.firstIndex(where: { $0.id == id }) {
            var transaction = state.failed[index]
            transaction.status = .pending
            state.failed.remove(at: index)
            state.pending.append(transaction)
        }

    case .removeFailedTransaction(let id):
        state.failed.removeAll { $0.id == id }

    // Loading & Errors
    case .setLoading(let loading):
        state.isLoading = loading

    case .setError(let error):
        state.error = error

    case .clearError:
        state.error = nil

    // Refresh
    case .refreshTransactions:
        state.isLoading = true
        state.error = nil

    case .refreshCompleted(let timestamp):
        state.lastFetchTimestamp = timestamp
        state.isLoading = false
        state.error = nil

    case .refreshFailed(let error):
        state.error = error
        state.isLoading = false

    // Details
    case .fetchTransactionDetails:
        state.isLoading = true
        state.error = nil

    case .transactionDetailsFetched(let transaction):
        updateOrAddTransaction(state: &state, transaction: transaction)
        state.isLoading = false
        state.error = nil

    case .detailsFetchFailed(let error):
        state.error = error
        state.isLoading = false

    // Cancel
    case .cancelTransaction(let id):
        updateTransactionStatus(state: &state, id: id, status: .cancelled)

    case .transactionCancelled(let id):
        state.pending.removeAll { $0.id == id }

    case .cancelFailed(let error):
        state.error = error
    }
}

// MARK: - Helper Functions
private func categorizeTransactions(state: inout TransactionState, transactions: [Transaction]) {
    state.pending = transactions.filter { $0.status == .pending }
    state.confirmed = transactions.filter { $0.status == .confirmed }
    state.failed = transactions.filter { $0.status == .failed }
}

private func updateOrAddTransaction(state: inout TransactionState, transaction: Transaction) {
    // Remove from all categories
    state.pending.removeAll { $0.id == transaction.id }
    state.confirmed.removeAll { $0.id == transaction.id }
    state.failed.removeAll { $0.id == transaction.id }

    // Add to appropriate category
    switch transaction.status {
    case .pending:
        state.pending.append(transaction)
    case .confirmed:
        state.confirmed.append(transaction)
    case .failed, .cancelled:
        state.failed.append(transaction)
    }
}

private func updateTransactionStatus(state: inout TransactionState, id: String, status: TransactionStatus) {
    if let index = state.pending.firstIndex(where: { $0.id == id }) {
        state.pending[index].status = status
    } else if let index = state.confirmed.firstIndex(where: { $0.id == id }) {
        state.confirmed[index].status = status
    } else if let index = state.failed.firstIndex(where: { $0.id == id }) {
        state.failed[index].status = status
    }
}

private func incrementConfirmation(state: inout TransactionState, id: String) {
    if let index = state.pending.firstIndex(where: { $0.id == id }) {
        let currentConfirmations = state.pending[index].confirmations ?? 0
        state.pending[index].confirmations = currentConfirmations + 1
    } else if let index = state.confirmed.firstIndex(where: { $0.id == id }) {
        let currentConfirmations = state.confirmed[index].confirmations ?? 0
        state.confirmed[index].confirmations = currentConfirmations + 1
    }
}

// MARK: - Transaction History Reducer
func transactionHistoryReducer(state: inout TransactionState, action: Action) {
    guard let action = action as? TransactionHistoryAction else { return }

    switch action {
    case .loadMore:
        state.isLoading = true
        state.error = nil

    case .loadMoreCompleted(let transactions):
        categorizeTransactions(state: &state, transactions: transactions)
        state.isLoading = false
        state.error = nil

    case .loadMoreFailed(let error):
        state.error = error
        state.isLoading = false

    case .clearHistory:
        state.pending.removeAll()
        state.confirmed.removeAll()
        state.failed.removeAll()

    case .exportHistory:
        state.isLoading = true
        state.error = nil

    case .historyExported:
        state.isLoading = false
        state.error = nil
    }
}

// MARK: - Transaction Fee Reducer
func transactionFeeReducer(state: inout TransactionState, action: Action) {
    guard let action = action as? TransactionFeeAction else { return }

    switch action {
    case .estimateFee:
        state.isLoading = true
        state.error = nil

    case .feeEstimated:
        state.isLoading = false
        state.error = nil

    case .estimationFailed(let error):
        state.error = error
        state.isLoading = false

    case .updateFee(let transactionId, let fee):
        if let index = state.pending.firstIndex(where: { $0.id == transactionId }) {
            state.pending[index].fee = fee
        }
    }
}
