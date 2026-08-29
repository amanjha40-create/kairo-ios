import SwiftUI

struct VerifyOverviewFixtureHostView: View {
    @State private var state: VerifyOverviewState

    init(state: VerifyOverviewState) {
        _state = State(initialValue: state)
    }

    var body: some View {
        VerifyOverviewScreenView(state: $state)
    }
}

struct VerifyOverviewScreenView: View {
    @EnvironmentObject private var router: AppRouter

    @Binding private var state: VerifyOverviewState
    private let retryAction: (() -> Void)?
    private let refreshAction: (() async -> Void)?
    private let requestActionHandler: VerifyRequestActionHandler?
    private let startVerificationHandler: ((VerificationInitiationPreset) -> Void)?
    private let focusedRequestID: String?
    private let focusedRequestPresentedHandler: ((String) -> Void)?

    @State private var presentedSheet: VerifyPresentedSheet?
    @State private var provideInformationText = ""
    @State private var actionError: VerifyActionError?
    @State private var actionInFlight: VerifyActionExecution?

    init(
        state: Binding<VerifyOverviewState>,
        retryAction: (() -> Void)? = nil,
        refreshAction: (() async -> Void)? = nil,
        requestActionHandler: VerifyRequestActionHandler? = nil,
        startVerificationHandler: ((VerificationInitiationPreset) -> Void)? = nil,
        focusedRequestID: String? = nil,
        focusedRequestPresentedHandler: ((String) -> Void)? = nil
    ) {
        _state = state
        self.retryAction = retryAction
        self.refreshAction = refreshAction
        self.requestActionHandler = requestActionHandler
        self.startVerificationHandler = startVerificationHandler
        self.focusedRequestID = focusedRequestID
        self.focusedRequestPresentedHandler = focusedRequestPresentedHandler
    }

    var body: some View {
        KairoScreenContainer(
            title: "Verify",
            subtitle: "Strengthen your Trust Passport with verified professional history.",
            titleAccessibilityIdentifier: CandidateTab.verify.titleAccessibilityIdentifier
        ) {
            supportLine
            phaseContent
        }
        .refreshableIfAvailable(action: refreshAction)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.verifyScreen)
        .sheet(item: $presentedSheet) { destination in
            sheetDestination(for: destination)
        }
        .alert(item: $actionError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onChange(of: state) { _, _ in
            presentFocusedRequestIfAvailable()
        }
        .onChange(of: focusedRequestID) { _, _ in
            presentFocusedRequestIfAvailable()
        }
    }

    private var supportLine: some View {
        HStack(alignment: .top, spacing: KairoSpacing.small) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KairoColors.accent)

