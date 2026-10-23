import XCTest

@MainActor
final class InstitutionCatalogueUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if testRun?.hasSucceeded == false {
            let app = XCUIApplication()
            capture(app, "Institution failure screen")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Institution failure hierarchy"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        }
    }

    func testCareerAddSelectionAndLegacyEditCancelPreserveFourTabs() {
        let app = launch(["KAIRO_UI_TEST_CAREER_HIERARCHY": "1"])
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["Home", "Career", "Passport", "More"])
        app.tabBars.buttons["Career"].tap()
        let add = app.buttons["candidate.career.education.add"]
        app.revealContent(add); add.tap()
        let field = app.buttons["candidate.career.education.field.institution"]
        XCTAssertTrue(field.waitForExistence(timeout: 5)); field.tap()
        chooseResult(app)
        XCTAssertEqual(field.value as? String, "Synthetic Institute")
        capture(app, "Career selected institution")
        app.buttons["candidate.career.mutation.cancel"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "career.record.open.", "Christ University")).firstMatch
        app.revealContent(row); row.tap()
        let edit = app.buttons["career.detail.edit"]
        app.revealContent(edit); edit.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let before = field.value as? String
        field.tap()
        XCTAssertEqual(app.staticTexts["institution.current"].label, before)
        app.buttons["candidate.picker.cancel"].tap()
        XCTAssertEqual(field.value as? String, before)
    }

    func testResumeSelectedValueSurvivesSaveAndReopen() {
        let app = resume()
        let edit = app.buttons["resume.review.edit.education.education"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15)); app.revealContent(edit); edit.tap()
        let field = app.buttons["resume.review.edit.institution"]
        app.revealContent(field); field.tap()
        chooseResult(app)
        XCTAssertEqual(field.value as? String, "Synthetic Institute")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 10)); app.revealContent(edit); edit.tap()
        app.revealContent(field)
        XCTAssertEqual(field.value as? String, "Synthetic Institute")
        capture(app, "Resume institution after save")
    }

    func testFailedCatalogueStillAllowsManualResumeEntry() {
        let app = resume(mode: "failure")
        let edit = app.buttons["resume.review.edit.education.education"]
        XCTAssertTrue(edit.waitForExistence(timeout: 15)); app.revealContent(edit); edit.tap()
        let field = app.buttons["resume.review.edit.institution"]
        app.revealContent(field); field.tap()
        XCTAssertTrue(app.navigationBars["Choose institution"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["institution.failure"].waitForExistence(timeout: 8))
        app.buttons["institution.manual"].tap()
        let input = app.descendants(matching: .any).matching(identifier: "institution.manual.name").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); input.tap()
        input.press(forDuration: 1.2)
        let selectAll = app.buttons["Select All"].exists ? app.buttons["Select All"] : app.menuItems["Select All"]
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5)); selectAll.tap()
        input.typeText("Historical Custom Institute")
        XCTAssertEqual(input.value as? String, "Historical Custom Institute")
        app.buttons["institution.manual.confirm"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Historical Custom Institute")
        app.navigationBars.buttons["Save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 10)); app.revealContent(edit); edit.tap()
        app.revealContent(field)
        XCTAssertEqual(field.value as? String, "Historical Custom Institute")
    }

    func testManualOnboardingSelectionAndDarkLargeTextFallbackStates() {
        let app = launch(["KAIRO_UI_TEST_ROUTE": "onboarding", "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile",
            "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE": "education", "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL": "1",
            "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": "Synthetic", "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": "Candidate"], darkLarge: true)
        let field = app.buttons["onboarding.manualProfile.education.institution.0"]
        app.revealContent(field); XCTAssertTrue(field.exists); field.tap()
        chooseResult(app)
        XCTAssertEqual(field.value as? String, "Synthetic Institute")
        capture(app, "Manual onboarding dark XXXL institution")
    }

    func testEmptyAndUnavailableCatalogueKeepManualAction() {
        for mode in ["empty", "unavailable"] {
            let app = resume(mode: mode)
            let edit = app.buttons["resume.review.edit.education.education"]
            XCTAssertTrue(edit.waitForExistence(timeout: 15)); app.revealContent(edit); edit.tap()
            let field = app.buttons["resume.review.edit.institution"]
            app.revealContent(field); field.tap()
            XCTAssertTrue(app.staticTexts["institution.\(mode)"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.buttons["institution.manual"].isHittable)
            app.buttons["candidate.picker.cancel"].tap()
            XCTAssertEqual(field.value as? String, "Synthetic Institute")
            app.terminate()
        }
    }

    func testBackendProvenanceIsReachableFromLegal() {
        let app = launch()
        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 10)); app.tabBars.buttons["More"].tap()
        let settings = app.buttons["candidate.more.settings"]
        app.revealContent(settings); settings.tap()
        let legal = app.buttons["candidate.more.legal"]
        app.revealContent(legal); legal.tap()
        let sources = app.buttons["more.institutionDataSources"]
        app.revealContent(sources); sources.tap()
        XCTAssertTrue(app.staticTexts["Synthetic test data, not a published catalogue."].waitForExistence(timeout: 8))
        capture(app, "Backend supplied institution provenance")
    }

    private func chooseResult(_ app: XCUIApplication) {
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("Synthetic\n")
        let result = app.buttons["institution.result.synthetic-institution"]
        if !result.waitForExistence(timeout: 8) {
            capture(app, "Search result visibility")
            let hierarchy = XCTAttachment(string: app.debugDescription); hierarchy.lifetime = .keepAlways; add(hierarchy)
        }
        XCTAssertTrue(result.exists); result.tap()
    }
    private func resume(mode: String = "results") -> XCUIApplication {
        launch(["KAIRO_UI_TEST_ROUTE": "onboarding", "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile",
                "KAIRO_UI_TEST_RESUME_IMPORT_PHASE": "processingOrganising", "KAIRO_UI_TEST_RESUME_IMPORT_AUTO_ADVANCE": "0",
                "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO": "editor_controls", "KAIRO_UI_TEST_INSTITUTION_MODE": mode])
    }
    private func launch(_ extra: [String: String] = [:], darkLarge: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", darkLarge ? "dark" : "light"]
        if darkLarge { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"].merging(extra) { _, new in new }
        app.launch(); return app
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
