//
//  String+Localization.swift
//  FuekiWallet
//
//  String localization extensions for easy access
//

import Foundation

extension String {

    // MARK: - Localization

    /// Get localized string for current language
    var localized: String {
        LocalizationManager.shared.localized(self)
    }

    /// Get localized string with arguments
    /// - Parameter arguments: Format arguments
    /// - Returns: Localized formatted string
    func localized(with arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(self)
        return String(format: format, locale: LocalizationManager.shared.currentLocale, arguments: arguments)
    }

    /// Get localized string with plural support
    /// - Parameter count: Count for pluralization
    /// - Returns: Localized plural string
    func localizedPlural(count: Int) -> String {
        LocalizationManager.shared.localizedPlural(self, count: count)
    }

    // MARK: - Common Localizations

    static var ok: String { "common.ok".localized }
    static var cancel: String { "common.cancel".localized }
    static var done: String { "common.done".localized }
    static var close: String { "common.close".localized }
    static var save: String { "common.save".localized }
    static var delete: String { "common.delete".localized }
    static var edit: String { "common.edit".localized }
    static var continue_: String { "common.continue".localized }
    static var next: String { "common.next".localized }
    static var back: String { "common.back".localized }
    static var skip: String { "common.skip".localized }
    static var loading: String { "common.loading".localized }
    static var retry: String { "common.retry".localized }
    static var yes: String { "common.yes".localized }
    static var no: String { "common.no".localized }

    // MARK: - Error Messages

    static var errorTitle: String { "error.title".localized }
    static var errorNetworkTitle: String { "error.network.title".localized }
    static var errorNetworkMessage: String { "error.network.message".localized }
    static var errorUnknown: String { "error.unknown".localized }

    // MARK: - Wallet

    static var walletBalanceTitle: String { "wallet.balance.title".localized }
    static var walletSendButton: String { "wallet.send.button".localized }
    static var walletReceiveButton: String { "wallet.receive.button".localized }

    // MARK: - Transactions

    static var transactionPending: String { "transaction.status.pending".localized }
    static var transactionConfirmed: String { "transaction.status.confirmed".localized }
    static var transactionFailed: String { "transaction.status.failed".localized }
}

// MARK: - Localization Keys Namespace
enum L10n {

    // MARK: - Onboarding
    enum Onboarding {
        static let welcomeTitle = "onboarding.welcome.title"
        static let welcomeSubtitle = "onboarding.welcome.subtitle"
        static let createButton = "onboarding.create.button"
        static let importButton = "onboarding.import.button"
    }

    // MARK: - Wallet
    enum Wallet {
        static let balanceTitle = "wallet.balance.title"
        static let sendButton = "wallet.send.button"
        static let receiveButton = "wallet.receive.button"
        static let swapButton = "wallet.swap.button"

        enum Balance {
            static let available = "wallet.balance.available"
            static let locked = "wallet.balance.locked"
            static let hide = "wallet.balance.hide"
            static let show = "wallet.balance.show"
        }
    }

    // MARK: - Send
    enum Send {
        static let title = "send.title"
        static let recipientTitle = "send.recipient.title"
        static let amountTitle = "send.amount.title"
        static let feeTitle = "send.fee.title"
        static let confirmButton = "send.confirm.button"
        static let success = "send.success"

        enum Error {
            static let invalidAddress = "send.recipient.invalid"
            static let insufficientBalance = "send.amount.insufficient"
        }
    }

    // MARK: - Receive
    enum Receive {
        static let title = "receive.title"
        static let addressTitle = "receive.address.title"
        static let copyAddress = "receive.address.copy"
        static let addressCopied = "receive.address.copied"
    }

    // MARK: - Transaction
    enum Transaction {
        static let title = "transactions.title"
        static let empty = "transactions.empty"

        enum Status {
            static let pending = "transaction.status.pending"
            static let confirmed = "transaction.status.confirmed"
            static let failed = "transaction.status.failed"
        }

        enum Details {
            static let title = "transaction.details.title"
            static let hash = "transaction.details.hash"
            static let from = "transaction.details.from"
            static let to = "transaction.details.to"
            static let amount = "transaction.details.amount"
            static let fee = "transaction.details.fee"
            static let timestamp = "transaction.details.timestamp"
        }
    }

    // MARK: - Settings
    enum Settings {
        static let title = "settings.title"

        enum General {
            static let title = "settings.general.title"
            static let language = "settings.general.language"
            static let currency = "settings.general.currency"
            static let theme = "settings.general.theme"
        }

        enum Security {
            static let title = "settings.security.title"
            static let password = "settings.security.password"
            static let biometric = "settings.security.biometric"
            static let phrase = "settings.security.phrase"
        }
    }

    // MARK: - Error
    enum Error {
        static let title = "error.title"
        static let networkTitle = "error.network.title"
        static let networkMessage = "error.network.message"
        static let unknown = "error.unknown"
        static let retry = "error.retry"
    }
}

// MARK: - Helper Functions
extension String {
    /// Check if localization key exists
    var hasLocalization: Bool {
        let localized = LocalizationManager.shared.localized(self)
        return localized != self
    }

    /// Get localized string or fallback
    /// - Parameter fallback: Fallback string
    /// - Returns: Localized string or fallback
    func localizedOrFallback(_ fallback: String) -> String {
        let localized = self.localized
        return localized != self ? localized : fallback
    }
}
