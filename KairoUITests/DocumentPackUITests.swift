import XCTest

@MainActor
final class DocumentPackUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    private let first = "pack.select.vault:00000000-0000-4000-8000-000000000001"
    private let second = "pack.select.employment:00000000-0000-4000-8000-000000000002"

    func testEntryZeroSelectionMultiSelectDeselectAndClear() {
        let app = launch()
        XCTAssertFalse(app.buttons["pack.continue"].isEnabled)
        tap(first, app); tap(second, app)
        XCTAssertEqual(app.staticTexts["pack.selectedCount"].label, "2 selected")
        tap(first, app)
        XCTAssertEqual(app.staticTexts["pack.selectedCount"].label, "1 selected")
        tap("pack.clear", app)
        XCTAssertEqual(app.staticTexts["pack.selectedCount"].label, "0 selected")
        XCTAssertFalse(app.buttons["pack.continue"].isEnabled)
    }
    func testCategoryFilteringDoesNotBroadenSelection() {
        let app = launch(); tap(first, app)
        tap("pack.category", app); app.buttons["Employment"].tap()
        XCTAssertTrue(app.buttons[second].exists); XCTAssertFalse(app.buttons[first].exists)
        XCTAssertEqual(app.staticTexts["pack.selectedCount"].label, "1 selected")
    }
    func testPurposeMandatoryLimitAndExpiryDefaultOptions() {
        let app = launch(); tap(first, app); tap("pack.continue", app)
        XCTAssertFalse(app.buttons["pack.continue"].isEnabled)
        let purpose = app.textViews["pack.purpose"].exists ? app.textViews["pack.purpose"] : app.textFields["pack.purpose"]
        XCTAssertTrue(purpose.waitForExistence(timeout: 5)); purpose.tap(); purpose.typeText(String(repeating: "a", count: 121))
        XCTAssertTrue(app.staticTexts["pack.purpose.invalid"].exists)
        XCTAssertFalse(app.buttons["pack.continue"].isEnabled)
    }
    func testReviewUsesExactOneFileAndChosenExpiry() {
        let app = launch(); prepareReview(app, days: 3)
        XCTAssertTrue(app.staticTexts["pack.review"].exists)
        XCTAssertTrue(app.staticTexts["demo-birth-certificate.pdf"].exists)
        XCTAssertFalse(app.staticTexts["demo-employment-letter-with-a-long-descriptive-filename.pdf"].exists)
        XCTAssertTrue(app.staticTexts["Expires in 3 days"].exists)
        XCTAssertTrue(app.buttons["pack.create"].isEnabled)
    }
    func testCreateReadyCopyQRRecipientAndDone() {
        let app = launch(); prepareReview(app); tap("pack.create", app)
        XCTAssertTrue(app.staticTexts["pack.ready"].waitForExistence(timeout: 10))
        tap("pack.copy", app); XCTAssertEqual(app.buttons["pack.copy"].label, "Copied")
        tap("pack.qr", app); XCTAssertTrue(app.navigationBars["Document Pack QR"].waitForExistence(timeout: 5))
        app.navigationBars["Document Pack QR"].buttons["Done"].tap()
        tap("pack.preview", app); XCTAssertTrue(app.navigationBars["Shared documents"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["demo-birth-certificate.pdf"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["demo-employment-letter-with-a-long-descriptive-filename.pdf"].exists)
        app.navigationBars["Shared documents"].buttons["Done"].tap()
        tap("pack.done", app)
        XCTAssertTrue(app.buttons["pack.history.00000000-0000-4000-8000-000000000004"].waitForExistence(timeout: 5))
    }
    func testNativeShareLaunchAndCancelPreservesResult() {
        let app = launch(); prepareReview(app); tap("pack.create", app)
        XCTAssertTrue(app.staticTexts["pack.ready"].waitForExistence(timeout: 10))
        tap("pack.share", app)
        let activity = app.otherElements["ActivityListView"].firstMatch
        XCTAssertTrue(activity.waitForExistence(timeout: 8))
        let popover = app.popovers.containing(.other, identifier: "ActivityListView").firstMatch
        let dismissRegion = app.otherElements["PopoverDismissRegion"].firstMatch
        let nativeSheet = app.sheets.containing(.other, identifier: "ActivityListView").firstMatch
        let container = nativeSheet.exists ? nativeSheet : activity
        let dismissButtons = container.buttons.matching(
            NSPredicate(format: "label IN %@", ["Close", "Cancel"])
        )
        let dismissReady = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                (popover.exists && dismissRegion.exists && dismissRegion.isHittable)
                    || dismissButtons.allElementsBoundByIndex.contains(where: \.isHittable)
            }, object: nil
        )
        XCTAssertEqual(XCTWaiter.wait(for: [dismissReady], timeout: 8), .completed)
        if popover.exists && dismissRegion.exists && dismissRegion.isHittable {
            dismissRegion.tap()
            XCTAssertTrue(popover.waitForNonExistence(timeout: 5))
        } else if let dismiss = dismissButtons.allElementsBoundByIndex.first(where: \.isHittable) {
            dismiss.tap()
        } else {
            XCTFail("Native Share has no supported dismissal control")
            return
        }
        XCTAssertTrue(activity.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pack.ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Document packs"].exists)
    }
    func testRejectedCreateThenExplicitRetry() {
        let app = launch("create-rejected"); prepareReview(app); tap("pack.create", app)
        XCTAssertTrue(app.staticTexts["pack.error"].waitForExistence(timeout: 5)); XCTAssertTrue(app.buttons["pack.create"].isEnabled)
        tap("pack.create", app); XCTAssertTrue(app.staticTexts["pack.ready"].waitForExistence(timeout: 10))
    }
    func testAmbiguousCreateBlocksRetryAndOffersHistory() {
        let app = launch("create-ambiguous"); prepareReview(app); tap("pack.create", app)
        XCTAssertTrue(app.staticTexts["pack.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pack.create"].isEnabled)
        tap("pack.checkHistory", app)
        XCTAssertTrue(app.buttons["pack.history.00000000-0000-4000-8000-000000000001"].waitForExistence(timeout: 5))
    }
    func testHistoryDetailAnalyticsRevokeCancelConfirmAndSourcePreserved() {
        let app = launch(history: true)
        tap("pack.history.00000000-0000-4000-8000-000000000001", app)
        XCTAssertTrue(app.staticTexts["pack.detail.status"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["pack.detail.status"].label, "Active")
        XCTAssertEqual(app.staticTexts["pack.detail.count"].label, "2 documents")
        XCTAssertEqual(app.staticTexts["pack.detail.analytics"].label, "2 views")
        XCTAssertFalse(app.buttons["pack.copy"].exists)
        tap("pack.revoke", app); XCTAssertTrue(app.alerts.buttons["Cancel"].waitForExistence(timeout: 5)); app.alerts.buttons["Cancel"].tap()
        XCTAssertEqual(app.staticTexts["pack.detail.status"].label, "Active")
        tap("pack.revoke", app); app.alerts.buttons["Revoke access"].tap()
        let revoked = NSPredicate(format: "label == %@", "Revoked")
        expectation(for: revoked, evaluatedWith: app.staticTexts["pack.detail.status"])
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.buttons["pack.revoke"].exists)
        XCTAssertTrue(app.staticTexts["demo-birth-certificate.pdf"].exists)
    }
    func testExpiredAndRevokedHistoryHaveNoRecipientActions() {
        let app = launch(history: true)
        for (id, title) in [("00000000-0000-4000-8000-000000000002", "Expired"), ("00000000-0000-4000-8000-000000000003", "Revoked")] {
            tap("pack.history." + id, app)
            XCTAssertTrue(app.staticTexts["pack.detail.status"].waitForExistence(timeout: 5))
            XCTAssertEqual(app.staticTexts["pack.detail.status"].label, title)
            XCTAssertFalse(app.buttons["pack.copy"].exists); XCTAssertFalse(app.buttons["pack.revoke"].exists)
            app.navigationBars["Pack detail"].buttons.element(boundBy: 0).tap()
        }
    }
    func testEmptyDocumentsAndHistory() {
        let app = launch("empty")
        XCTAssertTrue(app.staticTexts["pack.documents.empty"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["pack.continue"].isEnabled)
        app.segmentedControls.buttons["Shared document packs"].tap()
        XCTAssertTrue(app.staticTexts["pack.history.empty"].waitForExistence(timeout: 5))
    }
    func testHistoryFailureRetryAndLoading() {
        let app = launch("error", history: true)
        XCTAssertTrue(app.buttons["pack.history.retry"].waitForExistence(timeout: 5)); tap("pack.history.retry", app)
        XCTAssertTrue(app.buttons["pack.history.00000000-0000-4000-8000-000000000001"].waitForExistence(timeout: 5))
    }
    func testSelectionLoadingAndErrorRetry() {
        let app = launch("error")
        XCTAssertTrue(app.buttons["pack.documents.retry"].waitForExistence(timeout: 5)); tap("pack.documents.retry", app)
        XCTAssertTrue(app.buttons[first].waitForExistence(timeout: 5))
    }
    func testAccessibilityLargeTypeLongNamesAndBackgroundRestore() {
        let app = launch("loading", largeType: true)
        XCTAssertTrue(app.buttons[first].waitForExistence(timeout: 10)); tap(first, app)
        XCTAssertEqual(app.buttons[first].value as? String, "Selected")
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(app.staticTexts["pack.selectedCount"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["pack.selectedCount"].label, "1 selected")
        XCTAssertTrue(app.buttons[second].exists)
    }

    private func launch(_ scenario: String = "populated", history: Bool = false, largeType: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        if largeType { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_PACK_STATE": scenario]
        app.launch(); app.tabBars.buttons["More"].tap(); tap("documentVault", app)
        tap(history ? "documents.sharedPacks" : "documents.shareDocuments", app)
        XCTAssertTrue(app.navigationBars["Document packs"].waitForExistence(timeout: 10))
        return app
    }
    private func prepareReview(_ app: XCUIApplication, days: Int = 7) {
        tap(first, app); tap("pack.continue", app)
        let purpose = app.textViews["pack.purpose"].exists ? app.textViews["pack.purpose"] : app.textFields["pack.purpose"]
        XCTAssertTrue(purpose.waitForExistence(timeout: 5)); purpose.tap(); purpose.typeText("Demo QA selected documents")
        tap("pack.continue", app)
        XCTAssertEqual(app.buttons["pack.expiry.7"].value as? String, "Selected")
        for option in [1, 3, 7, 14, 30] { XCTAssertTrue(app.buttons["pack.expiry.\(option)"].exists) }
        tap("pack.expiry.\(days)", app); tap("pack.continue", app)
    }
    private func tap(_ id: String, _ app: XCUIApplication) {
        let element = app.buttons[id].firstMatch
        XCTAssertTrue(element.waitForExistence(timeout: 10), "Missing control: \(id)")
        for _ in 0..<10 { if element.isHittable { break }; app.swipeUp() }
        element.tap()
    }
}
