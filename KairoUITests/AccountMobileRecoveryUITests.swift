import XCTest

@MainActor
final class AccountMobileRecoveryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPasswordLoginUsesExistingAccountMobileFlowAndCanonicalProfileRoute() {
        let app = login(scenario: "success")
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.emailVerified"].exists ||
                      app.descendants(matching: .any)["onboarding.accountVerification.emailVerified"].exists)
        XCTAssertFalse(app.buttons["onboarding.verifyIdentity.email.sendCode"].exists)
        app.buttons["onboarding.accountVerification.send"].tap()
        let code = app.textFields["onboarding.accountVerification.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.accountVerification.send"].isEnabled)
        code.tap()
        code.typeText("123456")
        let verify = app.buttons["onboarding.accountVerification.verify"]
        if !verify.isHittable { app.swipeUp() }
        verify.tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.step.chooseStart"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["candidate.tabShell"].exists)
    }

    func testInvalidCodeKeepsAuthenticatedRecoveryScreen() {
        let app = login(scenario: "invalidCode")
        app.buttons["onboarding.accountVerification.send"].tap()
        let code = app.textFields["onboarding.accountVerification.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        code.typeText("123456")
        let verify = app.buttons["onboarding.accountVerification.verify"]
        if !verify.isHittable { app.swipeUp() }
        verify.tap()
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.login.submit"].exists)
        XCTAssertFalse(app.staticTexts["Your signup session expired. Please start again."].exists)
    }

    func testMissingPhoneFailsClosedWithoutSignup() {
        let app = login(scenario: "phoneRequired")
        app.buttons["onboarding.accountVerification.send"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.phoneRequired"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.accountVerification.send"].exists)
        XCTAssertFalse(app.buttons["onboarding.verifyIdentity.email.sendCode"].exists)
    }

    func testDeliveryFailureIsRetryableWithoutOTPFieldError() {
        let app = login(scenario: "deliveryFailure")
        app.buttons["onboarding.accountVerification.send"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["onboarding.accountVerification.code"].exists)
        XCTAssertTrue(app.buttons["onboarding.accountVerification.send"].isEnabled)
        XCTAssertTrue(app.buttons["onboarding.accountVerification.refresh"].exists)
    }

    private func login(scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        app.launchEnvironment = [
            "KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_LOGIN_RESULT": "success",
            "KAIRO_UI_TEST_ACCOUNT_MOBILE_RECOVERY": scenario
        ]
        app.launch()
        let login = app.buttons["onboarding.existingAccount"]
        XCTAssertTrue(login.waitForExistence(timeout: 10))
        login.tap()
        let email = app.textFields["onboarding.login.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 5))
        email.tap()
        email.typeText("synthetic@example.com")
        let password = app.secureTextFields["onboarding.login.password"]
        password.tap()
        password.typeText("SyntheticPassword123!")
        let submit = app.buttons["onboarding.login.submit"]
        if !submit.isHittable { app.swipeUp() }
        submit.tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.accountVerification.title"].waitForExistence(timeout: 10))
        return app
    }
}
