import XCTest

@MainActor
final class MoreSettingsHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

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
        for _ in 0..<40 {
            let viewport = CGRect(x: 0, y: 110, width: app.frame.width, height: app.frame.height - 205)
            if row.exists && row.isHittable && row.frame.intersection(viewport).height >= min(44, row.frame.height) { return }
            let down = row.exists && row.frame.minY <= 110
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.72))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.68 : 0.38)))
        }
        XCTFail("Could not reveal \(row.identifier)")
    }
    private func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
