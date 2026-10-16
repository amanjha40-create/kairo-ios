import Foundation

struct AppDependencies: Sendable {
    let networkClient: any NetworkClient
    let tokenStore: any TokenStore
    let sessionService: any SessionServiceProtocol
    let authService: any AuthServiceProtocol
    let manualProfileService: any ManualProfileServiceProtocol
    let resumeImportService: any ResumeImportServiceProtocol
    let homeOverviewService: any HomeOverviewServiceProtocol
    let trustScoreService: any TrustScoreServiceProtocol
    let digiLockerService: any DigiLockerServiceProtocol
    let careerOverviewService: any CareerOverviewServiceProtocol
    let careerDocumentService: any CareerDocumentServiceProtocol
    let documentVaultService: any DocumentVaultServiceProtocol
    let documentsHubService: any DocumentsHubServiceProtocol
    let documentPackService: any DocumentPackServiceProtocol
    let verifyOverviewService: any VerifyOverviewServiceProtocol
    let verificationInitiationService: any VerificationInitiationServiceProtocol
    let passportOverviewService: any PassportOverviewServiceProtocol
    let passportShareService: any PassportShareServiceProtocol
    let passportPDFExportService: any PassportPDFExportServiceProtocol
    let moreOverviewService: any MoreOverviewServiceProtocol
    let profileService: any ProfileServiceProtocol
    let candidateNotificationService: any CandidateNotificationServiceProtocol
    var employmentReferencesService: any EmploymentReferencesServing = UnavailableReferencesService()
    var permanentAddressService: (any PermanentAddressServing)? = nil

