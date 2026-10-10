import XCTest

@MainActor
final class Batch2MirrorUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOwnerPassportKeepsTrustCompletenessAndNavigatesToCareer() {
        let app = launch()
        app.tabBars.buttons["Passport"].tap()
        reveal(app.staticTexts["candidate.passport.strength"], app)
        let career = app.buttons["candidate.passport.viewCareer"]
        reveal(career, app)
        for section in ["employment", "education", "certifications", "projects", "skills", "portfolio"] {
            XCTAssertFalse(app.staticTexts["candidate.passport.\(section)"].exists)
        }
        career.tap()
        XCTAssertTrue(app.buttons["batch2.evidence.0"].waitForExistence(timeout: 5))
    }

    func testZeroOneTwoPrimaryProgressAndSupportingExclusion() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        for count in 0...2 {
            app.buttons["batch2.evidence.\(count)"].tap()
            let progress = app.staticTexts["career.documents.primaryProgress"]
            XCTAssertTrue(progress.waitForExistence(timeout: 5))
            XCTAssertEqual(progress.label, count < 2 ? "\(count) of 2 documents added" : "2 documents added")
            reveal(app.staticTexts["synthetic-supporting.pdf"], app)
            XCTAssertTrue(app.staticTexts["Supporting evidence"].firstMatch.exists)
            app.navigationBars.buttons["Done"].tap()
        }
    }

    func testLegacyClassifiesWithoutReuploadAndUpdatesAuthoritativeFixtureCount() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        app.buttons["batch2.evidence.1"].tap()
        let classify = app.buttons["career.documents.classify.legacy.primary"]
        reveal(classify, app); classify.tap()
        let progress = app.staticTexts["career.documents.primaryProgress"]
        reveal(progress, app)
        XCTAssertEqual(progress.label, "2 documents added")
        XCTAssertFalse(classify.exists)
        app.navigationBars.buttons["Done"].tap()
        app.buttons["batch2.evidence.1"].tap()
        let supporting = app.buttons["career.documents.classify.legacy.supporting"]
        reveal(supporting, app); supporting.tap()
        reveal(progress, app)
        XCTAssertEqual(progress.label, "1 of 2 documents added")
    }

    func testEmploymentNeutralStatusLocationAndOutlinedActionsAtXXXL() {
        let app = launch(large: true)
        app.tabBars.buttons["Career"].tap()
        app.buttons["batch2.detail"].tap()
        reveal(app.staticTexts["Jaipur, India"], app)
        XCTAssertFalse(app.staticTexts["Jaipur, United Kingdom"].exists)
        XCTAssertFalse(app.staticTexts["Withdrawn"].exists)
        for key in ["edit", "delete"] {
            let action = app.buttons["career.detail.\(key)"]
            reveal(action, app)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
            XCTAssertGreaterThanOrEqual(action.frame.minX, 0)
            XCTAssertLessThanOrEqual(action.frame.maxX, app.frame.width)
        }
        // Do not invoke destructive actions, even in the fixture.
    }

    private func launch(large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_BATCH2": "1", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated"]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Career"].waitForExistence(timeout: 10))
        return app
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<30 {
            let bottom = app.tabBars.firstMatch.isHittable ? app.tabBars.firstMatch.frame.minY : app.frame.maxY - 35
            if element.exists && element.isHittable && element.frame.minY > 100 && element.frame.maxY < bottom { return }
            let up = element.exists && element.frame.minY < 100
            app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: up ? 0.35 : 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .init(dx: 0.5, dy: up ? 0.72 : 0.35)))
        }
        XCTAssertTrue(element.isHittable)
    }
}
