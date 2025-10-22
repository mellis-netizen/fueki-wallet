//
//  TransactionState.swift
//  Fueki Wallet
//
//  Transaction state management with pending/confirmed tracking
//

import Foundation
import Combine
import SwiftUI

@MainActor
class TransactionState: ObservableObject {
    // MARK: - Published Properties
    @Published var transactions: [Transaction] = []
    @Published var pendingTransactions: [Transaction] = []
    @Published var recentTransactions: [Transaction] = []
    @Published var isLoadingHistory = false
    @Published var hasMoreHistory = true

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private let maxRecentCount = 10
    private var currentPage = 0
    private let pageSize = 20

    // MARK: - Initialization
    init() {
        setupTransactionMonitoring()
    }

    // MARK: - Transaction Management

    func addTransaction(_ transaction: Transaction) {
        if transaction.status == .pending {
            pendingTransactions.append(transaction)
            startMonitoring(transaction)
        }

        transactions.insert(transaction, at: 0)
        updateRecentTransactions()
        notifyStateChange()
    }

    func updateTransaction(_ transaction: Transaction) {
        if let index = transactions.firstIndex(where: { $0.id == transaction.id }) {
            transactions[index] = transaction
        }

        if let index = pendingTransactions.firstIndex(where: { $0.id == transaction.id }) {
            if transaction.status != .pending {
                pendingTransactions.remove(at: index)
            } else {
                pendingTransactions[index] = transaction
            }
        }

        updateRecentTransactions()
        notifyStateChange()
    }

    func removeTransaction(_ transactionId: String) {
        transactions.removeAll { $0.id == transactionId }
        pendingTransactions.removeAll { $0.id == transactionId }
        updateRecentTransactions()
        notifyStateChange()
    }

    // MARK: - History Management

    func loadTransactionHistory(walletAddress: String) async {
        guard !isLoadingHistory else { return }

        isLoadingHistory = true

        do {
            let newTransactions = try await fetchTransactionHistory(
                address: walletAddress,
                page: currentPage,
                pageSize: pageSize
            )

            await MainActor.run {
                if currentPage == 0 {
                    self.transactions = newTransactions
                } else {
                    self.transactions.append(contentsOf: newTransactions)
                }

                self.hasMoreHistory = newTransactions.count == self.pageSize
                self.currentPage += 1
                self.updateRecentTransactions()
                self.isLoadingHistory = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingHistory = false
            }
            print("Failed to load transaction history: \(error)")
        }
    }

    func refreshTransactionHistory(walletAddress: String) async {
        currentPage = 0
        hasMoreHistory = true
        await loadTransactionHistory(walletAddress: walletAddress)
    }

    // MARK: - Filtering & Search

    func getTransactions(
        for assetId: String? = nil,
        type: TransactionType? = nil,
        status: TransactionStatus? = nil
    ) -> [Transaction] {
        transactions.filter { transaction in
            var matches = true

            if let assetId = assetId {
                matches = matches && transaction.asset.id == assetId
            }

            if let type = type {
                matches = matches && transaction.type == type
            }

            if let status = status {
                matches = matches && transaction.status == status
            }

            return matches
        }
    }

    func searchTransactions(query: String) -> [Transaction] {
        guard !query.isEmpty else { return transactions }

        let lowercasedQuery = query.lowercased()
        return transactions.filter { transaction in
            transaction.hash?.lowercased().contains(lowercasedQuery) ?? false ||
            transaction.toAddress?.lowercased().contains(lowercasedQuery) ?? false ||
            transaction.fromAddress?.lowercased().contains(lowercasedQuery) ?? false ||
            transaction.asset.name.lowercased().contains(lowercasedQuery)
        }
    }

    // MARK: - State Management

    func reset() {
        transactions = []
        pendingTransactions = []
        recentTransactions = []
        isLoadingHistory = false
        hasMoreHistory = true
        currentPage = 0
    }

    // MARK: - Snapshot Management

    func createSnapshot() -> TransactionStateSnapshot {
        TransactionStateSnapshot(
            transactions: Array(transactions.prefix(100)), // Limit to recent 100
            pendingTransactions: pendingTransactions
        )
    }

    func restore(from snapshot: TransactionStateSnapshot) async {
        transactions = snapshot.transactions
        pendingTransactions = snapshot.pendingTransactions
        updateRecentTransactions()

        // Resume monitoring pending transactions
        for transaction in pendingTransactions {
            startMonitoring(transaction)
        }
    }

    // MARK: - Private Methods

    private func setupTransactionMonitoring() {
        // Monitor pending transactions
        $pendingTransactions
            .sink { [weak self] pending in
                if pending.isEmpty {
                    self?.notifyAllTransactionsComplete()
                }
            }
            .store(in: &cancellables)
    }

    private func updateRecentTransactions() {
        recentTransactions = Array(transactions.prefix(maxRecentCount))
    }

    private func startMonitoring(_ transaction: Transaction) {
        // Monitor blockchain for transaction status
        Task {
            var currentTransaction = transaction
            var pollCount = 0
            let maxPolls = 60 // Monitor for up to 30 minutes (30s intervals)

            while currentTransaction.status == .pending && pollCount < maxPolls {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds

                // Simulate blockchain polling
                // In production, this would call actual blockchain API
                pollCount += 1

                // Simulate confirmation progress
                if pollCount > 2 {
                    currentTransaction.confirmations = min(pollCount - 2, 6)

                    if currentTransaction.confirmations >= 6 {
                        currentTransaction.status = .confirmed
                        updateTransaction(currentTransaction)

                        NotificationCenter.default.post(
                            name: .transactionConfirmed,
                            object: currentTransaction
                        )
                        break
                    }

                    updateTransaction(currentTransaction)
                }
            }

            // If still pending after max polls, mark as failed
            if currentTransaction.status == .pending {
                currentTransaction.status = .failed
                updateTransaction(currentTransaction)
            }
        }
    }

    private func fetchTransactionHistory(
        address: String,
        page: Int,
        pageSize: Int
    ) async throws -> [Transaction] {
        // Simulate API delay
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // In production, this would fetch from blockchain API
        // For now, return empty to indicate no more history
        return []
    }

    private func notifyStateChange() {
        NotificationCenter.default.post(
            name: .transactionStateChanged,
            object: createSnapshot()
        )
    }

    private func notifyAllTransactionsComplete() {
        NotificationCenter.default.post(
            name: .allTransactionsConfirmed,
            object: nil
        )
    }
}

// MARK: - Supporting Types

struct TransactionStateSnapshot: Codable {
    let transactions: [Transaction]
    let pendingTransactions: [Transaction]
}

// MARK: - Notifications

extension Notification.Name {
    static let transactionStateChanged = Notification.Name("transactionStateChanged")
    static let allTransactionsConfirmed = Notification.Name("allTransactionsConfirmed")
    static let transactionConfirmed = Notification.Name("transactionConfirmed")
}
