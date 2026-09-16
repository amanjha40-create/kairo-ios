import SwiftUI
import UIKit

nonisolated struct DocumentPackPresentation: Identifiable, Equatable, Sendable {
    let id = UUID()
    let history: Bool
}

struct DocumentPackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentPackService) private var service
    @EnvironmentObject private var session: AppSessionStore
    @StateObject private var store = DocumentPackStore()
    @State private var history: Bool
    init(history: Bool = false) { _history = State(initialValue: history) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    Picker("Document pack destination", selection: $history) {
                        Text("Share documents").tag(false)
                        Text("Shared document packs").tag(true)
                    }.pickerStyle(.segmented).disabled(store.busy || store.loading)
                        .accessibilityIdentifier("pack.mode")
                    if let error = store.error {
                        Text(error.localizedDescription).foregroundStyle(KairoColors.danger)
                            .accessibilityIdentifier("pack.error")
                        if !history && !store.ambiguous && store.creation == nil && (error == .rejected || error == .unavailable) {
                            Button("Refresh eligible documents") {
                                store.step = .selection
                                Task { await store.loadDocuments(service) }
                            }.disabled(store.busy).accessibilityIdentifier("pack.refreshSelection")
                        }
                    }
                    if store.busy { ProgressView("Confirming with server").accessibilityIdentifier("pack.busy") }
                    if history { historyContent }
                    else if let creation = store.creation {
                        Text("Document pack ready").font(KairoTypography.title2).accessibilityIdentifier("pack.ready")
                        packSummary(creation.pack)
                        Text("Anyone with this link can access only these files until expiry or revocation. Save or share it now; the link cannot be recovered from history.")
                            .font(KairoTypography.footnote)
                        DocumentPackActions(pack: creation.pack, capability: creation.capability)
                        Button("Done") { store.finishCreation(); history = true }.buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("pack.done")
                    } else { createContent }
                }.padding(KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Document packs").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Close") { dismiss() }.disabled(store.busy) } }
            .navigationDestination(for: String.self) { id in
                DocumentPackDetailView(id: id, store: store)
            }
            .task(id: history) {
                if history { await store.loadHistory(service) }
                else if store.creation == nil { await store.loadDocuments(service) }
            }
            .onChange(of: session.currentUser?.id) { _, _ in store.endSession(); dismiss() }
        }
        .interactiveDismissDisabled(store.busy)
        .controlSize(.large)
        .onDisappear { store.endSession() }
        .accessibilityIdentifier("pack.root")
    }

    @ViewBuilder private var historyContent: some View {
        Text("Shared document packs").font(KairoTypography.title2)
        Text("Old links cannot be recovered. History contains exact file snapshots, not your latest attachments.")
            .font(KairoTypography.footnote)
        if store.loading { ProgressView("Loading packs").accessibilityIdentifier("pack.loading") }
        else if store.error != nil {
            Button("Retry history") { Task { await store.loadHistory(service) } }.accessibilityIdentifier("pack.history.retry")
        } else if store.packs.isEmpty {
            Text("No shared document packs yet.").accessibilityIdentifier("pack.history.empty")
        } else {
            ForEach(store.packs) { pack in
                NavigationLink(value: pack.id) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(pack.purpose).font(KairoTypography.headline)
                        Text("\(pack.documentCount) documents · \(pack.statusTitle) · \(pack.viewCount) views")
                        Text("Created \(pack.createdAt.formatted(date: .abbreviated, time: .omitted)) · Expires \(pack.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(KairoTypography.caption)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.accessibilityIdentifier("pack.history.\(pack.id)")
                Divider()
            }
            Button("Refresh history") { Task { await store.loadHistory(service) } }
        }
    }

    @ViewBuilder private var createContent: some View {
        Text("Step \(store.step.rawValue + 1) of 4").font(KairoTypography.caption)
        switch store.step {
        case .selection: selection
        case .purpose:
            Text("Purpose").font(KairoTypography.title2)
            TextField("Employment onboarding — Acme", text: $store.purpose, axis: .vertical)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Purpose").accessibilityIdentifier("pack.purpose")
            Text("Required, 1–120 characters. Visible to the recipient.").font(KairoTypography.footnote)
            Text("\(store.purpose.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count)/120")
            if !store.purpose.isEmpty && !DocumentPackLimits.validPurpose(store.purpose) {
                Text(DocumentPackError.invalidPurpose.localizedDescription).accessibilityIdentifier("pack.purpose.invalid")
            }
        case .expiry:
            Text("Link expiry").font(KairoTypography.title2)
            ForEach(DocumentPackLimits.expiryDays, id: \.self) { days in
                Button { store.expiryDays = days } label: {
                    Label("\(days) \(days == 1 ? "day" : "days")", systemImage: store.expiryDays == days ? "largecircle.fill.circle" : "circle")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }.accessibilityIdentifier("pack.expiry.\(days)")
                    .accessibilityValue(store.expiryDays == days ? "Selected" : "Not selected")
            }
        case .review:
            Text("Review selection").font(KairoTypography.title2).accessibilityIdentifier("pack.review")
            Text("Purpose: \(store.purpose.trimmingCharacters(in: .whitespacesAndNewlines))")
            Text("Expires in \(store.expiryDays) days")
            Text("\(store.selected.count) selected documents")
            ForEach(store.selected) { document in documentLabel(document) }
            Text("This pack shares these exact file versions. Replacing or removing the source does not update this pack. Revoke the pack to stop access; create a new pack to add files.").font(KairoTypography.footnote)
            Text("Sharing a document does not verify its contents or your identity.").font(KairoTypography.footnote)
        }
        if store.ambiguous {
            Button("Check Shared document packs") { history = true }.accessibilityIdentifier("pack.checkHistory")
        }
        HStack {
            if store.step != .selection { Button("Back") { store.back() }.disabled(store.busy).accessibilityIdentifier("pack.back") }
            if store.step == .review {
                Button("Create secure link") { Task { await store.create(service) } }
                    .buttonStyle(.borderedProminent).disabled(!store.canCreate).accessibilityIdentifier("pack.create")
            } else {
                Button("Continue") { store.next() }.buttonStyle(.borderedProminent)
                    .disabled(!store.canContinue).accessibilityIdentifier("pack.continue")
            }
        }
    }

    @ViewBuilder private var selection: some View {
        Text("Select documents").font(KairoTypography.title2)
        Text("Only explicitly selected files are shared. No Passport, Profile, Trust Score, unrelated files, or historical verification evidence is included.").font(KairoTypography.footnote)
        if store.loading { ProgressView("Loading eligible documents").accessibilityIdentifier("pack.loading") }
        else if store.error != nil && store.documents.isEmpty {
            Button("Retry documents") { Task { await store.loadDocuments(service) } }.accessibilityIdentifier("pack.documents.retry")
        } else {
            Picker("Category", selection: $store.category) {
                ForEach(store.categories, id: \.self) { category in Text(category == "all" ? "All categories" : DocumentPackCategory.title(category)).tag(category) }
            }.accessibilityIdentifier("pack.category")
            HStack {
                Text("\(store.selected.count) selected").accessibilityIdentifier("pack.selectedCount")
                Spacer()
                Button { store.clearSelection() } label: { Text("Clear selection").frame(minHeight: 44) }
                    .accessibilityIdentifier("pack.clear")
            }
            Button("Refresh eligible documents") { Task { await store.loadDocuments(service) } }
                .disabled(store.busy || store.ambiguous).accessibilityIdentifier("pack.refreshDocuments")
            if store.visible.isEmpty { Text("No shareable documents in this category.").accessibilityIdentifier("pack.documents.empty") }
            ForEach(store.visible) { document in
                Button { store.toggle(document) } label: {
                    HStack(alignment: .top) {
                        Image(systemName: store.selectedIDs.contains(document.id) ? "checkmark.square.fill" : "square")
                        documentLabel(document)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("pack.select.\(document.id)")
                    .accessibilityLabel("\(document.title), \(document.filename), \(document.categoryTitle)")
                    .accessibilityValue(store.selectedIDs.contains(document.id) ? "Selected" : "Not selected")
                Divider()
            }
            if !store.selected.isEmpty && !store.selectionValid { Text(DocumentPackError.limit.localizedDescription) }
        }
    }
    private func documentLabel(_ document: PackSelectableDocument) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(document.title).font(KairoTypography.headline)
            Text(document.filename)
            if let context = document.context { Text(context) }
            Text("\(document.categoryTitle) · Uploaded document · \(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file))").font(KairoTypography.caption)
        }.fixedSize(horizontal: false, vertical: true)
    }
    private func packSummary(_ pack: DocumentPack) -> some View {
        VStack(alignment: .leading) {
            Text(pack.purpose).font(KairoTypography.headline)
            Text("\(pack.documentCount) documents · \(pack.statusTitle)")
            Text("Expires \(pack.expiresAt.formatted())")
        }
    }
}

