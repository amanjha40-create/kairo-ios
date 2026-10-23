import XCTest

@MainActor
final class VerifyFocusedNavigationUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testPlainConsentCopyKeepsBothExplicitRequirementsWithoutSubmitting() {
        let app = launch()
        app.openCareerVerification()
        XCTAssertTrue(app.buttons["fixture.verify.begin"].waitForExistence(timeout: 10))
        app.buttons["fixture.verify.begin"].tap()
        let consent = app.switches["Share selected record details"]
        reveal(consent, app)
        XCTAssertEqual(consent.value as? String, "0")
        let documents = app.switches["Share selected documents"]
        reveal(documents, app); XCTAssertEqual(documents.value as? String, "0")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label == %@",
            "KairoID will share only the details and documents you selected with the verifier. This does not automatically verify your record.")).firstMatch.exists)
        let submit = app.buttons["Send verification request"]
        reveal(submit, app); XCTAssertFalse(submit.isEnabled)
        reveal(consent, app); consent.tap()
        reveal(submit, app); XCTAssertFalse(submit.isEnabled)
        let proof = XCTAttachment(screenshot: app.screenshot())
        proof.name = "Plain consent retains explicit requirements"; proof.lifetime = .keepAlways; add(proof)
        app.terminate() // No submit or provider call.
    }

    func testNewRequestSurvivesSheetDismissalAndStaleWithdrawnHistory() {
        let app = launch()
        prepareAndOpenNewRequest(app)
        XCTAssertEqual(app.staticTexts["fixture.verify.pending"].label, "fixture-new-1")
        XCTAssertFalse(app.navigationBars["Request detail"].exists)
        XCTAssertFalse(app.alerts["Request no longer available"].exists)
        XCTAssertTrue(app.buttons["candidate.verify.request.action.fixture-withdrawn"].exists)
        app.buttons["fixture.verify.release"].tap()
        let detail = app.otherElements["candidate.verify.requestDetail"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertEqual(detail.value as? String, "fixture-new-1")
        XCTAssertTrue(app.staticTexts["Pending KairoID Review"].firstMatch.exists)
        XCTAssertEqual(app.staticTexts["fixture.verify.pending"].label, "none")
    }

    func testAuthoritativelyUnavailableClearsFocusWithoutOpeningOldHistory() {
        let app = launch(missing: true)
        prepareAndOpenNewRequest(app)
        XCTAssertEqual(app.staticTexts["fixture.verify.pending"].label, "fixture-new-1")
        XCTAssertFalse(app.alerts["Request no longer available"].exists)
        app.buttons["fixture.verify.release"].tap()
        let error = app.alerts["Request no longer available"]
        XCTAssertTrue(error.waitForExistence(timeout: 10))
        error.buttons["OK"].tap()
        XCTAssertFalse(app.navigationBars["Request detail"].exists)
        XCTAssertEqual(app.staticTexts["fixture.verify.pending"].label, "none")
        XCTAssertTrue(app.buttons["candidate.verify.request.action.fixture-withdrawn"].exists)
        XCTAssertTrue(app.staticTexts["Withdrawn"].exists)
    }

    private func prepareAndOpenNewRequest(_ app: XCUIApplication) {
        app.openCareerVerification()
        XCTAssertTrue(app.buttons["candidate.verify.request.action.fixture-withdrawn"].waitForExistence(timeout: 10))
        app.buttons["fixture.verify.begin"].tap()
        let evidence = app.staticTexts["synthetic-navigation.pdf"]
        XCTAssertTrue(evidence.waitForExistence(timeout: 10))
        reveal(evidence, app); evidence.tap()
        let secondEvidence = app.staticTexts["synthetic-navigation-2.pdf"]
        reveal(secondEvidence, app); secondEvidence.tap()
        let email = app.textFields["hr@organisation.com"]
        reveal(email, app); email.tap(); email.typeText("qa@example.com\n")
        XCTAssertEqual(email.value as? String, "qa@example.com")
        for label in ["Share selected record details", "Share selected documents"] {
            let consent = app.switches[label]
            reveal(consent, app)
            if (consent.value as? String) == "0" { consent.tap() }
            XCTAssertEqual(consent.value as? String, "1")
        }
        let submit = app.buttons["Send verification request"]
        reveal(submit, app)
        if !submit.isEnabled {
            let snapshot = XCTAttachment(screenshot: app.screenshot())
            snapshot.name = "Isolated synthetic navigation form"
            snapshot.lifetime = .keepAlways
            add(snapshot)
        }
        XCTAssertTrue(submit.isEnabled); submit.tap()
        let view = app.buttons["candidate.verificationInitiation.viewRequest"]
        XCTAssertTrue(view.waitForExistence(timeout: 10)); view.tap()
        XCTAssertTrue(app.buttons["fixture.verify.release"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.navigationBars["Start verification"].waitForNonExistence(timeout: 10))
    }

    private func launch(missing: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
#if KAIRO_LOCAL_BATCH1_QA
        app.launchArguments += ["-KAIRO_LOCAL_BATCH1_QA"]
#endif
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_VERIFY_STATE": "populated",
            "KAIRO_UI_TEST_HOME_STATE": "populated", "KAIRO_UI_TEST_VERIFY_NAVIGATION": "1",
            "KAIRO_UI_TEST_CAREER_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_MISSING": missing ? "1" : "0"]
        app.launch(); return app
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<18 {
            let bottom = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch.frame.minY : app.frame.height - 65
            if element.exists && element.isHittable && element.frame.midY > 120 && element.frame.midY < bottom { return }
            let earlier = element.exists && element.frame.midY < 140
            let available = max(200, bottom - 140)
            let startY = 140 + available * (earlier ? 0.3 : 0.8)
            let endY = 140 + available * (earlier ? 0.8 : 0.3)
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.frame.width * 0.5, dy: startY))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: app.frame.width * 0.5, dy: endY)))
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
}
