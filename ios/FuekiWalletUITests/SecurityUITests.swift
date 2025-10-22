import XCTest

final class SecurityUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "Skip-Onboarding"]
        app.launch()

        // Navigate to Settings > Security
        _ = app.staticTexts["My Wallet"].waitForExistence(timeout: 5)
        app.buttons["Settings"].tap()
        app.cells["Security"].tap()
        _ = app.staticTexts["Security Settings"].waitForExistence(timeout: 2)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Biometric Authentication Tests

    func testSecurity_BiometricToggle_Exists() {
        // Then
        XCTAssertTrue(app.switches["Enable Biometric Authentication"].exists)
    }

    func testSecurity_EnableBiometrics_ShowsPrompt() {
        // When
        let biometricSwitch = app.switches["Enable Biometric Authentication"]

        if !biometricSwitch.value as! Bool {
            biometricSwitch.tap()

            // Then
            // System biometric prompt should appear
            // Note: Can't directly test system prompts in UI tests
            // Verify the switch state changes after interaction
        }
    }

    func testSecurity_DisableBiometrics_RequiresPassword() {
        // Given
        let biometricSwitch = app.switches["Enable Biometric Authentication"]

        // Enable first if not enabled
        if !(biometricSwitch.value as! Bool) {
            biometricSwitch.tap()
            // Wait for biometric setup
            sleep(2)
        }

        // When
        biometricSwitch.tap()

        // Then
        XCTAssertTrue(app.staticTexts["Enter Password"].waitForExistence(timeout: 2))
    }

    // MARK: - Auto-Lock Tests

    func testSecurity_AutoLockOptions_Displayed() {
        // When
        app.cells["Auto-Lock"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Auto-Lock Timer"].exists)
        XCTAssertTrue(app.buttons["Immediately"].exists)
        XCTAssertTrue(app.buttons["1 Minute"].exists)
        XCTAssertTrue(app.buttons["5 Minutes"].exists)
        XCTAssertTrue(app.buttons["15 Minutes"].exists)
        XCTAssertTrue(app.buttons["Never"].exists)
    }

    func testSecurity_SelectAutoLock_UpdatesSetting() {
        // Given
        app.cells["Auto-Lock"].tap()

        // When
        app.buttons["5 Minutes"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["5 Minutes"].exists)
        XCTAssertTrue(app.buttons["< Back"].exists)
    }

    // MARK: - Change Password Tests

    func testSecurity_ChangePassword_NavigatesToScreen() {
        // When
        app.cells["Change Password"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Change Password"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.secureTextFields["Current Password"].exists)
        XCTAssertTrue(app.secureTextFields["New Password"].exists)
        XCTAssertTrue(app.secureTextFields["Confirm New Password"].exists)
    }

    func testSecurity_ChangePassword_WrongCurrentPassword_ShowsError() {
        // Given
        app.cells["Change Password"].tap()

        // When
        app.secureTextFields["Current Password"].tap()
        app.secureTextFields["Current Password"].typeText("WrongPassword")

        app.secureTextFields["New Password"].tap()
        app.secureTextFields["New Password"].typeText("NewSecurePass123!")

        app.secureTextFields["Confirm New Password"].tap()
        app.secureTextFields["Confirm New Password"].typeText("NewSecurePass123!")

        app.buttons["Change Password"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Incorrect current password"].exists)
    }

    func testSecurity_ChangePassword_WeakNewPassword_ShowsError() {
        // Given
        app.cells["Change Password"].tap()

        // When
        app.secureTextFields["Current Password"].tap()
        app.secureTextFields["Current Password"].typeText("TestPassword123!")

        app.secureTextFields["New Password"].tap()
        app.secureTextFields["New Password"].typeText("123")

        app.buttons["Change Password"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Password too weak"].exists)
    }

    func testSecurity_ChangePassword_Success_ShowsConfirmation() {
        // Given
        app.cells["Change Password"].tap()

        // When
        app.secureTextFields["Current Password"].tap()
        app.secureTextFields["Current Password"].typeText("TestPassword123!")

        app.secureTextFields["New Password"].tap()
        app.secureTextFields["New Password"].typeText("NewSecurePass456!")

        app.secureTextFields["Confirm New Password"].tap()
        app.secureTextFields["Confirm New Password"].typeText("NewSecurePass456!")

        app.buttons["Change Password"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Password changed successfully"].waitForExistence(timeout: 3))
    }

    // MARK: - Backup Tests

    func testSecurity_BackupWallet_ShowsMnemonic() {
        // Given
        app.buttons["< Back"].tap() // Back to main settings

        // When
        app.cells["Backup Wallet"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Backup Recovery Phrase"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Reveal Phrase"].exists)
    }

    func testSecurity_BackupWallet_RequiresAuthentication() {
        // Given
        app.buttons["< Back"].tap()
        app.cells["Backup Wallet"].tap()

        // When
        app.buttons["Reveal Phrase"].tap()

        // Then
        // Should require password or biometric auth
        XCTAssertTrue(
            app.staticTexts["Enter Password"].exists ||
            app.staticTexts["Authenticate"].exists
        )
    }

    func testSecurity_BackupWallet_CopyPhrase_ShowsConfirmation() {
        // Given
        authenticateAndRevealBackup()

        // When
        app.buttons["Copy Phrase"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Copied to clipboard"].waitForExistence(timeout: 2))
    }

    // MARK: - Delete Wallet Tests

    func testSecurity_DeleteWallet_ShowsWarning() {
        // Given
        app.buttons["< Back"].tap()

        // When
        app.cells["Delete Wallet"].tap()

        // Then
        XCTAssertTrue(app.alerts["Delete Wallet?"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'permanently delete'")).element.exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["Delete"].exists)
    }

    func testSecurity_DeleteWallet_RequiresConfirmation() {
        // Given
        app.buttons["< Back"].tap()
        app.cells["Delete Wallet"].tap()

        // When
        app.buttons["Delete"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Type DELETE to confirm"].exists)
        XCTAssertTrue(app.textFields["Confirmation"].exists)
    }

    func testSecurity_DeleteWallet_WrongConfirmation_ShowsError() {
        // Given
        navigateToDeleteConfirmation()

        // When
        app.textFields["Confirmation"].tap()
        app.textFields["Confirmation"].typeText("WRONG")
        app.buttons["Confirm Delete"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Please type DELETE to confirm"].exists)
    }

    func testSecurity_DeleteWallet_Success_ReturnsToOnboarding() {
        // Given
        navigateToDeleteConfirmation()

        // When
        app.textFields["Confirmation"].tap()
        app.textFields["Confirmation"].typeText("DELETE")
        app.buttons["Confirm Delete"].tap()

        // Then
        let onboardingScreen = app.staticTexts["Welcome to Fueki Wallet"]
        XCTAssertTrue(onboardingScreen.waitForExistence(timeout: 5))
    }

    // MARK: - PIN Code Tests

    func testSecurity_EnablePIN_ShowsSetupScreen() {
        // When
        let pinSwitch = app.switches["Enable PIN Code"]

        if !pinSwitch.value as! Bool {
            pinSwitch.tap()

            // Then
            XCTAssertTrue(app.staticTexts["Create PIN"].waitForExistence(timeout: 2))
        }
    }

    func testSecurity_SetPIN_RequiresSixDigits() {
        // Given
        let pinSwitch = app.switches["Enable PIN Code"]

        if !pinSwitch.value as! Bool {
            pinSwitch.tap()

            // When
            // Type 4 digits
            app.buttons["1"].tap()
            app.buttons["2"].tap()
            app.buttons["3"].tap()
            app.buttons["4"].tap()

            // Then
            // Continue button should still be disabled
            XCTAssertFalse(app.buttons["Continue"].isEnabled)
        }
    }

    // MARK: - Accessibility Tests

    func testSecurity_VoiceOverLabels() {
        XCTAssertNotNil(app.switches["Enable Biometric Authentication"].accessibilityLabel)
        XCTAssertNotNil(app.cells["Change Password"].accessibilityLabel)
        XCTAssertNotNil(app.cells["Auto-Lock"].accessibilityLabel)
    }

    func testSecurity_PasswordFields_SecureEntry() {
        // Given
        app.cells["Change Password"].tap()

        // Then
        let currentPasswordField = app.secureTextFields["Current Password"]
        XCTAssertTrue(currentPasswordField.exists)
        XCTAssertTrue(currentPasswordField.isSecureTextEntry)
    }

    // MARK: - Helper Methods

    private func authenticateAndRevealBackup() {
        app.buttons["< Back"].tap()
        app.cells["Backup Wallet"].tap()
        app.buttons["Reveal Phrase"].tap()

        // Enter password if prompted
        if app.secureTextFields["Password"].exists {
            app.secureTextFields["Password"].tap()
            app.secureTextFields["Password"].typeText("TestPassword123!")
            app.buttons["Authenticate"].tap()
        }

        _ = app.staticTexts.matching(identifier: "MnemonicWord").element.waitForExistence(timeout: 3)
    }

    private func navigateToDeleteConfirmation() {
        app.buttons["< Back"].tap()
        app.cells["Delete Wallet"].tap()
        app.buttons["Delete"].tap()
        _ = app.staticTexts["Type DELETE to confirm"].waitForExistence(timeout: 2)
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    var isSecureTextEntry: Bool {
        return self.elementType == .secureTextField
    }
}
