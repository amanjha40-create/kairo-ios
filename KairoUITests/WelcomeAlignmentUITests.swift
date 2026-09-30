import XCTest

@MainActor
final class WelcomeAlignmentUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testExactStoryBenefitsAndFinalSignupRoute() {
        let app = launch()
        let headlines = ["Your career.", "One identity.", "Share with confidence.", "Your verified career"]
        let supports = [
            "Build a verified professional identity that stays with you and can be shared wherever your career takes you.",
            "We bring your verified career information together in one secure identity.",
            "Share your verified identity instantly and open doors to new opportunities.",
            "Build your professional identity once and share it whenever you need."
        ]
        for page in 0..<4 {
            let titleID = page == 0 ? "onboarding.step.welcome" : "onboarding.intro.\(page).title"
            let title = app.descendants(matching: .any)[titleID].firstMatch
            XCTAssertTrue(title.waitForExistence(timeout: 10))
            XCTAssertTrue(title.label.contains(headlines[page]))
            let supportID = page == 0 ? "onboarding.welcome.support" : "onboarding.intro.\(page).support.0"
            XCTAssertEqual(app.staticTexts[supportID].label, supports[page])
            let login = app.buttons["onboarding.existingAccount"]
            XCTAssertTrue(login.label.contains("Already have an account?"))
            XCTAssertTrue(login.label.contains("Log in"))
            let cta = app.buttons[page == 0 ? "onboarding.getStarted" : "onboarding.continue"]
            XCTAssertEqual(cta.label, page == 0 || page == 3 ? "Get Started" : "Continue")
            capture("Welcome light page \(page + 1)")
            if page == 1 { revealText("Private by default", app: app, page: page) }
            if page == 2 { revealText("You’re always in control", app: app, page: page) }
            if page == 3 {
                for title in ["Verify once", "You own it", "Share with confidence"] {
                    revealText(title, app: app, page: page)
                }
            }
            cta.tap()
        }
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 10))
    }

    func testAllFourPagesAtAccessibilityXXXLAndDarkKeepNativeActionsReachable() {
        let app = launch(large: true)
        for page in 0..<4 {
            let indicator = app.descendants(matching: .any)["onboarding.intro.pageIndicator"].firstMatch
            XCTAssertTrue(indicator.waitForExistence(timeout: 10))
            XCTAssertEqual(indicator.value as? String, "Page \(page + 1) of 4")
            capture("Welcome dark Accessibility XXXL page \(page + 1)")
            let primary = app.buttons[page == 0 ? "onboarding.getStarted" : "onboarding.continue"]
            let login = app.buttons["onboarding.existingAccount"]
            if page == 1 || page == 2 {
                XCTAssertLessThan(primary.frame.height, 125, "Decorative arrow must not force Continue onto multiple lines at XXXL")
            }
            for action in [primary, login] {
                XCTAssertTrue(action.isHittable)
                XCTAssertGreaterThanOrEqual(action.frame.height, 44)
                XCTAssertGreaterThanOrEqual(action.frame.minX, 0)
                XCTAssertLessThanOrEqual(action.frame.maxX, app.frame.maxX)
                XCTAssertLessThan(action.frame.maxY, app.frame.maxY)
            }
            if page < 3 { primary.tap() }
        }
        revealText("Your verified identity stays with you.", app: app, page: 3)
        app.buttons["onboarding.existingAccount"].tap()
        XCTAssertTrue(app.buttons["onboarding.login.submit"].waitForExistence(timeout: 10))
    }

    func testSkipKeepsCanonicalSignupRoute() {
        let app = launch()
        app.buttons["onboarding.getStarted"].tap()
        let skip = app.buttons["onboarding.intro.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
        XCTAssertTrue(app.secureTextFields.firstMatch.waitForExistence(timeout: 10))
    }

    private func launch(large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", large ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = [
            "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_ROUTE": "onboarding", "KAIRO_UI_TEST_ONBOARDING_STEP": "welcome",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1"
        ]
        app.launch()
        return app
    }

    private func revealText(_ text: String, app: XCUIApplication, page: Int) {
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        let scroll = app.scrollViews["onboarding.welcome.page.\(page)"]
        for _ in 0..<12 {
            if match.exists && match.isHittable { return }
            scroll.swipeUp()
        }
        XCTAssertTrue(match.exists)
        XCTAssertTrue(match.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
