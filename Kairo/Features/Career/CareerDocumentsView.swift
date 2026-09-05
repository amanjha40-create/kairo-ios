import SwiftUI
import UniformTypeIdentifiers

struct CareerDocumentsView: View {
    let presentation: CareerDocumentPresentation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.careerDocumentService) private var service
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var documents: [CareerDocument] = []
    @State private var documentTypes: [CareerDocumentType] = []
    @State private var selectedType = "other"
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var isFileImporterPresented = false
    @State private var pendingDelete: CareerDocument?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    KairoCard {
                        Text(presentation.parent.title)
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)
                        Text("Documents stay private unless you explicitly use them as verification evidence or include them in a Passport share.")
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if isLoading {
                        KairoLoadingStateView(title: "Loading documents", message: "Kairo is fetching private document metadata.")
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
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
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
    }

    private var emptyMessage: String {
        if case .certification = presentation.parent {
            return "This certification does not have an uploaded certificate. The current backend only accepts a certificate file when a certification is first created."
        }
        return "Add a PDF, JPEG, or PNG when you are ready."
    }

    private var documentList: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text("Attached documents (\(documents.count))")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            ForEach(documents) { document in
                KairoCard {
                    Text(document.originalFilename)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(typeTitle(document.documentType))
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text("\(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file)) • \(statusTitle(document.verificationStatus))")
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)

                    HStack(spacing: KairoSpacing.large) {
                        Button("View") { view(document) }
                            .buttonStyle(.plain)
                            .foregroundStyle(KairoColors.brandPrimary)
                        if presentation.parent.canDelete {
                            Button("Delete", role: .destructive) { pendingDelete = document }
                                .buttonStyle(.plain)
                                .foregroundStyle(KairoColors.danger)
                        }
                    }
                    .font(KairoTypography.footnote)
                }
                .accessibilityIdentifier(KairoAccessibilityID.careerDocumentRow(document.id))
            }
        }
    }

    private var uploadControls: some View {
        KairoCard {
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

            Text("PDF, JPEG, or PNG • up to 20 MB")
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
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            isMutating = true
            errorMessage = nil
            Task {
                do {
                    let loaded = try await service.uploadDocument(
                        fileURL: url,
                        documentType: selectedType,
                        to: presentation.parent
                    )
                    await MainActor.run {
                        documents = loaded
                        isMutating = false
                        refreshStore.candidateDataChanged()
                    }
                } catch { await present(error) }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func view(_ document: CareerDocument) {
        errorMessage = nil
        Task {
            do {
                let url = try await service.downloadURL(for: document, parent: presentation.parent)
                await MainActor.run {
                    openURL(url) { accepted in
                        if !accepted { errorMessage = "This device could not open the secure document preview." }
                    }
                }
            } catch { await present(error) }
        }
    }

    private func deletePendingDocument() {
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
        errorMessage = error.localizedDescription
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            await sessionStore.refreshLaunchRoute()
        }
    }

    private func typeTitle(_ value: String) -> String {
        documentTypes.first(where: { $0.id == value })?.label
            ?? value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func statusTitle(_ value: String) -> String {
        value.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
