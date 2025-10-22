//
//  BiometricAuthManager.swift
//  FuekiWallet
//
//  Face ID/Touch ID integration with security controls
//

import Foundation
import LocalAuthentication

/// Manages biometric authentication (Face ID/Touch ID) with security controls
final class BiometricAuthManager: BiometricAuthProtocol {

    // MARK: - Properties

    private let context = LAContext()
    private var failedAttempts = 0
    private var lockoutEndTime: Date?
    private let maxAttempts: Int
    private let lockoutDuration: TimeInterval

    // MARK: - Initialization

    init(maxAttempts: Int = 5, lockoutDuration: TimeInterval = 300) {
        self.maxAttempts = maxAttempts
        self.lockoutDuration = lockoutDuration
    }

    // MARK: - BiometricAuthProtocol

    var isAvailable: Bool {
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var isEnrolled: Bool {
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)

        if let error = error as? LAError {
            switch error.code {
            case .biometryNotEnrolled:
                return false
            default:
                return canEvaluate
            }
        }

        return canEvaluate
    }

    var biometricType: BiometricType {
        guard isAvailable else { return .none }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }

    func authenticate(reason: String) async throws -> Bool {
        // Check if currently locked out
        if let lockoutEnd = lockoutEndTime, Date() < lockoutEnd {
            throw WalletError.biometricLockout
        }

        // Check if biometric is available
        guard isAvailable else {
            throw WalletError.biometricNotAvailable
        }

        guard isEnrolled else {
            throw WalletError.biometricNotEnrolled
        }

        // Create new context for authentication
        let authContext = LAContext()
        authContext.localizedCancelTitle = "Cancel"
        authContext.localizedFallbackTitle = "Use Passcode"

        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                // Reset failed attempts on success
                failedAttempts = 0
                lockoutEndTime = nil
                return true
            }

            return false

        } catch let error as LAError {
            // Increment failed attempts
            failedAttempts += 1

            // Check if lockout threshold reached
            if failedAttempts >= maxAttempts {
                lockoutEndTime = Date().addingTimeInterval(lockoutDuration)
                throw WalletError.biometricLockout
            }

            // Handle specific errors
            switch error.code {
            case .userCancel:
                throw WalletError.biometricCancelled

            case .userFallback:
                // User chose to use passcode instead
                return false

            case .biometryNotAvailable:
                throw WalletError.biometricNotAvailable

            case .biometryNotEnrolled:
                throw WalletError.biometricNotEnrolled

            case .biometryLockout:
                throw WalletError.biometricLockout

            case .authenticationFailed:
                throw WalletError.biometricAuthenticationFailed

            default:
                throw WalletError.biometricAuthenticationFailed
            }
        }
    }

    // MARK: - Additional Methods

    /// Authenticate with device owner authentication (includes passcode as fallback)
    func authenticateWithFallback(reason: String) async throws -> Bool {
        let authContext = LAContext()
        authContext.localizedCancelTitle = "Cancel"

        do {
            return try await authContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
        } catch let error as LAError {
            switch error.code {
            case .userCancel:
                throw WalletError.biometricCancelled
            default:
                throw WalletError.biometricAuthenticationFailed
            }
        }
    }

    /// Check if biometry has changed (re-enrollment detected)
    func hasBiometryChanged() -> Bool {
        guard let domainState = context.evaluatedPolicyDomainState else {
            return false
        }

        // Store and compare domain state to detect changes
        let key = "biometry.domain.state"
        let userDefaults = UserDefaults.standard

        if let previousState = userDefaults.data(forKey: key) {
            if domainState != previousState {
                // Biometry has changed
                userDefaults.set(domainState, forKey: key)
                return true
            }
        } else {
            // First time, store the state
            userDefaults.set(domainState, forKey: key)
        }

        return false
    }

    /// Reset failed attempts counter
    func resetFailedAttempts() {
        failedAttempts = 0
        lockoutEndTime = nil
    }

    /// Get remaining lockout time
    func remainingLockoutTime() -> TimeInterval? {
        guard let lockoutEnd = lockoutEndTime else {
            return nil
        }

        let remaining = lockoutEnd.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }

    /// Check if currently locked out
    var isLockedOut: Bool {
        guard let lockoutEnd = lockoutEndTime else {
            return false
        }

        return Date() < lockoutEnd
    }

    /// Get biometric type description
    var biometricTypeDescription: String {
        return biometricType.description
    }
}

// MARK: - Biometric Policy Helper

extension BiometricAuthManager {
    /// Get available authentication policies
    func availablePolicies() -> [AuthenticationPolicy] {
        var policies: [AuthenticationPolicy] = []

        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policies.append(.biometric)
        }

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            policies.append(.deviceOwner)
        }

        return policies
    }

    enum AuthenticationPolicy {
        case biometric
        case deviceOwner

        var policy: LAPolicy {
            switch self {
            case .biometric:
                return .deviceOwnerAuthenticationWithBiometrics
            case .deviceOwner:
                return .deviceOwnerAuthentication
            }
        }

        var description: String {
            switch self {
            case .biometric:
                return "Biometric Authentication"
            case .deviceOwner:
                return "Device Owner Authentication"
            }
        }
    }
}

// MARK: - Security Monitoring

extension BiometricAuthManager {
    /// Create authentication event log entry
    struct AuthenticationEvent {
        let timestamp: Date
        let success: Bool
        let biometricType: BiometricType
        let failedAttempts: Int

        var dictionary: [String: Any] {
            return [
                "timestamp": timestamp.timeIntervalSince1970,
                "success": success,
                "biometricType": biometricType.description,
                "failedAttempts": failedAttempts
            ]
        }
    }

    /// Log authentication event
    func logAuthenticationEvent(success: Bool) -> AuthenticationEvent {
        return AuthenticationEvent(
            timestamp: Date(),
            success: success,
            biometricType: biometricType,
            failedAttempts: failedAttempts
        )
    }
}
