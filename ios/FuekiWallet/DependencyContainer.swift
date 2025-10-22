//
//  DependencyContainer.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import Foundation
import CoreData

class DependencyContainer {

    // MARK: - Core Services

    lazy var networkingService: NetworkingServiceProtocol = {
        return NetworkingService(
            baseURL: AppConfiguration.apiBaseURL,
            apiKey: AppConfiguration.apiKey,
            timeout: 30.0
        )
    }()

    lazy var persistenceService: PersistenceServiceProtocol = {
        return PersistenceService(modelName: "FuekiWallet")
    }()

    lazy var securityService: SecurityServiceProtocol = {
        return SecurityService(
            keychainService: keychainService,
            biometricService: biometricService
        )
    }()

    lazy var keychainService: KeychainServiceProtocol = {
        return KeychainService(service: AppConfiguration.bundleIdentifier)
    }()

    lazy var biometricService: BiometricServiceProtocol = {
        return BiometricService()
    }()

    lazy var encryptionService: EncryptionServiceProtocol = {
        return EncryptionService(securityService: securityService)
    }()

    // MARK: - Blockchain Services

    lazy var blockchainService: BlockchainServiceProtocol = {
        return BlockchainService(
            rpcURL: AppConfiguration.rpcURL,
            networkService: networkingService,
            cacheService: cacheService
        )
    }()

    lazy var walletService: WalletServiceProtocol = {
        return WalletService(
            blockchainService: blockchainService,
            securityService: securityService,
            persistenceService: persistenceService,
            encryptionService: encryptionService
        )
    }()

    lazy var transactionService: TransactionServiceProtocol = {
        return TransactionService(
            blockchainService: blockchainService,
            walletService: walletService,
            gasEstimationService: gasEstimationService,
            persistenceService: persistenceService
        )
    }()

    lazy var gasEstimationService: GasEstimationServiceProtocol = {
        return GasEstimationService(
            blockchainService: blockchainService,
            networkService: networkingService
        )
    }()

    lazy var tokenService: TokenServiceProtocol = {
        return TokenService(
            blockchainService: blockchainService,
            persistenceService: persistenceService,
            networkService: networkingService
        )
    }()

    lazy var nftService: NFTServiceProtocol = {
        return NFTService(
            blockchainService: blockchainService,
            networkService: networkingService,
            persistenceService: persistenceService
        )
    }()

    // MARK: - DApp Services

    lazy var dappBrowserService: DAppBrowserServiceProtocol = {
        return DAppBrowserService(
            walletService: walletService,
            securityService: securityService,
            web3Bridge: web3Bridge
        )
    }()

    lazy var web3Bridge: Web3BridgeProtocol = {
        return Web3Bridge(
            walletService: walletService,
            transactionService: transactionService,
            signatureService: signatureService
        )
    }()

    lazy var signatureService: SignatureServiceProtocol = {
        return SignatureService(
            walletService: walletService,
            securityService: securityService
        )
    }()

    lazy var walletConnectService: WalletConnectServiceProtocol = {
        return WalletConnectService(
            walletService: walletService,
            signatureService: signatureService,
            persistenceService: persistenceService
        )
    }()

    // MARK: - Market Data Services

    lazy var priceService: PriceServiceProtocol = {
        return PriceService(
            networkService: networkingService,
            cacheService: cacheService,
            updateInterval: 60.0
        )
    }()

    lazy var chartService: ChartServiceProtocol = {
        return ChartService(
            networkService: networkingService,
            cacheService: cacheService
        )
    }()

    lazy var portfolioService: PortfolioServiceProtocol = {
        return PortfolioService(
            walletService: walletService,
            tokenService: tokenService,
            priceService: priceService,
            nftService: nftService
        )
    }()

    // MARK: - Notification Services

    lazy var notificationService: NotificationServiceProtocol = {
        return NotificationService(
            persistenceService: persistenceService
        )
    }()

    lazy var transactionMonitoringService: TransactionMonitoringServiceProtocol = {
        return TransactionMonitoringService(
            blockchainService: blockchainService,
            walletService: walletService,
            notificationService: notificationService,
            pollInterval: 15.0
        )
    }()

    lazy var priceAlertService: PriceAlertServiceProtocol = {
        return PriceAlertService(
            priceService: priceService,
            notificationService: notificationService,
            persistenceService: persistenceService
        )
    }()

    // MARK: - Utility Services

    lazy var cacheService: CacheServiceProtocol = {
        return CacheService(maxCacheSize: 100 * 1024 * 1024) // 100 MB
    }()

    lazy var analyticsService: AnalyticsServiceProtocol = {
        return AnalyticsService(
            enabledInDebug: false,
            providers: [
                FirebaseAnalyticsProvider(),
                MixpanelAnalyticsProvider(token: AppConfiguration.mixpanelToken)
            ]
        )
    }()

    lazy var imageService: ImageServiceProtocol = {
        return ImageService(
            cacheService: cacheService,
            networkService: networkingService
        )
    }()

    lazy var qrCodeService: QRCodeServiceProtocol = {
        return QRCodeService()
    }()

    lazy var clipboardService: ClipboardServiceProtocol = {
        return ClipboardService()
    }()

    lazy var hapticService: HapticServiceProtocol = {
        return HapticService()
    }()

    lazy var localizationService: LocalizationServiceProtocol = {
        return LocalizationService(
            defaultLanguage: .english,
            supportedLanguages: [.english, .spanish, .french, .german, .japanese, .chinese]
        )
    }()

    // MARK: - API Services

