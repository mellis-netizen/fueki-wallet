//
//  AuthenticationViewModel.swift
//  Fueki Wallet
//
//  Authentication ViewModel with social sign-on and biometrics
//

import SwiftUI
import Combine
import AuthenticationServices
import LocalAuthentication

@MainActor
class AuthenticationViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var hasSeenOnboarding = false
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var biometricType: BiometricType = .none
    @Published var errorMessage: String?

    private var cancellables = Set<AnyCancellable>()
    private let authService: AuthenticationService
    private let keychainService: KeychainService
    private let biometricService: BiometricService

    // State management integration
    private let appState = AppState.shared
    private let stateManager = StateManager.shared

    enum BiometricType {
        case none
        case touchID
        case faceID
    }

    init(
        authService: AuthenticationService = .shared,
        keychainService: KeychainService = .shared,
        biometricService: BiometricService = .shared
    ) {
        self.authService = authService
        self.keychainService = keychainService
        self.biometricService = biometricService

        // Load saved preferences
        loadUserPreferences()

        // Sync with AppState
        syncWithAppState()
    }

    // MARK: - Initialization

    func checkAuthStatus() async {
        isLoading = true

        // Check for stored auth token
        if let token = keychainService.getAuthToken() {
            do {
                let isValid = try await authService.validateToken(token)
                if isValid {
                    isAuthenticated = true
                    await loadUserProfile()
                }
            } catch {
                print("Token validation failed: \(error)")
            }
        }

        isLoading = false
    }

    func setupBiometrics() async {
        biometricType = biometricService.detectBiometricType()
    }

    // MARK: - Social Sign-In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await authService.signInWithGoogle()
            await handleSuccessfulAuth(result)
        } catch {
            errorMessage = "Google sign-in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func signInWithFacebook() async {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await authService.signInWithFacebook()
            await handleSuccessfulAuth(result)
        } catch {
            errorMessage = "Facebook sign-in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func handleAppleSignIn(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    func handleAppleSignInCompletion(result: Result<ASAuthorization, Error>) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                do {
                    let authResult = try await authService.signInWithApple(
                        credential: appleIDCredential
                    )
                    await handleSuccessfulAuth(authResult)
                } catch {
                    errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
                }
            }

        case .failure(let error):
            errorMessage = "Apple sign-in failed: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Biometric Authentication

    func authenticateWithBiometrics() async {
        do {
            let success = try await biometricService.authenticate(
                reason: "Authenticate to access your wallet"
            )

            if success {
                // Re-authenticate with stored credentials
                if let token = keychainService.getAuthToken() {
                    let isValid = try await authService.validateToken(token)
                    if isValid {
                        isAuthenticated = true
                        await loadUserProfile()
                    }
                }
            }
        } catch {
            errorMessage = "Biometric authentication failed"
        }
    }

    func setBiometricEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let success = try await biometricService.authenticate(
                    reason: "Enable biometric authentication"
                )
                if success {
                    UserDefaults.standard.set(true, forKey: "biometric_enabled")
                }
            } catch {
                errorMessage = "Failed to enable biometric authentication"
            }
        } else {
            UserDefaults.standard.set(false, forKey: "biometric_enabled")
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        keychainService.deleteAuthToken()
        keychainService.deleteWalletKeys()

        isAuthenticated = false
        userName = nil
        userEmail = nil

        // Update AppState
        await stateManager.execute(
            StateAction(name: "logout", category: .auth)
        ) {
            self.appState.authState.logout()
        }
    }

    // MARK: - Onboarding

    func completeOnboarding() {
        hasSeenOnboarding = true
        UserDefaults.standard.set(true, forKey: "has_seen_onboarding")
    }

    // MARK: - Private Methods

    private func handleSuccessfulAuth(_ result: AuthResult) async {
        // Store auth token
        keychainService.saveAuthToken(result.token)

        // Update user info
        userName = result.name
        userEmail = result.email

        // Save to UserDefaults
        UserDefaults.standard.set(result.name, forKey: "user_name")
        UserDefaults.standard.set(result.email, forKey: "user_email")

        isAuthenticated = true

        // Update AppState with authenticated user
        let user = User(id: UUID().uuidString, name: result.name, email: result.email)
        await stateManager.execute(
            StateAction(name: "login", category: .auth)
        ) {
            self.appState.authState.login(user: user, token: result.token, method: .google)
        }

        // Initialize wallet
        await initializeWallet()
    }

    private func loadUserProfile() async {
        do {
            let profile = try await authService.getUserProfile()
            userName = profile.name
            userEmail = profile.email
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }

    private func loadUserPreferences() {
        hasSeenOnboarding = UserDefaults.standard.bool(forKey: "has_seen_onboarding")
        userName = UserDefaults.standard.string(forKey: "user_name")
        userEmail = UserDefaults.standard.string(forKey: "user_email")
    }

    private func initializeWallet() async {
        // Initialize wallet keys if needed
        if !keychainService.hasWalletKeys() {
            do {
                try await authService.generateWalletKeys()
            } catch {
                print("Failed to generate wallet keys: \(error)")
            }
        }
    }

    // MARK: - State Synchronization

    private func syncWithAppState() {
        // Observe auth state changes from AppState
        appState.authState.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuth in
                self?.isAuthenticated = isAuth
            }
            .store(in: &cancellables)

        appState.authState.$currentUser
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.userName = user?.name
                self?.userEmail = user?.email
            }
            .store(in: &cancellables)

        // Observe error state
        appState.$errorState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorState in
                self?.errorMessage = errorState?.message
            }
            .store(in: &cancellables)

        // Observe loading state
        appState.$loadingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loadingState in
                if case .loading = loadingState {
                    self?.isLoading = true
                } else {
                    self?.isLoading = false
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Authentication Service (Mock Implementation)
class AuthenticationService {
    static let shared = AuthenticationService()

    func validateToken(_ token: String) async throws -> Bool {
        // TODO: Implement real token validation
        try await Task.sleep(nanoseconds: 500_000_000)
        return !token.isEmpty
    }

    func signInWithGoogle() async throws -> AuthResult {
        // TODO: Implement Google Sign-In SDK
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return AuthResult(
            token: UUID().uuidString,
            name: "John Doe",
            email: "john@example.com"
        )
    }

    func signInWithFacebook() async throws -> AuthResult {
        // TODO: Implement Facebook SDK
        try await Task.sleep(nanoseconds: 1_000_000_000)
        return AuthResult(
            token: UUID().uuidString,
            name: "John Doe",
            email: "john@example.com"
        )
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential) async throws -> AuthResult {
        // TODO: Implement Apple Sign-In backend validation
        try await Task.sleep(nanoseconds: 1_000_000_000)

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        return AuthResult(
            token: UUID().uuidString,
            name: name.isEmpty ? "User" : name,
            email: credential.email ?? "user@icloud.com"
        )
    }

    func getUserProfile() async throws -> UserProfile {
        // TODO: Implement profile fetch
        try await Task.sleep(nanoseconds: 500_000_000)
        return UserProfile(name: "John Doe", email: "john@example.com")
    }

    func generateWalletKeys() async throws {
        // TODO: Implement wallet key generation
        try await Task.sleep(nanoseconds: 500_000_000)
    }
}

// MARK: - Biometric Service
class BiometricService {
    static let shared = BiometricService()
    private let context = LAContext()

    func detectBiometricType() -> AuthenticationViewModel.BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? NSError(domain: "BiometricService", code: -1)
        }

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}

// MARK: - Keychain Service
class KeychainService {
    static let shared = KeychainService()

    func saveAuthToken(_ token: String) {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "auth_token",
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    func getAuthToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "auth_token",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    func deleteAuthToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "auth_token"
        ]
        SecItemDelete(query as CFDictionary)
    }

    func hasWalletKeys() -> Bool {
        // TODO: Check for wallet keys in keychain
        return false
    }

    func deleteWalletKeys() {
        // TODO: Delete wallet keys from keychain
    }
}

// MARK: - Models
struct AuthResult {
    let token: String
    let name: String
    let email: String
}

struct UserProfile {
    let name: String
    let email: String
}
