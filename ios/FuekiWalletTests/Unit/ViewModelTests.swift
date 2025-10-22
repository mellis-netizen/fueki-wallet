import XCTest
import ComposableArchitecture
@testable import FuekiWallet

@MainActor
final class WalletViewModelTests: XCTestCase {

    // MARK: - Wallet List Tests

    func testWalletList_LoadWallets_Success() async {
        let store = TestStore(
            initialState: WalletListFeature.State(),
            reducer: { WalletListFeature() }
        )

        await store.send(.loadWallets) {
            $0.isLoading = true
        }

        await store.receive(.walletsLoaded([
            Wallet(id: "1", name: "Main Wallet", balance: 100000)
        ])) {
            $0.isLoading = false
            $0.wallets = [Wallet(id: "1", name: "Main Wallet", balance: 100000)]
        }
    }

    func testWalletList_SelectWallet_UpdatesSelection() async {
        let store = TestStore(
            initialState: WalletListFeature.State(
                wallets: [Wallet(id: "1", name: "Test", balance: 0)]
            ),
            reducer: { WalletListFeature() }
        )

        await store.send(.selectWallet("1")) {
            $0.selectedWalletID = "1"
        }
    }

    func testWalletList_DeleteWallet_RemovesFromList() async {
        let store = TestStore(
            initialState: WalletListFeature.State(
                wallets: [
                    Wallet(id: "1", name: "Wallet 1", balance: 0),
                    Wallet(id: "2", name: "Wallet 2", balance: 0)
                ]
            ),
            reducer: { WalletListFeature() }
        )

        await store.send(.deleteWallet("1")) {
            $0.wallets = [Wallet(id: "2", name: "Wallet 2", balance: 0)]
        }
    }

    // MARK: - Transaction List Tests

    func testTransactionList_LoadTransactions_Success() async {
        let store = TestStore(
            initialState: TransactionListFeature.State(),
            reducer: { TransactionListFeature() }
        )

        await store.send(.loadTransactions) {
            $0.isLoading = true
        }

        await store.receive(.transactionsLoaded([
            Transaction(id: "tx1", amount: 50000, type: .received)
        ])) {
            $0.isLoading = false
            $0.transactions = [Transaction(id: "tx1", amount: 50000, type: .received)]
        }
    }

    func testTransactionList_FilterByType_UpdatesList() async {
        let store = TestStore(
            initialState: TransactionListFeature.State(
                transactions: [
                    Transaction(id: "1", amount: 100, type: .sent),
                    Transaction(id: "2", amount: 200, type: .received)
                ]
            ),
            reducer: { TransactionListFeature() }
        )

        await store.send(.filterTransactions(.received)) {
            $0.filter = .received
            $0.filteredTransactions = [
                Transaction(id: "2", amount: 200, type: .received)
            ]
        }
    }

    // MARK: - Send Transaction Tests

    func testSendTransaction_ValidInput_Success() async {
        let store = TestStore(
            initialState: SendTransactionFeature.State(),
            reducer: { SendTransactionFeature() }
        )

        await store.send(.updateRecipient("tb1qtest123")) {
            $0.recipient = "tb1qtest123"
        }

        await store.send(.updateAmount("0.001")) {
            $0.amount = "0.001"
        }

        await store.send(.send) {
            $0.isSending = true
        }

        await store.receive(.sendCompleted(.success("txid123"))) {
            $0.isSending = false
            $0.transactionID = "txid123"
        }
    }

    func testSendTransaction_InvalidAddress_ShowsError() async {
        let store = TestStore(
            initialState: SendTransactionFeature.State(
                recipient: "invalid_address"
            ),
            reducer: { SendTransactionFeature() }
        )

        await store.send(.send)

        await store.receive(.sendCompleted(.failure(.invalidAddress))) {
            $0.error = "Invalid recipient address"
        }
    }

    func testSendTransaction_InsufficientBalance_ShowsError() async {
        let store = TestStore(
            initialState: SendTransactionFeature.State(
                recipient: "tb1qtest",
                amount: "10.0",
                availableBalance: 100000 // 0.001 BTC
            ),
            reducer: { SendTransactionFeature() }
        )

        await store.send(.send)

        await store.receive(.sendCompleted(.failure(.insufficientFunds))) {
            $0.error = "Insufficient balance"
        }
    }
}

@MainActor
final class OnboardingViewModelTests: XCTestCase {

    func testOnboarding_CreateNewWallet_Success() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(),
            reducer: { OnboardingFeature() }
        )

        await store.send(.selectOption(.createNew)) {
            $0.selectedOption = .createNew
        }

        await store.send(.setPassword("SecurePassword123!")) {
            $0.password = "SecurePassword123!"
        }

        await store.send(.confirmPassword("SecurePassword123!")) {
            $0.confirmPassword = "SecurePassword123!"
        }

        await store.send(.createWallet) {
            $0.isCreating = true
        }

        await store.receive(.walletCreated(.success("mnemonic words here"))) {
            $0.isCreating = false
            $0.mnemonic = "mnemonic words here"
        }
    }

    func testOnboarding_ImportWallet_Success() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(),
            reducer: { OnboardingFeature() }
        )

        await store.send(.selectOption(.importExisting)) {
            $0.selectedOption = .importExisting
        }

        let validMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        await store.send(.updateMnemonic(validMnemonic)) {
            $0.mnemonic = validMnemonic
        }

        await store.send(.importWallet) {
            $0.isImporting = true
        }

        await store.receive(.walletImported(.success("tb1qtest"))) {
            $0.isImporting = false
            $0.walletAddress = "tb1qtest"
        }
    }

    func testOnboarding_WeakPassword_ShowsError() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(),
            reducer: { OnboardingFeature() }
        )

        await store.send(.setPassword("123")) {
            $0.password = "123"
            $0.passwordError = "Password too weak"
        }
    }

    func testOnboarding_PasswordMismatch_ShowsError() async {
        let store = TestStore(
            initialState: OnboardingFeature.State(
                password: "SecurePassword123!",
                confirmPassword: "DifferentPassword"
            ),
            reducer: { OnboardingFeature() }
        )

        await store.send(.createWallet)

        await store.receive(.validationError("Passwords do not match")) {
            $0.error = "Passwords do not match"
        }
    }
}

@MainActor
final class SettingsViewModelTests: XCTestCase {

    func testSettings_ToggleBiometrics_Updates() async {
        let store = TestStore(
            initialState: SettingsFeature.State(),
            reducer: { SettingsFeature() }
        )

        await store.send(.toggleBiometrics) {
            $0.biometricsEnabled = true
        }

        await store.send(.toggleBiometrics) {
            $0.biometricsEnabled = false
        }
    }

    func testSettings_ChangeNetwork_Updates() async {
        let store = TestStore(
            initialState: SettingsFeature.State(network: .testnet),
            reducer: { SettingsFeature() }
        )

        await store.send(.changeNetwork(.mainnet)) {
            $0.network = .mainnet
        }
    }

    func testSettings_BackupWallet_Success() async {
        let store = TestStore(
            initialState: SettingsFeature.State(),
            reducer: { SettingsFeature() }
        )

        await store.send(.backupWallet) {
            $0.isBackingUp = true
        }

        await store.receive(.backupCompleted(.success("backup_data"))) {
            $0.isBackingUp = false
            $0.backupData = "backup_data"
        }
    }
}
