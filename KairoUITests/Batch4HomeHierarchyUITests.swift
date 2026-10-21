import XCTest

@MainActor
final class Batch4HomeHierarchyUITests: XCTestCase {
    private var initialVoiceOver: Bool?
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if #available(iOS 27.0, *), let enabled = initialVoiceOver {
            if enabled { try XCUIDevice.shared.voiceOverService.enable() }
            else { try XCUIDevice.shared.voiceOverService.disable() }
        }
        initialVoiceOver = nil
    }

    func testAttentionBeforeProgressAndSecondaryDestinations() {
        let app = launch("attention")
        let passport = app.buttons["candidate.home.viewTrustPassport"]
        reveal(passport, app)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.home.viewTrustPassport").count, 1)
        XCTAssertGreaterThanOrEqual(passport.frame.height, 44)
        capture(app, "Home primary trust and attention")
        let attention = app.staticTexts["Needs Your Attention"]
        reveal(attention, app)
        XCTAssertTrue(app.buttons["candidate.home.verificationRequest.action"].firstMatch.exists)
        reveal(app.staticTexts["In progress"], app)
        reveal(app.staticTexts["Build Your Trust"], app)
        capture(app, "Home grouped progress")
        reveal(app.staticTexts["Documents & identity"], app)
        reveal(app.buttons["candidate.home.documents"], app)
        capture(app, "Home secondary identity and documents")
        reveal(app.staticTexts["Recent trust changes"], app)
        reveal(app.staticTexts["Recent Passport views"], app)
        capture(app, "Home recent history")
        XCTAssertEqual(app.tabBars.buttons.count, 4)
    }

    func testEmptyCandidateKeepsHonestScoreAndAllDestinations() {
        let app = launch("empty")
        XCTAssertTrue(app.staticTexts["Unavailable"].exists)
        reveal(app.staticTexts["No action needed right now"], app)
        XCTAssertFalse(app.buttons["candidate.home.verificationRequest.action"].exists)
        reveal(app.staticTexts["0% profile complete"], app)
        reveal(app.buttons["candidate.home.documents"], app)
        capture(app, "Empty Home compact but complete")
    }

    func testPartialProfileRetainsRecommendationAndTaskMetadata() {
        let app = launch("partial")
        reveal(app.staticTexts["45% profile complete"], app)
        reveal(app.buttons["candidate.home.continueProfile"], app)
        XCTAssertTrue(app.staticTexts["Add your employment history"].exists)
        capture(app, "Partial profile next action")
    }

    func testCompleteAndNoTaskStatesDoNotFabricateAttention() {
        for scenario in ["complete", "noTasks"] {
            let app = launch(scenario)
            reveal(app.staticTexts["No action needed right now"], app)
            XCTAssertFalse(app.buttons["candidate.home.verificationRequest.action"].exists)
            reveal(app.staticTexts["100% profile complete"], app)
            capture(app, "Home \(scenario)")
        }
    }

    func testInProgressRemainsSeparateFromAttention() {
        let app = launch("inProgress")
        reveal(app.staticTexts["No action needed right now"], app)
        reveal(app.staticTexts["In progress"], app)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.home.verificationRequest.action").count, 1)
        capture(app, "Authoritative in-progress state")
    }

    func testUnavailableSourcesDoNotInventNoActionOrScore() {
        let app = launch("unavailable")
        XCTAssertTrue(app.staticTexts["Unavailable"].exists)
        reveal(app.staticTexts["Verification status unavailable"], app)
        XCTAssertFalse(app.staticTexts["No action needed right now"].exists)
        XCTAssertFalse(app.buttons["candidate.home.verificationRequest.action"].exists)
        capture(app, "Unavailable sources remain explicit")
    }

    func testLoadingKeepsHeaderWithoutStaleActions() {
        let app = launch("loading")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Preparing your Home overview")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["candidate.home.notifications"].isHittable)
        XCTAssertFalse(app.buttons["candidate.home.viewTrustPassport"].exists)
        capture(app, "Home loading")
    }

    func testErrorAndOfflineRetryWithoutSessionChanges() {
        for scenario in ["error", "offline"] {
            let app = launch(scenario)
            XCTAssertTrue(app.staticTexts[scenario == "offline" ? "You're offline" : "Home overview unavailable"].exists)
            XCTAssertFalse(app.buttons["candidate.home.viewTrustPassport"].exists)
            capture(app, "Home \(scenario)")
            app.buttons["Try Again"].tap()
            XCTAssertTrue(app.buttons["candidate.home.viewTrustPassport"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        }
    }

    func testPassportDestinationPreservesUnavailableState() {
        let app = launch("onboarded", passport: "error")
        let button = app.buttons["candidate.home.viewTrustPassport"]
        reveal(button, app); button.tap()
        XCTAssertTrue(app.tabBars.buttons["Passport"].isSelected)
        XCTAssertTrue(app.staticTexts["Trust Passport unavailable"].waitForExistence(timeout: 5))
        capture(app, "Existing Passport error route")
    }

    func testLightDarkAndBackgroundRestore() {
        for dark in [false, true] {
            let app = launch("onboarded", dark: dark)
            let bell = app.buttons["candidate.home.notifications"]
            XCTAssertTrue(bell.isHittable)
            XCTAssertGreaterThanOrEqual(bell.frame.width, 44)
            capture(app, "Home \(dark ? "dark" : "light")")
            XCUIDevice.shared.press(.home); app.activate()
            XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["candidate.home.viewTrustPassport"].exists)
        }
    }

    func testXXXLReducedMotionLightAndDarkKeepActionsReachable() {
        for dark in [false, true] {
            let app = launch("attention", dark: dark, large: true, reduced: true)
            let passport = app.buttons["candidate.home.viewTrustPassport"]
            reveal(passport, app); assertTarget(passport, app)
            capture(app, "Home XXXL trust \(dark ? "dark" : "light")")
            reveal(app.buttons["candidate.home.continueProfile"], app)
            let documents = app.buttons["candidate.home.documents"]
            reveal(documents, app); assertTarget(documents, app)
            capture(app, "Home XXXL secondary \(dark ? "dark" : "light")")
        }
    }

    func testNotificationAndPassportNavigationRemainCanonical() {
        let app = launch("onboarded")
        app.buttons["candidate.home.notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let passport = app.buttons["candidate.home.viewTrustPassport"]
        reveal(passport, app); passport.tap()
        XCTAssertTrue(app.tabBars.buttons["Passport"].isSelected)
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
    }

    func testPhysicalVoiceOverReadsTrustBeforeAttentionAndProgress() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical VoiceOver speech gate")
        #else
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires iOS 27 speech API") }
        let service = XCUIDevice.shared.voiceOverService
        initialVoiceOver = service.isEnabled
        try service.disable()
        _ = launch("attention")
        try service.enable()
        var spoken = (try service.currentSpeech()).utterance
        for _ in 0..<85 {
            spoken += " " + (try service.moveForward()).utterance
            if spoken.contains("Build Your Trust") { break }
        }
        guard let trust = spoken.range(of: "Trust Score"),
              let passport = spoken.range(of: "View Trust Passport"),
              let attention = spoken.range(of: "Needs Your Attention"),
              let progress = spoken.range(of: "Build Your Trust") else { return XCTFail("Synthetic reading-order elements missing") }
        XCTAssertLessThan(trust.lowerBound, passport.lowerBound)
        XCTAssertLessThan(passport.lowerBound, attention.lowerBound)
        XCTAssertLessThan(attention.lowerBound, progress.lowerBound)
        // Synthetic speech only, deliberately not printed or attached.
        #endif
    }

    private func launch(_ scenario: String, dark: Bool = false, large: Bool = false,
                        reduced: Bool = false, passport: String = "populated") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES",
            "-kairo.appearance.preference", dark ? "dark" : "light",
            "-UIAccessibilityReduceMotionEnabled", reduced ? "YES" : "NO"]
        #if KAIRO_LOCAL_BATCH1_QA
        app.launchArguments += ["-KAIRO_LOCAL_BATCH1_QA"]
        #endif
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "0",
            "KAIRO_UI_TEST_BATCH4_HOME": scenario, "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_VERIFY_STATE": "populated",
            "KAIRO_UI_TEST_PASSPORT_STATE": passport, "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated", "KAIRO_LOCAL_BATCH1_MODE": "batch4Home",
            "KAIRO_LOCAL_BATCH1_APPEARANCE": dark ? "dark" : "light"]
        app.launch()
        XCTAssertTrue(app.staticTexts["candidate.home.greeting"].waitForExistence(timeout: 10))
        return app
    }
    private func assertTarget(_ target: XCUIElement, _ app: XCUIApplication) {
        XCTAssertGreaterThanOrEqual(target.frame.height, 44)
        XCTAssertGreaterThanOrEqual(target.frame.minX, 0)
        XCTAssertLessThanOrEqual(target.frame.maxX, app.frame.maxX)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<35 {
            if element.exists && element.isHittable && element.frame.midY > 100 && element.frame.midY < app.frame.maxY - 100 { return }
            let above = element.exists && element.frame.midY < 100
            app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: above ? 0.35 : 0.72)).press(forDuration: 0.03,
                thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: above ? 0.72 : 0.35)))
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
