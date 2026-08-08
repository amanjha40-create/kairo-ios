import SwiftUI

struct VerifyOverviewContainerView: View {
    @Environment(\.verifyOverviewService) private var verifyOverviewService
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var state = VerifyOverviewState.loading()
    @State private var hasLoaded = false

    var body: some View {
        VerifyOverviewScreenView(
            state: $state,
            retryAction: {
                Task {
                    await load(showLoading: true)
                }
            },
            requestActionHandler: { requestID, action, response in
                try await performAction(
                    requestID: requestID,
                    action: action,
                    response: response
                )
            }
        )
        .task {
            guard !hasLoaded else {
                return
            }

            hasLoaded = true
            state = .loading()
            await load(showLoading: true)
        }
    }

    private func load(showLoading: Bool) async {
        let previousState = state

        if showLoading || !hasRenderableContent(previousState) {
            state = .loading()
        }

        do {
            state = VerifyOverviewMapper.map(try await verifyOverviewService.loadOverview())
        } catch {
            if VerifyOverviewMapper.requiresSessionRecovery(for: error) {
                await sessionStore.refreshLaunchRoute()
                return
            }

            if hasRenderableContent(previousState), !showLoading {
                state = previousState
                return
            }

            state = VerifyOverviewMapper.errorState(for: error)
        }
    }

    private func performAction(
        requestID: String,
        action: VerifyRequestAction,
        response: String?
    ) async throws {
        do {
            try await verifyOverviewService.performAction(
                requestID: requestID,
                action: action,
                response: response
            )
            await load(showLoading: true)
        } catch {
            if VerifyOverviewMapper.requiresSessionRecovery(for: error) {
                await sessionStore.refreshLaunchRoute()
                return
            }

            throw error
        }
    }

    private func hasRenderableContent(_ state: VerifyOverviewState) -> Bool {
        switch state.phase {
        case .populated, .empty:
            return true
        case .loading, .error:
            return false
        }
    }
}
