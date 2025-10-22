//
//  TransactionSelectors.swift
//  FuekiWallet
//
//  Selectors for deriving transaction state
//

import Foundation

// MARK: - Transaction Selectors
struct TransactionSelectors {

    // MARK: - Basic Selectors
    static func allTransactions(from state: AppState) -> [Transaction] {
        state.transactions.allTransactions
    }

    static func pendingTransactions(from state: AppState) -> [Transaction] {
        state.transactions.pending
    }

    static func confirmedTransactions(from state: AppState) -> [Transaction] {
        state.transactions.confirmed
    }

    static func failedTransactions(from state: AppState) -> [Transaction] {
        state.transactions.failed
    }

    static func transactionById(_ id: String) -> (AppState) -> Transaction? {
        return { state in
            state.transactions.allTransactions.first { $0.id == id }
        }
    }

    // MARK: - Filter Selectors
    static func currentFilter(from state: AppState) -> TransactionFilter {
        state.transactions.filter
    }

    static func filteredTransactions(from state: AppState) -> [Transaction] {
        let all = state.transactions.allTransactions
        let filter = state.transactions.filter

        switch filter {
        case .all:
            return all
        case .sent:
            return all.filter { $0.type == .send }
        case .received:
            return all.filter { $0.type == .receive }
        case .pending:
            return all.filter { $0.status == .pending }
        case .failed:
            return all.filter { $0.status == .failed }
        }
    }

    // MARK: - Status Selectors
    static func isLoading(from state: AppState) -> Bool {
        state.transactions.isLoading
    }

    static func hasError(from state: AppState) -> Bool {
        state.transactions.error != nil
    }

    static func error(from state: AppState) -> ErrorState? {
        state.transactions.error
    }

    static func lastFetchTime(from state: AppState) -> Date? {
        state.transactions.lastFetchTimestamp
    }

    // MARK: - Count Selectors
    static func totalTransactionCount(from state: AppState) -> Int {
        state.transactions.allTransactions.count
    }

    static func pendingCount(from state: AppState) -> Int {
        state.transactions.pending.count
    }

    static func confirmedCount(from state: AppState) -> Int {
        state.transactions.confirmed.count
    }

    static func failedCount(from state: AppState) -> Int {
        state.transactions.failed.count
    }

    static func hasPendingTransactions(from state: AppState) -> Bool {
        !state.transactions.pending.isEmpty
    }

    // MARK: - Type-based Selectors
    static func transactionsByType(_ type: TransactionType) -> (AppState) -> [Transaction] {
        return { state in
            state.transactions.allTransactions.filter { $0.type == type }
        }
    }

    static func sentTransactions(from state: AppState) -> [Transaction] {
        state.transactions.allTransactions.filter { $0.type == .send }
    }

    static func receivedTransactions(from state: AppState) -> [Transaction] {
        state.transactions.allTransactions.filter { $0.type == .receive }
    }

    static func swapTransactions(from state: AppState) -> [Transaction] {
        state.transactions.allTransactions.filter { $0.type == .swap }
    }

    // MARK: - Time-based Selectors
    static func recentTransactions(limit: Int = 10) -> (AppState) -> [Transaction] {
        return { state in
            Array(state.transactions.allTransactions.prefix(limit))
        }
    }

