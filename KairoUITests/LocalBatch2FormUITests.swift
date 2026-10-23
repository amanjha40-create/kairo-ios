import XCTest

#if KAIRO_LOCAL_BATCH1_QA
@MainActor
final class LocalBatch2FormUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHistoricalManualDateConfirmAndCancelDoNotBecomeIncomplete() {
        let app = launch(extra: ["KAIRO_LOCAL_BATCH1_MODE": "", "KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile", "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE": "employment",
            "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL": "1", "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": "Synthetic",
            "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": "Candidate"])
        let date = app.buttons["manual.employment.0.startDate"]
        reveal(date, app)
        let historical = date.value as? String
        XCTAssertNotEqual(historical, "Not set"); XCTAssertNotEqual(historical, "Incomplete saved date")
        date.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5))
        app.buttons["manual.employment.0.startDate.confirm"].tap()
        XCTAssertEqual(date.value as? String, historical, "Picker commit must round-trip its numeric month")
        date.tap(); app.buttons["manual.employment.0.startDate.cancel"].tap()
        XCTAssertEqual(date.value as? String, historical)
        capture(app, "Historical manual date round-trip without incomplete state")
        app.terminate()
    }

    func testEmployerTradeNameClearSurvivesRefetchAndProcessRelaunch() {
        verifyClearing(editor: "employment", field: "employerTradeName")
    }
    func testCredentialIDClearSurvivesRefetchAndProcessRelaunch() {
        verifyClearing(editor: "certification", field: "credentialID")
    }
    func testFieldOfStudyClearSurvivesRefetchAndProcessRelaunch() {
        verifyClearing(editor: "education", field: "fieldOfStudy")
    }
    func testProjectRoleClearSurvivesRefetchAndProcessRelaunch() {
        verifyClearing(editor: "project", field: "role")
    }
    private func verifyClearing(editor: String, field: String) {
        let run = UUID().uuidString
        let app = launch(editor: editor, extra: ["KAIRO_POSTBUILD8_PERSISTENCE_RUN": run])
        let fieldID = "candidate.career.\(editor).field.\(field)"
        let input = app.textFields[fieldID]
        reveal(input, app)
        XCTAssertEqual(input.value as? String, "Synthetic retained value")
        input.tap()
        input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Synthetic retained value".count) + "\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let save = app.buttons["candidate.career.mutation.save"]
        reveal(save, app); XCTAssertTrue(save.isEnabled); save.tap()
        XCTAssertTrue(app.staticTexts["Wire: null; refetch: cleared"].waitForExistence(timeout: 5))
        reveal(input, app)
        XCTAssertEqual(input.value as? String, input.placeholderValue)
        capture(app, "\(editor) explicit null and canonical local refetch")
        app.terminate()
        app.launch() // Same disposable run, fresh process and editor draft.
        XCTAssertTrue(app.staticTexts["Refetched: cleared"].waitForExistence(timeout: 10))
        reveal(app.textFields[fieldID], app)
        XCTAssertEqual(app.textFields[fieldID].value as? String, app.textFields[fieldID].placeholderValue)
        capture(app, "\(editor) cleared after process relaunch — isolated store")
    }

    func testEmploymentLegacyTypeAndExplicitCanonicalSelection() {
        let app = launch()
        let picker = app.buttons["candidate.career.employment.field.employmentType"]
        reveal(picker, app)
        XCTAssertEqual(picker.value as? String, "legacy apprenticeship")
        picker.tap(); app.buttons["Contract"].tap()
        XCTAssertEqual(picker.value as? String, "Contract")
        capture(app, "Employment canonical selection")
        let save = app.buttons["candidate.career.mutation.save"]
        reveal(save, app); save.tap()
        XCTAssertTrue(app.staticTexts["Saved locally: contract / null"].waitForExistence(timeout: 5))
    }
    func testOpeningDateAndCancelPreservesNullThenConfirmationSelects() {
        let app = launch()
        let date = app.buttons["candidate.career.employment.field.startDate"]
        reveal(date, app); XCTAssertEqual(date.value as? String, "Not set"); date.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 5))
        app.buttons["candidate.career.employment.field.startDate.cancel"].tap()
        XCTAssertEqual(date.value as? String, "Not set")
        date.tap(); app.buttons["candidate.career.employment.field.startDate.confirm"].tap()
        XCTAssertNotEqual(date.value as? String, "Not set")
        let remove = app.buttons["candidate.career.employment.field.startDate.remove"]
        reveal(remove, app); remove.tap(); XCTAssertEqual(date.value as? String, "Not set")
        capture(app, "Explicit date cancel confirm remove")
    }
    func testCountryStateCityDependencyAndNoNewFreeText() {
        let app = launch()
        let country = app.buttons["career.employment.location.country"]
        reveal(country, app); country.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); search.tap(); search.typeText("India")
        app.buttons["India"].tap()
        XCTAssertEqual(country.value as? String, "India")
        let region = app.buttons["career.employment.location.region"]
        reveal(region, app); region.tap()
        app.searchFields.firstMatch.tap(); app.searchFields.firstMatch.typeText("Maharashtra")
        app.buttons["Maharashtra"].tap()
        let city = app.buttons["career.employment.location.city"]
        reveal(city, app); city.tap(); app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("Unlisted Synthetic Town")
        XCTAssertFalse(app.buttons["candidate.location.customCity"].exists)
        // iOS 26's active search replaces the sheet toolbar with its own Close.
        // End only this known search presentation, then cancel the picker itself.
        if !app.buttons["candidate.picker.cancel"].exists {
            XCTAssertTrue(app.searchFields["Search city"].exists)
            let closeSearch = app.buttons["Close"]
            XCTAssertTrue(closeSearch.isHittable)
            closeSearch.tap()
        }
        XCTAssertTrue(app.buttons["candidate.picker.cancel"].waitForExistence(timeout: 5))
        app.buttons["candidate.picker.cancel"].tap()
        XCTAssertEqual(city.value as? String, "Not selected")
        city.tap(); app.searchFields.firstMatch.tap(); app.searchFields.firstMatch.typeText("Mumbai")
        app.buttons["Mumbai"].tap()
        XCTAssertEqual(city.value as? String, "Mumbai")
        reveal(region, app); region.tap()
        app.searchFields.firstMatch.tap(); app.searchFields.firstMatch.typeText("Karnataka")
        app.buttons["Karnataka"].tap()
        XCTAssertEqual(city.value as? String, "Not selected")
        capture(app, "Dependent controlled city selection")
    }
    func testEducationDegreeLevelAndPrecisionUpdates() {
        let app = launch(editor: "education")
        let degree = app.buttons["candidate.career.education.field.degree"]
        reveal(degree, app)
        XCTAssertEqual(degree.value as? String, "Other")
        XCTAssertEqual(app.textFields["candidate.career.education.field.degree.other"].value as? String, "Uncommon degree")
        degree.tap(); app.searchFields.firstMatch.tap()
        app.searchFields.firstMatch.typeText("Bachelor of Science")
        app.buttons["Bachelor of Science (BSc)"].tap()
        XCTAssertEqual(degree.value as? String, "Bachelor of Science (BSc)")
        degree.tap(); app.searchFields.firstMatch.tap(); app.searchFields.firstMatch.typeText("Other")
        app.buttons["Other"].tap()
        let custom = app.textFields["candidate.career.education.field.degree.other"]
        reveal(custom, app); custom.tap(); custom.typeText("Unlisted specialist qualification")
        XCTAssertEqual(custom.value as? String, "Unlisted specialist qualification")
        custom.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        let level = app.buttons["candidate.career.education.field.educationLevel"]
        reveal(level, app); level.tap(); app.buttons["Other"].tap()
        XCTAssertEqual(level.value as? String, "Other")
        let precision = app.buttons["candidate.career.education.field.startPrecision"]
        let date = app.buttons["candidate.career.education.field.startDate"]
        reveal(date, app); XCTAssertEqual(date.value as? String, "2020")
        reveal(precision, app); precision.tap(); app.buttons["Month & year"].tap()
        let month = date.value as? String
        XCTAssertNotEqual(month, "2020")
        precision.tap(); app.buttons["Exact date"].tap()
        XCTAssertNotEqual(date.value as? String, month)
        precision.tap(); app.buttons["Year only"].tap()
        XCTAssertEqual(date.value as? String, "2020")
        date.tap()
        let year = app.textFields["candidate.career.education.field.startDate.year"]
        XCTAssertTrue(year.waitForExistence(timeout: 5))
        XCTAssertEqual(year.value as? String, "2020")
        app.buttons["candidate.career.education.field.startDate.cancel"].tap()
        capture(app, "Education precision and degree")
    }
    func testCurrentEducationAndEmploymentRequireExplicitRemoval() {
        for editor in ["education", "employment"] {
            let app = launch(editor: editor)
            let toggle = app.switches["candidate.career.\(editor).field.\(editor == "education" ? "currentlyStudying" : "currentlyWorking")"]
            reveal(toggle, app); toggle.tap()
            let end = app.buttons["candidate.career.\(editor).field.endDate"]
            reveal(end, app); XCTAssertFalse(end.isEnabled)
            let remove = app.buttons["candidate.career.\(editor).field.endDate.remove"]
            XCTAssertTrue(remove.exists); remove.tap()
            XCTAssertEqual(end.value as? String, "Not set")
            let save = app.buttons["candidate.career.mutation.save"]
            reveal(save, app); XCTAssertTrue(save.isEnabled)
            capture(app, "Explicit current conflict resolution \(editor)")
        }
    }
    func testCertificationRequiredIssueDateAndOptionalExpiry() {
        let app = launch(editor: "certification")
        let issue = app.buttons["candidate.career.certification.field.issuedDate"]
        reveal(issue, app)
        XCTAssertTrue(issue.label.contains("required"))
        XCTAssertEqual(issue.value as? String, "Not set")
        capture(app, "Certification before center date tap")
        issue.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["candidate.career.certification.field.issuedDate.confirm"].waitForExistence(timeout: 5))
        app.buttons["candidate.career.certification.field.issuedDate.confirm"].tap()
        let save = app.buttons["candidate.career.mutation.save"]
        reveal(save, app); XCTAssertTrue(save.isEnabled)
        capture(app, "Certification confirmed issue date")
    }
    func testLargeTypeLightDarkPickerReachability() {
        for style in ["light", "dark"] {
            let app = launch(editor: "education", style: style, large: true)
            let degree = app.buttons["candidate.career.education.field.degree"]
            reveal(degree, app); degree.tap()
            XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
            app.buttons["candidate.picker.cancel"].tap()
            let date = app.buttons["candidate.career.education.field.startDate"]
            reveal(date, app); date.tap()
            XCTAssertTrue(app.buttons["candidate.career.education.field.startDate.confirm"].waitForExistence(timeout: 5))
            capture(app, "XXXL date sheet \(style)")
            app.buttons["candidate.career.education.field.startDate.cancel"].tap()
            let save = app.buttons["candidate.career.mutation.save"]
            reveal(save, app); XCTAssertTrue(save.isHittable)
            capture(app, "XXXL education \(style)")
        }
    }
    func testManualOnboardingUsesCanonicalPickersAndSingleDateFields() {
        for phase in ["employment", "education"] {
            let app = launch(extra: ["KAIRO_LOCAL_BATCH1_MODE": "", "KAIRO_UI_TEST_ROUTE": "onboarding",
                "KAIRO_UI_TEST_ONBOARDING_STEP": "resumeImportOrQuickProfile", "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE": phase,
                "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL": "1", "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": "Synthetic",
                "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": "Candidate"])
            let identifier = phase == "employment" ? "onboarding.manualProfile.employment.type.0" : "onboarding.manualProfile.education.level.0"
            let requiredField = app.textFields[phase == "employment" ? "onboarding.manualProfile.employment.company.0" : "onboarding.manualProfile.education.institution.0"]
            reveal(requiredField, app)
            XCTAssertTrue(requiredField.label.contains("required"))
            let picker = app.buttons[identifier]
            reveal(picker, app); picker.tap()
            XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons[phase == "employment" ? "Contract" : "Other"].exists)
            app.buttons["candidate.picker.cancel"].tap()
            XCTAssertTrue(app.buttons["candidate.picker.cancel"].waitForNonExistence(timeout: 5))
            let date = app.buttons["manual.\(phase).0.startDate"]
            reveal(date, app); XCTAssertTrue(date.label.contains("required"))
            let before = date.value as? String
            date.tap()
            XCTAssertTrue(app.buttons["manual.\(phase).0.startDate.confirm"].waitForExistence(timeout: 5))
            app.buttons["manual.\(phase).0.startDate.cancel"].tap(); XCTAssertEqual(date.value as? String, before)
            capture(app, "Manual \(phase) unified controls")
        }
    }
    private func launch(editor: String = "employment", style: String = "light", large: Bool = false, extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-KAIRO_LOCAL_BATCH1_QA", "-ApplePersistenceIgnoreState", "YES"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_LOCAL_BATCH1_MODE": "batch2Forms", "KAIRO_BATCH2_EDITOR": editor,
            "KAIRO_LOCAL_BATCH1_APPEARANCE": style, "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1"].merging(extra) { _, value in value }
        app.launch()
        XCTAssertTrue(app.staticTexts["batch1.qa.banner"].waitForExistence(timeout: 10))
        return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<20 {
            if element.exists {
                if element.identifier == "candidate.career.mutation.save" && element.isHittable { return }
                let middle = element.frame.midY
                if element.isHittable && middle > 100 && middle < app.frame.maxY - 180 { return }
            }
            // Full-screen swipes overshoot between the newly labelled sections
            // on SE. Scroll this form by a bounded fraction; never tap coordinates.
            let scroll = app.scrollViews.firstMatch
            let earlier = element.exists && element.frame.midY < 100
            scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.45 : 0.65))
                .press(forDuration: 0.1, thenDragTo: scroll.coordinate(
                    withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.65 : 0.45)))
        }
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Form reachability failure"; hierarchy.lifetime = .keepAlways; add(hierarchy)
        capture(app, "Form reachability failure")
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
#endif
