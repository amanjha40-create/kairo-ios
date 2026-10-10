import XCTest

@MainActor
final class SessionRecoveryQAUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testTransientRefreshPreservesSyntheticSessionAndRetryRecovers() {
        let app = launch()
        app.buttons["sessionQA.fail"].tap()
        XCTAssertTrue(app.buttons["sessionQA.retry"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sessionQA.credentials"].label, "Synthetic credentials present")
        XCTAssertTrue(app.staticTexts["sessionQA.signedIn"].exists)
        XCTAssertFalse(app.buttons["onboarding.existingAccount"].exists)
        app.buttons["sessionQA.retry"].tap()
        XCTAssertTrue(app.staticTexts["Authenticated fixture data loaded"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sessionQA.credentials"].label, "Synthetic credentials present")
        XCTAssertFalse(app.buttons["sessionQA.retry"].exists)
    }

    func testConfirmedRejectionClearsSyntheticSessionAndShowsCanonicalLogin() {
        let app = launch()
        app.buttons["sessionQA.reject"].tap()
        let login = app.buttons["onboarding.existingAccount"]
        XCTAssertTrue(login.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["sessionQA.credentials"].label, "Synthetic credentials absent")
        XCTAssertFalse(app.staticTexts["sessionQA.signedIn"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        login.tap()
        XCTAssertTrue(app.textFields["onboarding.login.email"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["candidate.tabShell"].exists)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = ["KAIRO_UI_TEST_SESSION_RECOVERY": "1", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_DEMO_MODE": "false", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Authenticated fixture data loaded"].waitForExistence(timeout: 10))
        return app
    }
}