    static func transactionsToday(from state: AppState) -> [Transaction] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return state.transactions.allTransactions.filter {
            calendar.isDate($0.timestamp, inSameDayAs: today)
        }
    }

    static func transactionsThisWeek(from state: AppState) -> [Transaction] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        return state.transactions.allTransactions.filter {
            $0.timestamp >= weekAgo
        }
    }

    static func transactionsThisMonth(from state: AppState) -> [Transaction] {
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: Date())!

        return state.transactions.allTransactions.filter {
            $0.timestamp >= monthAgo
        }
    }

    static func transactionsInDateRange(from: Date, to: Date) -> (AppState) -> [Transaction] {
        return { state in
            state.transactions.allTransactions.filter {
                $0.timestamp >= from && $0.timestamp <= to
            }
        }
    }

    // MARK: - Amount-based Selectors
    static func largestTransaction(from state: AppState) -> Transaction? {
        state.transactions.allTransactions.max { $0.amount < $1.amount }
    }

    static func smallestTransaction(from state: AppState) -> Transaction? {
        state.transactions.allTransactions.min { $0.amount < $1.amount }
    }

    static func transactionsAboveAmount(_ amount: Decimal) -> (AppState) -> [Transaction] {
        return { state in
            state.transactions.allTransactions.filter { $0.amount >= amount }
        }
    }

    static func totalTransactionVolume(from state: AppState) -> Decimal {
        state.transactions.allTransactions.reduce(0) { $0 + $1.amount }
    }

    static func totalSent(from state: AppState) -> Decimal {
        sentTransactions(from: state).reduce(0) { $0 + $1.amount }
    }

    static func totalReceived(from state: AppState) -> Decimal {
        receivedTransactions(from: state).reduce(0) { $0 + $1.amount }
    }

    // MARK: - Search Selectors
    static func transactionsMatching(query: String) -> (AppState) -> [Transaction] {
        return { state in
            guard !query.isEmpty else { return state.transactions.allTransactions }

            let lowercasedQuery = query.lowercased()
            return state.transactions.allTransactions.filter {
                $0.fromAddress.lowercased().contains(lowercasedQuery) ||
                $0.toAddress.lowercased().contains(lowercasedQuery) ||
                $0.hash?.lowercased().contains(lowercasedQuery) == true ||
                $0.memo?.lowercased().contains(lowercasedQuery) == true
            }
        }
    }

    static func transactionsByAddress(_ address: String) -> (AppState) -> [Transaction] {
        return { state in
            state.transactions.allTransactions.filter {
                $0.fromAddress == address || $0.toAddress == address
            }
        }
    }

    // MARK: - Statistics
    static func transactionStatistics(from state: AppState) -> TransactionStatistics {
        let all = state.transactions.allTransactions

        return TransactionStatistics(
            total: all.count,
            pending: state.transactions.pending.count,
            confirmed: state.transactions.confirmed.count,
            failed: state.transactions.failed.count,
            totalVolume: totalTransactionVolume(from: state),
            totalSent: totalSent(from: state),
            totalReceived: totalReceived(from: state),
            averageAmount: averageTransactionAmount(from: state),
            largestAmount: largestTransaction(from: state)?.amount ?? 0,
            smallestAmount: smallestTransaction(from: state)?.amount ?? 0
        )
    }

    private static func averageTransactionAmount(from state: AppState) -> Decimal {
        let transactions = state.transactions.allTransactions
        guard !transactions.isEmpty else { return 0 }
        return totalTransactionVolume(from: state) / Decimal(transactions.count)
    }

    // MARK: - Grouping
    static func transactionsGroupedByDate(from state: AppState) -> [Date: [Transaction]] {
        let calendar = Calendar.current
        var grouped: [Date: [Transaction]] = [:]

        for transaction in state.transactions.allTransactions {
            let date = calendar.startOfDay(for: transaction.timestamp)
            grouped[date, default: []].append(transaction)
        }

        return grouped
    }

    static func transactionsGroupedByType(from state: AppState) -> [TransactionType: [Transaction]] {
        var grouped: [TransactionType: [Transaction]] = [:]

        for transaction in state.transactions.allTransactions {
            grouped[transaction.type, default: []].append(transaction)
        }

        return grouped
    }
}

// MARK: - Supporting Types
struct TransactionStatistics {
    let total: Int
    let pending: Int
    let confirmed: Int
    let failed: Int
    let totalVolume: Decimal
    let totalSent: Decimal
    let totalReceived: Decimal
    let averageAmount: Decimal
    let largestAmount: Decimal
    let smallestAmount: Decimal
}
