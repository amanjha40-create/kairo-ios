import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var rootDestination: RootDestination
    @Published var selectedTab: CandidateTab
    @Published var onboardingPath: [OnboardingDestination]
    @Published private(set) var publicPassportPresentation: PublicPassportPresentation?
    @Published private(set) var passportActivityRequestID: UUID?
    @Published private(set) var notificationCenterPresentation: NotificationCenterPresentation?

    init(
        rootDestination: RootDestination = .onboarding,
        selectedTab: CandidateTab = .home,
        onboardingPath: [OnboardingDestination] = []
    ) {
        self.rootDestination = rootDestination
        self.selectedTab = selectedTab
        self.onboardingPath = onboardingPath
        publicPassportPresentation = nil
        passportActivityRequestID = nil
        notificationCenterPresentation = nil
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

    @discardableResult
    func handleIncomingURL(
        _ url: URL,
        allowedPublicPassportHosts: Set<String>,
        isDemoModeEnabled: Bool
    ) -> Bool {
        guard !isDemoModeEnabled else { return false }

        switch PublicPassportLinkParser.parse(url, allowedHosts: allowedPublicPassportHosts) {
        case .success(let destination):
            publicPassportPresentation = PublicPassportPresentation(content: .handoff(destination))
            return true
        case .failure(.unsupportedHost):
            return false
        case .failure:
            guard PublicPassportLinkParser.targetsExpectedHost(
                url,
                allowedHosts: allowedPublicPassportHosts
            ) else {
                return false
            }
            publicPassportPresentation = PublicPassportPresentation(content: .unavailable)
            return true
        }
    }

    func dismissPublicPassportPresentation() {
        publicPassportPresentation = nil
    }

    func showPassportActivity() {
        enterMainTabs(selectedTab: .passport)
        passportActivityRequestID = UUID()
    }

    func consumePassportActivityRequest() {
        passportActivityRequestID = nil
    }

    func showNotificationCenter() {
        notificationCenterPresentation = NotificationCenterPresentation()
    }

    func dismissNotificationCenter() {
        notificationCenterPresentation = nil
    }
}
