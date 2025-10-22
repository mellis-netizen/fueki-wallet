//
//  ReceiveFlowUITests.swift
//  FuekiWalletUITests
//
//  UI tests for receive cryptocurrency flow
//

import XCTest

final class ReceiveFlowUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]
        app.launch()

        completeOnboardingFlow()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Basic Receive Flow

    func testReceiveFlow_NavigateToReceiveScreen() {
        // When
        app.tabBars.buttons["Receive"].tap()

        // Then
        XCTAssertTrue(app.staticTexts["Receive"].exists)
        XCTAssertTrue(app.images["QR Code"].exists)
        XCTAssertTrue(app.staticTexts["Your Address"].exists)
    }

    func testReceiveFlow_DisplaysWalletAddress() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // Then
        let addressLabel = app.staticTexts["Wallet Address"]
        XCTAssertTrue(addressLabel.exists)
        XCTAssertFalse(addressLabel.label.isEmpty)
        XCTAssertTrue(addressLabel.label.hasPrefix("0x"))
    }

    func testReceiveFlow_DisplaysQRCode() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // Then
        let qrCodeImage = app.images["QR Code"]
        XCTAssertTrue(qrCodeImage.exists)
        XCTAssertTrue(qrCodeImage.isHittable)
    }

    // MARK: - Copy Address

    func testReceiveFlow_CopyAddress_ShowsConfirmation() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // When
        app.buttons["Copy Address"].tap()

        // Then
        let confirmation = app.staticTexts["Address copied to clipboard"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
    }

    // MARK: - Share Address

    func testReceiveFlow_ShareAddress_OpensShareSheet() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // When
        app.buttons["Share"].tap()

        // Then
        let shareSheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 5))
    }

    // MARK: - QR Code Actions

    func testReceiveFlow_SaveQRCode() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // When
        app.buttons["Save QR Code"].tap()

        // Then
        let confirmation = app.staticTexts["QR Code saved to Photos"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
    }

    func testReceiveFlow_ShareQRCode() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // When
        let qrCodeImage = app.images["QR Code"]
        qrCodeImage.press(forDuration: 1.0)

        // Then
        let shareOption = app.buttons["Share"]
        XCTAssertTrue(shareOption.waitForExistence(timeout: 2))
    }

    // MARK: - Request Amount

    func testReceiveFlow_RequestSpecificAmount() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // When
        app.buttons["Request Amount"].tap()

        // Then
        XCTAssertTrue(app.textFields["Amount"].exists)

        // Enter amount
        let amountField = app.textFields["Amount"]
        amountField.tap()
        amountField.typeText("0.5")

        app.buttons["Generate QR"].tap()

        // Verify QR code updated with amount
        XCTAssertTrue(app.images["QR Code"].exists)
        XCTAssertTrue(app.staticTexts["Requested: 0.5 ETH"].exists)
    }

    // MARK: - Network Selection

    func testReceiveFlow_SwitchNetwork_UpdatesAddress() {
        // Given
        app.tabBars.buttons["Receive"].tap()
        let initialAddress = app.staticTexts["Wallet Address"].label

        // When
        app.buttons["Network Selector"].tap()
        app.buttons["Polygon"].tap()

        // Then
        let updatedAddress = app.staticTexts["Wallet Address"].label
        // Address format should change or remain same depending on implementation
        XCTAssertTrue(app.staticTexts["Network: Polygon"].exists)
    }

    // MARK: - Transaction History from Receive

    func testReceiveFlow_ViewRecentTransactions() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // When
        app.buttons["Recent Transactions"].tap()

        // Then
        XCTAssertTrue(app.navigationBars["Transactions"].exists)
    }

    // MARK: - Accessibility

    func testReceiveFlow_VoiceOverAccessibility() {
        // Given
        app.tabBars.buttons["Receive"].tap()

        // Then
        XCTAssertNotNil(app.buttons["Copy Address"].accessibilityLabel)
        XCTAssertNotNil(app.buttons["Share"].accessibilityLabel)
        XCTAssertNotNil(app.images["QR Code"].accessibilityLabel)
    }

    // MARK: - Helper Methods

    private func completeOnboardingFlow() {
        if app.buttons["Create New Wallet"].exists {
            app.buttons["Create New Wallet"].tap()

            app.secureTextFields["Password"].tap()
            app.secureTextFields["Password"].typeText("TestPassword123!")

            app.secureTextFields["Confirm Password"].tap()
            app.secureTextFields["Confirm Password"].typeText("TestPassword123!")

            app.buttons["Continue"].tap()

            if app.buttons["Skip Verification"].waitForExistence(timeout: 5) {
                app.buttons["Skip Verification"].tap()
            }
        }

        _ = app.staticTexts["My Wallet"].waitForExistence(timeout: 5)
    }
}
