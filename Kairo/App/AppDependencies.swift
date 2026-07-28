import Foundation

struct AppDependencies: Sendable {
    let networkClient: any NetworkClient
    let tokenStore: any TokenStore

    static func make(configuration: AppConfiguration) -> AppDependencies {
        if configuration.isDemoModeEnabled {
            return AppDependencies(
                networkClient: DemoNetworkClient(),
                tokenStore: InMemoryTokenStore()
            )
        }

        return AppDependencies(
            networkClient: URLSessionNetworkClient(
                baseURL: configuration.apiBaseURL,
                session: .shared
            ),
            tokenStore: KeychainTokenStore(service: configuration.keychainService)
        )
    }
}
