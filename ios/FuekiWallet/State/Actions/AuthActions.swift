//
//  AuthActions.swift
//  FuekiWallet
//
//  Actions related to authentication state
//

import Foundation

// MARK: - Auth Actions
enum AuthAction: Action {

    // Authentication
    case authenticate(method: AuthMethod)
    case authenticationSucceeded(method: AuthMethod, timestamp: Date)
    case authenticationFailed(error: ErrorState)

    // Biometric
    case requestBiometric
    case biometricSucceeded
    case biometricFailed(error: ErrorState)
    case biometricUnavailable
    case setBiometricType(BiometricType)

    // Passcode
    case requestPasscode
    case passcodeEntered(String)
    case passcodeSucceeded
    case passcodeFailed(error: ErrorState)
    case passcodeIncorrect

    // Session
    case startSession(duration: TimeInterval)
    case sessionStarted(expiry: Date)
    case extendSession(duration: TimeInterval)
    case sessionExtended(expiry: Date)
    case endSession
    case sessionEnded
    case sessionExpired

    // Lock/Unlock
    case lock
    case locked
    case unlock
    case unlocked

    // Failed Attempts
    case incrementFailedAttempts
    case resetFailedAttempts
    case maxAttemptsReached

    // Logout
    case logout
    case logoutCompleted

    // Setup
    case setupPasscode(String)
    case passcodeSetup
    case setupFailed(error: ErrorState)

    case setupBiometric
    case biometricSetup

    // Reset
    case resetAuth
    case authReset

    // Error
    case setError(ErrorState?)
    case clearError
}

// MARK: - Session Actions
enum SessionAction: Action {
    case create(duration: TimeInterval)
    case created(expiry: Date)
    case validate
    case valid
    case invalid
    case refresh
    case refreshed(expiry: Date)
    case destroy
    case destroyed
}

// MARK: - Biometric Actions
enum BiometricAction: Action {
    case checkAvailability
    case available(type: BiometricType)
    case unavailable
    case authorize
    case authorized
    case authorizationFailed(error: ErrorState)
    case authorizationCancelled
}

// MARK: - Security Actions
enum SecurityAction: Action {
    case enableSecureMode
    case disableSecureMode
    case secureModeChanged(enabled: Bool)

    case enableAutoLock
    case disableAutoLock
    case autoLockChanged(enabled: Bool)

    case wipeData
    case dataWiped
    case wipeFailed(error: ErrorState)
}
