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
    @Published private(set) var currentUser: AppUser?

    private let configuration: AppConfiguration
    private let uiTestConfiguration: UITestLaunchConfiguration
    private let router: AppRouter
    private let authService: any AuthServiceProtocol
    private let sessionService: any SessionServiceProtocol
    private var hasBootstrapped = false

    init(
        configuration: AppConfiguration,
        uiTestConfiguration: UITestLaunchConfiguration,
        router: AppRouter,
        authService: any AuthServiceProtocol,
        sessionService: any SessionServiceProtocol
    ) {
        self.configuration = configuration
        self.uiTestConfiguration = uiTestConfiguration
        self.router = router
        self.authService = authService
        self.sessionService = sessionService
    }

    func bootstrapIfNeeded() async {
        guard !hasBootstrapped else {
            return
        }

        hasBootstrapped = true

        guard !configuration.isDemoModeEnabled, !uiTestConfiguration.isEnabled else {
            return
        }

        await refreshLaunchRoute()
    }

    func refreshLaunchRoute() async {
        launchPhase = .bootstrapping

        do {
            let launchRoute = try await resolveLaunchRoute()
            applyLaunchRoute(launchRoute)
            launchPhase = .idle
        } catch {
            if shouldFallBackToSignedOut(for: error) {
                currentUser = nil
                router.showOnboarding()
                launchPhase = .idle
            } else {
                launchPhase = .failed(authMessage(for: error))
            }
        }
    }

    func completeAuthenticationAndRoute() async {
        await refreshLaunchRoute()
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
        router.showOnboarding()
        launchPhase = .idle
    }

    private func resolveLaunchRoute() async throws -> AppLaunchRoute {
        let hasAccessToken = try await sessionService.hasStoredAccessToken()
        let hasRefreshToken = try await sessionService.hasStoredRefreshToken()

        if !hasAccessToken, !hasRefreshToken {
            if try await sessionService.readSignupSessionID() != nil {
                return .verifyIdentity
            }

            return .signedOut
        }

        _ = try await sessionService.prepareBootstrapSession()
        currentUser = try await authService.currentUser().asDomainModel()
        let onboardingStatus = try await authService.onboardingStatus()

        if onboardingStatus.isOnboardingComplete {
            return .mainTabs
        }

        guard let currentStep = onboardingStatus.resolvedCurrentStep else {
            throw AppSessionStoreError.unsupportedOnboardingStep(onboardingStatus.currentStep)
        }

        switch currentStep {
        case .verifyIdentity:
            return .verifyIdentity
        case .completeProfile:
            return .completeProfile(.chooseStart)
        case .complete:
            return .mainTabs
        }
    }

    private func applyLaunchRoute(_ route: AppLaunchRoute) {
        switch route {
        case .signedOut:
            router.showOnboarding()
        case .verifyIdentity:
            router.navigateToOnboarding(.verifyIdentity)
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

    private func authMessage(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api(let apiError):
                return apiError.message
            case .transport:
                return "Kairo couldn't reach the network. Check your connection and try again."
            case .unavailableInDemoMode:
                return "Demo Mode keeps authentication local."
            case .invalidResponse:
                return "Kairo received an unexpected response while restoring your session."
            case .invalidURL:
                return "Kairo's API configuration is invalid."
            }
        case let sessionError as SessionServiceError:
            return sessionError.errorDescription ?? "Kairo couldn't restore your session."
        case let appSessionError as AppSessionStoreError:
            return appSessionError.errorDescription ?? "Kairo couldn't restore your session."
        default:
            return error.localizedDescription
        }
    }
}

private enum AppLaunchRoute: Equatable {
    case signedOut
    case verifyIdentity
    case completeProfile(OnboardingStep)
    case mainTabs
}

private enum AppSessionStoreError: LocalizedError {
    case unsupportedOnboardingStep(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOnboardingStep(let step):
            "Kairo needs an app update before it can continue this onboarding step (\(step))."
        }
    }
}
