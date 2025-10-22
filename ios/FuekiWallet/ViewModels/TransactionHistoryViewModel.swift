//
//  TransactionHistoryViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine

/// ViewModel managing transaction history and filtering
@MainActor
final class TransactionHistoryViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var transactions: [TransactionRecord] = []
    @Published var filteredTransactions: [TransactionRecord] = []
    @Published var selectedTransaction: TransactionRecord?

    // MARK: - Filters

    @Published var filterType: TransactionFilterType = .all
    @Published var filterStatus: TransactionStatus?
    @Published var filterAsset: Asset?
    @Published var searchQuery = ""
    @Published var dateRange: DateRange = .allTime

    // MARK: - State

    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Pagination

    private var currentPage = 0
    private let pageSize = 20

    // MARK: - Dependencies

    private let transactionService: TransactionHistoryServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        transactionService: TransactionHistoryServiceProtocol = TransactionHistoryService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.transactionService = transactionService
        self.walletViewModel = walletViewModel
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Apply filters when any filter changes
        Publishers.CombineLatest4($transactions, $filterType, $filterStatus, $filterAsset)
            .combineLatest($searchQuery, $dateRange)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .map { [weak self] combined, search, range in
                let (transactions, type, status, asset) = combined
                return self?.applyFilters(
                    transactions: transactions,
                    type: type,
                    status: status,
                    asset: asset,
                    search: search,
                    dateRange: range
                ) ?? []
            }
            .assign(to: &$filteredTransactions)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Reload when network changes
        walletViewModel.$selectedNetwork
            .dropFirst()
            .sink { [weak self] _ in
                Task { await self?.loadTransactions() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    func loadTransactions() async {
        guard let wallet = walletViewModel.currentWallet else { return }

        isLoading = true
        errorMessage = nil
        currentPage = 0

        do {
            let result = try await transactionService.fetchTransactions(
                for: wallet,
                network: walletViewModel.selectedNetwork,
                page: currentPage,
                pageSize: pageSize
            )

            transactions = result.transactions
            hasMore = result.hasMore
        } catch {
            errorMessage = "Failed to load transactions: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func loadMoreTransactions() async {
        guard hasMore, !isLoadingMore, let wallet = walletViewModel.currentWallet else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let result = try await transactionService.fetchTransactions(
                for: wallet,
                network: walletViewModel.selectedNetwork,
                page: currentPage,
                pageSize: pageSize
            )

            transactions.append(contentsOf: result.transactions)
            hasMore = result.hasMore
        } catch {
            errorMessage = "Failed to load more transactions: \(error.localizedDescription)"
            currentPage -= 1
        }

        isLoadingMore = false
    }

    func refreshTransactions() async {
        await loadTransactions()
    }

    // MARK: - Filtering

    private func applyFilters(
        transactions: [TransactionRecord],
        type: TransactionFilterType,
        status: TransactionStatus?,
        asset: Asset?,
        search: String,
        dateRange: DateRange
    ) -> [TransactionRecord] {
        var filtered = transactions

        // Filter by type
        if type != .all {
            filtered = filtered.filter { transaction in
                switch type {
                case .sent:
                    return transaction.direction == .outgoing
                case .received:
                    return transaction.direction == .incoming
                case .swapped:
                    return transaction.type == .swap
                case .contract:
                    return transaction.type == .contractInteraction
                case .all:
                    return true
                }
            }
        }

        // Filter by status
        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }

        // Filter by asset
        if let asset = asset {
            filtered = filtered.filter { $0.asset.id == asset.id }
        }

        // Filter by search query
        if !search.isEmpty {
            filtered = filtered.filter { transaction in
                transaction.hash.localizedCaseInsensitiveContains(search) ||
                transaction.toAddress.localizedCaseInsensitiveContains(search) ||
                transaction.fromAddress.localizedCaseInsensitiveContains(search) ||
                transaction.asset.symbol.localizedCaseInsensitiveContains(search)
            }
        }

        // Filter by date range
        filtered = filtered.filter { dateRange.contains($0.timestamp) }

        return filtered
    }

    func clearFilters() {
        filterType = .all
        filterStatus = nil
        filterAsset = nil
        searchQuery = ""
        dateRange = .allTime
    }

    // MARK: - Transaction Details

    func selectTransaction(_ transaction: TransactionRecord) {
        selectedTransaction = transaction
    }

    func openExplorer(for transaction: TransactionRecord) {
        let explorerURL = walletViewModel.selectedNetwork.explorerURL
        if let url = URL(string: "\(explorerURL)/tx/\(transaction.hash)") {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Export

    func exportTransactions() async -> URL? {
        let csvContent = generateCSV()

        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "transactions_\(Date().ISO8601Format()).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            errorMessage = "Failed to export transactions: \(error.localizedDescription)"
            return nil
        }
    }

    private func generateCSV() -> String {
        var csv = "Date,Type,Asset,Amount,From,To,Fee,Status,Hash\n"

        for transaction in filteredTransactions {
            let row = [
                transaction.formattedDate,
                transaction.type.rawValue,
                transaction.asset.symbol,
                String(describing: transaction.amount),
                transaction.fromAddress,
                transaction.toAddress,
                String(describing: transaction.fee),
                transaction.status.rawValue,
                transaction.hash
            ].joined(separator: ",")

            csv += row + "\n"
        }

        return csv
    }

    // MARK: - Computed Properties

    var totalSent: Decimal {
        transactions
            .filter { $0.direction == .outgoing && $0.status == .confirmed }
            .reduce(0) { $0 + $1.amount }
    }

    var totalReceived: Decimal {
        transactions
            .filter { $0.direction == .incoming && $0.status == .confirmed }
            .reduce(0) { $0 + $1.amount }
    }

    var totalFees: Decimal {
        transactions
            .filter { $0.status == .confirmed }
            .reduce(0) { $0 + $1.fee }
    }

    var transactionsByDate: [Date: [TransactionRecord]] {
        Dictionary(grouping: filteredTransactions) { transaction in
            Calendar.current.startOfDay(for: transaction.timestamp)
        }
    }
}

// MARK: - Models

struct TransactionRecord: Identifiable, Codable {
    let id: String
    let hash: String
    let fromAddress: String
    let toAddress: String
    let amount: Decimal
    let fee: Decimal
    let asset: Asset
    let timestamp: Date
    let status: TransactionStatus
    let type: TransactionType
    let direction: TransactionDirection
    let blockNumber: Int?
    let confirmations: Int
    let nonce: Int?

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8

        let number = NSDecimalNumber(decimal: amount)
        let formatted = formatter.string(from: number) ?? "0.00"

        let prefix = direction == .incoming ? "+" : "-"
        return "\(prefix)\(formatted) \(asset.symbol)"
    }

    var statusColor: String {
        switch status {
        case .pending: return "orange"
        case .confirmed: return "green"
        case .failed: return "red"
        }
    }
}