            Text(state.header.supportingLine)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: KairoSpacing.small)

            if let dataSourceLabel {
                VerifyDataSourceBadge(title: dataSourceLabel)
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your Trust Center",
                message: "Kairo is assembling your latest verification requests."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message,
                retryAction: retryAction
            )
        case .empty(let content):
            emptyStateView(content)
        case .populated(let content):
            populatedStateView(content)
        }
    }

    private func populatedStateView(_ content: VerifyOverviewContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
            priorityActionCard(content.priorityAction)
            requestsSection(
                title: "Pending requests",
                identifier: KairoAccessibilityID.verifyPendingRequestsSection,
                requests: content.pendingRequests,
                emptyMessage: "No pending requests right now."
            )
            requestsSection(
                title: "In progress",
                identifier: KairoAccessibilityID.verifyInProgressSection,
                requests: content.inProgressRequests,
                emptyMessage: "No verifications are currently in progress."
            )
            completedSection(content.completedRequests)
            suggestedNextSection(content.suggestions)
        }
    }

    private func emptyStateView(_ content: VerifyOverviewEmptyContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoEmptyStateView(
                title: content.title,
                message: content.message,
                systemImage: "checkmark.shield"
            )
            .accessibilityIdentifier(KairoAccessibilityID.verifyEmptyState)

            if content.primaryAction != nil || content.secondaryAction != nil {
                KairoCard {
                    Text("Suggested next step")
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text("Prepare the part of your profile you want Kairo to verify next, then come back here as live verification requests become available.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let title = content.primaryActionTitle,
                       let action = content.primaryAction {
                        KairoPrimaryButton(
                            title: title,
                            accessibilityIdentifier: KairoAccessibilityID.verifyStartVerification,
                            action: { handle(callToAction: action) }
                        )
                    }

                    if let title = content.secondaryActionTitle,
                       let action = content.secondaryAction {
                        KairoSecondaryButton(
                            title: title,
                            accessibilityIdentifier: KairoAccessibilityID.verifyViewTrustPassport,
                            action: { handle(callToAction: action) }
                        )
                    }
                }
            }
        }
    }

    private func priorityActionCard(_ action: VerifyPriorityAction) -> some View {
        KairoCard {
            VerifySectionEyebrow(title: "Priority action")

            Text(action.title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(action.organization)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(action.supportingCopy)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) {
                    VerifyMetaPill(title: action.trustImpact, systemImage: "waveform.path.ecg")
                    VerifyMetaPill(title: action.estimatedCompletionTime, systemImage: "clock")
                    VerifyMetaPill(title: action.statusTitle, systemImage: "checkmark.circle")
                }

                VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    VerifyMetaPill(title: action.trustImpact, systemImage: "waveform.path.ecg")
                    VerifyMetaPill(title: action.estimatedCompletionTime, systemImage: "clock")
                    VerifyMetaPill(title: action.statusTitle, systemImage: "checkmark.circle")
                }
            }

            if let title = action.actionTitle,
               let callToAction = action.action {
                KairoPrimaryButton(
                    title: title,
                    accessibilityIdentifier: KairoAccessibilityID.verifyStartVerification,
                    action: { handle(callToAction: callToAction) }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.verifyPriorityRecommendation)
    }

    private func requestsSection(
        title: String,
        identifier: String,
        requests: [VerifyRequest],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            VerifySectionTitle(title: title, accessibilityIdentifier: identifier)

            if requests.isEmpty {
                KairoCard {
                    Text(emptyMessage)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            } else {
                ForEach(requests) { request in
                    requestCard(request)
                }
            }
        }
    }

    private func requestCard(_ request: VerifyRequest) -> some View {
        KairoCard {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    Text(request.type)
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(request.organization)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: KairoSpacing.small)

                VerifyStatusBadge(status: request.status)
            }

            Text(request.dateLabel)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            Text(request.timelineSummary)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VerifyInlineButton(
                title: "View request",
                accessibilityIdentifier: KairoAccessibilityID.verifyRequestAction(request.id),
                action: { presentedSheet = .requestDetail(request.id) }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.verifyRequestCard(request.id))
    }

    private func completedSection(_ requests: [VerifyRequest]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            VerifySectionTitle(
                title: "Completed",
                accessibilityIdentifier: KairoAccessibilityID.verifyCompletedSection
            )

            if requests.isEmpty {
                KairoCard {
                    Text("No completed verifications yet.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            } else {
                KairoCard {
                    ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                        if index > 0 {
                            Divider()
                        }

                        HStack(alignment: .top, spacing: KairoSpacing.medium) {
                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(request.type)
                                    .font(KairoTypography.headline)
                                    .foregroundStyle(KairoColors.textPrimary)

                                Text(request.organization)
                                    .font(KairoTypography.body)
                                    .foregroundStyle(KairoColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text(request.dateLabel)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.textSecondary)
                            }

                            Spacer(minLength: KairoSpacing.small)

                            VerifyStatusBadge(status: request.status)
                        }
                    }
                }
            }
        }
    }

    private func suggestedNextSection(_ suggestions: [VerifySuggestion]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            VerifySectionTitle(
                title: "Suggested next",
                accessibilityIdentifier: KairoAccessibilityID.verifySuggestedNextSection
            )

            if suggestions.isEmpty {
                KairoCard {
                    Text("Kairo will suggest more verification opportunities here as live verification coverage expands.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                KairoCard {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                        if index > 0 {
                            Divider()
                        }

                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                                        .fill(KairoColors.surfaceMuted)

                                    Image(systemName: suggestion.kind?.systemImage ?? "sparkles")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(KairoColors.accent)
                                }
                                .frame(width: 40, height: 40)

                                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                    Text(suggestion.title)
                                        .font(KairoTypography.headline)
                                        .foregroundStyle(KairoColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Text(suggestion.valueStatement)
                                        .font(KairoTypography.body)
                                        .foregroundStyle(KairoColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }

                                Spacer(minLength: KairoSpacing.small)
                            }

                            if let actionTitle = suggestion.actionTitle,
                               let action = suggestion.action {
                                VerifyInlineButton(
                                    title: actionTitle,
                                    accessibilityIdentifier: suggestion.kind.map { KairoAccessibilityID.verifySuggestedAction($0.rawValue) },
                                    action: { handle(callToAction: action) }
                                )
                                .disabled(!suggestion.isEnabled)
                            }

                            if let availabilityNote = suggestion.availabilityNote {
                                Text(availabilityNote)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var dataSourceLabel: String? {
        switch state.phase {
        case .populated(let content):
            content.dataSourceLabel
        case .empty(let content):
            content.dataSourceLabel
        case .loading, .error:
            nil
        }
    }

    private var activeContent: VerifyOverviewContent? {
        guard case .populated(let content) = state.phase else {
            return nil
        }

        return content
    }

    private func request(for id: String) -> VerifyRequest? {
        activeContent?.request(id: id)
    }

    private func handle(callToAction: VerifyCallToAction) {
        switch callToAction {
        case .startVerification(let kind):
            openStartVerification(preselected: kind)
        case .openRequest(let requestID):
            presentedSheet = .requestDetail(requestID)
        case .openCareer:
            router.selectTab(.career)
        case .viewTrustPassport:
            router.selectTab(.passport)
        }
    }

    private func openStartVerification(preselected: VerifyVerificationKind?) {
        guard let preselected else {
            actionError = VerifyActionError(
                title: "Choose a supported record",
                message: "Start verification from an eligible employment or education record."
            )
            return
        }

        let preset: VerificationInitiationPreset
        switch preselected {
        case .employment:
            preset = .employment()
        case .education:
            preset = .education()
        case .certification, .project:
            actionError = VerifyActionError(
                title: "Verification not supported",
                message: "The current backend supports employment and education verification initiation only."
            )
            return
        }

        guard let startVerificationHandler else {
            actionError = VerifyActionError(
                title: "Unavailable in preview",
                message: "Demo and UI-test sessions do not create live verification requests."
            )
            return
        }
        startVerificationHandler(preset)
    }

    private func presentFocusedRequestIfAvailable() {
        guard
            let focusedRequestID,
            let request = activeContent?.requests.first(where: {
                $0.routeRequestID == focusedRequestID || $0.id == focusedRequestID
            })
        else { return }
        presentedSheet = .requestDetail(request.id)
        focusedRequestPresentedHandler?(focusedRequestID)
    }

    private func performRequestAction(
        _ action: VerifyRequestAction,
        requestID: String,
        response: String? = nil
    ) {
        if let requestActionHandler {
            guard let routeRequestID = request(for: requestID)?.routeRequestID else {
                actionError = VerifyActionError(
                    title: "Action unavailable",
                    message: "This verification request is missing the live routing details needed to send an update."
                )
                return
            }

            actionInFlight = VerifyActionExecution(requestID: requestID, action: action)
            Task {
                do {
                    try await requestActionHandler(routeRequestID, action, response)
                    await MainActor.run {
                        actionInFlight = nil
                        provideInformationText = ""
                        presentedSheet = nil
                    }
                } catch {
                    await MainActor.run {
                        actionInFlight = nil
                        actionError = VerifyActionError(
                            title: "Action unavailable",
                            message: userFacingMessage(for: error)
                        )
                    }
                }
            }
            return
        }

        switch action {
        case .accept:
            state = state.applying(.accept, to: requestID)
            presentedSheet = nil
        case .submitInformation:
            presentedSheet = .provideInformation(requestID)
        case .submitForReview, .resubmitForReview:
            actionError = VerifyActionError(
                title: "Local preview only",
                message: "This fixture session only supports accept and provide-information previews."
            )
        }
    }

    private func userFacingMessage(for error: Error) -> String {
        if let sessionError = error as? SessionServiceError,
           sessionError == .sessionExpired {
            return sessionError.localizedDescription
        }

        if let networkError = error as? NetworkError {
            return networkError.localizedDescription
        }

        return error.localizedDescription
    }

    @ViewBuilder
    private func sheetDestination(for destination: VerifyPresentedSheet) -> some View {
        switch destination {
        case .requestDetail(let requestID):
            if let request = request(for: requestID) {
                VerifyRequestDetailSheet(
                    request: request,
                    isLive: requestActionHandler != nil,
                    actionInFlight: actionInFlight,
                    onAccept: { performRequestAction(.accept, requestID: requestID) },
                    onProvideInformation: { presentedSheet = .provideInformation(requestID) },
                    onSubmitForReview: { performRequestAction(.submitForReview, requestID: requestID) },
                    onResubmitForReview: { performRequestAction(.resubmitForReview, requestID: requestID) },
                    onDecline: { declineRequest(requestID) }
                )
            } else {
                VerifySimpleSheet(
                    title: "Request unavailable",
                    message: "The selected request is no longer available in this session."
                )
            }
        case .provideInformation(let requestID):
            if requestActionHandler == nil {
                VerifySimpleSheet(
                    title: "Provide information",
                    message: "This local placeholder confirms where Kairo will request extra evidence or clarification for \(request(for: requestID)?.organization ?? "this verification") in a later milestone."
                )
            } else {
                VerifyProvideInformationSheet(
                    organization: request(for: requestID)?.organization ?? "this verification",
                    text: $provideInformationText,
                    isSubmitting: actionInFlight == VerifyActionExecution(
                        requestID: requestID,
                        action: .submitInformation
                    ),
                    onSubmit: {
                        performRequestAction(
                            .submitInformation,
                            requestID: requestID,
                            response: provideInformationText
                        )
                    }
                )
            }
        }
    }

    private func declineRequest(_ requestID: String) {
        state = state.applying(.decline, to: requestID)
        presentedSheet = nil
    }
}

typealias VerifyRequestActionHandler = @Sendable (_ requestID: String, _ action: VerifyRequestAction, _ response: String?) async throws -> Void

private struct VerifyActionExecution: Equatable {
    let requestID: String
    let action: VerifyRequestAction
}

private struct VerifyActionError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private enum VerifyPresentedSheet: Identifiable {
    case requestDetail(String)
    case provideInformation(String)

    var id: String {
        switch self {
        case .requestDetail(let requestID):
            "request.\(requestID)"
        case .provideInformation(let requestID):
            "provide.\(requestID)"
        }
    }
}

private struct VerifySectionTitle: View {
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        Text(title)
            .font(KairoTypography.title2)
            .foregroundStyle(KairoColors.textPrimary)
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct VerifySectionEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.textSecondary)
            .tracking(0.4)
    }
}

