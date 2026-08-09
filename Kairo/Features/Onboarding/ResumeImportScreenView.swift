import SwiftUI
import UniformTypeIdentifiers

struct ResumeImportScreenView: View {
    let createAccountDraft: CreateAccountDraft
    @Binding var state: ResumeImportState
    let onBuildProfileManually: () -> Void
    let onContinueRemainingProfileCompletion: () async throws -> Void

    @EnvironmentObject private var router: AppRouter
    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.resumeImportService) private var resumeImportService

    @State private var isFileImporterPresented = false
    @State private var activeEditorItem: ResumeReviewItem?
    @State private var editorValues: [String: String] = [:]

    private var isPreviewMode: Bool {
        appConfiguration.isDemoModeEnabled || UITestLaunchConfiguration.current().isEnabled
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
            layoutMode: .task,
            eyebrow: "Verify once. Trusted everywhere.",
            title: "Import your resume",
            subtitle: "Bring in your professional history and let Kairo organise it for your review.",
            titleAccessibilityIdentifier: KairoAccessibilityID.resumeImportPlaceholderTitle
        ) {
            ResumeImportHero()
                .frame(maxWidth: 144)
        } content: {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                switch state.phase {
                case .initial:
                    introductoryCard
                case .selected:
                    selectedFileCard
                case .uploading, .processingPreparing, .processingOrganising, .importing:
                    processingCard
                case .failed:
                    failureCard
                case .readyForReview, .confirmed:
                    reviewContent
                case .unsupportedFile:
                    unsupportedFileCard
                }
            }
        } actions: {
            actionContent
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
        .onAppear {
            guard !isPreviewMode else {
                return
            }

            state.prepareForEntryIntoLiveResumeImport()
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
        KairoCard {
            Text("Nothing is added to your Trust Passport until you confirm it.")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text(
                isPreviewMode
                    ? "Choose a PDF or DOCX file to generate a deterministic demo review. Demo Mode never uploads your resume or calls resume-processing services."
                    : "Choose a PDF or DOCX file up to 10 MB. Kairo will upload it securely, process it on the backend, and bring the parsed claims back for your approval before import."
            )
            .font(KairoTypography.body)
            .foregroundStyle(KairoColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedFileCard: some View {
        KairoCard {
            fileSummaryHeader(title: "Resume selected")

            fileSummaryDetails

            Text(
                isPreviewMode
                    ? "Demo Mode keeps only minimal file metadata in the current seeded session."
                    : "Kairo will request a secure upload intent, upload your file without exposing your bearer token to storage, and confirm the checksum before parsing begins."
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
        if state.liveReviewSession != nil || state.liveImportBatch != nil {
            return "We couldn't finish that import"
        }

        if state.liveResume != nil {
            return "We couldn't finish processing that resume"
        }

        return "We couldn't prepare that resume"
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
        if let liveReviewSession = state.liveReviewSession, !isPreviewMode {
            liveReviewContent(liveReviewSession)
        } else {
            demoReviewContent
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
                    Text("These are candidate-provided claims. Imported records remain unverified until Kairo verifies them separately.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(state.reviewSections) { section in
                ResumeImportLiveReviewSectionCard(
                    section: section,
                    onToggleSelection: { item in
                        Task { await toggleSelection(for: item) }
                    },
                    onEdit: { item in
                        openEditor(for: item)
                    }
                )
            }
        }
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
                secondaryTitle: "Build profile manually",
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
                secondaryTitle: "Build profile manually",
                secondaryAccessibilityIdentifier: KairoAccessibilityID.resumeImportManualButton,
                secondaryAction: onBuildProfileManually
            )
        case .uploading, .processingPreparing, .processingOrganising:
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

                KairoSecondaryButton(
                    title: "Choose Another Resume",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportChooseAnotherButton,
                    action: clearSelectedResume
                )
            }
            .accessibilityElement(children: .contain)
        case .readyForReview, .confirmed:
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
        }
    }

    private var retryButtonTitle: String {
        if state.liveReviewSession != nil || state.liveImportBatch != nil {
            return "Retry Import"
        }

        if state.liveResume != nil {
            return "Retry Processing"
        }

        return "Retry Import"
    }

    private var retryAction: () -> Void {
        if isPreviewMode {
            return { state.retryProcessing() }
        }

        if state.liveReviewSession != nil || state.liveImportBatch != nil {
            return { Task { await handleLiveLooksGood() } }
        }

        if state.liveResume != nil {
            return { Task { await retryLiveProcessing() } }
        }

        return { isFileImporterPresented = true }
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
        guard !isPreviewMode, !state.restorationAttempted else {
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
                await reconcileImportRecovery(reviewID: reviewID)
                return
            }

            state.applyRestoredWorkflow(snapshot)
        } catch {
            state.setError(message(for: error))
        }
    }

    private func pollLiveWorkflowIfNeeded() async {
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
                    if process.status == .needsReview {
                        let review = try await resumeImportService.loadOrCreateReviewSession(resumeID: resumeID)
                        state.applyReviewSession(review)
                    }
                    return
                }
            } catch {
                state.setError(message(for: error))
                return
            }

            try? await Task.sleep(for: .milliseconds(2500))
        }

        state.setError(
            "Resume processing is taking longer than expected. You can leave this screen and return later."
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
                state.setError(message(for: error))
                return
            }

            try? await Task.sleep(for: .milliseconds(2500))
        }

        state.setError(
            "Import is taking longer than expected. Kairo will resume from backend state when you return."
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
                state.setError(message(for: error))
            }
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.domain != NSCocoaErrorDomain || nsError.code != NSUserCancelledError else {
                return
            }

            state.setError("Kairo couldn't open that file. Choose another resume to continue.")
        }
    }

    private func clearSelectedResume() {
        if let temporaryFileURL = state.selectedTemporaryFileURL, !isPreviewMode {
            resumeImportService.cleanupSelection(at: temporaryFileURL)
        }
        state.clearSelection()
    }

    private func beginLiveUpload() async {
        guard let selectedFile = state.selectedFile,
              let selectedTemporaryFileURL = state.selectedTemporaryFileURL
        else {
            return
        }

        state.phase = .uploading
        state.errorMessage = nil
        state.statusTitleOverride = "Uploading your resume"
        state.statusMessageOverride = "Kairo is securely uploading your file before backend processing starts."

        do {
            let selection = ResumeImportPreparedSelection(
                file: selectedFile,
                temporaryFileURL: selectedTemporaryFileURL
            )
            let resume = try await resumeImportService.upload(selection: selection)
            resumeImportService.cleanupSelection(at: selectedTemporaryFileURL)
            state.selectedTemporaryFileURL = nil
            state.applyUploadStarted(resume: resume)

            let process = try await resumeImportService.startProcessing(resumeID: resume.id)
            state.applyProcessingJob(process)
        } catch {
            state.setError(message(for: error))
        }
    }

    private func retryLiveProcessing() async {
        guard let resumeID = state.liveResume?.id else {
            return
        }

        do {
            let process = try await resumeImportService.startProcessing(resumeID: resumeID)
            state.applyProcessingJob(process)
        } catch {
            state.setError(message(for: error))
        }
    }

    private func handlePreviewLooksGood() {
        state.confirmReview()
        router.advanceOnboarding(from: .resumeImportOrQuickProfile)
    }

    private func handleLiveLooksGood() async {
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
                        ? "Kairo needs updated review decisions before import can continue."
                        : plan.blockers.map(userFacingBlocker).joined(separator: " ")
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
                state.setError(message(for: error))
            }
        } catch {
            state.setError(message(for: error))
        }
    }

    private func handleTerminalImportBatch(_ batch: ResumeImportBatch) async {
        if batch.isCompletedWithoutHardFailures {
            do {
                try await finishSuccessfulImport()
            } catch {
                state.setError(message(for: error))
            }
            return
        }

        guard batch.isPartiallyCompleted else {
            state.setError(importFailureMessage(for: batch))
            return
        }

        if batch.isPartiallyCompleted,
           let reviewID = state.liveReviewSession?.id,
           let latest = try? await resumeImportService.refreshReviewSession(reviewID: reviewID) {
            state.applyReviewSession(latest)
        }
        state.setError(importFailureMessage(for: batch))
    }

    private func finishSuccessfulImport(
        using completionResult: ResumeImportCompletionResult? = nil
    ) async throws {
        let resolvedCompletionResult: ResumeImportCompletionResult
        if let completionResult {
            resolvedCompletionResult = completionResult
        } else {
            resolvedCompletionResult = try await resumeImportService.completeOnboardingIfNeeded()
        }

        if resolvedCompletionResult.isOnboardingComplete {
            router.advanceOnboarding(from: .resumeImportOrQuickProfile)
            return
        }

        try await onContinueRemainingProfileCompletion()
    }

    private func reconcileImportRecovery(reviewID: String) async {
        do {
            let recovery = try await resumeImportService.reconcileImportRecovery(reviewID: reviewID)

            switch recovery.disposition {
            case .importCompleted:
                guard let completionResult = recovery.completionResult else {
                    state.setError(
                        "Kairo refreshed the latest import state, but couldn't finish onboarding reconciliation yet."
                    )
                    activeEditorItem = nil
                    return
                }

                try await finishSuccessfulImport(using: completionResult)
            case .importPartiallyCompleted:
                state.applyReviewSession(recovery.reviewSession)
                if let importBatch = recovery.importBatch {
                    state.applyImportBatch(importBatch)
                }
                if let importBatch = recovery.importBatch {
                    state.setError(importFailureMessage(for: importBatch))
                } else {
                    state.setError(
                        "Some imported claims still need your attention before onboarding can finish."
                    )
                }
            case .importInProgress:
                state.applyReviewSession(recovery.reviewSession)
                guard let importBatch = recovery.importBatch else {
                    state.setError(
                        "Kairo is reconciling your import progress on the server. Please wait a moment and try again."
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
                    "Your resume review changed on the server. Kairo refreshed the latest version so you can continue safely."
                )
            }

            activeEditorItem = nil
        } catch {
            state.setError(message(for: error))
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
                state.setError(message(for: error))
            }
        } catch {
            state.setError(message(for: error))
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
                state.setError(message(for: error))
            }
        } catch {
            state.setError(message(for: error))
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
                    "Your resume review changed on the server. Kairo refreshed the latest version so you can continue safely."
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
                "Your resume review changed on the server. Kairo refreshed the latest version so you can continue safely."
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
                return "Kairo couldn't reach the network. Check your connection and try again."
            case .api(let apiError):
                return apiError.message
            case .invalidResponse:
                return "Kairo received an unexpected resume response. Please try again."
            case .invalidURL:
                return "Kairo's resume configuration is invalid."
            case .unavailableInDemoMode:
                return "Demo Mode keeps resume import local."
            }
        }

        return error.localizedDescription
    }

    private func importFailureMessage(for batch: ResumeImportBatch) -> String {
        if batch.isPartiallyCompleted {
            return "Kairo imported some approved claims, but some items still need your attention before onboarding can finish."
        }

        if batch.failedCount > 0 || batch.blockedCount > 0 {
            return "Some resume claims still need attention before Kairo can finish the import. Review the latest items and try again."
        }

        if batch.incompleteCount > 0 {
            return "Some imported claims are incomplete. Review the latest items before continuing."
        }

        return "Kairo couldn't finish that import. Review the latest claims and try again."
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

private struct ResumeReviewEditorSheet: View {
    let item: ResumeReviewItem
    @Binding var values: [String: String]
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    Text("Edit only the fields Kairo currently supports for resume review. Everything else stays exactly as parsed.")
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
