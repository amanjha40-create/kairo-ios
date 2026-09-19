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
                    Text("Your documents across KairoID. Select exact files to share in a Document Pack.")
                        .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    KairoPrimaryButton(title: "Share documents", accessibilityIdentifier: "documents.shareDocuments") {
                        router.showDocumentPacks()
                    }
                    if loading { ProgressView("Loading document sources") }
                    else if let message {
                        KairoErrorStateView(title: "Documents unavailable", message: message)
                        Button { Task { await load() } } label: { Text("Retry").frame(minWidth: 44, minHeight: 44) }
                    } else if rows.isEmpty {
                        Text("No documents yet.").font(KairoTypography.body).accessibilityIdentifier("documents.empty")
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(DocumentsHubRow.categories(in: rows)) { item in
                                    Button { category = item } label: {
                                        Text(item.rawValue).frame(minHeight: 44)
                                    }
                                        .buttonStyle(.bordered)
                                        .tint(category == item ? KairoColors.brandPrimary : KairoColors.textSecondary)
                                        .accessibilityIdentifier("documents.filter.\(item.id)")
                                        .accessibilityValue(category == item ? "Selected" : "Not selected")
                                }
                            }
                        }.accessibilityElement(children: .contain).accessibilityIdentifier("documents.filters")
                        ForEach(DocumentHierarchy.groups(rows, category: category)) { group in
                            DocumentGroupHeading(title: group.title, count: group.rows.count)
                                .accessibilityIdentifier("documents.group.\(group.id)")
                            ForEach(group.rows) { row in documentRow(row) }
                        }
                    }
                    KairoSecondaryButton(title: "Shared document packs", accessibilityIdentifier: "documents.sharedPacks") {
                        router.showDocumentPacks(history: true)
                    }
                    Button { showsVault = true } label: {
                        Label("Vault · Private identity & personal documents", systemImage: "lock.doc")
                            .font(KairoTypography.body).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }.accessibilityIdentifier("documents.vault")
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

    private func documentRow(_ row: DocumentsHubRow) -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.small) {
            Group {
                if row.canView {
                    Button { Task { await view(row) } } label: { rowLabel(row) }
                        .buttonStyle(.plain).disabled(mutating)
                        .accessibilityHint("Opens the authorized document preview")
                } else { rowLabel(row) }
            }.accessibilityIdentifier("documents.row.\(row.id)")
            if row.canReplace || row.canRemove {
                Menu {
                    if row.canReplace { Button("Replace") { replacement = row; choosingFile = true } }
                    if row.canRemove { Button("Remove", role: .destructive) { removal = row } }
                } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .disabled(mutating).accessibilityLabel("More actions for \(row.filename)")
                    .accessibilityIdentifier("documents.actions.\(row.id)")
            }
        }.padding(.vertical, KairoSpacing.small)
            .overlay(alignment: .bottom) { Rectangle().fill(KairoColors.border).frame(height: 1) }
    }

    private func rowLabel(_ row: DocumentsHubRow) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            CompactDocumentLabel(title: DocumentHierarchy.title(row), filename: row.filename, context: row.context,
                metadata: "\(row.status) · \(ByteCountFormatter.string(fromByteCount: Int64(row.byteSize), countStyle: .file))")
            if row.immutable { Text("Read-only evidence / history").font(KairoTypography.caption) }
            if !row.canView { Text("Historical preview unavailable in the current backend contract.").font(KairoTypography.caption) }
        }.foregroundStyle(KairoColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
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
