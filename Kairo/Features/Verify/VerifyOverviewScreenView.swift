import SwiftUI

struct VerifyOverviewScreenView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var currentState: VerifyOverviewState
    @State private var presentedSheet: VerifyPresentedSheet?
    @State private var startVerificationState: VerifyStartVerificationSheetState

    init(state: VerifyOverviewState) {
        _currentState = State(initialValue: state)
        _startVerificationState = State(initialValue: VerifyStartVerificationSheetState())
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.verifyScreen)
        .sheet(item: $presentedSheet) { destination in
            sheetDestination(for: destination)
        }
    }

    private var supportLine: some View {
        HStack(alignment: .top, spacing: KairoSpacing.small) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KairoColors.accent)

            Text(currentState.header.supportingLine)
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
        switch currentState.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your Trust Center",
                message: "Kairo is assembling your next verification priorities."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message
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

            KairoCard {
                Text("Suggested first step")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Verify your current employment to start turning your professional history into reusable trust.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                KairoPrimaryButton(
                    title: "Start your first verification",
                    accessibilityIdentifier: KairoAccessibilityID.verifyStartVerification,
                    action: { openStartVerification(preselected: .employment) }
                )

                KairoSecondaryButton(
                    title: "View Trust Passport",
                    accessibilityIdentifier: KairoAccessibilityID.verifyViewTrustPassport,
                    action: { router.selectTab(.passport) }
                )
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

            KairoPrimaryButton(
                title: "Start verification",
                accessibilityIdentifier: KairoAccessibilityID.verifyStartVerification,
                action: { openStartVerification(preselected: .employment) }
            )
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

    private func suggestedNextSection(_ suggestions: [VerifySuggestion]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            VerifySectionTitle(
                title: "Suggested next",
                accessibilityIdentifier: KairoAccessibilityID.verifySuggestedNextSection
            )

            KairoCard {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    if index > 0 {
                        Divider()
                    }

                    HStack(alignment: .top, spacing: KairoSpacing.medium) {
                        ZStack {
                            RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                                .fill(KairoColors.surfaceMuted)

                            Image(systemName: suggestion.type.systemImage)
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

                    VerifyInlineButton(
                        title: "Start",
                        accessibilityIdentifier: KairoAccessibilityID.verifySuggestedAction(suggestion.type.rawValue),
                        action: { openStartVerification(preselected: suggestion.type) }
                    )
                }
            }
        }
    }

    private var dataSourceLabel: String? {
        switch currentState.phase {
        case .populated(let content):
            content.dataSourceLabel
        case .empty(let content):
            content.dataSourceLabel
        case .loading, .error:
            nil
        }
    }

    private var activeContent: VerifyOverviewContent? {
        guard case .populated(let content) = currentState.phase else {
            return nil
        }

        return content
    }

    private func request(for id: String) -> VerifyRequest? {
        activeContent?.request(id: id)
    }

    private func openStartVerification(preselected: VerifyVerificationKind?) {
        startVerificationState = VerifyStartVerificationSheetState(selectedType: preselected)
        presentedSheet = .startVerification
    }

    private func acceptRequest(_ requestID: String) {
        currentState = currentState.applying(.accept, to: requestID)
        presentedSheet = nil
    }

    private func declineRequest(_ requestID: String) {
        currentState = currentState.applying(.decline, to: requestID)
        presentedSheet = nil
    }

    @ViewBuilder
    private func sheetDestination(for destination: VerifyPresentedSheet) -> some View {
        switch destination {
        case .requestDetail(let requestID):
            if let request = request(for: requestID) {
                VerifyRequestDetailSheet(
                    request: request,
                    onAccept: { acceptRequest(requestID) },
                    onProvideInformation: {
                        presentedSheet = .provideInformation(requestID)
                    },
                    onDecline: { declineRequest(requestID) }
                )
            } else {
                VerifySimpleSheet(
                    title: "Request unavailable",
                    message: "The selected request is no longer available in this local session."
                )
            }
        case .provideInformation(let requestID):
            VerifySimpleSheet(
                title: "Provide information",
                message: "This local placeholder confirms where Kairo will request extra evidence or clarification for \(request(for: requestID)?.organization ?? "this verification") in a later milestone."
            )
        case .startVerification:
            VerifyStartVerificationSheet(
                state: $startVerificationState
            )
        }
    }
}

private enum VerifyPresentedSheet: Identifiable {
    case requestDetail(String)
    case provideInformation(String)
    case startVerification

