import SwiftUI

struct AppRootView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationStore: CandidateNotificationStore
    @EnvironmentObject private var candidateDataRefreshStore: CandidateDataRefreshStore

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
            routeIncomingURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            routeIncomingURL(url)
        }
        .sheet(item: publicPassportPresentationBinding) { presentation in
            PublicPassportHandoffView(presentation: presentation)
        }
        .sheet(item: notificationCenterPresentationBinding) { _ in
            CandidateNotificationCenterView()
        }
        .sheet(item: trustScorePresentationBinding) { _ in
            TrustScoreDetailView()
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

    private func routeIncomingURL(_ url: URL) {
        router.handleIncomingURL(url, configuration: appConfiguration)
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
