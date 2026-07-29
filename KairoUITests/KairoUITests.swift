//
//  KairoUITests.swift
//  KairoUITests
//
//  Created by Aman on 27/07/26.
//

import XCTest

final class KairoUITests: XCTestCase {
    private let uiTestingArgument = "-KAIRO_UI_TESTING"
    private let uiTestDisableAnimationsKey = "KAIRO_UI_TEST_DISABLE_ANIMATIONS"
    private let uiTestRouteKey = "KAIRO_UI_TEST_ROUTE"
    private let demoModeKey = "KAIRO_DEMO_MODE"
    private let appEnvironmentKey = "KAIRO_APP_ENVIRONMENT"
    private let onboardingWelcomeTitle = "onboarding.step.welcome"
    private let onboardingCreateAccountTitle = "onboarding.step.createAccount"
    private let onboardingVerifyIdentityTitle = "onboarding.step.verifyIdentity"
    private let onboardingGetStartedButton = "onboarding.getStarted"
    private let onboardingContinueButton = "onboarding.continue"
    private let welcomeExistingAccountButton = "onboarding.existingAccount"
    private let createAccountFirstNameField = "onboarding.createAccount.firstName"
    private let createAccountLastNameField = "onboarding.createAccount.lastName"
    private let createAccountEmailField = "onboarding.createAccount.email"
    private let createAccountMobileField = "onboarding.createAccount.mobile"
    private let createAccountContinueButton = "onboarding.createAccount.continue"
    private let createAccountLoginButton = "onboarding.createAccount.login"
    private let onboardingLoginTitle = "onboarding.login.title"
    private let remainingOnboardingTransitionCount = 4
    private var baseLaunchArguments: [String] {
        [
            "-ApplePersistenceIgnoreState",
            "YES",
            uiTestingArgument
        ]
    }
    private var baseLaunchEnvironment: [String: String] {
        [
            uiTestDisableAnimationsKey: "1",
            uiTestRouteKey: "onboarding"
        ]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIApplication().terminate()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    @MainActor
    func testOnboardingFlowReachesLockedHomeShell() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@example.com",
            mobile: "9876543210"
        ))

        XCTAssertTrue(app.staticTexts[onboardingWelcomeTitle].waitForExistence(timeout: 10))
        advanceThroughOnboarding(in: app)

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["candidate.screen.home"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testDemoModeLaunchOverrideReachesDemoHomeShell() throws {
        let app = launchApp(environment: [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome"
        ])

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["candidate.screen.home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["candidate.networkStatusMessage"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testExistingAccountRoutesToLoginPlaceholder() throws {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts[onboardingWelcomeTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[welcomeExistingAccountButton].waitForExistence(timeout: 10))

        app.buttons[welcomeExistingAccountButton].tap()

        assertLoginPlaceholderVisible(in: app)
    }

    @MainActor
    func testCreateAccountEmptyFormKeepsContinueDisabled() throws {
        let app = launchApp()

        navigateToCreateAccount(in: app)

        let continueButton = app.buttons[createAccountContinueButton]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)
        XCTAssertFalse(app.staticTexts["Enter your first name."].exists)
    }

    @MainActor
    func testCreateAccountShowsInvalidEmailMessage() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@",
            mobile: "9876543210",
            touchedFields: ["emailAddress"]
        ))

        navigateToCreateAccount(in: app)

        XCTAssertTrue(app.staticTexts["Enter a valid email address."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[createAccountContinueButton].isEnabled)
    }

    @MainActor
    func testCreateAccountShowsInvalidMobileMessage() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@example.com",
            mobile: "987654321",
            touchedFields: ["mobileNumber"]
        ))

        navigateToCreateAccount(in: app)

        XCTAssertTrue(app.staticTexts["Enter a valid 10-digit Indian mobile number."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[createAccountContinueButton].isEnabled)
    }

    @MainActor
    func testCreateAccountValidFormEnablesContinue() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@example.com",
            mobile: "9876543210"
        ))

        navigateToCreateAccount(in: app)

        let continueButton = app.buttons[createAccountContinueButton]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    func testCreateAccountLoginButtonRoutesToLoginPlaceholder() throws {
        let app = launchApp()

        navigateToCreateAccount(in: app)

        let loginButton = app.buttons[createAccountLoginButton]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        assertLoginPlaceholderVisible(in: app)
    }

    @MainActor
    private func advanceThroughOnboarding(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[onboardingGetStartedButton].waitForExistence(timeout: 10))
        app.buttons[onboardingGetStartedButton].tap()
        XCTAssertTrue(app.staticTexts[onboardingCreateAccountTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[createAccountContinueButton].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[createAccountContinueButton].isEnabled)
        app.buttons[createAccountContinueButton].tap()

        for _ in 0..<remainingOnboardingTransitionCount {
            XCTAssertTrue(app.buttons[onboardingContinueButton].waitForExistence(timeout: 10))
            app.buttons[onboardingContinueButton].tap()
        }
    }

    @MainActor
    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = baseLaunchArguments
        app.launchEnvironment = baseLaunchEnvironment.merging(environment) { _, override in override }
        app.launch()
        return app
    }

    @MainActor
    private func navigateToCreateAccount(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[onboardingGetStartedButton].waitForExistence(timeout: 10))
        app.buttons[onboardingGetStartedButton].tap()
        XCTAssertTrue(app.staticTexts[onboardingCreateAccountTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func assertLoginPlaceholderVisible(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts[onboardingLoginTitle].waitForExistence(timeout: 10))
    }

    private func createAccountEnvironment(
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        mobile: String = "",
        touchedFields: Set<String> = []
    ) -> [String: String] {
        [
            "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": firstName,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": lastName,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_EMAIL": email,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_MOBILE": mobile,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_TOUCHED_FIELDS": touchedFields.sorted().joined(separator: ",")
        ]
    }
}
