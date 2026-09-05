import SwiftUI

struct VerifyOverviewContainerView: View {
    @Environment(\.verifyOverviewService) private var verifyOverviewService
    @Environment(\.verificationInitiationService) private var verificationInitiationService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore

    @State private var state = VerifyOverviewState.loading()
    @State private var hasLoaded = false
    @State private var initiationPreset: VerificationInitiationPreset?

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
            },
            startVerificationHandler: { preset in
                initiationPreset = preset
            },
            focusedRequestID: refreshStore.focusedVerificationRequestID,
            focusedRequestPresentedHandler: { requestID in
                refreshStore.clearVerificationFocus(requestID: requestID)
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
        .onChange(of: refreshStore.revision) { _, _ in
            Task { await load(showLoading: false) }
        }
        .sheet(item: $initiationPreset) { preset in
            VerificationInitiationSheet(
                service: verificationInitiationService,
                preset: preset,
                onSuccess: { requestID in
                    refreshStore.verificationRequested(requestID: requestID)
                }
            )
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
            refreshStore.candidateDataChanged()
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
