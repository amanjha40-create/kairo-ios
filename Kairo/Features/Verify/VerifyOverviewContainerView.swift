import SwiftUI

struct VerifyOverviewContainerView: View {
    @Environment(\.verifyOverviewService) private var verifyOverviewService
    @Environment(\.verificationInitiationService) private var verificationInitiationService
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore

    @StateObject private var loadState = VerifyOverviewLoadState()
    @State private var hasLoaded = false
    @State private var initiationPreset: VerificationInitiationPreset?

    var body: some View {
        VerifyOverviewScreenView(
            state: $loadState.state,
            retryAction: {
                Task {
                    await load(showLoading: true)
                }
            },
            refreshAction: { await load(showLoading: false) },
            requestActionHandler: { requestID, action, response, consent in
                try await performAction(
                    requestID: requestID,
                    action: action,
                    response: response,
                    consent: consent
                )
            },
            startVerificationHandler: { preset in
                initiationPreset = preset
            },
            focusedRequestID: refreshStore.focusedVerificationRequestID,
            authoritativeFocusedRequestID: loadState.authoritativeFocusID,
            focusedRequestPresentedHandler: { requestID in
                refreshStore.clearVerificationFocus(requestID: requestID)
            }
        )
        .task {
            guard !hasLoaded else {
                return
            }

            hasLoaded = true
            await load(showLoading: true)
        }
        .onChange(of: refreshStore.revision) { _, _ in
            Task { await load(showLoading: false) }
        }
        .onChange(of: refreshStore.focusedVerificationRequestID) { _, requestID in
            guard requestID != nil else { return }
            Task { await load(showLoading: false) }
        }
        .verificationInitiationSheet(preset: $initiationPreset, service: verificationInitiationService) { requestID in
            refreshStore.verificationRequested(requestID: requestID)
        }
    }

    private func load(showLoading: Bool) async {
        if await loadState.load(
            service: verifyOverviewService,
            focusedRequestID: refreshStore.focusedVerificationRequestID,
            showLoading: showLoading
        ) {
            await sessionStore.refreshLaunchRoute()
        }
    }

    private func performAction(
        requestID: String,
        action: VerifyRequestAction,
        response: String?,
        consent: VerificationSubmissionConsent?
    ) async throws {
        do {
            try await verifyOverviewService.performAction(
                requestID: requestID,
                action: action,
                response: response,
                consent: consent
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

}
