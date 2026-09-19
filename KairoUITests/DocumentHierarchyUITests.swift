import XCTest

/// Every route installs in-memory services. No upload, live pack or real capability is used.
@MainActor
final class DocumentHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private let first = "pack.select.vault:00000000-0000-4000-8000-000000000001"
    private let second = "pack.select.employment:00000000-0000-4000-8000-000000000002"

    func testHubPrimaryShareGroupsContextAndSecondaryNavigation() {
        let app = launch()
        let share = app.buttons["documents.shareDocuments"]
        XCTAssertTrue(share.exists); XCTAssertGreaterThanOrEqual(share.frame.height, 44)
        let employment = element("documents.group.Employment", app)
        XCTAssertTrue(employment.label.contains("1 documents"))
        XCTAssertLessThan(share.frame.minY, employment.frame.minY)
        let row = app.buttons["documents.row.Employment"]
        XCTAssertTrue(row.exists); XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        XCTAssertTrue(app.staticTexts["Synthetic Employer"].exists)
        capture(app, "4C5 Documents primary hierarchy")
        let history = app.buttons["documents.sharedPacks"]
        reveal(history, app)
        let vault = app.buttons["documents.vault"]
        reveal(vault, app)
        XCTAssertGreaterThan(vault.frame.minY, history.frame.minY)
        capture(app, "4C5 Documents secondary navigation")
    }
    func testHubFiltersPreciseVaultLabelsAndHistoricalEvidenceHasNoActions() {
        let app = launch()
        tapFilter("Verification", app)
        XCTAssertTrue(app.staticTexts["demo-historical-evidence.pdf"].exists)
        XCTAssertTrue(app.staticTexts["Historical preview unavailable in the current backend contract."].exists)
        XCTAssertFalse(app.buttons["documents.actions.demo-history"].exists)
        XCTAssertFalse(app.buttons["documents.row.demo-history"].exists)
        tapFilter("Other", app)
        XCTAssertTrue(element("documents.group.identity", app).label.contains("4 documents"))
        XCTAssertTrue(app.staticTexts["Birth Certificate"].exists)
        XCTAssertFalse(app.staticTexts["demo-historical-evidence.pdf"].exists)
        let row = app.buttons["documents.row.vault.birth"]
        reveal(row, app); XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        let menu = app.buttons["documents.actions.vault.birth"]
        reveal(menu, app); menu.tap()
        XCTAssertTrue(app.buttons["Replace"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Remove"].exists)
        // Do not choose either mutation action.
    }
    func testHubEmptyAndFailedSourcesNeverPresentPartialRowsAsComplete() {
        for state in ["empty", "error"] {
            let app = launch(state)
            XCTAssertFalse(app.buttons["documents.row.Employment"].exists)
            XCTAssertFalse(element("documents.group.identity", app).exists)
            if state == "empty" { XCTAssertTrue(app.staticTexts["documents.empty"].exists) }
            else {
                XCTAssertTrue(app.staticTexts["Documents unavailable"].exists)
                XCTAssertTrue(app.staticTexts["Some authoritative document sources could not be loaded. No partial list is presented as complete."].exists)
            }
            app.terminate()
        }
    }
    func testVaultTitlePrivacyLegacyRowsAndExactlySevenUploadChoices() {
        let app = launch(); openVault(app)
        XCTAssertTrue(app.staticTexts["Private by default"].exists)
        XCTAssertTrue(app.staticTexts["Private identity and personal documents. Uploading does not mean verified. Sharing requires your explicit selection."].exists)
        XCTAssertTrue(app.staticTexts["Birth Certificate"].exists)
        let government = app.buttons["candidate.more.documentVault.document.government"]
        reveal(government, app); XCTAssertTrue(government.label.contains("Government ID"))
        let other = app.buttons["candidate.more.documentVault.document.other"]
        reveal(other, app); XCTAssertTrue(other.label.contains("Other"))
        XCTAssertFalse(app.buttons["vault.actions.historical"].exists)
        let add = app.buttons["vault.add"]
        reveal(add, app); add.tap()
        let picker = app.buttons["candidate.more.documentVault.type"]
        reveal(picker, app); picker.tap()
        for title in ["Aadhaar", "PAN", "Passport", "Driving Licence", "Voter ID", "Birth Certificate", "Address Proof"] {
            XCTAssertTrue(app.buttons[title].exists, title)
        }
        XCTAssertFalse(app.buttons["Government ID"].exists)
        // The Documents sheet underneath retains its canonical Other filter.
        // Exclude that identified filter, not any possible upload-menu choice.
        XCTAssertEqual(app.buttons.matching(NSPredicate(
            format: "label == %@ AND identifier != %@", "Other", "documents.filter.Other"
        )).count, 0)
        app.buttons["Birth Certificate"].tap()
        capture(app, "4C5 Vault add document")
    }
    func testPackSelectionAndReviewOrderExactFilesReadOnly() {
        let app = launch(); openPack(app)
        XCTAssertEqual(app.staticTexts["pack.selectedCount"].label, "0 selected")
        XCTAssertFalse(app.buttons["pack.continue"].isEnabled)
        XCTAssertLessThan(app.staticTexts["pack.selectedCount"].frame.minY, app.buttons["pack.category"].frame.minY)
        let row = app.buttons[first]
        reveal(row, app); XCTAssertGreaterThanOrEqual(row.frame.height, 44)
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.7)).tap()
        XCTAssertEqual(row.value as? String, "Selected")
        prepareReview(app, selected: true)
        let ids = ["pack.review.purpose", "pack.review.expiry", "pack.review.count", "pack.review.snapshot", "pack.create"]
        var previous: XCUIElement?
        for id in ids {
            let next = element(id, app); reveal(next, app)
            if let previous { XCTAssertLessThan(previous.frame.minY, next.frame.minY) }
            previous = next
        }
        XCTAssertTrue(app.staticTexts["demo-birth-certificate.pdf"].exists)
        XCTAssertFalse(app.staticTexts["demo-employment-letter-with-a-long-descriptive-filename.pdf"].exists)
        capture(app, "4C5 exact selection review")
        // Stop before Create; physical QA uses the same read-only path.
    }
    func testOfflineResultAdaptiveActionsAndHistoryHasNoRecoveredCapability() {
        let app = launch(); openPack(app); prepareReview(app)
        tap("pack.create", app) // in-memory fixture only
        XCTAssertTrue(app.staticTexts["pack.ready"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["pack.ready"].label, "Share ready")
        for id in ["pack.copy", "pack.qr", "pack.share", "pack.preview"] {
            let button = app.buttons[id]; reveal(button, app)
            XCTAssertTrue(button.isEnabled); XCTAssertGreaterThanOrEqual(button.frame.height, 44)
        }
        XCTAssertEqual(app.buttons["pack.copy"].frame.minY, app.buttons["pack.qr"].frame.minY, accuracy: 2)
        XCTAssertEqual(app.buttons["pack.share"].frame.minY, app.buttons["pack.preview"].frame.minY, accuracy: 2)
        capture(app, "4C5 fixture Share ready action grid")
        tap("pack.done", app)
        tap("pack.history.00000000-0000-4000-8000-000000000004", app)
        XCTAssertEqual(app.staticTexts["pack.detail.status"].label, "Active")
        XCTAssertEqual(app.staticTexts["pack.detail.count"].label, "1 documents")
        XCTAssertFalse(app.buttons["pack.copy"].exists)
        XCTAssertFalse(app.buttons["pack.qr"].exists)
        capture(app, "4C5 compact snapshot detail")
    }
    func testLargeTypeDarkLongFilenamePurposeAndBackgroundRestore() {
        let app = launch(large: true); openPack(app)
        tap(first, app)
        XCTAssertEqual(app.buttons[first].value as? String, "Selected")
        let row = app.buttons[second]; reveal(row, app)
        XCTAssertGreaterThanOrEqual(row.frame.minX, 0)
        XCTAssertLessThanOrEqual(row.frame.maxX, app.frame.width)
        prepareReview(app, selected: true, purpose: String(repeating: "Synthetic QA ", count: 8))
        let purpose = element("pack.review.purpose", app); reveal(purpose, app)
        XCTAssertGreaterThan(purpose.frame.height, 90)
        XCTAssertLessThanOrEqual(purpose.frame.maxX, app.frame.width)
        capture(app, "4C5 large dark review")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.staticTexts["pack.review"].waitForExistence(timeout: 10))
        XCTAssertTrue(purpose.label.contains("Synthetic QA"))
        tap("pack.create", app) // in-memory fixture only, including the adaptive result
        XCTAssertTrue(app.staticTexts["pack.ready"].waitForExistence(timeout: 10))
        var previous: XCUIElement?
        for id in ["pack.copy", "pack.qr", "pack.share", "pack.preview"] {
            let action = app.buttons[id]; reveal(action, app)
            XCTAssertGreaterThanOrEqual(action.frame.height, 44)
            XCTAssertLessThanOrEqual(action.frame.maxX, app.frame.width)
            if let previous {
                XCTAssertEqual(previous.frame.minX, action.frame.minX, accuracy: 2)
                XCTAssertLessThan(previous.frame.minY, action.frame.minY)
            }
            previous = action
        }
        capture(app, "4C5 large dark one-column fixture actions")
        // No live create or recipient access.
    }

    private func launch(_ scenario: String = "populated", large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchArguments += ["-kairo.appearance.preference", large ? "dark" : "light"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_MORE_STATE": "populated",
            "KAIRO_UI_TEST_DOCUMENT_HIERARCHY": scenario]
        app.launch(); app.tabBars.buttons["More"].tap()
        tap("documentVault", app)
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))
        return app
    }
    private func openVault(_ app: XCUIApplication) {
        tap("documents.vault", app); XCTAssertTrue(app.navigationBars["Vault"].waitForExistence(timeout: 10))
    }
    private func openPack(_ app: XCUIApplication) {
        tap("documents.shareDocuments", app); XCTAssertTrue(app.navigationBars["Document packs"].waitForExistence(timeout: 10))
    }
    private func prepareReview(_ app: XCUIApplication, selected: Bool = false, purpose: String = "Synthetic selected files") {
        if !selected { tap(first, app) }
        tap("pack.continue", app)
        let field = app.textViews["pack.purpose"].exists ? app.textViews["pack.purpose"] : app.textFields["pack.purpose"]
        reveal(field, app); field.tap(); field.typeText(purpose)
        let keyboardDone = app.buttons["pack.purpose.done"]
        XCTAssertTrue(keyboardDone.waitForExistence(timeout: 5))
        keyboardDone.tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        tap("pack.continue", app); tap("pack.continue", app)
        XCTAssertTrue(app.staticTexts["pack.review"].waitForExistence(timeout: 10))
    }
    private func tapFilter(_ name: String, _ app: XCUIApplication) {
        let button = app.buttons["documents.filter.\(name)"]
        let filters = app.scrollViews["documents.filters"]
        XCTAssertTrue(filters.waitForExistence(timeout: 10))
        reveal(filters, app)
        for _ in 0..<10 { if button.isHittable { break }; filters.swipeLeft() }
        button.tap(); XCTAssertEqual(button.value as? String, "Selected")
    }
    private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    private func tap(_ id: String, _ app: XCUIApplication) { let button = app.buttons[id]; reveal(button, app); button.tap() }
    private func reveal(_ item: XCUIElement, _ app: XCUIApplication) {
        for attempt in 0..<35 {
            if item.exists && item.isHittable &&
                ((item.frame.minY > 95 && item.frame.maxY < app.frame.height - 35) || item.frame.height > app.frame.height - 240) { return }
            let above = (item.exists && item.frame.minY <= 95) || (!item.exists && attempt >= 15)
            let keyboard = app.keyboards.firstMatch
            let bottom = keyboard.exists ? keyboard.frame.minY / app.frame.height - 0.04 : 0.72
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: above ? 0.30 : bottom))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: above ? bottom : 0.30)))
        }
        XCTAssertTrue(item.exists); XCTAssertTrue(item.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
