//
//  KairoUITests.swift
//  KairoUITests
//
//  Created by Aman on 27/07/26.
//

import XCTest

final class KairoUITests: XCTestCase {
    private let onboardingIdentifiers = [
        "onboarding.step.welcome",
        "onboarding.step.createAccount",
        "onboarding.step.verifyIdentity",
        "onboarding.step.chooseStart",
        "onboarding.step.resumeImportOrQuickProfile",
        "onboarding.step.passportCreated"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingFlowReachesLockedHomeShell() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.step.welcome"].waitForExistence(timeout: 10))
        advanceThroughOnboarding(in: app)

        XCTAssertTrue(app.otherElements["candidate.tabShell"].exists)
        XCTAssertTrue(app.staticTexts["candidate.screen.home"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testDemoModeLaunchOverrideReachesDemoHomeShell() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KAIRO_DEMO_MODE"] = "true"
        app.launchEnvironment["KAIRO_APP_ENVIRONMENT"] = "staging"
        app.launch()

        XCTAssertTrue(app.staticTexts["onboarding.step.welcome"].waitForExistence(timeout: 10))
        advanceThroughOnboarding(in: app)

        XCTAssertTrue(app.staticTexts["candidate.screen.home"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["candidate.networkStatusMessage"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func advanceThroughOnboarding(in app: XCUIApplication) {
        for identifier in onboardingIdentifiers {
            XCTAssertTrue(app.staticTexts[identifier].waitForExistence(timeout: 10))
            app.buttons["onboarding.continue"].tap()
        }
    }
}
