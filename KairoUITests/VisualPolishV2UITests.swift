import XCTest

@MainActor
final class VisualPolishV2UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFiveTabsAndFormLight() { inspect(appearance: "light") }
    func testFiveTabsAndFormDark() { inspect(appearance: "dark") }
    func testFiveTabsXXXLReduceMotion() { inspect(appearance: "dark", accessible: true) }

    @available(iOS 27.0, *)
    func testPhysicalVoiceOverHome() throws {
        let service = XCUIDevice.shared.voiceOverService
        let initiallyEnabled = service.isEnabled
        defer {
            if initiallyEnabled { try? service.enable() } else { try? service.disable() }
        }
        try service.disable()
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-KAIRO_LOCAL_BATCH1_QA", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = ["KAIRO_LOCAL_BATCH1_APPEARANCE": "dark", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        app.launch()
        XCTAssertTrue(app.staticTexts["batch1.qa.banner"].waitForExistence(timeout: 15), "Synthetic physical gate must be active")
        try service.enable()
        var speech = try service.currentSpeech().utterance
        for _ in 0..<35 {
            speech += " " + (try service.moveForward()).utterance
            if speech.localizedCaseInsensitiveContains("Trust Score") && speech.localizedCaseInsensitiveContains("View Trust Passport") { break }
        }
        XCTAssertTrue(speech.localizedCaseInsensitiveContains("Trust Score"))
        XCTAssertTrue(speech.localizedCaseInsensitiveContains("View Trust Passport"))
        capture(app, "Physical-VoiceOver-synthetic-Home")
        try service.disable()
        app.terminate()
    }

    private func inspect(appearance: String, accessible: Bool = false) {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", appearance]
#if KAIRO_LOCAL_BATCH1_QA
        app.launchArguments += ["-KAIRO_LOCAL_BATCH1_QA"]
#endif
        if accessible {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                "-UIAccessibilityReduceMotionEnabled", "YES"]
        }
        app.launchEnvironment = ["KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_DEMO_MODE": "false",
            "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_LOCAL_BATCH1_APPEARANCE": appearance,
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_VERIFY_STATE": "populated",
            "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 15))
        for tab in ["Home", "Career", "Verify", "Passport", "More"] {
            if tab == "Verify" {
                app.openCareerVerification()
                XCTAssertTrue(app.staticTexts["candidate.verify.pendingRequests"].waitForExistence(timeout: 10))
            } else {
                app.tabBars.buttons[tab].tap()
                XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
            }
            XCTAssertEqual(app.state, .runningForeground)
            capture(app, "\(tab)-\(appearance)\(accessible ? "-XXXL" : "")")
        }
        app.tabBars.buttons["Passport"].tap()
        let share = app.buttons["candidate.passport.share"]
        app.revealContent(share); XCTAssertTrue(share.isHittable); share.tap()
        let create = app.buttons["candidate.passport.share.createEntry"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); app.revealContent(create); create.tap()
        XCTAssertTrue(app.textFields["candidate.passport.share.label"].waitForExistence(timeout: 10))
        capture(app, "Form-\(appearance)\(accessible ? "-XXXL" : "")")
        app.terminate() // No share, write or provider action.
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
