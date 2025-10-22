import XCTest

final class TransactionUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "Skip-Onboarding"]
        app.launch()

        // Navigate to Send screen
        _ = app.staticTexts["My Wallet"].waitForExistence(timeout: 5)
        app.buttons["Send"].tap()
        _ = app.staticTexts["Send Bitcoin"].waitForExistence(timeout: 2)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Send Screen Tests

    func testSendScreen_DisplaysAllFields() {
        // Then
        XCTAssertTrue(app.textFields["Recipient Address"].exists)
        XCTAssertTrue(app.textFields["Amount"].exists)
        XCTAssertTrue(app.buttons["Scan QR Code"].exists)
        XCTAssertTrue(app.buttons["Send All"].exists)
        XCTAssertTrue(app.buttons["Review Transaction"].exists)
    }

    func testSendScreen_ScanQRCode_OpensCamera() {
        // When
        app.buttons["Scan QR Code"].tap()

        // Then
        // Camera view should appear
        XCTAssertTrue(app.staticTexts["Scan QR Code"].exists || app.otherElements["CameraView"].exists)
    }

    func testSendScreen_EnterRecipientAddress_Valid() {
        // When
        let addressField = app.textFields["Recipient Address"]
        addressField.tap()
        addressField.typeText("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx")

        // Then
        XCTAssertFalse(app.staticTexts["Invalid address"].exists)
    }

    func testSendScreen_EnterRecipientAddress_Invalid_ShowsError() {
        // When
        let addressField = app.textFields["Recipient Address"]
        addressField.tap()
        addressField.typeText("invalid_address_12345")

        app.textFields["Amount"].tap() // Move focus

        // Then
        XCTAssertTrue(app.staticTexts["Invalid address"].exists)
    }

    func testSendScreen_EnterAmount_Valid() {
        // When
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.001")

        // Then
        XCTAssertTrue(app.staticTexts.matching(identifier: "FiatEquivalent").element.exists)
    }

    func testSendScreen_EnterAmount_ExceedsBalance_ShowsError() {
        // When
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("1000")

        app.buttons["Review Transaction"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Insufficient balance"].exists)
    }

    func testSendScreen_SendAll_FillsMaxAmount() {
        // When
        app.buttons["Send All"].tap()

        // Then
        let amountField = app.textFields["Amount"]
        XCTAssertFalse(amountField.value as? String == "")
    }

    // MARK: - Fee Selection Tests

    func testSendScreen_FeeSelection_DisplaysOptions() {
        // When
        app.buttons["Fee Options"].tap()

        // Then
        XCTAssertTrue(app.buttons["Slow"].exists)
        XCTAssertTrue(app.buttons["Medium"].exists)
        XCTAssertTrue(app.buttons["Fast"].exists)
    }

    func testSendScreen_FeeSelection_ChangeFee_UpdatesTotal() {
        // Given
        fillTransactionFields()

        // When
        app.buttons["Fee Options"].tap()
        let initialTotal = app.staticTexts.matching(identifier: "TotalAmount").element.label

        app.buttons["Fast"].tap()

        // Then
        let newTotal = app.staticTexts.matching(identifier: "TotalAmount").element.label
        XCTAssertNotEqual(initialTotal, newTotal)
    }

    func testSendScreen_CustomFee_AllowsInput() {
        // When
        app.buttons["Fee Options"].tap()
        app.buttons["Custom"].tap()

        // Then
        XCTAssertTrue(app.textFields["Satoshis per byte"].exists)

        // When
        app.textFields["Satoshis per byte"].tap()
        app.textFields["Satoshis per byte"].typeText("25")

        // Then
        XCTAssertTrue(app.staticTexts.matching(identifier: "EstimatedFee").element.exists)
    }

    // MARK: - Transaction Review Tests

    func testSendScreen_ReviewTransaction_ShowsSummary() {
        // Given
        fillTransactionFields()

        // When
        app.buttons["Review Transaction"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Review Transaction"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Recipient"].exists)
        XCTAssertTrue(app.staticTexts["Amount"].exists)
        XCTAssertTrue(app.staticTexts["Fee"].exists)
        XCTAssertTrue(app.staticTexts["Total"].exists)
    }

    func testSendScreen_ReviewTransaction_CanEdit() {
        // Given
        fillTransactionFields()
        app.buttons["Review Transaction"].tap()

        // When
        app.buttons["Edit"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Send Bitcoin"].exists)
        XCTAssertTrue(app.textFields["Amount"].exists)
    }

    func testSendScreen_ConfirmTransaction_RequiresPassword() {
        // Given
        fillTransactionFields()
        app.buttons["Review Transaction"].tap()

        // When
        app.buttons["Confirm & Send"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Enter Password"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.secureTextFields["Password"].exists)
    }

    func testSendScreen_ConfirmTransaction_WrongPassword_ShowsError() {
        // Given
        navigateToConfirmation()

        // When
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("WrongPassword")
        app.buttons["Confirm"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Incorrect password"].exists)
    }

    func testSendScreen_ConfirmTransaction_Success_ShowsSuccess() {
        // Given
        navigateToConfirmation()

        // When
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("TestPassword123!")
        app.buttons["Confirm"].tap()

        // Then
        let successMessage = app.staticTexts["Transaction sent successfully"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10))
    }

    func testSendScreen_TransactionSuccess_ShowsTransactionID() {
        // Given
        sendTransaction()

        // Then
        XCTAssertTrue(app.staticTexts.matching(identifier: "TransactionID").element.exists)
        XCTAssertTrue(app.buttons["View Transaction"].exists)
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testSendScreen_TransactionSuccess_ViewTransaction_NavigatesToDetails() {
        // Given
        sendTransaction()

        // When
        app.buttons["View Transaction"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Transaction Details"].waitForExistence(timeout: 2))
    }

    // MARK: - Input Validation Tests

    func testSendScreen_AmountInput_AcceptsDecimals() {
        // When
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.00123456")

        // Then
        XCTAssertEqual(amountField.value as? String, "0.00123456")
    }

    func testSendScreen_AmountInput_RejectsLetters() {
        // When
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("abc")

        // Then
        XCTAssertNotEqual(amountField.value as? String, "abc")
    }

    func testSendScreen_AmountInput_ShowsFiatConversion() {
        // When
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.001")

        // Then
        XCTAssertTrue(app.staticTexts.matching(identifier: "FiatEquivalent").element.exists)
    }

    // MARK: - Cancel Transaction Tests

    func testSendScreen_Cancel_ReturnsToWallet() {
        // When
        app.buttons["Cancel"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["My Wallet"].waitForExistence(timeout: 2))
    }

    func testSendScreen_CancelAfterReview_ShowsConfirmation() {
        // Given
        fillTransactionFields()
        app.buttons["Review Transaction"].tap()

        // When
        app.buttons["Cancel"].tap()

        // Then
        XCTAssertTrue(app.alerts["Cancel Transaction?"].exists)
        XCTAssertTrue(app.buttons["Yes, Cancel"].exists)
        XCTAssertTrue(app.buttons["No, Continue"].exists)
    }

    // MARK: - Accessibility Tests

    func testSendScreen_VoiceOverSupport() {
        XCTAssertNotNil(app.textFields["Recipient Address"].accessibilityLabel)
        XCTAssertNotNil(app.textFields["Amount"].accessibilityLabel)
        XCTAssertNotNil(app.buttons["Review Transaction"].accessibilityLabel)
    }

    func testSendScreen_DynamicType() {
        // Verify text scales with system text size
        // Would require adjusting system settings
    }

    // MARK: - Helper Methods

    private func fillTransactionFields() {
        let addressField = app.textFields["Recipient Address"]
        addressField.tap()
        addressField.typeText("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx")

        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.001")
    }

    private func navigateToConfirmation() {
        fillTransactionFields()
        app.buttons["Review Transaction"].tap()
        _ = app.staticTexts["Review Transaction"].waitForExistence(timeout: 2)
        app.buttons["Confirm & Send"].tap()
        _ = app.staticTexts["Enter Password"].waitForExistence(timeout: 2)
    }

    private func sendTransaction() {
        navigateToConfirmation()
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("TestPassword123!")
        app.buttons["Confirm"].tap()
        _ = app.staticTexts["Transaction sent successfully"].waitForExistence(timeout: 10)
    }
}
