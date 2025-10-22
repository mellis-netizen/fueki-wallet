//
//  SceneDelegate.swift
//  FuekiWallet
//
//  Created by Fueki Wallet Team
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Get dependency container from AppDelegate
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        window = UIWindow(windowScene: windowScene)

        // Create and start app coordinator
        appCoordinator = AppCoordinator(
            window: window!,
            dependencyContainer: appDelegate.dependencyContainer
        )

        appCoordinator?.start()
        window?.makeKeyAndVisible()

        // Handle deep links
        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(urlContext.url)
        }

        // Handle shortcuts
        if let shortcutItem = connectionOptions.shortcutItem {
            handleShortcut(shortcutItem)
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Clean up resources specific to this scene
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Resume scene-specific tasks
        appCoordinator?.sceneDidBecomeActive()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Pause scene-specific tasks
        appCoordinator?.sceneWillResignActive()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Prepare UI for foreground
        appCoordinator?.sceneWillEnterForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save scene-specific data
        appCoordinator?.sceneDidEnterBackground()
    }

    // MARK: - Deep Links

    func scene(
        _ scene: UIScene,
        openURLContexts URLContexts: Set<UIOpenURLContext>
    ) {
        guard let url = URLContexts.first?.url else { return }
        handleDeepLink(url)
    }

    private func handleDeepLink(_ url: URL) {
        // Parse deep link
        // fueki://wallet/send?address=0x123&amount=1.5
        // fueki://wallet/receive
        // fueki://settings
        // fueki://transaction/0xabc...

        guard url.scheme == "fueki" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        guard let host = components?.host else { return }

        switch host {
        case "wallet":
            handleWalletDeepLink(url, components: components)

        case "transaction":
            if let txHash = components?.path.replacingOccurrences(of: "/", with: "") {
                appCoordinator?.showTransactionDetails(txHash)
            }

        case "settings":
            appCoordinator?.navigateToSettings()

        case "dapp":
            handleDAppDeepLink(url, components: components)

        default:
            break
        }
    }

    private func handleWalletDeepLink(_ url: URL, components: URLComponents?) {
        guard let path = components?.path else { return }

        switch path {
        case "/send":
            if let queryItems = components?.queryItems {
                var address: String?
                var amount: String?
                var token: String?

                for item in queryItems {
                    switch item.name {
                    case "address":
                        address = item.value
                    case "amount":
                        amount = item.value
                    case "token":
                        token = item.value
                    default:
                        break
                    }
                }

                appCoordinator?.navigateToSend(
                    address: address,
                    amount: amount,
                    token: token
                )
            }

        case "/receive":
            appCoordinator?.navigateToReceive()

        default:
            break
        }
    }

    private func handleDAppDeepLink(_ url: URL, components: URLComponents?) {
        guard let dappURL = components?.queryItems?.first(where: { $0.name == "url" })?.value else {
            return
        }

        appCoordinator?.openDApp(dappURL)
    }

    // MARK: - Quick Actions

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = handleShortcut(shortcutItem)
        completionHandler(handled)
    }

    @discardableResult
    private func handleShortcut(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        switch shortcutItem.type {
        case "com.fueki.wallet.send":
            appCoordinator?.navigateToSend(address: nil, amount: nil, token: nil)
            return true

        case "com.fueki.wallet.receive":
            appCoordinator?.navigateToReceive()
            return true

        case "com.fueki.wallet.scan":
            appCoordinator?.navigateToQRScanner()
            return true

        case "com.fueki.wallet.portfolio":
            appCoordinator?.navigateToPortfolio()
            return true

        default:
            return false
        }
    }

    // MARK: - Handoff

    func scene(
        _ scene: UIScene,
        continue userActivity: NSUserActivity
    ) {
        handleUserActivity(userActivity)
    }

    private func handleUserActivity(_ userActivity: NSUserActivity) {
        switch userActivity.activityType {
        case NSUserActivityTypeBrowsingWeb:
            if let url = userActivity.webpageURL {
                handleUniversalLink(url)
            }

        case "com.fueki.wallet.view-transaction":
            if let txHash = userActivity.userInfo?["txHash"] as? String {
                appCoordinator?.showTransactionDetails(txHash)
            }

        case "com.fueki.wallet.view-token":
            if let tokenSymbol = userActivity.userInfo?["symbol"] as? String {
                appCoordinator?.showTokenDetails(tokenSymbol)
            }

        default:
            break
        }
    }

    private func handleUniversalLink(_ url: URL) {
        // Handle https://fueki.io/... links
        // Convert to deep link and handle
        if let deepLink = convertUniversalLinkToDeepLink(url) {
            handleDeepLink(deepLink)
        }
    }

    private func convertUniversalLinkToDeepLink(_ url: URL) -> URL? {
        // Convert https://fueki.io/wallet/send to fueki://wallet/send
        guard url.host == "fueki.io" else { return nil }

        var components = URLComponents()
        components.scheme = "fueki"
        components.host = url.pathComponents.dropFirst().first
        components.path = "/" + url.pathComponents.dropFirst(2).joined(separator: "/")
        components.queryItems = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems

        return components.url
    }

    // MARK: - State Restoration

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
}
