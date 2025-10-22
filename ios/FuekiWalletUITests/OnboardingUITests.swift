import XCTest

final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Initial Launch Tests

    func testOnboardingScreen_AppearsOnFirstLaunch() {
        // Then
        XCTAssertTrue(app.staticTexts["Welcome to Fueki Wallet"].exists)
        XCTAssertTrue(app.buttons["Create New Wallet"].exists)
        XCTAssertTrue(app.buttons["Import Wallet"].exists)
    }

    func testOnboardingScreen_DisplaysAppLogo() {
        // Then
        XCTAssertTrue(app.images["AppLogo"].exists)
    }

    // MARK: - Create New Wallet Flow

    func testCreateNewWallet_NavigatesToPasswordScreen() {
        // When
        app.buttons["Create New Wallet"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Create Password"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        XCTAssertTrue(app.secureTextFields["Confirm Password"].exists)
    }

    func testCreateNewWallet_WeakPassword_ShowsError() {
        // Given
        app.buttons["Create New Wallet"].tap()

        // When
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("123")

        app.buttons["Continue"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Password too weak"].exists)
    }

    func testCreateNewWallet_PasswordMismatch_ShowsError() {
        // Given
        app.buttons["Create New Wallet"].tap()

        // When
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("SecurePass123!")

        app.secureTextFields["Confirm Password"].tap()
        app.secureTextFields["Confirm Password"].typeText("DifferentPass123!")

        app.buttons["Continue"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Passwords do not match"].exists)
    }

    func testCreateNewWallet_ValidPassword_ShowsMnemonicScreen() {
        // Given
        app.buttons["Create New Wallet"].tap()

        // When
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("SecurePass123!")

        app.secureTextFields["Confirm Password"].tap()
        app.secureTextFields["Confirm Password"].typeText("SecurePass123!")

        app.buttons["Continue"].tap()

        // Then
        let mnemonicScreen = app.staticTexts["Backup Your Recovery Phrase"]
        XCTAssertTrue(mnemonicScreen.waitForExistence(timeout: 5))
    }

    func testCreateNewWallet_MnemonicDisplay_Shows12Words() {
        // Given
        createWalletToMnemonicScreen()

        // Then
        // Check for mnemonic word labels (numbered 1-12)
        for i in 1...12 {
            XCTAssertTrue(app.staticTexts["Word \(i)"].exists)
        }
    }

    func testCreateNewWallet_CopyMnemonic_ShowsConfirmation() {
        // Given
        createWalletToMnemonicScreen()

        // When
        app.buttons["Copy to Clipboard"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Copied to clipboard"].waitForExistence(timeout: 2))
    }

    func testCreateNewWallet_ConfirmMnemonic_RequiresSelection() {
        // Given
        createWalletToMnemonicScreen()
        app.buttons["I've Backed It Up"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Verify Recovery Phrase"].exists)
        XCTAssertTrue(app.staticTexts["Select the missing words"].exists)
    }

    func testCreateNewWallet_CompleteFlow_NavigatesToWallet() {
        // Given
        createWalletToMnemonicScreen()
        app.buttons["I've Backed It Up"].tap()

        // When - simulate word verification
        app.buttons["Skip Verification"].tap() // In test mode

        // Then
        let walletScreen = app.staticTexts["My Wallet"]
        XCTAssertTrue(walletScreen.waitForExistence(timeout: 5))
    }

    // MARK: - Import Wallet Flow

    func testImportWallet_NavigatesToMnemonicInput() {
        // When
        app.buttons["Import Wallet"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Import Wallet"].exists)
        XCTAssertTrue(app.textViews["Mnemonic Phrase"].exists)
    }

    func testImportWallet_InvalidMnemonic_ShowsError() {
        // Given
        app.buttons["Import Wallet"].tap()

        // When
        let mnemonicField = app.textViews["Mnemonic Phrase"]
        mnemonicField.tap()
        mnemonicField.typeText("invalid mnemonic phrase")

        app.buttons["Continue"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Invalid recovery phrase"].exists)
    }

    func testImportWallet_ValidMnemonic_NavigatesToPasswordScreen() {
        // Given
        app.buttons["Import Wallet"].tap()

        // When
        let mnemonicField = app.textViews["Mnemonic Phrase"]
        mnemonicField.tap()
        mnemonicField.typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")

        app.buttons["Continue"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Create Password"].waitForExistence(timeout: 2))
    }

    func testImportWallet_CompleteFlow_NavigatesToWallet() {
        // Given
        app.buttons["Import Wallet"].tap()

        // When
        app.textViews["Mnemonic Phrase"].tap()
        app.textViews["Mnemonic Phrase"].typeText("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
        app.buttons["Continue"].tap()

        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("SecurePass123!")
        app.secureTextFields["Confirm Password"].tap()
        app.secureTextFields["Confirm Password"].typeText("SecurePass123!")
        app.buttons["Import"].tap()

        // Then
        let walletScreen = app.staticTexts["My Wallet"]
        XCTAssertTrue(walletScreen.waitForExistence(timeout: 10))
    }

    // MARK: - Accessibility Tests

    func testOnboarding_VoiceOverAccessibility() {
        // Given
        XCUIApplication.shared.activate()

        // Then
        XCTAssertNotNil(app.buttons["Create New Wallet"].accessibilityLabel)
        XCTAssertNotNil(app.buttons["Import Wallet"].accessibilityLabel)
        XCTAssertTrue(app.buttons["Create New Wallet"].isAccessibilityElement)
        XCTAssertTrue(app.buttons["Import Wallet"].isAccessibilityElement)
    }

    func testOnboarding_DynamicTypeSupport() {
        // Test with different text sizes
        // This would require adjusting system settings programmatically
        // or using launch arguments to enable larger text
    }

    // MARK: - Helper Methods

    private func createWalletToMnemonicScreen() {
        app.buttons["Create New Wallet"].tap()

        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("SecurePass123!")

        app.secureTextFields["Confirm Password"].tap()
        app.secureTextFields["Confirm Password"].typeText("SecurePass123!")

        app.buttons["Continue"].tap()

        _ = app.staticTexts["Backup Your Recovery Phrase"].waitForExistence(timeout: 5)
    }
}
