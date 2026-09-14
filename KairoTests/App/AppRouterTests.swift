import XCTest
@testable import Kairo

@MainActor
final class AppRouterTests: XCTestCase {
    func test_notificationCenterUsesCanonicalRouterPresentation() {
        let router = AppRouter(rootDestination: .mainTabs)

        XCTAssertNil(router.notificationCenterPresentation)
        router.showNotificationCenter()
        XCTAssertNotNil(router.notificationCenterPresentation)

        router.dismissNotificationCenter()
        XCTAssertNil(router.notificationCenterPresentation)
        XCTAssertEqual(router.rootDestination, .mainTabs)
    }

    func test_onboardingAdvancesIntoMainTabs() {
        let router = AppRouter()

        for step in OnboardingStep.allCases {
            router.advanceOnboarding(from: step)
        }

        XCTAssertEqual(router.rootDestination, .mainTabs)
        XCTAssertEqual(router.selectedTab, .home)
    }

    func test_selectingTabForcesMainShell() {
        let router = AppRouter()

        router.selectTab(.passport)

        XCTAssertEqual(router.rootDestination, .mainTabs)
        XCTAssertEqual(router.selectedTab, .passport)
    }

    func test_homeVerificationFocusPreservesAuthoritativeIdentifier() {
        let router = AppRouter()
        let refreshStore = CandidateDataRefreshStore()

        refreshStore.focusVerificationRequest(identifier: "request_123")
        router.selectTab(.verify)

        XCTAssertEqual(refreshStore.focusedVerificationRequestID, "request_123")
        XCTAssertEqual(router.rootDestination, .mainTabs)
        XCTAssertEqual(router.selectedTab, .verify)
    }

    func test_navigatingToIntermediateOnboardingStepBuildsExpectedPath() {
        let router = AppRouter()

        router.navigateToOnboarding(.resumeImportOrQuickProfile)

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(
            router.onboardingPath,
            [
                .step(.createAccount),
                .step(.verifyIdentity),
                .step(.chooseStart),
                .step(.resumeImportOrQuickProfile)
            ]
        )
    }

    func test_existingAccountRouteUsesLoginPlaceholder() {
        let router = AppRouter()

        router.showLoginPlaceholder()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [.loginPlaceholder])
    }

    func test_forgotPasswordUsesExistingOnboardingNavigationStack() {
        let router = AppRouter()

        router.showForgotPassword(initialEmail: "aman@example.com")

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(
            router.onboardingPath,
            [
                .loginPlaceholder,
                .forgotPassword(initialEmail: "aman@example.com")
            ]
        )
    }

    func test_passwordResetLinkUsesExistingOnboardingNavigationStack() throws {
        let router = AppRouter()
        let token = String(repeating: "R", count: 43)
        let configuration = stagingConfiguration()
        let url = try XCTUnwrap(URL(string: "https://app.kairoid.com/reset-password-confirm?token=\(token)"))

        XCTAssertTrue(router.handleIncomingURL(url, configuration: configuration))
        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [.loginPlaceholder, .resetPassword(token: token)])
    }

    func test_googleHandoffUsesRedactedOneTimePresentationWithoutChangingNavigation() throws {
        let router = AppRouter(rootDestination: .onboarding)
        let code = String(repeating: "G", count: 43)
        let configuration = stagingConfiguration()
        let url = try XCTUnwrap(URL(string: "https://staging-api.kairoid.com/auth/google/complete?code=\(code)"))

        XCTAssertTrue(router.handleIncomingURL(url, configuration: configuration))
        XCTAssertEqual(router.rootDestination, .onboarding)
        let presentation = try XCTUnwrap(router.googleAuthenticationPresentation)
        XCTAssertEqual(presentation.handoffCode, code)
        XCTAssertFalse(presentation.description.contains(code))
        XCTAssertTrue(presentation.description.contains("<redacted>"))
    }

    func test_appLinksRejectWrongSchemeHostExtraQueriesAndShortSecrets() throws {
        let router = AppRouter()
        let configuration = stagingConfiguration()
        let code = String(repeating: "G", count: 43)
        let values = [
            "http://staging-api.kairoid.com/auth/google/complete?code=\(code)",
            "https://example.com/auth/google/complete?code=\(code)",
            "https://staging-api.kairoid.com/auth/google/complete?code=\(code)&other=value",
            "https://app.kairoid.com/reset-password-confirm?token=short"
        ]

        for value in values {
            XCTAssertFalse(router.handleIncomingURL(try XCTUnwrap(URL(string: value)), configuration: configuration))
        }
        XCTAssertNil(router.googleAuthenticationPresentation)
    }

    func test_identityChangeResetClearsFocusedRequestAndInvalidatesAllCandidateCaches() {
        let refreshStore = CandidateDataRefreshStore()
        refreshStore.focusVerificationRequest(identifier: "account-a-request")
        let initialRevision = refreshStore.revision

        refreshStore.resetForIdentityChange()

        XCTAssertNil(refreshStore.focusedVerificationRequestID)
        XCTAssertEqual(refreshStore.revision, initialRevision + 1)
    }

    func test_lockedNavigationRemainsInExpectedOrder() {
        XCTAssertEqual(CandidateTab.allCases.map(\.title), ["Home", "Career", "Verify", "Passport", "More"])
        XCTAssertEqual(
            OnboardingStep.allCases.map(\.title),
            [
                "Welcome",
                "Create Account",
                "Verify Identity",
                "Choose Start",
                "Resume Import or Quick Profile",
                "Passport Created"
            ]
        )
    }

    private func stagingConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .staging,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.app-links"
        )
    }
}
