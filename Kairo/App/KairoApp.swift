import SwiftUI
import UIKit

@main
struct KairoApp: App {
    @StateObject private var router: AppRouter
    @StateObject private var sessionStore: AppSessionStore
    @StateObject private var candidateDataRefreshStore: CandidateDataRefreshStore
    @StateObject private var candidateNotificationStore: CandidateNotificationStore
    @StateObject private var appearanceStore: AppAppearanceStore
    @StateObject private var digiLockerStore: DigiLockerStore
    @StateObject private var guidedTourCoordinator: GuidedTourCoordinator

    init() {
        let configuration = AppConfiguration.resolve()
        let uiTestConfiguration = UITestLaunchConfiguration.current().validated(for: configuration)
        let dependencies = AppDependencies.make(
            configuration: configuration,
            uiTestConfiguration: uiTestConfiguration
        )
        let guidedTourPreferences = GuidedTourPreferences()
        let guidedTourTestConfiguration = UITestGuidedTourConfiguration.current(
            launchConfiguration: uiTestConfiguration
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
            resumeImportService: dependencies.resumeImportService,
            guidedTourPreferences: guidedTourPreferences
        ))
        _candidateDataRefreshStore = StateObject(wrappedValue: CandidateDataRefreshStore())
        _candidateNotificationStore = StateObject(wrappedValue: CandidateNotificationStore(
            service: dependencies.candidateNotificationService
        ))
        _appearanceStore = StateObject(wrappedValue: AppAppearanceStore())
        _digiLockerStore = StateObject(wrappedValue: DigiLockerStore(service: dependencies.digiLockerService))
        _guidedTourCoordinator = StateObject(wrappedValue: GuidedTourCoordinator(
            preferences: guidedTourPreferences,
            testConfiguration: guidedTourTestConfiguration
        ))
        self.configuration = configuration
        self.dependencies = dependencies
    }

    private let configuration: AppConfiguration
    private let dependencies: AppDependencies

    var body: some Scene {
        WindowGroup {
            Group {
                if DigiLockerReadQA.current(configuration: configuration) != nil {
                    // Exact canonical Hub, no bootstrap/Home requests or account actions.
                    DigiLockerHubView()
                } else {
                    AppRootView()
                }
            }
                .environmentObject(router)
                .environmentObject(sessionStore)
                .environmentObject(candidateDataRefreshStore)
                .environmentObject(candidateNotificationStore)
                .environmentObject(appearanceStore)
                .environmentObject(digiLockerStore)
                .environmentObject(guidedTourCoordinator)
                .environment(\.appConfiguration, configuration)
                .environment(\.networkClient, dependencies.networkClient)
                .environment(\.tokenStore, dependencies.tokenStore)
                .environment(\.authService, dependencies.authService)
                .environment(\.manualProfileService, dependencies.manualProfileService)
                .environment(\.resumeImportService, dependencies.resumeImportService)
                .environment(\.homeOverviewService, dependencies.homeOverviewService)
                .environment(\.trustScoreService, dependencies.trustScoreService)
                .environment(\.careerOverviewService, dependencies.careerOverviewService)
                .environment(\.careerDocumentService, dependencies.careerDocumentService)
                .environment(\.documentVaultService, dependencies.documentVaultService)
                .environment(\.documentsHubService, dependencies.documentsHubService)
                .environment(\.documentPackService, dependencies.documentPackService)
                .environment(\.verifyOverviewService, dependencies.verifyOverviewService)
                .environment(\.verificationInitiationService, dependencies.verificationInitiationService)
                .environment(\.passportOverviewService, dependencies.passportOverviewService)
                .environment(\.passportShareService, dependencies.passportShareService)
                .environment(\.passportPDFExportService, dependencies.passportPDFExportService)
                .environment(\.moreOverviewService, dependencies.moreOverviewService)
                .environment(\.profileService, dependencies.profileService)
                .preferredColorScheme(appearanceStore.preferredColorScheme)
        }
    }
}
