import XCTest

@MainActor
final class DigiLockerWave1UITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testSafeConnectedReturnSurvivesBackgroundAndKeepsServerTruth() {
        checkSafeReturn(fixture: "connected", background: true)
    }

    func testSafeFailedReturnKeepsSameHubAndSavedResults() {
        checkSafeReturn(fixture: "failed")
    }

    func testSafeBrowserCancellationKeepsSameHubAndSavedResults() {
        checkSafeReturn(fixture: "connected", cancel: true)
    }

    private func checkSafeReturn(fixture: String, background: Bool = false, cancel: Bool = false) {
        // Only the credential-free Staging /complete page is read. All account
        // services are synthetic; this cannot authorize, verify, or call a provider.
        let app = launch(fixture: fixture)
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app); entry.tap()
        let connect = app.buttons["candidate.digilocker.connect"]
        reveal(connect, in: app); connect.tap()
        // System permission/browser elements can be owned by a view service.
        // Query only the app and Apple's known system hosts, never launch them.
        let hosts = [app, XCUIApplication(bundleIdentifier: "com.apple.AuthenticationServicesUI"),
                     XCUIApplication(bundleIdentifier: "com.apple.SafariViewService"),
                     XCUIApplication(bundleIdentifier: "com.apple.springboard")]
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            hosts.contains { host in host.state != .notRunning &&
                (host.buttons["Continue"].exists || host.links["Return to KairoID on iPhone"].exists) }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
        if let host = hosts.first(where: { $0.state != .notRunning && $0.buttons["Continue"].exists }) {
            host.buttons["Continue"].tap()
        }
        let pageReady = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            hosts.contains { $0.state != .notRunning && $0.links["Return to KairoID on iPhone"].exists }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [pageReady], timeout: 30), .completed)
        guard let browserHost = hosts.first(where: { $0.state != .notRunning && $0.links["Return to KairoID on iPhone"].exists }) else {
            XCTFail("Safe completion page missing"); return
        }
        let action = browserHost.links["Return to KairoID on iPhone"]
        XCTAssertTrue(action.waitForExistence(timeout: 30))
        if background {
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(action.waitForExistence(timeout: 10))
        }
        if cancel { browserHost.buttons["Cancel"].tap() } else { action.tap() }
        XCTAssertTrue(action.waitForNonExistence(timeout: 15))
        XCTAssertEqual(app.navigationBars.matching(identifier: "DigiLocker").count, 1)
        let saved = app.staticTexts["Verified through DigiLocker"]
        revealAbove(saved, in: app)
        XCTAssertTrue(saved.exists)
        XCTAssertFalse(app.staticTexts["Connected"].exists)
        if cancel {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "DigiLocker connection cancelled.")).firstMatch.exists)
        }
        if fixture == "failed" {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Couldn't connect DigiLocker.")).firstMatch.exists)
        }
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
    }

    func testBatch2FixtureVerificationFinishesWithSavedResultsAndResetConsent() {
        checkFixtureVerification(fails: false)
    }

    func testBatch2FixtureVerificationFailurePreservesResultsAndExitsLoading() {
        checkFixtureVerification(fails: true)
    }

    private func checkFixtureVerification(fails: Bool) {
        // Existing UI-test dependencies are in-memory; this never calls live Verify or OAuth.
        let app = launch(fixture: fails ? "consent" : nil)
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app); entry.tap()
        let pan = app.switches["candidate.digilocker.select.PANCR"].switches.firstMatch
        revealAbove(pan, in: app); pan.tap()
        let consent = app.buttons["candidate.digilocker.consent"]
        reveal(consent, in: app); consent.tap()
        let verify = app.buttons["candidate.digilocker.verify"]
        reveal(verify, in: app); XCTAssertTrue(verify.isEnabled); verify.tap()
        let finished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (fails ? consent.value as? String == "Unchecked" : !consent.exists) && !verify.isEnabled
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [finished], timeout: 10), .completed)
        XCTAssertFalse(app.staticTexts["Checking..."].exists)
        XCTAssertEqual(app.navigationBars.matching(identifier: "DigiLocker").count, 1)
        if fails {
            let error = app.staticTexts["DigiLocker action failed. Verification could not be completed. Review saved results before trying again."]
            revealAbove(error, in: app)
            XCTAssertTrue(error.exists)
        }
        let saved = app.staticTexts["Verified through DigiLocker"]
        revealAbove(saved, in: app); XCTAssertTrue(saved.exists)
    }

    func testConsentIsExplicitAndSelectionChangesInvalidateIt() {
        assertConsent(large: false)
    }

    func testConsentAccessibilityXXXLKeepsCheckboxAndCTAReachable() {
        assertConsent(large: true)
    }

    private func assertConsent(large: Bool) {
        let app = launch(largeType: large, fixture: "consent")
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app); entry.tap()
        let consent = app.buttons["candidate.digilocker.consent"]
        let verify = app.buttons["candidate.digilocker.verify"]
        XCTAssertFalse(consent.exists, "Consent appears only after a supported document is selected")
        reveal(verify, in: app)
        XCTAssertFalse(verify.isEnabled)
        let pan = app.switches["candidate.digilocker.select.PANCR"]
        let panControl = pan.switches.firstMatch
        revealAbove(panControl, in: app); panControl.tap()
        XCTAssertEqual(pan.value as? String, "Selected")
        reveal(consent, in: app)
        XCTAssertEqual(consent.value as? String, "Unchecked")
        XCTAssertTrue(consent.isEnabled)
        consent.tap()
        XCTAssertEqual(consent.value as? String, "Checked")
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.digilocker.consent").count, 1)
        reveal(verify, in: app)
        XCTAssertTrue(verify.isEnabled) // Do not verify, even in fixture mode.
        let licence = app.switches["candidate.digilocker.select.DRVLC"]
        let licenceControl = licence.switches.firstMatch
        revealAbove(licenceControl, in: app); licenceControl.tap()
        XCTAssertEqual(licence.value as? String, "Selected")
        reveal(consent, in: app)
        XCTAssertEqual(consent.value as? String, "Unchecked")
        reveal(verify, in: app)
        XCTAssertFalse(verify.isEnabled)
        attach(app, name: large ? "Batch1-Consent-AXXXL" : "Batch1-Consent-Standard")
    }

    func testInvalidReturnFixturePreservesOneHubAndHistoricalVerification() {
        let app = launch(fixture: "invalid")
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app); entry.tap()
        let connect = app.buttons["candidate.digilocker.connect"]
        reveal(connect, in: app); connect.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Couldn't connect DigiLocker")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(app.navigationBars.matching(identifier: "DigiLocker").count, 1)
        XCTAssertFalse(app.staticTexts["Connected"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["DigiLocker"].exists)
    }

    private func revealAbove(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
    }

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
        app.openCareerVerification()
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
        app.openCareerVerification()
        XCTAssertTrue(app.staticTexts["Verified via DigiLocker"].waitForExistence(timeout: 10))
        attach(app, name: "Wave1-Verify-Provenance-Dark")
        app.tabBars.buttons["Passport"].tap()
        let identity = app.descendants(matching: .any)["candidate.passport.identity"].firstMatch
        reveal(identity, in: app)
        XCTAssertTrue(app.staticTexts["Verified via DigiLocker"].exists)
        attach(app, name: "Wave1-Passport-Provenance-Dark")
    }

    private func launch(appearance: String = "light", largeType: Bool = false, fixture: String? = nil) -> XCUIApplication {
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
        if let fixture { app.launchEnvironment["KAIRO_UI_TEST_DIGILOCKER_RETURN"] = fixture }
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<30 {
            let viewport = visibleScrollFrame(in: app)
            if element.exists, element.frame.intersection(viewport).height >= min(44, element.frame.height),
               element.isHittable || !element.isEnabled { return }
            // Move toward the target in bounded steps, including after overshoot.
            let towardAbove = element.exists && element.frame.midY < viewport.midY
            let startY = viewport.minY + viewport.height * (towardAbove ? 0.3 : 0.7)
            let endY = viewport.minY + viewport.height * (towardAbove ? 0.7 : 0.3)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let start = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: startY - app.frame.minY))
            let end = origin.withOffset(CGVector(dx: viewport.midX - app.frame.minX, dy: endY - app.frame.minY))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable || !element.isEnabled)
        XCTAssertGreaterThanOrEqual(element.frame.intersection(visibleScrollFrame(in: app)).height,
                                    min(44, element.frame.height))
    }

    private func visibleScrollFrame(in app: XCUIApplication) -> CGRect {
        let scroll = app.scrollViews.firstMatch
        var viewport = scroll.exists ? scroll.frame.intersection(app.frame) : app.frame
        let navigation = app.navigationBars.firstMatch
        if navigation.exists && navigation.frame.intersects(viewport) {
            let top = max(viewport.minY, navigation.frame.maxY)
            viewport = CGRect(x: viewport.minX, y: top, width: viewport.width, height: max(0, viewport.maxY - top))
        }
        let tabBar = app.tabBars.firstMatch
        if tabBar.exists && tabBar.isHittable && tabBar.frame.intersects(viewport) {
            viewport.size.height = max(0, tabBar.frame.minY - viewport.minY)
        }
        return viewport.insetBy(dx: 8, dy: 8)
    }

    private func waitForLabel(_ text: String, in element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let predicate = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            // The identity section contains separately focusable disclosure and
            // provenance children; do not require a combined parent label.
            return element.label.contains(text) || element.staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", text)).firstMatch.exists
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