private struct DocumentPackDetailView: View {
    let id: String
    @ObservedObject var store: DocumentPackStore
    @Environment(\.documentPackService) private var service
    @State private var confirming = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                if store.loading { ProgressView("Loading pack detail") }
                if let error = store.error {
                    Text(error.localizedDescription)
                    Button("Refresh detail") { Task { await store.loadDetail(id, service: service) } }
                }
                if let pack = store.detail, pack.id == id {
                    Text(pack.purpose).font(KairoTypography.title2)
                    Text(pack.statusTitle).accessibilityIdentifier("pack.detail.status")
                    Text("Created \(pack.createdAt.formatted())")
                    Text("Expires \(pack.expiresAt.formatted())")
                    Text("\(pack.documentCount) documents · \(pack.viewCount) views").accessibilityIdentifier("pack.detail.analytics")
                    if let date = pack.lastViewedAt { Text("Last viewed \(date.formatted())") }
                    Text("Exact file snapshots at creation; source changes do not update this pack.").font(KairoTypography.footnote)
                    DocumentPackItemList(items: pack.items)
                    if pack.isActive {
                        if let creation = store.creation, creation.pack.id == id {
                            DocumentPackActions(pack: pack, capability: creation.capability,
                                onRecipientDismiss: { Task { await store.loadDetail(id, service: service) } })
                        } else { Text("The bearer link is not recoverable from history. You can still revoke access.").font(KairoTypography.footnote) }
                        Button("Revoke pack", role: .destructive) { confirming = true }.disabled(store.busy).accessibilityIdentifier("pack.revoke")
                    }
                    Button("Refresh detail") { Task { await store.loadDetail(id, service: service) } }.disabled(store.busy)
                }
            }.padding(KairoSpacing.medium)
        }.navigationTitle("Pack detail").navigationBarTitleDisplayMode(.inline)
            .task { await store.loadDetail(id, service: service) }
            .alert("Revoke this document pack?", isPresented: $confirming) {
                Button("Revoke access", role: .destructive) { Task { await store.revoke(id, service: service) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Recipient access stops. Source documents and Career records are not removed. History is retained.") }
            .accessibilityIdentifier("pack.detail")
    }
}

private struct DocumentPackActions: View {
    let pack: DocumentPack
    let capability: DocumentPackCapability
    var onRecipientDismiss: () -> Void = {}
    @State private var copied = false
    @State private var qr = false
    @State private var recipient = false
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 12) {
                Button(copied ? "Copied" : "Copy") {
                    UIPasteboard.general.setItems([["public.url": capability.copyURL]], options: [.localOnly: true, .expirationDate: min(pack.expiresAt, Date().addingTimeInterval(300))])
                    copied = true
                }.accessibilityIdentifier("pack.copy")
                Button("QR") { qr = true }.accessibilityIdentifier("pack.qr")
                ShareLink(item: capability.shareURL, subject: Text("KairoID shared documents"), message: Text("View my selected documents")) { Text("Share") }.accessibilityIdentifier("pack.share")
                Button("View recipient") { recipient = true }.accessibilityIdentifier("pack.preview")
                Text("Opening the recipient view records a server-authoritative view.").font(KairoTypography.caption)
            }.buttonStyle(.bordered).disabled(!pack.isActive)
        }
        .sheet(isPresented: $qr) {
            NavigationStack {
                VStack {
                    if let image = PassportShareQRCode.image(for: capability.qrURL) {
                        Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(maxWidth: 260)
                            .accessibilityLabel("QR code granting access to this document pack")
                    } else { Text("QR unavailable. Use Copy instead.") }
                    Text("Share only with intended recipients.")
                }.padding().navigationTitle("Document Pack QR")
                    .toolbar { Button("Done") { qr = false } }
            }.privacySensitive().accessibilityIdentifier("pack.qr.sheet")
        }
        .sheet(isPresented: $recipient, onDismiss: onRecipientDismiss) { DocumentPackRecipientView(capability: capability) }
    }
}

