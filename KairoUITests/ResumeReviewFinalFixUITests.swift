import XCTest

@MainActor
final class ResumeReviewFinalFixUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testBulkSelectionIsImmediateWhileSerialSavesRunAndDoubleTapDoesNotOverlap() {
        let app = launch(appearance: "light", accessibilityXXXL: false,
                         extraEnvironment: ["KAIRO_UI_TEST_RESUME_EDIT_MODE": "bulk_slow"])
        let bulk = app.buttons["resume.import.section.bulkSelection.project"]
        app.revealContent(bulk)
        bulk.doubleTap()
        XCTAssertEqual(bulk.label, "Deselect all eligible Projects claims")
        XCTAssertEqual(bulk.value as? String, "Saving selections")
        XCTAssertFalse(bulk.isEnabled)
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("5"))
        for id in ["project-1", "project-2", "project-3"] {
            XCTAssertEqual(app.buttons["resume.review.selection.\(id)"].label, "Exclude claim")
        }
        XCTAssertFalse(app.buttons["resume.review.selection.profile"].exists)
        XCTAssertFalse(app.buttons["resume.review.selection.project-conflict"].exists)
        waitForSaved(bulk)
        XCTAssertFalse(app.staticTexts["Some selections couldn’t be saved. The latest saved review is shown."].exists)
        bulk.tap()
        XCTAssertEqual(bulk.label, "Select all eligible Projects claims")
        XCTAssertEqual(bulk.value as? String, "Saving selections")
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("2"))
        waitForSaved(bulk)
        XCTAssertEqual(bulk.label, "Select all eligible Projects claims")
    }

    func testBulkFailureRefetchesPartialServerTruthAndReviewRemainsUsable() {
        let app = launch(appearance: "light", accessibilityXXXL: false,
                         extraEnvironment: ["KAIRO_UI_TEST_RESUME_EDIT_MODE": "bulk_failure"])
        let bulk = app.buttons["resume.import.section.bulkSelection.project"]
        app.revealContent(bulk); bulk.tap()
        XCTAssertEqual(bulk.label, "Deselect all eligible Projects claims")
        waitForSaved(bulk)
        XCTAssertEqual(bulk.label, "Select all eligible Projects claims")
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("4"))
        XCTAssertEqual(app.buttons["resume.review.selection.project-2"].label, "Exclude claim")
        XCTAssertEqual(app.buttons["resume.review.selection.project-3"].label, "Select claim")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@",
            "Some selections couldn’t be saved. The latest saved review is shown.")).count, 1)
        XCTAssertTrue(bulk.isEnabled)
    }

    func testBulkFinalRefetchWinsOverSuccessfulPatchResponses() {
        let app = launch(appearance: "light", accessibilityXXXL: false,
                         extraEnvironment: ["KAIRO_UI_TEST_RESUME_EDIT_MODE": "bulk_server_truth"])
        let bulk = app.buttons["resume.import.section.bulkSelection.project"]
        app.revealContent(bulk); bulk.tap()
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("5"))
        waitForSaved(bulk)
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("4"))
        XCTAssertEqual(app.buttons["resume.review.selection.project-3"].label, "Select claim")
    }

    func testBulkRefetchFailureRequiresReloadInsteadOfClaimingSavedState() {
        let app = launch(appearance: "light", accessibilityXXXL: false,
                         extraEnvironment: ["KAIRO_UI_TEST_RESUME_EDIT_MODE": "bulk_refresh_failure"])
        let bulk = app.buttons["resume.import.section.bulkSelection.project"]
        app.revealContent(bulk); bulk.tap()
        XCTAssertTrue(app.staticTexts["We couldn’t refresh the saved selections. Reload the review before continuing."].waitForExistence(timeout: 25))
        XCTAssertFalse(bulk.exists)
        XCTAssertFalse(app.buttons["onboarding.resumeImport.looksGood"].exists)
    }

    private func waitForSaved(_ button: XCUIElement) {
        let saved = NSPredicate { _, _ in button.exists && button.isEnabled && button.value as? String == "Saved" }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: saved, object: nil)], timeout: 30), .completed)
    }

    func testProjectBulkSelectionAndSuggestionOnlyProfileInLightMode() {
        verifyBulkSelection(appearance: "light", accessibilityXXXL: false)
    }

    func testProjectBulkSelectionWrapsInDarkAccessibilityXXXL() {
        verifyBulkSelection(appearance: "dark", accessibilityXXXL: true)
    }

    func testHeadlineSaveFailureKeepsEditorAndUnsavedText() {
        let app = launch(
            appearance: "light",
            accessibilityXXXL: false,
            extraEnvironment: ["KAIRO_UI_TEST_RESUME_EDIT_MODE": "failure"]
        )
        let edit = app.buttons["resume.review.edit.profile.profile"]
        app.revealContent(edit)
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()

        let headline = app.textFields["resume.review.edit.professional_headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        headline.tap()
        headline.typeText(" Updated")
        app.buttons["resume.import.editor.save"].tap()

        let error = app.staticTexts["resume.import.editor.error"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        XCTAssertTrue(error.label.contains("couldn't reach the network"))
        XCTAssertTrue(headline.exists)
        XCTAssertTrue((headline.value as? String)?.contains("Updated") == true)
        XCTAssertFalse(app.staticTexts["We couldn't save that review"].exists)
    }

    func testHeadlineSaveRefetchesBeforeDismissAndPersists() {
        let app = launch(appearance: "light", accessibilityXXXL: false)
        let edit = app.buttons["resume.review.edit.profile.profile"]
        app.revealContent(edit)
        XCTAssertTrue(edit.waitForExistence(timeout: 15))
        edit.tap()

        let headline = app.textFields["resume.review.edit.professional_headline"]
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        headline.tap()
        headline.typeText(" Updated")
        app.buttons["resume.import.editor.save"].tap()

        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertTrue(headline.waitForExistence(timeout: 5))
        XCTAssertTrue((headline.value as? String)?.contains("Updated") == true)
        app.buttons["resume.import.editor.cancel"].tap()
    }

    private func verifyBulkSelection(appearance: String, accessibilityXXXL: Bool) {
        let app = launch(appearance: appearance, accessibilityXXXL: accessibilityXXXL)
        let bulk = app.buttons["resume.import.section.bulkSelection.project"]
        app.revealContent(bulk)
        XCTAssertTrue(bulk.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(bulk.frame.height, 44)
        XCTAssertEqual(bulk.label, "Select all eligible Projects claims")
        XCTAssertTrue(app.staticTexts["Suggestion only. Edit here without importing it."].exists)

        bulk.tap()
        let deselect = app.buttons["resume.import.section.bulkSelection.project"]
        let becameDeselect = NSPredicate { _, _ in
            deselect.exists && deselect.label == "Deselect all eligible Projects claims"
        }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: becameDeselect, object: nil)],
                timeout: 10
            ),
            .completed
        )
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("5"))

        waitForSaved(deselect)
        deselect.tap()
        let becameSelect = NSPredicate { _, _ in
            bulk.exists && bulk.label == "Select all eligible Projects claims"
        }
        XCTAssertEqual(
            XCTWaiter.wait(
                for: [XCTNSPredicateExpectation(predicate: becameSelect, object: nil)],
                timeout: 10
            ),
            .completed
        )
        XCTAssertTrue(element(in: app, identifier: "resume.import.stat.selected").label.contains("2"))
        XCTAssertTrue(app.staticTexts["Conflicting Project"].exists)
    }

    private func element(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func launch(
        appearance: String,
        accessibilityXXXL: Bool,
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KAIRO_UI_TESTING",
            "-ApplePersistenceIgnoreState", "YES",
            "-UIAccessibilityReduceMotionEnabled", "YES",
            "-kairo.appearance.preference", appearance
        ]
        if accessibilityXXXL {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL"
            ]
        }
        app.launchEnvironment = [
            "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_RESUME_IMPORT_PHASE": "processingOrganising",
            "KAIRO_UI_TEST_RESUME_IMPORT_AUTO_ADVANCE": "0",
            "KAIRO_UI_TEST_RESUME_IMPORT_SERVICE_SCENARIO": "editor_controls"
        ].merging(extraEnvironment) { _, new in new }
        app.launch()
        return app
    }
}
