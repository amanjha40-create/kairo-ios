import Foundation

struct AppDependencies: Sendable {
    let networkClient: any NetworkClient
    let tokenStore: any TokenStore
    let sessionService: any SessionServiceProtocol
    let authService: any AuthServiceProtocol

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

        if configuration.isDemoModeEnabled {
            return AppDependencies(
                networkClient: networkClient,
                tokenStore: tokenStore,
                sessionService: sessionService,
                authService: DemoAuthService(sessionService: sessionService)
            )
        }

        return AppDependencies(
            networkClient: networkClient,
            tokenStore: tokenStore,
            sessionService: sessionService,
            authService: uiTestConfiguration.isEnabled
                ? UITestAuthService(sessionService: sessionService)
                : AuthService(configuration: configuration, networkClient: networkClient, sessionService: sessionService)
        )
    }
}