struct DocumentPackItemList: View {
    let items: [DocumentPackItem]
    var body: some View {
        ForEach(items) { item in
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(KairoTypography.headline)
                Text(item.filename)
                if let context = item.context { Text(context) }
                Text("\(DocumentPackCategory.title(item.category)) · Uploaded document").font(KairoTypography.caption)
            }.fixedSize(horizontal: false, vertical: true)
            Divider()
        }
    }
}

private struct DocumentPackRecipientView: View {
    let capability: DocumentPackCapability
    @Environment(\.documentPackService) private var service
    @Environment(\.dismiss) private var dismiss
    @State private var pack: PublicDocumentPack?
    @State private var failed = false
    @State private var requested = false
    @State private var preview: SecureDocumentPreview?
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    if failed { Text("This document pack is unavailable. It may have expired or been revoked.").accessibilityIdentifier("pack.recipient.unavailable") }
                    else if let pack {
                        Text(pack.purpose).font(KairoTypography.title2)
                        Text("\(pack.documentCount) documents · Expires \(pack.expiresAt.formatted())")
                        ForEach(pack.items) { item in
                            DocumentPackItemList(items: [item])
                            Button("View \(item.title)") { preview = .init(documentPack: capability, itemID: item.id, filename: item.filename) }
                                .accessibilityIdentifier("pack.recipient.item.\(item.id)")
                        }
                        Text("These files were selected by the sender. Uploading or sharing a document does not verify its contents or the sender’s identity.")
                    } else { ProgressView("Loading shared documents") }
                }.padding()
            }.navigationTitle("Shared documents").navigationBarTitleDisplayMode(.inline)
                .toolbar { Button("Done") { dismiss() } }
                .task {
                    guard !requested else { return }
                    requested = true
                    do { pack = try await service.recipient(capability) }
                    catch { failed = true }
                }
                .sheet(item: $preview) { SecureDocumentPreviewSheet(preview: $0) }
        }.privacySensitive().accessibilityIdentifier("pack.recipient")
    }
}
