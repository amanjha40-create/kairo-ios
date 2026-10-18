import SwiftUI

struct VerifyOverviewFixtureHostView: View {
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @State private var state: VerifyOverviewState

    init(state: VerifyOverviewState) {
        _state = State(initialValue: state)
    }

    var body: some View {
        VerifyOverviewScreenView(
            state: $state,
            focusedRequestID: refreshStore.focusedVerificationRequestID,
            authoritativeFocusedRequestID: refreshStore.focusedVerificationRequestID,
            focusedRequestPresentedHandler: { requestID in
                refreshStore.clearVerificationFocus(requestID: requestID)
            }
        )
    }
}

struct VerifyOverviewScreenView: View {
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var digiLockerStore: DigiLockerStore
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var state: VerifyOverviewState
    private let retryAction: (() -> Void)?
    private let refreshAction: (() async -> Void)?
    private let requestActionHandler: VerifyRequestActionHandler?
    private let startVerificationHandler: ((VerificationInitiationPreset) -> Void)?
    private let focusedRequestID: String?
    private let authoritativeFocusedRequestID: String?
    private let focusedRequestPresentedHandler: ((String) -> Void)?

    @State private var selectedFilter: VerifyRequestFilter = .all
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
        authoritativeFocusedRequestID: String? = nil,
        focusedRequestPresentedHandler: ((String) -> Void)? = nil
    ) {
        _state = state
        self.retryAction = retryAction
        self.refreshAction = refreshAction
        self.requestActionHandler = requestActionHandler
        self.startVerificationHandler = startVerificationHandler
        self.focusedRequestID = focusedRequestID
        self.authoritativeFocusedRequestID = authoritativeFocusedRequestID
        self.focusedRequestPresentedHandler = focusedRequestPresentedHandler
    }

    var body: some View {
        KairoScreenContainer(
            title: "Verification activity",
            titleAccessibilityIdentifier: CandidateTab.verify.titleAccessibilityIdentifier
        ) {
            DigiLockerVerifySections()
            PermanentAddressEntry()
            filterControl
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
        .onChange(of: authoritativeFocusedRequestID) { _, _ in
            presentFocusedRequestIfAvailable()
        }
        .onChange(of: router.selectedTab) { _, _ in
            presentFocusedRequestIfAvailable()
        }
        .onAppear { presentFocusedRequestIfAvailable() }
        .task { await digiLockerStore.loadSummaryIfNeeded() }
    }

    private var loadedRequests: [VerifyRequest]? {
        switch state.phase {
        case .populated(let content): content.requests
        case .empty: []
        case .loading, .error: nil
        }
    }

    private var filterControl: some View {
        Menu {
            Picker("Filter verification requests", selection: $selectedFilter) {
                ForEach(VerifyRequestFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                        .accessibilityIdentifier("verify.filter.option.\(filter.rawValue)")
                }
            }
        } label: {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                        Text(selectedFilter.title).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Image(systemName: "line.3.horizontal.decrease").accessibilityHidden(true)
                            filterCount
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down").accessibilityHidden(true)
                        }
                        .font(KairoTypography.caption)
                    }
                } else {
                    HStack(spacing: KairoSpacing.small) {
                        Image(systemName: "line.3.horizontal.decrease").accessibilityHidden(true)
                        Text(selectedFilter.title).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        filterCount
                        Image(systemName: "chevron.down").accessibilityHidden(true)
                    }
                }
            }
            .font(KairoTypography.bodyStrong)
            .multilineTextAlignment(.leading)
            .foregroundStyle(KairoColors.textPrimary)
            .padding(KairoSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(KairoColors.surface, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Filter verification requests")
        .accessibilityValue("Selected: \(selectedFilter.title)")
        .accessibilityIdentifier("verify.filter")
    }

    @ViewBuilder
    private var filterCount: some View {
        if let requests = loadedRequests {
            Text("\(selectedFilter.requests(in: requests).count)").monospacedDigit()
                .accessibilityIdentifier("verify.filter.count")
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .loading:
            ProgressView("Loading verification requests")
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("verify.loading")
        case .error(let error):
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Text(error.title).font(KairoTypography.headline)
                Text(error.message).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                if let retryAction {
                    Button("Retry", action: retryAction).buttonStyle(KairoActionStyle())
                        .accessibilityIdentifier("verify.retry")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("verify.error")
        case .empty(let content):
            filteredList([])
            if selectedFilter == .all {
                if let title = content.primaryActionTitle, let action = content.primaryAction {
                    Button(title) { handle(callToAction: action) }.buttonStyle(KairoActionStyle())
                        .accessibilityIdentifier(KairoAccessibilityID.verifyStartVerification)
                }
                if let title = content.secondaryActionTitle, let action = content.secondaryAction {
                    Button(title) { handle(callToAction: action) }.buttonStyle(KairoActionStyle())
                        .accessibilityIdentifier(KairoAccessibilityID.verifyViewTrustPassport)
                }
            }
        case .populated(let content):
            filteredList(content.requests)
        }
    }

    private func filteredList(_ requests: [VerifyRequest]) -> some View {
        let visible = selectedFilter.requests(in: requests)
        return VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            if visible.isEmpty {
                Text(selectedFilter.emptyMessage).font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(KairoAccessibilityID.verifyEmptyState)
            } else {
                ForEach(VerifyListGroup.allCases) { group in
                    let rows = visible.filter { group.includes($0.status) }
                    if !rows.isEmpty {
                        KairoSection(compact: true) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(group.title).font(KairoTypography.sectionTitle)
                                    .accessibilityAddTraits(.isHeader)
                                    .accessibilityIdentifier(group.accessibilityIdentifier)
                                Spacer(minLength: KairoSpacing.small)
                                Text("\(rows.count)").font(KairoTypography.footnote).monospacedDigit()
                                    .foregroundStyle(KairoColors.textSecondary)
                                    .accessibilityLabel("\(group.title): \(rows.count) requests")
                                    .accessibilityIdentifier("\(group.accessibilityIdentifier).count")
                            }
                            ForEach(Array((group == .completed ? Array(rows.prefix(3)) : rows).enumerated()), id: \.element.id) { index, request in
                                if index > 0 { Divider() }
                                VerifyCompactRequestRow(request: request) {
                                    presentedSheet = .requestDetail(request.id)
                                }
                            }
                            if group == .completed && rows.count > 3 {
                                KairoDisclosure(title: "View all \(rows.count) completed requests", identifier: "verify.completed.more") {
                                    ForEach(Array(rows.dropFirst(3))) { request in
                                        VerifyCompactRequestRow(request: request) { presentedSheet = .requestDetail(request.id) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.24), value: selectedFilter)
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
        guard router.selectedTab == .career, router.showsCareerVerification, let focusedRequestID else { return }
        switch VerifyFocusedDestination.resolve(target: focusedRequestID,
                                                authoritativeFocusID: authoritativeFocusedRequestID, state: state) {
        case .pending:
            return
        case .unavailable:
            focusedRequestPresentedHandler?(focusedRequestID)
            actionError = VerifyActionError(
                title: "Request no longer available",
                message: "KairoID opened your current verification list because that request could not be found. Pull to refresh if its status changed recently."
            )
        case .request(let requestID):
            presentedSheet = .requestDetail(requestID)
        }
    }

    private func performRequestAction(
        _ action: VerifyRequestAction,
        requestID: String,
        response: String? = nil,
        consent: VerificationSubmissionConsent? = nil
    ) {
        guard actionInFlight == nil else { return }
        if action == .withdraw, request(for: requestID)?.status.canCandidateWithdraw != true { return }
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
                    try await requestActionHandler(routeRequestID, action, response, consent)
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
        case .submitForReview, .resubmitForReview, .withdraw:
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
            return switch networkError {
            case .transport: "KairoID couldn't reach Verify. Check your connection and try again."
            case .api: "KairoID couldn't complete that Verify action. Refresh and try again."
            case .invalidResponse: "KairoID received an unexpected Verify response. Please try again."
            case .invalidURL: "KairoID's Verify configuration is invalid."
            case .unavailableInDemoMode: "This Verify action is unavailable in Demo Mode."
            }
        }

        return "KairoID couldn't complete that Verify action. Please try again."
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
                    onSubmitForReview: { presentedSheet = .submissionConsent(requestID) },
                    onResubmitForReview: { performRequestAction(.resubmitForReview, requestID: requestID) },
                    onWithdraw: { performRequestAction(.withdraw, requestID: requestID) },
                    onOpenCareer: {
                        presentedSheet = nil
                        router.selectTab(.career)
                    }
                )
                .onAppear {
                    // A requested sheet is not yet a successfully presented destination.
                    guard let focusedRequestID,
                          VerifyFocusedDestination.resolve(target: focusedRequestID,
                              authoritativeFocusID: authoritativeFocusedRequestID, state: state) == .request(requestID) else { return }
                    focusedRequestPresentedHandler?(focusedRequestID)
                }
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
                    message: "This local placeholder confirms where KairoID will request extra evidence or clarification for \(request(for: requestID)?.organization ?? "this verification") in a later milestone."
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
        case .submissionConsent(let requestID):
            if let request = request(for: requestID) {
                VerifySubmissionConsentSheet(
                    request: request,
                    isSubmitting: actionInFlight == VerifyActionExecution(
                        requestID: requestID,
                        action: .submitForReview
                    ),
                    onSubmit: { consent in
                        performRequestAction(
                            .submitForReview,
                            requestID: requestID,
                            consent: consent
                        )
                    }
                )
            } else {
                VerifySimpleSheet(
                    title: "Request unavailable",
                    message: "The selected request is no longer available in this session."
                )
            }
        }
    }

}

typealias VerifyRequestActionHandler = @Sendable (
    _ requestID: String,
    _ action: VerifyRequestAction,
    _ response: String?,
    _ consent: VerificationSubmissionConsent?
) async throws -> Void

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
    case submissionConsent(String)

    var id: String {
        switch self {
        case .requestDetail(let requestID):
            "request.\(requestID)"
        case .provideInformation(let requestID):
            "provide.\(requestID)"
        case .submissionConsent(let requestID):
            "consent.\(requestID)"
        }
    }
}

private struct VerifySectionEyebrow: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(KairoTypography.sectionTitle)
            .foregroundStyle(KairoColors.textSecondary)
            .tracking(0.4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct VerifyStatusBadge: View {
    let status: VerifyVerificationStatus

    private var tone: KairoStatusTone {
        switch status.style.tone {
        case .accent: .pending
        case .success: .verified
        case .warning: .attention
        case .danger: .rejected
        case .neutral: .draft
        }
    }

    var body: some View {
        KairoStatusChip(title: status.style.title, tone: tone, systemImage: status.style.symbol)
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
    let onWithdraw: () -> Void
    let onOpenCareer: () -> Void

    @State private var confirmsWithdrawal = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                        Text(request.type).font(KairoTypography.title2).foregroundStyle(KairoColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        VerifyStatusBadge(status: request.status).accessibilityIdentifier("verify.detail.status")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("verify.detail.header")

                    Text(request.requestedItem).font(KairoTypography.bodyStrong)
                    Text(request.organization).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    nextActionSection

                    KairoSection(compact: true) {
                      KairoDisclosure(title: "Claim", identifier: "verify.detail.section.claim") {
                        detailRow(title: "Requested item", value: request.requestedItem)
                        detailRow(title: "Organization", value: request.organization)
                        detailRow(title: "Requester", value: request.requester)
                      }
                    }

                    KairoSection(compact: true) {
                      KairoDisclosure(title: "Shared information", summary: "\(VerificationSharedLabels.labels(request.consentedFields).count) fields", identifier: "verify.detail.section.sharing") {
                        let labels = VerificationSharedLabels.labels(request.consentedFields)
                        Text(labels.isEmpty ? "No recognized shared fields supplied." : labels.joined(separator: ", "))
                      }
                      KairoDisclosure(title: "Consent", identifier: "verify.detail.section.consent") {
                        detailRow(title: "Evidence scope", value: request.consentedEvidenceScope.isEmpty
                            ? "No evidence consent scope supplied." : request.consentedEvidenceScope.map(VerificationSharedLabels.evidenceLabel).joined(separator: ", "))
                        if let date = request.consentedAt {
                            detailRow(title: "Consent recorded", value: date.formatted(date: .abbreviated, time: .shortened))
                        }
                        if let version = request.consentVersion, !version.isEmpty {
                            detailRow(title: "Consent version", value: version)
                        }
                      }
                    }

                    KairoDisclosure(title: "Verification contact", identifier: "verify.detail.section.contact") {
                    if let contact = request.verificationContact {
                        contactCard(contact)
                    } else {
                        KairoSection(compact: true) {
                            detailRow(title: "Organization", value: request.organization)
                            Text("No verification contact available.").font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                        }
                    }
                    }

                    if request.status.group == .pending { evidenceCard }
                    else {
                        KairoDisclosure(title: "Evidence", summary: "\(request.evidence.count) documents", identifier: "verify.detail.section.evidence") { evidenceCard }
                    }

                    KairoSection(compact: true) {
                      KairoDisclosure(title: "Timeline", summary: "\(request.timeline.count) events", identifier: "verify.detail.section.timeline") {
                        if request.timeline.isEmpty {
                            Text("No timeline events available.").font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                        }
                        ForEach(Array(request.timeline.enumerated()), id: \.element.id) { index, event in
                            if index > 0 { Divider() }
                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(event.title).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                                Text(event.dateLabel).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                Text(event.source).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("verify.detail.event.\(event.id)")
                        }
                      }
                    }

                    if !request.corrections.isEmpty { correctionsCard }

                    KairoSection(compact: true) {
                      KairoDisclosure(title: "Additional details", identifier: "verify.detail.section.metadata") {
                        detailRow(title: "Updated / due", value: request.dateLabel)
                        detailRow(title: "Latest activity", value: request.timelineSummary)
                        detailRow(title: "Supporting note", value: request.supportingNote)
                        if let reviewStatus = request.reviewStatus {
                            detailRow(title: "Review status", value: humanized(reviewStatus))
                        }
                      }
                    }
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Request detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }.disabled(actionInFlight != nil)
            } }
        }
        .accessibilityIdentifier(KairoAccessibilityID.verifyRequestDetail)
        .accessibilityValue(request.routeRequestID ?? request.id)
        .confirmationDialog("Withdraw this verification request?", isPresented: $confirmsWithdrawal, titleVisibility: .visible) {
            Button("Withdraw request", role: .destructive) { onWithdraw() }
            Button("Keep request", role: .cancel) { }
        } message: {
            Text("This is available only before verification outreach progresses. The request stays in history; the linked record returns to an editable draft. Verifying again creates a new request.")
        }
        .interactiveDismissDisabled(actionInFlight != nil)
        .presentationDetents([.large])
    }

    private var nextActionSection: some View {
        KairoSection(compact: true) {
            sectionHeading("Next action", id: "actions")
            Text(request.requiredAction).font(KairoTypography.body).fixedSize(horizontal: false, vertical: true)
            actionButtons
            if request.showsCareerRecovery {
                Text("Review the linked Career record, make any needed correction, then start a new verification when it is ready.")
                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                KairoSecondaryButton(title: "Open Career record", action: onOpenCareer)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if request.availableActions.contains(.withdraw), request.status.canCandidateWithdraw {
            Button("Withdraw request", role: .destructive) { confirmsWithdrawal = true }
                .buttonStyle(KairoActionStyle(role: .destructiveSecondary))
                .disabled(actionInFlight != nil)
                .accessibilityIdentifier("verify.request.withdraw")
        }
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
                action: onSubmitForReview
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


    }

    private func contactCard(_ contact: VerifyContactRecord) -> some View {
        KairoSection(compact: true) {
            detailRow(title: "Name", value: contact.name ?? "Not provided")
            detailRow(title: "Email", value: contact.email)
            detailRow(title: "Role", value: contact.role ?? "Not provided")
            detailRow(title: "Contact type", value: humanized(contact.type))
            detailRow(title: "Review status", value: humanized(contact.reviewStatus))
            if let note = contact.candidateNote, !note.isEmpty {
                detailRow(title: "Your note", value: note)
            }
            if let reviewNotes = contact.reviewNotes, !reviewNotes.isEmpty {
                detailRow(title: "Review note", value: reviewNotes)
            }
        }
    }

    private var evidenceCard: some View {
        KairoSection(compact: true) {
            sectionHeading("Evidence", id: "evidence.content")
            Text(request.evidenceRequirement).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if request.evidence.isEmpty {
                Text("No evidence is available to view for this request.").font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            }
            ForEach(request.evidence) { evidence in
                KairoDocumentRow(
                    filename: evidence.originalFilename ?? humanized(evidence.fieldKey),
                    metadata: humanized(evidence.evidenceType),
                    source: "Verification evidence",
                    status: humanized(evidence.status),
                    isHistorical: true,
                    details: {
                        if let size = evidence.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                                .font(KairoTypography.caption)
                                .foregroundStyle(KairoColors.textSecondary)
                        }
                    },
                    actions: {
                        if let url = evidence.downloadURL {
                            Button("View evidence") { openURL(url) }
                                .buttonStyle(KairoActionStyle())
                        } else {
                            Text("Historical evidence download is unavailable.")
                                .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                )
            }
        }
    }

    private var correctionsCard: some View {
        KairoSection(compact: true) {
            VerifySectionEyebrow(title: "Requested corrections")
            ForEach(Array(request.corrections.enumerated()), id: \.element.id) { index, correction in
                if index > 0 { Divider() }
                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    Text(humanized(correction.fieldKey))
                        .font(KairoTypography.headline)
                        .foregroundStyle(KairoColors.textPrimary)
                    Text(correction.requestText)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(correction.guidance, id: \.self) { guidance in
                        Text(guidance)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                    Text(humanized(correction.status))
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.warning)
                }
            }
        }
    }

    private func sectionHeading(_ title: String, id: String) -> some View {
        Text(title).font(KairoTypography.sectionTitle).foregroundStyle(KairoColors.textPrimary)
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("verify.detail.section.\(id)")
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

    private func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

private struct VerifySubmissionConsentSheet: View {
    let request: VerifyRequest
    let isSubmitting: Bool
    let onSubmit: (VerificationSubmissionConsent) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedFields: Set<String> = []
    @State private var selectedEvidenceScope: Set<String> = []
    @State private var confirmsAuthorization = false

    private var fieldOptions: [String] {
        unique(request.consentedFields + request.evidence.map(\.fieldKey).filter { !$0.isEmpty })
    }

    private var evidenceScopeOptions: [String] {
        unique(request.consentedEvidenceScope + request.evidence.map { evidence in
            if let documentType = evidence.documentType, !documentType.isEmpty {
                return documentType
            }
            return evidence.evidenceType
        }.filter { !$0.isEmpty })
    }

    private var canSubmit: Bool {
        confirmsAuthorization && (!selectedFields.isEmpty || !selectedEvidenceScope.isEmpty) && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoSection {
                        Text("Review what you are sharing")
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)
                        Text("Select only the fields and evidence scope you authorize KairoID to use for this verification request.")
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if fieldOptions.isEmpty && evidenceScopeOptions.isEmpty {
                        KairoEmptyStateView(
                            title: "No evidence is ready",
                            message: "Return to Career, attach the required evidence, then reopen this request.",
                            systemImage: "doc.badge.ellipsis"
                        )
                    } else {
                        if !fieldOptions.isEmpty {
                            consentOptionsCard(
                                title: "Requested fields",
                                options: fieldOptions,
                                selection: $selectedFields
                            )
                        }
                        if !evidenceScopeOptions.isEmpty {
                            consentOptionsCard(
                                title: "Evidence scope",
                                options: evidenceScopeOptions,
                                selection: $selectedEvidenceScope
                            )
                        }

                        KairoSection {
                            Toggle(isOn: $confirmsAuthorization) {
                                Text("I authorize KairoID to submit only the selected information and evidence for this verification.")
                                    .font(KairoTypography.body)
                                    .foregroundStyle(KairoColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .tint(KairoColors.brandPrimary)
                        }

                        KairoPrimaryButton(
                            title: "Consent and submit for review",
                            isLoading: isSubmitting,
                            action: submit
                        )
                        .disabled(!canSubmit)
                    }
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Submission consent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSubmitting)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func consentOptionsCard(
        title: String,
        options: [String],
        selection: Binding<Set<String>>
    ) -> some View {
        KairoSection {
            Text(title)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
            ForEach(options, id: \.self) { option in
                Toggle(
                    humanized(option),
                    isOn: Binding(
                        get: { selection.wrappedValue.contains(option) },
                        set: { enabled in
                            var updated = selection.wrappedValue
                            if enabled {
                                updated.insert(option)
                            } else {
                                updated.remove(option)
                            }
                            selection.wrappedValue = updated
                        }
                    )
                )
                .tint(KairoColors.brandPrimary)
            }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        onSubmit(
            VerificationSubmissionConsent(
                fields: fieldOptions.filter(selectedFields.contains),
                evidenceScope: evidenceScopeOptions.filter(selectedEvidenceScope.contains),
                version: request.consentVersion
            )
        )
    }

    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func humanized(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
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
                KairoSection {
                    Text("Provide information")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text("Share the clarification KairoID requested for \(organization).")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoSection {
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
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.large)
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
                KairoSection {
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
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.large)
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
