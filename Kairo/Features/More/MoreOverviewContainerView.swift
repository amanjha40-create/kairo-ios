import SwiftUI

struct MoreOverviewContainerView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.moreOverviewService) private var moreOverviewService
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var state = MoreOverviewState.loading(accountSummary: .fixture)
    @State private var hasLoaded = false

    var body: some View {
        MoreOverviewScreenView(
            state: $state,
            isLiveMode: true,
            retryAction: {
                Task {
                    await load(showLoading: true)
                }
            },
            reloadAction: {
                await load(showLoading: false)
            }
        )
        .task {
            guard !hasLoaded else {
                return
            }

            hasLoaded = true
            state = .loading(accountSummary: cachedSummary)
            await load(showLoading: true)
        }
    }

    private var cachedSummary: MoreAccountSummary {
        MoreOverviewMapper.cachedSummary(from: sessionStore.currentUser)
    }

    private func load(showLoading: Bool) async {
        let previousState = state

        if showLoading || !hasRenderableContent(previousState) {
            state = .loading(accountSummary: cachedSummary)
        }

        do {
            let overview = try await moreOverviewService.loadOverview()
            await MainActor.run {
                sessionStore.replaceCurrentUser(overview.user)
                state.apply(
                    overview: overview,
                    destinations: MoreExternalDestinations(
                        supportEmailAddress: appConfiguration.supportEmailAddress,
                        helpCenterURL: appConfiguration.helpCenterURL,
                        termsOfServiceURL: appConfiguration.termsOfServiceURL,
                        privacyPolicyURL: appConfiguration.privacyPolicyURL,
                        cookiePolicyURL: appConfiguration.cookiePolicyURL
                    )
                )
            }
        } catch {
            if MoreOverviewMapper.requiresSessionRecovery(for: error) {
                await sessionStore.refreshLaunchRoute()
                return
            }

            if hasRenderableContent(previousState), !showLoading {
                state = previousState
                return
            }

            state = MoreOverviewMapper.errorState(
                for: error,
                accountSummary: cachedSummary
            )
        }
    }

    private func hasRenderableContent(_ state: MoreOverviewState) -> Bool {
        switch state.phase {
        case .populated:
            true
        case .loading, .error:
            false
        }
    }
}
