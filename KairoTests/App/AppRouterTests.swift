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
            [.createAccount, .verifyIdentity, .chooseStart, .resumeImportOrQuickProfile]
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
