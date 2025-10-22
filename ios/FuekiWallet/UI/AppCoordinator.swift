import Foundation
import SwiftUI
import Combine

class AppCoordinator: ObservableObject {
    @Published var isLoading = true
    @Published var hasCompletedOnboarding = false
    @Published var isUnlocked = false
    @Published var currentRoute: Route = .welcome
    @Published var error: AppError?

    private var cancellables = Set<AnyCancellable>()

    enum Route: Hashable {
        case welcome
        case createWallet
        case importWallet
        case mainTab
        case send
        case receive
        case settings
        case security
    }

    func initialize() {
        Task {
            // Check if wallet exists
            let hasWallet = await checkWalletExists()

            // Check if onboarding completed
            let onboardingComplete = UserDefaults.standard.bool(forKey: "onboardingCompleted")

            await MainActor.run {
                self.hasCompletedOnboarding = onboardingComplete && hasWallet
                self.isLoading = false
            }
        }
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        hasCompletedOnboarding = true
    }

    func unlock() {
        isUnlocked = true
    }

    func lockWallet() {
        isUnlocked = false
    }

    func navigate(to route: Route) {
        currentRoute = route
    }

    func showError(_ error: AppError) {
        self.error = error
    }

    func clearError() {
        self.error = nil
    }

    func reset() {
        hasCompletedOnboarding = false
        isUnlocked = false
        currentRoute = .welcome
        UserDefaults.standard.removeObject(forKey: "onboardingCompleted")
    }

    private func checkWalletExists() async -> Bool {
        // Check if wallet data exists in Keychain
        do {
            let secureStorage = SecureStorage.shared
            let hasWallet = try secureStorage.hasWallet()
            return hasWallet
        } catch {
            return false
        }
    }
}

// MARK: - App Error
enum AppError: LocalizedError, Identifiable {
    case walletCreationFailed(String)
    case walletImportFailed(String)
    case transactionFailed(String)
    case networkError(String)
    case biometricFailed(String)
    case unknown(String)

    var id: String {
        errorDescription ?? "unknown"
    }

    var errorDescription: String? {
        switch self {
        case .walletCreationFailed(let message):
            return "Wallet creation failed: \(message)"
        case .walletImportFailed(let message):
            return "Wallet import failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .biometricFailed(let message):
            return "Biometric authentication failed: \(message)"
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .walletCreationFailed, .walletImportFailed:
            return "Please try again or contact support if the issue persists."
        case .transactionFailed:
            return "Check your balance and network connection, then try again."
        case .networkError:
            return "Check your internet connection and try again."
        case .biometricFailed:
            return "Try using your PIN instead."
        case .unknown:
            return "Please try again."
        }
    }
}

// MARK: - Biometric Unlock View
struct BiometricUnlockView: View {
    @EnvironmentObject var appCoordinator: AppCoordinator
    @StateObject private var biometricAuth = BiometricAuth.shared
    @State private var showPINEntry = false

    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                VStack(spacing: 12) {
                    Text("Fueki Wallet")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Unlock to continue")
                        .font(.body)
                        .foregroundColor(.secondary)
                }

                CustomButton(
                    title: biometricAuth.biometricType == .faceID ? "Unlock with Face ID" : "Unlock with Touch ID",
                    icon: biometricAuth.biometricType == .faceID ? "faceid" : "touchid",
                    style: .primary
                ) {
                    authenticateWithBiometric()
                }
                .padding(.horizontal)

                Button("Use PIN") {
                    showPINEntry = true
                }
                .font(.body)
                .foregroundColor(.blue)
            }
        }
        .onAppear {
            authenticateWithBiometric()
        }
        .sheet(isPresented: $showPINEntry) {
            PINEntryView(onSuccess: {
                appCoordinator.unlock()
            })
        }
    }

    private func authenticateWithBiometric() {
        Task {
            let success = await biometricAuth.authenticate(reason: "Unlock Fueki Wallet")
            if success {
                await MainActor.run {
                    appCoordinator.unlock()
                }
            }
        }
    }
}
