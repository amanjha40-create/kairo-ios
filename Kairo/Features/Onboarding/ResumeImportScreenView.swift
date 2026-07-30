import SwiftUI
import UniformTypeIdentifiers

struct ResumeImportScreenView: View {
    let createAccountDraft: CreateAccountDraft
    @Binding var state: ResumeImportState
    let onBuildProfileManually: () -> Void

    @EnvironmentObject private var router: AppRouter
    @State private var isFileImporterPresented = false

    private var reviewPreview: ResumeImportReviewPreview {
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
                case .processingPreparing, .processingOrganising:
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
        .task(id: processingTaskKey) {
            guard state.autoAdvanceProcessing, state.phase.isProcessing else {
                return
            }

            try? await Task.sleep(for: .milliseconds(850))
            state.advanceProcessing()
        }
    }

    private var processingTaskKey: String {
        "\(state.phase.rawValue)-\(state.processingAttemptCount)-\(state.autoAdvanceProcessing)"
    }

    private var introductoryCard: some View {
        KairoCard {
            Text("Nothing is added to your Trust Passport until you confirm it.")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text("Choose a PDF, DOC, or DOCX file to generate a local, review-first draft of your professional history. Kairo keeps only the file name, type, and size in this demo session.")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var selectedFileCard: some View {
        KairoCard {
            fileSummaryHeader(title: "Resume selected")

            fileSummaryDetails

            Text("This local demo keeps only minimal file metadata in memory for the current session.")
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
                    state.clearSelection()
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

            Text("Local preview only. No upload or parsing service is being called in this milestone.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var failureCard: some View {
        KairoErrorStateView(
            title: "We couldn't prepare that local preview",
            message: state.errorMessage ?? "Choose another resume to continue.",
            messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportFailureMessage
        )
    }

    private var unsupportedFileCard: some View {
        KairoErrorStateView(
            title: "That file isn't supported",
            message: state.errorMessage ?? "Choose a PDF, DOC, or DOCX resume to continue.",
            messageAccessibilityIdentifier: KairoAccessibilityID.resumeImportUnsupportedMessage
        )
    }

    private var reviewContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            KairoCard {
                fileSummaryHeader(title: state.readyTitle)

                Text(state.readyMessage)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                fileSummaryDetails
            }

            Text(reviewPreview.summary)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(reviewPreview.sections) { section in
                ResumeImportReviewSectionCard(section: section)
            }
        }
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
                primaryAction: { state.beginProcessing() },
                secondaryTitle: "Build profile manually",
                secondaryAccessibilityIdentifier: KairoAccessibilityID.resumeImportManualButton,
                secondaryAction: onBuildProfileManually
            )
        case .processingPreparing, .processingOrganising:
            KairoPrimaryButton(
                title: state.currentProcessingTitle ?? "Preparing your resume",
                isLoading: true,
                accessibilityIdentifier: KairoAccessibilityID.resumeImportProcessingButton,
                action: {}
            )
            .disabled(true)
        case .failed:
            VStack(spacing: KairoSpacing.small) {
                KairoPrimaryButton(
                    title: "Retry Import",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportRetryButton,
                    action: { state.retryProcessing() }
                )

                KairoSecondaryButton(
                    title: "Choose Another Resume",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportChooseAnotherButton,
                    action: { state.chooseAnotherResume() }
                )
            }
            .accessibilityElement(children: .contain)
        case .readyForReview, .confirmed:
            VStack(spacing: KairoSpacing.small) {
                KairoPrimaryButton(
                    title: "Looks Good",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportLooksGoodButton,
                    action: handleLooksGood
                )

                KairoSecondaryButton(
                    title: "Choose Another Resume",
                    accessibilityIdentifier: KairoAccessibilityID.resumeImportChooseAnotherButton,
                    action: { state.chooseAnotherResume() }
                )
            }
            .accessibilityElement(children: .contain)
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

            Text(value)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .modifier(ValueAccessibilityIdentifier(identifier: valueAccessibilityIdentifier))
        }
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

            state.selectFile(from: url)
        case .failure(let error):
            let nsError = error as NSError
            guard nsError.domain != NSCocoaErrorDomain || nsError.code != NSUserCancelledError else {
                return
            }

            state = ResumeImportState(
                phase: .failed,
                selectedFile: state.selectedFile,
                errorMessage: "Kairo couldn't open that file. Choose another resume to continue.",
                processingPolicy: state.processingPolicy,
                processingAttemptCount: state.processingAttemptCount,
                autoAdvanceProcessing: state.autoAdvanceProcessing
            )
        }
    }

    private func handleLooksGood() {
        state.confirmReview()
        router.advanceOnboarding(from: .resumeImportOrQuickProfile)
    }
}

private struct ValueAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

private struct ResumeImportReviewSectionCard: View {
    let section: ResumeImportReviewPreview.Section

    var body: some View {
        KairoCard {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)

                Spacer()

                Button("Edit") {}
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .disabled(true)
                    .accessibilityLabel("Edit \(section.title) coming soon")
            }

            ForEach(section.entries, id: \.self) { entry in
                Text(entry)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
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

            ZStack {
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .fill(KairoColors.surfaceMuted)
                    .frame(width: 74, height: 90)
                    .rotationEffect(.degrees(-8))
                    .offset(x: -24, y: 6)

                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .fill(KairoColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                            .stroke(KairoColors.border, lineWidth: 1)
                    )
                    .frame(width: 84, height: 102)
                    .kairoShadow(KairoShadow.card)
                    .overlay(documentFace)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.05, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var documentFace: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            HStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(KairoColors.brandPrimary.opacity(0.14))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(KairoColors.brandPrimary)
                    )

                Spacer()
            }

            Capsule()
                .fill(KairoColors.textPrimary.opacity(0.14))
                .frame(width: 42, height: 8)

            Capsule()
                .fill(KairoColors.textPrimary.opacity(0.08))
                .frame(width: 52, height: 8)

            Capsule()
                .fill(KairoColors.textPrimary.opacity(0.08))
                .frame(width: 34, height: 8)

            Spacer(minLength: 0)

            Capsule()
                .fill(KairoColors.accent.opacity(0.16))
                .frame(width: 40, height: 18)
                .overlay(
                    Text("Review")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(KairoColors.accent)
                )
        }
        .padding(KairoSpacing.medium)
    }
}
