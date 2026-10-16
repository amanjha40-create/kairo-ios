import XCTest

@MainActor final class PermanentAddressProductionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testFeatureOffAndUnavailableFailClosed() {
        var app = launch("feature_off")
        XCTAssertTrue(app.staticTexts["Address verification is not available yet."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["address.location.start"].exists)
        XCTAssertFalse(app.buttons["Add permanent address"].exists)
        app = launch("provider_unavailable")
        XCTAssertTrue(app.staticTexts["address.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["address.location.start"].exists)
        XCTAssertTrue(app.buttons["Refresh status"].isEnabled)
    }
    func testNoAddressAndEditorUseCanonicalStructuredFields() {
        let app = launch("no_address")
        app.buttons["Add permanent address"].tap()
        XCTAssertTrue(app.textFields["Address line 1"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save permanent address"].isEnabled)
        XCTAssertFalse(app.staticTexts["Legacy Location"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["Add permanent address"].waitForExistence(timeout: 5))
    }
    func testZeroThroughThreeNeverLocallyVerifyAndSameDayIsDisabled() {
        for (scenario, count) in [("required", 0), ("one", 1), ("two", 2), ("three", 3)] {
            let app = launch(scenario)
            XCTAssertEqual(app.staticTexts["address.progress"].label, "Location checks: \(count) of 3 completed")
            XCTAssertTrue(app.staticTexts["Permanent Address: Not yet verified"].exists)
            XCTAssertFalse(app.staticTexts["Permanent Address Verified"].exists)
        }
        let app = launch("same_day")
        reveal(app.buttons["address.location.start"], app)
        XCTAssertFalse(app.buttons["address.location.start"].isEnabled)
    }
    func testEveryManualReviewOutcomeHasSafeCopyAndCannotAdvanceProgress() {
        for (status, prefix) in [("pending", "Review pending"), ("in_review", "Review pending"),
            ("waiting_for_address_document", "Review pending"), ("additional_evidence_requested", "Additional evidence requested"),
            ("correction_requested", "Correction required"), ("rejected", "Review rejected"),
            ("historical_target_not_retained", "This earlier check"), ("review_window_expired", "The review window")] {
            let app = launch("manual_" + status)
            let message = app.staticTexts["address.manual.review"]
            reveal(message, app)
            XCTAssertTrue(message.label.hasPrefix(prefix))
            XCTAssertEqual(app.staticTexts["address.progress"].label, "Location checks: 0 of 3 completed")
            XCTAssertFalse(app.staticTexts["Permanent Address Verified"].exists)
            reveal(app.buttons["address.location.start"], app)
            XCTAssertFalse(app.buttons["address.location.start"].isEnabled)
        }
    }
    func testReviewApprovalOnlyExplainsCheckOneAndFinalVerifiedIsSeparate() {
        var app = launch("manual_approved")
        XCTAssertEqual(app.staticTexts["address.progress"].label, "Location checks: 1 of 3 completed")
        XCTAssertTrue(app.staticTexts["address.first.check"].label.contains("Check 1 confirmed via review"))
        XCTAssertFalse(app.staticTexts["Permanent Address Verified"].exists)
        XCTAssertFalse(app.staticTexts["onsite_confirmation_manual_review"].exists)
        app = launch("verified")
        XCTAssertEqual(app.staticTexts["address.status"].label, "Permanent Address Verified")
    }
    func testManualReviewDarkXXXLReducedMotionKeepsActionsReachable() throws {
        let app = launch("manual_correction_requested", large: true, dark: true, reduced: true)
        let message = app.staticTexts["address.manual.review"]
        reveal(message, app)
        XCTAssertTrue(message.label.hasPrefix("Correction required"))
        capture("Synthetic manual review dark XXXL reduced motion")
        reveal(app.buttons["address.location.start"], app)
        XCTAssertFalse(app.buttons["address.location.start"].isEnabled)
        reveal(app.buttons["Refresh status"], app)
        XCTAssertTrue(app.buttons["Refresh status"].isHittable)
        try app.performAccessibilityAudit(for: [.textClipped, .trait, .sufficientElementDescription])
    }
    func testPhysicalVoiceOverAnnouncesReviewAndProgress() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical VoiceOver speech gate.")
        #else
        guard #available(iOS 27.0, *) else { throw XCTSkip("Requires iOS 27 speech API.") }
        let voiceOver = XCUIDevice.shared.voiceOverService
        let wasEnabled = voiceOver.isEnabled
        defer { if wasEnabled { try? voiceOver.enable() } else { try? voiceOver.disable() } }
        try voiceOver.disable()
        _ = launch("manual_pending")
        try voiceOver.enable()
        var speech = (try voiceOver.currentSpeech()).utterance
        for _ in 0..<50 {
            speech += " " + (try voiceOver.moveForward()).utterance
            if speech.contains("Review pending") && speech.contains("0 of 3") { break }
        }
        XCTAssertTrue(speech.contains("Review pending"))
        XCTAssertTrue(speech.contains("0 of 3"))
        #endif
    }
    private func launch(_ scenario: String, large: Bool = false, dark: Bool = false, reduced: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES",
            "-kairo.appearance.preference", dark ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        if reduced { app.launchArguments += ["-UIAccessibilityReduceMotionEnabled", "YES"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_CURRENT_PARITY": "1", "KAIRO_UI_TEST_ADDRESS_SCENARIO": scenario,
            "KAIRO_BUILD_CONFIGURATION": "Staging", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "0"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Permanent address"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Refresh status"].waitForExistence(timeout: 5))
        return app
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<18 {
            if element.exists && element.frame.minY > 100 && element.frame.maxY < app.frame.maxY - 60 { return }
            let down = element.exists && element.frame.minY < 100
            app.coordinate(withNormalizedOffset: .init(dx: 0.85, dy: down ? 0.35 : 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.85, dy: down ? 0.75 : 0.35)))
        }
        XCTAssertTrue(element.exists)
    }
}
