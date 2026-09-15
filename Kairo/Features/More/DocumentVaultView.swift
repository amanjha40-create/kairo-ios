import SwiftUI
import UniformTypeIdentifiers

struct DocumentVaultView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preview: SecureDocumentPreview?
    @Environment(\.documentVaultService) private var service
    @EnvironmentObject private var sessionStore: AppSessionStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore

    @State private var documents: [VaultDocument] = []
    @State private var isLoading = true
    @State private var isMutating = false
    @State private var errorMessage: String?
    @State private var isFileImporterPresented = false
    @State private var uploadMode: VaultUploadMode = .new
    @State private var selectedType: VaultDocumentType = .other
    @State private var documentNumber = ""
    @State private var includesExpiry = false
    @State private var expiryDate = Date()
    @State private var editingDocument: VaultDocument?
    @State private var pendingDelete: VaultDocument?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    privacyCard

                    if isLoading {
                        KairoLoadingStateView(
                            title: "Loading Document Vault",
                            message: "KairoID is fetching private document metadata."
                        )
                    } else if documents.isEmpty {
                        KairoEmptyStateView(
                            title: "Your Vault is empty",
                            message: "Add a private identity document when you are ready. Documents are never shared automatically.",
                            systemImage: "lock.doc"
                        )
                    } else {
                        documentSection(title: "Current documents", documents: currentDocuments)
                        if !historicalDocuments.isEmpty {
                            documentSection(title: "Version history", documents: historicalDocuments)
                        }
                    }

                    uploadCard

                    if let errorMessage {
                        KairoErrorStateView(title: "Vault action failed", message: errorMessage)
                    }
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Document Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isMutating)
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.pdf, .jpeg, .png, .webP],
                allowsMultipleSelection: false,
                onCompletion: handleFileSelection
            )
            .sheet(item: $editingDocument) { document in
                VaultMetadataEditor(
                    document: document,
                    onSave: { number, expiry in
                        try await updateMetadata(document: document, number: number, expiry: expiry)
                    }
                )
            }
            .confirmationDialog(
                "Delete this private document?",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Delete document", role: .destructive) { deletePendingDocument() }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("KairoID removes the document only after the backend confirms deletion.")
            }
        }
        .accessibilityIdentifier("candidate.more.documentVault")
        .sheet(item: $preview) { SecureDocumentPreviewSheet(preview: $0) }
    }

    private var currentDocuments: [VaultDocument] {
        documents.filter(\.isCurrent)
    }

    private var historicalDocuments: [VaultDocument] {
        documents.filter { !$0.isCurrent }
    }

    private var privacyCard: some View {
        KairoSection {
            Label("Private by default", systemImage: "lock.shield")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
            Text("Vault documents stay private unless you explicitly select them as verification evidence. KairoID uses short-lived secure URLs for upload and viewing; storage locations are never shown here.")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var uploadCard: some View {
        KairoSection {
            Text("Add document")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Picker("Document type", selection: $selectedType) {
                ForEach(VaultDocumentType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }

            KairoTextField(
                title: "Document number",
                prompt: "Optional",
                text: $documentNumber
            )

            Toggle("Include an expiry date", isOn: $includesExpiry)
                .tint(KairoColors.brandPrimary)
            if includesExpiry {
                DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
            }

            KairoPrimaryButton(
                title: "Choose private file",
                isLoading: isMutating,
                accessibilityIdentifier: "candidate.more.documentVault.upload",
                action: {
                    uploadMode = .new
                    isFileImporterPresented = true
                }
            )
            .disabled(isMutating)

            Text("PDF, JPEG, PNG, or WebP • up to 50 MB")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private func documentSection(title: String, documents: [VaultDocument]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text(title)
                .font(KairoTypography.sectionEyebrow)
                .foregroundStyle(KairoColors.textSecondary)
                .textCase(.uppercase)

            ForEach(documents) { document in
                documentCard(document)
            }
        }
    }

    private func documentCard(_ document: VaultDocument) -> some View {
        KairoDocumentRow(
            filename: document.originalFilename,
            metadata: "\(document.documentType.title) · \(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file))",
            source: document.isCurrent ? "Documents · Current" : "Documents · Replaced",
            status: statusTitle(document.verificationStatus),
            isHistorical: !document.isCurrent,
            details: {
                if let number = document.documentNumber, !number.isEmpty {
                    Text("Document number: \(number)")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                if let expiresAt = document.expiresAt {
                    Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                if let note = document.reviewerNote, !note.isEmpty {
                    Text(note)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            },
            actions: {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: KairoSpacing.small) { documentActions(document) }
                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) { documentActions(document) }
                }
            }
        )
        .accessibilityIdentifier("candidate.more.documentVault.document.\(document.id)")
    }

    @ViewBuilder
    private func documentActions(_ document: VaultDocument) -> some View {
        Button("View securely") { view(document) }
            .buttonStyle(.plain)
            .foregroundStyle(KairoColors.brandPrimary)
            .frame(minHeight: 44)

        if document.isCurrent {
            Button("Edit details") { editingDocument = document }
                .buttonStyle(.plain)
                .foregroundStyle(KairoColors.brandPrimary)
                .frame(minHeight: 44)
            Button("Replace") {
                uploadMode = .replace(document)
                isFileImporterPresented = true
            }
            .buttonStyle(.plain)
            .foregroundStyle(KairoColors.brandPrimary)
            .frame(minHeight: 44)
            Button("Delete", role: .destructive) { pendingDelete = document }
                .buttonStyle(.plain)
                .foregroundStyle(KairoColors.danger)
                .frame(minHeight: 44)
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await service.listDocuments()
            await MainActor.run {
                documents = loaded
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
            let mode = uploadMode
            isMutating = true
            errorMessage = nil
            Task {
                do {
                    let replacingDocument: VaultDocument?
                    switch mode {
                    case .new: replacingDocument = nil
                    case .replace(let document): replacingDocument = document
                    }
                    let loaded = try await service.uploadDocument(
                        fileURL: url,
                        type: replacingDocument?.documentType ?? selectedType,
                        documentNumber: replacingDocument?.documentNumber ?? documentNumber,
                        expiresAt: replacingDocument?.expiresAt ?? (includesExpiry ? expiryDate : nil),
                        replacing: replacingDocument?.id
                    )
                    await MainActor.run {
                        documents = loaded
                        isMutating = false
                        uploadMode = .new
                        if replacingDocument == nil {
                            documentNumber = ""
                            includesExpiry = false
                        }
                        refreshStore.candidateDataChanged()
                    }
                } catch {
                    await present(error)
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func updateMetadata(document: VaultDocument, number: String?, expiry: Date?) async throws {
        let loaded = try await service.updateMetadata(
            documentID: document.id,
            documentNumber: number,
            expiresAt: expiry
        )
        await MainActor.run {
            documents = loaded
            refreshStore.candidateDataChanged()
        }
    }

    private func view(_ document: VaultDocument) {
        errorMessage = nil
        Task {
            do {
                let url = try await service.downloadURL(documentID: document.id)
                await MainActor.run {
                    preview = SecureDocumentPreview(url: url, filename: document.originalFilename)
                }
            } catch {
                await present(error)
            }
        }
    }

    private func deletePendingDocument() {
        guard let document = pendingDelete else { return }
        pendingDelete = nil
        isMutating = true
        errorMessage = nil
        Task {
            do {
                let loaded = try await service.deleteDocument(documentID: document.id)
                await MainActor.run {
                    documents = loaded
                    isMutating = false
                    refreshStore.candidateDataChanged()
                }
            } catch {
                await present(error)
            }
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

    private func statusTitle(_ value: String) -> String {
        ProductStatusLanguage.title(for: value)
    }
}

private enum VaultUploadMode {
    case new
    case replace(VaultDocument)
}

private struct VaultMetadataEditor: View {
    let document: VaultDocument
    let onSave: (String?, Date?) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var number: String
    @State private var includesExpiry: Bool
    @State private var expiryDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(document: VaultDocument, onSave: @escaping (String?, Date?) async throws -> Void) {
        self.document = document
        self.onSave = onSave
        _number = State(initialValue: document.documentNumber ?? "")
        _includesExpiry = State(initialValue: document.expiresAt != nil)
        _expiryDate = State(initialValue: document.expiresAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document details") {
                    TextField("Document number", text: $number)
                    Toggle("Include expiry date", isOn: $includesExpiry)
                    if includesExpiry {
                        DatePicker("Expiry date", selection: $expiryDate, displayedComponents: .date)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(KairoColors.danger)
                    }
                }
            }
            .navigationTitle("Edit details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                try await onSave(
                    number.trimmingCharacters(in: .whitespacesAndNewlines),
                    includesExpiry ? expiryDate : nil
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
