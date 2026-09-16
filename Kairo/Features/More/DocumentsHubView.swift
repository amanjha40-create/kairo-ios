import SwiftUI
import UniformTypeIdentifiers

struct DocumentsHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentsHubService) private var service
    @Environment(\.careerDocumentService) private var documents
    @Environment(\.documentVaultService) private var vault
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @EnvironmentObject private var router: AppRouter
    @State private var rows: [DocumentsHubRow] = []
    @State private var category: DocumentsHubCategory = .all
    @State private var loading = true
    @State private var mutating = false
    @State private var message: String?
    @State private var replacement: DocumentsHubRow?
    @State private var removal: DocumentsHubRow?
    @State private var choosingFile = false
    @State private var showsVault = false
    @State private var preview: SecureDocumentPreview?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    Text("Documents you have uploaded to KairoID")
                        .font(KairoTypography.title2)
                    Text("Current attachments and immutable verification history, from your authorized records. Project items may retain a legacy Portfolio origin until the shared migration is complete.")
                        .font(KairoTypography.footnote)
                    Button("Manage Vault / identity documents") { showsVault = true }
                    Button("Share documents") { router.showDocumentPacks() }
                        .accessibilityIdentifier("documents.shareDocuments")
                    Button("Shared document packs") { router.showDocumentPacks(history: true) }
                        .accessibilityIdentifier("documents.sharedPacks")
                    if loading { ProgressView("Loading document sources") }
                    else if let message {
                        KairoErrorStateView(title: "Documents unavailable", message: message)
                        Button("Retry") { Task { await load() } }
                    } else if rows.isEmpty {
                        KairoEmptyStateView(title: "No uploaded documents", message: "Attachments from your Career, verification evidence, and Vault will appear here.", systemImage: "doc.on.doc")
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(DocumentsHubRow.categories(in: rows)) { item in
                                    Button(item.rawValue) { category = item }
                                        .buttonStyle(.bordered)
                                        .tint(category == item ? KairoColors.brandPrimary : KairoColors.textSecondary)
                                        .accessibilityIdentifier("documents.filter.\(item.id)")
                                }
                            }
                        }
                        ForEach(rows.filter { category == .all || $0.category == category }) { row in
                            KairoDocumentRow(filename: row.filename,
                                metadata: "\(row.category.rawValue) · \(row.contentType) · \(ByteCountFormatter.string(fromByteCount: Int64(row.byteSize), countStyle: .file))",
                                source: row.context, status: row.status, isHistorical: row.historical,
                                details: {
                                    if row.immutable { Text("Immutable evidence / history").font(KairoTypography.caption) }
                                    if !row.canView { Text("Historical preview unavailable in the current backend contract.").font(KairoTypography.caption) }
                                }, actions: {
                                    ViewThatFits(in: .horizontal) {
                                        HStack { actions(row) }
                                        VStack(alignment: .leading) { actions(row) }
                                    }
                                })
                                .accessibilityIdentifier("documents.row.\(row.id)")
                        }
                    }
                }
                .padding(KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.disabled(mutating) } }
            .task { await load() }
            .refreshable { if !mutating { await load() } }
            .sheet(isPresented: $showsVault, onDismiss: { Task { await load() } }) { DocumentVaultView() }
            .sheet(item: $preview) { SecureDocumentPreviewSheet(preview: $0) }
            .sheet(item: $router.documentPackPresentation) { DocumentPackView(history: $0.history) }
            .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.pdf, .jpeg, .png], allowsMultipleSelection: false) { result in
                guard let row = replacement else { return }
                replacement = nil
                if case .success(let files) = result, let url = files.first { Task { await replace(row, file: url) } }
            }
            .confirmationDialog("Remove this exact attachment?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
                Button("Remove document", role: .destructive) {
                    guard let row = removal else { return }
                    removal = nil
                    Task { await remove(row) }
                }
                Button("Cancel", role: .cancel) { removal = nil }
            } message: { Text("The linked Career record is preserved. Removal is confirmed by the backend.") }
        }
        .interactiveDismissDisabled(mutating)
        .accessibilityIdentifier("candidate.more.documentsHub")
    }

    @ViewBuilder private func actions(_ row: DocumentsHubRow) -> some View {
        if row.canView { Button("View") { Task { await view(row) } }.disabled(mutating) }
        if row.canReplace { Button("Replace") { replacement = row; choosingFile = true }.disabled(mutating) }
        if row.canRemove { Button("Remove", role: .destructive) { removal = row }.disabled(mutating) }
    }

    private func load() async {
        loading = true
        message = nil
        defer { loading = false }
        do {
            rows = try await service.load()
            if !DocumentsHubRow.categories(in: rows).contains(category) { category = .all }
        } catch { message = "Some authoritative document sources could not be loaded. No partial list is presented as complete." }
    }

    private func view(_ row: DocumentsHubRow) async {
        do {
            switch row.source {
            case .career(let parent, let doc):
                let url = try await documents.downloadURL(for: doc, parent: parent)
                preview = SecureDocumentPreview(url: url, filename: row.filename)
            case .vault(let doc):
                preview = SecureDocumentPreview(vaultDocumentID: doc.id, filename: row.filename)
            case .unavailable: return
            }
        } catch { message = "The backend could not authorize a current document preview." }
    }

    private func replace(_ row: DocumentsHubRow, file: URL) async {
        guard row.canReplace, !mutating else { return }
        mutating = true
        defer { mutating = false }
        do {
            switch row.source {
            case .career(let parent, let doc):
                _ = try await documents.replaceDocument(doc, with: file, documentType: doc.documentType, parent: parent)
            case .vault(let doc):
                _ = try await vault.uploadDocument(fileURL: file, type: doc.documentType, documentNumber: doc.documentNumber, expiresAt: doc.expiresAt, replacing: doc.id)
            case .unavailable: return
            }
            refreshStore.candidateDataChanged()
            await load()
        } catch { message = "Replacement was not confirmed. Refresh before retrying; no local success is assumed." }
    }

    private func remove(_ row: DocumentsHubRow) async {
        guard row.canRemove, !mutating else { return }
        mutating = true
        defer { mutating = false }
        do {
            switch row.source {
            case .career(let parent, let doc): _ = try await documents.deleteDocument(doc, parent: parent)
            case .vault(let doc): _ = try await vault.deleteDocument(documentID: doc.id)
            case .unavailable: return
            }
            refreshStore.candidateDataChanged()
            await load()
        } catch { message = "Removal was not confirmed. Evidence may be locked by the backend. Refresh to check its current state." }
    }
}
