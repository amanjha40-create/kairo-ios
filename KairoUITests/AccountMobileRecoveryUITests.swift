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
        XCTAssertTrue(app.textFields["onboarding.accountVerification.phone"].exists)
        XCTAssertTrue(app.buttons["onboarding.accountVerification.savePhone"].exists)
    }

    func testNoStoredPhoneCanBeSavedThenExplicitlyVerifiedWithoutNewSignup() {
        let app = login(scenario: "missingPhone")
        saveMissingPhone(in: app)
        let send = app.buttons["onboarding.accountVerification.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 10))
        XCTAssertFalse(app.textFields["onboarding.accountVerification.code"].exists, "Save must not send OTP")
        XCTAssertFalse(app.buttons["onboarding.accountVerification.verify"].exists)
        XCTAssertFalse(app.buttons["onboarding.verifyIdentity.email.sendCode"].exists)
        send.tap()
        let code = app.textFields["onboarding.accountVerification.code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        code.typeText("123456")
        let verify = app.buttons["onboarding.accountVerification.verify"]
        if !verify.isHittable { app.swipeUp() }
        verify.tap()
        XCTAssertTrue(app.descendants(matching: .any)["onboarding.step.chooseStart"].waitForExistence(timeout: 10))
    }

    func testMissingPhoneConflictKeepsEntryWithoutSendingCode() {
        let app = login(scenario: "missingPhoneConflict")
        saveMissingPhone(in: app)
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["onboarding.accountVerification.phone"].exists)
        XCTAssertFalse(app.buttons["onboarding.accountVerification.send"].exists)
        XCTAssertFalse(app.buttons["onboarding.login.submit"].exists)
    }

    func testMissingPhoneNetworkFailureKeepsRetryableEntry() {
        let app = login(scenario: "missingPhoneSaveFailure")
        saveMissingPhone(in: app)
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.error"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["onboarding.accountVerification.savePhone"].isEnabled)
        XCTAssertTrue(app.buttons["onboarding.accountVerification.refresh"].exists)
        XCTAssertFalse(app.textFields["onboarding.accountVerification.code"].exists)
    }

    func testMissingPhoneEntryAndSaveReachableAtAccessibilityXXXL() {
        let app = login(scenario: "missingPhone", accessibilityXXXL: true)
        saveMissingPhone(in: app)
        let send = app.buttons["onboarding.accountVerification.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 10))
        // Canonical refresh returns to the top. At XXXL the header and copy
        // span several viewports, so one swipe cannot reach the inline action.
        for _ in 0..<6 {
            if send.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(send.isHittable)
        XCTAssertFalse(app.textFields["onboarding.accountVerification.code"].exists)
        let reachable = XCTAttachment(screenshot: app.screenshot())
        reachable.name = "XXXL synthetic Send Code reachable"
        reachable.lifetime = .keepAlways
        add(reachable)
        send.tap()
        XCTAssertTrue(app.textFields["onboarding.accountVerification.code"].waitForExistence(timeout: 5))
    }

    private func saveMissingPhone(in app: XCUIApplication) {
        let phone = app.textFields["onboarding.accountVerification.phone"]
        XCTAssertTrue(phone.waitForExistence(timeout: 5))
        let save = app.buttons["onboarding.accountVerification.savePhone"]
        XCTAssertFalse(save.isEnabled)
        if !phone.isHittable { app.swipeUp() }
        phone.tap()
        phone.typeText("9876543210")
        if !save.isHittable { app.swipeUp() }
        XCTAssertTrue(save.isEnabled)
        save.tap()
    }

    func testDeliveryFailureIsRetryableWithoutOTPFieldError() {
        let app = login(scenario: "deliveryFailure")
        app.buttons["onboarding.accountVerification.send"].tap()
        XCTAssertTrue(app.staticTexts["onboarding.accountVerification.error"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["onboarding.accountVerification.code"].exists)
        XCTAssertTrue(app.buttons["onboarding.accountVerification.send"].isEnabled)
        XCTAssertTrue(app.buttons["onboarding.accountVerification.refresh"].exists)
    }

    private func login(scenario: String, accessibilityXXXL: Bool = false) -> XCUIApplication {
        let passwordSavePrompt = PasswordSavePromptSupport()
        let app = XCUIApplication()
        app.launchArguments = ["-KAIRO_UI_TESTING", "-ApplePersistenceIgnoreState", "YES"]
        if accessibilityXXXL {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launchEnvironment = [
            "KAIRO_UI_TEST_ROUTE": "onboarding",
            "KAIRO_UI_TEST_DISABLE_ANIMATIONS": "1",
            "KAIRO_UI_TEST_LOGIN_RESULT": "success",
            "KAIRO_UI_TEST_ACCOUNT_MOBILE_RECOVERY": scenario
        ]
        app.launch()
        passwordSavePrompt.dismissIfPresent(in: self)
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
        passwordSavePrompt.dismissIfPresent(in: self)
        return app
    }
}
