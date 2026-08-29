import Foundation

struct AppDependencies: Sendable {
    let networkClient: any NetworkClient
    let tokenStore: any TokenStore
    let sessionService: any SessionServiceProtocol
    let authService: any AuthServiceProtocol
    let manualProfileService: any ManualProfileServiceProtocol
    let resumeImportService: any ResumeImportServiceProtocol
    let homeOverviewService: any HomeOverviewServiceProtocol
    let careerOverviewService: any CareerOverviewServiceProtocol
    let verifyOverviewService: any VerifyOverviewServiceProtocol
    let verificationInitiationService: any VerificationInitiationServiceProtocol
    let passportOverviewService: any PassportOverviewServiceProtocol
    let moreOverviewService: any MoreOverviewServiceProtocol

    static func make(
        configuration: AppConfiguration,
        uiTestConfiguration: UITestLaunchConfiguration = .current()
    ) -> AppDependencies {
        let tokenStore: any TokenStore = configuration.isDemoModeEnabled
            ? InMemoryTokenStore()
            : KeychainTokenStore(service: configuration.keychainService)

        let networkClient: any NetworkClient = configuration.isDemoModeEnabled
            ? DemoNetworkClient()
            : URLSessionNetworkClient(
                baseURL: configuration.apiBaseURL,
                session: .shared
            )

        let sessionService = SessionService(
            configuration: configuration,
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let authService: any AuthServiceProtocol

        if configuration.isDemoModeEnabled {
            authService = DemoAuthService(sessionService: sessionService)
        } else if uiTestConfiguration.isEnabled {
            authService = UITestAuthService(sessionService: sessionService)
        } else {
            authService = AuthService(
                configuration: configuration,
                networkClient: networkClient,
                sessionService: sessionService
            )
        }
        let manualProfileService: any ManualProfileServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoManualProfileService(authService: authService)
            } else {
                ManualProfileService(
                    authService: authService,
                    sessionService: sessionService
                )
            }
        let resumeImportService: any ResumeImportServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoResumeImportService()
            } else {
                ResumeImportService(
                    sessionService: sessionService,
                    authService: authService,
                    consentVersion: configuration.currentResumeImportConsentVersion
                )
            }
        let homeOverviewService = HomeOverviewService(
            authService: authService,
            sessionService: sessionService
        )
        let careerOverviewService = CareerOverviewService(
            authService: authService,
            sessionService: sessionService
        )
        let verifyOverviewService = VerifyOverviewService(
            sessionService: sessionService
        )
        let verificationInitiationService = VerificationInitiationService(
            careerService: careerOverviewService,
            sessionService: sessionService
        )
        let passportOverviewService = PassportOverviewService(
            sessionService: sessionService
        )
        let moreOverviewService = MoreOverviewService(
            sessionService: sessionService,
            bundleAppVersion: bundleAppVersion()
        )

        return AppDependencies(
            networkClient: networkClient,
            tokenStore: tokenStore,
            sessionService: sessionService,
            authService: authService,
            manualProfileService: manualProfileService,
            resumeImportService: resumeImportService,
            homeOverviewService: homeOverviewService,
            careerOverviewService: careerOverviewService,
            verifyOverviewService: verifyOverviewService,
            verificationInitiationService: verificationInitiationService,
            passportOverviewService: passportOverviewService,
            moreOverviewService: moreOverviewService
        )
    }

    private static func bundleAppVersion(bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = info["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }
}
