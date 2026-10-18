import XCTest

@MainActor final class KairoLogoTransparencyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHomeLightTransparentBrandAndUnchangedHierarchy() { checkHome(dark: false, large: false) }
    func testHomeDarkTransparentBrandAndUnchangedHierarchy() { checkHome(dark: true, large: false) }
    func testHomeLightXXXLKeepsHeaderAndNotificationSeparate() { checkHome(dark: false, large: true) }
    func testHomeDarkXXXLKeepsHeaderAndNotificationSeparate() { checkHome(dark: true, large: true) }

    func testWelcomeLightAndLoginUseFullColorMaster() { checkWelcomeAndLogin(dark: false) }
    func testWelcomeFixedLightArtworkAndLoginDarkUseAppropriateMasters() { checkWelcomeAndLogin(dark: true) }

    private func checkWelcomeAndLogin(dark: Bool) {
        let app = launch(dark: dark, large: false, onboarding: true)
        let login = app.buttons["onboarding.existingAccount"]
        XCTAssertTrue(login.waitForExistence(timeout: 10))
        // Welcome and toolbar marks are decorative and intentionally hidden
        // from accessibility. Unit pixel/source guards prove asset selection;
        // retained screenshots prove the actual rendering, not AX image names.
        XCTAssertTrue(app.staticTexts["onboarding.welcome.support"].exists)
        capture(app, name: "Welcome \(dark ? "dark" : "light") fixed-light brand canvas")
        login.tap()
        XCTAssertTrue(app.buttons["onboarding.login.submit"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.back"].isHittable)
        capture(app, name: "Login \(dark ? "dark white" : "light full-color") master")
        app.buttons["onboarding.back"].tap()
        XCTAssertTrue(login.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["onboarding.welcome.support"].exists)
    }

    func testDecorativeMasterDoesNotAddVoiceOverElements() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical VoiceOver speech gate.")
        #else
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires physical speech API.") }
        let voiceOver = XCUIDevice.shared.voiceOverService
        let initial = voiceOver.isEnabled
        defer { if initial { try? voiceOver.enable() } else { try? voiceOver.disable() } }
        try voiceOver.disable()
        let app = launch(dark: true, large: false)
        XCTAssertTrue(app.staticTexts["candidate.home.greeting"].waitForExistence(timeout: 10))
        try voiceOver.enable()
        var speech = (try voiceOver.currentSpeech()).utterance
        for _ in 0..<30 {
            speech += " " + (try voiceOver.moveForward()).utterance
            if speech.contains("View Trust Passport") { break }
        }
        XCTAssertTrue(speech.localizedCaseInsensitiveContains("Good morning"))
        XCTAssertTrue(speech.contains("Notifications"))
        XCTAssertFalse(speech.contains("KairoIDMaster"))
        XCTAssertFalse(speech.contains("master.png"))
        XCTAssertFalse(speech.contains("master-white.png"))
        XCTAssertFalse(speech.localizedCaseInsensitiveContains("trademark"))
        // Synthetic speech is asserted only, never logged or attached.
        #endif
    }

    private func checkHome(dark: Bool, large: Bool) {
        let app = launch(dark: dark, large: large)
        let greeting = app.staticTexts["candidate.home.greeting"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertFalse(app.tabBars.buttons["Verify"].exists)
        // XCTest snapshots include decorative images; spoken focus is checked
        // separately with the physical VoiceOver service above.
        XCTAssertTrue(app.images[dark ? "KairoIDMasterWhite" : "KairoIDMaster"].exists)
        XCTAssertFalse(app.images[dark ? "KairoIDMaster" : "KairoIDMasterWhite"].exists)
        let bell = app.buttons["candidate.home.notifications"]
        XCTAssertTrue(bell.exists)
        XCTAssertLessThanOrEqual(greeting.frame.maxX, bell.frame.minX)
        XCTAssertGreaterThan(greeting.frame.minY, app.frame.minY)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Transparent master Home \(dark ? "dark" : "light") \(large ? "XXXL" : "normal")"
        shot.lifetime = .keepAlways
        add(shot)
        let passport = app.buttons["candidate.home.viewTrustPassport"]
        for _ in 0..<15 {
            if passport.exists && passport.isHittable { break }
            app.swipeUp()
        }
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.home.viewTrustPassport").count, 1)
        XCTAssertTrue(passport.isHittable)
        passport.tap()
        XCTAssertTrue(app.tabBars.buttons["Passport"].isSelected)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func launch(dark: Bool, large: Bool, onboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES",
            "-kairo.appearance.preference", dark ? "dark" : "light",
            "-UIPreferredContentSizeCategoryName", large ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated"]
        if onboarding {
            app.launchEnvironment["KAIRO_UI_TEST_ROUTE"] = "onboarding"
            app.launchEnvironment["KAIRO_UI_TEST_ONBOARDING_STEP"] = "welcome"
        }
        app.launch()
        return app
    }
}
