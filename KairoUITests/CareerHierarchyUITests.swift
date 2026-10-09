import XCTest

@MainActor
final class CareerHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSectionOrderCountsAndNoInlineLifecycleControls() {
        let app = launch()
        let sections = [("employment", "Employment: 3 records"), ("education", "Education: 2 records"),
                        ("certifications", "Certifications: 2 records"), ("skills", "Skills: 8 records"),
                        ("projects", "Projects: 2 records"), ("portfolio", "Portfolio: 1 record")]
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
        keepScreenshot("Wave 2 - Career overview", app)
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
            keepScreenshot("Wave 2 - Employment detail", app)
            app.buttons["Done"].tap()
        }
        row.tap()
        let documents = app.buttons["career.detail.documents"]
        reveal(documents, app); documents.tap()
        XCTAssertTrue(app.navigationBars["Employment documents"].waitForExistence(timeout: 10))
        keepScreenshot("Wave 2 - Employment evidence", app)
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
        keepScreenshot("Wave 2 - Education detail", app)
        let documents = app.buttons["career.detail.documents"]
        reveal(documents, app); documents.tap()
        XCTAssertTrue(app.navigationBars["Education documents"].waitForExistence(timeout: 10))
        keepScreenshot("Wave 2 - Education evidence", app)
    }

    func testCertificationAttachmentAndProjectWithoutFalseVerification() {
        let app = launch()
        let certificate = app.buttons["career.record.open.People Operations Foundations"]
        reveal(certificate, app)
        XCTAssertTrue(certificate.label.contains("Attachment added"))
        XCTAssertFalse(certificate.label.contains("Candidate-provided"))
        certificate.tap()
        XCTAssertTrue(app.staticTexts["career.detail.field.Issue date"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Metadata edits preserve this file. Use Documents to view, replace, or remove the attachment."].exists)
        XCTAssertFalse(app.staticTexts["Verification"].exists)
        XCTAssertFalse(app.buttons["career.detail.verify"].exists)
        keepScreenshot("Wave 2 - Certification detail", app)
        app.buttons["Done"].tap()
        let project = app.buttons["career.record.open.University Hiring Readiness Workshop"]
        reveal(project, app)
        XCTAssertFalse(project.label.contains("Candidate-provided"))
        project.tap()
        XCTAssertTrue(app.staticTexts["career.detail.title"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["career.detail.status"].firstMatch.exists)
        let projectDetail = app.descendants(matching: .any)["career.record.detail"].firstMatch
        XCTAssertTrue(projectDetail.exists)
        XCTAssertFalse(projectDetail.staticTexts["Candidate-provided"].exists)
        XCTAssertFalse(app.staticTexts["Verification"].exists)
        XCTAssertFalse(app.buttons["career.detail.verify"].exists)
        XCTAssertFalse(app.links.firstMatch.exists) // Display-only fixture label is not a fabricated URL.
        keepScreenshot("Wave 2 - Project detail", app)
    }

    func testEmptySectionsHaveCountsAndOneCanonicalAddAction() {
        let app = launch(empty: true, actions: true)
        XCTAssertTrue(app.staticTexts["Your professional timeline starts here"].exists)
        for key in ["employment", "education", "certifications", "skills", "projects", "portfolio"] {
            let count = app.staticTexts["candidate.career.\(key).count"]
            reveal(count, app)
            XCTAssertTrue(count.label.hasSuffix("0 records"))
        }
        let add = app.buttons["candidate.career.employment.add"]
        reveal(add, app)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.career.employment.add").count, 1)
        XCTAssertGreaterThanOrEqual(add.frame.height, 43.9)
        add.tap()
        XCTAssertTrue(app.staticTexts["candidate.career.mutation.title"].waitForExistence(timeout: 10))
        app.buttons["candidate.career.mutation.cancel"].tap()
        // Never save or create a record.
        let portfolio = app.staticTexts["candidate.career.portfolio"]
        reveal(portfolio, app)
        keepScreenshot("Wave 4 - Portfolio empty state", app)
    }

    func testAllWave2AddScreensAreNavigableWithoutWriting() {
        let app = launch(empty: true, actions: true)
        let cases = [
            ("candidate.career.employment.add", "Add Employment"),
            ("candidate.career.education.add", "Add Education"),
            ("candidate.career.certifications.add", "Add Certification"),
            ("candidate.career.projects.add", "Add Project"),
            ("candidate.career.portfolio.add", "Add Portfolio Item")
        ]

        for (identifier, title) in cases {
            let add = app.buttons[identifier]
            reveal(add, app)
            add.tap()
            let editorTitle = app.staticTexts["candidate.career.mutation.title"]
            XCTAssertTrue(editorTitle.waitForExistence(timeout: 10))
            XCTAssertEqual(editorTitle.label, title)
            keepScreenshot("Wave 2 - \(title)", app)
            app.buttons["candidate.career.mutation.cancel"].tap()
            XCTAssertTrue(app.staticTexts["candidate.screen.career"].waitForExistence(timeout: 10))
        }
    }

    func testAllWave2EditScreensAreNavigableWithoutWriting() {
        let app = launch(actions: true)
        let cases = [
            ("career.record.open.Operations Analyst", "Edit Employment"),
            ("career.record.open.BBA, Human Resources & Operations", "Edit Education"),
            ("career.record.open.People Operations Foundations", "Edit Certification"),
            ("career.record.open.University Hiring Readiness Workshop", "Edit Project"),
            ("career.record.open.Candidate Experience Case Study", "Edit Portfolio Item")
        ]

        for (recordIdentifier, title) in cases {
            let row = app.buttons[recordIdentifier]
            reveal(row, app)
            row.tap()
            let edit = app.buttons["career.detail.edit"]
            reveal(edit, app)
            edit.tap()
            let editorTitle = app.staticTexts["candidate.career.mutation.title"]
            XCTAssertTrue(editorTitle.waitForExistence(timeout: 10))
            XCTAssertEqual(editorTitle.label, title)
            app.buttons["candidate.career.mutation.cancel"].tap()
            XCTAssertTrue(app.staticTexts["candidate.screen.career"].waitForExistence(timeout: 10))
        }
    }

    func testPortfolioDetailEditAndAttachmentLifecycleWithoutLiveMutation() {
        let app = launch(actions: true, portfolioAttachment: "present")
        let row = app.buttons["career.record.open.Candidate Experience Case Study"]
        reveal(row, app)
        XCTAssertTrue(row.label.contains("Attachment added"))
        keepScreenshot("Wave 4 - Career Portfolio section and card", app)
        row.tap()

        XCTAssertTrue(app.descendants(matching: .any)["candidate.career.portfolio.detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["career.detail.field.Description"].exists)
        XCTAssertTrue(app.staticTexts["career.detail.field.Tags"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["career.detail.link.Work sample URL"].exists)
        keepScreenshot("Wave 4 - Portfolio detail attachment present", app)

        let edit = app.buttons["career.detail.edit"]
        reveal(edit, app); edit.tap()
        XCTAssertEqual(app.staticTexts["candidate.career.mutation.title"].label, "Edit Portfolio Item")
        XCTAssertTrue(app.staticTexts["candidate.career.portfolio.existingAttachment"].exists)
        keepScreenshot("Wave 4 - Edit Portfolio", app)
        app.buttons["candidate.career.mutation.cancel"].tap()

        // Editing is launched after dismissing the detail presentation, so a
        // cancelled edit returns to the authoritative Career list.
        XCTAssertTrue(app.staticTexts["candidate.screen.career"].waitForExistence(timeout: 10))
        reveal(row, app)
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.career.portfolio.detail"].waitForExistence(timeout: 10))

        let documents = app.buttons["career.detail.documents"]
        reveal(documents, app); documents.tap()
        XCTAssertTrue(app.navigationBars["Portfolio attachment"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["View"].exists)
        XCTAssertTrue(app.buttons["Replace"].exists)
        XCTAssertTrue(app.buttons["Remove"].exists)
        keepScreenshot("Wave 4 - Portfolio attachment replace", app)

        app.buttons["Remove"].tap()
        XCTAssertTrue(app.buttons["Delete document"].waitForExistence(timeout: 5))
        app.buttons["Delete document"].tap()
        XCTAssertTrue(app.staticTexts["No documents attached"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidate.career.documents.upload"].exists)
        keepScreenshot("Wave 4 - Portfolio attachment removed and re-add", app)
    }

    func testPortfolioLightDarkLargeTypeAndReduceMotionPresentation() {
        let light = launch(actions: true, portfolioAttachment: "present")
        let lightRow = light.buttons["career.record.open.Candidate Experience Case Study"]
        reveal(lightRow, light); lightRow.tap()
        XCTAssertTrue(light.descendants(matching: .any)["candidate.career.portfolio.detail"].waitForExistence(timeout: 10))
        keepScreenshot("Wave 4 - Portfolio light", light)
        light.terminate()

        let dark = launch(actions: true, large: true, portfolioAttachment: "present")
        let darkRow = dark.buttons["career.record.open.Candidate Experience Case Study"]
        reveal(darkRow, dark); darkRow.tap()
        XCTAssertTrue(dark.descendants(matching: .any)["candidate.career.portfolio.detail"].waitForExistence(timeout: 10))
        XCTAssertLessThanOrEqual(dark.staticTexts["career.detail.title"].frame.maxX, dark.frame.maxX)
        keepScreenshot("Wave 4 - Portfolio dark AXXXL", dark)
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
        keepScreenshot("Wave 2 - Career dark AXXXL", app)
    }

    private func launch(
        empty: Bool = false,
        actions: Bool = false,
        large: Bool = false,
        portfolioAttachment: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES",
                               "-kairo.appearance.preference", large ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_CAREER_STATE": empty ? "empty" : "populated", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        if actions { app.launchEnvironment["KAIRO_UI_TEST_CAREER_HIERARCHY"] = "1" }
        if let portfolioAttachment { app.launchEnvironment["KAIRO_UI_TEST_PORTFOLIO_ATTACHMENT"] = portfolioAttachment }
        app.launch()
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

    private func keepScreenshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
