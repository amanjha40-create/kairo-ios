import XCTest

@MainActor final class AndroidV11ParityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFourTabsHomeSnapshotAttentionAndCareerVerification() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertFalse(app.tabBars.buttons["Verify"].exists)
        let passport = app.buttons["candidate.home.viewTrustPassport"]
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.home.viewTrustPassport").count, 1)
        let attention = app.staticTexts["Needs Your Attention"]
        reveal(attention, app)
        XCTAssertLessThan(passport.frame.minY, attention.frame.minY)
        let integration = app.buttons["candidate.home.digilocker"]
        reveal(integration, app)
        XCTAssertLessThan(attention.frame.minY, integration.frame.minY)
        capture(app, "V1.1 Home hierarchy light")
        app.openCareerVerification()
        XCTAssertTrue(app.staticTexts["candidate.screen.verify"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Career"].isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["career.verification.activity"].waitForExistence(timeout: 10))
    }

    func testPassportBrandOwnerScoreShareAndFactualSignalsLight() {
        let app = launch()
        app.tabBars.buttons["Passport"].tap()
        let hero = app.otherElements["passport.integratedHero"]
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.passport.share").count, 1)
        XCTAssertTrue(app.staticTexts["Aarav Mehta"].exists)
        capture(app, "V1.1 Passport primary full-color mark light")
        let signals = app.staticTexts["Trust Signals"]
        reveal(signals, app)
        XCTAssertLessThan(share.frame.minY, signals.frame.minY)
        reveal(app.staticTexts["Account contact"], app)
        XCTAssertTrue(app.staticTexts["Account contact"].exists)
        reveal(app.staticTexts["1 certification"], app)
        XCTAssertTrue(app.staticTexts["1 certification"].exists)
        XCTAssertFalse(app.staticTexts["Optional · 1 candidate-provided"].exists)
        XCTAssertFalse(app.staticTexts["Trust Score V2"].exists)
        capture(app, "V1.1 factual Trust Signals")
    }

    func testDarkXXXLReducedMotionKeepsUpdatedControlsReachable() {
        let app = launch(dark: true, large: true)
        let passport = app.buttons["candidate.home.viewTrustPassport"]
        reveal(passport, app); XCTAssertGreaterThanOrEqual(passport.frame.height, 44); passport.tap()
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app)
        XCTAssertGreaterThanOrEqual(share.frame.height, 44)
        XCTAssertGreaterThanOrEqual(share.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(share.frame.maxX, app.frame.maxX)
        capture(app, "V1.1 Passport dark XXXL reduced motion")
        app.tabBars.buttons["Career"].tap()
        reveal(app.buttons["career.verification.activity"], app)
        XCTAssertTrue(app.buttons["career.verification.activity"].isHittable)
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.staticTexts["candidate.screen.more"].waitForExistence(timeout: 10))
        capture(app, "V1.1 More dark XXXL")
    }

    func testSyntheticInvitationReviewHasNoImplicitAcceptance() {
        let app = launch(extra: ["KAIRO_UI_TEST_TRUST_INVITATION": "1"])
        XCTAssertTrue(app.staticTexts["Synthetic organization"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Pending"].exists)
        XCTAssertFalse(app.staticTexts["Accepted"].exists)
        app.buttons["guidance.invitation"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "does not create verification requests")).firstMatch.exists)
        capture(app, "V1.1 synthetic organization invitation")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
    }

    func testQuickProfileInvalidFieldFocusSummaryAndInputPreservation() {
        let app = launch(extra: ["KAIRO_UI_TEST_ROUTE": "onboarding", "KAIRO_UI_TEST_ONBOARDING_STEP": "chooseStart", "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE": "basicProfile", "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL": "0"])
        let manual = app.buttons["onboarding.chooseStart.manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 10)); reveal(manual, app); manual.tap()
        app.buttons["onboarding.chooseStart.continue"].tap()
        let button = app.buttons["onboarding.manualProfile.basic.continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 10)); reveal(button, app); button.tap()
        let name = app.textFields["onboarding.manualProfile.fullName"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(name.isHittable)
        name.typeText("Synthetic Candidate")
        // Submit through the focused input rather than AX-scrolling the system
        // keyboard's Done key, whose reported frame can be stale after focus.
        name.typeText("\n")
        reveal(button, app); button.tap()
        XCTAssertEqual(name.value as? String, "Synthetic Candidate")
        XCTAssertTrue(app.textFields["onboarding.manualProfile.headline"].isHittable)
        capture(app, "V1.1 Quick Profile first invalid field synthetic")
    }

    func testPhysicalVoiceOverHasFourTabsAndSinglePassportAction() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical VoiceOver speech gate.")
        #else
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires physical speech API.") }
        let voiceOver = XCUIDevice.shared.voiceOverService
        let initial = voiceOver.isEnabled
        defer { if initial { try? voiceOver.enable() } else { try? voiceOver.disable() } }
        try voiceOver.disable()
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        try voiceOver.enable()
        var spoken = (try voiceOver.currentSpeech()).utterance
        for _ in 0..<75 {
            spoken += " " + (try voiceOver.moveForward()).utterance
            if spoken.contains("View Trust Passport") && spoken.contains("Needs Your Attention") && spoken.contains("More") { break }
        }
        XCTAssertTrue(spoken.contains("View Trust Passport"))
        XCTAssertTrue(spoken.contains("Needs Your Attention"))
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        // Synthetic speech is asserted but never logged or attached.
        #endif
    }

    private func launch(dark: Bool = false, large: Bool = false, extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", dark ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-UIAccessibilityReduceMotionEnabled", "YES"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated"].merging(extra) { _, value in value }
        app.launch(); return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<25 {
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.maxY - 90
            if element.exists && element.isHittable && element.frame.minY > 80 && element.frame.maxY < bottom { return }
            let above = element.exists && element.frame.minY < 80
            if above { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
