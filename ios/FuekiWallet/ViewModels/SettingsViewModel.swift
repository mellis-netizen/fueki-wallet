//
//  SettingsViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import Combine
import SwiftUI

/// ViewModel managing app settings and preferences
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Published Properties

    // Security Settings
    @Published var biometricEnabled = false
    @Published var autoLockDuration: AutoLockDuration = .oneMinute
    @Published var requireBiometricForTransactions = true

    // Display Settings
    @Published var currency: Currency = .usd
    @Published var language: Language = .english
    @Published var theme: AppTheme = .system
    @Published var showBalanceOnHome = true

    // Notification Settings
    @Published var transactionNotifications = true
    @Published var priceAlerts = false
    @Published var securityAlerts = true

    // Network Settings
    @Published var defaultNetwork: Network = .mainnet
    @Published var customRPCEnabled = false
    @Published var customRPCURL = ""

    // Advanced Settings
    @Published var analyticsEnabled = true
    @Published var crashReportingEnabled = true
    @Published var experimentalFeaturesEnabled = false

    // MARK: - State

    @Published var isLoading = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showResetConfirmation = false

    // MARK: - Dependencies

    private let settingsService: SettingsServiceProtocol
    private let biometricService: BiometricServiceProtocol
    private let walletViewModel: WalletViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        settingsService: SettingsServiceProtocol = SettingsService.shared,
        biometricService: BiometricServiceProtocol = BiometricService.shared,
        walletViewModel: WalletViewModel
    ) {
        self.settingsService = settingsService
        self.biometricService = biometricService
        self.walletViewModel = walletViewModel
        setupBindings()
        loadSettings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Auto-save settings when they change
        Publishers.CombineLatest4($currency, $language, $theme, $showBalanceOnHome)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.saveSettings() }
            }
            .store(in: &cancellables)

        Publishers.CombineLatest4($transactionNotifications, $priceAlerts, $securityAlerts, $autoLockDuration)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.saveSettings() }
            }
            .store(in: &cancellables)

        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Update network when default changes
        $defaultNetwork
            .dropFirst()
            .sink { [weak self] network in
                Task { await self?.walletViewModel.switchNetwork(network) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Settings Management

    func loadSettings() {
        isLoading = true
        errorMessage = nil

        do {
            let settings = try settingsService.loadSettings()

            // Security
            biometricEnabled = settings.biometricEnabled
            autoLockDuration = settings.autoLockDuration
            requireBiometricForTransactions = settings.requireBiometricForTransactions

            // Display
            currency = settings.currency
            language = settings.language
            theme = settings.theme
            showBalanceOnHome = settings.showBalanceOnHome

            // Notifications
            transactionNotifications = settings.transactionNotifications
            priceAlerts = settings.priceAlerts
            securityAlerts = settings.securityAlerts

            // Network
            defaultNetwork = settings.defaultNetwork
            customRPCEnabled = settings.customRPCEnabled
            customRPCURL = settings.customRPCURL

            // Advanced
            analyticsEnabled = settings.analyticsEnabled
            crashReportingEnabled = settings.crashReportingEnabled
            experimentalFeaturesEnabled = settings.experimentalFeaturesEnabled
        } catch {
            errorMessage = "Failed to load settings: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func saveSettings() async {
        isSaving = true
        errorMessage = nil

        do {
            let settings = AppSettings(
                biometricEnabled: biometricEnabled,
                autoLockDuration: autoLockDuration,
                requireBiometricForTransactions: requireBiometricForTransactions,
                currency: currency,
                language: language,
                theme: theme,
                showBalanceOnHome: showBalanceOnHome,
                transactionNotifications: transactionNotifications,
                priceAlerts: priceAlerts,
                securityAlerts: securityAlerts,
                defaultNetwork: defaultNetwork,
                customRPCEnabled: customRPCEnabled,
                customRPCURL: customRPCURL,
                analyticsEnabled: analyticsEnabled,
                crashReportingEnabled: crashReportingEnabled,
                experimentalFeaturesEnabled: experimentalFeaturesEnabled
            )

            try await settingsService.saveSettings(settings)
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
        }

        isSaving = false
    }

    // MARK: - Security Actions

    func toggleBiometric() async {
        do {
            if !biometricEnabled {
                // Enable biometric
                let available = await biometricService.isBiometricAvailable()

                guard available else {
                    throw SettingsError.biometricNotAvailable
                }

                let authenticated = try await biometricService.authenticate()

                guard authenticated else {
                    throw SettingsError.biometricAuthenticationFailed
                }

                if let wallet = walletViewModel.currentWallet {
                    try await biometricService.enableBiometric(for: wallet.id)
                }

                biometricEnabled = true
            } else {
                // Disable biometric
                if let wallet = walletViewModel.currentWallet {
                    try await biometricService.disableBiometric(for: wallet.id)
                }

                biometricEnabled = false
            }

            await saveSettings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func changeAutoLockDuration(_ duration: AutoLockDuration) async {
        autoLockDuration = duration
        await saveSettings()
    }

    // MARK: - Data Management

    func clearCache() async {
        isLoading = true
        errorMessage = nil

        do {
            try await settingsService.clearCache()
        } catch {
            errorMessage = "Failed to clear cache: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func resetSettings() async {
        isLoading = true
        errorMessage = nil

        do {
            try await settingsService.resetToDefaults()
            loadSettings()
        } catch {
            errorMessage = "Failed to reset settings: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func exportData() async -> URL? {
        do {
            return try await settingsService.exportUserData()
        } catch {
            errorMessage = "Failed to export data: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - App Information

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var formattedVersion: String {
        "Version \(appVersion) (\(buildNumber))"
    }
}

// MARK: - Models

struct AppSettings: Codable {
    // Security
    var biometricEnabled: Bool
    var autoLockDuration: AutoLockDuration
    var requireBiometricForTransactions: Bool

    // Display
    var currency: Currency
    var language: Language
    var theme: AppTheme
    var showBalanceOnHome: Bool

    // Notifications
    var transactionNotifications: Bool
    var priceAlerts: Bool
    var securityAlerts: Bool

    // Network
    var defaultNetwork: Network
    var customRPCEnabled: Bool
    var customRPCURL: String

    // Advanced
    var analyticsEnabled: Bool
    var crashReportingEnabled: Bool
    var experimentalFeaturesEnabled: Bool
}

enum AutoLockDuration: String, Codable, CaseIterable {
    case immediate = "Immediate"
    case oneMinute = "1 Minute"
    case fiveMinutes = "5 Minutes"
    case fifteenMinutes = "15 Minutes"
    case never = "Never"

    var seconds: TimeInterval {
        switch self {
        case .immediate: return 0
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .never: return .infinity
        }
    }
}

enum Currency: String, Codable, CaseIterable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case jpy = "JPY"
    case cny = "CNY"
    case krw = "KRW"

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .cny: return "¥"
        case .krw: return "₩"
        }
    }
}

enum Language: String, Codable, CaseIterable {
    case english = "English"
    case spanish = "Español"
    case french = "Français"
    case german = "Deutsch"
    case chinese = "中文"
    case japanese = "日本語"
    case korean = "한국어"

    var code: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .chinese: return "zh"
        case .japanese: return "ja"
        case .korean: return "ko"
        }
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

enum SettingsError: LocalizedError {
    case biometricNotAvailable
    case biometricAuthenticationFailed
    case saveSettingsFailed
    case loadSettingsFailed

    var errorDescription: String? {
        switch self {
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricAuthenticationFailed:
            return "Failed to authenticate with biometrics"
        case .saveSettingsFailed:
            return "Failed to save settings"
        case .loadSettingsFailed:
            return "Failed to load settings"
        }
    }
}

// MARK: - Service Protocol

protocol SettingsServiceProtocol {
    func loadSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws
    func clearCache() async throws
    func resetToDefaults() async throws
    func exportUserData() async throws -> URL
}
