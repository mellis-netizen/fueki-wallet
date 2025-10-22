//
//  TransactionHistoryViewModelTests.swift
//  FuekiWalletTests
//
//  Comprehensive tests for transaction history functionality
//

import XCTest
import Combine
@testable import FuekiWallet

@MainActor
final class TransactionHistoryViewModelTests: XCTestCase {

    var sut: TransactionHistoryViewModel!
    var mockTransactionService: MockTransactionService!
    var mockWalletService: MockWalletService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        mockTransactionService = MockTransactionService()
        mockWalletService = MockWalletService()
        cancellables = []

        sut = TransactionHistoryViewModel(
            transactionService: mockTransactionService,
            walletService: mockWalletService
        )
    }

    override func tearDown() {
        sut = nil
        mockTransactionService = nil
        mockWalletService = nil
        cancellables = nil
    }

    // MARK: - Load Transactions Tests

    func testLoadTransactions_Success() async {
        // Given
        let mockTransactions = [
            Transaction(
                id: "tx1",
                hash: "0xabc",
                from: "0x123",
                to: "0x456",
                amount: Decimal(100000),
                timestamp: Date(),
                status: .confirmed,
                type: .sent
            ),
            Transaction(
                id: "tx2",
                hash: "0xdef",
                from: "0x789",
                to: "0x123",
                amount: Decimal(200000),
                timestamp: Date().addingTimeInterval(-3600),
                status: .confirmed,
                type: .received
            )
        ]
        mockTransactionService.mockTransactions = mockTransactions

        // When
        await sut.loadTransactions()

        // Then
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.transactions.count, 2)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadTransactions_Empty() async {
        // Given
        mockTransactionService.mockTransactions = []

        // When
        await sut.loadTransactions()

        // Then
        XCTAssertTrue(sut.transactions.isEmpty)
        XCTAssertFalse(sut.isLoading)
    }

    func testLoadTransactions_Failure() async {
        // Given
        mockTransactionService.shouldFailLoadTransactions = true

        // When
        await sut.loadTransactions()

        // Then
        XCTAssertTrue(sut.transactions.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    // MARK: - Filter Tests

    func testFilterTransactions_All() {
        // Given
        setupMockTransactions()

        // When
        sut.selectedFilter = .all
        sut.applyFilter()

        // Then
        XCTAssertEqual(sut.filteredTransactions.count, 4)
    }

    func testFilterTransactions_SentOnly() {
        // Given
        setupMockTransactions()

        // When
        sut.selectedFilter = .sent
        sut.applyFilter()

        // Then
        XCTAssertEqual(sut.filteredTransactions.count, 2)
        XCTAssertTrue(sut.filteredTransactions.allSatisfy { $0.type == .sent })
    }

    func testFilterTransactions_ReceivedOnly() {
        // Given
        setupMockTransactions()

        // When
        sut.selectedFilter = .received
        sut.applyFilter()

        // Then
        XCTAssertEqual(sut.filteredTransactions.count, 2)
        XCTAssertTrue(sut.filteredTransactions.allSatisfy { $0.type == .received })
    }

    func testFilterTransactions_Pending() {
        // Given
        setupMockTransactions()

        // When
        sut.selectedFilter = .pending
        sut.applyFilter()

        // Then
        XCTAssertEqual(sut.filteredTransactions.count, 1)
        XCTAssertTrue(sut.filteredTransactions.allSatisfy { $0.status == .pending })
    }

    // MARK: - Search Tests

    func testSearchTransactions_ByHash() {
        // Given
        setupMockTransactions()

        // When
        sut.searchQuery = "0xabc"
        sut.performSearch()

        // Then
        XCTAssertEqual(sut.filteredTransactions.count, 1)
        XCTAssertEqual(sut.filteredTransactions.first?.hash, "0xabc")
    }

    func testSearchTransactions_ByAddress() {
        // Given
        setupMockTransactions()

        // When
        sut.searchQuery = "0x123"
        sut.performSearch()

        // Then
        XCTAssertGreaterThan(sut.filteredTransactions.count, 0)
    }

    func testSearchTransactions_CaseInsensitive() {
        // Given
        setupMockTransactions()

        // When
        sut.searchQuery = "0XABC"
        sut.performSearch()

        // Then
        XCTAssertGreaterThan(sut.filteredTransactions.count, 0)
    }

    func testSearchTransactions_EmptyQuery() {
        // Given
        setupMockTransactions()

        // When
        sut.searchQuery = ""
        sut.performSearch()

        // Then
        XCTAssertEqual(sut.filteredTransactions.count, sut.transactions.count)
    }

    // MARK: - Sort Tests

    func testSortTransactions_ByDateDescending() {
        // Given
        setupMockTransactions()

        // When
        sut.sortOption = .dateDescending
        sut.applySorting()

        // Then
        XCTAssertTrue(isSortedByDateDescending(sut.filteredTransactions))
    }

    func testSortTransactions_ByDateAscending() {
        // Given
        setupMockTransactions()

        // When
        sut.sortOption = .dateAscending
        sut.applySorting()

        // Then
        XCTAssertTrue(isSortedByDateAscending(sut.filteredTransactions))
    }

    func testSortTransactions_ByAmountDescending() {
        // Given
        setupMockTransactions()

        // When
        sut.sortOption = .amountDescending
        sut.applySorting()

        // Then
        XCTAssertTrue(isSortedByAmountDescending(sut.filteredTransactions))
    }

    // MARK: - Refresh Tests

    func testRefreshTransactions_PullToRefresh() async {
        // Given
        setupMockTransactions()

        // When
        await sut.refreshTransactions()

        // Then
        XCTAssertFalse(sut.isRefreshing)
        XCTAssertGreaterThan(sut.transactions.count, 0)
    }

    // MARK: - Transaction Details Tests

    func testSelectTransaction_SetsSelectedTransaction() {
        // Given
        setupMockTransactions()
        let transaction = sut.transactions.first!

        // When
        sut.selectTransaction(transaction)

        // Then
        XCTAssertEqual(sut.selectedTransaction?.id, transaction.id)
    }

    func testDeselectTransaction_ClearsSelection() {
        // Given
        setupMockTransactions()
        sut.selectTransaction(sut.transactions.first!)

        // When
        sut.deselectTransaction()

        // Then
        XCTAssertNil(sut.selectedTransaction)
    }

    // MARK: - Pagination Tests

    func testLoadMoreTransactions_AppendsToList() async {
        // Given
        setupMockTransactions()
        let initialCount = sut.transactions.count

        mockTransactionService.mockTransactions = [
            Transaction(
                id: "tx5",
                hash: "0xnew",
                from: "0x999",
                to: "0x888",
                amount: Decimal(50000),
                timestamp: Date(),
                status: .confirmed,
                type: .sent
            )
        ]

        // When
        await sut.loadMoreTransactions()

        // Then
        XCTAssertGreaterThan(sut.transactions.count, initialCount)
    }

    func testLoadMoreTransactions_NoMoreAvailable() async {
        // Given
        sut.hasMoreTransactions = false
        let initialCount = sut.transactions.count

        // When
        await sut.loadMoreTransactions()

        // Then
        XCTAssertEqual(sut.transactions.count, initialCount)
    }

    // MARK: - Status Update Tests

    func testUpdateTransactionStatus_PendingToConfirmed() async {
        // Given
        let pendingTx = Transaction(
            id: "pending_tx",
            hash: "0xpending",
            from: "0x123",
            to: "0x456",
            amount: Decimal(100),
            timestamp: Date(),
            status: .pending,
            type: .sent
        )
        mockTransactionService.mockTransactions = [pendingTx]
        await sut.loadTransactions()

        // When
        mockTransactionService.updatedStatus = .confirmed
        await sut.updatePendingTransactions()

        // Then
        let updatedTx = sut.transactions.first(where: { $0.id == "pending_tx" })
        XCTAssertEqual(updatedTx?.status, .confirmed)
    }

    // MARK: - Export Tests

    func testExportTransactions_CSV() async {
        // Given
        setupMockTransactions()

        // When
        let csvData = await sut.exportToCSV()

        // Then
        XCTAssertNotNil(csvData)
        XCTAssertGreaterThan(csvData.count, 0)
    }

    // MARK: - Helper Methods

    private func setupMockTransactions() {
        sut.transactions = [
            Transaction(
                id: "tx1",
                hash: "0xabc",
                from: "0x123",
                to: "0x456",
                amount: Decimal(100000),
                timestamp: Date(),
                status: .confirmed,
                type: .sent
            ),
            Transaction(
                id: "tx2",
                hash: "0xdef",
                from: "0x789",
                to: "0x123",
                amount: Decimal(200000),
                timestamp: Date().addingTimeInterval(-3600),
                status: .confirmed,
                type: .received
            ),
            Transaction(
                id: "tx3",
                hash: "0xghi",
                from: "0x123",
                to: "0x999",
                amount: Decimal(50000),
                timestamp: Date().addingTimeInterval(-7200),
                status: .pending,
                type: .sent
            ),
            Transaction(
                id: "tx4",
                hash: "0xjkl",
                from: "0x888",
                to: "0x123",
                amount: Decimal(300000),
                timestamp: Date().addingTimeInterval(-10800),
                status: .confirmed,
                type: .received
            )
        ]
    }

    private func isSortedByDateDescending(_ transactions: [Transaction]) -> Bool {
        for i in 0..<(transactions.count - 1) {
            if transactions[i].timestamp < transactions[i + 1].timestamp {
                return false
            }
        }
        return true
    }

    private func isSortedByDateAscending(_ transactions: [Transaction]) -> Bool {
        for i in 0..<(transactions.count - 1) {
            if transactions[i].timestamp > transactions[i + 1].timestamp {
                return false
            }
        }
        return true
    }

    private func isSortedByAmountDescending(_ transactions: [Transaction]) -> Bool {
        for i in 0..<(transactions.count - 1) {
            if transactions[i].amount < transactions[i + 1].amount {
                return false
            }
        }
        return true
    }
}
