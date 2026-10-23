import SwiftUI
import UniformTypeIdentifiers

enum VaultHeadingStyle {
    static let color = KairoColors.teal
    // Bold headline meets the large-text contrast threshold on the Vault canvas.
    static let font = KairoTypography.headline.bold()
}

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
    @State private var selectedType: VaultDocumentType = .aadhaar
    @State private var documentNumber = ""
    @State private var includesExpiry = false
    @State private var expiryDate = Date()
    @State private var editingDocument: VaultDocument?
    @State private var pendingDelete: VaultDocument?
    @State private var addingDocument = false
    @State private var selectedFile: URL?
    @State private var uploadFailed = false
    @State private var uploadConfirmed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    privacyCard
                    Button { addingDocument.toggle() } label: {
                        HStack {
                            Label("Add document", systemImage: "plus")
                            Spacer()
                            Image(systemName: addingDocument ? "chevron.up" : "chevron.down")
                        }.font(KairoTypography.action).frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityIdentifier("vault.add")
                        .accessibilityValue(addingDocument ? "Expanded" : "Collapsed")
                        .accessibilityHint("Shows or hides private upload options")
                    if addingDocument { uploadCard }
                    if let selectedFile {
                        EvidenceUploadReview(type: reviewType.title,
                            filename: reviewType.metadataFilename(selectedFile.lastPathComponent, contentType: ""),
                            isUploading: isMutating, retry: uploadFailed,
                            upload: uploadSelection, cancel: clearSelection)
                    }
                    if uploadConfirmed {
                        Text("Document added. Vault was refreshed from KairoID.").accessibilityIdentifier("evidence.added")
                    }

                    if isLoading {
                        KairoLoadingStateView(
                            title: "Loading Vault",
                            message: "KairoID is fetching private document metadata."
                        )
                    } else if documents.isEmpty {
                        Text("No private identity documents yet.").accessibilityIdentifier("vault.empty")
                    } else {
                        documentSection(title: "Private identity documents", documents: currentDocuments.filter { !DocumentHierarchy.vaultIsLegacy($0) })
                        documentSection(title: "Legacy documents", documents: currentDocuments.filter { DocumentHierarchy.vaultIsLegacy($0) })
                        if !historicalDocuments.isEmpty {
                            documentSection(title: "Version history", documents: historicalDocuments)
                        }
                    }

                    if let errorMessage {
                        KairoErrorStateView(title: "Vault action failed", message: errorMessage)
                    }
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .disabled(isMutating)
                }
            }
            .task { await load() }
            .refreshable { if !isMutating { await load() } }
            .onChange(of: selectedType) { _, type in
                if !type.allowsDocumentNumber { documentNumber = "" }
            }
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
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Label("Private by default", systemImage: "lock.shield")
                .font(VaultHeadingStyle.font)
                .foregroundStyle(VaultHeadingStyle.color)
            Text("Private identity and personal documents. Uploading does not mean verified. Sharing requires your explicit selection.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var uploadCard: some View {
        KairoSection {
            Text("1. Select a private document type").font(VaultHeadingStyle.font)
                .foregroundStyle(VaultHeadingStyle.color)
            EvidenceTypeSelector(value: selectedType.rawValue,
                options: VaultDocumentType.newUploadTypes.map { .init(id: $0.rawValue, label: $0.title) },
                titleColor: VaultHeadingStyle.color, titleFont: VaultHeadingStyle.font) {
                selectedType = VaultDocumentType(rawValue: $0)
                clearSelection()
            }
            .accessibilityIdentifier("candidate.more.documentVault.type")
            .frame(minHeight: 44)

            if selectedType.allowsDocumentNumber {
                KairoTextField(
                    title: "Document number",
                    prompt: "Optional",
                    text: $documentNumber,
                    titleColor: VaultHeadingStyle.color,
                    titleFont: VaultHeadingStyle.font,
                    accessibilityIdentifier: "vault.documentNumber"
                )
            } else {
                Text("An Aadhaar number is not needed. We use a generic document filename. This does not redact the private file you choose to upload.")
                    .font(KairoTypography.footnote)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Toggle(isOn: $includesExpiry) {
                Text("Include an expiry date").font(VaultHeadingStyle.font).foregroundStyle(VaultHeadingStyle.color)
            }
                .tint(KairoColors.brandPrimary)
                .frame(minHeight: 44)
            if includesExpiry {
                DatePicker(selection: $expiryDate, displayedComponents: .date) {
                    Text("Expiry date").font(VaultHeadingStyle.font).foregroundStyle(VaultHeadingStyle.color)
                }
            }

            KairoPrimaryButton(
                title: "Choose private file",
                isLoading: isMutating,
                accessibilityIdentifier: "candidate.more.documentVault.upload",
                action: {
                    clearSelection()
                    uploadMode = .new
                    isFileImporterPresented = true
                }
            )
            .disabled(isMutating || isLoading)

            Text("PDF, JPEG, PNG, or WebP • up to 50 MB")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }.disabled(isMutating)
    }

    @ViewBuilder private func documentSection(title: String, documents: [VaultDocument]) -> some View {
        if !documents.isEmpty {
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                DocumentGroupHeading(title: title, count: documents.count, titleColor: VaultHeadingStyle.color, titleFont: VaultHeadingStyle.font)
                ForEach(documents) { document in documentCard(document) }
            }
        }
    }

    private func documentCard(_ document: VaultDocument) -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.small) {
            Button { view(document) } label: {
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    CompactDocumentLabel(title: document.documentType.title, filename: metadataFilename(document),
                        context: document.isCurrent ? "Identity & Personal · Current" : "Identity & Personal · Replaced version",
                        metadata: "\(statusTitle(document.verificationStatus)) · \(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file))")
                    Text("Added \(document.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                if document.documentType.allowsDocumentNumber, let number = document.documentNumber, !number.isEmpty {
                    Text("Document number: \(number)")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                if let expiresAt = document.expiresAt {
                    Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                if document.documentType != .aadhaar, let note = document.reviewerNote, !note.isEmpty {
                    Text(note)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).disabled(isMutating)
                .accessibilityIdentifier("candidate.more.documentVault.document.\(document.id)")
                .accessibilityHint("Opens the private authenticated preview")
            if document.isCurrent {
                Menu {
                    Button("Edit details") { editingDocument = document }
                    Button("Replace") { clearSelection(); uploadMode = .replace(document); isFileImporterPresented = true }
                    Button("Delete", role: .destructive) { pendingDelete = document }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .disabled(isMutating).accessibilityLabel("More actions for \(metadataFilename(document))")
                    .accessibilityIdentifier("vault.actions.\(document.id)")
            }
        }.padding(.vertical, KairoSpacing.small)
            .overlay(alignment: .bottom) { Rectangle().fill(KairoColors.border).frame(height: 1) }
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
        guard !isMutating else { return }
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFile = url
            uploadFailed = false
            uploadConfirmed = false
            errorMessage = nil
        case .failure:
            errorMessage = "KairoID couldn't read the selected document. Choose a supported file and try again."
        }
    }

    private var reviewType: VaultDocumentType {
        if case .replace(let document) = uploadMode { return document.documentType }
        return selectedType
    }

    private func clearSelection() {
        selectedFile = nil
        uploadMode = .new
        uploadFailed = false
        uploadConfirmed = false
    }

    private func uploadSelection() {
        guard !isMutating, let url = selectedFile else { return }
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
                    let type = replacingDocument?.documentType ?? selectedType
                    let loaded = try await service.uploadDocument(
                        fileURL: url,
                        type: type,
                        documentNumber: type.allowsDocumentNumber ? (replacingDocument?.documentNumber ?? documentNumber) : nil,
                        expiresAt: replacingDocument?.expiresAt ?? (includesExpiry ? expiryDate : nil),
                        replacing: replacingDocument?.id
                    )
                    await MainActor.run {
                        documents = loaded
                        clearSelection()
                        uploadConfirmed = true
                        isMutating = false
                        uploadMode = .new
                        if replacingDocument == nil {
                            documentNumber = ""
                            includesExpiry = false
                        }
                        refreshStore.candidateDataChanged()
                    }
                } catch {
                    uploadFailed = true
                    await present(error)
                }
            }
    }

    private func updateMetadata(document: VaultDocument, number: String?, expiry: Date?) async throws {
        let loaded = try await service.updateMetadata(
            documentID: document.id,
            documentNumber: document.documentType.allowsDocumentNumber ? number : nil,
            expiresAt: expiry
        )
        await MainActor.run {
            documents = loaded
            refreshStore.candidateDataChanged()
        }
    }

    private func view(_ document: VaultDocument) {
        errorMessage = nil
        preview = SecureDocumentPreview(vaultDocumentID: document.id, filename: metadataFilename(document))
    }

    private func metadataFilename(_ document: VaultDocument) -> String {
        document.documentType.metadataFilename(document.originalFilename, contentType: document.contentType)
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
        if let networkError = error as? NetworkError {
            errorMessage = switch networkError {
            case .transport: "KairoID couldn't reach Documents. Check your connection and try again."
            case .api: "KairoID couldn't complete that document action. Refresh and try again."
            case .invalidResponse: "KairoID received an unexpected Documents response. Please try again."
            case .invalidURL: "KairoID's Documents configuration is invalid."
            case .unavailableInDemoMode: "This document action is unavailable in Demo Mode."
            }
        } else {
            errorMessage = "KairoID couldn't complete that document action. Please try again."
        }
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
        _number = State(initialValue: document.documentType.allowsDocumentNumber ? (document.documentNumber ?? "") : "")
        _includesExpiry = State(initialValue: document.expiresAt != nil)
        _expiryDate = State(initialValue: document.expiresAt ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if document.documentType.allowsDocumentNumber {
                        KairoTextField(title: "Document number", prompt: "Optional", text: $number,
                            titleColor: VaultHeadingStyle.color, titleFont: VaultHeadingStyle.font,
                            accessibilityIdentifier: "vault.metadata.documentNumber")
                    }
                    Toggle(isOn: $includesExpiry) {
                        Text("Include expiry date").font(VaultHeadingStyle.font).foregroundStyle(VaultHeadingStyle.color)
                    }
                    if includesExpiry {
                        DatePicker(selection: $expiryDate, displayedComponents: .date) {
                            Text("Expiry date").font(VaultHeadingStyle.font).foregroundStyle(VaultHeadingStyle.color)
                        }
                    }
                } header: {
                    Text("Document details").font(VaultHeadingStyle.font).foregroundStyle(VaultHeadingStyle.color)
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
                    document.documentType.allowsDocumentNumber ? number.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                    includesExpiry ? expiryDate : nil
                )
                await MainActor.run { dismiss() }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = "KairoID couldn't save those document details. Please try again."
                }
            }
        }
    }
}
