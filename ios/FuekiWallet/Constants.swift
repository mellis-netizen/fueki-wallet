//
//  Constants.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import Foundation
import UIKit

struct Constants {

    // MARK: - Keychain

    struct Keychain {
        static let service = "com.fueki.wallet"
        static let accessGroup = "group.com.fueki.wallet"

        struct Keys {
            static let privateKey = "privateKey"
            static let mnemonic = "mnemonic"
            static let pin = "pin"
            static let deviceToken = "deviceToken"
            static let fcmToken = "fcmToken"
            static let biometricAuthEnabled = "biometricAuthEnabled"
            static let autoLockTimeout = "autoLockTimeout"
        }
    }

    // MARK: - UserDefaults

    struct UserDefaults {
        struct Keys {
            static let hasCompletedOnboarding = "hasCompletedOnboarding"
            static let selectedWalletAddress = "selectedWalletAddress"
            static let preferredCurrency = "preferredCurrency"
            static let preferredLanguage = "preferredLanguage"
            static let biometricAuthEnabled = "biometricAuthEnabled"
            static let pushNotificationsEnabled = "pushNotificationsEnabled"
            static let priceAlertsEnabled = "priceAlertsEnabled"
            static let transactionNotificationsEnabled = "transactionNotificationsEnabled"
            static let lastBackgroundTime = "lastBackgroundTime"
            static let lastPriceUpdate = "lastPriceUpdate"
            static let lastBlockSync = "lastBlockSync"
            static let showTestnetWarning = "showTestnetWarning"
            static let acceptedTermsVersion = "acceptedTermsVersion"
            static let appLaunchCount = "appLaunchCount"
            static let lastAppVersion = "lastAppVersion"
        }
    }

    // MARK: - Notifications

    struct Notifications {
        static let walletCreated = Notification.Name("WalletCreated")
        static let walletImported = Notification.Name("WalletImported")
        static let walletDeleted = Notification.Name("WalletDeleted")
        static let walletSelected = Notification.Name("WalletSelected")
        static let transactionSent = Notification.Name("TransactionSent")
        static let transactionReceived = Notification.Name("TransactionReceived")
        static let transactionConfirmed = Notification.Name("TransactionConfirmed")
        static let transactionFailed = Notification.Name("TransactionFailed")
        static let balanceUpdated = Notification.Name("BalanceUpdated")
        static let priceUpdated = Notification.Name("PriceUpdated")
        static let networkChanged = Notification.Name("NetworkChanged")
        static let biometricAuthChanged = Notification.Name("BiometricAuthChanged")
        static let languageChanged = Notification.Name("LanguageChanged")
        static let currencyChanged = Notification.Name("CurrencyChanged")
    }

    // MARK: - Blockchain

    struct Blockchain {
        static let zeroAddress = "0x0000000000000000000000000000000000000000"
        static let nativeTokenSymbol = "FUEKI"
        static let nativeTokenName = "Fueki"
        static let nativeTokenDecimals = 18
        static let confirmationBlocks = 12
        static let maxBlockRange = 5000
        static let defaultGasLimit: UInt64 = 21000
        static let tokenTransferGasLimit: UInt64 = 65000
        static let approveGasLimit: UInt64 = 50000
        static let swapGasLimit: UInt64 = 200000
    }

    // MARK: - Wallet

    struct Wallet {
        static let minPasswordLength = 8
        static let mnemonicWordCount = 12
        static let maxWallets = 10
        static let addressPrefix = "0x"
        static let addressLength = 42
        static let defaultDerivationPath = "m/44'/60'/0'/0/0"
        static let maxNameLength = 32
        static let minBalance = 0.001 // Minimum balance to show
    }

    // MARK: - Transaction

    struct Transaction {
        static let minAmount = 0.000001
        static let maxPendingTransactions = 50
        static let transactionTimeout: TimeInterval = 300 // 5 minutes
        static let maxMemoLength = 256
        static let speedUpMultiplier = 1.1
        static let cancelMultiplier = 1.2
    }

    // MARK: - Token

    struct Token {
        static let defaultTokens = [
            "USDT",
            "USDC",
            "DAI",
            "WETH",
            "WBTC"
        ]
        static let maxCustomTokens = 100
        static let minTokenBalance = 0.0001
        static let erc20ABI = "[{\"constant\":true,\"inputs\":[],\"name\":\"name\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_spender\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"approve\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"totalSupply\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_from\",\"type\":\"address\"},{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transferFrom\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"decimals\",\"outputs\":[{\"name\":\"\",\"type\":\"uint8\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"balance\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[],\"name\":\"symbol\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_value\",\"type\":\"uint256\"}],\"name\":\"transfer\",\"outputs\":[{\"name\":\"\",\"type\":\"bool\"}],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"},{\"name\":\"_spender\",\"type\":\"address\"}],\"name\":\"allowance\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}]"
        static let erc721ABI = "[{\"constant\":true,\"inputs\":[{\"name\":\"_tokenId\",\"type\":\"uint256\"}],\"name\":\"ownerOf\",\"outputs\":[{\"name\":\"\",\"type\":\"address\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_owner\",\"type\":\"address\"}],\"name\":\"balanceOf\",\"outputs\":[{\"name\":\"\",\"type\":\"uint256\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"},{\"constant\":false,\"inputs\":[{\"name\":\"_to\",\"type\":\"address\"},{\"name\":\"_tokenId\",\"type\":\"uint256\"}],\"name\":\"transfer\",\"outputs\":[],\"payable\":false,\"stateMutability\":\"nonpayable\",\"type\":\"function\"},{\"constant\":true,\"inputs\":[{\"name\":\"_tokenId\",\"type\":\"uint256\"}],\"name\":\"tokenURI\",\"outputs\":[{\"name\":\"\",\"type\":\"string\"}],\"payable\":false,\"stateMutability\":\"view\",\"type\":\"function\"}]"
    }

