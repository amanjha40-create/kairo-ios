import XCTest

@MainActor
final class HelpCenterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMoreOpensNativeHelpCenterWithCertifiedContent() {
        let app = launchHelpCenter()

        XCTAssertTrue(app.otherElements["candidate.help.screen"].exists || app.scrollViews["candidate.help.screen"].exists)
        XCTAssertTrue(app.staticTexts["How can we help?"].exists)
        XCTAssertTrue(app.buttons["candidate.help.guide.getting-started"].exists)
        XCTAssertTrue(app.buttons["candidate.help.guide.verifying-roles"].exists)
        XCTAssertTrue(app.buttons["candidate.help.guide.trust-score"].exists)
        XCTAssertTrue(app.buttons["candidate.help.guide.sharing-passport"].exists)
        XCTAssertTrue(app.buttons["candidate.help.faq.timing"].exists)
        XCTAssertTrue(app.buttons["candidate.help.faq.support"].exists)
        capture("Help Center home light")
    }

    func testGuideOpensNativelyAndReturnsFocusToItsTrigger() {
        let app = launchHelpCenter()
        let guide = app.buttons["candidate.help.guide.getting-started"]
        XCTAssertTrue(guide.waitForExistence(timeout: 10))
        guide.tap()

        XCTAssertTrue(app.navigationBars["Getting started"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Complete your profile"].exists)
        XCTAssertTrue(app.staticTexts["Build your Trust Passport"].exists)
        capture("Help guide detail light")

        app.buttons["candidate.help.detail.close"].tap()
        XCTAssertTrue(guide.waitForExistence(timeout: 10))
        XCTAssertTrue(guide.isHittable)
    }

    func testFAQDisclosureAnnouncesAndReversesItsState() {
        let app = launchHelpCenter()
        let faq = app.buttons["candidate.help.faq.timing"]
        reveal(faq, in: app)
        XCTAssertEqual(faq.value as? String, "Collapsed")
        faq.tap()

        XCTAssertEqual(faq.value as? String, "Expanded")
        let answer = app.staticTexts["candidate.help.faq.timing.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 10))
        reveal(answer, in: app)
        capture("Help FAQ expanded light")

        reveal(faq, in: app)
        faq.tap()
        XCTAssertEqual(faq.value as? String, "Collapsed")
        XCTAssertFalse(answer.exists)
    }

    func testSearchResultAndTypoQueryOpenExactContent() {
        let app = launchHelpCenter()
        let search = app.textFields["candidate.help.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("privacy")

        let faqResult = app.buttons["candidate.help.search.result.faq.privacy"]
        XCTAssertTrue(faqResult.waitForExistence(timeout: 10))
        capture("Help search results light")
        faqResult.tap()
        XCTAssertTrue(app.navigationBars["Is my data private?"].waitForExistence(timeout: 10))
        app.buttons["candidate.help.detail.close"].tap()

        let clear = app.buttons["candidate.help.search.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 10))
        clear.tap()
        search.tap()
        search.typeText("TRUST SOCRE")

        let typoResult = app.buttons["candidate.help.search.result.guide.trust-score"]
        XCTAssertTrue(typoResult.waitForExistence(timeout: 10))
        capture("Help typo tolerant result light")
        typoResult.tap()
        XCTAssertTrue(app.navigationBars["Trust score explained"].waitForExistence(timeout: 10))
    }

    func testEmptySearchStateIsPolishedAndSupportRemainsAvailable() {
        let app = launchHelpCenter()
        let search = app.textFields["candidate.help.search"]
        search.tap()
        search.typeText("zzzzzzzz")

        let empty = app.descendants(matching: .any)["candidate.help.search.empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["No results found"].exists)
        XCTAssertTrue(app.staticTexts["Try a different search term."].exists)
        capture("Help empty search light")

        dismissKeyboard(in: app)
        XCTAssertTrue(app.buttons["Email support · contact@kairoid.com"].exists)
    }

    func testSupportActionUsesSafeEmailInterception() {
        let app = launchHelpCenter()
        let support = app.buttons["candidate.help.support"]
        XCTAssertTrue(support.waitForExistence(timeout: 10))
        support.tap()

        XCTAssertTrue(app.navigationBars["Contact support"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["contact@kairoid.com"].exists)
    }

    func testDarkAccessibilityXXXLKeepsContentAndActionsReachable() {
        let app = launchHelpCenter(dark: true, accessibilityXXXL: true)
        let search = app.textFields["candidate.help.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(search.frame.height, 44)

        let guide = app.buttons["candidate.help.guide.getting-started"]
        reveal(guide, in: app)
        XCTAssertGreaterThanOrEqual(guide.frame.height, 44)
        capture("Help home dark accessibility XXXL")

        guide.tap()
        XCTAssertTrue(app.navigationBars["Getting started"].waitForExistence(timeout: 10))
        let close = app.buttons["candidate.help.detail.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(close.frame.height, 44)
        capture("Help guide dark accessibility XXXL")
    }

    private func launchHelpCenter(dark: Bool = false, accessibilityXXXL: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-KAIRO_UI_TESTING",
            "-ApplePersistenceIgnoreState",
            "YES",
            "-kairo.appearance.preference",
            dark ? "dark" : "light",
        ]
        if accessibilityXXXL {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                "UICTContentSizeCategoryAccessibilityXXXL",
            ]
        }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_DEMO_MODE": "false",
            "KAIRO_UI_TEST_MORE_STATE": "populated",
        ]
        app.launch()
        app.tabBars.buttons["More"].tap()

        let helpCenter = app.buttons["candidate.more.helpCentre"]
        reveal(helpCenter, in: app)
        helpCenter.tap()
        XCTAssertTrue(app.navigationBars["Help Center"].waitForExistence(timeout: 10))
        return app
    }

    private func dismissKeyboard(in app: XCUIApplication) {
        // Xcode may retain off-screen keyboard AX elements after typing. Send the
        // submit key to the focused field, rather than tapping that stale geometry.
        app.textFields["candidate.help.search"].typeText("\n")
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<50 {
            let viewport = CGRect(x: 0, y: 100, width: app.frame.width, height: app.frame.height - 190)
            if element.exists,
               element.isHittable,
               element.frame.intersection(viewport).height >= min(44, element.frame.height) {
                return
            }

            let scrollDown = !element.exists || element.frame.minY > 100
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: scrollDown ? 0.74 : 0.34))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: scrollDown ? 0.36 : 0.68))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTFail("Could not reveal \(element.identifier)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
