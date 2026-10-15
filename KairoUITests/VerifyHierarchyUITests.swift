import XCTest

@MainActor
final class VerifyHierarchyUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    private let choices: [(String, String, String)] = [
        ("all", "All verification requests", ""), ("attention", "Needs your attention", "attention"),
        ("inProgress", "In progress", "active"), ("verified", "Verified", "verified"),
        ("rejected", "Rejected", "rejected"), ("withdrawn", "Withdrawn", "withdrawn"),
        ("unableToVerify", "Unable to verify", "unable"), ("expired", "Expired", "expired"),
        ("cancelled", "Cancelled", "cancelled")]

    func testNineFiltersHaveExactMembershipAndSelectedState() {
        let app = launch()
        XCTAssertEqual(app.buttons["verify.filter"].value as? String, "Selected: All verification requests")
        XCTAssertEqual(rows(app).count, 6)
        reveal(app.buttons["verify.completed.more"], app); app.buttons["verify.completed.more"].tap()
        XCTAssertEqual(rows(app).count, 9)
        for (key, title, id) in choices.dropFirst() {
            select(key, title, app)
            XCTAssertEqual(app.buttons["verify.filter"].value as? String, "Selected: \(title)")
            XCTAssertEqual(rows(app).count, 1)
            XCTAssertTrue(row(id, app).exists)
        }
        select("all", "All verification requests", app)
        XCTAssertEqual(rows(app).count, 6)
        reveal(app.buttons["verify.completed.more"], app); app.buttons["verify.completed.more"].tap()
        XCTAssertEqual(rows(app).count, 9)
    }

    func testEveryFilterHasCompactEmptyState() {
        let app = launch(empty: true)
        let messages = ["No verification requests yet.", "No verification requests need your attention.",
            "No verification requests in progress.", "No verified requests yet.", "No rejected requests.",
            "No withdrawn requests.", "No requests with an unable-to-verify outcome.", "No expired requests.", "No cancelled requests."]
        for (index, choice) in choices.enumerated() {
            if index > 0 { select(choice.0, choice.1, app) }
            XCTAssertEqual(app.staticTexts["candidate.verify.empty"].label, messages[index])
            XCTAssertEqual(rows(app).count, 0)
        }
    }

    func testCompletedHistoryLeadingCenterTrailingAndWrappedAreaOpenExactPublicID() {
        let app = launch()
        select("withdrawn", "Withdrawn", app)
        let target = row("withdrawn", app)
        reveal(target, app)
        XCTAssertGreaterThanOrEqual(target.frame.height, 44)
        XCTAssertGreaterThan(target.frame.width, app.frame.width * 0.7)
        for point in [CGVector(dx: 0.01, dy: 0.5), CGVector(dx: 0.5, dy: 0.5),
                      CGVector(dx: 0.99, dy: 0.5), CGVector(dx: 0.5, dy: 0.92)] {
            target.coordinate(withNormalizedOffset: point).tap()
            assertDetail("withdrawn", app)
            app.buttons["Done"].tap()
            XCTAssertTrue(app.tabBars.buttons["Verify"].isSelected)
            XCTAssertEqual(app.buttons["verify.filter"].value as? String, "Selected: Withdrawn")
        }
    }

    func testActionableAndInProgressRowsUseSameFullWidthDestination() {
        let app = launch()
        for (key, title, id) in [choices[1], choices[2]] {
            select(key, title, app)
            let target = row(id, app)
            reveal(target, app)
            for point in [CGVector(dx: 0.01, dy: 0.5), CGVector(dx: 0.99, dy: 0.85)] {
                target.coordinate(withNormalizedOffset: point).tap()
                assertDetail(id, app)
                app.buttons["Done"].tap()
            }
        }
    }

    func testAllGroupOrderCountsAndUnknownNeverGainsActions() {
        let app = launch()
        var previous: XCUIElement?
        for (key, count) in [("pendingRequests", 1), ("inProgress", 1), ("completed", 6), ("unavailable", 1)] {
            let heading = app.staticTexts["candidate.verify.\(key)"]
            reveal(heading, app)
            if let previous { XCTAssertLessThan(previous.frame.minY, heading.frame.minY) }
            previous = heading
            XCTAssertTrue(app.staticTexts["candidate.verify.\(key).count"].label.hasSuffix("\(count) requests"))
        }
        let unknown = row("unknown", app)
        reveal(unknown, app)
        XCTAssertTrue(unknown.label.contains("Status unavailable"))
        unknown.tap(); assertDetail("unknown", app)
        XCTAssertFalse(app.buttons["verify.request.withdraw"].exists)
        XCTAssertFalse(app.buttons["candidate.verify.request.accept"].exists)
        XCTAssertFalse(app.buttons["Submit for review"].exists)
    }

    func testDetailOrderBothConsentScopesEvidenceTruthAndChronologicalTimeline() {
        let app = launch()
        select("inProgress", "In progress", app)
        row("active", app).tap(); assertDetail("active", app)
        let actions = app.staticTexts["verify.detail.section.actions"]
        let claim = app.buttons["verify.detail.section.claim"]
        XCTAssertLessThan(actions.frame.minY, claim.frame.minY)
        for key in ["claim", "sharing", "consent", "contact", "evidence", "timeline", "metadata"] {
            let disclosure = app.buttons["verify.detail.section.\(key)"]
            reveal(disclosure, app)
            XCTAssertEqual(disclosure.value as? String, "Collapsed")
            disclosure.tap()
            XCTAssertEqual(disclosure.value as? String, "Expanded")
        }
        let fields = app.staticTexts["Role, Employment dates"]
        reveal(fields, app)
        XCTAssertTrue(fields.isHittable)
        XCTAssertFalse(app.staticTexts["employment_document"].exists)
        XCTAssertFalse(app.staticTexts["role, employment_dates"].exists)
        XCTAssertTrue(app.staticTexts["Verification evidence"].exists)
        let unavailable = app.staticTexts["Historical evidence download is unavailable."]
        reveal(unavailable, app)
        XCTAssertFalse(app.buttons["View evidence"].exists)
        let early = app.descendants(matching: .any)["verify.detail.event.qa-event-early"].firstMatch
        let late = app.descendants(matching: .any)["verify.detail.event.qa-event-late"].firstMatch
        reveal(late, app)
        XCTAssertLessThan(early.frame.minY, late.frame.minY)
        capture(app, "4C3 timeline and evidence")
    }

    func testFilterSurvivesReloadAndFailedRefreshHidesCountsUntilRetry() {
        let app = launch()
        select("cancelled", "Cancelled", app)
        app.buttons["verify.fixture.reload"].tap()
        XCTAssertEqual(app.buttons["verify.filter"].value as? String, "Selected: Cancelled")
        XCTAssertTrue(row("cancelled", app).exists)
        app.buttons["verify.fixture.fail"].tap()
        XCTAssertTrue(app.buttons["verify.retry"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows(app).count, 0)
        XCTAssertFalse(app.staticTexts["verify.filter.count"].exists)
        app.buttons["verify.retry"].tap()
        XCTAssertTrue(row("cancelled", app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["verify.filter"].value as? String, "Selected: Cancelled")
    }

    func testLargeTypeDarkLongRowsSafeAreaAndBackgroundRestore() {
        let app = launch(large: true)
        select("unableToVerify", "Unable to verify", app)
        let filterTitle = app.buttons["verify.filter"].staticTexts["Unable to verify"]
        capture(app, "4C3 accessible full-width filter")
        // AX reports the rendered glyph bounds, not the SwiftUI layout proposal.
        // The title must occupy its own line above count/icons, without clipping.
        XCTAssertLessThan(filterTitle.frame.maxY, app.staticTexts["verify.filter.count"].frame.minY)
        XCTAssertGreaterThanOrEqual(filterTitle.frame.minX, app.buttons["verify.filter"].frame.minX)
        XCTAssertLessThanOrEqual(filterTitle.frame.maxX, app.buttons["verify.filter"].frame.maxX)
        let target = row("unable", app)
        reveal(target, app)
        XCTAssertGreaterThanOrEqual(target.frame.height, 44)
        XCTAssertGreaterThanOrEqual(target.frame.minX, 0)
        XCTAssertLessThanOrEqual(target.frame.maxX, app.frame.maxX)
        XCTAssertTrue(target.label.contains("Synthetic International Organization"))
        XCTAssertTrue(target.label.contains("Unable to verify"))
        capture(app, "4C3 dark accessibility list")
        target.tap(); assertDetail("unable", app)
        XCUIDevice.shared.press(.home); app.activate()
        assertDetail("unable", app)
        app.buttons["Done"].tap()
        XCTAssertEqual(app.buttons["verify.filter"].value as? String, "Selected: Unable to verify")
    }

    private func launch(empty: Bool = false, large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_HOME_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_VERIFY_STATE": empty ? "empty" : "populated",
            "KAIRO_UI_TEST_VERIFY_HIERARCHY": "1"]
        app.launch()
        if large {
            app.tabBars.buttons["More"].tap()
            let settings = app.buttons["candidate.more.settings"]
            reveal(settings, app); settings.tap()
            let dark = app.buttons["candidate.more.appearance.dark"]
            reveal(dark, app); dark.tap()
        }
        app.tabBars.buttons["Verify"].tap()
        XCTAssertTrue(app.buttons["verify.filter"].waitForExistence(timeout: 10))
        return app
    }
    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "candidate.verify.request.action."))
    }
    private func row(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.buttons["candidate.verify.request.action.qa-\(id)"] }
    private func select(_ key: String, _ title: String, _ app: XCUIApplication) {
        let filter = app.buttons["verify.filter"]
        reveal(filter, app); filter.tap()
        let identified = app.buttons["verify.filter.option.\(key)"]
        let option = identified.exists ? identified : app.buttons[title]
        // Native menus virtualize off-screen choices at accessibility text sizes.
        for _ in 0..<10 {
            if option.exists && option.isHittable { break }
            let menu = app.collectionViews.firstMatch
            guard menu.exists else { break }
            let visible = menu.frame.intersection(app.frame.insetBy(dx: 16, dy: 110))
            let start = app.coordinate(withNormalizedOffset: .zero)
                // UIKit can report a collection taller than its clipped popover.
                // Start near its top so this gesture stays inside the native menu.
                .withOffset(CGVector(dx: visible.midX, dy: visible.minY + min(200, visible.height * 0.6)))
            let end = app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: visible.midX, dy: visible.minY + 24))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(option.waitForExistence(timeout: 5)); option.tap()
        let selected = NSPredicate(format: "value == %@", "Selected: \(title)")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: selected, object: filter)], timeout: 5), .completed)
    }
    private func assertDetail(_ id: String, _ app: XCUIApplication) {
        let detail = app.descendants(matching: .any)["candidate.verify.requestDetail"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        XCTAssertEqual(detail.value as? String, "qa-\(id)")
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<22 {
            if element.exists && element.isHittable && element.frame.minY > 95 &&
                (element.frame.maxY < app.frame.height - 95 ||
                 (element.frame.height > app.frame.height - 200 && element.frame.minY < 220)) { return }
            let earlier = element.exists && element.frame.minY <= 95
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.35 : 0.70))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.65 : 0.40)))
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
