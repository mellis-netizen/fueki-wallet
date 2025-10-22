//
//  SecurityCoordinator.swift
//  FuekiWallet
//
//  Central coordinator for all security operations
//  Combines biometric, PIN, and secure storage services
//

import Foundation
import LocalAuthentication
import Combine

/// Security authentication method
public enum AuthenticationMethod {
    case biometric
    case pin
    case biometricWithPINFallback
    case none
}

/// Security level for operations
public enum SecurityLevel {
    case low        // No authentication required
    case medium     // PIN or biometric required
    case high       // Biometric required with PIN fallback
    case critical   // Biometric + PIN required
}

/// Security coordinator result
public enum SecurityResult {
    case authenticated(method: AuthenticationMethod)
    case failed(Error)
    case cancelled
}

/// Central security coordinator
public final class SecurityCoordinator {

    // MARK: - Singleton

    public static let shared = SecurityCoordinator()

    // MARK: - Services

    private let biometricService = BiometricService.shared
    private let pinManager = PINManager.shared
    private let secureStorage = SecureStorageService.shared

    // MARK: - Publishers

    private let authenticationSubject = PassthroughSubject<SecurityResult, Never>()
    public var authenticationPublisher: AnyPublisher<SecurityResult, Never> {
        authenticationSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    /// Preferred authentication method
    public var preferredAuthenticationMethod: AuthenticationMethod {
        get {
            let rawValue = UserDefaults.standard.string(forKey: "security.preferredMethod") ?? "biometricWithPINFallback"
            switch rawValue {
            case "biometric": return .biometric
            case "pin": return .pin
            case "none": return .none
            default: return .biometricWithPINFallback
            }
        }
        set {
            let rawValue: String
            switch newValue {
            case .biometric: rawValue = "biometric"
            case .pin: rawValue = "pin"
            case .biometricWithPINFallback: rawValue = "biometricWithPINFallback"
            case .none: rawValue = "none"
            }
            UserDefaults.standard.set(rawValue, forKey: "security.preferredMethod")
        }
    }

    /// Check if security is properly configured
    public var isSecurityConfigured: Bool {
        return biometricService.isBiometricAvailable || pinManager.isPINSet
    }

    /// Get available authentication methods
    public var availableAuthenticationMethods: [AuthenticationMethod] {
        var methods: [AuthenticationMethod] = []

        if biometricService.isBiometricAvailable {
            methods.append(.biometric)
        }

        if pinManager.isPINSet {
            methods.append(.pin)
        }

        if biometricService.isBiometricAvailable && pinManager.isPINSet {
            methods.append(.biometricWithPINFallback)
        }

        return methods
    }

    // MARK: - Initialization

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        // Observe PIN status changes
        pinManager.pinStatusPublisher
            .sink { [weak self] isSet in
                self?.handlePINStatusChange(isSet: isSet)
            }
            .store(in: &cancellables)
    }

    // MARK: - Authentication

    /// Authenticate user based on security level
    /// - Parameters:
    ///   - level: Required security level
    ///   - reason: Reason for authentication
    /// - Returns: Authentication result
    public func authenticate(
        level: SecurityLevel,
        reason: String
    ) async -> SecurityResult {
        switch level {
        case .low:
            return .authenticated(method: .none)

        case .medium:
            return await authenticateMedium(reason: reason)

        case .high:
            return await authenticateHigh(reason: reason)

        case .critical:
            return await authenticateCritical(reason: reason)
        }
    }

    /// Authenticate with preferred method
    /// - Parameter reason: Reason for authentication
    /// - Returns: Authentication result
    public func authenticateWithPreferred(reason: String) async -> SecurityResult {
        switch preferredAuthenticationMethod {
        case .biometric:
            return await authenticateWithBiometric(reason: reason, allowFallback: false)

        case .pin:
            return await authenticateWithPIN(reason: reason)

        case .biometricWithPINFallback:
            return await authenticateWithBiometric(reason: reason, allowFallback: true)

        case .none:
            return .authenticated(method: .none)
        }
    }

    // MARK: - Private Authentication Methods