    // MARK: - NFT

    struct NFT {
        static let maxNFTsPerPage = 50
        static let supportedStandards = ["ERC721", "ERC1155"]
        static let ipfsGateway = "https://ipfs.io/ipfs/"
        static let arweaveGateway = "https://arweave.net/"
    }

    // MARK: - DApp

    struct DApp {
        static let defaultDApps = [
            "https://app.uniswap.org",
            "https://aave.com",
            "https://curve.fi",
            "https://opensea.io"
        ]
        static let maxTabs = 10
        static let maxHistoryItems = 100
        static let maxBookmarks = 50
        static let userAgent = "FuekiWallet/\(AppConfiguration.appVersion) (iOS)"
    }

    // MARK: - Price

    struct Price {
        static let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "CNY"]
        static let defaultCurrency = "USD"
        static let priceChangeThreshold = 0.05 // 5%
        static let maxPriceHistory = 365 // days
    }

    // MARK: - UI

    struct UI {
        static let animationDuration = 0.3
        static let cornerRadius: CGFloat = 12.0
        static let shadowRadius: CGFloat = 8.0
        static let shadowOpacity: Float = 0.1
        static let borderWidth: CGFloat = 1.0
        static let spacing: CGFloat = 16.0
        static let padding: CGFloat = 16.0
        static let buttonHeight: CGFloat = 56.0
        static let textFieldHeight: CGFloat = 48.0
        static let iconSize: CGFloat = 24.0
        static let avatarSize: CGFloat = 40.0
        static let maxTextLength = 1000
    }

    // MARK: - API

    struct API {
        struct Endpoints {
            static let prices = "/v1/prices"
            static let charts = "/v1/charts"
            static let tokens = "/v1/tokens"
            static let nfts = "/v1/nfts"
            static let transactions = "/v1/transactions"
            static let gas = "/v1/gas"
            static let news = "/v1/news"
            static let discover = "/v1/discover"
        }

        struct Headers {
            static let apiKey = "X-API-Key"
            static let appVersion = "X-App-Version"
            static let platform = "X-Platform"
            static let deviceId = "X-Device-ID"
        }
    }

    // MARK: - Cache

    struct Cache {
        static let pricesCacheKey = "prices"
        static let tokensCacheKey = "tokens"
        static let nftsCacheKey = "nfts"
        static let balanceCacheKey = "balance"
        static let transactionsCacheKey = "transactions"
        static let gasPriceCacheKey = "gasPrice"
        static let defaultCacheExpiration: TimeInterval = 300 // 5 minutes
    }

    // MARK: - Regex

    struct Regex {
        static let ethereumAddress = "^0x[a-fA-F0-9]{40}$"
        static let privateKey = "^[a-fA-F0-9]{64}$"
        static let transactionHash = "^0x[a-fA-F0-9]{64}$"
        static let email = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        static let url = "https?://[^\\s/$.?#].[^\\s]*"
    }

    // MARK: - Error Messages

    struct ErrorMessages {
        static let invalidAddress = "Invalid wallet address"
        static let insufficientFunds = "Insufficient funds"
        static let networkError = "Network error. Please try again."
        static let transactionFailed = "Transaction failed"
        static let invalidPrivateKey = "Invalid private key"
        static let invalidMnemonic = "Invalid recovery phrase"
        static let walletExists = "Wallet already exists"
        static let authenticationFailed = "Authentication failed"
        static let biometricNotAvailable = "Biometric authentication not available"
        static let pinMismatch = "PIN codes do not match"
        static let maxAttemptsReached = "Maximum attempts reached"
        static let unknownError = "An unknown error occurred"
    }

    // MARK: - Success Messages

    struct SuccessMessages {
        static let walletCreated = "Wallet created successfully"
        static let walletImported = "Wallet imported successfully"
        static let transactionSent = "Transaction sent successfully"
        static let settingsSaved = "Settings saved"
        static let copied = "Copied to clipboard"
        static let backupCompleted = "Backup completed"
        static let recoveryCompleted = "Recovery completed"
    }

    // MARK: - Analytics

    struct Analytics {
        struct Events {
            static let appLaunched = "app_launched"
            static let walletCreated = "wallet_created"
            static let walletImported = "wallet_imported"
            static let transactionSent = "transaction_sent"
            static let transactionReceived = "transaction_received"
            static let tokenAdded = "token_added"
            static let dappOpened = "dapp_opened"
            static let settingsChanged = "settings_changed"
            static let screenViewed = "screen_viewed"
            static let errorOccurred = "error_occurred"
        }

        struct Properties {
            static let walletAddress = "wallet_address"
            static let transactionHash = "transaction_hash"
            static let tokenSymbol = "token_symbol"
            static let amount = "amount"
            static let currency = "currency"
            static let screenName = "screen_name"
            static let errorType = "error_type"
            static let errorMessage = "error_message"
        }
    }
}
