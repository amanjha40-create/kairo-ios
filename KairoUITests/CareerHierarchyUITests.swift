import XCTest

@MainActor
final class CareerHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSectionOrderCountsAndNoInlineLifecycleControls() {
        let app = launch()
        let sections = [("employment", "Employment: 3 records"), ("education", "Education: 2 records"),
                        ("certifications", "Certifications: 2 records"), ("projects", "Projects: 2 records"), ("skills", "Skills: 8 records")]
        var previous: XCUIElement?
        for (key, count) in sections {
            let heading = app.staticTexts["candidate.career.\(key)"]
            reveal(heading, app)
            if let previous { XCTAssertLessThan(previous.frame.minY, heading.frame.minY) }
            previous = heading
            XCTAssertEqual(app.staticTexts["candidate.career.\(key).count"].label, count)
        }
        XCTAssertFalse(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Delete"].exists)
        XCTAssertFalse(app.buttons["Start verification"].exists)
    }

    func testFullRowEdgesOpenEmploymentAndPreserveDocumentsDestination() {
        let app = launch()
        let row = app.buttons["career.record.open.Trust & Operations Associate"]
        reveal(row, app)
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        XCTAssertGreaterThan(row.frame.width, app.frame.width * 0.75)
        for position in [CGVector(dx: 0.02, dy: 0.9), CGVector(dx: 0.98, dy: 0.5)] {
            row.coordinate(withNormalizedOffset: position).tap()
            XCTAssertTrue(app.staticTexts["career.detail.title"].waitForExistence(timeout: 10))
            XCTAssertEqual(app.staticTexts["career.detail.title"].label, "Trust & Operations Associate")
            XCTAssertEqual(app.descendants(matching: .any)["career.detail.status"].firstMatch.label, "Verified")
            let dates = app.staticTexts["career.detail.field.Employment dates"]
            XCTAssertTrue(dates.exists)
            XCTAssertLessThan(app.descendants(matching: .any)["career.detail.status"].firstMatch.frame.minY, dates.frame.minY)
            app.buttons["Done"].tap()
        }
        row.tap()
        let documents = app.buttons["career.detail.documents"]
        reveal(documents, app); documents.tap()
        XCTAssertTrue(app.navigationBars["Employment documents"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
    }

    func testEducationDetailTruthfulEvidenceAndHierarchy() {
        let app = launch()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "career.record.open.", "Christ University")).firstMatch
        reveal(row, app); row.tap()
        XCTAssertTrue(app.staticTexts["career.detail.field.Dates"].waitForExistence(timeout: 10))
        let notice = app.staticTexts["career.detail.educationEvidenceNotice"]
        reveal(notice, app)
        XCTAssertTrue(notice.label.contains("Historical verification evidence"))
        XCTAssertFalse(app.buttons["Download"].exists)
        let documents = app.buttons["career.detail.documents"]
        reveal(documents, app); documents.tap()
        XCTAssertTrue(app.navigationBars["Education documents"].waitForExistence(timeout: 10))
    }

    func testCertificationAttachmentAndProjectWithoutFalseVerification() {
        let app = launch()
        let certificate = app.buttons["career.record.open.People Operations Foundations"]
        reveal(certificate, app)
        XCTAssertTrue(certificate.label.contains("Attachment added"))
        certificate.tap()
        XCTAssertTrue(app.staticTexts["career.detail.field.Issue date"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Metadata edits preserve this file. Use Documents to view, replace, or remove the attachment."].exists)
        XCTAssertFalse(app.staticTexts["Verification"].exists)
        XCTAssertFalse(app.buttons["career.detail.verify"].exists)
        app.buttons["Done"].tap()
        let project = app.buttons["career.record.open.University Hiring Readiness Workshop"]
        reveal(project, app); project.tap()
        XCTAssertTrue(app.staticTexts["career.detail.title"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.descendants(matching: .any)["career.detail.status"].firstMatch.label, "Candidate-provided")
        XCTAssertFalse(app.staticTexts["Verification"].exists)
        XCTAssertFalse(app.buttons["career.detail.verify"].exists)
        XCTAssertFalse(app.links.firstMatch.exists) // Display-only fixture label is not a fabricated URL.
    }

    func testEmptySectionsHaveCountsAndOneCanonicalAddAction() {
        let app = launch(empty: true, actions: true)
        XCTAssertTrue(app.staticTexts["Your professional timeline starts here"].exists)
        for key in ["employment", "education", "certifications", "projects", "skills"] {
            let count = app.staticTexts["candidate.career.\(key).count"]
            reveal(count, app)
            XCTAssertTrue(count.label.hasSuffix("0 records"))
        }
        let add = app.buttons["candidate.career.employment.add"]
        reveal(add, app)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.career.employment.add").count, 1)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
        add.tap()
        XCTAssertTrue(app.staticTexts["candidate.career.mutation.title"].waitForExistence(timeout: 10))
        app.buttons["candidate.career.mutation.cancel"].tap()
        // Never save or create a record.
    }

    func testDetailDismissalHandsOffToCanonicalVerificationWithoutSubmitting() {
        let app = launch(actions: true)
        let row = app.buttons["career.record.open.Operations Analyst"]
        reveal(row, app); row.tap()
        let verify = app.buttons["career.detail.verify"]
        reveal(verify, app); verify.tap()
        XCTAssertTrue(app.navigationBars["Start verification"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["career.detail.title"].exists)
        // Canonical initiation opens against an isolated read-only fixture; never submit.
    }

    func testLargeTypeDarkCareerAndBackgroundRestore() {
        let app = launch(large: true)
        let row = app.buttons["career.record.open.Trust & Operations Associate"]
        reveal(row, app)
        XCTAssertTrue(row.label.contains("Northline Career Services"))
        XCTAssertTrue(row.label.contains("Verified"))
        XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
        row.tap()
        XCTAssertTrue(app.staticTexts["career.detail.title"].waitForExistence(timeout: 10))
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.staticTexts["career.detail.title"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Career"].isSelected)
    }

    private func launch(empty: Bool = false, actions: Bool = false, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": empty ? "empty" : "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        if actions { app.launchEnvironment["KAIRO_UI_TEST_CAREER_HIERARCHY"] = "1" }
        app.launch()
        if large {
            app.tabBars.buttons["More"].tap()
            let settings = app.buttons["candidate.more.settings"]
            reveal(settings, app); settings.tap()
            let dark = app.buttons["candidate.more.appearance.dark"]
            reveal(dark, app); dark.tap()
        }
        app.tabBars.buttons["Career"].tap()
        XCTAssertTrue(app.staticTexts["candidate.screen.career"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<35 {
            if element.exists && element.isHittable && element.frame.minY > 100 && element.frame.maxY < app.frame.height - 100 { return }
            let earlier = element.exists && element.frame.minY <= 100
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.35 : 0.70))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.65 : 0.40)))
        }
        XCTAssertTrue(element.isHittable)
    }
}
