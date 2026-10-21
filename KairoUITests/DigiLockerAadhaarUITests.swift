import XCTest

@MainActor
final class DigiLockerAadhaarUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        attach(app, name: "Synthetic Aadhaar final screen")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Synthetic Aadhaar accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    func testExplicitAvailabilityRequiresSeparateConsentBeforeVerification() {
        let app = launch(scenario: "available")
        openHub(app)
        let issuedSection = element("candidate.digilocker.available", in: app)
        let aadhaarSection = element("candidate.aadhaar.section", in: app)
        reveal(aadhaarSection, in: app)
        XCTAssertGreaterThan(aadhaarSection.frame.minY, issuedSection.frame.minY)
        XCTAssertFalse(app.buttons["candidate.aadhaar.consent"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.verify"].exists)
        XCTAssertFalse(element("candidate.aadhaar.saved", in: app).exists)

        checkAvailability(app)
        let consent = app.buttons["candidate.aadhaar.consent"]
        let verify = app.buttons["candidate.aadhaar.verify"]
        reveal(consent, in: app)
        XCTAssertEqual(consent.value as? String, "Unchecked")
        XCTAssertTrue(consent.label.contains("Required"))
        XCTAssertTrue(consent.label.contains("name and date of birth"))
        reveal(verify, in: app)
        XCTAssertFalse(verify.isEnabled)
        XCTAssertFalse(element("candidate.aadhaar.saved", in: app).exists)

        reveal(consent, in: app)
        consent.tap()
        XCTAssertEqual(consent.value as? String, "Checked")
        let pan = app.switches["candidate.digilocker.select.PANCR"].switches.firstMatch
        reveal(pan, in: app)
        pan.tap()
        let issuedConsent = app.buttons["candidate.digilocker.consent"]
        reveal(issuedConsent, in: app)
        XCTAssertEqual(issuedConsent.value as? String, "Unchecked")
        issuedConsent.tap()
        XCTAssertEqual(issuedConsent.value as? String, "Checked")
        reveal(consent, in: app)
        consent.tap()
        XCTAssertEqual(consent.value as? String, "Unchecked")
        reveal(verify, in: app)
        XCTAssertFalse(verify.isEnabled, "PAN/DL consent must not authorize e-Aadhaar")
        reveal(consent, in: app)
        consent.tap()
        reveal(verify, in: app)
        XCTAssertTrue(verify.isEnabled)
        verify.tap()

        assertSavedVerified(app)
        XCTAssertFalse(consent.exists)
        XCTAssertFalse(verify.exists)
        assertNoPrivateData(app)
        attach(app, name: "Aadhaar-Explicit-Consent-Verified")
    }

    func testNotLinkedDoesNotOfferConsentOrVerification() {
        assertAvailabilityFailure(scenario: "not-linked", message: "not linked")
    }

    func testAadhaarDisabledKeepsPANAndDrivingLicenceSeparate() {
        let app = assertAvailabilityFailure(scenario: "disabled", message: "not available")
        let available = element("candidate.digilocker.available", in: app)
        reveal(available, in: app)
        XCTAssertTrue(available.staticTexts["PAN"].exists)
        XCTAssertTrue(available.staticTexts["Driving Licence"].exists)
    }

    func testDeniedAccessHasSafeUnavailableStatus() {
        assertAvailabilityFailure(scenario: "denied", message: "unavailable")
    }

    func testExpiredConnectionRequestsExplicitReconnectWithoutOpeningBrowser() {
        assertAvailabilityFailure(scenario: "expired", message: "Reconnect")
    }

    func testTemporaryFailureDoesNotClaimVerification() {
        assertAvailabilityFailure(scenario: "temporary", message: "confirm")
    }

    func testIntegrityFailureDoesNotClaimVerification() {
        assertAvailabilityFailure(scenario: "integrity", message: "safely")
    }

    func testReconnectStateDoesNotOfferAvailabilityOrVerification() {
        let app = launch(scenario: "reconnect")
        openHub(app)
        assertStatus("Reconnect DigiLocker to check e-Aadhaar availability.", in: app)
        XCTAssertFalse(app.buttons["candidate.aadhaar.check"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.consent"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.verify"].exists)
        let saved = element("candidate.digilocker.verified", in: app)
        reveal(saved, in: app)
        // The section identifier is inherited by its leaves, not a container.
        // Match the combined saved row instead of searching beneath the heading.
        let savedLicence = app.descendants(matching: .any)
            .matching(identifier: "candidate.digilocker.verified").matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Driving Licence", "Verified")
        ).firstMatch
        XCTAssertTrue(savedLicence.waitForExistence(timeout: 10))
        reveal(savedLicence, in: app)
        assertNoPrivateData(app)
    }

