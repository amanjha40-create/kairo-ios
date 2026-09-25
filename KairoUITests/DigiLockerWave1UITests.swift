import XCTest

@MainActor
final class DigiLockerWave1UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func test_homeSummaryOpensNativeHubWithSeparatedTruth() {
        let app = launch()
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app)
        XCTAssertTrue(entry.exists)
        attach(app, name: "Wave1-Home-DigiLocker-Light")
        entry.tap()

        XCTAssertTrue(app.navigationBars["DigiLocker"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Verified through DigiLocker"].exists)
        XCTAssertTrue(app.staticTexts["Available in DigiLocker"].exists)
        XCTAssertTrue(app.staticTexts["Driving Licence"].exists)
        XCTAssertTrue(app.staticTexts["PAN"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "provider-private-uri")).firstMatch.exists)
        attach(app, name: "Wave1-DigiLocker-Hub-Light")
    }

    func test_moreEntryAndProfileExposeOnlySafeIdentityProvenance() {
        let app = launch()
        app.tabBars.buttons["More"].tap()
        let digiLocker = app.buttons["candidate.more.digilocker"]
        reveal(digiLocker, in: app)
        XCTAssertTrue(digiLocker.exists)
        attach(app, name: "Wave1-More-DigiLocker-Light")

        let profile = app.buttons["candidate.more.viewProfile"]
        reveal(profile, in: app)
        profile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        let provenance = app.descendants(matching: .any)["candidate.identity.provenance"].firstMatch
        reveal(provenance, in: app)
        XCTAssertTrue(provenance.exists)
        XCTAssertTrue(waitForLabel("Source: DigiLocker", in: provenance))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[A-Z]{5}[0-9]{4}[A-Z]")).firstMatch.exists)
        attach(app, name: "Wave1-Profile-Provenance-Light")
    }

    func test_verifyUsesProviderAsAttributionInsideCanonicalGroups() {
        let app = launch()
        app.tabBars.buttons["Verify"].tap()
        XCTAssertTrue(app.staticTexts["Needs attention"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Completed"].exists)
        XCTAssertTrue(app.staticTexts["Verified via DigiLocker"].exists)
        XCTAssertTrue(app.staticTexts["Name does not match your KairoID profile"].exists)
        attach(app, name: "Wave1-Verify-Provenance-Light")
    }

    func test_passportAddsSubtleDigiLockerSourceWithoutRedesign() {
        let app = launch()
        app.tabBars.buttons["Passport"].tap()
        let identity = app.descendants(matching: .any)["candidate.passport.identity"].firstMatch
        reveal(identity, in: app)
        XCTAssertTrue(app.staticTexts["Verified via DigiLocker"].exists)
        attach(app, name: "Wave1-Passport-Provenance-Light")
    }

    func test_darkLargeTypeHubKeepsSemanticActionsReachable() {
        let app = launch(appearance: "dark", largeType: true)
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app)
        XCTAssertGreaterThanOrEqual(entry.frame.height, 44)
        attach(app, name: "Wave1-Home-DigiLocker-Dark-AXXXL")
        entry.tap()
        XCTAssertTrue(app.navigationBars["DigiLocker"].waitForExistence(timeout: 10))
        let refresh = app.buttons["Refresh status and results"]
        reveal(refresh, in: app)
        XCTAssertGreaterThanOrEqual(refresh.frame.height, 44)
        attach(app, name: "Wave1-DigiLocker-Hub-Dark-AXXXL")
    }

    func test_darkTouchedSurfacesRetainHierarchyAndSafeProvenance() {
        var app = launch(appearance: "dark")
        let homeEntry = app.buttons["candidate.home.digilocker"]
        reveal(homeEntry, in: app)
        XCTAssertTrue(homeEntry.exists)
        attach(app, name: "Wave1-Home-DigiLocker-Dark")

        app.tabBars.buttons["More"].tap()
        let moreEntry = app.buttons["candidate.more.digilocker"]
        reveal(moreEntry, in: app)
        XCTAssertTrue(moreEntry.exists)
        attach(app, name: "Wave1-More-DigiLocker-Dark")
        let profile = app.buttons["candidate.more.viewProfile"]
        reveal(profile, in: app)
        profile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        let provenance = app.descendants(matching: .any)["candidate.identity.provenance"].firstMatch
        reveal(provenance, in: app)
        XCTAssertTrue(waitForLabel("Source: DigiLocker", in: provenance))
        attach(app, name: "Wave1-Profile-Provenance-Dark")

        app.terminate()
        app = launch(appearance: "dark")
        app.tabBars.buttons["Verify"].tap()
        XCTAssertTrue(app.staticTexts["Verified via DigiLocker"].waitForExistence(timeout: 10))
        attach(app, name: "Wave1-Verify-Provenance-Dark")
        app.tabBars.buttons["Passport"].tap()
        let identity = app.descendants(matching: .any)["candidate.passport.identity"].firstMatch
        reveal(identity, in: app)
        XCTAssertTrue(app.staticTexts["Verified via DigiLocker"].exists)
        attach(app, name: "Wave1-Passport-Provenance-Dark")
    }

    private func launch(appearance: String = "light", largeType: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", appearance]
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated"
        ]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<30 {
            if element.exists && element.isHittable && element.frame.maxY < app.frame.maxY - 90 { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func waitForLabel(_ text: String, in element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { object, _ in
            (object as? XCUIElement)?.label.contains(text) == true
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
