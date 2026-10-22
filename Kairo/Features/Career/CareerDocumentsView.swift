import SwiftUI
import UniformTypeIdentifiers

struct CareerDocumentsView: View {
    let presentation: CareerDocumentPresentation
    /// Supplied only by the isolated local QA host, never by normal app routes.
    var syntheticSelection: URL? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var preview: SecureDocumentPreview?
    @Environment(\.careerDocumentService) private var service
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var documents: [CareerDocument] = []
    @State private var documentTypes: [CareerDocumentType] = []
    @State private var selectedType = ""
    @State private var selectedEvidenceRole: EmploymentEvidenceRole = .primary
    @State private var eligibility: EmploymentEvidenceEligibility?
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var isFileImporterPresented = false
    @State private var pendingReplacement: CareerDocument?
    @State private var pendingDelete: CareerDocument?
    @State private var errorMessage: String?
    @State private var selectedFile: URL?
    @State private var uploadFailed = false
    @State private var uploadConfirmed = false
    @State private var uploadStage: DocumentUploadStage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoSection {
                        Text(presentation.parent.title)
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)
                        Text("Documents stay private unless you explicitly use them as verification evidence or include them in a Passport share.")
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if case .employment = presentation.parent {
                        KairoSection {
                            Text(eligibility?.progress ?? "Evidence readiness unavailable")
                                .font(KairoTypography.bodyStrong).accessibilityIdentifier("career.documents.primaryProgress")
                            Text("Add at least two distinct, completed primary employment documents. Supporting and unclassified legacy files do not count.")
                                .font(KairoTypography.body).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if isLoading {
                        KairoLoadingStateView(title: "Loading documents", message: "KairoID is fetching private document metadata.")
                    } else if documents.isEmpty {
                        KairoEmptyStateView(
                            title: "No documents attached",
                            message: emptyMessage,
                            systemImage: "doc"
                        )
                    } else {
                        documentList
                    }

                    if presentation.parent.canAddDocument(existing: documents) {
                        uploadControls
                    } else if presentation.parent.hasSingleAttachment && !documents.isEmpty {
                        Text("Already added. Use Replace to change this attachment, or Remove before adding another.")
                            .font(KairoTypography.body).accessibilityIdentifier("evidence.alreadyAdded")
                    } else if case .employment = presentation.parent {
                        Text("Documents cannot be added while this employment record uses employer confirmation or is in a locked workflow state.")
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let selectedFile {
                        EvidenceUploadReview(type: typeTitle(selectedType), filename: selectedFile.lastPathComponent,
                            isUploading: isMutating, retry: uploadFailed, stage: uploadStage,
                            upload: uploadSelection, cancel: clearSelection)
                    }
                    if uploadConfirmed {
                        Text("Document added. The document list was refreshed from KairoID.")
                            .accessibilityIdentifier("evidence.added")
                    }

                    if let errorMessage {
                        KairoErrorStateView(title: "Document action failed", message: errorMessage)
                            .accessibilityIdentifier(KairoAccessibilityID.careerDocumentError)
                    }
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle(presentation.parent.categoryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.disabled(isMutating)
                }
            }
            .task { await load() }
            .refreshable { if !isMutating { await load() } }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf, .jpeg, .png],
                allowsMultipleSelection: false,
                onCompletion: handleFileSelection
            )
            .confirmationDialog(
                "Delete this document?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete document", role: .destructive) { deletePendingDocument() }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("The document is removed only after the backend confirms the deletion.")
            }
        }
        .accessibilityIdentifier(KairoAccessibilityID.careerDocuments)
        .sheet(item: $preview) { SecureDocumentPreviewSheet(preview: $0) }
    }

    private var emptyMessage: String {
        if case .certification = presentation.parent {
            return "Add a certificate to this existing record. You can replace or remove the attachment without recreating the certification."
        }
        return "Add a PDF, JPEG, or PNG when you are ready."
    }

    private var documentList: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            KairoSectionHeading(title: "Attached documents", count: documents.count)
            ForEach(documentGroups, id: \.title) { group in
                KairoSectionHeading(title: group.title, count: group.items.count)
                ForEach(group.items) { document in
                KairoDocumentRow(
                    filename: document.originalFilename,
                    metadata: "\(typeTitle(document.documentType)) · \(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file))",
                    source: presentation.parent.title,
                    status: statusTitle(document.verificationStatus),
                    details: {
                        if case .employment = presentation.parent {
                            Text(document.evidenceRole?.title ?? "Unclassified legacy evidence — not yet counted toward Employment verification.")
                                .font(KairoTypography.footnote).fixedSize(horizontal: false, vertical: true)
                            if document.canClassifyLegacyEvidence, presentation.parent.canUpload {
                                ForEach(EmploymentEvidenceRole.allCases.filter { EmploymentEvidenceTypePolicy.allows(document.documentType, role: $0) }, id: \.self) { role in
                                    Button(role.title) { classify(document, as: role) }
                                        .buttonStyle(KairoActionStyle(role: .secondary)).disabled(isMutating)
                                        .accessibilityIdentifier("career.documents.classify.\(document.id).\(role.rawValue)")
                                }
                            }
                        }
                    },
                    actions: {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: KairoSpacing.medium) { rowActions(document) }.disabled(isMutating)
                            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) { rowActions(document) }.disabled(isMutating)
                        }
                    }
                )
                .accessibilityIdentifier(KairoAccessibilityID.careerDocumentRow(document.id))
            }
            }
        }
    }

    private var documentGroups: [(title: String, items: [CareerDocument])] {
        guard case .employment = presentation.parent else { return [("Documents", documents)] }
        return [
            ("Primary evidence", documents.filter { $0.evidenceRole == .primary }),
            ("Supporting evidence — optional", documents.filter { $0.evidenceRole == .supporting }),
            ("Unclassified evidence — not counted", documents.filter { $0.evidenceRole == nil })
        ].filter { !$0.1.isEmpty }
    }

    @ViewBuilder
    private func rowActions(_ document: CareerDocument) -> some View {
        Button("View") { view(document) }
            .buttonStyle(KairoActionStyle())
        if presentation.parent.canDelete {
            Button("Replace") {
                clearSelection()
                if case .employment = presentation.parent, !document.canPreserveEmploymentReplacement {
                    errorMessage = CareerDocumentServiceError.legacyClassificationRequired.localizedDescription
                    return
                }
                selectedType = document.documentType
                selectedEvidenceRole = document.evidenceRole ?? .primary
                pendingReplacement = document
                chooseFile()
            }
            .buttonStyle(KairoActionStyle())
            Button("Remove", role: .destructive) { pendingDelete = document }
                .buttonStyle(KairoActionStyle(role: .destructiveSecondary))
        }
    }

    private var availableDocumentTypes: [CareerDocumentType] {
        if case .employment = presentation.parent {
            return EmploymentEvidenceTypePolicy.options(documentTypes, role: selectedEvidenceRole)
        }
        return documentTypes
    }

    private var uploadControls: some View {
        KairoSection {
            Text("Add document")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text("1. Choose evidence purpose and type").font(KairoTypography.headline)
            if case .employment = presentation.parent {
                ForEach(EmploymentEvidenceRole.allCases, id: \.self) { role in
                    Button {
                        guard selectedEvidenceRole != role else { return }
                        selectedEvidenceRole = role
                        selectedType = ""
                        clearSelection()
                    } label: {
                        Label(role.title, systemImage: selectedEvidenceRole == role ? "checkmark.circle.fill" : "circle")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(KairoActionStyle(role: .secondary)).disabled(isMutating)
                        .accessibilityAddTraits(selectedEvidenceRole == role ? [.isSelected] : [])
                        .accessibilityIdentifier("career.documents.evidenceRole.\(role.rawValue)")
                }
            }
            EvidenceTypeSelector(value: pendingReplacement == nil ? selectedType : "", options: availableDocumentTypes) { selectedType = $0; clearSelection() }
                .disabled(isMutating || isLoading)
            Text("2. Choose a file, then review before uploading").font(KairoTypography.footnote)

            KairoPrimaryButton(
                title: "Choose file",
                isLoading: isMutating,
                accessibilityIdentifier: KairoAccessibilityID.careerDocumentUpload,
                action: { clearSelection(); chooseFile() }
            )
            .disabled(isMutating || isLoading || !availableDocumentTypes.contains { $0.id == selectedType })

            Text((presentation.parent.isCertification || presentation.parent.isPortfolio) ? "PDF, JPEG, or PNG • up to 50 MB" : "PDF, JPEG, or PNG • up to 20 MB")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private func load() async {
        errorMessage = nil
        eligibility = nil
        do {
            let loaded = try await service.listDocuments(for: presentation.parent)
            let types = service.documentTypes(for: presentation.parent)
            await MainActor.run {
                documents = loaded
                documentTypes = types
                if pendingReplacement == nil, !availableDocumentTypes.contains(where: { $0.id == selectedType }) {
                    if case .employment = presentation.parent {
                        selectedType = ""
                    } else {
                        // Preserve the existing non-Employment upload defaults.
                        selectedType = types.contains { $0.id == "other" } ? "other" : types.first?.id ?? ""
                    }
                }
                isLoading = false
            }
            try await refreshEligibility()
        } catch {
            await present(error)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard !isMutating else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFile = url
            uploadFailed = false
            uploadConfirmed = false
            errorMessage = nil
        case .failure:
            errorMessage = "KairoID couldn't read that file. Choose another supported document."
        }
    }

    private func chooseFile() {
#if KAIRO_LOCAL_BATCH1_QA
        if LocalBatch1QA.mode("batch3Evidence", configuration: .resolve()), let syntheticSelection {
            handleFileSelection(.success([syntheticSelection]))
            return
        }
#endif
        isFileImporterPresented = true
    }

    private func clearSelection() {
        selectedFile = nil
        pendingReplacement = nil
        uploadFailed = false
        uploadConfirmed = false
    }

    private func uploadSelection() {
        guard !isMutating, let url = selectedFile else { return }
        guard pendingReplacement != nil || availableDocumentTypes.contains(where: { $0.id == selectedType }) else { return }
        let replacement = pendingReplacement
        let type = selectedType
        let role = selectedEvidenceRole
        uploadStage = .uploading
        let progress: @Sendable (DocumentUploadStage) -> Void = { stage in
            Task { @MainActor in uploadStage = stage }
        }
        isMutating = true
        errorMessage = nil
        eligibility = nil
        Task {
            do {
                let loaded: [CareerDocument]
                if let replacement {
                    loaded = try await service.replaceDocument(
                        replacement,
                        with: url,
                        documentType: type,
                        evidenceRole: role,
                        parent: presentation.parent, progress: progress
                    )
                } else {
                    loaded = try await service.uploadDocument(
                        fileURL: url,
                        documentType: type,
                        evidenceRole: role,
                        to: presentation.parent, progress: progress
                    )
                }
                await MainActor.run {
                    documents = loaded
                    clearSelection()
                    uploadConfirmed = true
                    isMutating = false
                    refreshStore.candidateDataChanged()
                }
                try await refreshEligibility()
            } catch { uploadFailed = true; await present(error) }
        }
    }

    private func view(_ document: CareerDocument) {
        errorMessage = nil
        if presentation.parent.isPortfolio {
            preview = SecureDocumentPreview(careerParent: presentation.parent, filename: document.originalFilename)
            return
        }
        Task {
            do {
                let url = try await service.downloadURL(for: document, parent: presentation.parent)
                await MainActor.run {
                    preview = SecureDocumentPreview(url: url, filename: document.originalFilename)
                }
            } catch { await present(error) }
        }
    }

    private func refreshEligibility() async throws {
        guard case .employment(let id, _, _, _) = presentation.parent else { return }
        eligibility = nil
        eligibility = try await service.employmentEligibility(id: id)
    }

    private func classify(_ document: CareerDocument, as role: EmploymentEvidenceRole) {
        guard !isMutating else { return }
        isMutating = true
        errorMessage = nil
        eligibility = nil
        Task {
            defer { isMutating = false }
            do {
                try await service.classifyEvidence(document, parent: presentation.parent, role: role)
                refreshStore.candidateDataChanged()
                await load()
            } catch { await present(error) }
        }
    }

    private func deletePendingDocument() {
        guard !isMutating else { return }
        guard let document = pendingDelete else { return }
        pendingDelete = nil
        isMutating = true
        errorMessage = nil
        eligibility = nil
        Task {
            do {
                let loaded = try await service.deleteDocument(document, parent: presentation.parent)
                await MainActor.run {
                    documents = loaded
                    isMutating = false
                    refreshStore.candidateDataChanged()
                }
                try await refreshEligibility()
            } catch { await present(error) }
        }
    }

    @MainActor
    private func present(_ error: Error) async {
        isLoading = false
        isMutating = false
        errorMessage = safeMessage(for: error)
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            await sessionStore.refreshLaunchRoute()
        }
    }

    private func safeMessage(for error: Error) -> String {
        if let documentError = error as? CareerDocumentServiceError {
            return documentError.errorDescription ?? "The document action could not be completed. Please try again."
        }
        if let transferError = error as? SecureDocumentTransferError {
            return transferError.errorDescription ?? "The secure document transfer could not be completed. Please try again."
        }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .transport:
                return "KairoID couldn't reach your documents. Check your connection and try again."
            case .unavailableInDemoMode:
                return "Document changes are unavailable in this preview."
            case .api, .invalidResponse, .invalidURL:
                return "KairoID couldn't complete that document action. Please try again."
            }
        }
        return "KairoID couldn't complete that document action. Please try again."
    }

    private func typeTitle(_ value: String) -> String {
        documentTypes.first(where: { $0.id == value })?.label
            ?? value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func statusTitle(_ value: String) -> String {
        let title = ProductStatusLanguage.title(for: value)
        if case .certification = presentation.parent {
            return ProductStatusLanguage.optionalRecordTitle(title) ?? "Attachment"
        }
        return title
    }
}
