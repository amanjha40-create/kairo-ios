import XCTest

/// These routes inject the existing in-memory services. No live share or capability is used.
@MainActor
final class PassportHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOwnerTrustShareDisclosureRecordAndExportOrder() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Aarav Mehta"].exists)
        let scoreDetails = app.buttons["View score details"]
        reveal(scoreDetails, app)
        XCTAssertGreaterThanOrEqual(scoreDetails.frame.height, 44)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.passport.share").count, 1)
        let disclosure = app.buttons["passport.trustSignals.disclosure"]
        reveal(disclosure, app); XCTAssertEqual(disclosure.value as? String, "Collapsed"); disclosure.tap()
        let ids = ["candidate.passport.trustScore", "candidate.passport.share", "candidate.passport.strength", "passport.summary.verified",
            "passport.summary.candidateProvided",
            "candidate.passport.careerDetails", "candidate.passport.viewCareer",
            "candidate.passport.identity", "candidate.passport.download",
            "candidate.passport.share.activity.entry"]
        var previous: XCUIElement?
        for id in ids {
            let item = element(id, app)
            reveal(item, app)
            if let previous { XCTAssertLessThan(previous.frame.minY, item.frame.minY, id) }
            previous = item
        }
        for removedSection in ["employment", "education", "certifications", "skills", "projects", "portfolio"] {
            XCTAssertFalse(element("candidate.passport.\(removedSection)", app).exists)
        }
        XCTAssertTrue(app.staticTexts["Evidence and status behind your Passport. Self-declared information is not verification."].exists)
        capture(app, "4C4 owner export and activity")
    }

    func testModeSectionsPurposeReviewOrderAndDefaultPrivacy() {
        let app = launch(); openCreate(app)
        XCTAssertEqual(app.switches["passport.share.mixedOptIn"].value as? String, "0")
        XCTAssertTrue(app.staticTexts["Verified only"].exists)
        XCTAssertFalse(app.switches["candidate.passport.share.permission.profile"].exists)
        XCTAssertFalse(app.staticTexts["Legacy sharing policy"].exists)
        var previous: XCUIElement?
        for title in ["1. Sharing mode", "2. Choose what to share", "3. Purpose & expiry", "4. Review"] {
            let heading = app.staticTexts[title]
            reveal(heading, app)
            if let previous { XCTAssertLessThan(previous.frame.minY, heading.frame.minY) }
            previous = heading
        }
        XCTAssertFalse(app.buttons["candidate.passport.share.create"].isEnabled)
        XCTAssertFalse(element("passport.share.preview", app).exists)
        XCTAssertTrue(element("passport.share.review.profile", app).label.contains("Not shared"))
        XCTAssertTrue(element("passport.share.review.photo", app).label.contains("Not shared"))
        XCTAssertTrue(element("passport.share.review.trustScore", app).label.contains("Not shared"))
        capture(app, "4C4 default review")
    }

    func testActivityShowsModeDatesAndAuthoritativeCountsWithoutRecipientActions() {
        let app = launch()
        capture(app, "4C4 owner identity and Trust Score")
        reveal(app.buttons["candidate.passport.share"], app)
        capture(app, "4C4 owner Share and disclosure summaries")
        let activity = app.buttons["candidate.passport.share.activity.entry"]
        reveal(activity, app); activity.tap()
        XCTAssertTrue(app.navigationBars["Share Activity"].waitForExistence(timeout: 10))
        let row = element("candidate.passport.share.activity.row.demo-share-1", app)
        reveal(row, app)
        for value in ["Recruiter preview", "Legacy sharing policy", "Active", "0 total views", "0 unique views", "created", "Expires"] {
            XCTAssertTrue(row.label.contains(value), value)
        }
        XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        capture(app, "4C4 compact activity")
        row.tap()
        XCTAssertTrue(element("candidate.passport.share.detail", app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["candidate.passport.share.copyLink"].exists)
        XCTAssertFalse(element("passport.share.preview", app).exists)
        XCTAssertFalse(app.buttons["candidate.passport.share.qrCode"].exists)
    }

    func testMixedOptInReviewExactSectionsAndDependentPhotoClearing() {
        let app = launch(); openCreate(app)
        app.switches["passport.share.mixedOptIn"].tap()
        for key in ["certifications", "profile", "photo"] {
            let option = app.switches["candidate.passport.share.permission.\(key)"]
            reveal(option, app); option.tap()
        }
        let profile = app.switches["candidate.passport.share.permission.profile"]
        reveal(profile, app); profile.tap()
        XCTAssertEqual(app.switches["candidate.passport.share.permission.photo"].value as? String, "0")
        enterPurpose("  Synthetic recipient review  ", app)
        let review = element("passport.share.review.mode", app)
        reveal(review, app)
        XCTAssertTrue(review.label.contains("Verified + Candidate-provided"))
        XCTAssertTrue(element("passport.share.review.purpose", app).label.contains("Synthetic recipient review"))
        let sections = element("passport.share.review.sections", app)
        XCTAssertTrue(sections.label.contains("Certifications"))
        XCTAssertFalse(sections.label.contains("Employment"))
        XCTAssertFalse(sections.label.contains("Education"))
        XCTAssertTrue(element("passport.share.review.photo", app).label.contains("Not shared"))
        let create = app.buttons["candidate.passport.share.create"]
        reveal(create, app); XCTAssertTrue(create.isEnabled)
        // Deliberately stop before Create; suitable for physical read-only QA too.
        capture(app, "4C4 explicit mixed review")
    }

    func testFixtureOnlyResultActionsAndHistoryNeverReconstructURL() {
        let app = launch(); openCreate(app)
        enterPurpose("Fixture-only Passport hierarchy", app)
        let create = app.buttons["candidate.passport.share.create"]
        reveal(create, app); XCTAssertTrue(create.isEnabled); create.tap()
        XCTAssertTrue(app.navigationBars["Share ready"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["5. Share ready"].exists)
        XCTAssertTrue(app.staticTexts["https://demo.kairoid.invalid/passport/demo-share-2"].exists)
        for id in ["copyLink", "nativeShare", "qrCode"] {
            let button = app.buttons["candidate.passport.share.\(id)"]
            reveal(button, app)
            XCTAssertTrue(button.isEnabled)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        app.buttons["candidate.passport.share.qrCode"].tap()
        XCTAssertTrue(app.navigationBars["Passport QR code"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.images["QR code for the public Passport URL"].exists)
        app.navigationBars["Passport QR code"].buttons["Done"].tap()
        let preview = element("passport.share.preview", app)
        reveal(preview, app); XCTAssertTrue(preview.isEnabled)
        // Do not open the recipient or invoke an external Share destination.
        let done = app.buttons["candidate.passport.share.manage"]
        reveal(done, app); XCTAssertEqual(done.label, "Done"); done.tap()
        let row = element("candidate.passport.share.row.demo-share-2", app)
        reveal(row, app); XCTAssertTrue(row.label.contains("Verified only")); row.tap()
        XCTAssertFalse(app.buttons["candidate.passport.share.copyLink"].exists)
        XCTAssertFalse(app.buttons["candidate.passport.share.qrCode"].exists)
    }

    func testOwnerEmptyLoadingErrorDoNotInventScoreOrShare() {
        for state in ["empty", "loading", "error"] {
            let app = launch(state: state)
            XCTAssertFalse(app.buttons["candidate.passport.share"].exists)
            XCTAssertFalse(element("passport.summary.verified", app).exists)
            XCTAssertFalse(element("candidate.passport.trustScore", app).exists)
            app.terminate()
        }
    }

    func testLargeTypeDarkLongPurposeSafeAreaAndBackgroundRestoreReadOnly() {
        let app = launch(large: true)
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app)
        XCTAssertGreaterThanOrEqual(share.frame.height, 44)
        // The system status bar is not part of the app's XCUITest hierarchy on iOS 27.
        XCTAssertGreaterThan(share.frame.minY, 95)
        capture(app, "4C4 accessible dark owner")
        share.tap(); app.buttons["candidate.passport.share.createEntry"].tap()
        enterPurpose(String(repeating: "Long purpose ", count: 9), app)
        let purpose = element("passport.share.review.purpose", app)
        reveal(purpose, app)
        XCTAssertGreaterThan(purpose.frame.height, 90)
        XCTAssertGreaterThanOrEqual(purpose.frame.minX, 0)
        XCTAssertLessThanOrEqual(purpose.frame.maxX, app.frame.maxX)
        capture(app, "4C4 accessible review")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.navigationBars["Create share"].waitForExistence(timeout: 10))
        XCTAssertTrue(purpose.label.contains("Long purpose"))
        XCTAssertFalse(app.buttons["candidate.passport.share.copyLink"].exists)
    }

    private func launch(state: String = "populated", large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": state]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Passport"].waitForExistence(timeout: 10))
        if large {
            app.tabBars.buttons["More"].tap()
            let settings = app.buttons["candidate.more.settings"]
            reveal(settings, app); settings.tap()
            let dark = app.buttons["candidate.more.appearance.dark"]
            reveal(dark, app); dark.tap()
        }
        app.tabBars.buttons["Passport"].tap()
        return app
    }
    private func openCreate(_ app: XCUIApplication) {
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app); share.tap()
        let create = app.buttons["candidate.passport.share.createEntry"]
        XCTAssertTrue(create.waitForExistence(timeout: 10)); create.tap()
        XCTAssertTrue(app.switches["passport.share.mixedOptIn"].waitForExistence(timeout: 10))
    }
    private func enterPurpose(_ text: String, _ app: XCUIApplication) {
        let field = app.textFields["candidate.passport.share.label"]
        reveal(field, app); field.tap(); field.typeText(text + "\n")
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<35 {
            let tabBar = app.tabBars.firstMatch
            let bottom = tabBar.exists && tabBar.isHittable ? tabBar.frame.minY : app.frame.height - 20
            if element.exists && element.isHittable && element.frame.minY > 95 &&
                (element.frame.maxY < bottom || (element.frame.height > app.frame.height - 200 && element.frame.minY < 230)) { return }
            let earlier = element.exists && element.frame.minY <= 95
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.35 : 0.70))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.70 : 0.35)))
        }
        if !element.exists || !element.isHittable {
            let diagnostic = XCTAttachment(string: app.debugDescription)
            diagnostic.name = "Fixture-only Passport navigation hierarchy"
            diagnostic.lifetime = .keepAlways
            add(diagnostic)
        }
        XCTAssertTrue(element.exists); XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = name; image.lifetime = .keepAlways; add(image)
    }
}