    func testBaseDisabledDoesNotOfferProviderActions() {
        let app = launch(scenario: "base-disabled")
        openHub(app)
        assertStatus("Connection status unavailable. Refresh saved results before checking e-Aadhaar.", in: app)
        XCTAssertFalse(app.buttons["candidate.aadhaar.check"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.consent"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.verify"].exists)
        XCTAssertFalse(app.buttons["candidate.digilocker.connect"].exists)
        assertNoPrivateData(app)
    }

    func testSavedVerificationDoesNotAutomaticallyCheckAndContainsNoIdentifiers() {
        let app = launch(scenario: "verified")
        openHub(app)
        assertSavedVerified(app)
        let check = app.buttons["candidate.aadhaar.check"]
        reveal(check, in: app)
        XCTAssertTrue(check.isEnabled)
        XCTAssertFalse(app.buttons["candidate.aadhaar.consent"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.verify"].exists)
        XCTAssertFalse(app.staticTexts["candidate.aadhaar.status"].exists)
        assertNoPrivateData(app)
        app.buttons["Done"].tap()
        openHub(app)
        assertSavedVerified(app)
        XCTAssertFalse(app.buttons["candidate.aadhaar.consent"].exists)
        attach(app, name: "Aadhaar-Saved-Safe-Provenance")
    }

    func testLeavingAndBackgroundingClearConsentAndRequireAnotherExplicitCheck() {
        let app = launch(scenario: "available")
        openHub(app)
        for background in [false, true] {
            checkAvailability(app)
            let consent = app.buttons["candidate.aadhaar.consent"]
            reveal(consent, in: app)
            XCTAssertEqual(consent.value as? String, "Unchecked")
            consent.tap()
            XCTAssertEqual(consent.value as? String, "Checked")
            if background {
                XCUIDevice.shared.press(.home)
                app.activate()
            } else {
                app.buttons["Done"].tap()
                openHub(app)
            }
            let check = app.buttons["candidate.aadhaar.check"]
            XCTAssertTrue(check.waitForExistence(timeout: 10))
            reveal(check, in: app)
            XCTAssertFalse(consent.exists)
            XCTAssertFalse(app.buttons["candidate.aadhaar.verify"].exists)
            XCTAssertFalse(element("candidate.aadhaar.saved", in: app).exists)
        }
    }

    func testAccessibilityXXXLDarkConsentAndVerifiedResultRemainReachable() {
        let app = launch(scenario: "available", largeDark: true)
        openHub(app)
        let check = app.buttons["candidate.aadhaar.check"]
        reveal(check, in: app)
        XCTAssertGreaterThanOrEqual(check.frame.height, 44)
        attach(app, name: "Aadhaar-Dark-AXXXL-Explicit-Check")
        checkAvailability(app)
        let consent = app.buttons["candidate.aadhaar.consent"]
        reveal(consent, in: app)
        XCTAssertGreaterThanOrEqual(consent.frame.height, 44)
        XCTAssertEqual(consent.value as? String, "Unchecked")
        let verify = app.buttons["candidate.aadhaar.verify"]
        reveal(verify, in: app)
        XCTAssertFalse(verify.isEnabled)
        reveal(consent, in: app)
        consent.tap()
        reveal(verify, in: app)
        XCTAssertTrue(verify.isEnabled)
        XCTAssertGreaterThanOrEqual(verify.frame.height, 44)
        attach(app, name: "Aadhaar-Dark-AXXXL-Required-Consent")
        verify.tap()
        assertSavedVerified(app)
        assertNoPrivateData(app)
        attach(app, name: "Aadhaar-Dark-AXXXL-Verified")
    }

    @discardableResult
    private func assertAvailabilityFailure(scenario: String, message: String) -> XCUIApplication {
        let app = launch(scenario: scenario)
        openHub(app)
        let check = app.buttons["candidate.aadhaar.check"]
        reveal(check, in: app)
        XCTAssertTrue(check.isEnabled)
        check.tap()
        assertStatus(message, in: app)
        XCTAssertFalse(app.buttons["candidate.aadhaar.consent"].exists)
        XCTAssertFalse(app.buttons["candidate.aadhaar.verify"].exists)
        XCTAssertFalse(element("candidate.aadhaar.saved", in: app).exists)
        XCTAssertTrue(app.navigationBars["DigiLocker"].exists)
        assertNoPrivateData(app)
        attach(app, name: "Aadhaar-Safe-\(scenario)")
        return app
    }

    private func checkAvailability(_ app: XCUIApplication) {
        let check = app.buttons["candidate.aadhaar.check"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND isEnabled == true"), object: check)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        reveal(check, in: app)
        check.tap()
        XCTAssertTrue(app.buttons["candidate.aadhaar.consent"].waitForExistence(timeout: 10))
        assertStatus("available", in: app)
    }

    private func assertStatus(_ text: String, in app: XCUIApplication) {
        let status = app.staticTexts["candidate.aadhaar.status"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label CONTAINS[c] %@", text), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        reveal(status, in: app)
    }

    private func assertSavedVerified(_ app: XCUIApplication) {
        let saved = element("candidate.aadhaar.saved", in: app)
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label == %@", "e-Aadhaar. Verified"), object: saved)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
        reveal(saved, in: app)
    }

    private func assertNoPrivateData(_ app: XCUIApplication) {
        for marker in ["123456789012", "XXXX XXXX 9012", "PRIVATE_PHOTO", "PRIVATE_XML", "provider-private-uri",
                       "HMAC", "entitlement", "digilocker_invalid_token", "digilocker_integrity_failed", "HTTP 403", "HTTP 404", "HTTP 503"] {
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", marker)).firstMatch.exists, marker)
        }
        XCTAssertEqual(app.textFields.count, 0, "e-Aadhaar must not introduce number entry")
        XCTAssertEqual(app.secureTextFields.count, 0)
    }

    private func launch(scenario: String, largeDark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES",
                               "-kairo.appearance.preference", largeDark ? "dark" : "light"]
        if largeDark {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        // The validated UI-test dependency graph replaces every account service; no live requests.
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated",
            "KAIRO_UI_TEST_AADHAAR": scenario
        ]
        app.launch()
        return app
    }

    private func openHub(_ app: XCUIApplication) {
        let entry = app.buttons["candidate.home.digilocker"]
        reveal(entry, in: app)
        entry.tap()
        XCTAssertTrue(app.navigationBars["DigiLocker"].waitForExistence(timeout: 10))
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<35 {
            // The connection action now precedes this section. Use the actual
            // navigation/home-indicator bounds, not an arbitrary 140pt footer
            // that excludes reachable controls at the end of the scroll view.
            let navigation = app.navigationBars.firstMatch
            let top = navigation.exists ? max(app.frame.minY + 60, navigation.frame.maxY + 8) : app.frame.minY + 100
            let viewport = CGRect(x: app.frame.minX, y: top, width: app.frame.width,
                                  height: max(0, app.frame.maxY - 44 - top))
            if element.exists {
                let visibleHeight = element.frame.intersection(viewport).height
                let tapCentreVisible = element.elementType != .button || viewport.contains(
                    CGPoint(x: element.frame.midX, y: element.frame.midY))
                if visibleHeight >= min(44, element.frame.height), tapCentreVisible,
                   element.isHittable || !element.isEnabled { return }
                if element.frame.midY < viewport.minY {
                    app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
                        .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65)))
                    continue
                }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)))
        }
        XCTFail("Control is not reachable: \(element.identifier)")
    }

    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