private struct VerifyDataSourceBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.textSecondary)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(KairoColors.surface, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(KairoColors.border, lineWidth: 1)
            )
    }
}

private struct VerifyMetaPill: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(KairoTypography.footnote)
            .foregroundStyle(KairoColors.textSecondary)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(KairoColors.surfaceMuted.opacity(0.85), in: Capsule())
    }
}

private struct VerifyStatusBadge: View {
    let status: VerifyVerificationStatus

    var body: some View {
        Label(status.style.title, systemImage: status.style.symbol)
            .font(KairoTypography.caption)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(backgroundColor, in: Capsule())
            .accessibilityElement()
            .accessibilityLabel(status.style.title)
    }

    private var foregroundColor: Color {
        switch status.style.tone {
        case .accent:
            KairoColors.brandPrimary
        case .success:
            KairoColors.success
        case .warning:
            KairoColors.warning
        case .danger:
            KairoColors.danger
        case .neutral:
            KairoColors.textSecondary
        }
    }

    private var backgroundColor: Color {
        switch status.style.tone {
        case .accent:
            KairoColors.brandPrimary.opacity(0.12)
        case .success:
            KairoColors.success.opacity(0.12)
        case .warning:
            KairoColors.warning.opacity(0.14)
        case .danger:
            KairoColors.danger.opacity(0.12)
        case .neutral:
            KairoColors.surfaceMuted
        }
    }
}

