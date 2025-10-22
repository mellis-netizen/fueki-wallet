import SwiftUI
import Combine

@main
struct FuekiWalletApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var walletManager = WalletManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    init() {
        // Configure app appearance
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appCoordinator.isLoading {
                    LoadingView(message: "Initializing Fueki Wallet...")
                } else if !appCoordinator.hasCompletedOnboarding {
                    WelcomeView()
                } else if !appCoordinator.isUnlocked {
                    BiometricUnlockView()
                } else {
                    MainTabView()
                }
            }
            .environmentObject(appCoordinator)
            .environmentObject(walletManager)
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.colorScheme)
            .onAppear {
                appCoordinator.initialize()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                appCoordinator.lockWallet()
            }
        }
    }

    private func configureAppearance() {
        // Navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        // Tab bar appearance
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var colorScheme: ColorScheme? = nil
    @Published var accentColor: Color = .blue

    private init() {
        loadThemePreferences()
    }

    private func loadThemePreferences() {
        // Load from UserDefaults
        if let savedTheme = UserDefaults.standard.string(forKey: "theme") {
            switch savedTheme {
            case "dark":
                colorScheme = .dark
            case "light":
                colorScheme = .light
            default:
                colorScheme = nil
            }
        }
    }

    func setTheme(_ theme: String) {
        UserDefaults.standard.set(theme, forKey: "theme")
        switch theme {
        case "dark":
            colorScheme = .dark
        case "light":
            colorScheme = .light
        default:
            colorScheme = nil
        }
    }
}
