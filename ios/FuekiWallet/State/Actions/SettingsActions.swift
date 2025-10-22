//
//  SettingsActions.swift
//  FuekiWallet
//
//  Actions related to settings state
//

import Foundation

// MARK: - Settings Actions
enum SettingsAction: Action {

    // Currency
    case setCurrency(Currency)
    case currencyChanged(Currency)

    // Language
    case setLanguage(Language)
    case languageChanged(Language)

    // Theme
    case setTheme(Theme)
    case themeChanged(Theme)

    // Biometric
    case enableBiometric
    case disableBiometric
    case biometricChanged(enabled: Bool)

    // Notifications
    case enableNotifications
    case disableNotifications
    case notificationsChanged(enabled: Bool)

    // Auto Lock
    case setAutoLockTimeout(TimeInterval)
    case autoLockTimeoutChanged(TimeInterval)

    // Network
    case setNetwork(Network)
    case networkChanged(Network)

    // Loading & Errors
    case setLoading(Bool)
    case setError(ErrorState?)
    case clearError

    // Persistence
    case saveSettings
    case settingsSaved
    case saveFailed(error: ErrorState)

    case loadSettings
    case settingsLoaded(settings: SettingsState)
    case loadFailed(error: ErrorState)

    // Reset
    case resetToDefaults
    case settingsReset

    // Privacy
    case enablePrivacyMode
    case disablePrivacyMode
    case privacyModeChanged(enabled: Bool)

    // Advanced
    case enableDeveloperMode
    case disableDeveloperMode
    case developerModeChanged(enabled: Bool)
}

// MARK: - Preference Actions
enum PreferenceAction: Action {
    case updatePreference(key: String, value: Any)
    case preferenceUpdated(key: String, value: Any)
    case deletePreference(key: String)
    case preferenceDeleted(key: String)
    case clearAllPreferences
    case preferencesCleared
}

// MARK: - Security Settings Actions
enum SecuritySettingsAction: Action {
    case enableTwoFactor
    case disableTwoFactor
    case twoFactorChanged(enabled: Bool)

    case setPasscodeLength(Int)
    case passcodeLengthChanged(Int)

    case enableBiometricFallback
    case disableBiometricFallback
    case biometricFallbackChanged(enabled: Bool)
}
