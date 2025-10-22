//
//  AppConfiguration.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import Foundation

enum AppEnvironment: String {
    case development
    case staging
    case production

    var displayName: String {
        switch self {
        case .development:
            return "Development"
        case .staging:
            return "Staging"
        case .production:
            return "Production"
        }
    }
}

struct AppConfiguration {

    // MARK: - Environment

    static var environment: AppEnvironment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }

    // MARK: - App Info

    static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.fueki.wallet"
    }

    static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var displayName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Fueki Wallet"
    }

    // MARK: - API Configuration

    static var apiBaseURL: URL {
        switch environment {
        case .development:
            return URL(string: "https://dev-api.fueki.io")!
        case .staging:
            return URL(string: "https://staging-api.fueki.io")!
        case .production:
            return URL(string: "https://api.fueki.io")!
        }
    }

    static var apiKey: String {
        switch environment {
        case .development:
            return getEnvironmentVariable("DEV_API_KEY") ?? ""
        case .staging:
            return getEnvironmentVariable("STAGING_API_KEY") ?? ""
        case .production:
            return getEnvironmentVariable("PROD_API_KEY") ?? ""
        }
    }

    // MARK: - Blockchain Configuration

    static var rpcURL: URL {
        switch environment {
        case .development:
            return URL(string: "http://localhost:8545")!
        case .staging:
            return URL(string: "https://rpc.testnet.fueki.network")!
        case .production:
            return URL(string: "https://rpc.fueki.network")!
        }
    }

    static var chainId: Int {
        switch environment {
        case .development:
            return 1337
        case .staging:
            return 80001 // Mumbai testnet
        case .production:
            return 137 // Polygon mainnet
        }
    }

    static var networkName: String {
        switch environment {
        case .development:
            return "Local Network"
        case .staging:
            return "Fueki Testnet"
        case .production:
            return "Fueki Mainnet"
        }
    }

    static var explorerURL: URL {
        switch environment {
        case .development:
            return URL(string: "http://localhost:4000")!
        case .staging:
            return URL(string: "https://explorer.testnet.fueki.network")!
        case .production:
            return URL(string: "https://explorer.fueki.network")!
        }
    }

    // MARK: - Feature Flags

    static var isAnalyticsEnabled: Bool {
        return environment == .production
    }

    static var isCrashReportingEnabled: Bool {
        return environment != .development
    }

    static var isLoggingEnabled: Bool {
        return environment != .production
    }

    static var isDebugMenuEnabled: Bool {
        return environment == .development
    }

    static var isTestnetEnabled: Bool {
        return environment != .production
    }

    static var isDAppBrowserEnabled: Bool {
        return true
    }

    static var isNFTsEnabled: Bool {
        return true
    }

    static var isWalletConnectEnabled: Bool {
        return true
    }

    static var isStakingEnabled: Bool {
        return environment == .production
    }

    static var isSwapEnabled: Bool {
        return true
    }

    // MARK: - Security

    static var authenticationTimeout: TimeInterval {
        switch environment {
        case .development:
            return 300 // 5 minutes
        case .staging:
            return 180 // 3 minutes
        case .production:
            return 60 // 1 minute
        }
    }

    static var maxPINAttempts: Int {
        return 5
    }

    static var pinLength: Int {
        return 6
    }

    static var requireBiometricAuth: Bool {
        return environment == .production
    }

    // MARK: - Networking

    static var requestTimeout: TimeInterval {
        return 30.0
    }

    static var maxRetryAttempts: Int {
        return 3
    }

    static var retryDelay: TimeInterval {
        return 2.0
    }

    // MARK: - Cache

    static var maxCacheSize: Int {
        return 100 * 1024 * 1024 // 100 MB
    }

    static var cacheExpiration: TimeInterval {
        return 3600 // 1 hour
    }

    // MARK: - Third Party Services

    static var mixpanelToken: String {
        return getEnvironmentVariable("MIXPANEL_TOKEN") ?? ""
    }

    static var sentryDSN: String {
        return getEnvironmentVariable("SENTRY_DSN") ?? ""
    }

    static var walletConnectProjectID: String {
        return getEnvironmentVariable("WALLETCONNECT_PROJECT_ID") ?? ""
    }

    static var infuraProjectID: String {
        return getEnvironmentVariable("INFURA_PROJECT_ID") ?? ""
    }

    static var alchemyAPIKey: String {
        return getEnvironmentVariable("ALCHEMY_API_KEY") ?? ""
    }

    static var coinGeckoAPIKey: String {
        return getEnvironmentVariable("COINGECKO_API_KEY") ?? ""
    }

    // MARK: - App Store

    static var appStoreURL: String {
        return "https://apps.apple.com/app/id123456789"
    }

    static var appStoreID: String {
        return "123456789"
    }

    // MARK: - Support

    static var supportEmail: String {
        return "support@fueki.io"
    }

    static var supportURL: URL {
        return URL(string: "https://support.fueki.io")!
    }

    static var termsOfServiceURL: URL {
        return URL(string: "https://fueki.io/terms")!
    }

    static var privacyPolicyURL: URL {
        return URL(string: "https://fueki.io/privacy")!
    }

    // MARK: - Social Media

    static var twitterURL: URL {
        return URL(string: "https://twitter.com/fuekiwallet")!
    }

    static var discordURL: URL {
        return URL(string: "https://discord.gg/fueki")!
    }

    static var telegramURL: URL {
        return URL(string: "https://t.me/fuekiwallet")!
    }

    static var githubURL: URL {
        return URL(string: "https://github.com/fueki-network")!
    }

    // MARK: - Gas Limits

    static var defaultGasLimit: UInt64 {
        return 21000
    }

    static var tokenTransferGasLimit: UInt64 {
        return 65000
    }

    static var contractInteractionGasLimit: UInt64 {
        return 200000
    }

    // MARK: - Transaction Fees

    static var minGasPrice: Double {
        return 1.0 // 1 Gwei
    }

    static var maxGasPrice: Double {
        return 500.0 // 500 Gwei
    }

    static var gasPriceMultiplier: Double {
        return 1.1 // 10% buffer
    }

    // MARK: - Price Updates

    static var priceUpdateInterval: TimeInterval {
        return 60.0 // 1 minute
    }

    static var chartDataInterval: TimeInterval {
        return 300.0 // 5 minutes
    }

    // MARK: - Transaction Monitoring

    static var transactionPollInterval: TimeInterval {
        return 15.0 // 15 seconds
    }

    static var maxTransactionConfirmations: Int {
        return 12
    }

    // MARK: - Backup

    static var maxBackupRetentionDays: Int {
        return 90
    }

    static var isCloudBackupEnabled: Bool {
        return true
    }

    // MARK: - Rate Limiting

    static var maxRequestsPerMinute: Int {
        return 60
    }

    static var maxTransactionsPerDay: Int {
        return 100
    }

    // MARK: - Helper Methods

    private static func getEnvironmentVariable(_ key: String) -> String? {
        return ProcessInfo.processInfo.environment[key]
    }

    static func printConfiguration() {
        print("=== App Configuration ===")
        print("Environment: \(environment.displayName)")
        print("Version: \(appVersion) (\(buildNumber))")
        print("API Base URL: \(apiBaseURL.absoluteString)")
        print("RPC URL: \(rpcURL.absoluteString)")
        print("Chain ID: \(chainId)")
        print("Network: \(networkName)")
        print("Analytics Enabled: \(isAnalyticsEnabled)")
        print("Crash Reporting Enabled: \(isCrashReportingEnabled)")
        print("Logging Enabled: \(isLoggingEnabled)")
        print("========================")
    }
}
