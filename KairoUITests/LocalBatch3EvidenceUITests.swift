import XCTest

#if KAIRO_LOCAL_BATCH1_QA
@MainActor
final class LocalBatch3EvidenceUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    override func tearDownWithError() throws {
        let app = XCUIApplication()
        capture(app, "Synthetic Batch 3 final screen")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Synthetic Batch 3 accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    func testDisconnectedConnectIsVisibleAtTopAndUnique() {
        let app = launch("digilocker")
        let connect = app.buttons["candidate.digilocker.connect"]
        XCTAssertTrue(connect.waitForExistence(timeout: 8))
        XCTAssertTrue(connect.isHittable)
        XCTAssertLessThan(connect.frame.maxY, app.frame.maxY)
        XCTAssertEqual(app.buttons.matching(identifier: "candidate.digilocker.connect").count, 1)
        XCTAssertTrue(app.staticTexts["Not connected"].exists)
        capture(app, "DigiLocker single visible connection action")
        // No tap: loading a Hub must not connect or open any provider.
        XCUIDevice.shared.press(.home); app.activate()
        XCTAssertTrue(connect.waitForExistence(timeout: 8))
    }
    func testConnectedStateShowsRefreshNotConnect() {
        let app = launch("digilockerConnected")
        XCTAssertTrue(app.staticTexts["DigiLocker connected"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["candidate.digilocker.connect"].exists)
        XCTAssertTrue(app.buttons["Refresh status and results"].isHittable)
        capture(app, "DigiLocker connected server state")
    }
    func testUnavailableStateDoesNotOfferBlindConnect() {
        let app = launch("digilockerError")
        XCTAssertTrue(app.staticTexts["DigiLocker connection status unavailable"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["candidate.digilocker.connect"].exists)
        XCTAssertTrue(app.buttons["Refresh status and results"].isHittable)
        capture(app, "DigiLocker retryable unavailable state")
    }
    func testEmploymentPrimarySupportingAndLegacyHierarchy() {
        let app = launch("employment")
        let primary = app.staticTexts["Primary evidence"]
        XCTAssertTrue(primary.waitForExistence(timeout: 8))
        let supporting = app.staticTexts["Supporting evidence — optional"]
        reveal(supporting, app)
        XCTAssertLessThan(primary.frame.minY, supporting.frame.minY)
        reveal(app.staticTexts["Unclassified evidence — not counted"], app)
        capture(app, "Employment canonical evidence groups")
    }
    func testTypeSelectionPersistsAfterSheetDismissal() {
        let app = launch("employment")
        let type = app.buttons["evidence.documentType"]
        reveal(type, app)
        XCTAssertEqual(type.value as? String, "Not selected")
        XCTAssertFalse(app.buttons["candidate.career.documents.upload"].isEnabled)
        type.tap()
        XCTAssertTrue(app.buttons["Offer letter"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Other"].exists)
        XCTAssertFalse(app.buttons["Government ID"].exists)
        app.buttons["Offer letter"].tap()
        XCTAssertEqual(type.value as? String, "Offer letter")
        capture(app, "Prominent selected evidence type")
    }
    func testRoleSwitchResetsTypeAndFiltersSupportingChoices() {
        let app = launch("employment")
        let type = app.buttons["evidence.documentType"]
        reveal(type, app); type.tap(); app.buttons["Offer letter"].tap()
        let supporting = app.buttons["career.documents.evidenceRole.supporting"]
        reveal(supporting, app); supporting.tap()
        XCTAssertEqual(type.value as? String, "Not selected")
        reveal(type, app); type.tap()
        XCTAssertFalse(app.buttons["Offer letter"].exists)
        XCTAssertFalse(app.buttons["Government ID"].exists)
        XCTAssertTrue(app.buttons["Bank statement"].exists)
        app.buttons["Bank statement"].tap()
        XCTAssertEqual(type.value as? String, "Bank statement")
        capture(app, "Supporting evidence filtered, explicit selection")
    }
    func testUploadReviewFailureRetryAndCanonicalRefresh() {
        let app = launch("employment")
        let type = app.buttons["evidence.documentType"]
        reveal(type, app); type.tap(); app.buttons["Offer letter"].tap()
        let choose = app.buttons["candidate.career.documents.upload"]
        // Identifier comes from the shared production upload control.
        let file = choose.exists ? choose : app.buttons["Choose file"]
        reveal(file, app); file.tap()
        let upload = app.buttons["evidence.confirmUpload"]
        reveal(upload, app)
        XCTAssertTrue(app.staticTexts["synthetic-evidence.pdf"].exists)
        XCTAssertFalse(app.staticTexts["evidence.added"].exists)
        upload.tap()
        XCTAssertTrue(app.staticTexts["candidate.career.documents.error"].waitForExistence(timeout: 3)
                      || app.staticTexts["Document action failed"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["evidence.added"].exists)
        reveal(upload, app); XCTAssertEqual(upload.label, "Retry upload")
        capture(app, "Retained file and type after upload failure")
        upload.tap()
        XCTAssertTrue(app.staticTexts["evidence.added"].waitForExistence(timeout: 8))
        capture(app, "Upload confirmed and canonical list refreshed")
    }
    func testSingleAttachmentSlotUsesReplaceAndNotSecondAdd() {
        let app = launch("certification")
        XCTAssertTrue(app.staticTexts["evidence.alreadyAdded"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Choose file"].exists)
        let replace = app.buttons["Replace"]
        reveal(replace, app); replace.tap()
        reveal(app.buttons["evidence.confirmUpload"], app)
        XCTAssertTrue(app.staticTexts["Review document"].exists)
        capture(app, "Single attachment explicit replacement review")
    }
    func testEducationInstitutionContactWithoutEmploymentFields() {
        let app = launch("educationVerification")
        XCTAssertTrue(app.staticTexts["Education verification"].waitForExistence(timeout: 8))
        let contact = app.staticTexts["Institution contact"]
        reveal(contact, app)
        XCTAssertFalse(app.textFields["hr@organisation.com"].exists)
        XCTAssertFalse(app.textFields["HR manager"].exists)
        XCTAssertTrue(app.textFields["registrar@institution.edu"].exists)
        let contactType = app.buttons["Contact type, Authorised representative"]
        reveal(contactType, app)
        XCTAssertTrue(contactType.isHittable)
        contactType.tap()
        XCTAssertTrue(app.buttons["Authorised representative"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Other"].exists)
        XCTAssertFalse(app.buttons["HR"].exists)
        XCTAssertFalse(app.buttons["Founder"].exists)
        app.buttons["Authorised representative"].tap()
        capture(app, "Institution specific verification fields")
    }
    func testEducationDocumentTypeSelection() {
        let app = launch("education")
        let type = app.buttons["evidence.documentType"]
        reveal(type, app); type.tap()
        app.buttons["Transcript"].tap()
        XCTAssertEqual(type.value as? String, "Transcript")
        XCTAssertFalse(app.buttons["career.documents.evidenceRole.primary"].exists)
        capture(app, "Education documents without Employment role semantics")
    }
    func testLightDarkXXXLSelectionAndReviewReachable() {
        for style in ["light", "dark"] {
            let app = launch("education", style: style, large: true)
            let type = app.buttons["evidence.documentType"]
            reveal(type, app); type.tap()
            app.buttons["Transcript"].tap()
            XCTAssertEqual(type.value as? String, "Transcript")
            let choose = app.buttons["Choose file"]
            reveal(choose, app); choose.tap()
            let upload = app.buttons["evidence.confirmUpload"]
            reveal(upload, app); XCTAssertTrue(upload.isHittable)
            capture(app, "XXXL evidence review \(style)")
        }
    }
    private func launch(_ surface: String, style: String = "light", large: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-KAIRO_LOCAL_BATCH1_QA", "-ApplePersistenceIgnoreState", "YES"]
        if large { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launchEnvironment = ["KAIRO_LOCAL_BATCH1_MODE": "batch3Evidence", "KAIRO_BATCH3_SURFACE": surface,
            "KAIRO_LOCAL_BATCH1_APPEARANCE": style, "KAIRO_UI_TEST_ROUTE": "demoHome", "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1"]
        app.launch()
        XCTAssertTrue(app.staticTexts["batch1.qa.banner"].waitForExistence(timeout: 10))
        return app
    }
    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<22 {
            if element.exists && element.isHittable && element.frame.midY > 100 && element.frame.midY < app.frame.maxY - 100 { return }
            if element.exists && element.frame.midY < 100 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let item = XCTAttachment(screenshot: app.screenshot()); item.name = name; item.lifetime = .keepAlways; add(item)
    }
}
#endif
