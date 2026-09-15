import SwiftUI

struct HomeOverviewContainerView: View {
    @Environment(\.homeOverviewService) private var homeOverviewService
    @Environment(\.verifyOverviewService) private var verifyOverviewService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore

    @State private var state = HomeOverviewState.loading(header: .placeholder)
    @State private var hasLoaded = false

    var body: some View {
        HomeOverviewScreenView(
            state: state,
            retryAction: {
                Task {
                    await load(showLoading: true)
                }
            },
            refreshAction: {
                await load(showLoading: false)
            }
        )
        .task {
            guard !hasLoaded else {
                return
            }

            hasLoaded = true
            state = .loading(header: cachedHeader)
            await load(showLoading: true)
        }
        .onChange(of: refreshStore.revision) { _, _ in
            Task { await load(showLoading: false) }
        }
    }

    private var cachedHeader: HomeHeader {
        if let currentUser = sessionStore.currentUser {
            return HomeHeader(
                greeting: "Welcome back,",
                firstName: currentUser.fullName?
                    .split(separator: " ")
                    .first
                    .map(String.init) ?? "there",
                supportingCopy: "KairoID is preparing your latest trust snapshot.",
                initials: initials(from: currentUser)
            )
        }

        return .placeholder
    }

    private func load(showLoading: Bool) async {
        let previousState = state

        if showLoading || !hasRenderableContent(previousState) {
            state = .loading(header: cachedHeader)
        }

        do {
            state = try await HomeOverviewLoader.load(
                dashboardService: homeOverviewService,
                verificationService: verifyOverviewService
            )
        } catch {
            if HomeOverviewMapper.requiresSessionRecovery(for: error) {
                await sessionStore.refreshLaunchRoute()
                return
            }

            // Do not preserve an old active-request claim after a failed refresh.
            state = HomeOverviewMapper.errorState(for: error, header: cachedHeader)
        }
    }

    private func hasRenderableContent(_ state: HomeOverviewState) -> Bool {
        switch state.phase {
        case .populated, .empty:
            true
        case .loading, .error:
            false
        }
    }

    private func initials(from user: AppUser) -> String {
        let parts = (user.fullName ?? user.email)
            .split(whereSeparator: { $0 == " " || $0 == "@" || $0 == "." || $0 == "_" })
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }

        let value = parts.joined()
        return value.isEmpty ? "KA" : value
    }
}