    static func make(
        configuration: AppConfiguration,
        uiTestConfiguration: UITestLaunchConfiguration = .current()
    ) -> AppDependencies {
        let uiTestConfiguration = uiTestConfiguration.validated(for: configuration)
        var tokenStore: any TokenStore = configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled
            ? InMemoryTokenStore()
            : KeychainTokenStore(service: configuration.keychainService)

        // Synthetic UI-test credentials must never reach live services, including
        // unselected tabs refreshed by a Login identity transition.
        var networkClient: any NetworkClient = configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled
            ? DemoNetworkClient()
            : URLSessionNetworkClient(
                baseURL: configuration.apiBaseURL,
                session: .shared
            )

        if DigiLockerReadQA.current(configuration: configuration) != nil {
            tokenStore = DigiLockerReadOnlyTokens(underlying: tokenStore)
            networkClient = DigiLockerReadOnlyNetwork(underlying: networkClient)
        }

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
            if configuration.isDemoModeEnabled {
                DemoResumeImportService()
            } else if uiTestConfiguration.isEnabled {
                UITestResumeImportService(
                    scenario: UITestResumeImportConfiguration.current().serviceScenario
                )
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
        let trustScoreService: any TrustScoreServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoTrustScoreService()
            } else {
                TrustScoreService(sessionService: sessionService)
            }
        let digiLockerService: any DigiLockerServiceProtocol =
            if uiTestConfiguration.isEnabled,
               let scenario = ProcessInfo.processInfo.environment["KAIRO_UI_TEST_AADHAAR"] {
                DigiLockerAadhaarFixtureService(scenario: scenario)
            } else if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoDigiLockerService(returnFixture: DigiLockerReturnFixture.current(configuration: configuration))
            } else {
                DigiLockerService(sessionService: sessionService)
            }
        let careerOverviewService = CareerOverviewService(
            authService: authService,
            sessionService: sessionService
        )
        let careerDocumentService: any CareerDocumentServiceProtocol =
            if uiTestConfiguration.isEnabled,
               let scenario = ProcessInfo.processInfo.environment["KAIRO_UI_TEST_PORTFOLIO_ATTACHMENT"] {
                PortfolioLifecycleFixtureService(scenario: scenario)
            } else if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoCareerDocumentService()
            } else {
                CareerDocumentService(sessionService: sessionService)
            }
        let documentVaultService: any DocumentVaultServiceProtocol =
            if uiTestConfiguration.isEnabled, let scenario = ProcessInfo.processInfo.environment["KAIRO_UI_TEST_DOCUMENT_HIERARCHY"] {
                DocumentHierarchyFixtures(scenario: scenario)
            } else if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoDocumentVaultService()
            } else {
                DocumentVaultService(sessionService: sessionService)
            }
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
        let passportShareService: any PassportShareServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoPassportShareService()
            } else {
                PassportShareService(
                    sessionService: sessionService,
                    configuration: configuration
                )
            }
        let passportPDFExportService: any PassportPDFExportServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                UnavailablePassportPDFExportService()
            } else {
                PassportPDFExportService(sessionService: sessionService)
            }
        let moreOverviewService = MoreOverviewService(
            sessionService: sessionService,
            bundleAppVersion: bundleAppVersion()
        )
        let profileService: any ProfileServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                ProfileFixtureService()
            } else {
                ProfileService(session: sessionService)
            }
        let candidateNotificationService: any CandidateNotificationServiceProtocol =
            if configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled {
                DemoCandidateNotificationService(
                    fixture: UITestNotificationConfiguration.current().fixture ?? .unread
                )
            } else {
                CandidateNotificationService(sessionService: sessionService)
            }

        return AppDependencies(
            networkClient: networkClient,
            tokenStore: tokenStore,
            sessionService: sessionService,
            authService: authService,
            manualProfileService: manualProfileService,
            resumeImportService: resumeImportService,
            homeOverviewService: homeOverviewService,
            trustScoreService: trustScoreService,
            digiLockerService: digiLockerService,
            careerOverviewService: careerOverviewService,
            careerDocumentService: careerDocumentService,
            documentVaultService: documentVaultService,
            documentsHubService: configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled
                ? (uiTestConfiguration.isEnabled && ProcessInfo.processInfo.environment["KAIRO_UI_TEST_DOCUMENT_HIERARCHY"] != nil
                    ? DocumentHierarchyFixtures(scenario: ProcessInfo.processInfo.environment["KAIRO_UI_TEST_DOCUMENT_HIERARCHY"] ?? "populated") as any DocumentsHubServiceProtocol
                    : PreviewDocumentsHubService() as any DocumentsHubServiceProtocol)
                : DocumentsHubService(career: careerOverviewService, documents: careerDocumentService, vault: documentVaultService, session: sessionService),
            documentPackService: configuration.isDemoModeEnabled || uiTestConfiguration.isEnabled
                ? DemoDocumentPackService(scenario: uiTestConfiguration.isEnabled ? ProcessInfo.processInfo.environment["KAIRO_UI_TEST_PACK_STATE"] ?? "populated" : "populated")
                : DocumentPackService(session: sessionService, publicClient: networkClient, allowedHosts: configuration.documentPackHosts),
            verifyOverviewService: verifyOverviewService,
            verificationInitiationService: verificationInitiationService,
            passportOverviewService: passportOverviewService,
            passportShareService: passportShareService,
            passportPDFExportService: passportPDFExportService,
            moreOverviewService: moreOverviewService,
            profileService: profileService,
            candidateNotificationService: candidateNotificationService,
            employmentReferencesService: EmploymentReferencesService(session: sessionService,
                enabled: configuration.environment == .staging && !configuration.isDemoModeEnabled && !uiTestConfiguration.isEnabled),
            permanentAddressService: [.staging, .production].contains(configuration.environment) && !configuration.isDemoModeEnabled && !uiTestConfiguration.isEnabled
                ? PermanentAddressService(session: sessionService, enabled: true) : nil
        )
    }

    private static func bundleAppVersion(bundle: Bundle = .main) -> String {
        let info = bundle.infoDictionary ?? [:]
        let shortVersion = info["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = info["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }
}
