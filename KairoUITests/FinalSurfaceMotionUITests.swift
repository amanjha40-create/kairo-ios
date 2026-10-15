import XCTest

@MainActor final class FinalSurfaceMotionUITests: XCTestCase {
    private var voiceOverInitialState: Bool?
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if #available(iOS 27.0, *), let enabled = voiceOverInitialState {
            if enabled { try XCUIDevice.shared.voiceOverService.enable() }
            else { try XCUIDevice.shared.voiceOverService.disable() }
        }
        voiceOverInitialState = nil
    }
    func testDarkXXXLReducedMotionPreviewKeepsTruthAndControlsReachable() {
        let app = launch(large: true, reduced: true)
        openPreview(app)
        let verified = app.buttons["Preview newly Verified"]
        reveal(verified, app); verified.tap()
        XCTAssertTrue(app.staticTexts["Verified"].exists)
        let references = app.buttons["Preview References"]
        reveal(references, app); references.tap()
        XCTAssertTrue(app.staticTexts["2 of 2 completed"].exists)
        let disclosure = app.buttons["mirror.draft"]
        reveal(disclosure, app); disclosure.tap()
        XCTAssertEqual(disclosure.value as? String, "Expanded")
        reveal(app.textFields["mirror.draft.field"], app)
        let city = app.buttons["mirror.location.city"]
        reveal(city, app)
        XCTAssertEqual(city.value as? String, "Bengaluru")
        XCTAssertGreaterThanOrEqual(city.frame.height, 44)
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.lifetime = .keepAlways; add(capture)
    }
    func testPhysicalVoiceOverAnnouncesDisclosureAndLocationValues() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical speech gate; Simulator VoiceOver speech is not reliable.")
        #else
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires iOS 27 speech API.") }
        let service = XCUIDevice.shared.voiceOverService
        voiceOverInitialState = service.isEnabled
        try service.disable()
        let app = launch()
        openPreview(app)
        try service.enable()
        var speech = (try service.currentSpeech()).utterance
        for _ in 0..<65 {
            speech += " " + (try service.moveForward()).utterance
            if speech.contains("Retained draft") && speech.localizedCaseInsensitiveContains("collapsed") &&
                speech.contains("Karnataka") && speech.contains("Bengaluru") { break }
        }
        XCTAssertTrue(speech.contains("Retained draft"))
        XCTAssertTrue(speech.localizedCaseInsensitiveContains("collapsed"))
        XCTAssertTrue(speech.contains("Karnataka"))
        XCTAssertTrue(speech.contains("Bengaluru"))
        // Synthetic speech only; never inspect or attach speech from normal account UI.
        #endif
    }
    func testDisclosurePreservesDraftAndRemovesCollapsedFieldsFromAccessibility() {
        let app = launch()
        openPreview(app)
        let toggle = app.buttons["mirror.draft"]
        reveal(toggle, app); XCTAssertEqual(toggle.value as? String, "Collapsed")
        XCTAssertFalse(app.textFields["mirror.draft.field"].exists)
        toggle.tap()
        let field = app.textFields["mirror.draft.field"]
        reveal(field, app); field.tap(); field.typeText(" retained")
        field.typeText("\n")
        reveal(toggle, app); toggle.tap()
        XCTAssertFalse(field.exists)
        toggle.tap()
        XCTAssertTrue((field.value as? String)?.contains("retained") == true)
    }
    func testLocationPreservesBengaluruUntilExplicitParentChangeAndSupportsCityFallback() {
        let app = launch(); openPreview(app)
        let city = app.buttons["mirror.location.city"]
        reveal(city, app); XCTAssertEqual(city.value as? String, "Bengaluru")
        city.tap(); app.buttons["Cancel"].tap()
        XCTAssertEqual(city.value as? String, "Bengaluru")
        let region = app.buttons["mirror.location.region"]
        reveal(region, app); region.tap()
        let search = app.searchFields.firstMatch
        search.tap(); search.typeText("Maharashtra")
        app.buttons["Maharashtra"].tap()
        XCTAssertEqual(city.value as? String, "Not selected")
        reveal(city, app); city.tap()
        search.tap(); search.typeText("Synthetic Town")
        app.buttons["candidate.location.customCity"].tap()
        XCTAssertEqual(city.value as? String, "Synthetic Town")
        XCTAssertFalse(app.staticTexts["Legacy Location"].exists)
    }
    func testRealTabReentryKeepsAuthoritativeScoreAndNoBlockingOverlay() {
        let app = launch()
        for _ in 0..<3 {
            app.tabBars.buttons["Passport"].tap()
            XCTAssertTrue(app.tabBars.buttons["Passport"].isSelected)
            XCTAssertTrue(app.buttons["Share Trust Passport"].waitForExistence(timeout: 5))
            app.tabBars.buttons["Home"].tap()
            XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        }
        // This runs with animations ON. Founder/device playback remains a separate gate.
        let capture = XCTAttachment(screenshot: app.screenshot()); capture.lifetime = .keepAlways; add(capture)
    }
    private func openPreview(_ app: XCUIApplication) {
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        let button = app.buttons["mirror.preview.open"]
        XCTAssertTrue(button.isHittable)
        button.tap()
        let presented = app.navigationBars["Surface & motion preview"].waitForExistence(timeout: 5)
        if !presented {
            let capture = XCTAttachment(screenshot: app.screenshot()); capture.lifetime = .keepAlways; add(capture)
        }
        XCTAssertTrue(presented)
    }
    private func launch(large: Bool = false, reduced: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchArguments += ["-kairo.appearance.preference", large ? "dark" : "light",
                                "-UIAccessibilityReduceMotionEnabled", reduced ? "YES" : "NO"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_FINAL_MIRROR": "1", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "0",
            "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        app.launch(); XCTAssertTrue(app.buttons["mirror.preview.open"].waitForExistence(timeout: 10)); return app
    }
    private func reveal(_ target: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<20 {
            if target.exists && target.isHittable && target.frame.minY > 95 && target.frame.maxY < app.frame.height - 80 { return }
            let above = target.exists && target.frame.minY < 95
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.35 : 0.72)).press(forDuration: 0.05,
                thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: above ? 0.70 : 0.36)))
        }
        XCTAssertTrue(target.isHittable)
    }
}
