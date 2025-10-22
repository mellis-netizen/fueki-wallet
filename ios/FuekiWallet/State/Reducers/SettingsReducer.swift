//
//  SettingsReducer.swift
//  FuekiWallet
//
//  Pure reducer for settings state transformations
//

import Foundation

// MARK: - Settings Reducer
func settingsReducer(state: inout SettingsState, action: Action) {
    guard let action = action as? SettingsAction else { return }

    switch action {

    // Currency
    case .setCurrency(let currency):
        state.currency = currency

    case .currencyChanged(let currency):
        state.currency = currency

    // Language
    case .setLanguage(let language):
        state.language = language

    case .languageChanged(let language):
        state.language = language

    // Theme
    case .setTheme(let theme):
        state.theme = theme

    case .themeChanged(let theme):
        state.theme = theme

    // Biometric
    case .enableBiometric:
        state.biometricEnabled = true

    case .disableBiometric:
        state.biometricEnabled = false

    case .biometricChanged(let enabled):
        state.biometricEnabled = enabled

    // Notifications
    case .enableNotifications:
        state.notificationsEnabled = true

    case .disableNotifications:
        state.notificationsEnabled = false

    case .notificationsChanged(let enabled):
        state.notificationsEnabled = enabled

    // Auto Lock
    case .setAutoLockTimeout(let timeout):
        state.autoLockTimeout = timeout

    case .autoLockTimeoutChanged(let timeout):
        state.autoLockTimeout = timeout

    // Network
    case .setNetwork(let network):
        state.network = network

    case .networkChanged(let network):
        state.network = network

    // Loading & Errors
    case .setLoading(let loading):
        state.isLoading = loading

    case .setError(let error):
        state.error = error

    case .clearError:
        state.error = nil

    // Persistence
    case .saveSettings:
        state.isLoading = true
        state.error = nil

    case .settingsSaved:
        state.isLoading = false
        state.error = nil

    case .saveFailed(let error):
        state.error = error
        state.isLoading = false

    case .loadSettings:
        state.isLoading = true
        state.error = nil

    case .settingsLoaded(let settings):
        state = settings
        state.isLoading = false
        state.error = nil

    case .loadFailed(let error):
        state.error = error
        state.isLoading = false

    // Reset
    case .resetToDefaults:
        state = SettingsState()

    case .settingsReset:
        state = SettingsState()

    // Privacy
    case .enablePrivacyMode, .disablePrivacyMode, .privacyModeChanged:
        // Privacy mode implementation
        break

    // Advanced
    case .enableDeveloperMode, .disableDeveloperMode, .developerModeChanged:
        // Developer mode implementation
        break
    }
}

// MARK: - Preference Reducer
func preferenceReducer(state: inout SettingsState, action: Action) {
    guard let _ = action as? PreferenceAction else { return }

    // Preferences can be extended with a dictionary in SettingsState if needed
    // For now, using individual properties
}

// MARK: - Security Settings Reducer
func securitySettingsReducer(state: inout SettingsState, action: Action) {
    guard let _ = action as? SecuritySettingsAction else { return }

    // Security settings can be extended with additional properties
    // For now, using existing biometric and auto-lock settings
}
