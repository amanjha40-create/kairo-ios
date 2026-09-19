import SwiftUI

private enum ResumeManagementDestination: Hashable {
    case upload
    case existing(String)
}

/// Authenticated owner surface. The enclosing More stack owns navigation and session lifetime.
struct ResumeManagementScreenView: View {
    @Environment(\.resumeImportService) private var service
    @Environment(\.scenePhase) private var scenePhase
    @State private var entries: [ResumeImportWorkflowSnapshot] = []
    @State private var nextOffset = 0
    @State private var hasMore = false
    @State private var loading = false
    @State private var loaded = false
    @State private var errorMessage: String?
    @StateObject private var deletion = ResumeDeletionState()
    @State private var isDeleteConfirmationPresented = false

    @State private var destination: ResumeManagementDestination?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                Text("Import, review and manage your resume")
                    .font(KairoTypography.title).fixedSize(horizontal: false, vertical: true)
                Text("Imported claims remain candidate-provided, not verified. Importing a resume does not request verification or contact anyone.")
                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                KairoPrimaryButton(title: "Import resume", accessibilityIdentifier: "resume.management.upload") {
                    destination = .upload
                }
                .disabled(deletion.isDeleting || deletion.needsReconciliation)
                if loading && !loaded { ProgressView("Loading resumes").accessibilityIdentifier("resume.management.loading") }
                if deletion.isDeleting { ProgressView("Updating resume history").accessibilityIdentifier("resume.delete.progress") }
                if let message = deletion.message {
                    Text(message).font(KairoTypography.footnote).accessibilityIdentifier("resume.delete.message")
                }
                if deletion.needsReconciliation {
                    Button("Check deletion status") {
                        Task { if let page = await deletion.reconcile(using: service) { apply(page) } }
                    }.frame(minHeight: 44).disabled(deletion.isDeleting)
                        .accessibilityIdentifier("resume.delete.reconcile")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(KairoColors.textSecondary)
                    Button("Retry loading resumes") { Task { await load(reset: true) } }
                        .frame(minHeight: 44).disabled(loading)
                }
                if loaded && entries.isEmpty && errorMessage == nil {
                    KairoSection {
                        Text("No resumes yet").font(KairoTypography.bodyStrong)
                        Text("Choose a PDF or DOCX to review before adding claims to your Career.")
                    }.accessibilityIdentifier("resume.management.empty")
                }
                ForEach(Array(entries.enumerated()), id: \.element.resume.id) { index, entry in
                    VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    Button { destination = .existing(entry.resume.id) } label: {
                        KairoSection {
                            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                                Text(index == 0 ? "Latest import" : "Previous import")
                                    .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                                Text(entry.resume.originalFilename).font(KairoTypography.bodyStrong)
                                Text(entry.historyStatus).font(KairoTypography.footnote)
                                Text(entry.resume.createdAt, style: .date).font(KairoTypography.caption)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("resume.management.entry.\(index)")
                    .accessibilityHint("Open this resume's status and available review actions")
                    Button(role: .destructive) {
                        deletion.requestConfirmation(ResumeDeletionTarget(id: entry.resume.id, filename: entry.resume.originalFilename))
                        isDeleteConfirmationPresented = deletion.confirmation != nil
                    } label: {
                        Label("Delete resume", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("resume.management.delete.\(index)")
                    .accessibilityHint("Asks for confirmation. Imported Career records are kept.")
                    }
                    .disabled(loading || deletion.isDeleting || deletion.needsReconciliation)
                }
                if hasMore {
                    Button("Load more resumes") { Task { await load(reset: false) } }
                        .frame(minHeight: 44).disabled(loading)
                }
            }.padding(KairoSpacing.medium)
        }
        .background(KairoColors.background)
        .navigationTitle("Resume")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("resume.management.screen")
        .alert("Delete resume?", isPresented: $isDeleteConfirmationPresented, presenting: deletion.confirmation) { _ in
            Button("Cancel", role: .cancel) { deletion.cancel() }
            Button("Delete resume", role: .destructive) {
                guard let target = deletion.beginDeletion() else { return }
                Task { if let page = await deletion.performDeletion(target, using: service) { apply(page) } }
            }
        } message: { target in
            Text("\(target.filename)\n\nThis removes the uploaded resume from KairoID. Imported Career records will not be deleted.")
        }
        .navigationDestination(item: $destination) { target in
            ResumeManagementWorkflowView(resumeID: {
                if case .existing(let id) = target { return id }; return nil
            }(), onFinished: { destination = nil })
        }
        .task { await load(reset: true) }
        .refreshable { await load(reset: true) }
        .onChange(of: destination) { _, value in
            if value == nil { Task { await load(reset: true) } }
        }
        .onChange(of: scenePhase) { _, value in
            if value == .active && destination == nil { Task { await load(reset: true) } }
        }
    }

