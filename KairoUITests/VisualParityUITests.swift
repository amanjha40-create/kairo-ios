import XCTest

@MainActor
final class VisualParityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testHomeHierarchyAndScreenshot() {
        let app = launch()
        let hero = app.descendants(matching: .any)["candidate.home.trustScore"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidate.home.trustScore.details"].exists)
        assertBannerDoesNotCoverHeader(app)
        let attention = app.staticTexts["Needs your attention"]
        XCTAssertTrue(attention.exists)
        XCTAssertLessThan(hero.frame.minY, attention.frame.minY)
        capture("Home")
    }

    func testCareerDetailAndDocumentsReuse() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.record.open.")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        capture("Career")
        first.tap()
        XCTAssertTrue(app.otherElements["career.record.detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Details"].exists)
        XCTAssertTrue(app.staticTexts["Verification"].exists)
        capture("Employment detail")
        app.buttons["career.detail.documents"].tap()
        XCTAssertTrue(app.navigationBars["Employment documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["demo-evidence.pdf"].waitForExistence(timeout: 10))
        capture("Employment documents")
    }

    func testEducationDetail() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        let section = app.descendants(matching: .any)["candidate.career.education"].firstMatch
        reveal(section, app: app)
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "career.record.open.", "Christ University")).firstMatch
        reveal(record, app: app)
        record.tap()
        XCTAssertTrue(app.otherElements["career.record.detail"].waitForExistence(timeout: 10))
        capture("Education detail")
    }

    func testCertificationAndProjectDetails() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        for (sectionID, screenshotName) in [("candidate.career.certifications", "Certification"), ("candidate.career.projects", "Project")] {
            let section = app.descendants(matching: .any)[sectionID].firstMatch
            reveal(section, app: app)
            let visibleRecord = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.record.open.")).allElementsBoundByIndex.first { $0.isHittable && $0.frame.minY >= section.frame.minY }
            XCTAssertNotNil(visibleRecord)
            visibleRecord?.tap()
            XCTAssertTrue(app.otherElements["career.record.detail"].waitForExistence(timeout: 10))
            capture(screenshotName + " detail")
            app.buttons["Done"].tap()
        }
    }

    func testVerifyGroupsAndNextAction() {
        let app = launch()
        app.tabBars.buttons["Verify"].tap()
        XCTAssertTrue(app.staticTexts["candidate.verify.pendingRequests"].waitForExistence(timeout: 10))
        capture("Verify")
        let request = app.buttons["candidate.verify.request.action.employment-brightpath"]
        reveal(request, app: app)
        request.tap()
        XCTAssertTrue(app.staticTexts["Next action"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidate.verify.request.accept"].exists)
        capture("Verify detail")
    }

    func testPassportAndShareHierarchy() {
        let app = launch()
        app.tabBars.buttons["Passport"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.passport.header"].waitForExistence(timeout: 10))
        capture("Passport")
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app: app)
        share.tap()
        let create = app.buttons["candidate.passport.share.createEntry"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        XCTAssertTrue(app.textFields["candidate.passport.share.label"].waitForExistence(timeout: 10))
        capture("Share form")
    }

    func testMoreSettingsDocumentsAndNotifications() {
        let app = launch()
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.more.account"].waitForExistence(timeout: 10))
        capture("More")
        let documents = app.buttons["documentVault"]
        reveal(documents, app: app)
        documents.tap()
        XCTAssertTrue(app.navigationBars["Document Vault"].waitForExistence(timeout: 10))
        capture("Documents")
        app.buttons["Done"].tap()
        let settings = app.staticTexts["candidate.more.preferences"]
        reveal(settings, app: app)
        capture("Settings")
        app.tabBars.buttons["Home"].tap()
        app.buttons["candidate.home.notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 10))
        capture("Notifications")
    }

    func testDarkModeAndLargeText() {
        let app = launch(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.tabBars.buttons["More"].tap()
        let dark = app.buttons["candidate.more.appearance.dark"]
        reveal(dark, app: app)
        dark.tap()
        XCTAssertEqual(dark.value as? String, "Selected")
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["candidate.home.trustScore.details"].waitForExistence(timeout: 10))
        assertBannerDoesNotCoverHeader(app)
        capture("Home dark large text")
        app.tabBars.buttons["Career"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.career.screen"].waitForExistence(timeout: 10))
        let record = app.buttons["career.record.open.Trust & Operations Associate"]
        reveal(record, app: app)
        let status = app.descendants(matching: .any)["career.record.status.Trust & Operations Associate"].firstMatch
        XCTAssertTrue(status.exists)
        XCTAssertGreaterThanOrEqual(status.frame.minY, app.staticTexts["Trust & Operations Associate"].frame.maxY)
        capture("Career dark large text")
    }

    private func assertBannerDoesNotCoverHeader(_ app: XCUIApplication) {
        let banner = app.staticTexts["demo.banner"]
        let heading = app.staticTexts["KairoID"].firstMatch
        XCTAssertTrue(banner.exists)
        XCTAssertTrue(heading.exists)
        XCTAssertGreaterThanOrEqual(heading.frame.minY, banner.frame.maxY)
    }

    private func launch(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", "light"] + arguments
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "true", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated"
        ]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<18 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Visual Parity V1 - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
