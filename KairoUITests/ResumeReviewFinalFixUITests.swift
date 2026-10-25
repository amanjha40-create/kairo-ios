import XCTest

@MainActor
final class ResumeReviewFinalFixUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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
