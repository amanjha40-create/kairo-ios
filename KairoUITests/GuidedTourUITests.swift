import XCTest

@MainActor
final class GuidedTourUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEverySpotlightEnclosesItsMeasuredTargetWithoutSafeAreaOffset() {
        let app = XCUIApplication()
        configure(app, account: "device-fix-geometry", reset: true, appearance: "light", accessibilityXXXL: false)
        app.launchEnvironment["KAIRO_UI_TEST_TOUR_GEOMETRY"] = "1"
        app.launch()
        for index in 0..<5 {
            let spotlight = app.staticTexts["candidate.guidedTour.title"]
            XCTAssertTrue(spotlight.waitForExistence(timeout: 10))
            let aligned = NSPredicate { _, _ in
                guard let value = spotlight.value as? String else { return false }
                let frames = value.components(separatedBy: "|")
                guard frames.count == 2 else { return false }
                let target = NSCoder.cgRect(for: frames[0])
                let actual = NSCoder.cgRect(for: frames[1])
                return target.width > 0 && target.height > 0 &&
                    abs(actual.midX - target.midX) <= 3 && abs(actual.midY - target.midY) <= 3 &&
                    abs(actual.width - (target.width + 10)) <= 6 && abs(actual.height - (target.height + 10)) <= 6
            }
            XCTAssertTrue(waitFor(aligned, object: spotlight), "Step \(index + 1): spotlight \(spotlight.frame), measured target \(String(describing: spotlight.value))")
            capture("Device fix geometry - step \(index + 1)")
            if index < 4 { advance(in: app) }
        }
        app.buttons["candidate.guidedTour.done"].tap()
    }

    private func waitFor(_ predicate: NSPredicate, object: Any) -> Bool {
        XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: object)], timeout: 5) == .completed
    }

    func testNewAccountCompletesExactFiveHomeAnchoredStepsAndStaysOnHome() {
        let app = launchTour(account: "wave7-light-sequence", reset: true)

        assertStep("Your Trust Score", progress: "1 of 5", in: app)
        capture("Wave 7 - 1 Trust Score - Light")
        advance(in: app)

        assertStep("Your Trust Passport", progress: "2 of 5", in: app)
        capture("Wave 7 - 2 Passport - Light")
        advance(in: app)

        assertStep("Build your career record", progress: "3 of 5", in: app)
        capture("Wave 7 - 3 Career - Light")
        advance(in: app)

        assertStep("Get important records verified", progress: "4 of 5", in: app)
        capture("Wave 7 - 4 Verify - Light")
        advance(in: app)

        assertStep("Everything else is here", progress: "5 of 5", in: app)
        capture("Wave 7 - 5 More - Light")

        let done = app.buttons["candidate.guidedTour.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        done.tap()
        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].waitForExistence(timeout: 1))
        XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].waitForExistence(timeout: 10))
        capture("Wave 7 - Done remains on Home - Light")
    }

    func testCompletionPersistsAcrossRelaunch() {
        let account = "wave7-completion-reload"
        let app = launchTour(account: account, reset: true)
        for _ in 0..<4 { advance(in: app) }
        app.buttons["candidate.guidedTour.done"].tap()
        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].exists)

        relaunch(app, account: account)
        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].waitForExistence(timeout: 10))
    }

    func testSkipPersistsAcrossRelaunch() {
        let account = "wave7-skip-reload"
        let app = launchTour(account: account, reset: true)
        let skip = app.buttons["candidate.guidedTour.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].exists)

        relaunch(app, account: account)
        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].waitForExistence(timeout: 2))
    }

    func testInterruptedPendingTourRestartsAtStepOne() {
        let account = "wave7-pending-restart"
        let app = launchTour(account: account, reset: true)
        advance(in: app)
        assertStep("Your Trust Passport", progress: "2 of 5", in: app)

        relaunch(app, account: account)
        assertStep("Your Trust Score", progress: "1 of 5", in: app)
    }

    func testSecondAccountReceivesIndependentTour() {
        let first = launchTour(account: "wave7-account-a", reset: true)
        first.buttons["candidate.guidedTour.skip"].tap()
        XCTAssertFalse(first.otherElements["candidate.guidedTour.overlay"].exists)
        first.terminate()

        let second = launchTour(account: "wave7-account-b", reset: true)
        assertStep("Your Trust Score", progress: "1 of 5", in: second)
    }

    func testDarkModeKeepsEveryStepReadableAndAnchored() {
        let app = launchTour(account: "wave7-dark-sequence", reset: true, appearance: "dark")
        let expected = [
            "Your Trust Score",
            "Your Trust Passport",
            "Build your career record",
            "Get important records verified",
            "Everything else is here"
        ]
        for (index, title) in expected.enumerated() {
            assertStep(title, progress: "\(index + 1) of 5", in: app)
            capture("Wave 7 - \(index + 1) \(title) - Dark")
            if index < expected.count - 1 { advance(in: app) }
        }
    }

    func testAccessibilityXXXLAndReduceMotionKeepActionsReachable() {
        let app = launchTour(
            account: "wave7-accessibility",
            reset: true,
            appearance: "dark",
            accessibilityXXXL: true
        )
        let title = app.staticTexts["candidate.guidedTour.title"]
        let body = app.staticTexts["candidate.guidedTour.body"]
        let next = app.buttons["candidate.guidedTour.next"]
        let skip = app.buttons["candidate.guidedTour.skip"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(body.exists)
        XCTAssertGreaterThanOrEqual(next.frame.height, 44)
        XCTAssertGreaterThanOrEqual(skip.frame.height, 44)
        capture("Wave 7 - Trust Score - Dark Accessibility XXXL")

        for _ in 0..<4 { advance(in: app) }
        assertStep("Everything else is here", progress: "5 of 5", in: app)
        let done = app.buttons["candidate.guidedTour.done"]
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        capture("Wave 7 - More - Dark Accessibility XXXL")
    }

    func testOverlayBlocksUnintendedTabInteraction() {
        let app = launchTour(account: "wave7-blocks-tabs", reset: true)
        assertStep("Your Trust Score", progress: "1 of 5", in: app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.95)).tap()
        assertStep("Your Trust Score", progress: "1 of 5", in: app)
    }

    func testUnavailableTargetFailsClosedWithoutBlockingHomeOrCompletingTour() {
        let account = "wave7-target-unavailable"
        let app = XCUIApplication()
        configure(
            app,
            account: account,
            reset: true,
            appearance: "light",
            accessibilityXXXL: false,
            unavailableTarget: "trustScore"
        )
        app.launch()

        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].waitForExistence(timeout: 2))
        let notifications = app.buttons["candidate.home.notifications"]
        XCTAssertTrue(notifications.waitForExistence(timeout: 10))
        XCTAssertTrue(notifications.isHittable)

        app.terminate()
        configure(app, account: account, reset: false, appearance: "light", accessibilityXXXL: false)
        app.launch()
        assertStep("Your Trust Score", progress: "1 of 5", in: app)
    }

    private func launchTour(
        account: String,
        reset: Bool,
        appearance: String = "light",
        accessibilityXXXL: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        configure(
            app,
            account: account,
            reset: reset,
            appearance: appearance,
            accessibilityXXXL: accessibilityXXXL
        )
        app.launch()
        XCTAssertTrue(app.otherElements["candidate.guidedTour.overlay"].waitForExistence(timeout: 10))
        return app
    }

    private func relaunch(_ app: XCUIApplication, account: String) {
        app.terminate()
        configure(app, account: account, reset: false, appearance: "light", accessibilityXXXL: false)
        app.launch()
    }

    private func configure(
        _ app: XCUIApplication,
        account: String,
        reset: Bool,
        appearance: String,
        accessibilityXXXL: Bool,
        unavailableTarget: String? = nil
    ) {
        app.launchArguments = [
            "-KAIRO_UI_TESTING",
            "-ApplePersistenceIgnoreState",
            "YES",
            "-kairo.appearance.preference",
            appearance,
            "-UIAccessibilityReduceMotionEnabled",
            "YES"
        ]
        if accessibilityXXXL {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_GUIDED_TOUR": "pending",
            "KAIRO_UI_TEST_GUIDED_TOUR_ACCOUNT": account,
            "KAIRO_UI_TEST_GUIDED_TOUR_RESET": reset ? "1" : "0"
        ]
        if let unavailableTarget {
            app.launchEnvironment["KAIRO_UI_TEST_GUIDED_TOUR_UNAVAILABLE_TARGET"] = unavailableTarget
        }
    }

    private func assertStep(_ title: String, progress: String, in app: XCUIApplication) {
        let titleElement = app.staticTexts["candidate.guidedTour.title"]
        XCTAssertTrue(titleElement.waitForExistence(timeout: 10))
        XCTAssertEqual(titleElement.label, title)
        let progressElement = app.staticTexts["candidate.guidedTour.progress"]
        XCTAssertTrue(progressElement.exists)
        XCTAssertTrue(progressElement.label.localizedCaseInsensitiveContains(progress))
        XCTAssertTrue(app.staticTexts["candidate.guidedTour.body"].exists)
        XCTAssertTrue(app.buttons["candidate.guidedTour.skip"].exists)
    }

    private func advance(in app: XCUIApplication) {
        let next = app.buttons["candidate.guidedTour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
