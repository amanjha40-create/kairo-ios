import XCTest

#if KAIRO_LOCAL_BATCH1_QA
/// Only compiled for the explicitly approved development-signed physical QA artifact.
@MainActor
final class LocalBatch1PhysicalUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testProductionHomePassportAndBackgroundInLightAndDark() {
        for style in ["Light", "Dark"] {
            let app = launch(style: style)
            XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].waitForExistence(timeout: 10))
            capture(app, "Production synthetic Home \(style)")
            app.tabBars.buttons["Passport"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["candidate.passport.screen"].waitForExistence(timeout: 10))
            capture(app, "Production synthetic Passport \(style)")
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
            app.tabBars.buttons["Home"].tap()
            XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].exists)
            app.terminate(); app.launch()
            XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].waitForExistence(timeout: 10))
        }
    }

    func testRealRestoringSessionRootInLightAndDark() {
        for style in ["Light", "Dark"] {
            let app = launch(style: style, extra: ["KAIRO_LOCAL_BATCH1_MODE": "restoring"])
            XCTAssertTrue(app.staticTexts["Restoring your session"].waitForExistence(timeout: 10))
            capture(app, "Production real restoring root \(style)")
        }
    }

    func testUnknownCareerDatesRemainAbsentAfterUnrelatedEdit() {
        let app = launch(extra: ["KAIRO_LOCAL_BATCH1_MODE": "unknownDates"])
        XCTAssertTrue(app.staticTexts["candidate.career.mutation.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.datePickers.count, 0)
        let role = app.textFields["candidate.career.employment.field.jobTitle"]
        reveal(role, app); role.tap(); role.typeText(" updated\n")
        let save = app.buttons["candidate.career.mutation.save"]
        reveal(save, app); XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.staticTexts["Unknown dates preserved"].waitForExistence(timeout: 10))
        capture(app, "Unknown Career dates preserved")
    }

    func testManualZeroExperienceSkipsWithoutCreatingBlankRows() {
        let app = launch(extra: ["KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile",
            "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE": "employment", "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL": "1",
            "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": "Synthetic", "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": "Candidate"])
        let employment = app.buttons["Continue without employment"]
        XCTAssertTrue(employment.waitForExistence(timeout: 10)); reveal(employment, app); employment.tap()
        let education = app.buttons["Continue without education"]
        XCTAssertTrue(education.waitForExistence(timeout: 10)); reveal(education, app); education.tap()
        XCTAssertTrue(app.staticTexts["onboarding.step.passportCreated"].waitForExistence(timeout: 10))
        capture(app, "Synthetic zero Career onboarding completed")
    }

    func testSyntheticResumeReviewToCompletion() {
        let app = launch(extra: ["KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile",
            "KAIRO_UI_TEST_RESUME_IMPORT_PHASE": "readyForReview",
            "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": "Synthetic", "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": "Candidate"])
        let confirm = app.buttons["onboarding.resumeImport.looksGood"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10)); reveal(confirm, app); confirm.tap()
        XCTAssertTrue(app.staticTexts["onboarding.step.passportCreated"].waitForExistence(timeout: 10))
        capture(app, "Synthetic Resume completion")
    }

    private func launch(style: String = "Light", extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-KAIRO_LOCAL_BATCH1_QA", "-ApplePersistenceIgnoreState", "YES", "-AppleInterfaceStyle", style]
        app.launchEnvironment = ["KAIRO_LOCAL_BATCH1_APPEARANCE": style.lowercased(),
            "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_PASSPORT_STATE": "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"].merging(extra) { _, value in value }
        app.launch()
        XCTAssertTrue(app.staticTexts["batch1.qa.banner"].waitForExistence(timeout: 10), "Fail closed if local QA gate is unavailable")
        return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
#endif
