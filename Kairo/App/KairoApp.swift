import SwiftUI
import UIKit

@main
struct KairoApp: App {
    @StateObject private var router: AppRouter
    @StateObject private var sessionStore: AppSessionStore

    init() {
        let configuration = AppConfiguration.resolve()
        let uiTestConfiguration = UITestLaunchConfiguration.current()
        let dependencies = AppDependencies.make(
            configuration: configuration,
            uiTestConfiguration: uiTestConfiguration
        )

        if uiTestConfiguration.disablesAnimations {
            UIView.setAnimationsEnabled(false)
        }

        let router = AppRouter(
            rootDestination: uiTestConfiguration.route == .demoHome ? .mainTabs : .onboarding,
            selectedTab: .home,
            onboardingPath: uiTestConfiguration.route == .demoHome
                ? []
                : uiTestConfiguration.onboardingStep.map(OnboardingStep.destinationPath(to:)) ?? []
        )

        _router = StateObject(wrappedValue: router)
        _sessionStore = StateObject(wrappedValue: AppSessionStore(
            configuration: configuration,
            uiTestConfiguration: uiTestConfiguration,
            router: router,
            authService: dependencies.authService,
            sessionService: dependencies.sessionService
        ))
        self.configuration = configuration
        self.dependencies = dependencies
    }

    private let configuration: AppConfiguration
    private let dependencies: AppDependencies

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(router)
                .environmentObject(sessionStore)
                .environment(\.appConfiguration, configuration)
                .environment(\.networkClient, dependencies.networkClient)
                .environment(\.tokenStore, dependencies.tokenStore)
                .environment(\.authService, dependencies.authService)
                .environment(\.homeOverviewService, dependencies.homeOverviewService)
        }
    }
}
