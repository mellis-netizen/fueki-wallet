//
//  StateManagementTests.swift
//  Fueki Wallet Tests
//
//  Comprehensive tests for state management system
//

import XCTest
import Combine
@testable import Fueki_Wallet

@MainActor
class StateManagementTests: XCTestCase {
    var appState: AppState!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        try await super.setUp()
        appState = AppState.shared
        cancellables = Set<AnyCancellable>()
        await appState.resetState()
    }

    override func tearDown() async throws {
        cancellables = nil
        await appState.resetState()
        try await super.tearDown()
    }

    // MARK: - AppState Tests

    func testAppStateInitialization() async throws {
        XCTAssertEqual(appState.connectionState, .unknown)
        XCTAssertEqual(appState.syncState, .idle)
        XCTAssertNil(appState.errorState)
        XCTAssertEqual(appState.loadingState, .idle)
    }

    func testAppStateConnectionStateChange() async throws {
        appState.updateConnectionState(.online)
        XCTAssertEqual(appState.connectionState, .online)

        appState.updateConnectionState(.offline)
        XCTAssertEqual(appState.connectionState, .offline)
    }

    func testAppStateErrorHandling() async throws {
        let error = StateError.networkError("Test error")
        appState.handleError(error)

        XCTAssertNotNil(appState.errorState)
        XCTAssertEqual(appState.errorState?.error.localizedDescription, error.localizedDescription)

        appState.clearError()
        XCTAssertNil(appState.errorState)
    }

    // MARK: - AuthState Tests

    func testAuthStateLogin() async throws {
        let user = User(id: "123", name: "Test User", email: "test@example.com")
        let token = "test_token"

        appState.authState.login(user: user, token: token, method: .email)

        XCTAssertTrue(appState.authState.isAuthenticated)
        XCTAssertEqual(appState.authState.currentUser?.id, user.id)
        XCTAssertEqual(appState.authState.sessionToken, token)
        XCTAssertEqual(appState.authState.authMethod, .email)
    }

    func testAuthStateLogout() async throws {
        let user = User(id: "123", name: "Test User", email: "test@example.com")
        appState.authState.login(user: user, token: "token", method: .email)

        appState.authState.logout()

        XCTAssertFalse(appState.authState.isAuthenticated)
        XCTAssertNil(appState.authState.currentUser)
        XCTAssertNil(appState.authState.sessionToken)
    }

    func testAuthStateSessionRefresh() async throws {
        let user = User(id: "123", name: "Test User", email: "test@example.com")
        appState.authState.login(user: user, token: "old_token", method: .email)

        let newToken = "new_token"
        appState.authState.refreshSession(token: newToken)

        XCTAssertEqual(appState.authState.sessionToken, newToken)
        XCTAssertTrue(appState.authState.isAuthenticated)
    }

    // MARK: - WalletState Tests

    func testWalletStateAddWallet() async throws {
        let wallet = Wallet(name: "Test Wallet", assets: [])

        appState.walletState.addWallet(wallet)

        XCTAssertEqual(appState.walletState.wallets.count, 1)
        XCTAssertEqual(appState.walletState.activeWallet?.id, wallet.id)
    }

    func testWalletStateRemoveWallet() async throws {
        let wallet1 = Wallet(name: "Wallet 1", assets: [])
        let wallet2 = Wallet(name: "Wallet 2", assets: [])

        appState.walletState.addWallet(wallet1)
        appState.walletState.addWallet(wallet2)

        appState.walletState.removeWallet(wallet1.id)

        XCTAssertEqual(appState.walletState.wallets.count, 1)
        XCTAssertEqual(appState.walletState.activeWallet?.id, wallet2.id)
    }

    func testWalletStateBalanceUpdate() async throws {
        let asset = CryptoAsset(
            id: "btc",
            name: "Bitcoin",
            symbol: "BTC",
            chain: .bitcoin,
            contractAddress: nil,
            decimals: 8,
            iconURL: nil
        )

        let balance = Balance(
            amount: Decimal(1.5),
            asset: asset,
            fiatPrice: Decimal(50000)
        )

        appState.walletState.updateBalance(assetId: "btc", balance: balance)

        XCTAssertNotNil(appState.walletState.balances["btc"])
        XCTAssertEqual(appState.walletState.balances["btc"]?.amount, Decimal(1.5))
    }

    // MARK: - TransactionState Tests

    func testTransactionStateAddTransaction() async throws {
        let asset = CryptoAsset(
            id: "eth",
            name: "Ethereum",
            symbol: "ETH",
            chain: .ethereum,
            contractAddress: nil,
            decimals: 18,
            iconURL: nil
        )

        let transaction = Transaction(
            id: "tx1",
            hash: "0x123",
            type: .send,
            status: .pending,
            asset: asset,
            amount: Decimal(1.0),
            fromAddress: "0xabc",
            toAddress: "0xdef",
            timestamp: Date()
        )

        appState.transactionState.addTransaction(transaction)

        XCTAssertEqual(appState.transactionState.transactions.count, 1)
        XCTAssertEqual(appState.transactionState.pendingTransactions.count, 1)
    }

    func testTransactionStateUpdateTransaction() async throws {
        let asset = CryptoAsset(
            id: "eth",
            name: "Ethereum",
            symbol: "ETH",
            chain: .ethereum,
            contractAddress: nil,
            decimals: 18,
            iconURL: nil
        )

        var transaction = Transaction(
            id: "tx1",
            hash: "0x123",
            type: .send,
            status: .pending,
            asset: asset,
            amount: Decimal(1.0),
            fromAddress: "0xabc",
            toAddress: "0xdef",
            timestamp: Date()
        )

        appState.transactionState.addTransaction(transaction)

        transaction.status = .confirmed
        transaction.confirmations = 6

        appState.transactionState.updateTransaction(transaction)

        XCTAssertEqual(appState.transactionState.pendingTransactions.count, 0)
        XCTAssertEqual(appState.transactionState.transactions[0].status, .confirmed)
    }

    func testTransactionStateFiltering() async throws {
        let btc = CryptoAsset(id: "btc", name: "Bitcoin", symbol: "BTC", chain: .bitcoin, contractAddress: nil, decimals: 8, iconURL: nil)
        let eth = CryptoAsset(id: "eth", name: "Ethereum", symbol: "ETH", chain: .ethereum, contractAddress: nil, decimals: 18, iconURL: nil)

        let tx1 = Transaction(id: "tx1", hash: "0x1", type: .send, status: .confirmed, asset: btc, amount: 1, fromAddress: "a", toAddress: "b", timestamp: Date())
        let tx2 = Transaction(id: "tx2", hash: "0x2", type: .receive, status: .pending, asset: eth, amount: 2, fromAddress: "c", toAddress: "d", timestamp: Date())

        appState.transactionState.addTransaction(tx1)
        appState.transactionState.addTransaction(tx2)

        let btcTransactions = appState.transactionState.getTransactions(for: "btc")
        XCTAssertEqual(btcTransactions.count, 1)

        let pendingTransactions = appState.transactionState.getTransactions(status: .pending)
        XCTAssertEqual(pendingTransactions.count, 1)
    }

    // MARK: - SettingsState Tests

    func testSettingsStateCurrencyChange() async throws {
        appState.settingsState.updateCurrency(.eur)
        XCTAssertEqual(appState.settingsState.currency, .eur)
    }

    func testSettingsStateThemeChange() async throws {
        appState.settingsState.updateTheme(.dark)
        XCTAssertEqual(appState.settingsState.theme, .dark)
    }

    func testSettingsStateSecuritySettings() async throws {
        appState.settingsState.updateSecuritySettings(
            requireBiometric: true,
            requireConfirmation: true,
            maxAmount: Decimal(1000)
        )

        XCTAssertTrue(appState.settingsState.requireBiometricForTransactions)
        XCTAssertTrue(appState.settingsState.transactionConfirmationEnabled)
        XCTAssertEqual(appState.settingsState.maxTransactionAmount, Decimal(1000))
    }

    // MARK: - State Persistence Tests

    func testStatePersistence() async throws {
        let user = User(id: "123", name: "Test", email: "test@example.com")
        appState.authState.login(user: user, token: "token", method: .email)

        try await appState.persistState()

        await appState.resetState()
        XCTAssertFalse(appState.authState.isAuthenticated)

        await appState.restoreState()
        // Note: Restored state would need actual persistence implementation
    }

    // MARK: - State Sync Tests

    func testStateSyncQueue() async throws {
        let operation = SyncOperation(type: .createTransaction, data: ["test": "data"])

        StateSync.shared.queueOperation(operation)

        // Verify operation was queued (would need actual implementation)
    }

    // MARK: - State Recovery Tests

    func testStateRecovery() async throws {
        let result = await StateRecovery.shared.validateStateIntegrity()

        switch result {
        case .valid:
            XCTAssertTrue(true)
        case .invalid(let issues):
            XCTFail("State integrity issues: \(issues.joined(separator: ", "))")
        }
    }

    // MARK: - Performance Tests

    func testStateUpdatePerformance() async throws {
        measure {
            for i in 0..<100 {
                let wallet = Wallet(name: "Wallet \(i)", assets: [])
                appState.walletState.addWallet(wallet)
            }
        }
    }

    func testTransactionHistoryPerformance() async throws {
        let asset = CryptoAsset(id: "btc", name: "Bitcoin", symbol: "BTC", chain: .bitcoin, contractAddress: nil, decimals: 8, iconURL: nil)

        measure {
            for i in 0..<1000 {
                let tx = Transaction(
                    id: "tx\(i)",
                    hash: "0x\(i)",
                    type: .send,
                    status: .confirmed,
                    asset: asset,
                    amount: Decimal(i),
                    fromAddress: "from",
                    toAddress: "to",
                    timestamp: Date()
                )
                appState.transactionState.addTransaction(tx)
            }
        }
    }
}
