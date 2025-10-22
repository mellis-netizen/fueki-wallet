//
//  AppCoordinator.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import UIKit

protocol Coordinator: AnyObject {
    var childCoordinators: [Coordinator] { get set }
    var navigationController: UINavigationController { get set }

    func start()
    func coordinate(to coordinator: Coordinator)
    func removeChildCoordinator(_ coordinator: Coordinator)
}

extension Coordinator {
    func coordinate(to coordinator: Coordinator) {
        childCoordinators.append(coordinator)
        coordinator.start()
    }

    func removeChildCoordinator(_ coordinator: Coordinator) {
        childCoordinators = childCoordinators.filter { $0 !== coordinator }
    }
}

class AppCoordinator: Coordinator {

    var childCoordinators: [Coordinator] = []
    var navigationController: UINavigationController

    private let window: UIWindow
    private let dependencyContainer: DependencyContainer
    private var tabBarController: UITabBarController?

    // MARK: - Initialization

    init(window: UIWindow, dependencyContainer: DependencyContainer) {
        self.window = window
        self.dependencyContainer = dependencyContainer
        self.navigationController = UINavigationController()
    }

    // MARK: - Start

    func start() {
        // Check if user needs onboarding
        if shouldShowOnboarding() {
            showOnboarding()
        } else if shouldShowPINEntry() {
            showPINEntry()
        } else {
            showMainInterface()
        }
    }

    // MARK: - Onboarding Flow

    private func shouldShowOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    private func showOnboarding() {
        let onboardingCoordinator = OnboardingCoordinator(
            navigationController: navigationController,
            dependencyContainer: dependencyContainer
        )

        onboardingCoordinator.delegate = self
        coordinate(to: onboardingCoordinator)

        window.rootViewController = navigationController
    }

    // MARK: - Authentication Flow

    private func shouldShowPINEntry() -> Bool {
        return dependencyContainer.securityService.isPINSet()
    }

    private func showPINEntry() {
        let authCoordinator = AuthenticationCoordinator(
            navigationController: navigationController,
            dependencyContainer: dependencyContainer
        )

        authCoordinator.delegate = self
        coordinate(to: authCoordinator)

        window.rootViewController = navigationController
    }

    // MARK: - Main Interface

    private func showMainInterface() {
        let tabBarController = UITabBarController()
        self.tabBarController = tabBarController

        // Wallet Tab
        let walletNavigationController = UINavigationController()
        let walletCoordinator = WalletCoordinator(
            navigationController: walletNavigationController,
            dependencyContainer: dependencyContainer
        )
        coordinate(to: walletCoordinator)
        walletNavigationController.tabBarItem = UITabBarItem(
            title: "Wallet",
            image: UIImage(systemName: "wallet.pass"),
            selectedImage: UIImage(systemName: "wallet.pass.fill")
        )

        // DApp Browser Tab
        let dappNavigationController = UINavigationController()
        let dappCoordinator = DAppCoordinator(
            navigationController: dappNavigationController,
            dependencyContainer: dependencyContainer
        )
        coordinate(to: dappCoordinator)
        dappNavigationController.tabBarItem = UITabBarItem(
            title: "Browser",
            image: UIImage(systemName: "safari"),
            selectedImage: UIImage(systemName: "safari.fill")
        )

        // Portfolio Tab
        let portfolioNavigationController = UINavigationController()
        let portfolioCoordinator = PortfolioCoordinator(
            navigationController: portfolioNavigationController,
            dependencyContainer: dependencyContainer
        )
        coordinate(to: portfolioCoordinator)
        portfolioNavigationController.tabBarItem = UITabBarItem(
            title: "Portfolio",
            image: UIImage(systemName: "chart.pie"),
            selectedImage: UIImage(systemName: "chart.pie.fill")
        )

        // Settings Tab
        let settingsNavigationController = UINavigationController()
        let settingsCoordinator = SettingsCoordinator(
            navigationController: settingsNavigationController,
            dependencyContainer: dependencyContainer
        )
        coordinate(to: settingsCoordinator)
        settingsNavigationController.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        tabBarController.viewControllers = [
            walletNavigationController,
            dappNavigationController,
            portfolioNavigationController,
            settingsNavigationController
        ]

        window.rootViewController = tabBarController
    }

    // MARK: - Scene Lifecycle

    func sceneDidBecomeActive() {
        // Resume services
        dependencyContainer.transactionMonitoringService.resumeMonitoring()
        dependencyContainer.priceService.startAutoRefresh()

        // Refresh data
        refreshData()
    }

    func sceneWillResignActive() {
        // Pause services
        dependencyContainer.transactionMonitoringService.pauseMonitoring()
        dependencyContainer.priceService.stopAutoRefresh()
    }

    func sceneWillEnterForeground() {
        // Check if re-authentication is needed
        if shouldRequireAuthentication() {
            showAuthenticationOverlay()
        }
    }

    func sceneDidEnterBackground() {
        // Save state
        dependencyContainer.persistenceService.saveContext()

        // Show privacy screen
        showPrivacyScreen()
    }

    // MARK: - Navigation

    func navigateToSend(address: String?, amount: String?, token: String?) {
        guard let walletCoordinator = childCoordinators.first(where: { $0 is WalletCoordinator }) as? WalletCoordinator else {
            return
        }

        tabBarController?.selectedIndex = 0
        walletCoordinator.navigateToSend(address: address, amount: amount, token: token)
    }

