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
    @Published private(set) var trustScorePresentation: TrustScorePresentation?
    @Published private(set) var careerDocumentPresentation: CareerDocumentPresentation?
    @Published private(set) var googleAuthenticationPresentation: GoogleAuthenticationPresentation?
    @Published var documentPackPresentation: DocumentPackPresentation?

    func showDocumentPacks(history: Bool = false) {
        documentPackPresentation = DocumentPackPresentation(history: history)
    }

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
        trustScorePresentation = nil
        careerDocumentPresentation = nil
        googleAuthenticationPresentation = nil
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

    func showPasswordReset(token: String) {
        rootDestination = .onboarding
        onboardingPath = [
            .loginPlaceholder,
            .resetPassword(token: token)
        ]
    }

    func showGooglePhoneCompletion() {
        rootDestination = .onboarding
        onboardingPath = [
            .loginPlaceholder,
            .googlePhoneCompletion
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
        configuration: AppConfiguration
    ) -> Bool {
        guard !configuration.isDemoModeEnabled else { return false }

        switch PublicPassportLinkParser.parse(url, allowedHosts: configuration.publicPassportHosts) {
        case .success(let destination):
            publicPassportPresentation = PublicPassportPresentation(content: .handoff(destination))
            return true
        case .failure(.unsupportedHost):
            break
        case .failure:
            guard PublicPassportLinkParser.targetsExpectedHost(
                url,
                allowedHosts: configuration.publicPassportHosts
            ) else {
                break
            }
            publicPassportPresentation = PublicPassportPresentation(content: .unavailable)
            return true
        }

        guard let destination = AppLinkParser.parse(url, configuration: configuration) else {
            return false
        }

        switch destination {
        case .googleHandoff(let code):
            googleAuthenticationPresentation = GoogleAuthenticationPresentation(handoffCode: code)
        case .passwordReset(let token):
            showPasswordReset(token: token)
        }
        return true
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

    func showTrustScoreDetails() {
        trustScorePresentation = TrustScorePresentation()
    }

    func dismissTrustScoreDetails() {
        trustScorePresentation = nil
    }

    func showCareerDocuments(for parent: CareerDocumentParent) {
        careerDocumentPresentation = CareerDocumentPresentation(parent: parent)
    }

    func dismissCareerDocuments() {
        careerDocumentPresentation = nil
    }

    func dismissGoogleAuthentication() {
        googleAuthenticationPresentation = nil
    }
}