    lazy var apiService: APIServiceProtocol = {
        return APIService(
            networkService: networkingService,
            authService: authService
        )
    }()

    lazy var authService: AuthServiceProtocol = {
        return AuthService(
            keychainService: keychainService,
            apiService: apiService
        )
    }()

    lazy var updateService: UpdateServiceProtocol = {
        return UpdateService(
            apiService: apiService,
            currentVersion: AppConfiguration.appVersion
        )
    }()

    // MARK: - Backup & Recovery Services

    lazy var backupService: BackupServiceProtocol = {
        return BackupService(
            walletService: walletService,
            encryptionService: encryptionService,
            cloudService: cloudService
        )
    }()

    lazy var cloudService: CloudServiceProtocol = {
        return iCloudService()
    }()

    lazy var recoveryService: RecoveryServiceProtocol = {
        return RecoveryService(
            walletService: walletService,
            encryptionService: encryptionService,
            cloudService: cloudService
        )
    }()

    // MARK: - Security Services

    lazy var fraudDetectionService: FraudDetectionServiceProtocol = {
        return FraudDetectionService(
            apiService: apiService,
            analyticsService: analyticsService
        )
    }()

    lazy var addressValidationService: AddressValidationServiceProtocol = {
        return AddressValidationService(
            blockchainService: blockchainService
        )
    }()

    // MARK: - Repositories

    lazy var walletRepository: WalletRepository = {
        return WalletRepository(
            persistenceService: persistenceService,
            context: persistenceService.viewContext
        )
    }()

    lazy var transactionRepository: TransactionRepository = {
        return TransactionRepository(
            persistenceService: persistenceService,
            context: persistenceService.viewContext
        )
    }()

    lazy var tokenRepository: TokenRepository = {
        return TokenRepository(
            persistenceService: persistenceService,
            context: persistenceService.viewContext
        )
    }()

    lazy var nftRepository: NFTRepository = {
        return NFTRepository(
            persistenceService: persistenceService,
            context: persistenceService.viewContext
        )
    }()

    lazy var contactRepository: ContactRepository = {
        return ContactRepository(
            persistenceService: persistenceService,
            context: persistenceService.viewContext
        )
    }()

    // MARK: - View Models

    func makeWalletListViewModel() -> WalletListViewModel {
        return WalletListViewModel(
            walletService: walletService,
            portfolioService: portfolioService,
            priceService: priceService,
            analyticsService: analyticsService
        )
    }

    func makeWalletDetailViewModel(wallet: Wallet) -> WalletDetailViewModel {
        return WalletDetailViewModel(
            wallet: wallet,
            walletService: walletService,
            tokenService: tokenService,
            transactionService: transactionService,
            portfolioService: portfolioService,
            analyticsService: analyticsService
        )
    }

    func makeSendViewModel(wallet: Wallet) -> SendViewModel {
        return SendViewModel(
            wallet: wallet,
            walletService: walletService,
            transactionService: transactionService,
            gasEstimationService: gasEstimationService,
            addressValidationService: addressValidationService,
            contactRepository: contactRepository,
            analyticsService: analyticsService
        )
    }

    func makeReceiveViewModel(wallet: Wallet) -> ReceiveViewModel {
        return ReceiveViewModel(
            wallet: wallet,
            qrCodeService: qrCodeService,
            clipboardService: clipboardService,
            hapticService: hapticService,
            analyticsService: analyticsService
        )
    }

    func makeTransactionHistoryViewModel(wallet: Wallet) -> TransactionHistoryViewModel {
        return TransactionHistoryViewModel(
            wallet: wallet,
            transactionRepository: transactionRepository,
            transactionService: transactionService,
            analyticsService: analyticsService
        )
    }

    func makeTransactionDetailViewModel(transaction: Transaction) -> TransactionDetailViewModel {
        return TransactionDetailViewModel(
            transaction: transaction,
            blockchainService: blockchainService,
            clipboardService: clipboardService,
            analyticsService: analyticsService
        )
    }

    func makeTokenListViewModel(wallet: Wallet) -> TokenListViewModel {
        return TokenListViewModel(
            wallet: wallet,
            tokenService: tokenService,
            priceService: priceService,
            tokenRepository: tokenRepository,
            analyticsService: analyticsService
        )
    }

    func makeNFTGalleryViewModel(wallet: Wallet) -> NFTGalleryViewModel {
        return NFTGalleryViewModel(
            wallet: wallet,
            nftService: nftService,
            nftRepository: nftRepository,
            analyticsService: analyticsService
        )
    }

    func makeDAppBrowserViewModel() -> DAppBrowserViewModel {
        return DAppBrowserViewModel(
            dappBrowserService: dappBrowserService,
            walletConnectService: walletConnectService,
            securityService: securityService,
            analyticsService: analyticsService
        )
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        return SettingsViewModel(
            securityService: securityService,
            biometricService: biometricService,
            localizationService: localizationService,
            backupService: backupService,
            analyticsService: analyticsService
        )
    }

    func makeSecurityViewModel() -> SecurityViewModel {
        return SecurityViewModel(
            securityService: securityService,
            biometricService: biometricService,
            backupService: backupService,
            analyticsService: analyticsService
        )
    }

    func makeBackupViewModel() -> BackupViewModel {
        return BackupViewModel(
            backupService: backupService,
            cloudService: cloudService,
            securityService: securityService,
            analyticsService: analyticsService
        )
    }

    // MARK: - Cleanup

    func cleanup() {
        transactionMonitoringService.stopMonitoring()
        priceAlertService.stopMonitoring()
        cacheService.clearCache()
        persistenceService.saveContext()
    }
}