    func navigateToReceive() {
        guard let walletCoordinator = childCoordinators.first(where: { $0 is WalletCoordinator }) as? WalletCoordinator else {
            return
        }

        tabBarController?.selectedIndex = 0
        walletCoordinator.navigateToReceive()
    }

    func navigateToQRScanner() {
        guard let walletCoordinator = childCoordinators.first(where: { $0 is WalletCoordinator }) as? WalletCoordinator else {
            return
        }

        tabBarController?.selectedIndex = 0
        walletCoordinator.navigateToQRScanner()
    }

    func navigateToPortfolio() {
        tabBarController?.selectedIndex = 2
    }

    func navigateToSettings() {
        tabBarController?.selectedIndex = 3
    }

    func showTransactionDetails(_ txHash: String) {
        guard let walletCoordinator = childCoordinators.first(where: { $0 is WalletCoordinator }) as? WalletCoordinator else {
            return
        }

        tabBarController?.selectedIndex = 0
        walletCoordinator.showTransactionDetails(txHash)
    }

    func showTokenDetails(_ tokenSymbol: String) {
        guard let walletCoordinator = childCoordinators.first(where: { $0 is WalletCoordinator }) as? WalletCoordinator else {
            return
        }

        tabBarController?.selectedIndex = 0
        walletCoordinator.showTokenDetails(tokenSymbol)
    }

    func openDApp(_ url: String) {
        guard let dappCoordinator = childCoordinators.first(where: { $0 is DAppCoordinator }) as? DAppCoordinator else {
            return
        }

        tabBarController?.selectedIndex = 1
        dappCoordinator.openURL(url)
    }

    // MARK: - Authentication

    private func shouldRequireAuthentication() -> Bool {
        let lastBackgroundTime = UserDefaults.standard.double(forKey: "lastBackgroundTime")
        let authTimeout = AppConfiguration.authenticationTimeout
        let timeSinceBackground = Date().timeIntervalSince1970 - lastBackgroundTime

        return timeSinceBackground > authTimeout
    }

    private func showAuthenticationOverlay() {
        let authVC = AuthenticationViewController(
            mode: .unlock,
            dependencyContainer: dependencyContainer
        )

        authVC.onSuccess = { [weak self] in
            self?.dismissAuthenticationOverlay()
        }

        authVC.modalPresentationStyle = .fullScreen
        window.rootViewController?.present(authVC, animated: false)
    }

    private func dismissAuthenticationOverlay() {
        window.rootViewController?.dismiss(animated: true)
    }

    private func showPrivacyScreen() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastBackgroundTime")

        let privacyView = UIView(frame: window.bounds)
        privacyView.backgroundColor = Theme.Colors.background
        privacyView.tag = 999

        let logoImageView = UIImageView(image: UIImage(named: "AppLogo"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        privacyView.addSubview(logoImageView)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: privacyView.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: privacyView.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120)
        ])

        window.addSubview(privacyView)
    }

    private func removePrivacyScreen() {
        window.subviews.first(where: { $0.tag == 999 })?.removeFromSuperview()
    }

    // MARK: - Data Refresh

    private func refreshData() {
        dependencyContainer.blockchainService.syncLatestBlock()
        dependencyContainer.priceService.refreshPrices()
        dependencyContainer.portfolioService.refreshPortfolio()
    }

    // MARK: - Alerts

    func showAlert(title: String, message: String, style: UIAlertController.Style = .alert) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: style)
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        window.rootViewController?.present(alert, animated: true)
    }

    func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))

        window.rootViewController?.present(alert, animated: true)
    }
}

// MARK: - OnboardingCoordinatorDelegate

extension AppCoordinator: OnboardingCoordinatorDelegate {
    func onboardingCoordinatorDidComplete(_ coordinator: OnboardingCoordinator) {
        removeChildCoordinator(coordinator)
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        showMainInterface()
    }

    func onboardingCoordinatorDidCancel(_ coordinator: OnboardingCoordinator) {
        removeChildCoordinator(coordinator)
        // Handle cancellation if needed
    }
}

// MARK: - AuthenticationCoordinatorDelegate

extension AppCoordinator: AuthenticationCoordinatorDelegate {
    func authenticationCoordinatorDidAuthenticate(_ coordinator: AuthenticationCoordinator) {
        removeChildCoordinator(coordinator)
        removePrivacyScreen()
        showMainInterface()
    }

    func authenticationCoordinatorDidFail(_ coordinator: AuthenticationCoordinator, error: Error) {
        removeChildCoordinator(coordinator)
        showError(error)
    }
}

// MARK: - Coordinator Delegates

protocol OnboardingCoordinatorDelegate: AnyObject {
    func onboardingCoordinatorDidComplete(_ coordinator: OnboardingCoordinator)
    func onboardingCoordinatorDidCancel(_ coordinator: OnboardingCoordinator)
}

protocol AuthenticationCoordinatorDelegate: AnyObject {
    func authenticationCoordinatorDidAuthenticate(_ coordinator: AuthenticationCoordinator)
    func authenticationCoordinatorDidFail(_ coordinator: AuthenticationCoordinator, error: Error)
}