    private func authenticateMedium(reason: String) async -> SecurityResult {
        // Try preferred method first
        if biometricService.isBiometricAvailable && preferredAuthenticationMethod == .biometric {
            let result = await biometricService.authenticate(reason: reason, fallbackEnabled: false)
            switch result {
            case .success:
                return .authenticated(method: .biometric)
            case .failure(let error):
                // Fallback to PIN if biometric fails
                if pinManager.isPINSet {
                    return await authenticateWithPIN(reason: reason)
                }
                return .failed(error)
            case .fallbackRequested:
                return await authenticateWithPIN(reason: reason)
            }
        } else if pinManager.isPINSet {
            return await authenticateWithPIN(reason: reason)
        }

        return .failed(NSError(domain: "SecurityCoordinator", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "No authentication method available"
        ]))
    }

    private func authenticateHigh(reason: String) async -> SecurityResult {
        // Require biometric with PIN fallback
        let result = await biometricService.authenticate(reason: reason, fallbackEnabled: true)

        switch result {
        case .success:
            return .authenticated(method: .biometric)

        case .failure(let error):
            if pinManager.isPINSet {
                return await authenticateWithPIN(reason: reason)
            }
            return .failed(error)

        case .fallbackRequested:
            return await authenticateWithPIN(reason: reason)
        }
    }

    private func authenticateCritical(reason: String) async -> SecurityResult {
        // Require both biometric AND PIN
        let biometricResult = await biometricService.authenticate(reason: reason, fallbackEnabled: false)

        guard case .success = biometricResult else {
            if case .failure(let error) = biometricResult {
                return .failed(error)
            }
            return .cancelled
        }

        // Now require PIN
        return await authenticateWithPIN(reason: "Enter your PIN to complete authentication")
    }

    private func authenticateWithBiometric(
        reason: String,
        allowFallback: Bool
    ) async -> SecurityResult {
        let result = await biometricService.authenticate(reason: reason, fallbackEnabled: allowFallback)

        switch result {
        case .success:
            return .authenticated(method: .biometric)

        case .failure(let error):
            return .failed(error)

        case .fallbackRequested:
            if allowFallback && pinManager.isPINSet {
                return await authenticateWithPIN(reason: reason)
            }
            return .cancelled
        }
    }

    private func authenticateWithPIN(reason: String) async -> SecurityResult {
        // This would typically show a PIN entry UI
        // For now, we return a placeholder
        // In production, this would present a PIN entry view controller
        return .failed(NSError(domain: "SecurityCoordinator", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "PIN authentication requires UI implementation"
        ]))
    }

    // MARK: - Secure Operations

    /// Perform secure operation with authentication
    /// - Parameters:
    ///   - level: Security level required
    ///   - reason: Reason for authentication
    ///   - operation: Operation to perform after authentication
    /// - Returns: Result of operation
    public func performSecureOperation<T>(
        level: SecurityLevel,
        reason: String,
        operation: @escaping () async throws -> T
    ) async -> Result<T, Error> {
        let authResult = await authenticate(level: level, reason: reason)

        switch authResult {
        case .authenticated:
            do {
                let result = try await operation()
                return .success(result)
            } catch {
                return .failure(error)
            }

        case .failed(let error):
            return .failure(error)

        case .cancelled:
            return .failure(NSError(domain: "SecurityCoordinator", code: -2, userInfo: [
                NSLocalizedDescriptionKey: "Operation cancelled"
            ]))
        }
    }

    /// Get authentication context for Secure Enclave operations
    /// - Parameter reason: Reason for authentication
    /// - Returns: LAContext if authenticated, nil otherwise
    public func getAuthenticationContext(reason: String) async -> LAContext? {
        return await biometricService.authenticateForSecureEnclave(reason: reason)
    }

    // MARK: - Security Configuration

    /// Setup initial security (first time)
    /// - Parameters:
    ///   - enableBiometric: Whether to enable biometric
    ///   - pin: PIN to set (optional)
    /// - Returns: Result with success or error
    public func setupSecurity(
        enableBiometric: Bool,
        pin: String?
    ) -> Result<Void, Error> {
        // Set PIN if provided
        if let pin = pin {
            let result = pinManager.setPIN(pin)
            if case .failure(let error) = result {
                return .failure(error)
            }
        }

        // Configure preferred method
        if enableBiometric && biometricService.isBiometricAvailable {
            if pinManager.isPINSet {
                preferredAuthenticationMethod = .biometricWithPINFallback
            } else {
                preferredAuthenticationMethod = .biometric
            }
        } else if pinManager.isPINSet {
            preferredAuthenticationMethod = .pin
        }

        return .success(())
    }

    /// Reset all security settings
    /// - Parameter currentPIN: Current PIN for verification
    /// - Returns: Result with success or error
    public func resetSecurity(currentPIN: String?) -> Result<Void, Error> {
        // Remove PIN if set
        if pinManager.isPINSet {
            guard let currentPIN = currentPIN else {
                return .failure(PINError.notSet)
            }

            let result = pinManager.removePIN(currentPIN: currentPIN)
            if case .failure(let error) = result {
                return .failure(error)
            }
        }

        // Reset preferred method
        preferredAuthenticationMethod = .none

        // Clear secure storage (optional, use with caution)
        // secureStorage.clearAll()

        return .success(())
    }

    // MARK: - Security Status

    /// Get comprehensive security status
    /// - Returns: Dictionary with security information
    public func getSecurityStatus() -> [String: Any] {
        return [
            "configured": isSecurityConfigured,
            "preferredMethod": String(describing: preferredAuthenticationMethod),
            "availableMethods": availableAuthenticationMethods.map { String(describing: $0) },
            "biometric": biometricService.getBiometricInfo(),
            "pin": [
                "isSet": pinManager.isPINSet,
                "isLocked": pinManager.isLocked,
                "remainingAttempts": pinManager.remainingAttempts
            ]
        ]
    }

    // MARK: - Event Handlers

    private func handlePINStatusChange(isSet: Bool) {
        // Update preferred method if needed
        if !isSet && preferredAuthenticationMethod == .pin {
            if biometricService.isBiometricAvailable {
                preferredAuthenticationMethod = .biometric
            } else {
                preferredAuthenticationMethod = .none
            }
        }
    }
}
