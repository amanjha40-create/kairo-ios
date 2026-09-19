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
    @FocusState private var purposeFocused: Bool
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
                        Text("Share ready").font(KairoTypography.title2).accessibilityIdentifier("pack.ready")
                        packSummary(creation.pack)
                        Text("Only these exact files are shared until expiry or revocation. Save the link now; it cannot be recovered from history.")
                            .font(KairoTypography.footnote)
                        DocumentPackActions(pack: creation.pack, capability: creation.capability)
                        Button { store.finishCreation(); history = true } label: {
                            Text("Done").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.bordered)
                            .accessibilityIdentifier("pack.done")
                    } else { createContent }
                }.padding(KairoSpacing.medium)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(KairoColors.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if purposeFocused {
                    HStack {
                        Spacer()
                        Button { purposeFocused = false } label: {
                            Text("Done editing").frame(minWidth: 44, minHeight: 44)
                        }.accessibilityIdentifier("pack.purpose.done")
                    }
                    .padding(.horizontal, KairoSpacing.medium)
                    .background(KairoColors.background)
                }
            }
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
        Text("Shared document packs").font(KairoTypography.headline)
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
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text(pack.purpose).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(pack.documentCount) documents · \(pack.statusTitle) · \(pack.viewCount) views")
                            .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                        Text("Created \(pack.createdAt.formatted(date: .abbreviated, time: .omitted)) · Expires \(pack.expiresAt.formatted(date: .abbreviated, time: .omitted))")
                            .font(KairoTypography.caption)
                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        .padding(.vertical, KairoSpacing.small)
                        .overlay(alignment: .bottom) { Rectangle().fill(KairoColors.border).frame(height: 1) }
                }.buttonStyle(.plain).accessibilityIdentifier("pack.history.\(pack.id)")
                    .accessibilityElement(children: .combine)
            }
            Button { Task { await store.loadHistory(service) } } label: { Text("Refresh history").frame(minHeight: 44) }
        }
    }

    @ViewBuilder private var createContent: some View {
        Text("Step \(store.step.rawValue + 1) of 4").font(KairoTypography.caption)
        switch store.step {
        case .selection: selection
        case .purpose:
            Text("Purpose").font(KairoTypography.title2)
            TextField("Employment onboarding — Acme", text: $store.purpose, axis: .vertical)
                .lineLimit(1...4).focused($purposeFocused)
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
                .font(KairoTypography.bodyStrong).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("pack.review.purpose")
            Text("Expires in \(store.expiryDays) days").font(KairoTypography.footnote).accessibilityIdentifier("pack.review.expiry")
            DocumentGroupHeading(title: "Selected documents", count: store.selected.count)
                .accessibilityIdentifier("pack.review.count")
            ForEach(store.selected) { document in documentLabel(document) }
            Text("This pack shares these exact file versions. Replacing or removing the source does not update this pack. Revoke the pack to stop access; create a new pack to add files.").font(KairoTypography.footnote)
                .accessibilityIdentifier("pack.review.snapshot")
            Text("Sharing a document does not verify its contents or your identity.").font(KairoTypography.footnote)
        }
        if store.ambiguous {
            Button("Check Shared document packs") { history = true }.accessibilityIdentifier("pack.checkHistory")
        }
        HStack {
            if store.step != .selection { Button { store.back() } label: { Text("Back").frame(minWidth: 44, minHeight: 44) }.disabled(store.busy).accessibilityIdentifier("pack.back") }
            if store.step == .review {
                Button { Task { await store.create(service) } } label: { Text("Create secure link").frame(minHeight: 44) }
                    .buttonStyle(.borderedProminent).disabled(!store.canCreate).accessibilityIdentifier("pack.create")
            } else {
                Button { store.next() } label: { Text("Continue").frame(minHeight: 44) }.buttonStyle(.borderedProminent)
                    .disabled(!store.canContinue).accessibilityIdentifier("pack.continue")
            }
        }
    }

    @ViewBuilder private var selection: some View {
        Text("Select documents").font(KairoTypography.title2)
        HStack {
            Text("\(store.selected.count) selected").font(KairoTypography.bodyStrong).accessibilityIdentifier("pack.selectedCount")
            Spacer()
            Button { store.clearSelection() } label: { Text("Clear selection").frame(minHeight: 44) }
                .accessibilityIdentifier("pack.clear")
        }
        Text("Choose exact files only. No Profile, Passport, Trust Score or historical verification evidence. Up to 20 files / 200 MB.")
            .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
        if store.loading { ProgressView("Loading eligible documents").accessibilityIdentifier("pack.loading") }
        else if store.error != nil && store.documents.isEmpty {
            Button("Retry documents") { Task { await store.loadDocuments(service) } }.accessibilityIdentifier("pack.documents.retry")
        } else {
            Picker("Category", selection: $store.category) {
                ForEach(store.categories, id: \.self) { category in Text(category == "all" ? "All categories" : DocumentPackCategory.title(category)).tag(category) }
            }.accessibilityIdentifier("pack.category")
                .frame(minHeight: 44)
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
                Rectangle().fill(KairoColors.border).frame(height: 1)
            }
            if !store.selected.isEmpty && !store.selectionValid { Text(DocumentPackError.limit.localizedDescription) }
            Button { Task { await store.loadDocuments(service) } } label: { Text("Refresh eligible documents").frame(minHeight: 44) }
                .disabled(store.busy || store.ambiguous).accessibilityIdentifier("pack.refreshDocuments")
        }
    }
    private func documentLabel(_ document: PackSelectableDocument) -> some View {
        CompactDocumentLabel(title: document.title, filename: document.filename, context: document.context,
            metadata: "\(document.categoryTitle) · Uploaded document · \(ByteCountFormatter.string(fromByteCount: Int64(document.byteSize), countStyle: .file))")
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
                        .fixedSize(horizontal: false, vertical: true)
                    Text(pack.statusTitle).accessibilityIdentifier("pack.detail.status")
                    Text("\(pack.documentCount) documents").font(KairoTypography.bodyStrong).accessibilityIdentifier("pack.detail.count")
                    Text("Created \(pack.createdAt.formatted())").font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    Text("Expires \(pack.expiresAt.formatted())").font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                    Text("\(pack.viewCount) views").accessibilityIdentifier("pack.detail.analytics")
                    if let date = pack.lastViewedAt { Text("Last viewed \(date.formatted())").font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary) }
                    Text("Exact file snapshots at creation; source changes do not update this pack.").font(KairoTypography.footnote)
                    DocumentPackItemList(items: pack.items)
                    if pack.isActive {
                        if let creation = store.creation, creation.pack.id == id {
                            DocumentPackActions(pack: pack, capability: creation.capability,
                                onRecipientDismiss: { Task { await store.loadDetail(id, service: service) } })
                        } else { Text("The bearer link is not recoverable from history. You can still revoke access.").font(KairoTypography.footnote) }
                        Button(role: .destructive) { confirming = true } label: { Text("Revoke pack").frame(minHeight: 44) }.disabled(store.busy).accessibilityIdentifier("pack.revoke")
                    }
                    Button { Task { await store.loadDetail(id, service: service) } } label: { Text("Refresh detail").frame(minHeight: 44) }.disabled(store.busy)
                }
            }.padding(KairoSpacing.medium)
        }.background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Pack detail").navigationBarTitleDisplayMode(.inline)
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: KairoSpacing.small), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2), spacing: KairoSpacing.small) {
                Button {
                    UIPasteboard.general.setItems([["public.url": capability.copyURL]], options: [.localOnly: true, .expirationDate: min(pack.expiresAt, Date().addingTimeInterval(300))])
                    copied = true
                } label: { actionLabel(copied ? "Copied" : "Copy", symbol: "doc.on.doc") }.accessibilityIdentifier("pack.copy")
                Button { qr = true } label: { actionLabel("QR", symbol: "qrcode") }.accessibilityIdentifier("pack.qr")
                ShareLink(item: capability.shareURL, subject: Text("KairoID shared documents"), message: Text("View my selected documents")) { actionLabel("Share", symbol: "square.and.arrow.up") }.accessibilityIdentifier("pack.share")
                Button { recipient = true } label: { actionLabel("View recipient", symbol: "eye") }.accessibilityIdentifier("pack.preview")
                }.accessibilityElement(children: .contain).accessibilityIdentifier("pack.actions")
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
    private func actionLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(KairoTypography.action)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
    }
}

struct DocumentPackItemList: View {
    let items: [DocumentPackItem]
    var body: some View {
        ForEach(items) { item in
            CompactDocumentLabel(title: item.title, filename: item.filename, context: item.context,
                metadata: "\(DocumentPackCategory.title(item.category)) · Uploaded document · \(ByteCountFormatter.string(fromByteCount: Int64(item.byteSize), countStyle: .file))")
                .accessibilityIdentifier("pack.snapshot.\(item.id)")
            Rectangle().fill(KairoColors.border).frame(height: 1)
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
