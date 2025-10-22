//
//  BiometricService.swift
//  FuekiWallet
//
//  Production-grade biometric authentication service
//  Supports Face ID and Touch ID with fallback mechanisms
//

import Foundation
import LocalAuthentication
import Combine

/// Biometric authentication types available on device
public enum BiometricType {
    case none
    case touchID
    case faceID
    case opticID

    var displayName: String {
        switch self {
        case .none: return "None"
        case .touchID: return "Touch ID"
        case .faceID: return "Face ID"
        case .opticID: return "Optic ID"
        }
    }
}

/// Biometric authentication errors
public enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case cancelled
    case failed
    case passcodeNotSet
    case biometryNotEnrolled
    case systemCancel
    case appCancel
    case invalidContext
    case biometryLockout
    case notInteractive
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric authentication is enrolled"
        case .lockout:
            return "Biometric authentication is locked. Please try again later"
        case .cancelled:
            return "Authentication was cancelled"
        case .failed:
            return "Authentication failed"
        case .passcodeNotSet:
            return "Device passcode is not set"
        case .biometryNotEnrolled:
            return "Biometric authentication is not enrolled"
        case .systemCancel:
            return "Authentication was cancelled by system"
        case .appCancel:
            return "Authentication was cancelled by application"
        case .invalidContext:
            return "Invalid authentication context"
        case .biometryLockout:
            return "Biometric authentication is locked due to too many failed attempts"
        case .notInteractive:
            return "Authentication is not interactive"
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}

/// Authentication result
public enum AuthenticationResult {
    case success
    case failure(BiometricError)
    case fallbackRequested
}

/// Biometric authentication service
public final class BiometricService {

    // MARK: - Singleton

    public static let shared = BiometricService()

    // MARK: - Properties

    private let context = LAContext()
    private var cancellables = Set<AnyCancellable>()

    /// Current biometric type available on device
    public var biometricType: BiometricType {
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

    /// Check if biometric authentication is available
    public var isBiometricAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Check if device has passcode set
    public var isPasscodeSet: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Check if biometric authentication is enrolled
    public var isBiometricEnrolled: Bool {
        guard isBiometricAvailable else { return false }
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return error == nil
    }

    // MARK: - Initialization

    private init() {
        configureContext()
    }

    // MARK: - Configuration

    private func configureContext() {
        context.localizedCancelTitle = "Cancel"
        context.localizedFallbackTitle = "Use PIN"
    }

    // MARK: - Authentication

    /// Authenticate using biometrics with async/await
    /// - Parameters:
    ///   - reason: The reason for authentication displayed to user
    ///   - fallbackEnabled: Whether to show fallback option
    /// - Returns: Authentication result
    public func authenticate(
        reason: String,
        fallbackEnabled: Bool = true
    ) async -> AuthenticationResult {
        // Create new context for each authentication
        let authContext = LAContext()
        authContext.localizedCancelTitle = "Cancel"

        if fallbackEnabled {
            authContext.localizedFallbackTitle = "Use PIN"
        } else {
            authContext.localizedFallbackTitle = ""
        }

        // Check if biometric authentication is available
        var error: NSError?
        guard authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.notAvailable)
        }

        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                return .success
            } else {
                return .failure(.failed)
            }
        } catch let error as NSError {
            // Check if user requested fallback
            if error.code == LAError.userFallback.rawValue {
                return .fallbackRequested
            }
            return .failure(mapError(error))
        }
    }

    /// Authenticate with device passcode fallback
    /// - Parameter reason: The reason for authentication
    /// - Returns: Authentication result
    public func authenticateWithPasscode(reason: String) async -> AuthenticationResult {
        let authContext = LAContext()
        authContext.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard authContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let error = error {
                return .failure(mapError(error))
            }
            return .failure(.passcodeNotSet)
        }

        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                return .success
            } else {
                return .failure(.failed)
            }
        } catch let error as NSError {
            return .failure(mapError(error))
        }
    }

    /// Authenticate for secure enclave operations
    /// - Parameter reason: The reason for authentication
    /// - Returns: LAContext on success, nil on failure
    public func authenticateForSecureEnclave(reason: String) async -> LAContext? {
        let authContext = LAContext()
        authContext.localizedCancelTitle = "Cancel"
        authContext.touchIDAuthenticationAllowableReuseDuration = 10 // 10 seconds reuse

        var error: NSError?
        guard authContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }

        do {
            let success = try await authContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success ? authContext : nil
        } catch {
            return nil
        }
    }

    // MARK: - Error Mapping

    private func mapError(_ error: NSError) -> BiometricError {
        guard error.domain == LAErrorDomain else {
            return .unknown(error)
        }

        switch error.code {
        case LAError.authenticationFailed.rawValue:
            return .failed
        case LAError.userCancel.rawValue:
            return .cancelled
        case LAError.userFallback.rawValue:
            return .cancelled
        case LAError.systemCancel.rawValue:
            return .systemCancel
        case LAError.passcodeNotSet.rawValue:
            return .passcodeNotSet
        case LAError.biometryNotAvailable.rawValue:
            return .notAvailable
        case LAError.biometryNotEnrolled.rawValue:
            return .biometryNotEnrolled
        case LAError.biometryLockout.rawValue:
            return .biometryLockout
        case LAError.appCancel.rawValue:
            return .appCancel
        case LAError.invalidContext.rawValue:
            return .invalidContext
        case LAError.notInteractive.rawValue:
            return .notInteractive
        default:
            return .unknown(error)
        }
    }

    // MARK: - Utility Methods

    /// Invalidate current authentication context
    public func invalidateContext() {
        context.invalidate()
        configureContext()
    }

    /// Get biometric capability information
    /// - Returns: Dictionary with biometric capabilities
    public func getBiometricInfo() -> [String: Any] {
        return [
            "type": biometricType.displayName,
            "available": isBiometricAvailable,
            "enrolled": isBiometricEnrolled,
            "passcodeSet": isPasscodeSet
        ]
    }

    /// Check if biometric authentication changed (e.g., new fingerprint added)
    /// - Parameter domainState: Previous domain state data
    /// - Returns: True if changed, false otherwise
    public func hasBiometricChanged(previousDomainState: Data?) -> Bool {
        guard let previousDomainState = previousDomainState else { return true }

        let currentContext = LAContext()
        guard let currentDomainState = currentContext.evaluatedPolicyDomainState else {
            return true
        }

        return currentDomainState != previousDomainState
    }

    /// Get current biometric domain state
    /// - Returns: Current domain state data or nil
    public func getCurrentDomainState() -> Data? {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.evaluatedPolicyDomainState
    }
}

// MARK: - Combine Extensions

extension BiometricService {

    /// Authenticate using biometrics with Combine
    /// - Parameters:
    ///   - reason: The reason for authentication
    ///   - fallbackEnabled: Whether to show fallback option
    /// - Returns: Publisher that emits authentication result
    public func authenticatePublisher(
        reason: String,
        fallbackEnabled: Bool = true
    ) -> AnyPublisher<AuthenticationResult, Never> {
        return Future { promise in
            Task {
                let result = await self.authenticate(reason: reason, fallbackEnabled: fallbackEnabled)
                promise(.success(result))
            }
        }
        .eraseToAnyPublisher()
    }
}
