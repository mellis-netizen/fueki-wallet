//
//  AppReducer.swift
//  FuekiWallet
//
//  Main reducer combining all sub-reducers
//

import Foundation

// MARK: - App Reducer
func appReducer(state: inout AppState, action: Action) {
    // Apply all sub-reducers
    walletReducer(state: &state.wallet, action: action)
    accountReducer(state: &state.wallet, action: action)
    balanceReducer(state: &state.wallet, action: action)

    transactionReducer(state: &state.transactions, action: action)
    transactionHistoryReducer(state: &state.transactions, action: action)
    transactionFeeReducer(state: &state.transactions, action: action)

    settingsReducer(state: &state.settings, action: action)
    preferenceReducer(state: &state.settings, action: action)
    securitySettingsReducer(state: &state.settings, action: action)

    authReducer(state: &state.auth, action: action)
    sessionReducer(state: &state.auth, action: action)
    biometricReducer(state: &state.auth, action: action)
    securityReducer(state: &state.auth, action: action)

    uiReducer(state: &state.ui, action: action)
}

// MARK: - Auth Reducer
func authReducer(state: inout AuthState, action: Action) {
    guard let action = action as? AuthAction else { return }

    switch action {

    // Authentication
    case .authenticate:
        state.error = nil

    case .authenticationSucceeded(let method, let timestamp):
        state.isAuthenticated = true
        state.authMethod = method
        state.lastAuthTimestamp = timestamp
        state.isLocked = false
        state.failedAttempts = 0
        state.error = nil

    case .authenticationFailed(let error):
        state.isAuthenticated = false
        state.error = error
        state.failedAttempts += 1

    // Biometric
    case .requestBiometric:
        state.error = nil

    case .biometricSucceeded:
        state.isAuthenticated = true
        state.authMethod = .biometric
        state.lastAuthTimestamp = Date()
        state.isLocked = false
        state.failedAttempts = 0
        state.error = nil

    case .biometricFailed(let error):
        state.error = error
        state.failedAttempts += 1

    case .biometricUnavailable:
        state.biometricType = .none

    case .setBiometricType(let type):
        state.biometricType = type

    // Passcode
    case .requestPasscode:
        state.error = nil

    case .passcodeEntered:
        state.error = nil

    case .passcodeSucceeded:
        state.isAuthenticated = true
        state.authMethod = .passcode
        state.lastAuthTimestamp = Date()
        state.isLocked = false
        state.failedAttempts = 0
        state.error = nil

    case .passcodeFailed(let error):
        state.error = error
        state.failedAttempts += 1

    case .passcodeIncorrect:
        state.failedAttempts += 1

    // Session
    case .startSession(let duration):
        state.sessionExpiry = Date().addingTimeInterval(duration)

    case .sessionStarted(let expiry):
        state.sessionExpiry = expiry

    case .extendSession(let duration):
        if let currentExpiry = state.sessionExpiry {
            state.sessionExpiry = currentExpiry.addingTimeInterval(duration)
        }

    case .sessionExtended(let expiry):
        state.sessionExpiry = expiry

    case .endSession:
        state.sessionExpiry = nil
        state.isAuthenticated = false
        state.isLocked = true

    case .sessionEnded:
        state.sessionExpiry = nil
        state.isAuthenticated = false
        state.isLocked = true

    case .sessionExpired:
        state.sessionExpiry = nil
        state.isAuthenticated = false
        state.isLocked = true

    // Lock/Unlock
    case .lock:
        state.isLocked = true

    case .locked:
        state.isLocked = true

    case .unlock:
        state.isLocked = false

    case .unlocked:
        state.isLocked = false

    // Failed Attempts
    case .incrementFailedAttempts:
        state.failedAttempts += 1

    case .resetFailedAttempts:
        state.failedAttempts = 0

    case .maxAttemptsReached:
        state.isLocked = true
        state.isAuthenticated = false

    // Logout
    case .logout:
        state.isAuthenticated = false
        state.authMethod = nil
        state.sessionExpiry = nil
        state.isLocked = true

    case .logoutCompleted:
        state.isAuthenticated = false
        state.authMethod = nil
        state.sessionExpiry = nil
        state.isLocked = true

    // Setup
    case .setupPasscode:
        state.error = nil

    case .passcodeSetup:
        state.authMethod = .passcode
        state.error = nil

    case .setupFailed(let error):
        state.error = error

    case .setupBiometric:
        state.error = nil

    case .biometricSetup:
        state.authMethod = .biometric
        state.error = nil

    // Reset
    case .resetAuth:
        state = AuthState()

    case .authReset:
        state = AuthState()

    // Error
    case .setError(let error):
        state.error = error

    case .clearError:
        state.error = nil
    }
}

// MARK: - Session Reducer
func sessionReducer(state: inout AuthState, action: Action) {
    guard let action = action as? SessionAction else { return }

    switch action {
    case .create(let duration):
        state.sessionExpiry = Date().addingTimeInterval(duration)

    case .created(let expiry):
        state.sessionExpiry = expiry

    case .validate:
        break

    case .valid:
        break

    case .invalid:
        state.isAuthenticated = false
        state.isLocked = true

    case .refresh:
        break

    case .refreshed(let expiry):
        state.sessionExpiry = expiry

    case .destroy:
        state.sessionExpiry = nil
        state.isAuthenticated = false
        state.isLocked = true

    case .destroyed:
        state.sessionExpiry = nil
        state.isAuthenticated = false
        state.isLocked = true
    }
}

// MARK: - Biometric Reducer
func biometricReducer(state: inout AuthState, action: Action) {
    guard let action = action as? BiometricAction else { return }

    switch action {
    case .checkAvailability:
        break

    case .available(let type):
        state.biometricType = type

    case .unavailable:
        state.biometricType = .none

    case .authorize:
        state.error = nil

    case .authorized:
        state.isAuthenticated = true
        state.authMethod = .biometric
        state.lastAuthTimestamp = Date()
        state.isLocked = false
        state.failedAttempts = 0

    case .authorizationFailed(let error):
        state.error = error
        state.failedAttempts += 1

    case .authorizationCancelled:
        state.error = nil
    }
}

// MARK: - Security Reducer
func securityReducer(state: inout AuthState, action: Action) {
    guard let _ = action as? SecurityAction else { return }

    // Security-specific state updates can be added here
}

// MARK: - UI Reducer
func uiReducer(state: inout UIState, action: Action) {
    // Handle UI-specific actions
    // This can be extended with UIAction enum if needed
}
