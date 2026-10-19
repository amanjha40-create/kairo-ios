import XCTest

/// OS URL delivery into the real SwiftUI root; the existing UI-test dependency
/// graph uses only in-memory credentials and a network client that rejects I/O.
@MainActor
final class GoogleHandoffLifecycleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTerminatedAppReceivesCanonicalHandoffAndReachesHome() {
        let app = configuredApp()
        app.terminate()
        app.open(handoff)
        assertHome(app)
    }

    func testForegroundAppReceivesCanonicalHandoffAndReachesHome() {
        let app = configuredApp()
        app.launch()
        app.open(handoff)
        assertHome(app)
    }

    func testBackgroundAppReceivesCanonicalHandoffAndReachesHome() {
        let app = configuredApp()
        app.launch()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.open(handoff)
        assertHome(app)
    }

    func testUnrelatedURLCannotAuthenticate() {
        let app = configuredApp()
        app.terminate()
        app.open(URL(string: "https://api.kairoid.com/unrelated?code=synthetic_01234567890123456789012345678901234")!)
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["candidate.tabShell"].exists)
    }

    func testColdFragmentHandoffReachesHome() {
        let app = configuredApp()
        app.terminate()
        app.open(fragmentHandoff)
        assertHome(app)
    }

    func testWarmFragmentHandoffAndCompletedDuplicateKeepHome() {
        let app = configuredApp()
        app.launch()
        app.open(fragmentHandoff)
        assertHome(app)
        app.open(handoff)
        assertHome(app)
        XCTAssertFalse(app.otherElements["auth.google.handoff"].exists)
    }

    func testBackgroundFragmentHandoffReachesHomeAndSurvivesReopen() {
        let app = configuredApp()
        app.launch()
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.open(fragmentHandoff)
        assertHome(app)
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5))
        app.activate()
        assertHome(app)
    }

    private var fragmentHandoff: URL {
        URL(string: handoff.absoluteString + "#synthetic-non-auth-fragment")!
    }

    private var handoff: URL {
        URL(string: "https://api.kairoid.com/auth/google/complete?code=synthetic_01234567890123456789012345678901234")!
    }

    private func configuredApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING"]
        app.launchEnvironment = [
            "KAIRO_BUILD_CONFIGURATION": "Development",
            "KAIRO_APP_ENVIRONMENT": "production",
            "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_AUTH_ONBOARDING_STATUS": "complete"
        ]
        return app
    }

    private func assertHome(_ app: XCUIApplication) {
        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["auth.google.retry"].exists)
    }
}
