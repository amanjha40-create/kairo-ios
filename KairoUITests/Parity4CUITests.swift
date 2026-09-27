import XCTest

@MainActor
final class Parity4CUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testWelcomeRetainsFourStepsAndPersistentLogin() {
        let app = launch(welcome: true)
        let indicator = app.descendants(matching: .any)["onboarding.intro.pageIndicator"].firstMatch
        for page in 1...4 {
            XCTAssertTrue(indicator.waitForExistence(timeout: 10))
            XCTAssertEqual(indicator.value as? String, "Page \(page) of 4")
            let login = app.buttons["onboarding.existingAccount"]
            XCTAssertTrue(login.isHittable)
            XCTAssertGreaterThanOrEqual(login.frame.height, 44)
            if page > 1 { XCTAssertTrue(app.buttons["onboarding.intro.skip"].isHittable) }
            if page < 4 {
                app.buttons[page == 1 ? "onboarding.getStarted" : "onboarding.continue"].tap()
            }
        }
        app.buttons["onboarding.existingAccount"].tap()
        XCTAssertTrue(app.buttons["onboarding.login.submit"].waitForExistence(timeout: 10))
    }

    func testWelcomeLargeTypeKeepsActionsInSafeViewport() {
        let app = launch(welcome: true, largeType: true)
        let login = app.buttons["onboarding.existingAccount"]
        XCTAssertTrue(login.waitForExistence(timeout: 10))
        XCTAssertTrue(login.isHittable)
        XCTAssertLessThanOrEqual(login.frame.maxX, app.frame.maxX)
        XCTAssertLessThan(login.frame.maxY, app.frame.maxY)
        let primary = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(primary.isHittable)
        XCTAssertGreaterThanOrEqual(primary.frame.height, 44)
        for _ in 0..<3 {
            XCUIDevice.shared.press(.home)
            app.activate()
            // Activation can return before the transition's hit-testing settles.
            let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: login)
            XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed)
            XCTAssertGreaterThanOrEqual(login.frame.height, 44)
        }
    }

    func testHomeTaskFirstOrderAndSingleDestinations() {
        let app = launch()
        let hero = app.descendants(matching: .any)["candidate.home.trustScore"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        let passport = app.buttons["candidate.home.viewTrustPassport"]
        reveal(passport, in: app)
        let digiLocker = app.buttons["candidate.home.digilocker"]
        reveal(digiLocker, in: app)
        XCTAssertLessThan(passport.frame.minY, digiLocker.frame.minY)
        let attention = app.staticTexts["Needs your attention"]
        reveal(attention, in: app)
        XCTAssertLessThan(digiLocker.frame.minY, attention.frame.minY)
        let career = app.descendants(matching: .any)["candidate.home.career"].firstMatch
        reveal(career, in: app)
        XCTAssertLessThan(attention.frame.minY, career.frame.minY)
        let documents = app.buttons["candidate.home.documents"]
        reveal(documents, in: app)
        XCTAssertLessThan(career.frame.minY, documents.frame.minY)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.home.viewTrustPassport").count, 1)
        let activity = app.descendants(matching: .any)["candidate.home.recentActivity"].firstMatch
        reveal(activity, in: app)
        XCTAssertLessThan(activity.frame.minY, documents.frame.minY)
    }

    func testHomeDocumentsOpensCanonicalHubAndPreservesSessionOnReturn() {
        let app = launch()
        let documents = app.buttons["candidate.home.documents"]
        reveal(documents, in: app)
        documents.tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["documents.shareDocuments"].exists)
        app.buttons["Done"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.tabBars.buttons["Home"].isSelected)
        XCTAssertTrue(documents.exists)
    }

    func testHomeEmptyAndUnavailableDoNotInventVerificationActions() {
        for state in ["empty", "error", "loading"] {
            let app = launch(home: state)
            XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].firstMatch.waitForExistence(timeout: 10))
            XCTAssertFalse(app.buttons["candidate.home.verificationRequest.action"].exists)
            if state == "empty" {
                XCTAssertTrue(app.staticTexts["No active verification requests"].exists)
            } else {
                XCTAssertFalse(app.staticTexts["No active verification requests"].exists)
                XCTAssertFalse(app.buttons["candidate.home.documents"].exists)
            }
            app.terminate()
        }
    }

    func testHomeLargeTypeDarkModeKeepsDestinationsAccessible() {
        let app = launch(largeType: true, appearance: "dark")
        let documents = app.buttons["candidate.home.documents"]
        reveal(documents, in: app)
        XCTAssertGreaterThanOrEqual(documents.frame.height, 44)
        XCTAssertGreaterThanOrEqual(documents.frame.minX, app.frame.minX)
        XCTAssertLessThanOrEqual(documents.frame.maxX, app.frame.maxX)
        documents.tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))
    }

    private func launch(welcome: Bool = false, home: String = "populated", largeType: Bool = false, appearance: String = "light") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", appearance]
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": welcome ? "onboarding" : "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": home, "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated"
        ]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<24 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 90 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }
}
