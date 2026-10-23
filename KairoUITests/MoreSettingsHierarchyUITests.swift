import XCTest

@MainActor
final class MoreSettingsHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

#if !targetEnvironment(simulator)
    func testPhysicalLogoutVoiceOverReadsMessageCancelThenDestructiveAction() throws {
        guard #available(iOS 27.0, *) else { return XCTFail("Physical speech check requires iOS 27") }
        let voiceOver = XCUIDevice.shared.voiceOverService
        let initial = voiceOver.isEnabled
        defer {
            if initial { XCTAssertNoThrow(try voiceOver.enable()) }
            else { XCTAssertNoThrow(try voiceOver.disable()) }
        }
        try voiceOver.disable()
        let app = launch()
        let entry = app.buttons["candidate.more.signOut"]
        reveal(entry, app); entry.tap()
        XCTAssertTrue(app.buttons["more.logout.cancel"].waitForExistence(timeout: 10))
        try voiceOver.enable()
        var utterances = [(try voiceOver.currentSpeech()).utterance]
        for _ in 0..<20 {
            utterances.append((try voiceOver.moveForward()).utterance)
            if let cancel = utterances.firstIndex(where: { $0.contains("Cancel") }),
               utterances.dropFirst(cancel + 1).contains(where: { $0.contains("Log out") }) { break }
        }
        let message = try XCTUnwrap(utterances.firstIndex { $0.contains("logged out on this device") })
        let cancel = try XCTUnwrap(utterances.firstIndex { $0.contains("Cancel") })
        let action = try XCTUnwrap(utterances.indices.first { $0 > cancel && utterances[$0].contains("Log out") })
        XCTAssertLessThan(message, cancel)
        XCTAssertLessThan(cancel, action)
        try voiceOver.disable()
        app.buttons["more.logout.cancel"].tap()
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
        app.terminate() // Synthetic sheet only; never activate Log out.
    }