    private func load(reset: Bool) async {
        guard !loading, !deletion.isDeleting else { return }
        loading = true
        defer { loading = false }
        do {
            let page = try await service.resumeHistory(offset: reset ? 0 : nextOffset, limit: 20)
            guard !Task.isCancelled else { return }
            if reset { entries = page.entries }
            else {
                let existingIDs = Set(entries.map(\.resume.id))
                entries += page.entries.filter { !existingIDs.contains($0.resume.id) }
            }
            nextOffset = page.nextOffset
            hasMore = page.hasMore
            loaded = true
            errorMessage = nil
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Couldn't load your resumes. Please try again."
        }
    }

    private func apply(_ page: ResumeHistoryPage) {
        entries = page.entries
        nextOffset = page.nextOffset
        hasMore = page.hasMore
        loaded = true
        errorMessage = nil
    }
}

private struct ResumeManagementWorkflowView: View {
    let resumeID: String?
    let onFinished: () -> Void
    @Environment(\.resumeImportService) private var service
    @State private var state = ResumeImportState(restorationAttempted: true)
    @State private var snapshot: ResumeImportWorkflowSnapshot?
    @State private var reviewRequested = false
    @State private var loaded = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let errorMessage {
                VStack(spacing: KairoSpacing.medium) {
                    Text(errorMessage)
                    Button("Retry loading resume") { Task { await load() } }.frame(minHeight: 44)
                }.padding()
            } else if !loaded {
                ProgressView("Loading resume")
            } else if let snapshot, snapshot.resume.processingStatus == .needsReview,
                      snapshot.reviewSession == nil, !reviewRequested {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    Text(snapshot.resume.originalFilename).font(KairoTypography.title)
                    Text("Ready for review").font(KairoTypography.bodyStrong)
                    Text("Open your review to check candidate-provided claims before importing anything.")
                    KairoPrimaryButton(title: "Continue review", accessibilityIdentifier: "resume.management.continueReview") {
                        reviewRequested = true
                    }
                }.fixedSize(horizontal: false, vertical: true).padding()
            } else if let snapshot, snapshot.isReadOnlyHistory {
                ScrollView {
                    VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                        Text(snapshot.resume.originalFilename).font(KairoTypography.title)
                        Text(snapshot.historyStatus).font(KairoTypography.bodyStrong)
                        Text(snapshot.isImported
                             ? "Approved claims were imported. They remain candidate-provided, not verified. View your Career for those records."
                             : "No review action is available for this resume. Return to Resume to choose a new file or refresh its status.")
                        if let batch = snapshot.importBatch {
                            Text("Imported: \(batch.importedCount) · Linked: \(batch.linkedCount) · Skipped: \(batch.skippedCount)")
                        }
                    }.fixedSize(horizontal: false, vertical: true).padding()
                }.accessibilityIdentifier("resume.management.historyDetail")
            } else {
                ResumeImportScreenView(createAccountDraft: CreateAccountDraft(), state: $state,
                    onBuildProfileManually: {}, context: .authenticated, onAuthenticatedCompletion: onFinished)
            }
        }
        .navigationTitle(resumeID == nil ? "Import resume" : "Resume details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task { await load() }
    }

    private func load() async {
        guard !loaded else { return }
        errorMessage = nil
        do {
            if let resumeID {
                let result = try await service.restoreWorkflow(resumeID: resumeID)
                guard !Task.isCancelled else { return }
                snapshot = result
                state.applyRestoredWorkflow(result)
            }
            loaded = true
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "Couldn't load this resume. Please try again."
        }
    }
}
