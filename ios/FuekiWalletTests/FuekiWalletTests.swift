import XCTest
@testable import FuekiWallet

final class FuekiWalletTests: XCTestCase {

    var appState: AppState!

    override func setUpWithError() throws {
        super.setUp()
        appState = AppState()
    }

    override func tearDownWithError() throws {
        appState = nil
        super.tearDown()
    }

    func testAppStateInitialization() throws {
        XCTAssertNotNil(appState, "AppState should be initialized")
        XCTAssertFalse(appState.isAuthenticated, "User should not be authenticated initially")
        XCTAssertNil(appState.currentUser, "Current user should be nil initially")
        XCTAssertTrue(appState.wallets.isEmpty, "Wallets array should be empty initially")
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
            _ = AppState()
        }
    }
}
