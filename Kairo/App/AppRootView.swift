import SwiftUI

struct AppRootView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @EnvironmentObject private var sessionStore: AppSessionStore

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
