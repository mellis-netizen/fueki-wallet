//
//  LocalizationManager.swift
//  FuekiWallet
//
//  Centralized localization management system
//

import Foundation
import SwiftUI

/// Manages application localization and language preferences
final class LocalizationManager: ObservableObject {

    // MARK: - Singleton
    static let shared = LocalizationManager()

    // MARK: - Published Properties
    @Published var currentLocale: Locale
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: StorageKeys.language)
            updateLocale()
            NotificationCenter.default.post(name: .languageDidChange, object: currentLanguage)
        }
    }

    // MARK: - Properties
    private let supportedLanguages: [String] = [
        "en",    // English
        "es",    // Spanish
        "zh-Hans", // Chinese Simplified
        "ja",    // Japanese
        "fr",    // French
        "de",    // German
        "ko",    // Korean
        "pt"     // Portuguese
    ]

    private var bundle: Bundle = Bundle.main

    // MARK: - Storage Keys
    private enum StorageKeys {
        static let language = "app.language"
        static let useSystemLanguage = "app.useSystemLanguage"
    }

    // MARK: - Initialization
    private init() {
        // Load saved language preference or use system language
        if let savedLanguage = UserDefaults.standard.string(forKey: StorageKeys.language) {
            self.currentLanguage = savedLanguage
        } else {
            // Default to system language if supported
            let systemLanguage = Locale.preferredLanguages.first ?? "en"
            let languageCode = String(systemLanguage.prefix(2))
            self.currentLanguage = supportedLanguages.contains(languageCode) ? languageCode : "en"
        }

        self.currentLocale = Locale(identifier: currentLanguage)
        updateBundle()
    }

    // MARK: - Public Methods

    /// Get localized string for key
    /// - Parameters:
    ///   - key: Localization key
    ///   - arguments: Format arguments
    /// - Returns: Localized string
    func localized(_ key: String, arguments: CVarArg...) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)

        if arguments.isEmpty {
            return format
        }

        return String(format: format, locale: currentLocale, arguments: arguments)
    }

    /// Get localized string with plural support
    /// - Parameters:
    ///   - key: Localization key
    ///   - count: Count for pluralization
    /// - Returns: Localized string
    func localizedPlural(_ key: String, count: Int) -> String {
        let format = bundle.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, locale: currentLocale, count)
    }

    /// Set application language
    /// - Parameter languageCode: Language code (e.g., "en", "es")
    func setLanguage(_ languageCode: String) {
        guard supportedLanguages.contains(languageCode) else {
            print("⚠️ Unsupported language code: \(languageCode)")
            return
        }

        currentLanguage = languageCode
    }

    /// Get list of supported languages
    /// - Returns: Array of language info
    func getSupportedLanguages() -> [LanguageInfo] {
        return supportedLanguages.map { code in
            LanguageInfo(
                code: code,
                name: getLanguageName(for: code),
                nativeName: getNativeLanguageName(for: code),
                isRTL: isRTLLanguage(code)
            )
        }
    }

    /// Check if current language is RTL
    var isCurrentLanguageRTL: Bool {
        isRTLLanguage(currentLanguage)
    }

    /// Get language direction
    var layoutDirection: LayoutDirection {
        isCurrentLanguageRTL ? .rightToLeft : .leftToRight
    }

    // MARK: - Private Methods

    private func updateLocale() {
        currentLocale = Locale(identifier: currentLanguage)
        updateBundle()
    }

    private func updateBundle() {
        guard let path = Bundle.main.path(forResource: currentLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            self.bundle = Bundle.main
            return
        }
        self.bundle = bundle
    }

    private func isRTLLanguage(_ code: String) -> Bool {
        // RTL languages: Arabic, Hebrew, Persian, Urdu
        let rtlLanguages = ["ar", "he", "fa", "ur"]
        return rtlLanguages.contains(code)
    }

    private func getLanguageName(for code: String) -> String {
        let locale = Locale(identifier: "en")
        return locale.localizedString(forLanguageCode: code) ?? code
    }

    private func getNativeLanguageName(for code: String) -> String {
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code) ?? code
    }
}

// MARK: - Language Info Model
struct LanguageInfo: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    let nativeName: String
    let isRTL: Bool
}

// MARK: - Notification Names
extension Notification.Name {
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - Environment Key
struct LocalizationKey: EnvironmentKey {
    static let defaultValue = LocalizationManager.shared
}

extension EnvironmentValues {
    var localization: LocalizationManager {
        get { self[LocalizationKey.self] }
        set { self[LocalizationKey.self] = newValue }
    }
}

// MARK: - Helper Extension
extension Bundle {
    /// Get localized string with bundle support
    func localizedString(for key: String, locale: Locale) -> String {
        guard let path = self.path(forResource: locale.identifier, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

// MARK: - SwiftUI View Extension
extension View {
    /// Apply localization environment
    func withLocalization() -> some View {
        self.environment(\.locale, LocalizationManager.shared.currentLocale)
            .environment(\.layoutDirection, LocalizationManager.shared.layoutDirection)
            .environmentObject(LocalizationManager.shared)
    }
}
