import XCTest

@MainActor
final class Parity3AUITests: XCTestCase {
    func testCertificationIssueDateCanBeExplicitlyRemovedWithoutRemovingAttachment() {
        let app = launch(attachedCertification: true)
        app.tabBars.buttons["Career"].tap()
        XCTAssertTrue(app.buttons["Edit Certification"].waitForExistence(timeout: 10))
        app.buttons["Edit Certification"].tap()
        let date = app.buttons["candidate.career.certification.field.issuedDate"]
        reveal(date, app)
        XCTAssertNotEqual(date.value as? String, "Not set")
        let remove = app.buttons["candidate.career.certification.field.issuedDate.remove"]
        reveal(remove, app); remove.tap()
        XCTAssertEqual(date.value as? String, "Not set")
        XCTAssertTrue(app.staticTexts["demo-evidence.pdf"].exists)
    }
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAttachedCertificationEditorGuidanceAndCanonicalDocumentActions() {
        let app = launch(attachedCertification: true)
        app.tabBars.buttons["Career"].tap()
        app.buttons["Edit Certification"].tap()
        XCTAssertTrue(app.staticTexts["candidate.career.mutation.title"].waitForExistence(timeout: 10))
        let helper = app.staticTexts["Metadata edits preserve this file. Use Documents to view, replace, or remove the attachment."]
        reveal(helper, app)
        XCTAssertTrue(helper.isHittable)
        for stale in ["backend does not support", "backend only accepts", "file at creation"] {
            XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", stale)).firstMatch.exists)
        }
        XCTAssertFalse(app.buttons["Replace"].exists)
        XCTAssertFalse(app.buttons["Remove"].exists)
        let title = app.textFields["candidate.career.certification.field.title"]
        reveal(title, app)
        title.tap()
        title.typeText(" updated\n")
        let save = app.buttons["candidate.career.mutation.save"]
        reveal(save, app)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["Edit Certification"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["fixture.certification.attachment"].label, "demo-evidence.pdf")
        app.buttons["Edit Certification"].tap()
        reveal(helper, app)
        XCTAssertTrue(app.staticTexts["demo-evidence.pdf"].exists)
        let cancel = app.buttons["candidate.career.mutation.cancel"]
        reveal(cancel, app)
        cancel.tap()
        app.buttons["Documents"].tap()
        let view = app.buttons["View"]
        XCTAssertTrue(view.waitForExistence(timeout: 10))
        reveal(view, app)
        for action in ["View", "Replace", "Remove"] {
            XCTAssertTrue(app.buttons[action].exists)
            XCTAssertTrue(app.buttons[action].isEnabled)
        }
        app.buttons["Done"].tap()
    }

    func testSharingDefaultsRequiredPurposeAndExplicitMixedMode() {
        let app = launch()
        openShareCreate(app)
        XCTAssertTrue(app.staticTexts["Verified only"].waitForExistence(timeout: 10))
        let purpose = app.textFields["candidate.passport.share.label"]
        XCTAssertTrue(purpose.exists)
        let create = app.buttons["candidate.passport.share.create"]
        XCTAssertFalse(create.isEnabled)
        let mixed = app.switches["passport.share.mixedOptIn"]
        reveal(mixed, app)
        mixed.tap()
        XCTAssertTrue(app.staticTexts["Verified and candidate-provided"].exists)
        let profile = app.switches["candidate.passport.share.permission.profile"]
        reveal(profile, app)
        XCTAssertEqual(profile.value as? String, "0")
        let photo = app.switches["candidate.passport.share.permission.photo"]
        reveal(photo, app)
        XCTAssertEqual(photo.value as? String, "0")
        // Never tap Create: this test is solely the privacy-choice interface.
    }

    func testLegacyShareDetailAndNarrowOnlyEditor() {
        let app = launch()
        app.tabBars.buttons["Passport"].tap()
        let sharing = app.buttons["candidate.passport.share"]
        reveal(sharing, app); sharing.tap()
        let share = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Recruiter preview")).firstMatch
        reveal(share, app); share.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Legacy sharing policy")).firstMatch.waitForExistence(timeout: 10))
        let update = app.buttons["candidate.passport.share.update"]
        reveal(update, app); update.tap()
        XCTAssertFalse(app.switches["passport.share.mixedOptIn"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Existing links can only be narrowed")).firstMatch.waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()
    }

    func testWithdrawalRequiresConfirmationAndCanBeCancelled() {
        let app = launch()
        app.openCareerVerification()
        let request = app.buttons["candidate.verify.request.action.education-welingkar-review"]
        reveal(request, app); request.tap()
        let withdraw = app.buttons["verify.request.withdraw"]
        reveal(withdraw, app); withdraw.tap()
        let confirmation = app.buttons.matching(NSPredicate(format: "label == %@ AND identifier != %@", "Withdraw request", "verify.request.withdraw")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        let cancel = app.buttons["Keep request"].exists ? app.buttons["Keep request"] : app.buttons["Cancel"]
        if cancel.exists {
            cancel.tap()
        } else {
            // iOS 26 can present a compact confirmation popover without a cancel row.
            // Tapping the navigation title outside the popover cancels it.
            app.navigationBars["Request detail"].tap()
        }
        XCTAssertTrue(confirmation.waitForNonExistence(timeout: 5))
        XCTAssertTrue(withdraw.exists)
        // The destructive confirmation is intentionally not accepted.
    }

    func testDocumentsHubFiltersAndHistoricalEducationHasNoInventedActions() {
        let app = launch()
        app.tabBars.buttons["More"].tap()
        let entry = app.buttons["documentVault"]
        reveal(entry, app); entry.tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["demo-certificate.pdf"].exists)
        let filter = app.buttons["documents.filter.Verification"]
        reveal(filter, app); filter.tap()
        XCTAssertFalse(app.staticTexts["demo-certificate.pdf"].exists)
        XCTAssertTrue(app.staticTexts["demo-historical-evidence.pdf"].exists)
        XCTAssertFalse(app.buttons["Replace"].exists)
        XCTAssertFalse(app.buttons["Remove"].exists)
        XCTAssertFalse(app.buttons["View"].exists)
        app.buttons["Done"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 10))
    }

    private func openShareCreate(_ app: XCUIApplication) {
        app.tabBars.buttons["Passport"].tap()
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app); share.tap()
        let create = app.buttons["candidate.passport.share.createEntry"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
    }

    private func launch(attachedCertification: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        if attachedCertification { app.launchEnvironment["KAIRO_UI_TEST_ATTACHED_CERTIFICATION"] = "1" }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists && element.isHittable { return }
            let needsEarlierContent = element.exists && element.frame.midY < 150
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: needsEarlierContent ? 0.40 : 0.70))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: needsEarlierContent ? 0.65 : 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        let diagnostic = XCTAttachment(string: app.debugDescription)
        diagnostic.name = "Fixture-only failed navigation hierarchy"
        diagnostic.lifetime = .keepAlways
        add(diagnostic)
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }
}