#endif

    func testCompactLogoutLightDarkAndAccessibleCancelPreservesSession() {
        for large in [false, true] {
            let app = launch(large: large)
            let entry = app.buttons["candidate.more.signOut"]
            reveal(entry, app); entry.tap()
            let cancel = app.buttons["more.logout.cancel"]
            XCTAssertTrue(cancel.waitForExistence(timeout: 10))
            let message = app.staticTexts["more.logout.message"]
            let confirm = app.buttons["more.logout.confirm"]
            if !large {
                XCTAssertGreaterThan(app.navigationBars["Log out"].frame.minY, app.frame.height * 0.35)
            }
            reveal(confirm, app)
            XCTAssertGreaterThanOrEqual(confirm.frame.height, 44)
            XCTAssertTrue(cancel.isHittable)
            XCTAssertLessThan(message.frame.minY, cancel.frame.minY)
            XCTAssertLessThan(cancel.frame.minY, confirm.frame.minY)
            XCTAssertEqual(app.keyboards.count, 0)
            capture("Logout \(large ? "dark XXXL" : "compact light")")
            cancel.tap()
            XCTAssertTrue(app.buttons["candidate.more.viewProfile"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
            app.terminate() // Never confirm a real logout.
        }
    }

    func testPermanentAddressVisibleOpensAndReturnsWithoutDuplicateEntry() {
        let app = launch(variant: "address_no_address")
        let entry = app.buttons["candidate.more.permanentAddress"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.more.permanentAddress").count, 1)
        XCTAssertEqual(app.tabBars.buttons.count, 4)
        XCTAssertTrue(app.buttons["candidate.more.viewProfile"].exists)
        XCTAssertTrue(app.buttons["candidate.more.settings"].exists)
        entry.tap()
        XCTAssertTrue(app.navigationBars["Permanent address"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add permanent address"].waitForExistence(timeout: 10))
        app.navigationBars.buttons["Done"].tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
        app.buttons["candidate.more.viewProfile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["address.entry"].exists)
        app.navigationBars.buttons["Done"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.more.permanentAddress").count, 1)
    }

    func testPermanentAddressNavigationSurvivesDisabledAndFailedStatus() {
        for variant in ["address_feature_off", "address_offline"] {
            let app = launch(variant: variant)
            let entry = app.buttons["candidate.more.permanentAddress"]
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
            entry.tap()
            XCTAssertTrue(app.navigationBars["Permanent address"].waitForExistence(timeout: 10))
            if variant == "address_feature_off" {
                XCTAssertTrue(app.staticTexts["Address verification is not available yet."].waitForExistence(timeout: 10))
            } else {
                XCTAssertTrue(app.staticTexts["address.error"].waitForExistence(timeout: 10))
            }
            XCTAssertFalse(app.buttons["address.location.start"].exists)
            XCTAssertFalse(app.buttons["Add permanent address"].exists)
            app.navigationBars.buttons["Done"].tap()
            XCTAssertTrue(entry.waitForExistence(timeout: 10))
        }
    }

    func testMoreIsCompactRoutingHubWithNoDestructiveOrPreferenceControls() {
        let app = launch()
        let profile = app.buttons["candidate.more.viewProfile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(profile.frame.height, 44)
        XCTAssertFalse(app.buttons["candidate.more.deleteAccount"].exists)
        XCTAssertFalse(app.switches["candidate.more.notifications.productUpdates"].exists)
        let ids = ["candidate.more.settings", "candidate.more.digilocker", "notifications", "documentVault", "candidate.more.resume", "candidate.more.helpCentre", "candidate.more.signOut"]
        var previousY = profile.frame.minY
        for id in ids {
            let row = app.buttons[id]
            XCTAssertTrue(row.exists)
            XCTAssertGreaterThan(row.frame.minY, previousY)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
            previousY = row.frame.minY
        }
        capture("More compact hierarchy")
        profile.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 10))
    }

    func testSettingsSectionsAndBottomOnlyDeletion() {
        let app = launch()
        open("settings", app)
        let ids = ["candidate.more.account", "candidate.more.security", "candidate.more.preferences",
                   "candidate.more.privacyData", "settings.support", "settings.legal", "candidate.more.dangerZone"]
        for id in ids { reveal(app.staticTexts[id], app) }
        let deletion = app.buttons["candidate.more.deleteAccount"]
        reveal(deletion, app)
        XCTAssertGreaterThanOrEqual(deletion.frame.height, 44)
        XCTAssertTrue(deletion.label.contains("Delete account"))
        XCTAssertFalse(app.buttons["candidate.more.signOut"].exists)
        capture("Settings bottom destructive section")
        back(app)
        XCTAssertTrue(app.buttons["candidate.more.settings"].exists)
    }

    func testSupportAndLegalReuseDestinationsWithNativeBack() {
        let app = launch()
        let help = app.buttons["candidate.more.helpCentre"]
        reveal(help, app)
        help.tap()
        XCTAssertTrue(app.navigationBars["Help Center"].waitForExistence(timeout: 10))
        back(app)
        open("settings", app)
        open("support", app)
        XCTAssertTrue(app.navigationBars["Support"].waitForExistence(timeout: 10))
        back(app)
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        open("legal", app)
        XCTAssertTrue(app.buttons["candidate.more.privacyPolicy"].waitForExistence(timeout: 10))
        back(app)
        XCTAssertTrue(app.navigationBars["Settings"].exists)
    }

    func testDocumentsAndSessionPreservingBackgroundReopen() {
        let app = launch()
        let documents = app.buttons["documentVault"]
        reveal(documents, app); documents.tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        open("settings", app)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["More"].isSelected)
        back(app)
        XCTAssertTrue(app.buttons["candidate.more.viewProfile"].exists)
    }

    func testLargeTextDarkMoreAndSettingsReadOnly() {
        let app = launch(large: true)
        for id in ["candidate.more.viewProfile", "candidate.more.settings", "candidate.more.digilocker", "documentVault", "candidate.more.resume", "candidate.more.helpCentre", "candidate.more.signOut"] {
            let row = app.buttons[id]; reveal(row, app)
            XCTAssertGreaterThanOrEqual(row.frame.height, 44)
            XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.maxX)
        }
        capture("More dark accessibility text")
        open("settings", app)
        reveal(app.staticTexts["candidate.more.security"], app)
        capture("Settings dark accessibility text")
        reveal(app.staticTexts["candidate.more.dangerZone"], app)
        XCTAssertTrue(app.buttons["candidate.more.deleteAccount"].exists)
        capture("Danger zone dark accessibility text")
        back(app)
    }

    func testLongAccountFixtureAndMissingMetadataRemainUsable() {
        var app = launch(large: true, variant: "long")
        let profile = app.buttons["candidate.more.viewProfile"]
        XCTAssertTrue(profile.label.contains("Personal information"))
        XCTAssertLessThanOrEqual(profile.frame.maxX, app.frame.maxX)
        capture("Long account label")
        app.terminate()
        app = launch(variant: "minimal")
        XCTAssertTrue(app.buttons["candidate.more.viewProfile"].exists)
        open("settings", app)
        reveal(app.staticTexts["No notification preferences available"], app)
        XCTAssertFalse(app.switches["candidate.more.notifications.productUpdates"].exists)
    }

    func testDeletionConfirmationCancellationAndSingleConfirmedHandlerFixtureOnly() {
        let app = launch(variant: "deletion")
        app.buttons["Open deletion confirmation"].tap()
        let submit = app.buttons["candidate.more.deleteAccount.finalButton"]
        reveal(submit, app)
        XCTAssertFalse(submit.isEnabled)
        app.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["settings.fixture.deletionCalls"].label, "Deletion handler calls: 0")
        app.buttons["Open deletion confirmation"].tap()
        let confirm = app.textFields["candidate.more.deleteAccount.confirmationInput"]
        reveal(confirm, app); confirm.tap(); confirm.typeText("DELETE")
        XCTAssertEqual(confirm.value as? String, "DELETE")
        // Scroll the form, not the software keyboard. Keyboard return/Done is
        // a submit action, not a safe way to dismiss it before testing the CTA.
        for _ in 0..<12 {
            let keyboardVisible = app.keyboards.firstMatch.exists
            let keyboardTop = keyboardVisible ? app.keyboards.firstMatch.frame.minY : app.frame.maxY
            // The native Passwords accessory sits above the reported keyboard
            // frame. Keep the drag and CTA clear of that non-scrollable strip.
            let bottom = keyboardTop - (keyboardVisible ? 100 : 30)
            if submit.exists && submit.isHittable && submit.frame.maxY < bottom { break }
            let top = app.navigationBars["Delete account"].frame.maxY + 30
            XCTAssertGreaterThan(bottom, top)
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 24, dy: bottom))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: 24, dy: top)))
        }
        XCTAssertTrue(submit.isHittable)
        XCTAssertTrue(submit.isEnabled)
        submit.tap()
        XCTAssertTrue(app.staticTexts["settings.fixture.deletionCalls"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["settings.fixture.deletionCalls"].label, "Deletion handler calls: 1")
    }

    private func launch(large: Bool = false, variant: String = "") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", large ? "dark" : "light"]
#if KAIRO_LOCAL_BATCH1_QA
        app.launchArguments += ["-KAIRO_LOCAL_BATCH1_QA"]
#endif
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "false", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        app.launchEnvironment["KAIRO_UI_TEST_SETTINGS_VARIANT"] = variant
        app.launch(); app.tabBars.buttons["More"].tap()
        return app
    }

    private func open(_ name: String, _ app: XCUIApplication) {
        let row = app.buttons["candidate.more.\(name)"]; reveal(row, app); row.tap()
        XCTAssertTrue(app.navigationBars[name.capitalized].waitForExistence(timeout: 10))
    }
    private func back(_ app: XCUIApplication) { app.navigationBars.buttons.firstMatch.tap() }
    private func reveal(_ row: XCUIElement, _ app: XCUIApplication) {
        app.revealContent(row)
    }
    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
