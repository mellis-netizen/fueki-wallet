//
//  FuekiWalletApp.swift
//  Fueki Wallet
//
//  Main application entry point with SwiftUI lifecycle
//

import SwiftUI
import Combine

@main
struct FuekiWalletApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var authViewModel = AuthenticationViewModel()
    @StateObject private var walletViewModel = WalletViewModel()

    init() {
        // Configure app appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(authViewModel)
                .environmentObject(walletViewModel)
                .onAppear {
                    // Initialize app services
                    Task {
                        await initializeServices()
                    }
                }
        }
    }

    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "BackgroundPrimary")
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(named: "TextPrimary") ?? .label
        ]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance

        // Configure tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(named: "BackgroundSecondary")

        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }

    private func initializeServices() async {
        // Initialize wallet services
        await walletViewModel.initialize()

        // Check authentication status
        await authViewModel.checkAuthStatus()

        // Setup biometric authentication if available
        await authViewModel.setupBiometrics()
    }
}

// MARK: - App State Management
class AppState: ObservableObject {
    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var selectedTab: Tab = .wallet

    enum Tab {
        case wallet
        case transactions
        case send
        case receive
        case settings
    }

    func showErrorAlert(message: String) {
        errorMessage = message
        showError = true
    }
}
