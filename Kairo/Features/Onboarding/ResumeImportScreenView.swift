import SwiftUI
import UniformTypeIdentifiers

struct ResumeImportScreenView: View {
    let createAccountDraft: CreateAccountDraft
    @Binding var state: ResumeImportState
    let onBuildProfileManually: () -> Void
    var context: ResumePresentationContext = .onboarding
    var onAuthenticatedCompletion: () -> Void = {}

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var candidateDataRefreshStore: CandidateDataRefreshStore
    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.resumeImportService) private var resumeImportService
    @Environment(\.careerOverviewService) private var careerOverviewService

    @State private var isFileImporterPresented = false
    @State private var activeEditorItem: ResumeReviewItem?
    @State private var distinctRoleConfirmationItem: ResumeReviewItem?
    @State private var editorValues: [String: String] = [:]
    @State private var mutationInFlight = false
    @State private var employmentDecisionSubmissionGate = ResumeEmploymentDecisionSubmissionGate()
    @State private var employmentDecisionErrorID: String?
    @State private var isVisible = false

    private var isPreviewMode: Bool {
        appConfiguration.isDemoModeEnabled || UITestResumeImportConfiguration.current().usesDemoReview
    }

    private var demoReviewPreview: ResumeImportReviewPreview {
        ResumeImportReviewPreview.fixture(
            name: [createAccountDraft.firstName, createAccountDraft.lastName]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: " "),
            emailAddress: createAccountDraft.emailAddress
        )
    }

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Upload resume",
            title: "Import your resume",
            subtitle: "We'll organise claims from your resume so you can review them before adding anything to KairoID.",
            titleAccessibilityIdentifier: KairoAccessibilityID.resumeImportPlaceholderTitle
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                reviewFirstBanner

                switch state.phase {
                case .initial:
                    introductoryCard
                case .selected:
                    selectedFileCard
                case .uploading, .processingPreparing, .processingOrganising, .hydratingReview, .importing:
                    processingCard
                case .failed:
                    failureCard
                case .readyForReview:
                    reviewContent
                case .confirmed:
                    if isPreviewMode {
                        reviewContent
                    } else {
                        importSummaryContent
                    }
                case .unsupportedFile:
                    unsupportedFileCard
                }
            }
        } actions: {
            actionContent
                .disabled(mutationInFlight)
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: ResumeImportFile.supportedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleImportResult
        )
        .sheet(item: $activeEditorItem) { item in
            ResumeReviewEditorSheet(
                item: item,
                values: $editorValues,
                onCancel: { activeEditorItem = nil },
                onSave: { Task { await saveEdits(for: item) } }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $distinctRoleConfirmationItem) { item in
            ResumeDistinctRoleConfirmationSheet(
                item: item,
                onCancel: { distinctRoleConfirmationItem = nil },
                onConfirm: {
                    distinctRoleConfirmationItem = nil
                    Task {
                        await updateEmploymentDecision(
                            for: item,
                            decision: .addAsNewRole,
                            distinctRoleConfirmed: true
                        )
                    }
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            isVisible = true
            guard !isPreviewMode, context == .onboarding else {
                return
            }

            state.prepareForEntryIntoLiveResumeImport()
        }
        .onDisappear {
            isVisible = false
            if !mutationInFlight { cleanupAbandonedAuthenticatedSelection() }
        }
        .task {
            await restoreLatestWorkflowIfNeeded()
        }
        .task(id: demoProcessingTaskKey) {
            guard isPreviewMode, state.autoAdvanceProcessing, state.phase.isProcessing else {
                return
            }

            try? await Task.sleep(for: .milliseconds(850))
            state.advanceProcessing()
        }
        .task(id: livePollingTaskKey) {
            guard !isPreviewMode else {
                return
            }

            await pollLiveWorkflowIfNeeded()
        }
    }

    private var demoProcessingTaskKey: String {
        "\(state.phase.rawValue)-\(state.processingAttemptCount)-\(state.autoAdvanceProcessing)"
    }

    private var livePollingTaskKey: String {
        [
            state.phase.rawValue,
            state.liveResume?.id ?? "-",
            state.liveReviewSession?.id ?? "-",
            state.liveImportBatch?.id ?? "-"
        ].joined(separator: "::")
    }

    private var introductoryCard: some View {
        VStack(spacing: KairoSpacing.small) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(KairoColors.accent)

            Text("Choose PDF or DOCX")
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)

            Text("Maximum file size: 10 MB")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .padding(KairoSpacing.medium)
        .background(KairoColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(KairoColors.border, style: StrokeStyle(lineWidth: 1, dash: [7, 6]))
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var reviewFirstBanner: some View {
        HStack(alignment: .top, spacing: KairoSpacing.small) {
            Image(systemName: "lock.shield")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(hex: 0x07122B))
                .frame(width: 32, height: 32)
                .background(KairoColors.accent.opacity(0.24), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                Text("Your review comes first")
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Imported resume information remains candidate-provided, not verified. No employer or institution is contacted automatically.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(KairoSpacing.medium)
        .background(KairoColors.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                .stroke(KairoColors.accent.opacity(0.28), lineWidth: 1)
        )
    }

    private var selectedFileCard: some View {
        KairoCard {
            fileSummaryHeader(title: "Resume selected")

            fileSummaryDetails

            Text(
                isPreviewMode
                    ? "Demo Mode keeps only minimal file metadata in the current seeded session."
                    : "KairoID will request a secure upload intent, upload your file without exposing your bearer token to storage, and confirm the checksum before parsing begins."
            )
            .font(KairoTypography.footnote)
            .foregroundStyle(KairoColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: KairoSpacing.large) {
                Button("Replace") {
                    isFileImporterPresented = true
                }
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.brandPrimary)
                .accessibilityIdentifier(KairoAccessibilityID.resumeImportReplaceButton)

                Button("Remove") {
                    clearSelectedResume()
                }
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .accessibilityIdentifier(KairoAccessibilityID.resumeImportRemoveButton)
            }
        }
    }

    private var processingCard: some View {
        KairoCard {
            HStack(alignment: .center, spacing: KairoSpacing.medium) {
                ProgressView()
                    .tint(KairoColors.brandPrimary)

                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    Text(state.currentProcessingTitle ?? "Preparing your resume")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.resumeImportProcessingTitle)

                    Text(state.currentProcessingMessage ?? "")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            fileSummaryDetails

            if !isPreviewMode, let processingStatus = state.currentProcessingStatus {
                Text("Backend status: \(processingStatus.title)")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var failureCard: some View {
        KairoErrorStateView(
            title: failureTitle,
            message: state.errorMessage ?? "Choose another resume to continue.",
            messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportFailureMessage
        )
    }

    private var failureTitle: String {
        state.failureStage?.title ?? "We couldn't prepare that resume"
    }

    private var unsupportedFileCard: some View {
        KairoErrorStateView(
            title: "That file isn't supported",
            message: state.errorMessage ?? "Choose a PDF or DOCX file.",
            messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportUnsupportedMessage
        )
    }

    @ViewBuilder
    private var reviewContent: some View {
        if isPreviewMode {
            demoReviewContent
        } else if let liveReviewSession = state.liveReviewSession,
                  !liveReviewSession.items.isEmpty {
            liveReviewContent(liveReviewSession)
        } else {
            KairoErrorStateView(
                title: "We couldn't load your review",
                message: ResumeReviewRecoveryFailure.missingItems.localizedDescription,
                messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportFailureMessage
            )
        }
    }

    private var demoReviewContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            KairoCard {
                fileSummaryHeader(title: state.readyTitle)

                Text(state.readyMessage)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                fileSummaryDetails
            }

            Text(demoReviewPreview.summary)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(demoReviewPreview.sections) { section in
                ResumeImportPreviewSectionCard(section: section)
            }
        }
    }

    private func liveReviewContent(_ reviewSession: ResumeReviewSession) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            KairoCard {
                fileSummaryHeader(title: state.readyTitle)

                Text(state.readyMessage)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                fileSummaryDetails

                let selectedCount = reviewSession.items.filter(\.selected).count
                let warningCount = reviewSession.items.reduce(0) { $0 + $1.conflictWarnings.count }

                HStack(spacing: KairoSpacing.medium) {
                    reviewStat(title: "Claims", value: "\(reviewSession.items.count)")
                    reviewStat(title: "Selected", value: "\(selectedCount)")
                    reviewStat(title: "Warnings", value: "\(warningCount)")
                }
            }

            if let liveReviewPlan = state.liveReviewPlan, !liveReviewPlan.blockers.isEmpty {
                KairoErrorStateView(
                    title: "Review changes are required",
                    message: liveReviewPlan.blockers.map(userFacingBlocker).joined(separator: " "),
                    messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportFailureMessage
                )
            } else {
                KairoCard {
                    Text("These are candidate-provided claims. Imported records remain unverified until KairoID verifies them separately.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            reviewedOutcomesCard(reviewSession)

            ForEach(state.reviewSections) { section in
                ResumeImportLiveReviewSectionCard(
                    section: section,
                    onToggleSelection: { item in
                        Task { await toggleSelection(for: item) }
                    },
                    onEdit: { item in
                        openEditor(for: item)
                    },
                    onKeepExisting: { item in
                        Task {
                            await updateEmploymentDecision(
                                for: item,
                                decision: .keepExisting,
                                distinctRoleConfirmed: false
                            )
                        }
                    },
                    onRequestAddAsNew: { item in
                        distinctRoleConfirmationItem = item
                    },
                    employmentDecisionInFlightID: employmentDecisionSubmissionGate.inFlightItemID,
                    employmentDecisionErrorID: employmentDecisionErrorID
                )
            }
        }
    }

    private func reviewedOutcomesCard(_ reviewSession: ResumeReviewSession) -> some View {
        KairoCard {
            Text("Reviewed outcomes")
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)

            Text("These are the decisions KairoID will send for final import.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(ResumeImportMapper.visibleItems(from: reviewSession)) { item in
                HStack(alignment: .top, spacing: KairoSpacing.small) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ResumeImportMapper.displayTitle(for: item))
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(item.claimType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                    Spacer(minLength: KairoSpacing.small)
                    Text(ResumeImportMapper.reviewedOutcome(for: item).rawValue)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.brandPrimary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityIdentifier(KairoAccessibilityID.resumeImportReviewedOutcomes)
    }

    @ViewBuilder
    private var importSummaryContent: some View {
        if let batch = state.liveImportBatch, batch.isTerminal {
            let summary = ResumeImportResultSummary(batch: batch)
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                KairoCard {
                    Label("Resume import complete", systemImage: "checkmark.seal.fill")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text("KairoID used the completed backend result. Existing Career records are not counted as newly added.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 96), spacing: KairoSpacing.small)],
                        alignment: .leading,
                        spacing: KairoSpacing.small
                    ) {
                        reviewStat(title: "Added", value: "\(summary.added)")
                        reviewStat(title: "Already in Career", value: "\(summary.alreadyInCareer)")
                        reviewStat(title: "Skipped", value: "\(summary.skipped)")
                        if summary.updated > 0 {
                            reviewStat(title: "Updated", value: "\(summary.updated)")
                        }
                        if summary.needsAttention > 0 {
                            reviewStat(title: "Needs attention", value: "\(summary.needsAttention)")
                        }
                    }

                    careerRefreshStatusView
                }

                if !batch.results.isEmpty {
                    KairoCard {
                        Text("Item outcomes")
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.textPrimary)

                        ForEach(batch.results) { result in
                            HStack(alignment: .top, spacing: KairoSpacing.small) {
                                Text(importResultTitle(for: result))
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: KairoSpacing.small)
                                Text(ResumeImportResultSummary.outcome(for: result).rawValue)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.brandPrimary)
                                    .multilineTextAlignment(.trailing)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .accessibilityIdentifier(KairoAccessibilityID.resumeImportFinalSummary)
        } else {
            KairoErrorStateView(
                title: "Import summary unavailable",
                message: "KairoID couldn't load the completed backend result yet.",
                messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportFailureMessage
            )
        }
    }

    @ViewBuilder
    private var careerRefreshStatusView: some View {
        switch state.postImportCareerRefreshStatus {
        case .succeeded:
            Label("Career refreshed from KairoID", systemImage: "arrow.clockwise.circle.fill")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
        case .failed:
            Label("Import is complete. Career will refresh again when you open it.", systemImage: "exclamationmark.arrow.circlepath")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .idle:
            EmptyView()
        }
    }

    private func importResultTitle(for result: ResumeImportResultItem) -> String {
        state.liveReviewSession?.items
            .first(where: { $0.id == result.reviewItemID })
            .map(ResumeImportMapper.displayTitle(for:))
            ?? result.recordType?.replacingOccurrences(of: "_", with: " ").capitalized
            ?? "Resume item"
    }

    private func reviewStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
            Text(title)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actionContent: some View {
        switch state.phase {
        case .initial, .unsupportedFile:
            OnboardingActionGroup(
                primaryTitle: "Choose Resume",
                primaryAccessibilityIdentifier: KairoAccessibilityID.resumeImportChooseButton,
                primaryAction: { isFileImporterPresented = true },
                secondaryTitle: context == .onboarding ? "Build profile manually" : nil,
                secondaryAccessibilityIdentifier: KairoAccessibilityID.resumeImportManualButton,
                secondaryAction: onBuildProfileManually
            )
        case .selected:
            OnboardingActionGroup(
                primaryTitle: "Import Resume",
                primaryAccessibilityIdentifier: KairoAccessibilityID.resumeImportPrepareButton,
                primaryAction: {
                    if isPreviewMode {
                        state.beginProcessing()
                    } else {
                        Task { await beginLiveUpload() }
                    }
                },
                secondaryTitle: context == .onboarding ? "Build profile manually" : nil,
                secondaryAccessibilityIdentifier: KairoAccessibilityID.resumeImportManualButton,
                secondaryAction: onBuildProfileManually
            )
        case .uploading, .processingPreparing, .processingOrganising, .hydratingReview:
            KairoPrimaryButton(
                title: state.currentProcessingTitle ?? "Processing resume",
                isLoading: true,
                accessibilityIdentifier: KairoAccessibilityID.resumeImportProcessingButton,
                action: {}
            )
            .disabled(true)
        case .importing:
            KairoPrimaryButton(
                title: state.currentProcessingTitle ?? "Importing approved claims",
                isLoading: true,
                accessibilityIdentifier: KairoAccessibilityID.resumeImportProcessingButton,
                action: {}
            )
            .disabled(true)
        case .failed:
            VStack(spacing: KairoSpacing.small) {
                KairoPrimaryButton(
                    title: retryButtonTitle,
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportRetryButton,
                    action: retryAction
                )

                if state.failureStage != .onboardingCompletion {
                    KairoSecondaryButton(
                        title: "Choose Another Resume",
                        accessibilityIdentifier: KairoAccessibilityID.resumeImportChooseAnotherButton,
                        action: clearSelectedResume
                    )
                }
            }
            .accessibilityElement(children: .contain)
        case .readyForReview:
            VStack(spacing: KairoSpacing.small) {
                KairoPrimaryButton(
                    title: "Looks Good",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportLooksGoodButton,
                    action: {
                        if isPreviewMode {
                            handlePreviewLooksGood()
                        } else {
                            Task { await handleLiveLooksGood() }
                        }
                    }
                )

                KairoSecondaryButton(
                    title: "Choose Another Resume",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportChooseAnotherButton,
                    action: clearSelectedResume
                )
            }
            .accessibilityElement(children: .contain)
        case .confirmed:
            KairoPrimaryButton(
                title: context == .authenticated ? "View Career" : "Continue",
                accessibilityIdentifier: KairoAccessibilityID.resumeImportViewCareerButton,
                action: {
                    if isPreviewMode {
                        handlePreviewLooksGood()
                    } else {
                        Task { await completeAfterImportSummary() }
                    }
                }
            )
        }
    }

    private var retryButtonTitle: String {
        switch state.failureStage {
        case .upload:
            "Choose Resume"
        case .parsing:
            "Retry Processing"
        case .reviewHydration:
            "Retry Review"
        case .review:
            "Return to Review"
        case .import:
            "Retry Import"
        case .onboardingCompletion:
            "Finish Setup"
        case nil:
            "Try Again"
        }
    }

    private var retryAction: () -> Void {
        if isPreviewMode {
            return { state.retryProcessing() }
        }

        switch state.failureStage {
        case .upload, nil:
            return { isFileImporterPresented = true }
        case .parsing:
            return { Task { await retryLiveProcessing() } }
        case .reviewHydration:
            return { Task { await retryReviewRecovery() } }
        case .review:
            return { state.returnToReviewAfterFailure() }
        case .import:
            return { Task { await retryImportSafely() } }
        case .onboardingCompletion:
            return { Task { await retryOnboardingCompletion() } }
        }
    }

    private var fileSummaryDetails: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            metadataRow(
                label: "File name",
                value: state.selectedFile?.fileName ?? "No file selected",
                valueAccessibilityIdentifier: KairoAccessibilityID.resumeImportFileName
            )
            metadataRow(label: "File type", value: state.selectedFile?.fileType ?? "Unknown")
            metadataRow(label: "File size", value: state.selectedFile?.fileSizeDescription ?? "Unknown size")
        }
    }

    private func fileSummaryHeader(title: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text("Nothing is added to your Trust Passport until you confirm it.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metadataRow(
        label: String,
        value: String,
        valueAccessibilityIdentifier: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)

            if let valueAccessibilityIdentifier {
                Text(value)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(valueAccessibilityIdentifier)
            } else {
                Text(value)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func restoreLatestWorkflowIfNeeded() async {
        guard context == .onboarding, !isPreviewMode, !state.restorationAttempted else {
            return
        }

        state.markRestorationAttempted()

        do {
            guard let snapshot = try await resumeImportService.restoreLatestWorkflow() else {
                return
            }

            if let reviewID = snapshot.reviewSession?.id,
               let importBatch = snapshot.importBatch,
               importBatch.isTerminal {
                state.applyRestoredWorkflow(snapshot)
                await reconcileImportRecovery(reviewID: reviewID)
                return
            }

            state.applyRestoredWorkflow(snapshot)
        } catch let error as ResumeImportServiceError {
            if case .reviewRecovery = error {
                state.setError(message(for: error), stage: .reviewHydration)
            } else {
                state.setError(message(for: error), stage: .parsing)
            }
        } catch {
            state.setError(message(for: error), stage: .parsing)
        }
    }

    private func pollLiveWorkflowIfNeeded() async {
        if state.phase == .hydratingReview, let resumeID = state.liveResume?.id {
            await hydrateLiveReviewSession(resumeID: resumeID)
            return
        }

        if let reviewID = state.liveReviewSession?.id,
           state.phase == .importing,
           let importBatch = state.liveImportBatch,
           !importBatch.isTerminal {
            await pollImportStatus(reviewID: reviewID)
            return
        }

        guard let resumeID = state.liveResume?.id else {
            return
        }

        guard state.phase == .processingPreparing || state.phase == .processingOrganising else {
            return
        }

        for _ in 0 ..< 120 {
            guard !Task.isCancelled else {
                return
            }

            do {
                let process = try await resumeImportService.processingStatus(resumeID: resumeID)
                state.applyProcessingJob(process)

                if process.status.isTerminal {
                    return
                }
            } catch {
                state.setError(message(for: error), stage: .parsing)
                return
            }

            try? await Task.sleep(for: .milliseconds(2500))
        }

        state.setError(
            "Resume processing is taking longer than expected. You can leave this screen and return later.",
            stage: .parsing
        )
    }

    private func pollImportStatus(reviewID: String) async {
        for _ in 0 ..< 120 {
            guard !Task.isCancelled else {
                return
            }

            do {
                let batch = try await resumeImportService.latestImportStatus(reviewID: reviewID)
                state.applyImportBatch(batch)

                if batch.isTerminal {
                    await handleTerminalImportBatch(batch)
                    return
                }
            } catch {
                state.setError(message(for: error), stage: .import)
                return
            }

            try? await Task.sleep(for: .milliseconds(2500))
        }

        state.setError(
            "Import is taking longer than expected. KairoID will resume from backend state when you return.",
            stage: .import
        )
    }

    private func handleImportResult(_ result: Result<[URL], any Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                return
            }

            let accessedSecurityScopedResource = url.startAccessingSecurityScopedResource()
            defer {
                if accessedSecurityScopedResource {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            if isPreviewMode {
                state.selectFile(from: url)
                return
            }

            do {
                let selection = try resumeImportService.prepareSelection(from: url)
                state.applyPreparedSelection(selection)
            } catch {
                state.setError(message(for: error), stage: .upload)
            }
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.domain != NSCocoaErrorDomain || nsError.code != NSUserCancelledError else {
                return
            }

            state.setError(
                "KairoID couldn't open that file. Choose another resume to continue.",
                stage: .upload
            )
        }
    }

    private func clearSelectedResume() {
        if let temporaryFileURL = state.selectedTemporaryFileURL, !isPreviewMode {
            resumeImportService.cleanupSelection(at: temporaryFileURL)
        }
        state.clearSelection()
    }

    private func beginLiveUpload() async {
        guard !mutationInFlight, state.canPrepareResume else { return }
        mutationInFlight = true
        defer {
            mutationInFlight = false
            if !isVisible { cleanupAbandonedAuthenticatedSelection() }
        }
        guard let selectedFile = state.selectedFile,
              let selectedTemporaryFileURL = state.selectedTemporaryFileURL
        else {
            return
        }

        state.phase = .uploading
        state.errorMessage = nil
        state.failureStage = nil
        state.statusTitleOverride = "Uploading your resume"
        state.statusMessageOverride = "KairoID is securely uploading your file before backend processing starts."

        let selection = ResumeImportPreparedSelection(
            file: selectedFile,
            temporaryFileURL: selectedTemporaryFileURL
        )
        let resume: ResumeRecord

        do {
            resume = try await resumeImportService.upload(selection: selection)
            resumeImportService.cleanupSelection(at: selectedTemporaryFileURL)
            state.selectedTemporaryFileURL = nil
            state.applyUploadStarted(resume: resume)
        } catch {
            state.setError(message(for: error), stage: .upload)
            return
        }

        do {
            let process = try await resumeImportService.startProcessing(resumeID: resume.id)
            state.applyProcessingJob(process)
        } catch {
            state.setError(message(for: error), stage: .parsing)
        }
    }

    private func retryLiveProcessing() async {
        guard !mutationInFlight else { return }
        mutationInFlight = true
        defer { mutationInFlight = false }
        guard let resumeID = state.liveResume?.id else {
            return
        }

        do {
            let process = try await resumeImportService.startProcessing(resumeID: resumeID)
            state.applyProcessingJob(process)
        } catch {
            state.setError(message(for: error), stage: .parsing)
        }
    }

    private func cleanupAbandonedAuthenticatedSelection() {
        guard context == .authenticated, !isPreviewMode,
              let temporaryURL = state.selectedTemporaryFileURL else { return }
        // The canonical service copied this file into its private temporary directory.
        // Never remove the founder's original picked document or a file still being uploaded.
        resumeImportService.cleanupSelection(at: temporaryURL)
        state.clearSelection()
    }

    private func hydrateLiveReviewSession(resumeID: String) async {
        do {
            let review = try await resumeImportService.loadOrCreateReviewSession(resumeID: resumeID)
            state.applyReviewSession(review)
        } catch {
            state.setError(message(for: error), stage: .reviewHydration)
        }
    }

    private func retryReviewRecovery() async {
        if let resumeID = state.liveResume?.id {
            state.beginReviewHydration()
            await hydrateLiveReviewSession(resumeID: resumeID)
            return
        }

        state.restorationAttempted = false
        state.beginReviewHydration()
        await restoreLatestWorkflowIfNeeded()
    }

    private func retryImportSafely() async {
        guard let reviewID = state.liveReviewSession?.id else {
            return
        }

        if state.liveImportBatch != nil {
            await reconcileImportRecovery(reviewID: reviewID)
        } else {
            await handleLiveLooksGood()
        }
    }

    private func retryOnboardingCompletion() async {
        do {
            try await finishSuccessfulImport()
        } catch {
            state.setError(
                onboardingCompletionMessage(for: error),
                stage: .onboardingCompletion
            )
        }
    }

    private func completeAfterImportSummary() async {
        do {
            try await finishSuccessfulImport()
        } catch {
            state.setError(
                onboardingCompletionMessage(for: error),
                stage: .onboardingCompletion
            )
        }
    }

    private func handlePreviewLooksGood() {
        state.confirmReview()
        if context == .onboarding { router.advanceOnboarding(from: .resumeImportOrQuickProfile) }
        else { onAuthenticatedCompletion() }
    }

    private func handleLiveLooksGood() async {
        guard !mutationInFlight else { return }
        mutationInFlight = true
        defer { mutationInFlight = false }
        guard let review = state.liveReviewSession else {
            return
        }

        state.beginImporting()
        var attemptedImportRequest = false

        do {
            let plan = try await resumeImportService.validateReview(
                reviewID: review.id,
                expectedVersion: review.version
            )
            state.applyReviewPlan(plan)

            if !plan.ready || !plan.blockers.isEmpty {
                let latest = try await resumeImportService.refreshReviewSession(reviewID: review.id)
                state.applyReviewSession(latest)
                state.setError(
                    plan.blockers.isEmpty
                        ? "KairoID needs updated review decisions before import can continue."
                        : plan.blockers.map(userFacingBlocker).joined(separator: " "),
                    stage: .review
                )
                return
            }

            attemptedImportRequest = true
            let batch = try await resumeImportService.importReview(
                reviewID: review.id,
                expectedVersion: state.liveReviewSession?.version ?? plan.version,
                idempotencyKey: state.ensureImportIdempotencyKey(for: review.id)
            )
            state.applyImportBatch(batch)

            if batch.isTerminal {
                await handleTerminalImportBatch(batch)
            }
        } catch let error as NetworkError {
            if attemptedImportRequest {
                await reconcileImportRecovery(reviewID: review.id)
            } else if case .api(let apiError) = error, apiError.code == .conflict {
                await reconcileImportRecovery(reviewID: review.id)
            } else {
                state.setError(message(for: error), stage: .review)
            }
        } catch {
            state.setError(
                message(for: error),
                stage: attemptedImportRequest ? .import : .review
            )
        }
    }

    private func handleTerminalImportBatch(_ batch: ResumeImportBatch) async {
        if batch.isCompletedWithoutHardFailures {
            var careerRefreshSucceeded = false
            if UITestResumeImportConfiguration.current().serviceScenario == .duplicateReview {
                // The isolated UI fixture has no live Career service or founder data.
                // Production and unit-test paths below always read backend Career truth.
                careerRefreshSucceeded = true
            } else {
                do {
                    _ = try await ResumePostImportCareerRefresh.loadAuthoritativeOverview {
                        try await careerOverviewService.loadOverview()
                    }
                    careerRefreshSucceeded = true
                } catch {
                    careerRefreshSucceeded = false
                }
            }
            candidateDataRefreshStore.candidateDataChanged()
            state.markImportConfirmed(careerRefreshSucceeded: careerRefreshSucceeded)
            return
        }

        guard batch.isPartiallyCompleted else {
            state.setError(importFailureMessage(for: batch), stage: .import)
            return
        }

        if batch.isPartiallyCompleted,
           let reviewID = state.liveReviewSession?.id,
           let latest = try? await resumeImportService.refreshReviewSession(reviewID: reviewID) {
            state.applyReviewSession(latest)
        }
        state.setError(importFailureMessage(for: batch), stage: .import)
    }

    private func finishSuccessfulImport(
        using completionResult: ResumeImportCompletionResult? = nil
    ) async throws {
        if context == .authenticated {
            candidateDataRefreshStore.candidateDataChanged()
            if isVisible { onAuthenticatedCompletion() }
            router.selectTab(.career)
            return
        }
        let resolvedCompletionResult: ResumeImportCompletionResult
        if let completionResult {
            resolvedCompletionResult = completionResult
        } else {
            resolvedCompletionResult = try await resumeImportService.completeOnboardingIfNeeded()
        }

        guard resolvedCompletionResult.isOnboardingComplete else {
            throw ResumeImportServiceError.onboardingIncomplete(
                resolvedCompletionResult.onboardingStatus
            )
        }

        sessionStore.replaceCurrentUser(resolvedCompletionResult.user)
        router.enterMainTabs(selectedTab: .home)
    }

    private func reconcileImportRecovery(reviewID: String) async {
        do {
            let recovery = try await resumeImportService.reconcileImportRecovery(reviewID: reviewID, context: context)

            switch recovery.disposition {
            case .importCompleted:
                state.applyReviewSession(recovery.reviewSession)
                guard let importBatch = recovery.importBatch else {
                    state.setError(
                        "KairoID refreshed the latest review, but the completed import summary is not available yet.",
                        stage: .import
                    )
                    activeEditorItem = nil
                    return
                }
                state.applyImportBatch(importBatch)
                await handleTerminalImportBatch(importBatch)
            case .importPartiallyCompleted:
                state.applyReviewSession(recovery.reviewSession)
                if let importBatch = recovery.importBatch {
                    state.applyImportBatch(importBatch)
                }
                if let importBatch = recovery.importBatch {
                    state.setError(importFailureMessage(for: importBatch), stage: .import)
                } else {
                    state.setError(
                        "Some imported claims still need your attention.",
                        stage: .import
                    )
                }
            case .importInProgress:
                state.applyReviewSession(recovery.reviewSession)
                guard let importBatch = recovery.importBatch else {
                    state.setError(
                        "KairoID is reconciling your import progress on the server. Please wait a moment and try again.",
                        stage: .import
                    )
                    activeEditorItem = nil
                    return
                }

                state.beginImporting()
                state.applyImportBatch(importBatch)
                await pollImportStatus(reviewID: reviewID)
            case .noImportToResume:
                state.applyReviewSession(recovery.reviewSession)
                if let importBatch = recovery.importBatch {
                    state.applyImportBatch(importBatch)
                }
                state.setError(
                    "Your resume review changed on the server. KairoID refreshed the latest version so you can continue safely.",
                    stage: .review
                )
            }

            activeEditorItem = nil
        } catch {
            let stage: ResumeImportFailureStage =
                state.liveImportBatch?.isCompletedWithoutHardFailures == true
                    ? .onboardingCompletion
                    : .import
            state.setError(
                stage == .onboardingCompletion
                    ? onboardingCompletionMessage(for: error)
                    : message(for: error),
                stage: stage
            )
        }
    }

    private func refreshReviewAfterConflict(reviewID: String) async {
        await reconcileImportRecovery(reviewID: reviewID)
    }

    private func toggleSelection(for item: ResumeReviewItem) async {
        guard let review = state.liveReviewSession else {
            return
        }

        let desiredSelected = !item.selected

        do {
            let updated = try await resumeImportService.updateReviewItem(
                reviewID: review.id,
                itemID: item.id,
                payload: ResumeImportMapper.selectionUpdateRequest(
                    for: item,
                    selected: desiredSelected
                )
            )
            state.applyReviewSession(updated)
        } catch let error as NetworkError {
            if case .api(let apiError) = error, apiError.code == .conflict {
                await recoverConflictedReviewItemUpdate(
                    reviewID: review.id,
                    itemID: item.id,
                    desiredSelected: desiredSelected
                )
            } else {
                state.setError(message(for: error), stage: .review)
            }
        } catch {
            state.setError(message(for: error), stage: .review)
        }
    }

    private func updateEmploymentDecision(
        for item: ResumeReviewItem,
        decision: ResumeEmploymentDuplicateDecision,
        distinctRoleConfirmed: Bool
    ) async {
        guard ResumeImportMapper.employmentDuplicateReviewState(for: item).selectedDecision != decision,
              let review = state.liveReviewSession,
              let payload = ResumeImportMapper.employmentDecisionUpdateRequest(
                  for: item,
                  decision: decision,
                  distinctRoleConfirmed: distinctRoleConfirmed
              ) else {
            return
        }

        guard employmentDecisionSubmissionGate.begin(itemID: item.id) else {
            return
        }
        employmentDecisionErrorID = nil
        defer { employmentDecisionSubmissionGate.finish(itemID: item.id) }

        do {
            let updated = try await resumeImportService.updateReviewItem(
                reviewID: review.id,
                itemID: item.id,
                payload: payload
            )
            state.applyReviewSession(updated)
        } catch let error as NetworkError {
            if case .api(let apiError) = error, apiError.code == .conflict {
                if let latest = try? await resumeImportService.refreshReviewSession(reviewID: review.id) {
                    state.applyReviewSession(latest)
                }
            }
            employmentDecisionErrorID = item.id
        } catch {
            employmentDecisionErrorID = item.id
        }
    }

    private func openEditor(for item: ResumeReviewItem) {
        editorValues = Dictionary(
            uniqueKeysWithValues: ResumeImportMapper.editableFields(for: item).map { field in
                let resolvedValue = ([field.key] + field.fallbacks)
                    .compactMap { key in
                        if case .string(let value)? = item.editedPayload[key] {
                            return value
                        }
                        return nil
                    }
                    .first ?? ""
                return (field.key, resolvedValue)
            }
        )
        activeEditorItem = item
    }

    private func saveEdits(for item: ResumeReviewItem) async {
        guard let review = state.liveReviewSession else {
            return
        }

        var editedPayload = ResumeImportMapper.editedPayload(for: item, using: editorValues)
        editedPayload["claim_type"] = .string(item.claimType)

        do {
            let updated = try await resumeImportService.updateReviewItem(
                reviewID: review.id,
                itemID: item.id,
                payload: ResumeImportMapper.editedPayloadUpdateRequest(
                    for: item,
                    editedPayload: editedPayload
                )
            )
            state.applyReviewSession(updated)
            activeEditorItem = nil
        } catch let error as NetworkError {
            if case .api(let apiError) = error, apiError.code == .conflict {
                await recoverConflictedReviewItemUpdate(
                    reviewID: review.id,
                    itemID: item.id,
                    desiredEditedPayload: editedPayload
                )
            } else {
                state.setError(message(for: error), stage: .review)
            }
        } catch {
            state.setError(message(for: error), stage: .review)
        }
    }

    private func recoverConflictedReviewItemUpdate(
        reviewID: String,
        itemID: String,
        desiredSelected: Bool? = nil,
        desiredEditedPayload: [String: JSONValue]? = nil
    ) async {
        do {
            let latest = try await resumeImportService.refreshReviewSession(reviewID: reviewID)
            state.applyReviewSession(latest)

            guard let latestItem = latest.items.first(where: { $0.id == itemID }) else {
                state.setError(
                    "Your resume review changed on the server. KairoID refreshed the latest version so you can continue safely.",
                    stage: .review
                )
                activeEditorItem = nil
                return
            }

            guard let reconciledRequest = ResumeImportMapper.reconciledUpdateRequest(
                for: latestItem,
                desiredSelected: desiredSelected,
                desiredEditedPayload: desiredEditedPayload
            ) else {
                activeEditorItem = nil
                return
            }

            let updated = try await resumeImportService.updateReviewItem(
                reviewID: reviewID,
                itemID: itemID,
                payload: reconciledRequest
            )
            state.applyReviewSession(updated)
            activeEditorItem = nil
        } catch {
            state.setError(
                "Your resume review changed on the server. KairoID refreshed the latest version so you can continue safely.",
                stage: .review
            )
            activeEditorItem = nil
        }
    }

    private func message(for error: Error) -> String {
        if let serviceError = error as? ResumeImportServiceError {
            return serviceError.localizedDescription
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .transport:
                return "KairoID couldn't reach the network. Check your connection and try again."
            case .api(let apiError):
                return apiError.message
            case .invalidResponse:
                return "KairoID received an unexpected resume response. Please try again."
            case .invalidURL:
                return "KairoID's resume configuration is invalid."
            case .unavailableInDemoMode:
                return "Demo Mode keeps resume import local."
            }
        }

        return error.localizedDescription
    }

    private func onboardingCompletionMessage(for error: Error) -> String {
        "Your approved resume claims are already saved. KairoID couldn't finish account setup yet. "
            + "Try again to complete setup without importing the resume a second time. "
            + message(for: error)
    }

    private func importFailureMessage(for batch: ResumeImportBatch) -> String {
        if batch.isPartiallyCompleted {
            return "KairoID imported some approved claims, but some items still need your attention."
        }

        if batch.failedCount > 0 || batch.blockedCount > 0 {
            return "Some resume claims still need attention before KairoID can finish the import. Review the latest items and try again."
        }

        if batch.incompleteCount > 0 {
            return "Some imported claims are incomplete. Review the latest items before continuing."
        }

        return "KairoID couldn't finish that import. Review the latest claims and try again."
    }

    private func userFacingBlocker(_ code: String) -> String {
        switch code {
        case "unsupported_import_target":
            return "This item isn't currently supported for import. Exclude it to continue."
        default:
            return code.replacingOccurrences(of: "_", with: " ").capitalized + "."
        }
    }
}

private struct ResumeImportPreviewSectionCard: View {
    let section: ResumeImportReviewPreview.Section

    var body: some View {
        KairoCard {
            Text(section.title)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)

            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                ForEach(section.entries, id: \.self) { entry in
                    Text(entry)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct ResumeImportLiveReviewSectionCard: View {
    let section: ResumeReviewSection
    let onToggleSelection: (ResumeReviewItem) -> Void
    let onEdit: (ResumeReviewItem) -> Void
    let onKeepExisting: (ResumeReviewItem) -> Void
    let onRequestAddAsNew: (ResumeReviewItem) -> Void
    let employmentDecisionInFlightID: String?
    let employmentDecisionErrorID: String?

    var body: some View {
        KairoCard {
            HStack {
                Text(section.title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)

                Spacer()

                Text("\(section.items.count)")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                ForEach(section.items) { item in
                    switch ResumeImportMapper.employmentDuplicateReviewState(for: item) {
                    case .alreadyInCareer, .possibleMatch:
                        ResumeEmploymentDuplicateReviewCard(
                            item: item,
                            state: ResumeImportMapper.employmentDuplicateReviewState(for: item),
                            isUpdating: employmentDecisionInFlightID == item.id,
                            showsError: employmentDecisionErrorID == item.id,
                            onKeepExisting: { onKeepExisting(item) },
                            onRequestAddAsNew: { onRequestAddAsNew(item) }
                        )
                    case .noConflict:
                        ResumeImportReviewItemCard(
                            item: item,
                            onToggleSelection: { onToggleSelection(item) },
                            onEdit: { onEdit(item) }
                        )
                    }
                }
            }
        }
    }
}

private struct ResumeEmploymentDuplicateReviewCard: View {
    let item: ResumeReviewItem
    let state: ResumeEmploymentDuplicateReviewState
    let isUpdating: Bool
    let showsError: Bool
    let onKeepExisting: () -> Void
    let onRequestAddAsNew: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            switch state {
            case .noConflict:
                EmptyView()
            case .alreadyInCareer(let existing):
                duplicateHeader(
                    status: "Already in Career",
                    title: ResumeImportMapper.displayTitle(for: item),
                    detail: "Your existing Employment record will be kept unchanged. No second record will be added."
                )
                if let existing {
                    comparisonSummary(label: "Existing Career record", summary: existing)
                }
            case .possibleMatch(let existing, let imported, let decision):
                duplicateHeader(
                    status: "Possible match",
                    title: ResumeImportMapper.displayTitle(for: item),
                    detail: "This may already be in Career. Keep the existing record, or add this only if it is a separate role. Existing facts and evidence will not be changed."
                )

                if let existing {
                    comparisonSummary(label: "Existing Career record", summary: existing)
                } else {
                    unavailableComparisonSummary(label: "Existing Career record")
                }
                comparisonSummary(label: "Resume record", summary: imported)

                Label(
                    "Selected: \(decision.title)",
                    systemImage: decision == .keepExisting ? "checkmark.shield.fill" : "checkmark.circle.fill"
                )
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityIdentifier(KairoAccessibilityID.resumeImportEmploymentSelectedDecision)

                VStack(spacing: KairoSpacing.small) {
                    KairoSecondaryButton(
                        title: "Keep existing",
                        isLoading: isUpdating && decision != .keepExisting,
                        accessibilityIdentifier: KairoAccessibilityID.resumeImportEmploymentKeepExisting,
                        action: onKeepExisting
                    )
                    .disabled(isUpdating || decision == .keepExisting)

                    KairoSecondaryButton(
                        title: "Add as new role",
                        isLoading: isUpdating && decision != .addAsNewRole,
                        accessibilityIdentifier: KairoAccessibilityID.resumeImportEmploymentAddAsNew,
                        action: onRequestAddAsNew
                    )
                    .disabled(isUpdating || decision == .addAsNewRole)
                }

                if showsError {
                    Text("Could not save your choice. Your previous decision is still active. Please try again.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(KairoAccessibilityID.resumeImportEmploymentDecisionError)
                }
            }
        }
        .padding(KairoSpacing.medium)
        .background(KairoColors.surfaceMuted.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("\(KairoAccessibilityID.resumeImportEmploymentDuplicateCard).\(item.id)")
    }

    private func duplicateHeader(status: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(status)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.brandPrimary)
            Text(title)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private func comparisonSummary(label: String, summary: ResumeEmploymentSummary) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(label)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
            summaryLine("Employer", summary.employer)
            summaryLine("Role", summary.role)
            summaryLine("Dates", summary.dates)
            summaryLine("Location", summary.location)
        }
        .padding(KairoSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KairoColors.surface, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(summary.accessibilitySummary.isEmpty ? "details unavailable" : summary.accessibilitySummary)")
    }

    private func unavailableComparisonSummary(label: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(label)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
            Text("Details unavailable")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
        }
        .padding(KairoSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KairoColors.surface, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func summaryLine(_ label: String, _ value: String?) -> some View {
        if let value, !value.isEmpty {
            Text("\(label): \(value)")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ResumeImportReviewItemCard: View {
    let item: ResumeReviewItem
    let onToggleSelection: () -> Void
    let onEdit: () -> Void

    private var detailLines: [String] {
        ResumeImportMapper.detailLines(for: item)
    }

    private var canEdit: Bool {
        !ResumeImportMapper.editableFields(for: item).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                Button(action: onToggleSelection) {
                    Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(item.selected ? KairoColors.brandPrimary : KairoColors.border)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                    HStack(spacing: KairoSpacing.xSmall) {
                        Text(item.claimType.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)

                        Text(item.duplicateStatus.title)
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)
                    }

                    Text(ResumeImportMapper.displayTitle(for: item))
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let subtitle = ResumeImportMapper.displaySubtitle(for: item), !subtitle.isEmpty {
                        Text(subtitle)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(detailLines, id: \.self) { line in
                        Text(line)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(item.importAction.title)
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                }

                Spacer(minLength: 0)
            }

            if canEdit {
                Button("Edit") {
                    onEdit()
                }
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.brandPrimary)
            }
        }
        .padding(KairoSpacing.medium)
        .background(KairoColors.surfaceMuted.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
    }
}

private struct ResumeDistinctRoleConfirmationSheet: View {
    let item: ResumeReviewItem
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                Image(systemName: "person.crop.rectangle.stack")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(KairoColors.brandPrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    Text("Add as new role?")
                        .font(KairoTypography.title)
                        .foregroundStyle(KairoColors.textPrimary)
                    Text("This will create a separate Employment record. Confirm only if the resume entry represents a distinct role or employment period.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ResumeImportMapper.displayTitle(for: item))
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(KairoAccessibilityID.resumeImportEmploymentConfirmation)

                Spacer(minLength: 0)

                VStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Create separate Employment record",
                        accessibilityIdentifier: KairoAccessibilityID.resumeImportEmploymentConfirmDistinct,
                        action: onConfirm
                    )
                    KairoSecondaryButton(title: "Cancel", action: onCancel)
                }
            }
            .padding(KairoSpacing.large)
            .background(KairoColors.background)
            .navigationTitle("Confirm separate role")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct ResumeReviewEditorSheet: View {
    let item: ResumeReviewItem
    @Binding var values: [String: String]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    Text("Edit only the fields KairoID currently supports for resume review. Everything else stays exactly as parsed.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(ResumeImportMapper.editableFields(for: item)) { field in
                        KairoTextField(
                            title: field.label,
                            prompt: field.label,
                            text: Binding(
                                get: { values[field.key, default: ""] },
                                set: { values[field.key] = $0 }
                            ),
                            keyboardType: field.keyboard,
                            textInputAutocapitalization: field.keyboard == .emailAddress ? .never : .words
                        )
                    }
                }
                .padding(KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Edit claim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }
}

private struct ResumeImportHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .fill(KairoColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                HStack(spacing: KairoSpacing.small) {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .fill(KairoColors.brandPrimary.opacity(0.16))
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "doc.text.viewfinder")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(KairoColors.brandPrimary)
                        )

                    Capsule()
                        .fill(KairoColors.textPrimary.opacity(0.08))
                        .frame(width: 64, height: 10)
                }

                RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    .fill(KairoColors.surfaceMuted)
                    .frame(height: 42)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(KairoColors.textPrimary.opacity(0.12))
                            .frame(width: 120, height: 10)
                            .padding(.horizontal, KairoSpacing.medium)
                    }

                RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    .fill(KairoColors.surfaceMuted.opacity(0.82))
                    .frame(height: 42)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(KairoColors.textPrimary.opacity(0.1))
                            .frame(width: 154, height: 10)
                            .padding(.horizontal, KairoSpacing.medium)
                    }

                RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    .fill(KairoColors.surfaceMuted.opacity(0.72))
                    .frame(height: 42)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(KairoColors.textPrimary.opacity(0.08))
                            .frame(width: 138, height: 10)
                            .padding(.horizontal, KairoSpacing.medium)
                    }

                HStack {
                    Capsule()
                        .fill(KairoColors.brandPrimary.opacity(0.14))
                        .frame(width: 94, height: 32)
                        .overlay(
                            Text("Review")
                                .font(KairoTypography.caption)
                                .foregroundStyle(KairoColors.brandPrimary)
                        )

                    Spacer(minLength: 0)
                }
            }
            .padding(KairoSpacing.large)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.04, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
