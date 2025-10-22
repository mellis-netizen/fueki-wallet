//
//  NumberFormatters.swift
//  FuekiWallet
//
//  Number formatting for currency and crypto amounts
//

import Foundation

extension NumberFormatter {

    // MARK: - Crypto Formatters

    /// Formatter for cryptocurrency amounts (up to 8 decimals)
    static let crypto: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 8
        formatter.minimumIntegerDigits = 1
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = true
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Formatter for cryptocurrency with 2 decimals
    static let cryptoShort: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.minimumIntegerDigits = 1
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = true
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Formatter for full precision crypto (18 decimals for tokens)
    static let cryptoFull: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 18
        formatter.minimumIntegerDigits = 1
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        formatter.usesGroupingSeparator = true
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    // MARK: - Fiat Currency Formatters

    /// Formatter for fiat currency (USD, EUR, etc.)
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "app.currency") ?? "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Formatter for compact currency (K, M, B suffixes)
    static let currencyCompact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = UserDefaults.standard.string(forKey: "app.currency") ?? "USD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.currentLocale

        // Add compact notation for iOS 15+
        if #available(iOS 15.0, *) {
            formatter.formatWidth = .abbreviated
        }
        return formatter
    }()

    // MARK: - Percentage Formatters

    /// Formatter for percentage (0.1 = 10%)
    static let percentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 100
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Formatter for percentage with sign (+/-)
    static let percentageWithSign: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.multiplier = 100
        formatter.positivePrefix = "+"
        formatter.negativePrefix = "-"
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    // MARK: - Utility Formatters

    /// Formatter for whole numbers with grouping
    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        formatter.usesGroupingSeparator = true
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    /// Formatter for file sizes
    static let fileSize: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = LocalizationManager.shared.currentLocale
        return formatter
    }()

    // MARK: - Helper Methods

    /// Update all formatters with new locale
    static func updateLocale(_ locale: Locale) {
        crypto.locale = locale
        cryptoShort.locale = locale
        cryptoFull.locale = locale
        currency.locale = locale
        currencyCompact.locale = locale
        percentage.locale = locale
        percentageWithSign.locale = locale
        integer.locale = locale
        fileSize.locale = locale
    }
}

// MARK: - Formatting Extensions

extension Double {

    /// Format as crypto amount
    var asCrypto: String {
        NumberFormatter.crypto.string(from: NSNumber(value: self)) ?? "0"
    }

    /// Format as short crypto amount
    var asCryptoShort: String {
        NumberFormatter.cryptoShort.string(from: NSNumber(value: self)) ?? "0.00"
    }

    /// Format as full precision crypto
    var asCryptoFull: String {
        NumberFormatter.cryptoFull.string(from: NSNumber(value: self)) ?? "0"
    }

    /// Format as currency
    var asCurrency: String {
        NumberFormatter.currency.string(from: NSNumber(value: self)) ?? "$0.00"
    }

    /// Format as compact currency
    var asCurrencyCompact: String {
        if abs(self) >= 1_000_000_000 {
            return "\((self / 1_000_000_000).asCurrency)B"
        } else if abs(self) >= 1_000_000 {
            return "\((self / 1_000_000).asCurrency)M"
        } else if abs(self) >= 1_000 {
            return "\((self / 1_000).asCurrency)K"
        }
        return self.asCurrency
    }

    /// Format as percentage
    var asPercentage: String {
        NumberFormatter.percentage.string(from: NSNumber(value: self)) ?? "0%"
    }

    /// Format as percentage with sign
    var asPercentageWithSign: String {
        NumberFormatter.percentageWithSign.string(from: NSNumber(value: self)) ?? "+0.00%"
    }
}

extension Int {

    /// Format as integer with grouping
    var asInteger: String {
        NumberFormatter.integer.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

// MARK: - Decimal Extensions

extension Decimal {

    /// Format as crypto amount
    var asCrypto: String {
        NumberFormatter.crypto.string(from: self as NSDecimalNumber) ?? "0"
    }

    /// Format as currency
    var asCurrency: String {
        NumberFormatter.currency.string(from: self as NSDecimalNumber) ?? "$0.00"
    }

    /// Format as percentage
    var asPercentage: String {
        NumberFormatter.percentage.string(from: self as NSDecimalNumber) ?? "0%"
    }
}

// MARK: - String Parsing

extension String {

    /// Parse string as crypto number
    var parseCrypto: Double? {
        NumberFormatter.crypto.number(from: self)?.doubleValue
    }

    /// Parse string as currency
    var parseCurrency: Double? {
        NumberFormatter.currency.number(from: self)?.doubleValue
    }
}