    var id: String {
        switch self {
        case .requestDetail(let requestID):
            "request.\(requestID)"
        case .provideInformation(let requestID):
            "provide.\(requestID)"
        case .startVerification:
            "startVerification"
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
    let onAccept: () -> Void
    let onProvideInformation: () -> Void
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
                        detailRow(title: "Supporting note", value: request.supportingNote)
                    }

                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                        KairoPrimaryButton(
                            title: "Accept request",
                            accessibilityIdentifier: KairoAccessibilityID.verifyAcceptRequest,
                            action: {
                                onAccept()
                                dismiss()
                            }
                        )

                        KairoSecondaryButton(
                            title: "Provide information",
                            accessibilityIdentifier: KairoAccessibilityID.verifyProvideInformation,
                            action: { onProvideInformation() }
                        )

                        KairoSecondaryButton(
                            title: "Decline request",
                            accessibilityIdentifier: KairoAccessibilityID.verifyDeclineRequest,
                            action: { showsDeclineConfirmation = true }
                        )
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

private struct VerifyStartVerificationSheet: View {
    @Binding var state: VerifyStartVerificationSheetState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    switch state.phase {
                    case .form:
                        selectionContent
                    case .confirmation(let type):
                        confirmationContent(for: type)
                    }
                }
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Start verification")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier(KairoAccessibilityID.verifyStartVerificationSheet)
        .presentationDetents([.large])
    }

    private var selectionContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoCard {
                VerifySectionEyebrow(title: "Choose verification")

                Text("Select what you want to verify")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Use this local flow to preview how Kairo will guide new verification starts before backend submission is connected.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(VerifyVerificationKind.allCases) { type in
                    VerifySelectionButton(
                        type: type,
                        isSelected: state.selectedType == type,
                        action: { state.select(type) }
                    )
                }
            }

            if let selectedType = state.selectedType {
                KairoCard {
                    Text("\(selectedType.title) details")
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)

                    startVerificationForm(for: selectedType)
                }
            }

            KairoPrimaryButton(
                title: "Continue",
                action: { state.continueFlow() }
            )
            .disabled(!state.isContinueEnabled)

            KairoSecondaryButton(
                title: "Close",
                action: { dismiss() }
            )
        }
    }

    @ViewBuilder
    private func startVerificationForm(for type: VerifyVerificationKind) -> some View {
        switch type {
        case .employment:
            KairoTextField(
                title: "Organisation",
                prompt: "Organisation",
                text: $state.employment.organization
            )
            KairoTextField(
                title: "Role",
                prompt: "Role",
                text: $state.employment.role
            )
            KairoTextField(
                title: "Start date",
                prompt: "Start date",
                text: $state.employment.startDate
            )
            KairoTextField(
                title: "End date / current role",
                prompt: "End date or current role",
                text: $state.employment.endDate
            )
        case .education:
            KairoTextField(
                title: "Institution",
                prompt: "Institution",
                text: $state.education.institution
            )
            KairoTextField(
                title: "Qualification",
                prompt: "Qualification",
                text: $state.education.qualification
            )
            KairoTextField(
                title: "Graduation year",
                prompt: "Graduation year",
                text: $state.education.graduationYear
            )
        case .certification:
            KairoTextField(
                title: "Issuer",
                prompt: "Issuer",
                text: $state.certification.issuer
            )
            KairoTextField(
                title: "Certification name",
                prompt: "Certification name",
                text: $state.certification.certificationName
            )
            KairoTextField(
                title: "Issue date",
                prompt: "Issue date",
                text: $state.certification.issueDate
            )
        case .project:
            KairoTextField(
                title: "Project name",
                prompt: "Project name",
                text: $state.project.projectName
            )
            KairoTextField(
                title: "Role",
                prompt: "Role",
                text: $state.project.role
            )
            KairoTextField(
                title: "Evidence note",
                prompt: "Evidence note",
                text: $state.project.evidenceNote
            )
        }
    }

    private func confirmationContent(for type: VerifyVerificationKind) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoCard {
                VerifySectionEyebrow(title: "Local confirmation")

                Text("\(type.title) verification ready")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Kairo will connect real submission, outreach, and permanent verification tracking in a later milestone. For now, this confirms the native start flow and keeps Verify routing intact.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KairoCard {
                ForEach(state.selectedFieldRows) { row in
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text(row.title)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)

                        Text(row.value)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            KairoPrimaryButton(
                title: "Done",
                action: { dismiss() }
            )

            KairoSecondaryButton(
                title: "Back",
                action: { state.phase = .form }
            )
        }
    }
}

private struct VerifySelectionButton: View {
    let type: VerifyVerificationKind
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                ZStack {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .fill(isSelected ? KairoColors.brandPrimary.opacity(0.14) : KairoColors.surfaceMuted)

                    Image(systemName: type.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? KairoColors.brandPrimary : KairoColors.textSecondary)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(type.title)
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text(type.supportingCopy)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: KairoSpacing.small)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? KairoColors.brandPrimary : KairoColors.border)
                    .padding(.top, KairoSpacing.xxSmall)
            }
            .padding(KairoSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .fill(KairoColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .stroke(isSelected ? KairoColors.brandPrimary : KairoColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
