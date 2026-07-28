import SwiftUI

@main
struct KairoApp: App {
    @StateObject private var router: AppRouter

    init() {
        let configuration = AppConfiguration.resolve()
        let dependencies = AppDependencies.make(configuration: configuration)

        _router = StateObject(wrappedValue: AppRouter())
        self.configuration = configuration
        self.dependencies = dependencies
    }

    private let configuration: AppConfiguration
    private let dependencies: AppDependencies

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(router)
                .environment(\.appConfiguration, configuration)
                .environment(\.networkClient, dependencies.networkClient)
                .environment(\.tokenStore, dependencies.tokenStore)
        }
    }
}
