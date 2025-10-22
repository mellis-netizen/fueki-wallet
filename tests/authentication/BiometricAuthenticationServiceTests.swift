//
//  BiometricAuthenticationServiceTests.swift
//  Fueki Mobile Wallet Tests
//
//  Tests for biometric authentication service
//

import XCTest
import LocalAuthentication
@testable import Fueki_Mobile_Wallet

class BiometricAuthenticationServiceTests: XCTestCase {

    var service: BiometricAuthenticationService!

    override func setUp() {
        super.setUp()
        service = BiometricAuthenticationService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Availability Tests

    func testBiometricAvailabilityCheck() {
        // When
        service.checkBiometricAvailability()

        // Then
        XCTAssertNotNil(service.availableBiometricType)
    }

    func testAvailableBiometricTypeDetection() {
        // Given
        let detectedType = BiometricType.availableType()

        // Then
        XCTAssertTrue([.none, .touchID, .faceID, .opticID].contains(detectedType))
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() {
        // Given
        let config = BiometricConfig.default

        // Then
        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.requireForTransactions)
        XCTAssertFalse(config.requireForAppLaunch)
        XCTAssertTrue(config.fallbackToPasscode)
    }

    func testEnableBiometricConfiguration() {
        // Given
        var config = service.config
        config.isEnabled = true

        // When
        service.updateConfiguration(config)

        // Then
        XCTAssertTrue(service.config.isEnabled)
    }

    func testDisableBiometricAuth() {
        // Given
        var config = service.config
        config.isEnabled = true
        service.updateConfiguration(config)

        // When
        service.disableBiometricAuth()

        // Then
        XCTAssertFalse(service.config.isEnabled)
    }

    func testUpdateTransactionRequirement() {
        // When
        service.setRequireForTransactions(false)

        // Then
        XCTAssertFalse(service.config.requireForTransactions)

        // When
        service.setRequireForTransactions(true)

        // Then
        XCTAssertTrue(service.config.requireForTransactions)
    }

    func testUpdateAppLaunchRequirement() {
        // When
        service.setRequireForAppLaunch(true)

        // Then
        XCTAssertTrue(service.config.requireForAppLaunch)

        // When
        service.setRequireForAppLaunch(false)

        // Then
        XCTAssertFalse(service.config.requireForAppLaunch)
    }

    func testUpdateFallbackToPasscode() {
        // When
        service.setFallbackToPasscode(false)

        // Then
        XCTAssertFalse(service.config.fallbackToPasscode)

        // When
        service.setFallbackToPasscode(true)

        // Then
        XCTAssertTrue(service.config.fallbackToPasscode)
    }

    // MARK: - Error Handling Tests

    func testBiometricErrorFromLAError() {
        // Given
        let errors: [(LAError.Code, BiometricError)] = [
            (.biometryNotAvailable, .biometryNotAvailable),
            (.biometryNotEnrolled, .biometryNotEnrolled),
            (.biometryLockout, .lockout),
            (.userCancel, .userCancel),
            (.userFallback, .userFallback),
            (.systemCancel, .systemCancel),
            (.passcodeNotSet, .passcodeNotSet),
            (.invalidContext, .invalidContext)
        ]

        for (laCode, expectedError) in errors {
            // When
            let laError = LAError(laCode)
            let biometricError = BiometricError.from(laError: laError)

            // Then
            switch (biometricError, expectedError) {
            case (.biometryNotAvailable, .biometryNotAvailable),
                 (.biometryNotEnrolled, .biometryNotEnrolled),
                 (.lockout, .lockout),
                 (.userCancel, .userCancel),
                 (.userFallback, .userFallback),
                 (.systemCancel, .systemCancel),
                 (.passcodeNotSet, .passcodeNotSet),
                 (.invalidContext, .invalidContext):
                XCTAssertTrue(true, "Error correctly mapped")
            default:
                XCTFail("Error not correctly mapped: \(biometricError)")
            }
        }
    }

    func testBiometricErrorDescriptions() {
        // Given
        let errors: [BiometricError] = [
            .notAvailable,
            .notEnrolled,
            .lockout,
            .userCancel,
            .passcodeNotSet,
            .biometryNotAvailable,
            .biometryNotEnrolled
        ]

        for error in errors {
            // Then
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func testBiometricErrorRecoverySuggestions() {
        // Given
        let errors: [BiometricError] = [
            .notAvailable,
            .notEnrolled,
            .lockout,
            .passcodeNotSet
        ]

        for error in errors {
            // Then
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.recoverySuggestion?.isEmpty ?? true)
        }
    }

    // MARK: - Biometric Type Tests

    func testBiometricTypeDisplayNames() {
        // Given
        let types: [(BiometricType, String)] = [
            (.none, "None"),
            (.touchID, "Touch ID"),
            (.faceID, "Face ID"),
            (.opticID, "Optic ID")
        ]

        for (type, expectedName) in types {
            // Then
            XCTAssertEqual(type.displayName, expectedName)
        }
    }

    func testBiometricTypeIcons() {
        // Given
        let types: [(BiometricType, String)] = [
            (.none, "lock.fill"),
            (.touchID, "touchid"),
            (.faceID, "faceid"),
            (.opticID, "opticid")
        ]

        for (type, expectedIcon) in types {
            // Then
            XCTAssertEqual(type.icon, expectedIcon)
        }
    }

    // MARK: - Authentication Tests (Requires Device)

    func testAuthenticateWhenDisabled() async {
        // Given
        service.disableBiometricAuth()

        // When
        let result = await service.authenticate(reason: "Test")

        // Then
        switch result {
        case .success:
            XCTFail("Should not succeed when disabled")
        case .failure(let error):
            if case .notAvailable = error {
                XCTAssertTrue(true)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testAuthenticateForTransactionWhenNotRequired() async {
        // Given
        service.setRequireForTransactions(false)

        // When
        let result = await service.authenticateForTransaction(amount: "1.0 ETH")

        // Then
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure:
            XCTFail("Should succeed when not required")
        }
    }

    func testAuthenticateForAppLaunchWhenNotRequired() async {
        // Given
        service.setRequireForAppLaunch(false)

        // When
        let result = await service.authenticateForAppLaunch()

        // Then
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure:
            XCTFail("Should succeed when not required")
        }
    }

    // MARK: - Configuration Persistence Tests

    func testConfigurationPersistence() {
        // Given
        var config = service.config
        config.isEnabled = true
        config.requireForTransactions = false
        config.requireForAppLaunch = true
        config.fallbackToPasscode = false

        // When
        service.updateConfiguration(config)

        // Create new service instance to test persistence
        let newService = BiometricAuthenticationService()

        // Then
        XCTAssertTrue(newService.config.isEnabled)
        XCTAssertFalse(newService.config.requireForTransactions)
        XCTAssertTrue(newService.config.requireForAppLaunch)
        XCTAssertFalse(newService.config.fallbackToPasscode)
    }
}
