import XCTest
@testable import Kairo

@MainActor
final class AppRouterTests: XCTestCase {
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
}
