import Foundation

struct AppDependencies: Sendable {
    let networkClient: any NetworkClient
    let tokenStore: any TokenStore
    let sessionService: any SessionServiceProtocol
    let authService: any AuthServiceProtocol
    let manualProfileService: any ManualProfileServiceProtocol
    let homeOverviewService: any HomeOverviewServiceProtocol
    let careerOverviewService: any CareerOverviewServiceProtocol
    let verifyOverviewService: any VerifyOverviewServiceProtocol
    let passportOverviewService: any PassportOverviewServiceProtocol

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
        let passportOverviewService = PassportOverviewService(
            sessionService: sessionService
        )

        return AppDependencies(
            networkClient: networkClient,
            tokenStore: tokenStore,
            sessionService: sessionService,
            authService: authService,
            manualProfileService: manualProfileService,
            homeOverviewService: homeOverviewService,
            careerOverviewService: careerOverviewService,
            verifyOverviewService: verifyOverviewService,
            passportOverviewService: passportOverviewService
        )
    }
}