private struct VerifyInlineButton: View {
    let title: String
    let accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairoSpacing.xSmall) {
                Text(title)
                    .font(KairoTypography.headline)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(KairoColors.brandPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, KairoSpacing.xSmall)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

private struct VerifyRequestDetailSheet: View {
    let request: VerifyRequest
    let isLive: Bool
    let actionInFlight: VerifyActionExecution?
    let onAccept: () -> Void
    let onProvideInformation: () -> Void
    let onSubmitForReview: () -> Void
    let onResubmitForReview: () -> Void
    let onDecline: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showsDeclineConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        VerifySectionEyebrow(title: "Verification request")

                        Text(request.type)
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)

                        Text(request.organization)
                            .font(KairoTypography.headline)
                            .foregroundStyle(KairoColors.textSecondary)

                        VerifyStatusBadge(status: request.status)
                    }

                    KairoCard {
                        detailRow(title: "Requester", value: request.requester)
                        detailRow(title: "Requested item", value: request.requestedItem)
                        detailRow(title: "Current status", value: request.status.style.title)
                        detailRow(title: "Timeline", value: request.timelineSummary)
                        detailRow(title: "Required action", value: request.requiredAction)
                        detailRow(title: "Evidence requirements", value: request.evidenceRequirement)
                        detailRow(title: "Supporting note", value: request.supportingNote)
                    }

                    if !request.timeline.isEmpty {
                        KairoCard {
                            VerifySectionEyebrow(title: "Timeline")

                            ForEach(Array(request.timeline.enumerated()), id: \.element.id) { index, event in
                                if index > 0 {
                                    Divider()
                                }

                                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                    Text(event.title)
                                        .font(KairoTypography.headline)
                                        .foregroundStyle(KairoColors.textPrimary)

                                    Text(event.source)
                                        .font(KairoTypography.body)
                                        .foregroundStyle(KairoColors.textSecondary)

                                    Text(event.dateLabel)
                                        .font(KairoTypography.footnote)
                                        .foregroundStyle(KairoColors.textSecondary)
                                }
                            }
                        }
                    }

                    if !request.availableActions.isEmpty || !isLive {
                        VStack(alignment: .leading, spacing: KairoSpacing.small) {
                            actionButtons
                        }
                    }
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Request detail")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier(KairoAccessibilityID.verifyRequestDetail)
        .confirmationDialog(
            "Decline this request?",
            isPresented: $showsDeclineConfirmation,
            titleVisibility: .visible
        ) {
            Button("Decline request", role: .destructive) {
                onDecline()
                dismiss()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This local action does not send any response. It only updates the fixture state for this session.")
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var actionButtons: some View {
        if request.availableActions.contains(.accept) {
            KairoPrimaryButton(
                title: "Accept request",
                accessibilityIdentifier: KairoAccessibilityID.verifyAcceptRequest,
                action: {
                    onAccept()
                    if isLive {
                        dismiss()
                    }
                }
            )
            .disabled(actionInFlight == VerifyActionExecution(requestID: request.id, action: .accept))
        }

        if request.availableActions.contains(.submitInformation) {
            KairoSecondaryButton(
                title: "Provide information",
                accessibilityIdentifier: KairoAccessibilityID.verifyProvideInformation,
                action: { onProvideInformation() }
            )
            .disabled(actionInFlight == VerifyActionExecution(requestID: request.id, action: .submitInformation))
        }

        if request.availableActions.contains(.submitForReview) {
            KairoPrimaryButton(
                title: "Submit for review",
                action: {
                    onSubmitForReview()
                    if isLive {
                        dismiss()
                    }
                }
            )
            .disabled(actionInFlight == VerifyActionExecution(requestID: request.id, action: .submitForReview))
        }

        if request.availableActions.contains(.resubmitForReview) {
            KairoPrimaryButton(
                title: "Resubmit for review",
                action: {
                    onResubmitForReview()
                    if isLive {
                        dismiss()
                    }
                }
            )
            .disabled(actionInFlight == VerifyActionExecution(requestID: request.id, action: .resubmitForReview))
        }

        if !isLive {
            KairoSecondaryButton(
                title: "Decline request",
                accessibilityIdentifier: KairoAccessibilityID.verifyDeclineRequest,
                action: { showsDeclineConfirmation = true }
            )
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            Text(value)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct VerifyProvideInformationSheet: View {
    let organization: String
    @Binding var text: String
    let isSubmitting: Bool
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                KairoCard {
                    Text("Provide information")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text("Share the clarification Kairo requested for \(organization).")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoCard {
                    Text("Response")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)

                    TextEditor(text: $text)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textPrimary)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .padding(KairoSpacing.small)
                        .background(
                            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                                .fill(KairoColors.surfaceMuted)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                                .stroke(KairoColors.border, lineWidth: 1)
                        )
                }

                KairoPrimaryButton(
                    title: isSubmitting ? "Submitting..." : "Submit information",
                    action: onSubmit
                )
                .disabled(trimmedText.isEmpty || isSubmitting)

                KairoSecondaryButton(
                    title: "Cancel",
                    action: { dismiss() }
                )
                .disabled(isSubmitting)
            }
            .padding(.horizontal, KairoSpacing.large)
            .padding(.vertical, KairoSpacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Provide information")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private struct VerifySimpleSheet: View {
    let title: String
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                KairoCard {
                    Text(title)
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text(message)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoPrimaryButton(
                    title: "Done",
                    action: { dismiss() }
                )
            }
            .padding(.horizontal, KairoSpacing.large)
            .padding(.vertical, KairoSpacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

private extension View {
    @ViewBuilder
    func refreshableIfAvailable(action: (() async -> Void)?) -> some View {
        if let action {
            refreshable {
                await action()
            }
        } else {
            self
        }
    }
}
