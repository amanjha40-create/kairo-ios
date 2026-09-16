import XCTest

@MainActor
final class Parity4AUITests: XCTestCase {
    func testVaultNewUploadSelectorHasExactlySevenCanonicalChoices() {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = ["KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1", "KAIRO_UI_TEST_ROUTE": "demoHome",
            "KAIRO_DEMO_MODE": "false", "KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_UI_TEST_MORE_STATE": "populated"]
        app.launch()
        app.tabBars.buttons["More"].tap()
        let documents = app.buttons["documentVault"]
        reveal(documents, app); documents.tap()
        let vault = app.buttons["Manage Vault / identity documents"]
        XCTAssertTrue(vault.waitForExistence(timeout: 10)); vault.tap()
        XCTAssertTrue(app.navigationBars["Document Vault"].waitForExistence(timeout: 10))
        let picker = app.buttons["candidate.more.documentVault.type"]
        reveal(picker, app); picker.tap()
        let names = ["Aadhaar", "PAN", "Passport", "Driving Licence", "Voter ID", "Birth Certificate", "Address Proof"]
        for name in names { XCTAssertTrue(app.buttons[name].waitForExistence(timeout: 3), name) }
        XCTAssertFalse(app.buttons["Government ID"].exists)
        XCTAssertFalse(app.buttons["Other"].exists)
        app.buttons["Birth Certificate"].tap()
        XCTAssertTrue(picker.label.contains("Birth Certificate"))
        picker.tap(); app.buttons["Address Proof"].tap()
        XCTAssertTrue(picker.label.contains("Address Proof"))
        // No file selection or upload is performed.
    }

    private func reveal(_ element: XCUIElement, _ app: XCUIApplication) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Expected navigation element unavailable")
    }
}
