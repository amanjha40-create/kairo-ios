import Combine
import Foundation

@MainActor
final class AppSessionStore: ObservableObject {
    enum LaunchPhase: Equatable {
        case idle
        case bootstrapping
        case failed(String)
    }

    @Published private(set) var launchPhase: LaunchPhase = .idle
    @Published private(set) var currentUser: AppUser? {
        didSet {
            if oldValue?.id != currentUser?.id,
               !LocalBatch1QA.isEnabled(configuration: configuration) {
                DocumentPreviewFileStore.shared.clear()
            }
        }
    }
    @Published private(set) var signupRecovery: SignupSessionRecoveryResponseDTO?
    @Published private(set) var pendingGoogleSignup: SignupStartResponseDTO?
    @Published private(set) var authenticatedVerificationStatus: OnboardingStatusResponseDTO?

    private let configuration: AppConfiguration
    private let uiTestConfiguration: UITestLaunchConfiguration
    private let router: AppRouter
    private let authService: any AuthServiceProtocol
    private let sessionService: any SessionServiceProtocol
    private let manualProfileService: any ManualProfileServiceProtocol
    private let resumeImportService: any ResumeImportServiceProtocol
    private let guidedTourPreferences: any GuidedTourPreferenceStoring
    private var hasBootstrapped = false

    init(
        configuration: AppConfiguration,
        uiTestConfiguration: UITestLaunchConfiguration,
        router: AppRouter,
        authService: any AuthServiceProtocol,
        sessionService: any SessionServiceProtocol,
        manualProfileService: any ManualProfileServiceProtocol,
        resumeImportService: any ResumeImportServiceProtocol,
        guidedTourPreferences: (any GuidedTourPreferenceStoring)? = nil
    ) {
        self.configuration = configuration
        self.uiTestConfiguration = uiTestConfiguration
        self.router = router
        self.authService = authService
        self.sessionService = sessionService
        self.manualProfileService = manualProfileService
        self.resumeImportService = resumeImportService
        self.guidedTourPreferences = guidedTourPreferences ?? GuidedTourPreferences()
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else {
            return
        }

        hasBootstrapped = true

        #if !KAIRO_PRODUCTION || KAIRO_LOCAL_BATCH1_QA
        // Direct-to-Home UI fixtures normally skip bootstrap. Only this explicit
        // synthetic DOB scenario needs a canonical fixture profile for Verify.
        if uiTestConfiguration.isEnabled,
           ProcessInfo.processInfo.environment["KAIRO_UI_TEST_DIGILOCKER_DOB"] == "present" {
            currentUser = try? await authService.currentUser().asDomainModel()
        }
        if uiTestConfiguration.isEnabled,
           ProcessInfo.processInfo.environment["KAIRO_UI_TEST_PROFILE_TASKS"] == "1" {
            currentUser = ProfileSnapshot.fixture.user
        }
        #endif

        guard !configuration.isDemoModeEnabled, !uiTestConfiguration.isEnabled else {
            return
        }

        await refreshLaunchRoute()
    }

    func refreshLaunchRoute(armNewAccountTour: Bool = false) async {
        authenticatedVerificationStatus = nil
        GoogleReturnDiagnostics.emit(.bootstrapStarted)
        launchPhase = .bootstrapping

        do {
            let launchRoute = try await resolveLaunchRoute(armNewAccountTour: armNewAccountTour)
            applyLaunchRoute(launchRoute)
            launchPhase = .idle
            GoogleReturnDiagnostics.emit(.bootstrapSucceeded, state: router.diagnosticAuthRoot)
        } catch {
            GoogleReturnDiagnostics.emit(.bootstrapFailed)
            if shouldFallBackToSignedOut(for: error) {
                currentUser = nil
                pendingGoogleSignup = nil
                router.showOnboarding()
                launchPhase = .idle
            } else {
                launchPhase = .failed(authMessage(for: error))
            }
        }
    }

    func completeAuthenticationAndRoute() async {
        guidedTourPreferences.clearPendingStates()
        await refreshLaunchRoute()
    }

    func completeNewAccountAuthenticationAndRoute() async {
        guidedTourPreferences.clearPendingStates()
        await refreshLaunchRoute(armNewAccountTour: true)
    }

    func replaceCurrentUser(_ user: AppUser?) {
        currentUser = user
    }

