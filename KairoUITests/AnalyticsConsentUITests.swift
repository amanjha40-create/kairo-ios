import XCTest

@MainActor
final class AnalyticsConsentUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOptionalPromptHasEqualActionsAndRefusalDoesNotRepeatOrBlockFeatures() {
        let app = application(namespace: "kairoid.analytics.consent.ui-test.\(UUID().uuidString)")
        app.launch()

        let deny = app.buttons["analytics.consent.deny"]
        let allow = app.buttons["analytics.consent.allow"]
        XCTAssertTrue(deny.waitForExistence(timeout: 10))
        XCTAssertTrue(allow.exists)
        XCTAssertEqual(deny.frame.height, allow.frame.height, accuracy: 1)
        XCTAssertEqual(deny.frame.width, allow.frame.width, accuracy: 1)
        deny.tap()
        XCTAssertTrue(app.scrollViews["candidate.home.screen"].waitForExistence(timeout: 10))

        app.terminate()
        app.launch()
        XCTAssertTrue(app.scrollViews["candidate.home.screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["analytics.consent.deny"].exists)

        app.buttons["More"].firstMatch.tap()
        app.buttons["candidate.more.settings"].tap()
        let toggle = app.switches["candidate.more.privacy.usageAnalytics"]
        reveal(toggle, in: app)
        XCTAssertTrue(toggle.isHittable)
    }

    func testAcceptanceThenWithdrawalRemainsDisabledAfterRelaunch() {
        let app = application(namespace: "kairoid.analytics.consent.ui-test.\(UUID().uuidString)")
        app.launch()

        let allow = app.buttons["analytics.consent.allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 10))
        allow.tap()
        XCTAssertTrue(app.scrollViews["candidate.home.screen"].waitForExistence(timeout: 10))

        app.buttons["More"].firstMatch.tap()
        app.buttons["candidate.more.settings"].tap()
        let toggle = app.switches["candidate.more.privacy.usageAnalytics"]
        reveal(toggle, in: app)
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        let disabled = NSPredicate(format: "value == %@", "0")
        expectation(for: disabled, evaluatedWith: toggle)
        waitForExpectations(timeout: 5)

        app.terminate()
        app.launch()
        XCTAssertTrue(app.scrollViews["candidate.home.screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["analytics.consent.allow"].exists)
        app.buttons["More"].firstMatch.tap()
        app.buttons["candidate.more.settings"].tap()
        reveal(toggle, in: app)
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.value as? String, "0")
    }

    private func application(namespace: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = [
            "KAIRO_UI_TEST_ANALYTICS_CONSENT_PROMPT": "1",
            "KAIRO_UI_TEST_ANALYTICS_CONSENT_NAMESPACE": namespace,
            "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_DEMO_MODE": "false"
        ]
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 {
            if element.exists,
               element.frame.minY >= app.frame.minY,
               element.frame.maxY <= app.frame.maxY - 8 {
                return
            }
            app.swipeUp()
        }
    }
}
