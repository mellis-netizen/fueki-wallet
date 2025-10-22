//
//  AppDelegate.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import UIKit
import UserNotifications
import FirebaseCore
import FirebaseMessaging

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var dependencyContainer: DependencyContainer!
    var appCoordinator: AppCoordinator!

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // Initialize dependency container
        dependencyContainer = DependencyContainer()

        // Configure Firebase
        FirebaseApp.configure()

        // Configure push notifications
        configurePushNotifications(application)

        // Configure appearance
        configureAppearance()

        // Initialize Core Data
        initializeCoreData()

        // Configure crash reporting
        configureCrashReporting()

        // Configure analytics
        configureAnalytics()

        // Set up app coordinator
        setupAppCoordinator()

        return true
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Handle scene session disposal
    }

    // MARK: - Push Notifications

    private func configurePushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self

        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("Push notification authorization error: \(error)")
                }

                if granted {
                    DispatchQueue.main.async {
                        application.registerForRemoteNotifications()
                    }
                }
            }
        )

        Messaging.messaging().delegate = self
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken

        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")

        // Store token in secure storage
        dependencyContainer.securityService.storeDeviceToken(token)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("Failed to register for remote notifications: \(error)")
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Handle remote notification
        handleRemoteNotification(userInfo)
        completionHandler(.newData)
    }

    // MARK: - App Lifecycle

    func applicationWillResignActive(_ application: UIApplication) {
        // Pause ongoing tasks
        dependencyContainer.transactionMonitoringService.pauseMonitoring()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Save application state
        dependencyContainer.persistenceService.saveContext()

        // Clear sensitive data from memory
        dependencyContainer.securityService.clearSensitiveData()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Refresh data
        dependencyContainer.blockchainService.syncLatestBlock()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Resume monitoring
        dependencyContainer.transactionMonitoringService.resumeMonitoring()

        // Check for app updates
        checkForAppUpdates()

        // Refresh exchange rates
        dependencyContainer.priceService.refreshPrices()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Save final state
        dependencyContainer.persistenceService.saveContext()

        // Clean up resources
        dependencyContainer.cleanup()
    }

    // MARK: - Setup

    private func setupAppCoordinator() {
        window = UIWindow(frame: UIScreen.main.bounds)

        appCoordinator = AppCoordinator(
            window: window!,
            dependencyContainer: dependencyContainer
        )

        appCoordinator.start()
        window?.makeKeyAndVisible()
    }

    private func configureAppearance() {
        // Apply theme
        Theme.apply()

        // Configure navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.Colors.background
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.Colors.text,
            .font: Theme.Fonts.headline
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Configure tab bar
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = Theme.Colors.surface

        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }

    private func initializeCoreData() {
        _ = dependencyContainer.persistenceService.persistentContainer
    }

    private func configureCrashReporting() {
        // Configure Crashlytics or Sentry
        #if !DEBUG
        // Production crash reporting
        #endif
    }

    private func configureAnalytics() {
        dependencyContainer.analyticsService.initialize()
        dependencyContainer.analyticsService.trackEvent(
            .appLaunched,
            properties: [
                "version": AppConfiguration.appVersion,
                "environment": AppConfiguration.environment.rawValue
            ]
        )
    }

    private func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) {
        // Parse notification type
        guard let notificationType = userInfo["type"] as? String else { return }

        switch notificationType {
        case "transaction":
            if let txHash = userInfo["txHash"] as? String {
                dependencyContainer.notificationService.handleTransactionNotification(txHash)
            }

        case "price_alert":
            if let symbol = userInfo["symbol"] as? String,
               let price = userInfo["price"] as? Double {
                dependencyContainer.notificationService.handlePriceAlert(symbol: symbol, price: price)
            }

        case "security":
            dependencyContainer.notificationService.handleSecurityAlert(userInfo)

        default:
            break
        }
    }

    private func checkForAppUpdates() {
        dependencyContainer.updateService.checkForUpdates { result in
            switch result {
            case .success(let update):
                if update.isRequired {
                    // Show force update alert
                    self.showForceUpdateAlert(update)
                } else if update.isAvailable {
                    // Show optional update prompt
                    self.showUpdatePrompt(update)
                }

            case .failure(let error):
                print("Update check failed: \(error)")
            }
        }
    }

    private func showForceUpdateAlert(_ update: AppUpdate) {
        let alert = UIAlertController(
            title: "Update Required",
            message: "A new version of Fueki Wallet is required to continue. Please update now.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            self.openAppStore()
        })

        window?.rootViewController?.present(alert, animated: true)
    }

    private func showUpdatePrompt(_ update: AppUpdate) {
        let alert = UIAlertController(
            title: "Update Available",
            message: "A new version of Fueki Wallet is available with new features and improvements.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            self.openAppStore()
        })

        alert.addAction(UIAlertAction(title: "Later", style: .cancel))

        window?.rootViewController?.present(alert, animated: true)
    }

    private func openAppStore() {
        if let url = URL(string: AppConfiguration.appStoreURL) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        handleRemoteNotification(userInfo)
        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let token = fcmToken else { return }

        print("FCM Token: \(token)")

        // Store FCM token
        dependencyContainer.securityService.storeFCMToken(token)

        // Send token to backend
        dependencyContainer.apiService.updateFCMToken(token) { result in
            switch result {
            case .success:
                print("FCM token updated on server")
            case .failure(let error):
                print("Failed to update FCM token: \(error)")
            }
        }
    }
}
