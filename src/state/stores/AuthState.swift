//
//  AuthState.swift
//  Fueki Wallet
//
//  Authentication state management
//

import Foundation
import Combine
import SwiftUI

@MainActor
class AuthState: ObservableObject {
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var biometricEnabled = false
    @Published var sessionToken: String?
    @Published var sessionExpiry: Date?
    @Published var authMethod: AuthMethod?

    // MARK: - Properties
    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?

    // MARK: - Initialization
    init() {
        setupSessionMonitoring()
    }

    // MARK: - State Management

    func login(user: User, token: String, method: AuthMethod) {
        currentUser = user
        sessionToken = token
        authMethod = method
        isAuthenticated = true
        sessionExpiry = Date().addingTimeInterval(3600) // 1 hour

        startSessionTimer()
        notifyStateChange()
    }

    func logout() {
        reset()
        notifyStateChange()
    }

    func refreshSession(token: String) {
        sessionToken = token
        sessionExpiry = Date().addingTimeInterval(3600)
        startSessionTimer()
    }

    func updateBiometricState(_ enabled: Bool) {
        biometricEnabled = enabled
        notifyStateChange()
    }

    func reset() {
        isAuthenticated = false
        currentUser = nil
        sessionToken = nil
        sessionExpiry = nil
        authMethod = nil
        biometricEnabled = false
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    // MARK: - Snapshot Management

    func createSnapshot() -> AuthStateSnapshot {
        AuthStateSnapshot(
            isAuthenticated: isAuthenticated,
            userId: currentUser?.id,
            userName: currentUser?.name,
            userEmail: currentUser?.email,
            biometricEnabled: biometricEnabled,
            authMethod: authMethod,
            sessionExpiry: sessionExpiry
        )
    }

    func restore(from snapshot: AuthStateSnapshot) async {
        isAuthenticated = snapshot.isAuthenticated
        biometricEnabled = snapshot.biometricEnabled
        authMethod = snapshot.authMethod
        sessionExpiry = snapshot.sessionExpiry

        if let userId = snapshot.userId,
           let userName = snapshot.userName,
           let userEmail = snapshot.userEmail {
            currentUser = User(
                id: userId,
                name: userName,
                email: userEmail
            )
        }

        // Validate session hasn't expired
        if let expiry = sessionExpiry, expiry < Date() {
            reset()
        } else {
            startSessionTimer()
        }
    }

    // MARK: - Private Methods

    private func setupSessionMonitoring() {
        // Monitor app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppResignActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppBecomeActive()
            }
            .store(in: &cancellables)
    }

    private func startSessionTimer() {
        sessionTimer?.invalidate()

        guard let expiry = sessionExpiry else { return }

        let timeInterval = expiry.timeIntervalSinceNow
        guard timeInterval > 0 else {
            logout()
            return
        }

        sessionTimer = Timer.scheduledTimer(
            withTimeInterval: timeInterval,
            repeats: false
        ) { [weak self] _ in
            self?.handleSessionExpired()
        }
    }

    private func handleSessionExpired() {
        logout()
        NotificationCenter.default.post(
            name: .sessionExpired,
            object: nil
        )
    }

    private func handleAppResignActive() {
        // Lock wallet when app goes to background
        if isAuthenticated && !biometricEnabled {
            // Keep auth state but require re-authentication
        }
    }

    private func handleAppBecomeActive() {
        // Check if session is still valid
        if let expiry = sessionExpiry, expiry < Date() {
            handleSessionExpired()
        }
    }

    private func notifyStateChange() {
        NotificationCenter.default.post(
            name: .authStateChanged,
            object: createSnapshot()
        )
    }
}

// MARK: - Supporting Types

struct User: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let email: String
    var profileImageURL: URL?

    init(id: String, name: String, email: String, profileImageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.profileImageURL = profileImageURL
    }
}

enum AuthMethod: String, Codable {
    case google
    case facebook
    case apple
    case email
    case biometric
}

struct AuthStateSnapshot: Codable {
    let isAuthenticated: Bool
    let userId: String?
    let userName: String?
    let userEmail: String?
    let biometricEnabled: Bool
    let authMethod: AuthMethod?
    let sessionExpiry: Date?
}

// MARK: - Notifications

extension Notification.Name {
    static let authStateChanged = Notification.Name("authStateChanged")
    static let sessionExpired = Notification.Name("sessionExpired")
}
