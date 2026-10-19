import SwiftUI

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appConfiguration) private var appConfiguration
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationStore: CandidateNotificationStore
    @EnvironmentObject private var candidateDataRefreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var digiLockerStore: DigiLockerStore

    var body: some View {
        VStack(spacing: 0) {
            if appConfiguration.isDemoModeEnabled {
                DemoModeBanner(environment: appConfiguration.environment)
                    .padding(.horizontal, KairoSpacing.large)
                    .padding(.vertical, KairoSpacing.small)
            }

            switch sessionStore.launchPhase {
            case .idle:
                RootShellView()
            case .bootstrapping:
                SessionBootstrapScreen()
            case .failed(let message):
                SessionBootstrapErrorScreen(
                    message: message,
                    retry: {
                        Task {
                            await sessionStore.refreshLaunchRoute()
                        }
                    }
                )
            }

        }
        .background(KairoColors.background.ignoresSafeArea())
        .modifier(KairoStatusBarProtection())
        .task {
            await sessionStore.bootstrapIfNeeded()
        }
        .onOpenURL { url in
            routeIncomingURL(url, entry: .openURLReceived)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else {
                GoogleReturnDiagnostics.emit(.userActivityReceived, link: .init(nil))
                return
            }
            routeIncomingURL(url, entry: .userActivityReceived)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            let state: GoogleReturnDiagnostics.State = switch phase {
            case .active: .active
            case .inactive: .inactive
            case .background: .background
            @unknown default: .unknown
            }
            GoogleReturnDiagnostics.emit(phase == .active ? .sceneActive : .sceneChanged, state: state)
        }
        .onChange(of: router.diagnosticAuthRoot, initial: true) { _, root in
            GoogleReturnDiagnostics.emit(.authRootChanged, state: root)
        }
        .sheet(item: publicPassportPresentationBinding) { presentation in
            PublicPassportHandoffView(presentation: presentation)
        }
        .sheet(item: notificationCenterPresentationBinding) { _ in
            CandidateNotificationCenterView()
        }
        .sheet(item: $router.trustInvitationPresentation) { invitation in
            TrustInvitationView(presentation: invitation)
        }
        .task {
            if appConfiguration.buildConfiguration == .staging, appConfiguration.environment == .staging,
               UITestLaunchConfiguration.current().validated(for: appConfiguration).isEnabled,
               ProcessInfo.processInfo.environment["KAIRO_UI_TEST_TRUST_INVITATION"] == "1" {
                router.trustInvitationPresentation = TrustInvitationPresentation(token: String(repeating: "synthetic", count: 6))
            }
        }
        .sheet(item: trustScorePresentationBinding) { _ in
            TrustScoreDetailView()
        }
        .sheet(item: digiLockerPresentationBinding) { _ in
            DigiLockerHubView()
        }
        .sheet(item: careerDocumentPresentationBinding) { presentation in
            CareerDocumentsView(presentation: presentation)
        }
        .sheet(item: googleAuthenticationPresentationBinding) { presentation in
            GoogleAuthenticationHandoffView(presentation: presentation)
        }
        .onChange(of: sessionStore.currentUser?.id) { _, _ in
            notificationStore.reset()
            candidateDataRefreshStore.resetForIdentityChange()
            digiLockerStore.resetForIdentityChange()
            if sessionStore.currentUser != nil, let invitation = router.pendingTrustInvitation {
                router.pendingTrustInvitation = nil
                router.trustInvitationPresentation = invitation
            }
        }
    }

    private var publicPassportPresentationBinding: Binding<PublicPassportPresentation?> {
        Binding(
            get: { router.publicPassportPresentation },
            set: { presentation in
                if presentation == nil {
                    router.dismissPublicPassportPresentation()
                }
            }
        )
    }

    private var notificationCenterPresentationBinding: Binding<NotificationCenterPresentation?> {
        Binding(
            get: { router.notificationCenterPresentation },
            set: { presentation in
                if presentation == nil {
                    router.dismissNotificationCenter()
                }
            }
        )
    }

    private var trustScorePresentationBinding: Binding<TrustScorePresentation?> {
        Binding(
            get: { router.trustScorePresentation },
            set: { presentation in
                if presentation == nil {
                    router.dismissTrustScoreDetails()
                }
            }
        )
    }

    private var digiLockerPresentationBinding: Binding<DigiLockerHubPresentation?> {
        Binding(
            get: { router.digiLockerPresentation },
            set: { presentation in
                if presentation == nil {
                    router.dismissDigiLocker()
                }
            }
        )
    }

    private var careerDocumentPresentationBinding: Binding<CareerDocumentPresentation?> {
        Binding(
            get: { router.careerDocumentPresentation },
            set: { presentation in
                if presentation == nil {
                    router.dismissCareerDocuments()
                }
            }
        )
    }

    private var googleAuthenticationPresentationBinding: Binding<GoogleAuthenticationPresentation?> {
        Binding(
            get: { router.googleAuthenticationPresentation },
            set: { presentation in
                if presentation == nil {
                    router.dismissGoogleAuthentication()
                }
            }
        )
    }

    private func routeIncomingURL(_ url: URL, entry: GoogleReturnDiagnostics.Event) {
        let deliveryID = UUID()
        GoogleReturnDiagnostics.emit(entry, deliveryID: deliveryID, link: .init(url))
        router.handleIncomingURL(url, configuration: appConfiguration, diagnosticDeliveryID: deliveryID)
    }
}

private struct SessionBootstrapScreen: View {
    var body: some View {
        KairoLoadingStateView(
            title: "Restoring your session",
            message: "KairoID is checking your secure session and onboarding status."
        )
        .padding(KairoSpacing.large)
    }
}

private struct SessionBootstrapErrorScreen: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: KairoSpacing.large) {
            KairoErrorStateView(
                title: "Session unavailable",
                message: message
            )

            KairoPrimaryButton(
                title: "Retry",
                action: retry
            )
        }
        .padding(KairoSpacing.large)
    }
}
