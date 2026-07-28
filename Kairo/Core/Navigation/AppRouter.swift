import Combine

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var rootDestination: RootDestination
    @Published var selectedTab: CandidateTab
    @Published var onboardingPath: [OnboardingStep]

    init(
        rootDestination: RootDestination = .onboarding,
        selectedTab: CandidateTab = .home,
        onboardingPath: [OnboardingStep] = []
    ) {
        self.rootDestination = rootDestination
        self.selectedTab = selectedTab
        self.onboardingPath = onboardingPath
    }

    func showOnboarding() {
        rootDestination = .onboarding
        onboardingPath = []
    }

    func navigateToOnboarding(_ step: OnboardingStep) {
        rootDestination = .onboarding
        onboardingPath = Array(OnboardingStep.path(to: step).dropFirst())
    }

    func advanceOnboarding(from step: OnboardingStep) {
        let currentPath = Array(OnboardingStep.path(to: step).dropFirst())

        if let next = step.next {
            onboardingPath = currentPath + [next]
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

        onboardingPath = Array(path.dropFirst().dropLast())
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
