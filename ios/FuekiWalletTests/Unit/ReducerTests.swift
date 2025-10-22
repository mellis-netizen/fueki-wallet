import XCTest
import ComposableArchitecture
@testable import FuekiWallet

@MainActor
final class AppReducerTests: XCTestCase {

    func testAppLaunch_LoadsInitialState() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        await store.send(.appLaunched) {
            $0.isLoading = true
        }

        await store.receive(.loadingCompleted) {
            $0.isLoading = false
            $0.hasCompletedOnboarding = false
        }
    }

    func testNavigation_ToWalletDetail_UpdatesState() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        await store.send(.navigateToWalletDetail("wallet1")) {
            $0.selectedWalletID = "wallet1"
            $0.currentScreen = .walletDetail
        }
    }

    func testLogout_ClearsState() async {
        let store = TestStore(
            initialState: AppFeature.State(
                isAuthenticated: true,
                selectedWalletID: "wallet1"
            ),
            reducer: { AppFeature() }
        )

        await store.send(.logout) {
            $0.isAuthenticated = false
            $0.selectedWalletID = nil
            $0.currentScreen = .onboarding
        }
    }
}

@MainActor
final class WalletReducerTests: XCTestCase {

    func testWalletReducer_CreateWallet_UpdatesState() async {
        let store = TestStore(
            initialState: WalletFeature.State(),
            reducer: { WalletFeature() }
        )

        await store.send(.createWallet("password123")) {
            $0.isCreating = true
        }

        await store.receive(.walletCreated(.success(
            WalletInfo(address: "tb1qtest", mnemonic: "test mnemonic")
        ))) {
            $0.isCreating = false
            $0.walletAddress = "tb1qtest"
            $0.isUnlocked = true
        }
    }

    func testWalletReducer_LockWallet_UpdatesState() async {
        let store = TestStore(
            initialState: WalletFeature.State(isUnlocked: true),
            reducer: { WalletFeature() }
        )

        await store.send(.lockWallet) {
            $0.isUnlocked = false
        }
    }

    func testWalletReducer_UnlockWallet_Success() async {
        let store = TestStore(
            initialState: WalletFeature.State(isUnlocked: false),
            reducer: { WalletFeature() }
        )

        await store.send(.unlockWallet("correct_password")) {
            $0.isUnlocking = true
        }

        await store.receive(.unlockCompleted(.success(true))) {
            $0.isUnlocking = false
            $0.isUnlocked = true
        }
    }

    func testWalletReducer_UnlockWallet_Failure() async {
        let store = TestStore(
            initialState: WalletFeature.State(isUnlocked: false),
            reducer: { WalletFeature() }
        )

        await store.send(.unlockWallet("wrong_password")) {
            $0.isUnlocking = true
        }

        await store.receive(.unlockCompleted(.failure(.incorrectPassword))) {
            $0.isUnlocking = false
            $0.isUnlocked = false
            $0.error = "Incorrect password"
        }
    }

    func testWalletReducer_RefreshBalance_UpdatesBalance() async {
        let store = TestStore(
            initialState: WalletFeature.State(
                isUnlocked: true,
                balance: 0
            ),
            reducer: { WalletFeature() }
        )

        await store.send(.refreshBalance) {
            $0.isRefreshing = true
        }

        await store.receive(.balanceUpdated(100000)) {
            $0.isRefreshing = false
            $0.balance = 100000
        }
    }
}

@MainActor
final class TransactionReducerTests: XCTestCase {

    func testTransactionReducer_SendTransaction_Success() async {
        let store = TestStore(
            initialState: TransactionFeature.State(),
            reducer: { TransactionFeature() }
        )

        await store.send(.sendTransaction(
            recipient: "tb1qtest",
            amount: 50000,
            fee: 1000
        )) {
            $0.isSending = true
        }

        await store.receive(.transactionSent(.success("txid123"))) {
            $0.isSending = false
            $0.lastTransactionID = "txid123"
        }
    }

    func testTransactionReducer_SendTransaction_Failure() async {
        let store = TestStore(
            initialState: TransactionFeature.State(),
            reducer: { TransactionFeature() }
        )

        await store.send(.sendTransaction(
            recipient: "invalid",
            amount: 50000,
            fee: 1000
        )) {
            $0.isSending = true
        }

        await store.receive(.transactionSent(.failure(.invalidAddress))) {
            $0.isSending = false
            $0.error = "Invalid address"
        }
    }

    func testTransactionReducer_LoadHistory_UpdatesList() async {
        let store = TestStore(
            initialState: TransactionFeature.State(),
            reducer: { TransactionFeature() }
        )

        await store.send(.loadHistory) {
            $0.isLoadingHistory = true
        }

        let mockTransactions = [
            Transaction(id: "tx1", amount: 100, type: .received),
            Transaction(id: "tx2", amount: 50, type: .sent)
        ]

        await store.receive(.historyLoaded(mockTransactions)) {
            $0.isLoadingHistory = false
            $0.transactions = mockTransactions
        }
    }
}

@MainActor
final class SecurityReducerTests: XCTestCase {

    func testSecurityReducer_EnableBiometrics_UpdatesState() async {
        let store = TestStore(
            initialState: SecurityFeature.State(),
            reducer: { SecurityFeature() }
        )

        await store.send(.enableBiometrics) {
            $0.isEnablingBiometrics = true
        }

        await store.receive(.biometricsEnabled(.success(true))) {
            $0.isEnablingBiometrics = false
            $0.biometricsEnabled = true
        }
    }

    func testSecurityReducer_ChangePassword_Success() async {
        let store = TestStore(
            initialState: SecurityFeature.State(),
            reducer: { SecurityFeature() }
        )

        await store.send(.changePassword(
            current: "old_password",
            new: "new_password"
        )) {
            $0.isChangingPassword = true
        }

        await store.receive(.passwordChanged(.success(true))) {
            $0.isChangingPassword = false
        }
    }

    func testSecurityReducer_BiometricAuthentication_Success() async {
        let store = TestStore(
            initialState: SecurityFeature.State(biometricsEnabled: true),
            reducer: { SecurityFeature() }
        )

        await store.send(.authenticateWithBiometrics) {
            $0.isAuthenticating = true
        }

        await store.receive(.biometricAuthenticationCompleted(.success(true))) {
            $0.isAuthenticating = false
            $0.isAuthenticated = true
        }
    }
}

@MainActor
final class ReducerCompositionTests: XCTestCase {

    func testComposedReducers_InteractCorrectly() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        // Test wallet and transaction interaction
        await store.send(.wallet(.createWallet("password")))
        await store.receive(.wallet(.walletCreated(.success(
            WalletInfo(address: "tb1qtest", mnemonic: "mnemonic")
        ))))

        await store.send(.transaction(.loadHistory))
        await store.receive(.transaction(.historyLoaded([])))
    }

    func testStateSharing_BetweenReducers() async {
        let store = TestStore(
            initialState: AppFeature.State(),
            reducer: { AppFeature() }
        )

        // Unlock wallet in wallet reducer
        await store.send(.wallet(.unlockWallet("password")))
        await store.receive(.wallet(.unlockCompleted(.success(true))))

        // Should be able to access wallet state in transaction reducer
        await store.send(.transaction(.sendTransaction(
            recipient: "tb1qtest",
            amount: 1000,
            fee: 100
        )))
    }
}
