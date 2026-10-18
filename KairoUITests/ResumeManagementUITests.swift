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
            for title in ["Home", "Career", "Passport", "More"] {
                let tab = app.tabBars.buttons[title]
                tab.tap(); XCTAssertTrue(tab.isSelected)
                XCTAssertTrue(app.descendants(matching: .any)
                    .matching(identifier: "candidate.\(title.lowercased()).screen").firstMatch.waitForExistence(timeout: 20))
                XCTAssertFalse(app.textFields["auth.login.email"].exists)
            }
            app.tabBars.buttons["More"].tap()
            let documents = app.buttons["documentVault"]
            reveal(documents, app); documents.tap()
            XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 20))
            app.buttons["Done"].tap()
            let settings = app.buttons["candidate.more.settings"]
            reveal(settings, app); settings.tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
            app.navigationBars.buttons.firstMatch.tap()
        } else { app = launch(history: false) }
        openResume(app)
        let empty = app.staticTexts["No resumes yet"]
        let first = app.buttons["resume.management.entry.0"]
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in empty.exists || first.exists }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 30), .completed)
        if live, first.exists {
            let delete = app.buttons["resume.management.delete.0"]
            reveal(delete, app); delete.tap()
            let alert = app.alerts["Delete resume?"]
            XCTAssertTrue(alert.waitForExistence(timeout: 5))
            alert.buttons["Cancel"].tap() // Never confirm a live deletion.
            XCTAssertTrue(first.exists)
        }
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
        XCTAssertTrue(app.descendants(matching: .any)["resume.import.finalSummary"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["resume.import.viewCareer"].exists)
        app.buttons["resume.import.viewCareer"].tap()
        XCTAssertTrue(app.tabBars.buttons["Career"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Career"].isSelected)
        XCTAssertFalse(app.buttons["onboarding.resumeImport.manual"].exists)
    }

    func testEmploymentDuplicateReviewUsesSafeDefaultConfirmationAndTruthfulSummary() {
        let app = launchDuplicateReview()
        openResume(app)
        let current = app.buttons["resume.management.entry.0"]
        reveal(current, app)
        current.tap()

        let exactCard = app.descendants(matching: .any)["resume.import.employment.duplicate.item_duplicate_exact"]
        let possibleCard = app.descendants(matching: .any)["resume.import.employment.duplicate.item_duplicate_possible"]
        XCTAssertTrue(exactCard.waitForExistence(timeout: 10))
        reveal(possibleCard, app)
        XCTAssertTrue(app.staticTexts["Already in Career"].exists)
        XCTAssertTrue(app.staticTexts["Possible match"].exists)
        XCTAssertTrue(app.staticTexts["Selected: Keep existing"].exists)
        capture("Wave 5 exact possible and safe default")

        let add = app.buttons["resume.import.employment.addAsNew"]
        reveal(add, app)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
        add.tap()

        let confirmation = app.descendants(matching: .any)["resume.import.employment.confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(
            format: "label CONTAINS %@",
            "This will create a separate Employment record"
        )).firstMatch.exists)
        capture("Wave 5 distinct role confirmation")

        app.buttons["resume.import.employment.confirmDistinct"].tap()
        XCTAssertTrue(app.staticTexts["Selected: Add as new role"].waitForExistence(timeout: 10))
        capture("Wave 5 add as new confirmed")

        let looksGood = app.buttons["onboarding.resumeImport.looksGood"]
        reveal(looksGood, app)
        looksGood.tap()

        let summary = app.descendants(matching: .any)["resume.import.finalSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Resume import complete"].exists)
        XCTAssertTrue(app.staticTexts["Already in Career"].exists)
        XCTAssertTrue(app.staticTexts["Added"].exists)
        XCTAssertTrue(app.buttons["resume.import.viewCareer"].exists)
        capture("Wave 5 final backend summary")
    }

    func testEmploymentDuplicateReviewSupportsAccessibilityTextAndExplicitControls() {
        let app = launchDuplicateReview(large: true)
        openResume(app)
        let current = app.buttons["resume.management.entry.0"]
        reveal(current, app)
        current.tap()

        let add = app.buttons["resume.import.employment.addAsNew"]
        reveal(add, app)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
        XCTAssertTrue(app.staticTexts["Selected: Keep existing"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "similarity")).firstMatch.exists)
        capture("Wave 5 duplicate review dark accessibility XXL")
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

    func testDeleteConfirmationCancelLongFilenameAndLargeText() {
        let app = launch(large: true); openResume(app)
        let delete = app.buttons["resume.management.delete.0"]
        reveal(delete, app); XCTAssertGreaterThanOrEqual(delete.frame.height, 44); delete.tap()
        let alert = app.alerts["Delete resume?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Imported Career records will not be deleted")).firstMatch.exists)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["resume.management.entry.0"].exists)
        XCTAssertFalse(app.staticTexts["resume.delete.message"].exists)
    }

    func testDeleteExactPreviousWhileLoadingThenHistoryAndBackRemainIntact() {
        let app = launch(deleteMode: "slow"); openResume(app)
        confirmDelete(index: 1, app: app)
        XCTAssertTrue(app.descendants(matching: .any)["resume.delete.progress"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["resume.management.upload"].isEnabled)
        XCTAssertTrue(app.staticTexts["Resume deleted. Imported Career records were not deleted."].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["resume.management.entry.0"].label.contains("Synthetic_current_"))
        XCTAssertTrue(app.buttons["resume.management.entry.1"].label.contains("Synthetic_failed_"))
        XCTAssertFalse(app.buttons["resume.management.entry.2"].exists)
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["candidate.more.resume"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
    }

    func testDeleteLastResumeShowsCanonicalEmptyState() {
        let app = launch(single: true); openResume(app); confirmDelete(index: 0, app: app)
        XCTAssertTrue(app.staticTexts["No resumes yet"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resume.management.upload"].isEnabled)
        XCTAssertFalse(app.buttons["resume.management.entry.0"].exists)
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
    }

    func testDeleteFailurePreservesHistoryWithoutRawError() {
        let app = launch(deleteMode: "failure"); openResume(app); confirmDelete(index: 0, app: app)
        XCTAssertTrue(app.staticTexts["Couldn't delete this resume. It is still available. Nothing was removed locally."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resume.management.entry.0"].label.contains("Synthetic_current_"))
        XCTAssertFalse(app.staticTexts["Synthetic failure, not for display"].exists)
    }

    func testAmbiguousDeleteUsesUnavailableMessageNotFabricatedSuccess() {
        let app = launch(deleteMode: "ambiguous"); openResume(app); confirmDelete(index: 0, app: app)
        XCTAssertTrue(app.staticTexts["This resume is no longer available. Your history has been refreshed."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["resume.management.entry.0"].label.contains("Synthetic_previous_"))
        XCTAssertFalse(app.staticTexts["Resume deleted. Imported Career records were not deleted."].exists)
    }

    func testUnresolvedDeleteOffersReadOnlyStatusCheckAndDisablesAnotherDelete() {
        let app = launch(deleteMode: "unavailable"); openResume(app); confirmDelete(index: 0, app: app)
        let reconcile = app.buttons["resume.delete.reconcile"]
        XCTAssertTrue(reconcile.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["resume.management.delete.0"].isEnabled)
        reconcile.tap()
        XCTAssertTrue(app.buttons["resume.management.entry.0"].exists)
        XCTAssertFalse(app.buttons["resume.management.delete.0"].isEnabled)
    }

    private func confirmDelete(index: Int, app: XCUIApplication) {
        let delete = app.buttons["resume.management.delete.\(index)"]
        reveal(delete, app); delete.tap()
        let alert = app.alerts["Delete resume?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Delete resume"].tap()
    }

    private func launch(history: Bool = true, large: Bool = false, deleteMode: String = "success", single: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", large ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false", "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_RESUME_DELETE_MODE": deleteMode, "KAIRO_UI_TEST_RESUME_DELETE_SINGLE": single ? "1" : "0",
            "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO": history ? "management_history" : "management_empty"]
        app.launch(); app.tabBars.buttons["More"].tap()
        return app
    }

    private func launchDuplicateReview(large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KAIRO_UI_TESTING",
            "-ApplePersistenceIgnoreState",
            "YES",
            "-kairo.appearance.preference",
            large ? "dark" : "light"
        ]
        if large {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO": "duplicate_review"
        ]
        app.launch()
        app.tabBars.buttons["More"].tap()
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
