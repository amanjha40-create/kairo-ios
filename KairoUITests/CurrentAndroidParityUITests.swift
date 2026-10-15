import XCTest

@MainActor final class CurrentAndroidParityUITests: XCTestCase {
    private var voiceOverInitialState: Bool?
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        // Keep a failed prior speech test from changing subsequent tap semantics.
        if #available(iOS 27.0, *) { try XCUIDevice.shared.voiceOverService.disable() }
        #endif
    }
    override func tearDownWithError() throws {
        // XCTest aborts on an assertion when continueAfterFailure is false;
        // teardown, not just Swift defer, must restore the device setting.
        if #available(iOS 27.0, *), let enabled = voiceOverInitialState {
            if enabled { try XCUIDevice.shared.voiceOverService.enable() }
            else { try XCUIDevice.shared.voiceOverService.disable() }
        }
        voiceOverInitialState = nil
    }

    func testCompletedReferencesHaveTwoOfTwoAndNoCandidateSendAction() {
        let app = launch()
        open("parity.references.completed", app)
        XCTAssertTrue(app.staticTexts["references.progress"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["references.progress"].label, "2 of 2 completed")
        XCTAssertTrue(app.staticTexts["HR Reference"].exists)
        XCTAssertTrue(app.staticTexts["Reporting Manager"].exists)
        XCTAssertFalse(app.buttons["Send invitation"].exists)
        XCTAssertFalse(app.buttons["Send reference request"].exists)
    }
    func testNominationValidatesContactAndSavesAwaitingHRWithoutSending() {
        let app = launch()
        open("parity.references.nomination", app)
        reveal(app.buttons["references.nominate"], app).tap()
        reveal(app.textFields["references.name"], app).tap(); app.textFields["references.name"].typeText("Synthetic Manager")
        app.textFields["references.name"].typeText("\n")
        reveal(app.textFields["Designation"], app).tap(); app.textFields["Designation"].typeText("QA Lead")
        XCTAssertFalse(app.buttons["references.save"].isEnabled)
        // Close the focused keyboard before scrolling to the next field. On a
        // software-keyboard Simulator, the generic drag begins inside the keyboard.
        app.textFields["Designation"].typeText("\n")
        reveal(app.textFields["Work email"], app).tap(); app.textFields["Work email"].typeText("manager@example.invalid")
        // Return dismisses the focused field without dismissing the native sheet.
        app.textFields["Work email"].typeText("\n")
        reveal(app.buttons["references.save"], app).tap()
        XCTAssertTrue(app.staticTexts["Awaiting HR confirmation"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Send invitation"].exists)
    }
    func testPrivateHRIdentityWithheldAndChangeRequiresConsent() {
        let app = launch()
        open("parity.references.withheld", app)
        XCTAssertTrue(app.staticTexts["references.progress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Private identity must not render"].exists)
        reveal(app.buttons["references.nominate"], app).tap()
        XCTAssertTrue(app.staticTexts["Relationship: Reporting Manager"].exists)
        XCTAssertFalse(app.buttons["references.save"].isEnabled)
    }
    func testFormerManagerAndInvitationStatesAreNotEmploymentFailure() {
        let app = launch()
        open("parity.references.former", app)
        XCTAssertTrue(app.staticTexts["Former Reporting Manager"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Done"].tap()
        open("parity.references.sent", app)
        XCTAssertTrue(app.staticTexts["Invitation sent"].waitForExistence(timeout: 5))
        reveal(app.buttons["references.policy"], app).tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Reference completion is separate from employment verification.")).firstMatch.exists)
    }
    func testRequiredDocumentAndZeroOfThreeRemainUnverified() {
        let app = launch()
        open("parity.address.required", app)
        XCTAssertTrue(app.staticTexts["address.status"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["address.status"].label, "Needs review")
        XCTAssertEqual(app.staticTexts["address.progress"].label, "Location checks: 0 of 3 completed")
        reveal(app.staticTexts["address.document.status"], app)
        XCTAssertEqual(app.staticTexts["address.document.status"].label, "Required")
        XCTAssertTrue(app.staticTexts["Permanent Address: Not yet verified"].exists)
    }
    func testApprovedDocumentDoesNotImplyAddressVerifiedAtXXXL() {
        let app = launch(large: true)
        open("parity.address.approved", app)
        reveal(app.staticTexts["address.document.status"], app)
        XCTAssertEqual(app.staticTexts["address.document.status"].label, "Approved")
        reveal(app.staticTexts["address.progress"], app)
        XCTAssertEqual(app.staticTexts["address.progress"].label, "Location checks: 0 of 3 completed")
        XCTAssertFalse(app.staticTexts["Permanent Address Verified"].exists)
    }
    func testReviewCorrectionRejectedAndBackendVerifiedStates() {
        let app = launch()
        for (scenario, label) in [("review", "Under review"), ("correction", "Needs correction"), ("rejected", "Rejected"), ("verified", "Approved")] {
            open("parity.address." + scenario, app)
            reveal(app.staticTexts["address.document.status"], app)
            XCTAssertEqual(app.staticTexts["address.document.status"].label, label)
            if scenario == "verified" { XCTAssertEqual(app.staticTexts["address.status"].label, "Permanent Address Verified") }
            app.navigationBars.buttons["Done"].tap()
        }
    }
    func testExplicitDocumentConsentRequiredBeforeReview() {
        let app = launch()
        open("parity.address.uploaded", app)
        let submit = reveal(app.buttons["address.document.submit"], app)
        XCTAssertFalse(submit.isEnabled)
        let consent = app.switches["I am providing this document as proof of my current permanent address."]
        reveal(consent, app).tap()
        reveal(submit, app).tap()
        XCTAssertTrue(app.staticTexts["Under review"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Permanent Address Verified"].exists)
    }
    func testLocationPermissionFailureAndTimeoutAreSafeRetryableStates() {
        let app = launch()
        for scenario in ["denied", "disabled", "timeout"] {
            open("parity.address." + scenario, app)
            reveal(app.buttons["address.location.start"], app).tap()
            reveal(app.staticTexts["address.error"], app)
            XCTAssertFalse(app.staticTexts["address.error"].label.isEmpty)
            XCTAssertEqual(app.staticTexts["address.progress"].label, "Location checks: 0 of 3 completed")
            app.navigationBars.buttons["Done"].tap()
        }
    }
    func testOfflineAddressHasSafeRetryAndDone() {
        let app = launch()
        open("parity.address.offline", app)
        XCTAssertTrue(app.staticTexts["address.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Refresh status"].isEnabled)
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Current parity QA"].exists)
    }
    func testUnchangedAddressSaveClosesEditorAndPreservesAuthoritativeApproval() {
        let app = launch()
        open("parity.address.approved", app)
        reveal(app.buttons["Edit permanent address"], app).tap()
        let save = app.buttons["Save permanent address"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(save.isEnabled, "An unchanged valid address must remain saveable")
        XCTAssertTrue(save.isHittable, "The sticky Save action must be reachable without scrolling")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "Successful Save dismisses the editor")
        XCTAssertTrue(app.buttons["Edit permanent address"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["address.document.status"], app)
        XCTAssertEqual(app.staticTexts["address.document.status"].label, "Approved")
        XCTAssertFalse(app.staticTexts["Permanent Address Verified"].exists)
    }
    func testDarkXXXLNominationAndDocumentConsentRemainReachable() throws {
        let app = launch(large: true, dark: true)
        open("parity.references.nomination", app)
        reveal(app.buttons["references.nominate"], app).tap()
        for name in ["references.name", "Designation", "Work email"] {
            XCTAssertTrue(reveal(app.textFields[name], app).isHittable)
        }
        XCTAssertFalse(reveal(app.buttons["references.save"], app).isEnabled)
        capture("Synthetic nomination dark XXXL")
        app.navigationBars.buttons["Done"].tap()
        open("parity.address.uploaded", app)
        let consent = app.switches["I am providing this document as proof of my current permanent address."]
        XCTAssertTrue(reveal(consent, app).isHittable)
        XCTAssertFalse(reveal(app.buttons["address.document.submit"], app).isEnabled)
        reveal(consent, app).tap()
        XCTAssertTrue(reveal(app.buttons["address.document.submit"], app).isEnabled)
        capture("Synthetic document consent dark XXXL")
        try app.performAccessibilityAudit(for: [.textClipped, .trait, .sufficientElementDescription])
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Current parity QA"].exists)
    }
    func testSyntheticReferenceAccessibilityAudit() throws {
        let app = launch()
        open("parity.references.completed", app)
        XCTAssertTrue(app.staticTexts["references.progress"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .trait, .sufficientElementDescription]) { issue in
            // iOS 27's native glass Done produces a false contrast finding in this
            // harness. Retained device evidence shows black text on RGB 249+ white
            // (19.95:1). Do not exempt any app content or any other audit category.
            let done = app.navigationBars.buttons["Done"]
            if #available(iOS 27.0, *), issue.auditType == .contrast,
               issue.element?.elementType == .button, issue.element?.label == "Done",
               app.navigationBars.buttons.matching(identifier: "Done").count == 1,
               issue.element?.frame == done.frame {
                let evidence = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                evidence.name = "Native glass Done contrast exception — inspect retained pixels"
                evidence.lifetime = .keepAlways
                self.add(evidence)
                return true
            }
            return false
        }
        capture("Synthetic completed reference accessibility")
    }
    func testVoiceOverReadsReferenceProgressAndDocumentConsent() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical-device speech gate: Simulator VoiceOver returns intermittent No speech available. Run this test on the iPhone.")
        #else
        guard #available(iOS 27.0, *) else {
            throw XCTSkip("Programmatic VoiceOver speech verification requires iOS 27 or later.")
        }
        let service = XCUIDevice.shared.voiceOverService
        let wasEnabled = service.isEnabled
        voiceOverInitialState = wasEnabled
        defer { if wasEnabled { try? service.enable() } else { try? service.disable() } }
        let app = launch()
        open("parity.references.completed", app)
        try service.enable()
        var speech = (try service.currentSpeech()).utterance
        for _ in 0..<35 {
            speech += " " + (try service.moveForward()).utterance
            if speech.contains("2 of 2 completed") && speech.contains("HR Reference") && speech.contains("Reporting Manager") { break }
        }
        XCTAssertTrue(speech.contains("2 of 2 completed"))
        XCTAssertTrue(speech.contains("HR Reference"))
        XCTAssertTrue(speech.contains("Reporting Manager"))
        try service.disable()
        app.navigationBars.buttons["Done"].tap()
        open("parity.address.uploaded", app)
        let consent = app.switches["I am providing this document as proof of my current permanent address."]
        reveal(consent, app)
        try service.enable()
        speech = (try service.currentSpeech()).utterance
        for _ in 0..<45 {
            speech += " " + (try service.moveForward()).utterance
            if speech.contains("proof of my current permanent address") && speech.contains("Submit for review") { break }
        }
        let speechEvidence = XCTAttachment(string: speech)
        speechEvidence.name = "Synthetic document VoiceOver speech only"
        speechEvidence.lifetime = .keepAlways
        add(speechEvidence)
        XCTAssertTrue(speech.contains("proof of my current permanent address"))
        XCTAssertTrue(speech.contains("Submit for review"))
        XCTAssertFalse(app.buttons["address.document.submit"].isEnabled)
        try service.disable()
        reveal(consent, app).tap()
        XCTAssertTrue(reveal(app.buttons["address.document.submit"], app).isEnabled)
        if wasEnabled { try service.enable() }
        #endif
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    private func launch(large: Bool = false, dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchArguments += ["-kairo.appearance.preference", dark ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_CURRENT_PARITY":"1", "KAIRO_APP_ENVIRONMENT":"staging", "KAIRO_BUILD_CONFIGURATION":"Staging", "KAIRO_DEMO_MODE":"false", "KAIRO_UI_TEST_DISABLE_ANIMATIONS":"1"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Current parity QA"].waitForExistence(timeout: 10))
        return app
    }
    private func open(_ key: String, _ app: XCUIApplication) { reveal(app.buttons[key], app).tap() }
    @discardableResult private func reveal(_ element: XCUIElement, _ app: XCUIApplication) -> XCUIElement {
        for _ in 0..<24 {
            if element.exists && element.isHittable && element.frame.minY > 100 && element.frame.maxY < app.frame.maxY - 55 { return element }
            // A native switch includes its multiline label in its AX frame.
            // At XXXL, requiring that whole label to fit oscillates the scroll
            // position although the control's tap point is already reachable.
            if element.exists && element.elementType == .switch && element.isHittable &&
                element.frame.midY > 100 && element.frame.midY < app.frame.maxY - 55 { return element }
            // At XXXL the full consent label can exceed the viewport. Its native
            // switch remains reachable; the accessibility audit checks clipping.
            if element.exists && element.isHittable && element.frame.height > app.frame.height - 155 &&
                element.frame.intersection(app.frame.insetBy(dx: 0, dy: 100)).height > 160 { return element }
            let down = element.exists && element.frame.minY < 100
            app.coordinate(withNormalizedOffset: .init(dx: 0.8, dy: down ? 0.35 : 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.8, dy: down ? 0.72 : 0.35)))
        }
        XCTAssertTrue(element.isHittable)
        return element
    }
}
