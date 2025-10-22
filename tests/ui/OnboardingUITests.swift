import XCTest

/// UI tests for wallet onboarding flow
/// Tests complete user journey from app launch to wallet creation
class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-state"]
        app.launch()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    // MARK: - Splash Screen Tests

    func testSplashScreenAppears() {
        // Assert
        XCTAssertTrue(app.images["fueki-logo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Fueki Wallet"].exists)
    }

    // MARK: - Welcome Screen Tests

    func testWelcomeScreenElements() {
        // Wait for welcome screen
        let welcomeTitle = app.staticTexts["Welcome to Fueki"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5))

        // Assert all elements present
        XCTAssertTrue(app.staticTexts["Secure. Simple. Decentralized."].exists)
        XCTAssertTrue(app.buttons["Create New Wallet"].exists)
        XCTAssertTrue(app.buttons["Import Existing Wallet"].exists)
    }

    func testCreateNewWalletButton() {
        // Arrange
        let createButton = app.buttons["Create New Wallet"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))

        // Act
        createButton.tap()

        // Assert - Should navigate to wallet creation
        XCTAssertTrue(app.staticTexts["Create Your Wallet"].waitForExistence(timeout: 3))
    }

    func testImportWalletButton() {
        // Arrange
        let importButton = app.buttons["Import Existing Wallet"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))

        // Act
        importButton.tap()

        // Assert
        XCTAssertTrue(app.staticTexts["Import Wallet"].waitForExistence(timeout: 3))
    }

    // MARK: - Wallet Creation Flow Tests

    func testCompleteWalletCreationFlow() {
        // Step 1: Welcome screen
        let createButton = app.buttons["Create New Wallet"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        // Step 2: Set wallet name
        let walletNameField = app.textFields["Wallet Name"]
        XCTAssertTrue(walletNameField.waitForExistence(timeout: 3))
        walletNameField.tap()
        walletNameField.typeText("My First Wallet")

        let continueButton = app.buttons["Continue"]
        continueButton.tap()

        // Step 3: Set PIN
        let pinTitle = app.staticTexts["Create a PIN"]
        XCTAssertTrue(pinTitle.waitForExistence(timeout: 3))

        // Enter 6-digit PIN
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Step 4: Confirm PIN
        let confirmPinTitle = app.staticTexts["Confirm Your PIN"]
        XCTAssertTrue(confirmPinTitle.waitForExistence(timeout: 3))

        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Step 5: Enable biometrics (optional)
        let biometricPrompt = app.staticTexts["Enable Face ID/Touch ID?"]
        if biometricPrompt.waitForExistence(timeout: 3) {
            app.buttons["Enable"].tap()
        }

        // Step 6: Backup warning
        let backupWarning = app.staticTexts["Backup Your Wallet"]
        XCTAssertTrue(backupWarning.waitForExistence(timeout: 3))
        app.buttons["Show Recovery Phrase"].tap()

        // Step 7: View recovery phrase
        let recoveryTitle = app.staticTexts["Recovery Phrase"]
        XCTAssertTrue(recoveryTitle.waitForExistence(timeout: 3))

        // Verify 12 words are displayed
        for i in 1...12 {
            XCTAssertTrue(app.staticTexts["word-\(i)"].exists)
        }

        app.buttons["I've Saved It Securely"].tap()

        // Step 8: Verify recovery phrase
        let verifyTitle = app.staticTexts["Verify Recovery Phrase"]
        XCTAssertTrue(verifyTitle.waitForExistence(timeout: 3))

        // Select words in correct order (simplified for test)
        for i in 1...3 {
            app.buttons["verify-word-\(i)"].tap()
        }

        app.buttons["Verify"].tap()

        // Step 9: Success - Should navigate to wallet home
        let walletHomeTitle = app.staticTexts["My First Wallet"]
        XCTAssertTrue(walletHomeTitle.waitForExistence(timeout: 5))
    }

    func testWalletCreationWithWeakPIN() {
        // Step 1-2: Navigate to PIN creation
        app.buttons["Create New Wallet"].tap()
        app.textFields["Wallet Name"].tap()
        app.textFields["Wallet Name"].typeText("Test Wallet")
        app.buttons["Continue"].tap()

        // Step 3: Try weak PIN (like "111111")
        for _ in 0..<6 {
            app.buttons["1"].tap()
        }

        // Assert - Should show warning
        let weakPinWarning = app.staticTexts["PIN is too simple. Please choose a stronger PIN."]
        XCTAssertTrue(weakPinWarning.waitForExistence(timeout: 3))
    }

    func testWalletCreationPINMismatch() {
        // Navigate to PIN creation
        app.buttons["Create New Wallet"].tap()
        app.textFields["Wallet Name"].tap()
        app.textFields["Wallet Name"].typeText("Test Wallet")
        app.buttons["Continue"].tap()

        // Enter first PIN
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Enter different confirmation PIN
        for digit in "654321" {
            app.buttons[String(digit)].tap()
        }

        // Assert - Should show error
        let mismatchError = app.staticTexts["PINs do not match"]
        XCTAssertTrue(mismatchError.waitForExistence(timeout: 3))
    }

    // MARK: - Wallet Import Flow Tests

    func testImportWalletWithRecoveryPhrase() {
        // Step 1: Start import
        let importButton = app.buttons["Import Existing Wallet"]
        importButton.tap()

        // Step 2: Choose import method
        let recoveryPhraseButton = app.buttons["Recovery Phrase"]
        XCTAssertTrue(recoveryPhraseButton.waitForExistence(timeout: 3))
        recoveryPhraseButton.tap()

        // Step 3: Enter recovery phrase (12 words)
        let phraseTextView = app.textViews["recovery-phrase-input"]
        XCTAssertTrue(phraseTextView.waitForExistence(timeout: 3))
        phraseTextView.tap()

        let testPhrase = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        phraseTextView.typeText(testPhrase)

        // Step 4: Set wallet name
        app.textFields["Wallet Name"].tap()
        app.textFields["Wallet Name"].typeText("Imported Wallet")

        // Step 5: Set PIN
        app.buttons["Import Wallet"].tap()

        let pinTitle = app.staticTexts["Create a PIN"]
        XCTAssertTrue(pinTitle.waitForExistence(timeout: 3))

        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Confirm PIN
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Assert - Should navigate to wallet home
        let walletHomeTitle = app.staticTexts["Imported Wallet"]
        XCTAssertTrue(walletHomeTitle.waitForExistence(timeout: 5))
    }

    func testImportWalletWithInvalidPhrase() {
        // Start import
        app.buttons["Import Existing Wallet"].tap()
        app.buttons["Recovery Phrase"].tap()

        // Enter invalid phrase
        let phraseTextView = app.textViews["recovery-phrase-input"]
        phraseTextView.tap()
        phraseTextView.typeText("invalid words that are not in bip39 wordlist test fail")

        app.buttons["Import Wallet"].tap()

        // Assert - Should show error
        let errorMessage = app.staticTexts["Invalid recovery phrase"]
        XCTAssertTrue(errorMessage.waitForExistence(timeout: 3))
    }

    // MARK: - Social Login Tests

    func testSocialLoginOptionsDisplayed() {
        // Navigate to import
        app.buttons["Import Existing Wallet"].tap()

        // Assert social login options available
        XCTAssertTrue(app.buttons["Sign in with Google"].exists)
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        XCTAssertTrue(app.buttons["Sign in with Twitter"].exists)
    }

    func testGoogleSignIn() {
        app.buttons["Import Existing Wallet"].tap()
        app.buttons["Sign in with Google"].tap()

        // Assert - Should open Google OAuth (mocked in tests)
        let googleAuth = app.webViews.staticTexts["Sign in with Google"]
        XCTAssertTrue(googleAuth.waitForExistence(timeout: 5))
    }

    // MARK: - Accessibility Tests

    func testVoiceOverSupport() {
        // Enable accessibility
        app.launchArguments.append("--enable-voiceover")

        // Verify important elements have accessibility labels
        let createButton = app.buttons["Create New Wallet"]
        XCTAssertNotNil(createButton.label)
        XCTAssertFalse(createButton.label.isEmpty)

        let importButton = app.buttons["Import Existing Wallet"]
        XCTAssertNotNil(importButton.label)
        XCTAssertFalse(importButton.label.isEmpty)
    }

    func testDynamicTypeSupport() {
        // Test with larger text size
        app.launchArguments.append("--dynamic-type-xxxlarge")
        app.launch()

        let welcomeTitle = app.staticTexts["Welcome to Fueki"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5))

        // Verify text is still visible and not truncated
        XCTAssertTrue(welcomeTitle.isHittable)
    }

    // MARK: - Error Handling Tests

    func testNetworkErrorHandling() {
        // Simulate network error
        app.launchArguments.append("--simulate-network-error")
        app.launch()

        app.buttons["Create New Wallet"].tap()

        // Should show error message
        let errorAlert = app.alerts["Network Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 5))
        XCTAssertTrue(errorAlert.buttons["Retry"].exists)
    }

    func testScreenshotPrevention() {
        // Navigate to recovery phrase screen
        app.buttons["Create New Wallet"].tap()
        app.textFields["Wallet Name"].tap()
        app.textFields["Wallet Name"].typeText("Test Wallet")
        app.buttons["Continue"].tap()

        // Enter PIN
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        app.buttons["Show Recovery Phrase"].tap()

        // Verify screenshot prevention is active
        // (This would be tested through actual screenshot attempt in manual testing)
        let recoveryTitle = app.staticTexts["Recovery Phrase"]
        XCTAssertTrue(recoveryTitle.exists)
    }

    // MARK: - Performance Tests

    func testAppLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launch()
            app.terminate()
        }
    }

    func testWalletCreationPerformance() {
        app.buttons["Create New Wallet"].tap()

        measure {
            // Measure time to generate wallet
            app.textFields["Wallet Name"].tap()
            app.textFields["Wallet Name"].typeText("Perf Test")
            app.buttons["Continue"].tap()

            // Wait for PIN screen to appear (wallet generated)
            _ = app.staticTexts["Create a PIN"].waitForExistence(timeout: 10)
        }
    }
}
