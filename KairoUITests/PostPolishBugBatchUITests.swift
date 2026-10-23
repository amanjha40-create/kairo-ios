import XCTest

@MainActor
final class PostPolishBugBatchUITests: XCTestCase {
    private var largeDarkText = false
    override func setUpWithError() throws { continueAfterFailure = false }

    func testDarkXXXLDateAndSelectorLayouts() {
        largeDarkText = true
        testDOBPickerCancelAndCommitPreserveWireBackedInput()
        testResumeDateDegreeInstitutionPreserveValuesAndSave()
    }

    func testTutorialNavigatesBeforeEachExplanation() {
        let app = launch(["KAIRO_UI_TEST_GUIDED_TOUR": "pending", "KAIRO_UI_TEST_GUIDED_TOUR_ACCOUNT": "post-polish",
                          "KAIRO_UI_TEST_GUIDED_TOUR_RESET": "1"])
        let titles = ["Your Trust Score", "Your Trust Passport", "Build your career record", "Get important records verified", "Everything else is here"]
        let tabs = ["Home", "Passport", "Career", "Career", "More"]
        for index in 0..<5 {
            let title = app.staticTexts["candidate.guidedTour.title"]
            let expected = NSPredicate { _, _ in title.exists && title.label == titles[index] }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: expected, object: nil)], timeout: 12), .completed)
            XCTAssertTrue(app.tabBars.buttons[tabs[index]].isSelected)
            if index == 3 { XCTAssertTrue(app.staticTexts["candidate.verify.pendingRequests"].exists) }
            capture(app, "Tour-\(index)")
            app.buttons[index == 4 ? "candidate.guidedTour.done" : "candidate.guidedTour.next"].tap()
        }
        XCTAssertFalse(app.otherElements["candidate.guidedTour.overlay"].exists)
    }

    func testDOBPickerCancelAndCommitPreserveWireBackedInput() {
        let app = launch([:])
        app.tabBars.buttons["More"].tap()
        app.buttons["candidate.more.viewProfile"].tap()
        app.buttons["candidate.profile.edit"].tap()
        let input = app.textFields["candidate.profile.edit.date_of_birth"]
        app.revealContent(input)
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        let before = input.value as? String
        let picker = app.buttons["candidate.profile.edit.dobPicker"]
        app.revealContent(picker); picker.tap()
        XCTAssertTrue(app.buttons["candidate.profile.edit.dobPicker.cancel"].waitForExistence(timeout: 5))
        app.buttons["candidate.profile.edit.dobPicker.cancel"].tap()
        app.revealContent(input, missingTargetIsAbove: true)
        XCTAssertEqual(input.value as? String, before)
        app.revealContent(picker); picker.tap(); app.buttons["candidate.profile.edit.dobPicker.confirm"].tap()
        app.revealContent(input, missingTargetIsAbove: true)
        XCTAssertNotNil((input.value as? String)?.range(of: #"^\d{2}-\d{2}-\d{4}$"#, options: .regularExpression))
        capture(app, "DOB-picker")
        // Discard rather than save even these synthetic values.
        app.buttons["candidate.profile.edit.cancel"].tap()
        if app.buttons["Discard changes"].waitForExistence(timeout: 2) { app.buttons["Discard changes"].tap() }
    }

    func testResumeDateDegreeInstitutionPreserveValuesAndSave() {
        let app = launch(["KAIRO_UI_TEST_ROUTE": "onboarding", "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile",
                          "KAIRO_UI_TEST_RESUME_IMPORT_PHASE": "processingOrganising", "KAIRO_UI_TEST_RESUME_IMPORT_AUTO_ADVANCE": "0",
                          "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO": "editor_controls"])
        let edit = app.buttons["resume.review.edit.education.education"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15)); app.revealContent(edit); edit.tap()
        let date = app.buttons["resume.review.edit.start_date"]
        app.revealContent(date)
        XCTAssertTrue(date.waitForExistence(timeout: 5))
        XCTAssertEqual(date.value as? String, "2020/02/29")
        app.revealContent(date); date.tap()
        app.buttons["resume.review.edit.start_date.confirm"].tap()
        let degree = app.buttons["resume.review.edit.degree"]
        app.revealContent(degree, missingTargetIsAbove: true); degree.tap()
        let choice = app.buttons["Master of Business Administration (MBA)"]
        app.searchFields.firstMatch.tap(); app.searchFields.firstMatch.typeText("MBA")
        XCTAssertTrue(choice.waitForExistence(timeout: 5)); choice.tap()
        let institution = app.buttons["resume.review.edit.institution"]
        app.revealContent(institution, missingTargetIsAbove: true); institution.tap()
        XCTAssertTrue(app.buttons["Synthetic Institute"].waitForExistence(timeout: 5))
        app.buttons["candidate.picker.cancel"].tap()
        capture(app, "Resume-selectors")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 10)); app.revealContent(edit); edit.tap()
        app.revealContent(date)
        XCTAssertEqual(date.value as? String, "2020/02/29")
        app.revealContent(degree, missingTargetIsAbove: true)
        XCTAssertEqual(app.buttons["resume.review.edit.degree"].value as? String, "Master of Business Administration (MBA)")
        app.navigationBars.buttons["Cancel"].tap()
    }

    func testPasswordRevealAndHidePreservesExistingLogin() {
        let app = launch(["KAIRO_UI_TEST_ROUTE": "onboarding"])
        let login = app.buttons["onboarding.existingAccount"]
        XCTAssertTrue(login.waitForExistence(timeout: 10)); login.tap()
        let secure = app.secureTextFields["onboarding.login.password"]
        XCTAssertTrue(secure.waitForExistence(timeout: 10)); secure.tap(); secure.typeText("legacy-pass")
        app.buttons["onboarding.login.password.visibility"].tap()
        XCTAssertEqual(app.textFields["onboarding.login.password"].value as? String, "legacy-pass")
        app.buttons["onboarding.login.password.visibility"].tap()
        XCTAssertTrue(secure.exists)
        app.buttons["onboarding.login.password.visibility"].tap()
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(secure.exists)
    }

    func testHomeConsentEntryFourTabsAndPortrait() {
        let app = launch(["KAIRO_UI_TEST_BATCH4_HOME": "unavailable"])
        let consent = app.buttons["home.trustScore.consent"]
        XCTAssertTrue(consent.waitForExistence(timeout: 10))
        consent.tap()
        XCTAssertTrue(app.navigationBars["Trust Score details"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        XCTAssertGreaterThan(app.frame.height, app.frame.width)
        for tab in ["Home", "Career", "Passport", "More"] {
            app.tabBars.buttons[tab].tap(); XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
        }
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertFalse(app.tabBars.buttons["Verify"].exists)
        XCTAssertFalse(app.staticTexts["batch1.qa.banner"].exists)
        capture(app, "Four-tabs")
    }

    private func launch(_ extra: [String: String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-UIAccessibilityReduceMotionEnabled", "YES"]
        if largeDarkText {
            app.launchArguments += ["-kairo.appearance.preference", "dark", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        } else { app.launchArguments += ["-kairo.appearance.preference", "light"] }
        app.launchEnvironment = ["KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
            .merging(extra) { _, new in new }
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
