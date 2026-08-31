import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var rootDestination: RootDestination
    @Published var selectedTab: CandidateTab
    @Published var onboardingPath: [OnboardingDestination]

    init(
        rootDestination: RootDestination = .onboarding,
        selectedTab: CandidateTab = .home,
        onboardingPath: [OnboardingDestination] = []
    ) {
        self.rootDestination = rootDestination
        self.selectedTab = selectedTab
        self.onboardingPath = onboardingPath
    }

    func showOnboarding() {
        if rootDestination != .onboarding {
            rootDestination = .onboarding
        }
        onboardingPath = []
    }

    func navigateToOnboarding(_ step: OnboardingStep) {
        if rootDestination != .onboarding {
            rootDestination = .onboarding
        }
        onboardingPath = OnboardingStep.destinationPath(to: step)
    }

    func showLoginPlaceholder() {
        showLogin()
    }

    func showLogin() {
        if rootDestination != .onboarding {
            rootDestination = .onboarding
        }
        onboardingPath = [.loginPlaceholder]
    }

    func showForgotPassword(initialEmail: String = "") {
        if rootDestination != .onboarding {
            rootDestination = .onboarding
        }
        onboardingPath = [
            .loginPlaceholder,
            .forgotPassword(initialEmail: initialEmail)
        ]
    }

    func advanceOnboarding(from step: OnboardingStep) {
        let currentPath = OnboardingStep.destinationPath(to: step)

        if let next = step.next {
            onboardingPath = currentPath + [.step(next)]
        } else {
            enterMainTabs()
        }
    }

    func goBackOnboarding(from step: OnboardingStep) {
        let path = OnboardingStep.path(to: step)
        guard path.count > 1 else {
            onboardingPath = []
            return
        }

        onboardingPath = Array(path.dropFirst().dropLast()).map(OnboardingDestination.step)
    }

    func enterMainTabs(selectedTab: CandidateTab = .home) {
        rootDestination = .mainTabs
        self.selectedTab = selectedTab
    }

    func selectTab(_ tab: CandidateTab) {
        rootDestination = .mainTabs
        selectedTab = tab
    }
}
