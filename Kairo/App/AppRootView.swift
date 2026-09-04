import SwiftUI

struct AppRootView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var notificationStore: CandidateNotificationStore

    var body: some View {
        ZStack(alignment: .top) {
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

            if appConfiguration.isDemoModeEnabled {
                DemoModeBanner(environment: appConfiguration.environment)
                    .padding(.horizontal, KairoSpacing.large)
                    .padding(.top, KairoSpacing.small)
            }
        }
        .background(KairoColors.background.ignoresSafeArea())
        .task {
            await sessionStore.bootstrapIfNeeded()
        }
        .onOpenURL { url in
            routePublicPassportURL(url)
        }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            guard let url = activity.webpageURL else { return }
            routePublicPassportURL(url)
        }
        .sheet(item: publicPassportPresentationBinding) { presentation in
            PublicPassportHandoffView(presentation: presentation)
        }
        .sheet(item: notificationCenterPresentationBinding) { _ in
            CandidateNotificationCenterView()
        }
        .onChange(of: sessionStore.currentUser?.id) { _, _ in
            notificationStore.reset()
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

    private func routePublicPassportURL(_ url: URL) {
        router.handleIncomingURL(
            url,
            allowedPublicPassportHosts: appConfiguration.publicPassportHosts,
            isDemoModeEnabled: appConfiguration.isDemoModeEnabled
        )
    }
}

private struct SessionBootstrapScreen: View {
    var body: some View {
        KairoLoadingStateView(
            title: "Restoring your session",
            message: "Kairo is checking your secure session and onboarding status."
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
