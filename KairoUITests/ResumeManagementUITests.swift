import XCTest

@MainActor
final class ResumeManagementUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    // Opt-in runner flag is used only for the separately approved physical read-only check.
    // Default Test action remains deterministic and never consumes the device's real session.
    func testOwnerResumeReadOnlyNavigationAndSessionRestart() {
        let live = ProcessInfo.processInfo.environment["KAIRO_READ_ONLY_OWNER_QA"] == "1"
        let app: XCUIApplication
        if live {
            app = XCUIApplication()
            app.launchEnvironment = ["KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false"]
            app.launch()
            XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 30))
            app.tabBars.buttons["More"].tap()
        } else { app = launch(history: false) }
        openResume(app)
        let empty = app.staticTexts["No resumes yet"]
        let first = app.buttons["resume.management.entry.0"]
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in empty.exists || first.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 30), .completed)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["candidate.more.resume"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.tabBars.buttons["More"].waitForExistence(timeout: 30))
        app.tabBars.buttons["More"].tap(); openResume(app)
        XCTAssertTrue(app.buttons["resume.management.upload"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        // Never tap upload, a record's review action, logout, or account/settings mutations.
    }

    func testEmptyResumeEntryFullWidthAndBackPreservesMainTabs() {
        let app = launch(history: false)
        let row = app.buttons["candidate.more.resume"]
        reveal(row, app)
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["No resumes yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resume.management.upload"].exists)
        XCTAssertFalse(app.buttons["onboarding.resumeImport.manual"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["candidate.more.resume"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
    }

    func testAuthenticatedNewUploadUsesSharedFlowWithoutOnboardingCopy() {
        let app = launch(history: false); openResume(app)
        app.buttons["resume.management.upload"].tap()
        XCTAssertTrue(app.buttons["onboarding.resumeImport.choose"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.resumeImport.manual"].exists)
        XCTAssertFalse(app.staticTexts["Build profile manually"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["resume.management.upload"].waitForExistence(timeout: 10))
    }

    func testCurrentAndPriorHistoryUseExactSelectedResume() {
        let app = launch(); openResume(app)
        let previous = app.buttons["resume.management.entry.1"]
        reveal(previous, app)
        XCTAssertTrue(previous.label.contains("Previous import"))
        XCTAssertTrue(previous.label.contains("Imported"))
        previous.tap()
        XCTAssertTrue(app.scrollViews["resume.management.historyDetail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Synthetic_previous_")).firstMatch.exists)
        XCTAssertFalse(app.buttons["onboarding.resumeImport.looksGood"].exists)
        capture("Authenticated Resume imported history")
    }

    func testReviewContinuationCompletesInResumeNotOnboarding() {
        let app = launch(); openResume(app)
        let current = app.buttons["resume.management.entry.0"]
        reveal(current, app); current.tap()
        let confirm = app.buttons["onboarding.resumeImport.looksGood"]
        reveal(confirm, app); confirm.tap()
        XCTAssertTrue(app.buttons["resume.management.upload"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
        XCTAssertTrue(app.buttons["resume.management.entry.0"].label.contains("Imported"))
        XCTAssertFalse(app.buttons["onboarding.resumeImport.manual"].exists)
    }

    func testFailedResumeRetriesSameWorkflowThenReviews() {
        let app = launch(); openResume(app)
        let failed = app.buttons["resume.management.entry.2"]
        reveal(failed, app); failed.tap()
        let retry = app.buttons["onboarding.resumeImport.retry"]
        reveal(retry, app); XCTAssertEqual(retry.label, "Retry Processing"); retry.tap()
        XCTAssertTrue(app.buttons["onboarding.resumeImport.looksGood"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Synthetic_failed_")).firstMatch.exists)
    }

    func testDarkLargeTextLongHistoryAndBackgroundRestart() {
        let app = launch(large: true); openResume(app)
        let current = app.buttons["resume.management.entry.0"]
        reveal(current, app)
        XCTAssertGreaterThanOrEqual(current.frame.height, 44)
        XCTAssertTrue(current.label.contains("Ready for review"))
        capture("Resume large text dark history")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.navigationBars["Resume"].waitForExistence(timeout: 10))
        app.terminate(); app.launch(); app.tabBars.buttons["More"].tap(); openResume(app)
        XCTAssertTrue(app.buttons["resume.management.entry.0"].waitForExistence(timeout: 10))
    }

    private func launch(history: Bool = true, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", large ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false", "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO": history ? "management_history" : "management_empty"]
        app.launch(); app.tabBars.buttons["More"].tap()
        return app
    }

    private func openResume(_ app: XCUIApplication) {
        let row = app.buttons["candidate.more.resume"]; reveal(row, app); row.tap()
        XCTAssertTrue(app.buttons["resume.management.upload"].waitForExistence(timeout: 10))
    }
    private func reveal(_ row: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<25 {
            let viewport = CGRect(x: 0, y: 110, width: app.frame.width, height: app.frame.height - 210)
            if row.exists && row.isHittable && row.frame.intersection(viewport).height >= min(44, row.frame.height) { return }
            let down = row.exists && row.frame.minY < 110
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.68 : 0.38)))
        }
        XCTFail("Could not reveal \(row.identifier)")
    }
    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
