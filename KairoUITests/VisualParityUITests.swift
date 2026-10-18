import XCTest
import UIKit

@MainActor
final class VisualParityUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testScrolledStatusBarProtectionLight() { checkScrolledStatusBarProtection(appearance: "light") }
    func testScrolledStatusBarProtectionDark() { checkScrolledStatusBarProtection(appearance: "dark") }

    func testZeroRequestsHasNoViewRequestAction() {
        let app = launch(homeState: "empty")
        XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].firstMatch.waitForExistence(timeout: 10))
        for _ in 0..<5 {
            XCTAssertFalse(app.buttons["candidate.home.verificationRequest.action"].exists)
            XCTAssertFalse(app.staticTexts["Awaiting approval"].exists)
            app.swipeUp()
        }
    }

    private func checkScrolledStatusBarProtection(appearance: String) {
        // Hide the Demo banner while retaining isolated UI-test fixtures. The
        // banner otherwise masks the exact no-header layout that failed live.
        let app = launch(appearance: appearance, demoMode: false)
        for tab in ["Home", "Career", "Passport", "More"] {
            app.tabBars.buttons[tab].tap()
            XCTAssertTrue(app.tabBars.buttons[tab].isSelected)
            let before = statusBarBackgroundSamples(app)
            for index in 1...3 {
                app.swipeUp()
                XCTAssertEqual(app.state, .runningForeground)
                let after = statusBarBackgroundSamples(app)
                XCTAssertEqual(before.count, after.count)
                if !before.isEmpty, before.count == after.count {
                    let difference = zip(before, after).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(before.count)
                    XCTAssertLessThan(difference, 2, "\(tab) scroll changed the protected status-bar background")
                }
                capture("\(tab) scrolled \(index) \(appearance) status-bar")
            }
        }
    }

    private func statusBarBackgroundSamples(_ app: XCUIApplication) -> [UInt8] {
        let bar = XCUIApplication(bundleIdentifier: "com.apple.springboard").statusBars.firstMatch
        let nativeFrame = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.statusBarManager?.statusBarFrame }
            .first { !$0.isEmpty }
        let frame = bar.exists ? bar.frame : (nativeFrame ?? .zero)
        XCTAssertFalse(frame.isEmpty, "Use the system status-bar frame, never a guessed device inset")
        guard !frame.isEmpty, let image = app.screenshot().image.cgImage else { return [] }
        let scale = CGFloat(image.width) / app.frame.width
        var samples = [UInt8]()
        // Narrow background strips avoid changing clock digits and connectivity
        // indicators. All vertical bounds come from the OS-reported bar frame.
        for x in [0.02, 0.26, 0.96] {
            let rect = CGRect(x: frame.width * x * scale, y: frame.minY * scale, width: frame.width * 0.02 * scale, height: frame.height * scale).integral
            guard let crop = image.cropping(to: rect), let data = crop.dataProvider?.data else { XCTFail("Missing status-bar pixels"); return [] }
            samples.append(contentsOf: Data(referencing: data))
        }
        return samples
    }

    func testHomeHierarchyAndScreenshot() {
        let app = launch()
        let hero = app.descendants(matching: .any)["candidate.home.trustScore"].firstMatch
        XCTAssertTrue(hero.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidate.home.viewTrustPassport"].exists)
        assertBannerDoesNotCoverHeader(app)
        let attention = app.staticTexts["Needs Your Attention"]
        XCTAssertTrue(attention.exists)
        XCTAssertLessThan(hero.frame.minY, attention.frame.minY)
        capture("Home")
    }

    func testCareerDetailAndDocumentsReuse() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "career.record.open.")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10))
        capture("Career")
        first.tap()
        XCTAssertTrue(app.otherElements["career.record.detail"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Details"].exists)
        XCTAssertTrue(app.staticTexts["Verification"].exists)
        capture("Employment detail")
        app.buttons["career.detail.documents"].tap()
        XCTAssertTrue(app.navigationBars["Employment documents"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["demo-evidence.pdf"].waitForExistence(timeout: 10))
        capture("Employment documents")
    }

    func testEducationDetail() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        let section = app.descendants(matching: .any)["candidate.career.education"].firstMatch
        reveal(section, app: app)
        let record = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "career.record.open.", "Christ University")).firstMatch
        reveal(record, app: app)
        record.tap()
        XCTAssertTrue(app.otherElements["career.record.detail"].waitForExistence(timeout: 10))
        capture("Education detail")
    }

    func testCertificationAndProjectDetails() {
        let app = launch()
        app.tabBars.buttons["Career"].tap()
        for (title, screenshotName) in [("People Operations Foundations", "Certification"), ("Career Trust Onboarding Pilot", "Project")] {
            let record = app.buttons["career.record.open.\(title)"]
            // Section-header visibility does not mean its record is clear of the tab bar.
            for _ in 0..<25 {
                if record.exists && record.isHittable && record.frame.minY > 120 && record.frame.maxY < app.frame.height - 120 { break }
                let earlier = record.exists && record.frame.minY <= 120
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.40 : 0.70))
                    .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: earlier ? 0.60 : 0.45)))
            }
            XCTAssertTrue(record.isHittable)
            XCTAssertGreaterThan(record.frame.minY, 120)
            XCTAssertLessThan(record.frame.maxY, app.frame.height - 120)
            record.tap()
            XCTAssertTrue(app.otherElements["career.record.detail"].waitForExistence(timeout: 10))
            capture(screenshotName + " detail")
            app.buttons["Done"].tap()
        }
    }

    func testVerifyGroupsAndNextAction() {
        let app = launch()
        app.openCareerVerification()
        XCTAssertTrue(app.staticTexts["candidate.verify.pendingRequests"].waitForExistence(timeout: 10))
        capture("Verify")
        let request = app.buttons["candidate.verify.request.action.employment-brightpath"]
        reveal(request, app: app)
        request.tap()
        XCTAssertTrue(app.staticTexts["Next action"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidate.verify.request.accept"].exists)
        capture("Verify detail")
    }

    func testPassportAndShareHierarchy() {
        let app = launch()
        app.tabBars.buttons["Passport"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.passport.header"].waitForExistence(timeout: 10))
        capture("Passport")
        let share = app.buttons["candidate.passport.share"]
        reveal(share, app: app)
        share.tap()
        let create = app.buttons["candidate.passport.share.createEntry"]
        XCTAssertTrue(create.waitForExistence(timeout: 10))
        create.tap()
        XCTAssertTrue(app.textFields["candidate.passport.share.label"].waitForExistence(timeout: 10))
        capture("Share form")
    }

    func testMoreSettingsDocumentsAndNotifications() {
        let app = launch()
        app.tabBars.buttons["More"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.more.accountSummary"].waitForExistence(timeout: 10))
        capture("More")
        let documents = app.buttons["documentVault"]
        reveal(documents, app: app)
        documents.tap()
        XCTAssertTrue(app.navigationBars["Documents"].waitForExistence(timeout: 10))
        capture("Documents")
        app.buttons["Done"].tap()
        let settings = app.buttons["candidate.more.settings"]
        reveal(settings, app: app)
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        capture("Settings")
        app.tabBars.buttons["Home"].tap()
        app.buttons["candidate.home.notifications"].tap()
        XCTAssertTrue(app.navigationBars["Notifications"].waitForExistence(timeout: 10))
        capture("Notifications")
    }

    func testDarkModeAndLargeText() {
        let app = launch(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        app.tabBars.buttons["More"].tap()
        let settings = app.buttons["candidate.more.settings"]
        reveal(settings, app: app); settings.tap()
        let dark = app.buttons["candidate.more.appearance.dark"]
        reveal(dark, app: app)
        dark.tap()
        XCTAssertEqual(dark.value as? String, "Selected")
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(app.buttons["candidate.home.viewTrustPassport"].waitForExistence(timeout: 10))
        assertBannerDoesNotCoverHeader(app)
        capture("Home dark large text")
        app.tabBars.buttons["Career"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["candidate.career.screen"].waitForExistence(timeout: 10))
        let record = app.buttons["career.record.open.Trust & Operations Associate"]
        reveal(record, app: app)
        let status = app.descendants(matching: .any)["career.record.status.Trust & Operations Associate"].firstMatch
        XCTAssertTrue(status.exists)
        XCTAssertGreaterThanOrEqual(status.frame.minY, app.staticTexts["Trust & Operations Associate"].frame.maxY)
        capture("Career dark large text")
    }

    private func assertBannerDoesNotCoverHeader(_ app: XCUIApplication) {
        let banner = app.staticTexts["demo.banner"]
        // The master logo is decorative; use the visible, accessible Home header
        // to retain the banner-overlap assertion without duplicating brand speech.
        let heading = app.staticTexts["candidate.home.greeting"]
        XCTAssertTrue(banner.exists)
        XCTAssertTrue(heading.exists)
        XCTAssertGreaterThanOrEqual(heading.frame.minY, banner.frame.maxY)
    }

    private func launch(arguments: [String] = [], appearance: String = "light", homeState: String = "populated", demoMode: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES", "-kairo.appearance.preference", appearance] + arguments
        app.launchEnvironment = [
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": demoMode ? "true" : "false", "KAIRO_APP_ENVIRONMENT": "staging",
            "KAIRO_UI_TEST_HOME_STATE": homeState, "KAIRO_UI_TEST_CAREER_STATE": "populated",
            "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_PASSPORT_STATE": "populated",
            "KAIRO_UI_TEST_MORE_STATE": "populated", "KAIRO_UI_TEST_NOTIFICATIONS_STATE": "populated"
        ]
        app.launch()
        return app
    }

    private func reveal(_ element: XCUIElement, app: XCUIApplication) {
        for _ in 0..<18 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.isHittable)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Visual Parity V1 - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
