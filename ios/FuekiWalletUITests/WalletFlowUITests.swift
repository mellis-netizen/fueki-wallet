import XCTest

final class WalletFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing", "Skip-Onboarding"]
        app.launch()

        // Ensure we're on the wallet screen
        _ = app.staticTexts["My Wallet"].waitForExistence(timeout: 5)
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Wallet Home Screen Tests

    func testWalletHome_DisplaysBalance() {
        // Then
        XCTAssertTrue(app.staticTexts["Balance"].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "BalanceAmount").element.exists)
    }

    func testWalletHome_DisplaysAddress() {
        // Then
        XCTAssertTrue(app.buttons["Show Address"].exists)

        // When
        app.buttons["Show Address"].tap()

        // Then
        XCTAssertTrue(app.staticTexts.matching(identifier: "WalletAddress").element.exists)
    }

    func testWalletHome_CopyAddress_ShowsConfirmation() {
        // Given
        app.buttons["Show Address"].tap()

        // When
        app.buttons["Copy Address"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Address copied"].waitForExistence(timeout: 2))
    }

    func testWalletHome_RefreshBalance_UpdatesUI() {
        // When
        app.buttons["Refresh"].tap()

        // Then
        let activityIndicator = app.activityIndicators["Loading"]
        XCTAssertTrue(activityIndicator.exists)

        // Wait for refresh to complete
        XCTAssertFalse(activityIndicator.waitForNonExistence(timeout: 5))
    }

    func testWalletHome_NavigateToSend() {
        // When
        app.buttons["Send"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Send Bitcoin"].waitForExistence(timeout: 2))
    }

    func testWalletHome_NavigateToReceive() {
        // When
        app.buttons["Receive"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Receive Bitcoin"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.images["QRCode"].exists)
    }

    func testWalletHome_NavigateToTransactions() {
        // When
        app.buttons["Transactions"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Transaction History"].waitForExistence(timeout: 2))
    }

    // MARK: - Receive Bitcoin Tests

    func testReceive_DisplaysQRCode() {
        // Given
        app.buttons["Receive"].tap()

        // Then
        XCTAssertTrue(app.images["QRCode"].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "ReceiveAddress").element.exists)
    }

    func testReceive_ShareAddress_OpensShareSheet() {
        // Given
        app.buttons["Receive"].tap()

        // When
        app.buttons["Share"].tap()

        // Then
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 3))
    }

    func testReceive_GenerateNewAddress() {
        // Given
        app.buttons["Receive"].tap()
        let originalAddress = app.staticTexts.matching(identifier: "ReceiveAddress").element.label

        // When
        app.buttons["Generate New Address"].tap()

        // Then
        let newAddress = app.staticTexts.matching(identifier: "ReceiveAddress").element.label
        XCTAssertNotEqual(originalAddress, newAddress)
    }

    // MARK: - Transaction List Tests

    func testTransactionList_DisplaysTransactions() {
        // Given
        app.buttons["Transactions"].tap()

        // Then
        let transactionList = app.tables["TransactionList"]
        XCTAssertTrue(transactionList.exists)
    }

    func testTransactionList_FilterByType() {
        // Given
        app.buttons["Transactions"].tap()

        // When
        app.buttons["Filter"].tap()
        app.buttons["Received"].tap()

        // Then
        // Verify filter is applied (received transactions shown)
        XCTAssertTrue(app.staticTexts["Showing: Received"].exists)
    }

    func testTransactionList_TapTransaction_ShowsDetails() {
        // Given
        app.buttons["Transactions"].tap()

        // When
        let firstTransaction = app.tables["TransactionList"].cells.firstMatch
        if firstTransaction.exists {
            firstTransaction.tap()

            // Then
            XCTAssertTrue(app.staticTexts["Transaction Details"].waitForExistence(timeout: 2))
        }
    }

    func testTransactionList_PullToRefresh() {
        // Given
        app.buttons["Transactions"].tap()
        let transactionList = app.tables["TransactionList"]

        // When
        transactionList.swipeDown()

        // Then
        let refreshControl = app.activityIndicators["RefreshControl"]
        XCTAssertTrue(refreshControl.exists)
    }

    // MARK: - Transaction Details Tests

    func testTransactionDetails_DisplaysAllInfo() {
        // Given
        app.buttons["Transactions"].tap()
        let firstTransaction = app.tables["TransactionList"].cells.firstMatch

        if firstTransaction.exists {
            firstTransaction.tap()

            // Then
            XCTAssertTrue(app.staticTexts["Amount"].exists)
            XCTAssertTrue(app.staticTexts["Status"].exists)
            XCTAssertTrue(app.staticTexts["Date"].exists)
            XCTAssertTrue(app.staticTexts["Transaction ID"].exists)
            XCTAssertTrue(app.staticTexts["Confirmations"].exists)
        }
    }

    func testTransactionDetails_CopyTransactionID() {
        // Given
        navigateToFirstTransactionDetails()

        // When
        app.buttons["Copy Transaction ID"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Transaction ID copied"].waitForExistence(timeout: 2))
    }

    func testTransactionDetails_ViewOnExplorer() {
        // Given
        navigateToFirstTransactionDetails()

        // When
        app.buttons["View on Block Explorer"].tap()

        // Then
        // Safari or in-app browser should open
        // This is platform-dependent
    }

    // MARK: - Wallet Settings Tests

    func testWalletSettings_Navigate() {
        // When
        app.buttons["Settings"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 2))
    }

    func testWalletSettings_DisplaysOptions() {
        // Given
        app.buttons["Settings"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Network"].exists)
        XCTAssertTrue(app.staticTexts["Security"].exists)
        XCTAssertTrue(app.staticTexts["Backup Wallet"].exists)
    }

    func testWalletSettings_ToggleNetwork() {
        // Given
        app.buttons["Settings"].tap()

        // When
        app.cells["Network"].tap()
        app.buttons["Mainnet"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Switch to Mainnet?"].exists)
        XCTAssertTrue(app.buttons["Cancel"].exists)
        XCTAssertTrue(app.buttons["Switch"].exists)
    }

    // MARK: - Lock/Unlock Tests

    func testWallet_Lock_ShowsUnlockScreen() {
        // When
        app.buttons["Lock Wallet"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Enter Password"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.secureTextFields["Password"].exists)
    }

    func testWallet_Unlock_CorrectPassword_Success() {
        // Given
        app.buttons["Lock Wallet"].tap()

        // When
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("TestPassword123!")
        app.buttons["Unlock"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["My Wallet"].waitForExistence(timeout: 2))
    }

    func testWallet_Unlock_WrongPassword_ShowsError() {
        // Given
        app.buttons["Lock Wallet"].tap()

        // When
        app.secureTextFields["Password"].tap()
        app.secureTextFields["Password"].typeText("WrongPassword")
        app.buttons["Unlock"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Incorrect password"].exists)
    }

    // MARK: - Accessibility Tests

    func testWallet_VoiceOverLabels() {
        XCTAssertNotNil(app.buttons["Send"].accessibilityLabel)
        XCTAssertNotNil(app.buttons["Receive"].accessibilityLabel)
        XCTAssertNotNil(app.buttons["Transactions"].accessibilityLabel)
    }

    func testWallet_MinimumTapTargets() {
        // Verify buttons meet minimum tap target size (44x44 points)
        let sendButton = app.buttons["Send"]
        XCTAssertGreaterThanOrEqual(sendButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(sendButton.frame.height, 44)
    }

    // MARK: - Helper Methods

    private func navigateToFirstTransactionDetails() {
        app.buttons["Transactions"].tap()
        let firstTransaction = app.tables["TransactionList"].cells.firstMatch

        if firstTransaction.exists {
            firstTransaction.tap()
            _ = app.staticTexts["Transaction Details"].waitForExistence(timeout: 2)
        }
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        return result == .completed
    }
}
