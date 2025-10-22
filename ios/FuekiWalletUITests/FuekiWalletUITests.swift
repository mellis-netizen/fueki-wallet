import XCTest

final class FuekiWalletUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    func testAuthenticationViewExists() throws {
        // Test that the authentication view is displayed on launch
        let titleText = app.staticTexts["Fueki Wallet"]
        XCTAssertTrue(titleText.exists, "Title should be visible")

        let subtitleText = app.staticTexts["Secure. Simple. Powerful."]
        XCTAssertTrue(subtitleText.exists, "Subtitle should be visible")

        let authenticateButton = app.buttons["Authenticate"]
        XCTAssertTrue(authenticateButton.exists, "Authenticate button should be visible")
    }
}
