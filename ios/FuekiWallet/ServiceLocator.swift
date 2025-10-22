//
//  ServiceLocator.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import Foundation

class ServiceLocator {

    static let shared = ServiceLocator()

    private var services: [String: Any] = [:]
    private let queue = DispatchQueue(label: "com.fueki.servicelocator", attributes: .concurrent)

    private init() {}

    // MARK: - Registration

    func register<T>(_ service: T, for type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services[key] = service
        }
    }

    func register<T>(_ factory: @escaping () -> T, for type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services[key] = factory()
        }
    }

    // MARK: - Resolution

    func resolve<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        return queue.sync {
            return services[key] as? T
        }
    }

    func resolve<T>(_ type: T.Type) -> T {
        guard let service: T = resolve(type) else {
            fatalError("Service of type \(type) not registered")
        }
        return service
    }

    // MARK: - Unregistration

    func unregister<T>(_ type: T.Type) {
        let key = String(describing: type)
        queue.async(flags: .barrier) {
            self.services.removeValue(forKey: key)
        }
    }

    func reset() {
        queue.async(flags: .barrier) {
            self.services.removeAll()
        }
    }
}

// MARK: - Property Wrapper

@propertyWrapper
struct Injected<T> {
    private var service: T?

    var wrappedValue: T {
        mutating get {
            if service == nil {
                service = ServiceLocator.shared.resolve(T.self)
            }
            return service!
        }
        mutating set {
            service = newValue
        }
    }

    init() {}
}

// MARK: - Convenience Extensions

extension ServiceLocator {

    func registerDefaultServices(container: DependencyContainer) {
        // Core Services
        register(container.networkingService, for: NetworkingServiceProtocol.self)
        register(container.persistenceService, for: PersistenceServiceProtocol.self)
        register(container.securityService, for: SecurityServiceProtocol.self)
        register(container.keychainService, for: KeychainServiceProtocol.self)
        register(container.biometricService, for: BiometricServiceProtocol.self)
        register(container.encryptionService, for: EncryptionServiceProtocol.self)

        // Blockchain Services
        register(container.blockchainService, for: BlockchainServiceProtocol.self)
        register(container.walletService, for: WalletServiceProtocol.self)
        register(container.transactionService, for: TransactionServiceProtocol.self)
        register(container.gasEstimationService, for: GasEstimationServiceProtocol.self)
        register(container.tokenService, for: TokenServiceProtocol.self)
        register(container.nftService, for: NFTServiceProtocol.self)

        // DApp Services
        register(container.dappBrowserService, for: DAppBrowserServiceProtocol.self)
        register(container.web3Bridge, for: Web3BridgeProtocol.self)
        register(container.signatureService, for: SignatureServiceProtocol.self)
        register(container.walletConnectService, for: WalletConnectServiceProtocol.self)

        // Market Data Services
        register(container.priceService, for: PriceServiceProtocol.self)
        register(container.chartService, for: ChartServiceProtocol.self)
        register(container.portfolioService, for: PortfolioServiceProtocol.self)

        // Notification Services
        register(container.notificationService, for: NotificationServiceProtocol.self)
        register(container.transactionMonitoringService, for: TransactionMonitoringServiceProtocol.self)
        register(container.priceAlertService, for: PriceAlertServiceProtocol.self)

        // Utility Services
        register(container.cacheService, for: CacheServiceProtocol.self)
        register(container.analyticsService, for: AnalyticsServiceProtocol.self)
        register(container.imageService, for: ImageServiceProtocol.self)
        register(container.qrCodeService, for: QRCodeServiceProtocol.self)
        register(container.clipboardService, for: ClipboardServiceProtocol.self)
        register(container.hapticService, for: HapticServiceProtocol.self)
        register(container.localizationService, for: LocalizationServiceProtocol.self)

        // API Services
        register(container.apiService, for: APIServiceProtocol.self)
        register(container.authService, for: AuthServiceProtocol.self)
        register(container.updateService, for: UpdateServiceProtocol.self)

        // Backup & Recovery Services
        register(container.backupService, for: BackupServiceProtocol.self)
        register(container.cloudService, for: CloudServiceProtocol.self)
        register(container.recoveryService, for: RecoveryServiceProtocol.self)

        // Security Services
        register(container.fraudDetectionService, for: FraudDetectionServiceProtocol.self)
        register(container.addressValidationService, for: AddressValidationServiceProtocol.self)

        // Repositories
        register(container.walletRepository, for: WalletRepository.self)
        register(container.transactionRepository, for: TransactionRepository.self)
        register(container.tokenRepository, for: TokenRepository.self)
        register(container.nftRepository, for: NFTRepository.self)
        register(container.contactRepository, for: ContactRepository.self)
    }
}