    func signOut() async {
        launchPhase = .bootstrapping

        do {
            try await authService.logout()
        } catch {
            launchPhase = .failed(authMessage(for: error))
            return
        }

        currentUser = nil
        authenticatedVerificationStatus = nil
        signupRecovery = nil
        pendingGoogleSignup = nil
        guidedTourPreferences.clearPendingStates()
        ManualProfileDraftStore.clear()
        router.showOnboarding()
        launchPhase = .idle
    }

    func abandonPendingSignup() async {
        authenticatedVerificationStatus = nil
        try? await sessionService.clearSignupSessionID()
        signupRecovery = nil
        pendingGoogleSignup = nil
        guidedTourPreferences.clearPendingStates()
        ManualProfileDraftStore.clear()
        currentUser = nil
        router.navigateToOnboarding(.createAccount)
        launchPhase = .idle
    }

    func completeAccountDeletion() async {
        authenticatedVerificationStatus = nil
        try? await sessionService.clearSession()
        signupRecovery = nil
        pendingGoogleSignup = nil
        guidedTourPreferences.clearPendingStates()
        ManualProfileDraftStore.clear()
        currentUser = nil
        router.showOnboarding()
        launchPhase = .idle
    }

    func continueGooglePhoneSignup(_ signup: SignupStartResponseDTO) {
        authenticatedVerificationStatus = nil
        currentUser = nil
        signupRecovery = nil
        pendingGoogleSignup = signup
        router.showGooglePhoneCompletion()
        launchPhase = .idle
    }

    func continueGooglePhoneVerification(_ signup: SignupStartResponseDTO) {
        authenticatedVerificationStatus = nil
        currentUser = nil
        signupRecovery = nil
        pendingGoogleSignup = signup
        router.navigateToOnboarding(.verifyIdentity)
        launchPhase = .idle
    }

    private func resolveLaunchRoute(armNewAccountTour: Bool = false) async throws -> AppLaunchRoute {
        let hasAccessToken = try await sessionService.hasStoredAccessToken()
        let hasRefreshToken = try await sessionService.hasStoredRefreshToken()

        if !hasAccessToken, !hasRefreshToken {
            if try await sessionService.readSignupSessionID() != nil {
                do {
                    let recovery = try await authService.recoverSignupSession()

                    switch recovery.state {
                    case .valid:
                        guard recovery.nextStep != nil else {
                            throw AppSessionStoreError.invalidSignupRecoveryState
                        }
                        signupRecovery = recovery
                        if recovery.nextStep == .verifyPhone,
                           recovery.phoneMasked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return .googlePhoneCompletion
                        }
                        return .verifyIdentity
                    case .completed, .expired:
                        try? await sessionService.clearSignupSessionID()
                        signupRecovery = nil
                        pendingGoogleSignup = nil
                        return .signedOut
                    }
                } catch {
                    if shouldDiscardSignupSession(for: error) {
                        try? await sessionService.clearSignupSessionID()
                        signupRecovery = nil
                        pendingGoogleSignup = nil
                        return .signedOut
                    }

                    throw error
                }
            }

            signupRecovery = nil
            pendingGoogleSignup = nil
            return .signedOut
        }

        _ = try await sessionService.prepareBootstrapSession()
        signupRecovery = nil
        pendingGoogleSignup = nil
        currentUser = try await authService.currentUser().asDomainModel()
        if armNewAccountTour, let accountID = currentUser?.id {
            guidedTourPreferences.markPendingIfEligible(for: accountID)
        }
        let onboardingStatus = try await authService.onboardingStatus()

        if onboardingStatus.isOnboardingComplete {
            return .mainTabs
        }

        guard let currentStep = onboardingStatus.resolvedCurrentStep else {
            throw AppSessionStoreError.unsupportedOnboardingStep(onboardingStatus.currentStep)
        }

