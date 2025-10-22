//
//  LocalizedStringKey+Extensions.swift
//  FuekiWallet
//
//  SwiftUI LocalizedStringKey extensions
//

import SwiftUI

extension LocalizedStringKey {

    // MARK: - Initialization

    /// Create LocalizedStringKey from L10n keys
    init(_ key: String) {
        self.init(stringLiteral: key)
    }

    // MARK: - Common Keys

    static var ok: LocalizedStringKey { LocalizedStringKey("common.ok") }
    static var cancel: LocalizedStringKey { LocalizedStringKey("common.cancel") }
    static var done: LocalizedStringKey { LocalizedStringKey("common.done") }
    static var close: LocalizedStringKey { LocalizedStringKey("common.close") }
    static var save: LocalizedStringKey { LocalizedStringKey("common.save") }
    static var delete: LocalizedStringKey { LocalizedStringKey("common.delete") }
    static var edit: LocalizedStringKey { LocalizedStringKey("common.edit") }
    static var loading: LocalizedStringKey { LocalizedStringKey("common.loading") }
}

// MARK: - Text Extensions
extension Text {

    /// Create Text with localized key
    /// - Parameter key: Localization key
    init(localized key: String) {
        self.init(LocalizedStringKey(key))
    }

    // MARK: - Formatted Text

    /// Create Text with formatted localization
    /// - Parameters:
    ///   - key: Localization key
    ///   - arguments: Format arguments
    static func localized(_ key: String, _ arguments: CVarArg...) -> Text {
        let format = LocalizationManager.shared.localized(key)
        let formatted = String(format: format, locale: LocalizationManager.shared.currentLocale, arguments: arguments)
        return Text(formatted)
    }

    // MARK: - Amount Formatting

    /// Format crypto amount with localization
    /// - Parameters:
    ///   - amount: Amount value
    ///   - symbol: Currency/token symbol
    /// - Returns: Formatted text
    static func amount(_ amount: Double, symbol: String) -> Text {
        let formatted = NumberFormatter.crypto.string(from: NSNumber(value: amount)) ?? "0"
        return Text("\(formatted) \(symbol)")
    }

    /// Format fiat currency amount
    /// - Parameter amount: Amount value
    /// - Returns: Formatted text
    static func currency(_ amount: Double) -> Text {
        let formatted = NumberFormatter.currency.string(from: NSNumber(value: amount)) ?? "$0.00"
        return Text(formatted)
    }

    /// Format percentage
    /// - Parameter value: Percentage value (0.1 = 10%)
    /// - Returns: Formatted text
    static func percentage(_ value: Double) -> Text {
        let formatted = NumberFormatter.percentage.string(from: NSNumber(value: value)) ?? "0%"
        return Text(formatted)
    }
}

// MARK: - Button Extensions
extension Button where Label == Text {

    /// Create button with localized text
    /// - Parameters:
    ///   - key: Localization key
    ///   - action: Button action
    init(localized key: String, action: @escaping () -> Void) {
        self.init(action: action) {
            Text(localized: key)
        }
    }
}

// MARK: - TextField Extensions
extension TextField where Label == Text {

    /// Create TextField with localized placeholder
    /// - Parameters:
    ///   - key: Localization key for placeholder
    ///   - text: Binding to text
    init(localized key: String, text: Binding<String>) {
        self.init(LocalizedStringKey(key), text: text)
    }
}

// MARK: - NavigationLink Extensions
extension NavigationLink where Label == Text {

    /// Create NavigationLink with localized text
    /// - Parameters:
    ///   - key: Localization key
    ///   - destination: Destination view
    init(localized key: String, @ViewBuilder destination: () -> Destination) {
        self.init(destination: destination) {
            Text(localized: key)
        }
    }
}

// MARK: - Label Extensions
extension Label where Title == Text, Icon == Image {

    /// Create Label with localized text
    /// - Parameters:
    ///   - key: Localization key
    ///   - systemImage: SF Symbol name
    init(localized key: String, systemImage: String) {
        self.init {
            Text(localized: key)
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

// MARK: - Alert Extensions
extension Alert {

    /// Create alert with localized strings
    /// - Parameters:
    ///   - titleKey: Title localization key
    ///   - messageKey: Message localization key
    /// - Returns: Alert
    static func localized(title titleKey: String, message messageKey: String) -> Alert {
        Alert(
            title: Text(localized: titleKey),
            message: Text(localized: messageKey)
        )
    }

    /// Create confirmation alert with localized strings
    /// - Parameters:
    ///   - titleKey: Title localization key
    ///   - messageKey: Message localization key
    ///   - confirmKey: Confirm button localization key
    ///   - confirmAction: Confirm action
    /// - Returns: Alert
    static func confirmationLocalized(
        title titleKey: String,
        message messageKey: String,
        confirmKey: String = "common.ok",
        confirmAction: @escaping () -> Void
    ) -> Alert {
        Alert(
            title: Text(localized: titleKey),
            message: Text(localized: messageKey),
            primaryButton: .default(Text(localized: confirmKey), action: confirmAction),
            secondaryButton: .cancel(Text.cancel)
        )
    }

    /// Create error alert with localized strings
    /// - Parameters:
    ///   - messageKey: Message localization key
    ///   - dismissKey: Dismiss button localization key
    /// - Returns: Alert
    static func errorLocalized(
        message messageKey: String,
        dismissKey: String = "common.ok"
    ) -> Alert {
        Alert(
            title: Text(localized: "error.title"),
            message: Text(localized: messageKey),
            dismissButton: .default(Text(localized: dismissKey))
        )
    }
}
