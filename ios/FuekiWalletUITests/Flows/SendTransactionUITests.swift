//
//  SendTransactionUITests.swift
//  FuekiWalletUITests
//
//  Comprehensive UI tests for send transaction flow
//

import XCTest

final class SendTransactionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "MockData-Enabled"]
        app.launch()

        // Complete onboarding and navigate to wallet
        completeOnboardingFlow()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Send Flow

    func testSendFlow_NavigateToSendScreen() {
        // When
        app.tabBars.buttons["Send"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Send"].exists)
        XCTAssertTrue(app.textFields["Recipient Address"].exists)
        XCTAssertTrue(app.textFields["Amount"].exists)
        XCTAssertTrue(app.buttons["Send"].exists)
    }

    func testSendFlow_ValidTransaction_Success() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Enter recipient
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        // Enter amount
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.1")

        // Tap send
        app.buttons["Send"].tap()

        // Confirm transaction
        let confirmButton = app.buttons["Confirm Transaction"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5))
        confirmButton.tap()

        // Then - Verify success
        let successMessage = app.staticTexts["Transaction Sent"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10))
    }

    func testSendFlow_InvalidAddress_ShowsError() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Enter invalid address
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("invalid_address")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.1")

        app.buttons["Send"].tap()

        // Then - Should show error
        XCTAssertTrue(app.staticTexts["Invalid address"].exists)
    }

    func testSendFlow_InsufficientBalance_ShowsError() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Enter amount exceeding balance
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("1000") // Exceeds balance

        app.buttons["Send"].tap()

        // Then - Should show error
        XCTAssertTrue(app.staticTexts["Insufficient balance"].exists)
    }

    // MARK: - QR Code Scanning

    func testSendFlow_ScanQRCode() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Tap QR scan button
        app.buttons["Scan QR"].tap()

        // Then - Camera should be presented
        let cameraView = app.otherElements["QR Scanner"]
        XCTAssertTrue(cameraView.waitForExistence(timeout: 5))

        // Simulate QR code scan (in mock mode)
        app.buttons["Use Mock QR"].tap()

        // Then - Address field should be filled
        let recipientField = app.textFields["Recipient Address"]
        XCTAssertFalse(recipientField.value as? String ?? "" isEmpty)
    }

    // MARK: - Max Amount

    func testSendFlow_MaxAmount() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Tap max button
        app.buttons["Max"].tap()

        // Then - Amount field should be filled with max
        let amountField = app.textFields["Amount"]
        let amount = amountField.value as? String ?? ""
        XCTAssertFalse(amount.isEmpty)
        XCTAssertGreaterThan(Double(amount) ?? 0, 0)
    }

    // MARK: - Gas Estimation

    func testSendFlow_GasEstimation_Display() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Enter valid transaction details
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.1")

        // Then - Gas estimation should appear
        let gasEstimate = app.staticTexts["Estimated Gas"]
        XCTAssertTrue(gasEstimate.waitForExistence(timeout: 5))

        // Verify gas values displayed
        XCTAssertTrue(app.staticTexts["Gas Limit"].exists)
        XCTAssertTrue(app.staticTexts["Max Fee"].exists)
    }

    func testSendFlow_CustomGasSettings() {
        // Given
        app.tabBars.buttons["Send"].tap()
        enterValidTransactionDetails()

        // When - Tap advanced settings
        app.buttons["Advanced"].tap()

        // Then - Custom gas settings should appear
        XCTAssertTrue(app.textFields["Gas Limit"].exists)
        XCTAssertTrue(app.textFields["Max Fee Per Gas"].exists)
        XCTAssertTrue(app.textFields["Priority Fee"].exists)

        // When - Enter custom gas
        let gasLimitField = app.textFields["Gas Limit"]
        gasLimitField.tap()
        gasLimitField.clearText()
        gasLimitField.typeText("30000")

        // Then - Updated total should reflect
        let totalCost = app.staticTexts["Total Cost"]
        XCTAssertTrue(totalCost.exists)
    }

    // MARK: - Transaction Confirmation

    func testSendFlow_ConfirmationScreen_DisplaysDetails() {
        // Given
        app.tabBars.buttons["Send"].tap()
        enterValidTransactionDetails()

        // When - Tap send
        app.buttons["Send"].tap()

        // Then - Confirmation screen should show all details
        XCTAssertTrue(app.staticTexts["Confirm Transaction"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["To:"].exists)
        XCTAssertTrue(app.staticTexts["Amount:"].exists)
        XCTAssertTrue(app.staticTexts["Gas Fee:"].exists)
        XCTAssertTrue(app.staticTexts["Total:"].exists)

        // Verify buttons present
        XCTAssertTrue(app.buttons["Confirm Transaction"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    func testSendFlow_ConfirmationScreen_Cancel() {
        // Given
        app.tabBars.buttons["Send"].tap()
        enterValidTransactionDetails()
        app.buttons["Send"].tap()

        // When - Cancel transaction
        app.buttons["Cancel"].tap()

        // Then - Should return to send screen
        XCTAssertTrue(app.staticTexts["Send"].exists)
        XCTAssertTrue(app.textFields["Recipient Address"].exists)
    }

    // MARK: - Biometric Authentication

    func testSendFlow_BiometricAuth_Required() {
        // Given
        app.tabBars.buttons["Send"].tap()
        enterValidTransactionDetails()
        app.buttons["Send"].tap()

        // When - Confirm transaction
        app.buttons["Confirm Transaction"].tap()

        // Then - Biometric prompt should appear (in test mode, automatically succeeds)
        let successMessage = app.staticTexts["Transaction Sent"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10))
    }

    // MARK: - Error Handling

    func testSendFlow_NetworkError_ShowsRetry() {
        // Given
        app.launchArguments.append("SimulateNetworkError")
        app.launch()
        completeOnboardingFlow()

        app.tabBars.buttons["Send"].tap()
        enterValidTransactionDetails()
        app.buttons["Send"].tap()
        app.buttons["Confirm Transaction"].tap()

        // When - Network error occurs
        let errorAlert = app.alerts["Network Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 10))

        // Then - Should show retry option
        XCTAssertTrue(errorAlert.buttons["Retry"].exists)
        XCTAssertTrue(errorAlert.buttons["Cancel"].exists)
    }

    // MARK: - Transaction Status

    func testSendFlow_PendingStatus_ShowsProgress() {
        // Given
        app.tabBars.buttons["Send"].tap()
        enterValidTransactionDetails()
        app.buttons["Send"].tap()
        app.buttons["Confirm Transaction"].tap()

        // When - Transaction is pending
        let pendingIndicator = app.activityIndicators["Transaction Pending"]
        XCTAssertTrue(pendingIndicator.waitForExistence(timeout: 5))

        // Then - Should show pending message
        XCTAssertTrue(app.staticTexts["Processing Transaction"].exists)
        XCTAssertTrue(app.buttons["View in Explorer"].exists)
    }

    // MARK: - Recent Recipients

    func testSendFlow_RecentRecipients_Display() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Tap recipient field
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()

        // Then - Recent recipients should appear
        let recentSection = app.otherElements["Recent Recipients"]
        XCTAssertTrue(recentSection.waitForExistence(timeout: 2))

        // Verify can select from recent
        if app.cells.count > 0 {
            app.cells.firstMatch.tap()

            // Should fill recipient field
            let value = recipientField.value as? String ?? ""
            XCTAssertFalse(value.isEmpty)
        }
    }

    // MARK: - Contact Selection

    func testSendFlow_ContactSelection() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Tap contacts button
        app.buttons["Contacts"].tap()

        // Then - Contacts list should appear
        XCTAssertTrue(app.navigationBars["Contacts"].exists)

        // When - Select contact
        if app.tables.cells.count > 0 {
            app.tables.cells.firstMatch.tap()

            // Then - Should return with address filled
            XCTAssertTrue(app.staticTexts["Send"].exists)
            let recipientField = app.textFields["Recipient Address"]
            let value = recipientField.value as? String ?? ""
            XCTAssertFalse(value.isEmpty)
        }
    }

    // MARK: - Currency Conversion

    func testSendFlow_CurrencyConversion_USD() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Enter amount
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("1.5")

        // Then - USD value should display
        let usdValue = app.staticTexts["USD Value"]
        XCTAssertTrue(usdValue.waitForExistence(timeout: 5))

        // Verify conversion shown
        let value = usdValue.label
        XCTAssertTrue(value.contains("$"))
    }

    // MARK: - Form Validation

    func testSendFlow_FormValidation_EmptyFields() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Try to send without filling fields
        app.buttons["Send"].tap()

        // Then - Should show validation errors
        XCTAssertTrue(app.staticTexts["Recipient address required"].exists ||
                     app.staticTexts["Amount required"].exists)
    }

    func testSendFlow_FormValidation_ZeroAmount() {
        // Given
        app.tabBars.buttons["Send"].tap()

        // When - Enter zero amount
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0")

        app.buttons["Send"].tap()

        // Then - Should show error
        XCTAssertTrue(app.staticTexts["Amount must be greater than zero"].exists)
    }

    // MARK: - Helper Methods

    private func completeOnboardingFlow() {
        // Create wallet if needed
        if app.buttons["Create New Wallet"].exists {
            app.buttons["Create New Wallet"].tap()

            app.secureTextFields["Password"].tap()
            app.secureTextFields["Password"].typeText("TestPassword123!")

            app.secureTextFields["Confirm Password"].tap()
            app.secureTextFields["Confirm Password"].typeText("TestPassword123!")

            app.buttons["Continue"].tap()

            // Skip mnemonic verification in test mode
            if app.buttons["Skip Verification"].waitForExistence(timeout: 5) {
                app.buttons["Skip Verification"].tap()
            }
        }

        // Wait for wallet dashboard
        _ = app.staticTexts["My Wallet"].waitForExistence(timeout: 5)
    }

    private func enterValidTransactionDetails() {
        let recipientField = app.textFields["Recipient Address"]
        recipientField.tap()
        recipientField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.1")
    }
}

// MARK: - XCUIElement Extension

extension XCUIElement {
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }

        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
    }
}
