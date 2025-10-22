import XCTest

/// UI tests for main wallet functionality (send, receive, transaction history)
class WalletUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-wallet"]
        app.launch()

        // Assume we start with an existing wallet for these tests
        loginToTestWallet()
    }

    override func tearDown() {
        app = nil
        super.tearDown()
    }

    func loginToTestWallet() {
        // Enter test PIN
        if app.staticTexts["Enter PIN"].waitForExistence(timeout: 5) {
            for digit in "123456" {
                app.buttons[String(digit)].tap()
            }
        }
    }

    // MARK: - Wallet Home Screen Tests

    func testWalletHomeElements() {
        // Assert main elements are visible
        XCTAssertTrue(app.staticTexts["My Wallet"].exists)
        XCTAssertTrue(app.staticTexts["balance-label"].exists)
        XCTAssertTrue(app.buttons["Send"].exists)
        XCTAssertTrue(app.buttons["Receive"].exists)
        XCTAssertTrue(app.buttons["Buy"].exists)
        XCTAssertTrue(app.tables["transaction-history"].exists)
    }

    func testBalanceDisplay() {
        // Verify balance is displayed correctly
        let balanceLabel = app.staticTexts["balance-label"]
        XCTAssertTrue(balanceLabel.exists)

        let balanceText = balanceLabel.label
        XCTAssertTrue(balanceText.contains("ETH") || balanceText.contains("$"), "Balance should show currency")
    }

    func testMultipleTokensDisplay() {
        // Scroll to token list
        let tokenList = app.collectionViews["token-list"]
        XCTAssertTrue(tokenList.exists)

        // Verify multiple tokens are displayed
        XCTAssertTrue(app.cells["token-ETH"].exists)
        XCTAssertTrue(app.cells["token-USDC"].exists)
    }

    // MARK: - Send Flow Tests

    func testCompleteSendFlow() {
        // Step 1: Tap Send button
        app.buttons["Send"].tap()

        // Step 2: Enter recipient address
        let addressField = app.textFields["recipient-address"]
        XCTAssertTrue(addressField.waitForExistence(timeout: 3))
        addressField.tap()
        addressField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        // Step 3: Enter amount
        let amountField = app.textFields["amount"]
        amountField.tap()
        amountField.typeText("0.1")

        // Step 4: Review transaction
        app.buttons["Review"].tap()

        let reviewTitle = app.staticTexts["Review Transaction"]
        XCTAssertTrue(reviewTitle.waitForExistence(timeout: 3))

        // Verify transaction details
        XCTAssertTrue(app.staticTexts["To: 0x742d...0bEb"].exists)
        XCTAssertTrue(app.staticTexts["Amount: 0.1 ETH"].exists)
        XCTAssertTrue(app.staticTexts.matching(identifier: "gas-fee").element.exists)

        // Step 5: Confirm transaction
        app.buttons["Confirm"].tap()

        // Enter PIN for confirmation
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Step 6: Verify success message
        let successMessage = app.staticTexts["Transaction Sent!"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 10))

        app.buttons["Done"].tap()

        // Should return to home screen
        XCTAssertTrue(app.staticTexts["My Wallet"].exists)
    }

    func testSendWithQRCodeScan() {
        // Start send flow
        app.buttons["Send"].tap()

        // Tap QR scan button
        app.buttons["scan-qr"].tap()

        // Assert camera view opens
        XCTAssertTrue(app.otherElements["camera-view"].waitForExistence(timeout: 3))

        // Simulate QR code scan (mocked in tests)
        app.buttons["mock-scan-success"].tap()

        // Verify address is filled
        let addressField = app.textFields["recipient-address"]
        XCTAssertFalse(addressField.value as? String == "" )
    }

    func testSendWithInsufficientBalance() {
        app.buttons["Send"].tap()

        // Enter recipient
        let addressField = app.textFields["recipient-address"]
        addressField.tap()
        addressField.typeText("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")

        // Enter amount greater than balance
        let amountField = app.textFields["amount"]
        amountField.tap()
        amountField.typeText("999999")

        app.buttons["Review"].tap()

        // Assert error message
        let errorAlert = app.alerts["Insufficient Balance"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 3))
        errorAlert.buttons["OK"].tap()
    }

    func testSendWithInvalidAddress() {
        app.buttons["Send"].tap()

        // Enter invalid address
        let addressField = app.textFields["recipient-address"]
        addressField.tap()
        addressField.typeText("invalid-address")

        app.buttons["Review"].tap()

        // Assert error message
        let errorAlert = app.alerts["Invalid Address"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: 3))
    }

    func testSendWithMaxAmount() {
        app.buttons["Send"].tap()

        // Tap "Max" button
        app.buttons["use-max"].tap()

        // Verify amount field is filled with max
        let amountField = app.textFields["amount"]
        XCTAssertFalse((amountField.value as? String)?.isEmpty ?? true)

        // Amount should be balance minus gas
        XCTAssertTrue(app.staticTexts["(including gas fees)"].exists)
    }

    // MARK: - Receive Flow Tests

    func testReceiveFlowDisplay() {
        // Tap Receive button
        app.buttons["Receive"].tap()

        // Assert receive screen elements
        let receiveTitle = app.staticTexts["Receive"]
        XCTAssertTrue(receiveTitle.waitForExistence(timeout: 3))

        XCTAssertTrue(app.images["qr-code"].exists)
        XCTAssertTrue(app.staticTexts["wallet-address"].exists)
        XCTAssertTrue(app.buttons["Copy Address"].exists)
        XCTAssertTrue(app.buttons["Share"].exists)
    }

    func testCopyAddress() {
        app.buttons["Receive"].tap()

        // Tap copy button
        app.buttons["Copy Address"].tap()

        // Assert feedback message
        let copiedMessage = app.staticTexts["Address Copied!"]
        XCTAssertTrue(copiedMessage.waitForExistence(timeout: 3))
    }

    func testShareAddress() {
        app.buttons["Receive"].tap()

        // Tap share button
        app.buttons["Share"].tap()

        // Assert activity view appears (iOS share sheet)
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 3))
    }

    // MARK: - Transaction History Tests

    func testTransactionHistoryDisplay() {
        // Verify transaction list exists and has items
        let transactionTable = app.tables["transaction-history"]
        XCTAssertTrue(transactionTable.exists)

        // Check for transaction cells
        let firstTransaction = transactionTable.cells.element(boundBy: 0)
        XCTAssertTrue(firstTransaction.exists)

        // Verify transaction details are displayed
        XCTAssertTrue(firstTransaction.staticTexts.matching(identifier: "tx-amount").element.exists)
        XCTAssertTrue(firstTransaction.staticTexts.matching(identifier: "tx-date").element.exists)
    }

    func testTransactionDetailView() {
        // Tap on a transaction
        let transactionTable = app.tables["transaction-history"]
        transactionTable.cells.element(boundBy: 0).tap()

        // Assert detail view opens
        let detailTitle = app.staticTexts["Transaction Details"]
        XCTAssertTrue(detailTitle.waitForExistence(timeout: 3))

        // Verify all details are present
        XCTAssertTrue(app.staticTexts["Status"].exists)
        XCTAssertTrue(app.staticTexts["From"].exists)
        XCTAssertTrue(app.staticTexts["To"].exists)
        XCTAssertTrue(app.staticTexts["Amount"].exists)
        XCTAssertTrue(app.staticTexts["Gas Fee"].exists)
        XCTAssertTrue(app.staticTexts["Transaction Hash"].exists)
        XCTAssertTrue(app.buttons["View on Explorer"].exists)
    }

    func testFilterTransactions() {
        // Tap filter button
        app.buttons["filter-transactions"].tap()

        // Select filter options
        app.buttons["filter-sent"].tap()
        app.buttons["Apply"].tap()

        // Verify filtered results
        let transactionTable = app.tables["transaction-history"]
        XCTAssertTrue(transactionTable.cells.count > 0)
    }

    func testRefreshTransactionHistory() {
        // Pull to refresh
        let transactionTable = app.tables["transaction-history"]
        transactionTable.swipeDown()

        // Verify refresh indicator appears
        let refreshIndicator = app.activityIndicators["loading-indicator"]
        XCTAssertTrue(refreshIndicator.waitForExistence(timeout: 3))
    }

    // MARK: - Buy/Ramp Integration Tests

    func testBuyButtonOpensRamp() {
        // Tap Buy button
        app.buttons["Buy"].tap()

        // Assert ramp interface opens
        let rampTitle = app.staticTexts["Buy Crypto"]
        XCTAssertTrue(rampTitle.waitForExistence(timeout: 5))

        // Verify payment methods are displayed
        XCTAssertTrue(app.buttons["Credit Card"].exists)
        XCTAssertTrue(app.buttons["Bank Transfer"].exists)
    }

    func testBuyFlow() {
        app.buttons["Buy"].tap()

        // Select amount
        let amountField = app.textFields["buy-amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 3))
        amountField.tap()
        amountField.typeText("100")

        // Select payment method
        app.buttons["Credit Card"].tap()

        // Continue to payment
        app.buttons["Continue"].tap()

        // Assert payment processor screen (mocked)
        XCTAssertTrue(app.webViews["payment-processor"].waitForExistence(timeout: 5))
    }

    // MARK: - Settings and Security Tests

    func testAccessSettings() {
        // Tap settings icon
        app.buttons["settings"].tap()

        // Assert settings screen
        let settingsTitle = app.staticTexts["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 3))

        XCTAssertTrue(app.cells["Security"].exists)
        XCTAssertTrue(app.cells["Backup Wallet"].exists)
        XCTAssertTrue(app.cells["Network"].exists)
        XCTAssertTrue(app.cells["About"].exists)
    }

    func testChangePIN() {
        app.buttons["settings"].tap()
        app.cells["Security"].tap()
        app.cells["Change PIN"].tap()

        // Enter current PIN
        let currentPinTitle = app.staticTexts["Enter Current PIN"]
        XCTAssertTrue(currentPinTitle.waitForExistence(timeout: 3))

        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Enter new PIN
        for digit in "654321" {
            app.buttons[String(digit)].tap()
        }

        // Confirm new PIN
        for digit in "654321" {
            app.buttons[String(digit)].tap()
        }

        // Assert success
        let successMessage = app.staticTexts["PIN Changed Successfully"]
        XCTAssertTrue(successMessage.waitForExistence(timeout: 3))
    }

    func testBackupWallet() {
        app.buttons["settings"].tap()
        app.cells["Backup Wallet"].tap()

        // Enter PIN to view backup
        for digit in "123456" {
            app.buttons[String(digit)].tap()
        }

        // Assert recovery phrase is displayed
        let recoveryTitle = app.staticTexts["Recovery Phrase"]
        XCTAssertTrue(recoveryTitle.waitForExistence(timeout: 3))

        // Verify 12 words
        for i in 1...12 {
            XCTAssertTrue(app.staticTexts["word-\(i)"].exists)
        }
    }

    // MARK: - Network Switching Tests

    func testSwitchNetwork() {
        app.buttons["settings"].tap()
        app.cells["Network"].tap()

        // Assert network options
        XCTAssertTrue(app.cells["Ethereum Mainnet"].exists)
        XCTAssertTrue(app.cells["Polygon"].exists)
        XCTAssertTrue(app.cells["Sepolia Testnet"].exists)

        // Switch to testnet
        app.cells["Sepolia Testnet"].tap()

        // Verify network changed
        app.buttons["Back"].tap()
        app.buttons["Back"].tap()

        // Check network indicator
        let networkIndicator = app.staticTexts["network-name"]
        XCTAssertEqual(networkIndicator.label, "Sepolia")
    }

    // MARK: - Accessibility Tests

    func testAccessibilityLabels() {
        // Verify important buttons have accessibility labels
        XCTAssertNotNil(app.buttons["Send"].label)
        XCTAssertNotNil(app.buttons["Receive"].label)
        XCTAssertNotNil(app.buttons["Buy"].label)

        // Check accessibility hints
        XCTAssertNotNil(app.buttons["Send"].value)
    }

    // MARK: - Performance Tests

    func testTransactionListScrollPerformance() {
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            let transactionTable = app.tables["transaction-history"]
            transactionTable.swipeUp(velocity: .fast)
        }
    }

    func testSendFlowPerformance() {
        measure {
            app.buttons["Send"].tap()
            _ = app.textFields["recipient-address"].waitForExistence(timeout: 5)
            app.buttons["Back"].tap()
        }
    }
}
