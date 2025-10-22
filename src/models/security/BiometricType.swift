//
//  BiometricType.swift
//  Fueki Mobile Wallet
//
//  Biometric authentication type definitions
//

import Foundation
import LocalAuthentication

/// Available biometric authentication types
enum BiometricType: String, Codable {
    case none = "none"
    case touchID = "touchID"
    case faceID = "faceID"
    case opticID = "opticID"

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .touchID:
            return "Touch ID"
        case .faceID:
            return "Face ID"
        case .opticID:
            return "Optic ID"
        }
    }

    var icon: String {
        switch self {
        case .none:
            return "lock.fill"
        case .touchID:
            return "touchid"
        case .faceID:
            return "faceid"
        case .opticID:
            return "opticid"
        }
    }

    /// Detect available biometric type on device
    static func availableType() -> BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .none:
            return .none
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            return .opticID
        @unknown default:
            return .none
        }
    }
}

/// Biometric authentication error types
enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case userCancel
    case userFallback
    case systemCancel
    case passcodeNotSet
    case biometryNotAvailable
    case biometryNotEnrolled
    case invalidContext
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric authentication is enrolled. Please set up Face ID or Touch ID in Settings"
        case .lockout:
            return "Biometric authentication is locked. Please try again later or use your passcode"
        case .userCancel:
            return "Authentication was cancelled"
        case .userFallback:
            return "User selected fallback authentication"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .passcodeNotSet:
            return "Device passcode is not set. Please set up a passcode in Settings"
        case .biometryNotAvailable:
            return "Biometric authentication is not available"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled"
        case .invalidContext:
            return "Invalid authentication context"
        case .unknown(let error):
            return "Authentication failed: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .notAvailable, .biometryNotAvailable:
            return "This device does not support biometric authentication"
        case .notEnrolled, .biometryNotEnrolled:
            return "Go to Settings > Face ID & Passcode (or Touch ID & Passcode) to set up biometric authentication"
        case .lockout:
            return "Enter your device passcode to unlock biometric authentication"
        case .passcodeNotSet:
            return "Set up a device passcode in Settings to enable biometric authentication"
        case .userCancel, .userFallback, .systemCancel:
            return "Please try again"
        case .invalidContext, .unknown:
            return "Please restart the app and try again"
        }
    }

    static func from(laError: LAError) -> BiometricError {
        switch laError.code {
        case .biometryNotAvailable:
            return .biometryNotAvailable
        case .biometryNotEnrolled:
            return .biometryNotEnrolled
        case .biometryLockout:
            return .lockout
        case .userCancel:
            return .userCancel
        case .userFallback:
            return .userFallback
        case .systemCancel:
            return .systemCancel
        case .passcodeNotSet:
            return .passcodeNotSet
        case .invalidContext:
            return .invalidContext
        default:
            return .unknown(laError)
        }
    }
}

/// Biometric authentication configuration
struct BiometricConfig: Codable {
    var isEnabled: Bool
    var requireForTransactions: Bool
    var requireForAppLaunch: Bool
    var fallbackToPasscode: Bool
    var biometricType: BiometricType

    static let `default` = BiometricConfig(
        isEnabled: false,
        requireForTransactions: true,
        requireForAppLaunch: false,
        fallbackToPasscode: true,
        biometricType: .none
    )
}
