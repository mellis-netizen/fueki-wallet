//
//  AccountViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel managing account operations and multi-account support
@MainActor
final class AccountViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var accounts: [WalletAccount] = []
    @Published var selectedAccount: WalletAccount?
    @Published var isLoadingAccounts = false

    // MARK: - Account Creation

    @Published var newAccountName = ""
    @Published var showCreateAccount = false
    @Published var accountType: AccountType = .standard
    @Published var derivationPath: String = ""
    @Published var customDerivationEnabled = false

    // MARK: - Account Management

    @Published var showRenameDialog = false
    @Published var accountToRename: WalletAccount?
    @Published var newName = ""

    @Published var showDeleteConfirmation = false
    @Published var accountToDelete: WalletAccount?

    // MARK: - Account Details

    @Published var accountBalance: Decimal = 0
    @Published var accountAssets: [Asset] = []
    @Published var accountTransactions: [TransactionRecord] = []
    @Published var isLoadingDetails = false

    // MARK: - Export/Backup

    @Published var showExportOptions = false
    @Published var showPrivateKey = false
    @Published var privateKeyRevealed = ""
    @Published var showSeedPhrase = false
    @Published var seedPhraseWords: [String] = []

    // MARK: - Import

    @Published var showImportOptions = false
    @Published var importMethod: ImportMethod = .seedPhrase
    @Published var importData = ""
    @Published var isImporting = false

    // MARK: - Watch-Only Accounts

    @Published var watchOnlyAccounts: [WatchOnlyAccount] = []
    @Published var showAddWatchAccount = false
    @Published var watchAddress = ""
    @Published var watchAccountName = ""

    // MARK: - UI State

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var successMessage: String?
    @Published var showSuccess = false

    // MARK: - Sort & Filter

    @Published var sortOption: AccountSortOption = .createdDate
    @Published var filterOption: AccountFilterOption = .all
    @Published var searchQuery = ""

    // MARK: - Dependencies

    private let accountService: AccountServiceProtocol
    private let walletService: WalletServiceProtocol
    private let backupService: BackupServiceProtocol
    private let securityService: SecurityServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        accountService: AccountServiceProtocol = AccountService.shared,
        walletService: WalletServiceProtocol = WalletService.shared,
        backupService: BackupServiceProtocol = BackupService.shared,
        securityService: SecurityServiceProtocol = SecurityService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.accountService = accountService
        self.walletService = walletService
        self.backupService = backupService
        self.securityService = securityService
        self.walletViewModel = walletViewModel
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Monitor success state
        $successMessage
            .map { $0 != nil }
            .assign(to: &$showSuccess)

        // Auto-generate derivation path
        $accountType
            .combineLatest($accounts)
            .map { [weak self] type, accounts in
                self?.generateDerivationPath(for: type, accountIndex: accounts.count) ?? ""
            }
            .assign(to: &$derivationPath)

        // Watch account selection
        $selectedAccount
            .dropFirst()
            .sink { [weak self] account in
                guard let account = account else { return }
                Task { await self?.loadAccountDetails(account) }
            }
            .store(in: &cancellables)

        // Sort and filter accounts
        Publishers.CombineLatest3($accounts, $sortOption, $filterOption)
            .combineLatest($searchQuery)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] combined, search in
                let (accounts, sort, filter) = combined
                self?.accounts = self?.sortAndFilter(
                    accounts: accounts,
                    sort: sort,
                    filter: filter,
                    search: search
                ) ?? []
            }
            .store(in: &cancellables)
    }

    // MARK: - Account Loading

    func loadAccounts() async {
        isLoadingAccounts = true
        errorMessage = nil

        do {
            let loadedAccounts = try await accountService.fetchAccounts()
            accounts = loadedAccounts

            // Load watch-only accounts
            watchOnlyAccounts = try await accountService.fetchWatchOnlyAccounts()

            // Set selected account if none selected
            if selectedAccount == nil, let first = loadedAccounts.first {
                selectedAccount = first
            }
        } catch {
            errorMessage = "Failed to load accounts: \(error.localizedDescription)"
        }

        isLoadingAccounts = false
    }

    func loadAccountDetails(_ account: WalletAccount) async {
        isLoadingDetails = true

        do {
            // Load balance
            let balance = try await accountService.fetchBalance(for: account)
            accountBalance = balance.total

            // Load assets
            accountAssets = try await accountService.fetchAssets(for: account)

            // Load recent transactions
            accountTransactions = try await accountService.fetchRecentTransactions(
                for: account,
                limit: 10
            )
        } catch {
            errorMessage = "Failed to load account details: \(error.localizedDescription)"
        }

        isLoadingDetails = false
    }

    // MARK: - Account Creation

    func createAccount() async -> Bool {
        guard !newAccountName.isEmpty else {
            errorMessage = "Account name is required"
            return false
        }

        isLoading = true
        errorMessage = nil

        do {
            let path = customDerivationEnabled ? derivationPath : generateDerivationPath(
                for: accountType,
                accountIndex: accounts.count
            )

            let account = try await accountService.createAccount(
                name: newAccountName,
                type: accountType,
                derivationPath: path
            )

            accounts.append(account)
            selectedAccount = account

            successMessage = "Account '\(newAccountName)' created successfully"
            resetCreateForm()

            return true
        } catch {
            errorMessage = "Failed to create account: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    private func generateDerivationPath(for type: AccountType, accountIndex: Int) -> String {
        switch type {
        case .standard:
            return "m/44'/60'/0'/0/\(accountIndex)"
        case .legacy:
            return "m/44'/60'/\(accountIndex)'/0/0"
        case .ledgerLive:
            return "m/44'/60'/\(accountIndex)'/0/0"
        case .custom:
            return ""
        }
    }

    func validateDerivationPath(_ path: String) -> Bool {
        let pattern = "^m(/[0-9]+'?)+$"
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(path.startIndex..., in: path)
        return regex?.firstMatch(in: path, options: [], range: range) != nil
    }

    // MARK: - Account Management

    func renameAccount() async -> Bool {
        guard let account = accountToRename, !newName.isEmpty else {
            errorMessage = "Invalid account or name"
            return false
        }

        isLoading = true

        do {
            try await accountService.renameAccount(account, to: newName)

            if let index = accounts.firstIndex(where: { $0.id == account.id }) {
                accounts[index].name = newName
            }

            successMessage = "Account renamed successfully"
            showRenameDialog = false
            accountToRename = nil
            newName = ""

            return true
        } catch {
            errorMessage = "Failed to rename account: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func deleteAccount() async -> Bool {
        guard let account = accountToDelete else {
            errorMessage = "No account selected for deletion"
            return false
        }

        // Prevent deletion of last account
        guard accounts.count > 1 else {
            errorMessage = "Cannot delete the last account"
            return false
        }

        isLoading = true

        do {
            try await accountService.deleteAccount(account)

            accounts.removeAll { $0.id == account.id }

            // Select another account if we deleted the selected one
            if selectedAccount?.id == account.id {
                selectedAccount = accounts.first
            }

            successMessage = "Account deleted successfully"
            showDeleteConfirmation = false
            accountToDelete = nil

            return true
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func setActiveAccount(_ account: WalletAccount) async {
        selectedAccount = account

        do {
            try await accountService.setActiveAccount(account)
            await loadAccountDetails(account)
        } catch {
            errorMessage = "Failed to set active account: \(error.localizedDescription)"
        }
    }

    // MARK: - Export & Backup

    func exportPrivateKey(for account: WalletAccount) async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            // Require biometric authentication
            let authenticated = try await securityService.authenticateUser(
                reason: "Authenticate to view private key"
            )

            guard authenticated else {
                errorMessage = "Authentication required to export private key"
                return false
            }

            let privateKey = try await accountService.exportPrivateKey(for: account)
            privateKeyRevealed = privateKey
            showPrivateKey = true

            return true
        } catch {
            errorMessage = "Failed to export private key: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func exportSeedPhrase() async -> Bool {
        isLoading = true
        errorMessage = nil

        do {
            // Require biometric authentication
            let authenticated = try await securityService.authenticateUser(
                reason: "Authenticate to view seed phrase"
            )

            guard authenticated else {
                errorMessage = "Authentication required to export seed phrase"
                return false
            }

            let mnemonic = try await backupService.exportMnemonic()
            seedPhraseWords = mnemonic.components(separatedBy: " ")
            showSeedPhrase = true

            return true
        } catch {
            errorMessage = "Failed to export seed phrase: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func createBackup() async -> URL? {
        do {
            let backupURL = try await backupService.createEncryptedBackup(
                accounts: accounts
            )

            successMessage = "Backup created successfully"
            return backupURL
        } catch {
            errorMessage = "Failed to create backup: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Import

    func importAccount() async -> Bool {
        guard !importData.isEmpty else {
            errorMessage = "Import data is required"
            return false
        }

        isImporting = true
        errorMessage = nil

        do {
            let account: WalletAccount

            switch importMethod {
            case .seedPhrase:
                account = try await accountService.importFromMnemonic(importData)
            case .privateKey:
                account = try await accountService.importFromPrivateKey(importData)
            case .json:
                account = try await accountService.importFromJSON(importData)
            }

            accounts.append(account)
            selectedAccount = account

            successMessage = "Account imported successfully"
            showImportOptions = false
            importData = ""

            return true
        } catch {
            errorMessage = "Failed to import account: \(error.localizedDescription)"
            return false
        }

        isImporting = false
    }

    // MARK: - Watch-Only Accounts

    func addWatchOnlyAccount() async -> Bool {
        guard !watchAddress.isEmpty, !watchAccountName.isEmpty else {
            errorMessage = "Address and name are required"
            return false
        }

        isLoading = true

        do {
            let watchAccount = try await accountService.addWatchOnlyAccount(
                address: watchAddress,
                name: watchAccountName
            )

            watchOnlyAccounts.append(watchAccount)

            successMessage = "Watch-only account added"
            showAddWatchAccount = false
            watchAddress = ""
            watchAccountName = ""

            return true
        } catch {
            errorMessage = "Failed to add watch account: \(error.localizedDescription)"
            return false
        }

        isLoading = false
    }

    func removeWatchOnlyAccount(_ account: WatchOnlyAccount) async {
        do {
            try await accountService.removeWatchOnlyAccount(account)
            watchOnlyAccounts.removeAll { $0.id == account.id }
            successMessage = "Watch-only account removed"
        } catch {
            errorMessage = "Failed to remove watch account: \(error.localizedDescription)"
        }
    }

    // MARK: - Sort & Filter

    private func sortAndFilter(
        accounts: [WalletAccount],
        sort: AccountSortOption,
        filter: AccountFilterOption,
        search: String
    ) -> [WalletAccount] {
        var filtered = accounts

        // Apply filter
        switch filter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.id == selectedAccount?.id }
        case .hasBalance:
            filtered = filtered.filter { $0.balance.amount > 0 }
        }

        // Apply search
        if !search.isEmpty {
            filtered = filtered.filter { account in
                account.name.localizedCaseInsensitiveContains(search) ||
                account.address.localizedCaseInsensitiveContains(search)
            }
        }

        // Apply sort
        switch sort {
        case .name:
            filtered.sort { $0.name < $1.name }
        case .balance:
            filtered.sort { $0.balance.amount > $1.balance.amount }
        case .createdDate:
            filtered.sort { $0.createdAt > $1.createdAt }
        case .lastUsed:
            filtered.sort { $0.lastUsed > $1.lastUsed }
        }

        return filtered
    }

    // MARK: - Helpers

    private func resetCreateForm() {
        newAccountName = ""
        accountType = .standard
        customDerivationEnabled = false
        showCreateAccount = false
    }

    func copyAddress(_ address: String) {
        UIPasteboard.general.string = address
        successMessage = "Address copied to clipboard"
    }

    // MARK: - Computed Properties

    var totalBalance: Decimal {
        accounts.reduce(0) { $0 + $1.balance.amount }
    }

    var accountCount: Int {
        accounts.count
    }

    var watchAccountCount: Int {
        watchOnlyAccounts.count
    }

    var formattedTotalBalance: String {
        formatCurrency(totalBalance)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "$0.00"
    }
}

// MARK: - Supporting Types

enum AccountType: String, CaseIterable {
    case standard = "Standard (BIP44)"
    case legacy = "Legacy"
    case ledgerLive = "Ledger Live"
    case custom = "Custom Path"
}

enum ImportMethod: String, CaseIterable {
    case seedPhrase = "Seed Phrase"
    case privateKey = "Private Key"
    case json = "JSON Keystore"
}

enum AccountSortOption: String, CaseIterable {
    case name = "Name"
    case balance = "Balance"
    case createdDate = "Created Date"
    case lastUsed = "Last Used"
}

enum AccountFilterOption: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case hasBalance = "Has Balance"
}

struct WatchOnlyAccount: Identifiable, Codable {
    let id: String
    var name: String
    let address: String
    var balance: Balance
    let addedAt: Date
}

// MARK: - Service Protocols

protocol AccountServiceProtocol {
    func fetchAccounts() async throws -> [WalletAccount]
    func fetchWatchOnlyAccounts() async throws -> [WatchOnlyAccount]
    func fetchBalance(for account: WalletAccount) async throws -> WalletBalance
    func fetchAssets(for account: WalletAccount) async throws -> [Asset]
    func fetchRecentTransactions(for account: WalletAccount, limit: Int) async throws -> [TransactionRecord]

    func createAccount(name: String, type: AccountType, derivationPath: String) async throws -> WalletAccount
    func importFromMnemonic(_ mnemonic: String) async throws -> WalletAccount
    func importFromPrivateKey(_ privateKey: String) async throws -> WalletAccount
    func importFromJSON(_ json: String) async throws -> WalletAccount

    func renameAccount(_ account: WalletAccount, to name: String) async throws
    func deleteAccount(_ account: WalletAccount) async throws
    func setActiveAccount(_ account: WalletAccount) async throws

    func exportPrivateKey(for account: WalletAccount) async throws -> String

    func addWatchOnlyAccount(address: String, name: String) async throws -> WatchOnlyAccount
    func removeWatchOnlyAccount(_ account: WatchOnlyAccount) async throws
}

protocol BackupServiceProtocol {
    func exportMnemonic() async throws -> String
    func createEncryptedBackup(accounts: [WalletAccount]) async throws -> URL
}

protocol SecurityServiceProtocol {
    func authenticateUser(reason: String) async throws -> Bool
}
