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
    private let onboardingTransitionCount = 5
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
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["onboarding.step.welcome"].waitForExistence(timeout: 10))
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

        XCTAssertTrue(app.staticTexts["onboarding.step.welcome"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["onboarding.existingAccount"].waitForExistence(timeout: 10))

        app.buttons["onboarding.existingAccount"].tap()

        XCTAssertTrue(app.otherElements["onboarding.login.screen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["onboarding.login.title"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func advanceThroughOnboarding(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 10))
        app.buttons["onboarding.getStarted"].tap()

        for _ in 0..<onboardingTransitionCount {
            let actionIdentifier = "onboarding.continue"
            XCTAssertTrue(app.buttons[actionIdentifier].waitForExistence(timeout: 10))
            app.buttons[actionIdentifier].tap()
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
}
