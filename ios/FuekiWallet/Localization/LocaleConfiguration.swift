//
//  LocaleConfiguration.swift
//  FuekiWallet
//
//  Locale configuration and RTL support
//

import Foundation
import SwiftUI

/// Manages locale-specific configurations including RTL support
final class LocaleConfiguration {

    // MARK: - Singleton
    static let shared = LocaleConfiguration()

    // MARK: - Properties

    /// Current locale
    var currentLocale: Locale {
        LocalizationManager.shared.currentLocale
    }

    /// Current language code
    var currentLanguageCode: String {
        LocalizationManager.shared.currentLanguage
    }

    /// Is current language right-to-left
    var isRTL: Bool {
        LocalizationManager.shared.isCurrentLanguageRTL
    }

    /// Layout direction based on language
    var layoutDirection: LayoutDirection {
        isRTL ? .rightToLeft : .leftToRight
    }

    /// Semantic content attribute for UIKit views
    var semanticContentAttribute: UISemanticContentAttribute {
        isRTL ? .forceRightToLeft : .forceLeftToRight
    }

    // MARK: - RTL Languages

    private let rtlLanguages: Set<String> = [
        "ar",  // Arabic
        "he",  // Hebrew
        "fa",  // Persian
        "ur"   // Urdu
    ]

    // MARK: - Initialization

    private init() {
        setupLocaleObserver()
    }

    // MARK: - Configuration

    /// Apply RTL configuration to app
    func applyRTLConfiguration() {
        if isRTL {
            UIView.appearance().semanticContentAttribute = .forceRightToLeft
            UINavigationBar.appearance().semanticContentAttribute = .forceRightToLeft
            UITabBar.appearance().semanticContentAttribute = .forceRightToLeft
        } else {
            UIView.appearance().semanticContentAttribute = .forceLeftToRight
            UINavigationBar.appearance().semanticContentAttribute = .forceLeftToRight
            UITabBar.appearance().semanticContentAttribute = .forceLeftToRight
        }
    }

    /// Setup locale change observer
    private func setupLocaleObserver() {
        NotificationCenter.default.addObserver(
            forName: .languageDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleLocaleChange()
        }
    }

    /// Handle locale changes
    private func handleLocaleChange() {
        applyRTLConfiguration()
        updateFormatters()
    }

    /// Update all formatters with new locale
    private func updateFormatters() {
        NumberFormatter.updateLocale(currentLocale)
        DateFormatter.updateLocale(currentLocale)
    }

    // MARK: - Alignment

    /// Get text alignment based on layout direction
    var textAlignment: TextAlignment {
        isRTL ? .trailing : .leading
    }

    /// Get horizontal alignment based on layout direction
    var horizontalAlignment: HorizontalAlignment {
        isRTL ? .trailing : .leading
    }

    /// Get edge alignment based on layout direction
    var leadingEdge: Edge.Set {
        isRTL ? .trailing : .leading
    }

    var trailingEdge: Edge.Set {
        isRTL ? .leading : .trailing
    }

    // MARK: - Padding

    /// Get leading padding value
    func leadingPadding(_ value: CGFloat) -> EdgeInsets {
        isRTL ? EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: value) :
                EdgeInsets(top: 0, leading: value, bottom: 0, trailing: 0)
    }

    /// Get trailing padding value
    func trailingPadding(_ value: CGFloat) -> EdgeInsets {
        isRTL ? EdgeInsets(top: 0, leading: value, bottom: 0, trailing: 0) :
                EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: value)
    }

    // MARK: - Image Flipping

    /// Check if image should be flipped for RTL
    func shouldFlipImage(named imageName: String) -> Bool {
        // Don't flip logos, icons that are universally understood
        let noFlipImages = ["logo", "icon", "qr"]
        return isRTL && !noFlipImages.contains { imageName.lowercased().contains($0) }
    }
}

// MARK: - View Extensions

extension View {

    /// Apply RTL-aware alignment
    func rtlAlignment() -> some View {
        self.multilineTextAlignment(LocaleConfiguration.shared.textAlignment)
    }

    /// Apply RTL-aware leading padding
    func leadingPadding(_ value: CGFloat) -> some View {
        self.padding(LocaleConfiguration.shared.leadingPadding(value))
    }

    /// Apply RTL-aware trailing padding
    func trailingPadding(_ value: CGFloat) -> some View {
        self.padding(LocaleConfiguration.shared.trailingPadding(value))
    }

    /// Flip image for RTL if needed
    func rtlFlip() -> some View {
        self.scaleEffect(x: LocaleConfiguration.shared.isRTL ? -1 : 1, y: 1)
    }
}

// MARK: - Image Extensions

extension Image {

    /// Create image with RTL support
    init(rtlAware name: String) {
        self.init(name)
        if LocaleConfiguration.shared.shouldFlipImage(named: name) {
            _ = self.flipsForRightToLeftLayoutDirection(true)
        }
    }

    /// Create system image with RTL support
    init(rtlSystemName name: String) {
        self.init(systemName: name)
        // SwiftUI system images automatically flip for RTL
    }
}

// MARK: - Locale Info

extension Locale {

    /// Get display name for language code
    static func displayName(for languageCode: String) -> String? {
        let locale = Locale(identifier: languageCode)
        return locale.localizedString(forLanguageCode: languageCode)
    }

    /// Get native display name for language code
    static func nativeDisplayName(for languageCode: String) -> String? {
        let currentLocale = Locale.current
        return currentLocale.localizedString(forLanguageCode: languageCode)
    }

    /// Check if language is RTL
    static func isRTL(languageCode: String) -> Bool {
        let rtlLanguages: Set<String> = ["ar", "he", "fa", "ur"]
        return rtlLanguages.contains(languageCode)
    }
}

// MARK: - Currency Configuration

extension LocaleConfiguration {

    /// Get currency symbol for current locale
    var currencySymbol: String {
        let code = UserDefaults.standard.string(forKey: "app.currency") ?? "USD"
        return Locale.current.currencySymbol(forCurrencyCode: code) ?? "$"
    }

    /// Get currency code for current locale
    var currencyCode: String {
        UserDefaults.standard.string(forKey: "app.currency") ?? "USD"
    }

    /// Set currency code
    func setCurrency(_ code: String) {
        UserDefaults.standard.set(code, forKey: "app.currency")
        updateFormatters()
    }
}

// MARK: - Locale Extensions Helper

extension Locale {

    /// Get currency symbol for currency code
    func currencySymbol(forCurrencyCode code: String) -> String? {
        let locale = Locale(identifier: identifier)
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.currencySymbol
    }
}
