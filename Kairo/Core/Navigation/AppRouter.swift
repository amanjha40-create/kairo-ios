import Combine
import Foundation

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var rootDestination: RootDestination
    @Published var selectedTab: CandidateTab
    @Published var showsCareerVerification = false
    @Published var requestedMoreDestination: MoreHubDestination?
    @Published var showsDocumentsHub = false
    @Published var trustInvitationPresentation: TrustInvitationPresentation?
    var pendingTrustInvitation: TrustInvitationPresentation?

    func showMoreSettings() {
        selectTab(.more)
        requestedMoreDestination = .settings
    }
    @Published var onboardingPath: [OnboardingDestination]
    @Published private(set) var publicPassportPresentation: PublicPassportPresentation?
    @Published private(set) var passportActivityRequestID: UUID?
    @Published private(set) var notificationCenterPresentation: NotificationCenterPresentation?
    @Published private(set) var trustScorePresentation: TrustScorePresentation?
    @Published private(set) var careerDocumentPresentation: CareerDocumentPresentation?
    @Published private(set) var googleAuthenticationPresentation: GoogleAuthenticationPresentation?
    @Published private(set) var digiLockerPresentation: DigiLockerHubPresentation?
    @Published var documentPackPresentation: DocumentPackPresentation?

    var diagnosticAuthRoot: GoogleReturnDiagnostics.State {
        guard rootDestination == .onboarding else { return .mainTabs }
        switch onboardingPath.last {
        case nil: return .welcome
        case .loginPlaceholder, .forgotPassword, .resetPassword: return .login
        case .step, .googlePhoneCompletion: return .onboarding
        }
    }

    func showDocumentPacks(history: Bool = false) {
        documentPackPresentation = DocumentPackPresentation(history: history)
    }

    init(
        rootDestination: RootDestination = .onboarding,
        selectedTab: CandidateTab = .home,
        onboardingPath: [OnboardingDestination] = []
    ) {
        self.rootDestination = rootDestination
        self.selectedTab = selectedTab == .verify ? .career : selectedTab
        self.showsCareerVerification = selectedTab == .verify
        self.onboardingPath = onboardingPath
        publicPassportPresentation = nil
        passportActivityRequestID = nil
        notificationCenterPresentation = nil
        trustScorePresentation = nil
        careerDocumentPresentation = nil
        googleAuthenticationPresentation = nil
        digiLockerPresentation = nil
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
        selectTab(selectedTab)
    }

    func selectTab(_ tab: CandidateTab) {
        rootDestination = .mainTabs
        selectedTab = tab == .verify ? .career : tab
        showsCareerVerification = tab == .verify
    }

    @discardableResult
    func handleIncomingURL(
        _ url: URL,
        configuration: AppConfiguration,
        diagnosticDeliveryID: UUID = UUID()
    ) -> Bool {
        GoogleReturnDiagnostics.emit(.routerReceived, deliveryID: diagnosticDeliveryID, link: .init(url))
        guard !configuration.isDemoModeEnabled else { return false }

        if configuration.environment == .staging,
           let invitation = TrustInvitationPresentation.parse(url, allowedHosts: configuration.documentPackHosts) {
            trustInvitationPresentation = invitation
            return true
        }

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

        guard let destination = AppLinkParser.parse(url, configuration: configuration, diagnostic: { reason in
            GoogleReturnDiagnostics.emitParserResult(reason, deliveryID: diagnosticDeliveryID)
        }) else {
            GoogleReturnDiagnostics.emit(.linkValidated, deliveryID: diagnosticDeliveryID, state: .rejected, link: .init(url))
            return false
        }

        switch destination {
        case .googleHandoff(let code):
            GoogleReturnDiagnostics.emit(.linkValidated, deliveryID: diagnosticDeliveryID, state: .accepted, link: .init(url))
            googleAuthenticationPresentation = GoogleAuthenticationPresentation(
                handoffCode: code, diagnosticDeliveryID: diagnosticDeliveryID
            )
            GoogleReturnDiagnostics.emit(.presentationCreated, deliveryID: diagnosticDeliveryID)
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

    func showDigiLocker() {
        digiLockerPresentation = DigiLockerHubPresentation()
    }

    func dismissDigiLocker() {
        digiLockerPresentation = nil
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
