//
//  BiometricAuthenticationService.swift
//  Fueki Mobile Wallet
//
//  Production biometric authentication service with Face ID/Touch ID
//

import Foundation
import LocalAuthentication
import Combine

/// Production-grade biometric authentication service
class BiometricAuthenticationService: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var availableBiometricType: BiometricType = .none
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var isEnrolled: Bool = false
    @Published private(set) var config: BiometricConfig = .default

    // MARK: - Private Properties

    private let context = LAContext()
    private let userDefaults = UserDefaults.standard
    private let configKey = "biometric_config"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadConfiguration()
        checkBiometricAvailability()
    }

    // MARK: - Public Methods

    /// Check if biometric authentication is available on the device
    func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?

        // Check if device supports biometric authentication
        let canEvaluate = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        DispatchQueue.main.async { [weak self] in
            self?.isAvailable = canEvaluate
            self?.isEnrolled = canEvaluate && error == nil
            self?.availableBiometricType = BiometricType.availableType()

            // Update config with detected biometric type
            var updatedConfig = self?.config ?? .default
            updatedConfig.biometricType = self?.availableBiometricType ?? .none
            self?.config = updatedConfig
        }
    }

    /// Authenticate user with biometrics
    /// - Parameters:
    ///   - reason: The reason for authentication (displayed to user)
    ///   - fallbackTitle: Optional title for fallback button
    /// - Returns: Result with success or biometric error
    func authenticate(
        reason: String,
        fallbackTitle: String? = nil
    ) async -> Result<Void, BiometricError> {

        // Check if biometrics are enabled
        guard config.isEnabled else {
            return .failure(.notAvailable)
        }

        // Create fresh context for each authentication
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        if let fallbackTitle = fallbackTitle {
            context.localizedFallbackTitle = fallbackTitle
        } else if config.fallbackToPasscode {
            context.localizedFallbackTitle = "Use Passcode"
        } else {
            context.localizedFallbackTitle = ""
        }

        // Check if biometric authentication is available
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let laError = error as? LAError {
                return .failure(BiometricError.from(laError: laError))
            }
            return .failure(.notAvailable)
        }

        // Perform biometric authentication
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                return .success(())
            } else {
                return .failure(.unknown(NSError(domain: "BiometricAuth", code: -1)))
            }
        } catch let error as LAError {
            return .failure(BiometricError.from(laError: error))
        } catch {
            return .failure(.unknown(error))
        }
    }

    /// Authenticate for transaction signing
    /// - Parameter amount: Transaction amount for display in prompt
    /// - Returns: Result with success or biometric error
    func authenticateForTransaction(amount: String) async -> Result<Void, BiometricError> {
        guard config.requireForTransactions else {
            return .success(())
        }

        let reason = "Authenticate to sign transaction of \(amount)"
        return await authenticate(reason: reason, fallbackTitle: "Use Passcode")
    }

    /// Authenticate for app launch
    /// - Returns: Result with success or biometric error
    func authenticateForAppLaunch() async -> Result<Void, BiometricError> {
        guard config.requireForAppLaunch else {
            return .success(())
        }

        let biometricName = availableBiometricType.displayName
        let reason = "Authenticate with \(biometricName) to access your wallet"
        return await authenticate(reason: reason)
    }

    /// Authenticate with device owner authentication (includes passcode fallback)
    /// - Parameter reason: The reason for authentication
    /// - Returns: Result with success or biometric error
    func authenticateWithDeviceOwner(reason: String) async -> Result<Void, BiometricError> {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            if let laError = error as? LAError {
                return .failure(BiometricError.from(laError: laError))
            }
            return .failure(.notAvailable)
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )

            if success {
                return .success(())
            } else {
                return .failure(.unknown(NSError(domain: "BiometricAuth", code: -1)))
            }
        } catch let error as LAError {
            return .failure(BiometricError.from(laError: error))
        } catch {
            return .failure(.unknown(error))
        }
    }

    // MARK: - Configuration Management

    /// Enable biometric authentication
    func enableBiometricAuth() async -> Result<Void, BiometricError> {
        // Verify biometrics work before enabling
        let result = await authenticate(reason: "Verify \(availableBiometricType.displayName) to enable biometric authentication")

        switch result {
        case .success:
            var updatedConfig = config
            updatedConfig.isEnabled = true
            updateConfiguration(updatedConfig)
            return .success(())
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Disable biometric authentication
    func disableBiometricAuth() {
        var updatedConfig = config
        updatedConfig.isEnabled = false
        updateConfiguration(updatedConfig)
    }

    /// Update transaction authentication requirement
    func setRequireForTransactions(_ require: Bool) {
        var updatedConfig = config
        updatedConfig.requireForTransactions = require
        updateConfiguration(updatedConfig)
    }

    /// Update app launch authentication requirement
    func setRequireForAppLaunch(_ require: Bool) {
        var updatedConfig = config
        updatedConfig.requireForAppLaunch = require
        updateConfiguration(updatedConfig)
    }

    /// Update fallback to passcode setting
    func setFallbackToPasscode(_ fallback: Bool) {
        var updatedConfig = config
        updatedConfig.fallbackToPasscode = fallback
        updateConfiguration(updatedConfig)
    }

    /// Update complete configuration
    func updateConfiguration(_ newConfig: BiometricConfig) {
        config = newConfig
        saveConfiguration()
    }

    // MARK: - Private Methods

    private func loadConfiguration() {
        if let data = userDefaults.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(BiometricConfig.self, from: data) {
            config = decoded
        } else {
            config = .default
            config.biometricType = BiometricType.availableType()
        }
    }

    private func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(config) {
            userDefaults.set(encoded, forKey: configKey)
        }
    }
}