        switch currentStep {
        case .verifyIdentity:
            authenticatedVerificationStatus = onboardingStatus
            return .verifyIdentity
        case .completeProfile:
            if !configuration.isDemoModeEnabled,
               !uiTestConfiguration.isEnabled,
               ManualProfileDraftStore.hasSavedDraft {
                return .completeProfile(.resumeImportOrQuickProfile)
            }

            if !configuration.isDemoModeEnabled,
               !uiTestConfiguration.isEnabled,
               let restoredDraft = await restoredRemainingProfileDraftIfAvailable() {
                ManualProfileDraftStore.save(restoredDraft)
                return .completeProfile(.resumeImportOrQuickProfile)
            }

            return .completeProfile(.chooseStart)
        case .complete:
            return .mainTabs
        }
    }

    private func restoredRemainingProfileDraftIfAvailable() async -> ManualProfileFlowState? {
        do {
            guard let snapshot = try await resumeImportService.restoreLatestWorkflow(),
                  let reviewSession = snapshot.reviewSession
            else {
                return nil
            }

            let recovery = try await resumeImportService.reconcileImportRecovery(
                reviewID: reviewSession.id
            )

            guard recovery.disposition == .importCompleted else {
                return nil
            }

            guard let completionResult = recovery.completionResult else {
                return nil
            }

            let onboardingStatus = completionResult.onboardingStatus
            guard !onboardingStatus.isOnboardingComplete,
                  onboardingStatus.resolvedCurrentStep == .completeProfile
            else {
                return nil
            }

            return try await manualProfileService.prepareRemainingProfileDraft(
                signupDraftFullName: nil
            )
        } catch {
            return nil
        }
    }

    private func applyLaunchRoute(_ route: AppLaunchRoute) {
        switch route {
        case .signedOut:
            currentUser = nil
            router.showOnboarding()
        case .verifyIdentity:
            router.navigateToOnboarding(.verifyIdentity)
        case .googlePhoneCompletion:
            router.showGooglePhoneCompletion()
        case .completeProfile(let step):
            router.navigateToOnboarding(step)
        case .mainTabs:
            router.enterMainTabs(selectedTab: .home)
        }
    }

    private func shouldFallBackToSignedOut(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        if let networkError = error as? NetworkError,
           case .api(let apiError) = networkError,
           apiError.code == .unauthorized {
            return true
        }

        return false
    }

    private func shouldDiscardSignupSession(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError,
           sessionError == .missingSignupSession {
            return true
        }

        guard let networkError = error as? NetworkError,
              case .api(let apiError) = networkError else {
            return false
        }

        return switch apiError.code {
        case .unauthorized, .forbidden, .notFound, .validationError:
            true
        case .badRequest, .conflict, .rateLimited, .internalError, .serviceUnavailable:
            false
        }
    }

    private func authMessage(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api(let apiError):
                return switch apiError.code {
                case .badRequest, .validationError:
                    "Review your authentication details and try again."
                case .unauthorized:
                    "Your session expired. Sign in again."
                case .forbidden:
                    "This account cannot complete the requested authentication action."
                case .notFound:
                    "KairoID could not find the account or signup session. Start again."
                case .conflict:
                    "Your account state changed. Refresh and try again."
                case .rateLimited:
                    "Too many authentication attempts were made. Wait briefly, then try again."
                case .internalError:
                    "KairoID couldn't restore your session. Please try again."
                case .serviceUnavailable:
                    "Authentication is temporarily unavailable. Please try again shortly."
                }
            case .transport:
                return "KairoID couldn't reach the network. Check your connection and try again."
            case .unavailableInDemoMode:
                return "Demo Mode keeps authentication local."
            case .invalidResponse:
                return "KairoID received an unexpected response while restoring your session."
            case .invalidURL:
                return "KairoID's API configuration is invalid."
            }
        case let sessionError as SessionServiceError:
            return sessionError.errorDescription ?? "KairoID couldn't restore your session."
        case let appSessionError as AppSessionStoreError:
            return appSessionError.errorDescription ?? "KairoID couldn't restore your session."
        default:
            return "KairoID couldn't restore your session. Please try again."
        }
    }
}

private enum AppLaunchRoute: Equatable {
    case signedOut
    case verifyIdentity
    case googlePhoneCompletion
    case completeProfile(OnboardingStep)
    case mainTabs
}

private enum AppSessionStoreError: LocalizedError {
    case unsupportedOnboardingStep(String)
    case invalidSignupRecoveryState

    var errorDescription: String? {
        switch self {
        case .unsupportedOnboardingStep:
            "KairoID needs an app update before it can continue this onboarding step."
        case .invalidSignupRecoveryState:
            "KairoID received an incomplete signup recovery response. Please try again."
        }
    }
}
