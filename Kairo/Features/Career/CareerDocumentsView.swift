import SwiftUI
import UniformTypeIdentifiers

struct CareerDocumentsView: View {
    let presentation: CareerDocumentPresentation

    @Environment(\.dismiss) private var dismiss
    @State private var preview: SecureDocumentPreview?
    @Environment(\.careerDocumentService) private var service
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var documents: [CareerDocument] = []
    @State private var documentTypes: [CareerDocumentType] = []
    @State private var selectedType = "other"
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var isFileImporterPresented = false
    @State private var pendingReplacement: CareerDocument?
    @State private var pendingDelete: CareerDocument?
    @State private var errorMessage: String?

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

                    if presentation.parent.canUpload {
                        uploadControls
                    } else if case .employment = presentation.parent {
                        Text("Documents cannot be added while this employment record uses employer confirmation or is in a locked workflow state.")
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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
            .refreshable { await load() }
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
            ForEach(documents) { document in
                KairoDocumentRow(
                    filename: document.originalFilename,
                    metadata: "\(typeTitle(document.documentType)) · \(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file))",
                    source: presentation.parent.title,
                    status: statusTitle(document.verificationStatus),
                    details: { EmptyView() },
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

    @ViewBuilder
    private func rowActions(_ document: CareerDocument) -> some View {
        Button("View") { view(document) }
            .buttonStyle(KairoActionStyle())
        if presentation.parent.canDelete {
            Button("Replace") {
                selectedType = document.documentType
                pendingReplacement = document
                isFileImporterPresented = true
            }
            .buttonStyle(KairoActionStyle())
            Button("Remove", role: .destructive) { pendingDelete = document }
                .buttonStyle(KairoActionStyle(role: .destructiveSecondary))
        }
    }

    private var uploadControls: some View {
        KairoSection {
            Text("Add document")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Picker("Document type", selection: $selectedType) {
                ForEach(documentTypes) { option in Text(option.label).tag(option.id) }
            }

            KairoPrimaryButton(
                title: "Choose file",
                isLoading: isMutating,
                accessibilityIdentifier: KairoAccessibilityID.careerDocumentUpload,
                action: { isFileImporterPresented = true }
            )
            .disabled(isMutating)

            Text((presentation.parent.isCertification || presentation.parent.isPortfolio) ? "PDF, JPEG, or PNG • up to 50 MB" : "PDF, JPEG, or PNG • up to 20 MB")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await service.listDocuments(for: presentation.parent)
            let types = service.documentTypes(for: presentation.parent)
            await MainActor.run {
                documents = loaded
                documentTypes = types
                if let first = types.first, !types.contains(where: { $0.id == selectedType }) {
                    selectedType = first.id
                }
                isLoading = false
            }
        } catch {
            await present(error)
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        guard !isMutating else { return }
        let replacement = pendingReplacement
        pendingReplacement = nil
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isMutating = true
            errorMessage = nil
            Task {
                do {
                    let loaded: [CareerDocument]
                    if let replacement {
                        loaded = try await service.replaceDocument(
                            replacement,
                            with: url,
                            documentType: selectedType,
                            parent: presentation.parent
                        )
                    } else {
                        loaded = try await service.uploadDocument(
                            fileURL: url,
                            documentType: selectedType,
                            to: presentation.parent
                        )
                    }
                    await MainActor.run {
                        documents = loaded
                        isMutating = false
                        refreshStore.candidateDataChanged()
                    }
                } catch { await present(error) }
            }
        case .failure:
            errorMessage = "KairoID couldn't read that file. Choose another supported document."
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

    private func deletePendingDocument() {
        guard !isMutating else { return }
        guard let document = pendingDelete else { return }
        pendingDelete = nil
        isMutating = true
        errorMessage = nil
        Task {
            do {
                let loaded = try await service.deleteDocument(document, parent: presentation.parent)
                await MainActor.run {
                    documents = loaded
                    isMutating = false
                    refreshStore.candidateDataChanged()
                }
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
        ProductStatusLanguage.title(for: value)
    }
}
