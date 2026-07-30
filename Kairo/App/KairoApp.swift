import SwiftUI
import UIKit

@main
struct KairoApp: App {
    @StateObject private var router: AppRouter

    init() {
        let configuration = AppConfiguration.resolve()
        let dependencies = AppDependencies.make(configuration: configuration)
        let uiTestConfiguration = UITestLaunchConfiguration.current()

        if uiTestConfiguration.disablesAnimations {
            UIView.setAnimationsEnabled(false)
        }

        _router = StateObject(wrappedValue: AppRouter(
            rootDestination: uiTestConfiguration.route == .demoHome ? .mainTabs : .onboarding,
            selectedTab: .home,
            onboardingPath: uiTestConfiguration.route == .demoHome
                ? []
                : uiTestConfiguration.onboardingStep.map(OnboardingStep.destinationPath(to:)) ?? []
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
                .environment(\.appConfiguration, configuration)
                .environment(\.networkClient, dependencies.networkClient)
                .environment(\.tokenStore, dependencies.tokenStore)
        }
    }
}