enum TransactionStatus: String, Codable, CaseIterable {
    case pending = "Pending"
    case confirmed = "Confirmed"
    case failed = "Failed"
}

enum TransactionType: String, Codable {
    case send
    case receive
    case swap
    case contractInteraction = "Contract"
}

enum TransactionDirection: String, Codable {
    case incoming
    case outgoing
}

enum TransactionFilterType: String, CaseIterable {
    case all = "All"
    case sent = "Sent"
    case received = "Received"
    case swapped = "Swapped"
    case contract = "Contract"
}

enum DateRange: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case threeMonths = "3 Months"
    case year = "This Year"
    case allTime = "All Time"

    func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.isDateInToday(date)
        case .week:
            return date >= calendar.date(byAdding: .day, value: -7, to: now)!
        case .month:
            return date >= calendar.date(byAdding: .month, value: -1, to: now)!
        case .threeMonths:
            return date >= calendar.date(byAdding: .month, value: -3, to: now)!
        case .year:
            return date >= calendar.date(byAdding: .year, value: -1, to: now)!
        case .allTime:
            return true
        }
    }
}

struct TransactionResult {
    let transactions: [TransactionRecord]
    let hasMore: Bool
}

// MARK: - Service Protocol

protocol TransactionHistoryServiceProtocol {
    func fetchTransactions(
        for wallet: Wallet,
        network: Network,
        page: Int,
        pageSize: Int
    ) async throws -> TransactionResult
}
