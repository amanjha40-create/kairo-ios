import SwiftUI
import UIKit

@main
struct KairoApp: App {
    @StateObject private var router: AppRouter
    @StateObject private var sessionStore: AppSessionStore
    @StateObject private var candidateDataRefreshStore: CandidateDataRefreshStore
    @StateObject private var candidateNotificationStore: CandidateNotificationStore

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
            sessionService: dependencies.sessionService,
            manualProfileService: dependencies.manualProfileService,
            resumeImportService: dependencies.resumeImportService
        ))
        _candidateDataRefreshStore = StateObject(wrappedValue: CandidateDataRefreshStore())
        _candidateNotificationStore = StateObject(wrappedValue: CandidateNotificationStore(
            service: dependencies.candidateNotificationService
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
                .environmentObject(candidateDataRefreshStore)
                .environmentObject(candidateNotificationStore)
                .environment(\.appConfiguration, configuration)
                .environment(\.networkClient, dependencies.networkClient)
                .environment(\.tokenStore, dependencies.tokenStore)
                .environment(\.authService, dependencies.authService)
                .environment(\.manualProfileService, dependencies.manualProfileService)
                .environment(\.resumeImportService, dependencies.resumeImportService)
                .environment(\.homeOverviewService, dependencies.homeOverviewService)
                .environment(\.careerOverviewService, dependencies.careerOverviewService)
                .environment(\.verifyOverviewService, dependencies.verifyOverviewService)
                .environment(\.verificationInitiationService, dependencies.verificationInitiationService)
                .environment(\.passportOverviewService, dependencies.passportOverviewService)
                .environment(\.passportShareService, dependencies.passportShareService)
                .environment(\.passportPDFExportService, dependencies.passportPDFExportService)
                .environment(\.moreOverviewService, dependencies.moreOverviewService)
        }
    }
}
