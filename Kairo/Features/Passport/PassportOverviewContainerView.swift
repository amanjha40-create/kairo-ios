import SwiftUI

struct PassportOverviewContainerView: View {
    @Environment(\.passportOverviewService) private var passportOverviewService
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var state = PassportOverviewState.loading(header: .fixture)
    @State private var hasLoaded = false

    var body: some View {
        PassportOverviewScreenView(
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
    }

    private var cachedHeader: PassportHeader {
        PassportOverviewMapper.cachedHeader(from: sessionStore.currentUser)
    }

    private func load(showLoading: Bool) async {
        let previousState = state

        if showLoading || !hasRenderableContent(previousState) {
            state = .loading(header: cachedHeader)
        }

        do {
            state = PassportOverviewMapper.map(try await passportOverviewService.loadOverview())
        } catch {
            if PassportOverviewMapper.requiresSessionRecovery(for: error) {
                await sessionStore.refreshLaunchRoute()
                return
            }

            if hasRenderableContent(previousState), !showLoading {
                state = previousState
                return
            }

            state = PassportOverviewMapper.errorState(for: error, header: cachedHeader)
        }
    }

    private func hasRenderableContent(_ state: PassportOverviewState) -> Bool {
        switch state.phase {
        case .populated, .empty:
            true
        case .loading, .error:
            false
        }
    }
}
