//
//  BiometricViewModel.swift
//  FuekiWallet
//
//  Created by Fueki Team
//  Copyright © 2025 Fueki. All rights reserved.
//

import Foundation
import LocalAuthentication
import Combine

/// ViewModel managing biometric authentication state
@MainActor
final class BiometricViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var isAvailable = false
    @Published var biometricType: BiometricType = .none
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - State

    @Published var authenticationAttempts = 0
    @Published var maxAttemptsReached = false
    @Published var lockoutUntil: Date?

    // MARK: - Dependencies

    private let biometricService: BiometricServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Constants

    private let maxAttempts = 3
    private let lockoutDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(biometricService: BiometricServiceProtocol = BiometricService.shared) {
        self.biometricService = biometricService
        setupBindings()
        checkAvailability()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Monitor error state
        $errorMessage
            .map { $0 != nil }
            .assign(to: &$showError)

        // Check lockout status
        $lockoutUntil
            .map { lockout in
                guard let lockout = lockout else { return false }
                return Date() < lockout
            }
            .assign(to: &$maxAttemptsReached)
    }

    // MARK: - Biometric Availability

    func checkAvailability() {
        Task {
            isAvailable = await biometricService.isBiometricAvailable()

            if isAvailable {
                biometricType = await determineBiometricType()
            }
        }
    }

    private func determineBiometricType() async -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .opticID:
            return .opticID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    // MARK: - Authentication

    func authenticate(reason: String? = nil) async -> Bool {
        // Check lockout
        if let lockout = lockoutUntil, Date() < lockout {
            let remaining = Int(lockout.timeIntervalSinceNow / 60)
            errorMessage = "Too many failed attempts. Try again in \(remaining) minutes."
            return false
        }

        guard isAvailable else {
            errorMessage = "Biometric authentication is not available"
            return false
        }

        isAuthenticating = true
        errorMessage = nil

        do {
            let authenticated = try await biometricService.authenticate(
                reason: reason ?? defaultAuthenticationReason
            )

            if authenticated {
                isAuthenticated = true
                authenticationAttempts = 0
                lockoutUntil = nil
            } else {
                handleFailedAuthentication()
            }

            return authenticated
        } catch {
            handleAuthenticationError(error)
            return false
        }

        isAuthenticating = false
    }

    func authenticateForTransaction() async -> Bool {
        await authenticate(reason: "Authenticate to confirm transaction")
    }

    func authenticateForWalletAccess() async -> Bool {
        await authenticate(reason: "Authenticate to access wallet")
    }

    func authenticateForSettings() async -> Bool {
        await authenticate(reason: "Authenticate to change security settings")
    }

    // MARK: - Error Handling

    private func handleFailedAuthentication() {
        authenticationAttempts += 1

        if authenticationAttempts >= maxAttempts {
            lockoutUntil = Date().addingTimeInterval(lockoutDuration)
            errorMessage = "Too many failed attempts. Try again in 5 minutes."
        } else {
            let remaining = maxAttempts - authenticationAttempts
            errorMessage = "Authentication failed. \(remaining) attempts remaining."
        }
    }

    private func handleAuthenticationError(_ error: Error) {
        let laError = error as? LAError

        switch laError?.code {
        case .authenticationFailed:
            handleFailedAuthentication()
        case .userCancel:
            errorMessage = nil // User cancelled, no error needed
        case .userFallback:
            errorMessage = "Please use device passcode"
        case .systemCancel:
            errorMessage = "Authentication cancelled by system"
        case .passcodeNotSet:
            errorMessage = "Device passcode not set"
        case .biometryNotAvailable:
            errorMessage = "Biometric authentication not available"
        case .biometryNotEnrolled:
            errorMessage = "No biometric data enrolled"
        case .biometryLockout:
            lockoutUntil = Date().addingTimeInterval(lockoutDuration)
            errorMessage = "Biometric authentication locked. Try again later."
        default:
            errorMessage = "Authentication failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Reset

    func resetAuthenticationState() {
        isAuthenticated = false
        authenticationAttempts = 0
        lockoutUntil = nil
        errorMessage = nil
    }

    func clearLockout() {
        lockoutUntil = nil
        authenticationAttempts = 0
        errorMessage = nil
    }

    // MARK: - Computed Properties

    var defaultAuthenticationReason: String {
        switch biometricType {
        case .faceID:
            return "Use Face ID to authenticate"
        case .touchID:
            return "Use Touch ID to authenticate"
        case .opticID:
            return "Use Optic ID to authenticate"
        case .none:
            return "Authenticate to continue"
        }
    }

    var biometricIconName: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        case .opticID:
            return "opticid"
        case .none:
            return "lock.shield"
        }
    }

    var biometricDisplayName: String {
        switch biometricType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        case .none:
            return "Biometric"
        }
    }

    var remainingLockoutTime: String? {
        guard let lockout = lockoutUntil, Date() < lockout else { return nil }

        let remaining = Int(lockout.timeIntervalSinceNow)
        let minutes = remaining / 60
        let seconds = remaining % 60

        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Models

enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID
}

// MARK: - Service Extensions

extension BiometricServiceProtocol {
    func isBiometricAvailable() async -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String = "Authenticate to continue") async throws -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use Passcode"

        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }

    func disableBiometric(for walletId: String) async throws {
        // Implementation depends on keychain service
        // This is a placeholder for the protocol extension
    }
}
