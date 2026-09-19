import SwiftUI
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

@MainActor
final class PassportShareManagementViewModel: ObservableObject {
    @Published private(set) var shares: [PassportShare] = []
    @Published private(set) var isLoading = false
    @Published var error: PassportSharePresentationError?

    private let service: any PassportShareServiceProtocol
    private var hasLoaded = false

    init(service: any PassportShareServiceProtocol) {
        self.service = service
    }

    var activeShares: [PassportShare] { shares.filter { $0.state == .active } }
    var expiredShares: [PassportShare] { shares.filter { $0.state == .expired } }
    var revokedShares: [PassportShare] { shares.filter { $0.state == .revoked } }

    func load() async {
        guard !hasLoaded else { return }
        await reload()
    }

    func reload() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            shares = try await service.listShares().sorted { $0.createdAt > $1.createdAt }
            hasLoaded = true
        } catch {
            self.error = .map(error, fallbackTitle: "Passport shares unavailable")
        }
    }
}

@MainActor
final class PassportShareCreateViewModel: ObservableObject {
    @Published var draft: PassportShareDraft
    @Published private(set) var creation: PassportShareCreation?
    @Published private(set) var isSubmitting = false
    @Published var error: PassportSharePresentationError?
    @Published private(set) var capabilities: PassportShareCapabilities?
    @Published private(set) var loadingCapabilities = false
    @Published private(set) var submissionAttempted = false

    private let service: any PassportShareServiceProtocol

    init(
        service: any PassportShareServiceProtocol,
        draft: PassportShareDraft = PassportShareDraft()
    ) {
        self.service = service
        self.draft = draft
    }

    func loadCapabilities() async {
        guard capabilities == nil, !loadingCapabilities else { return }
        loadingCapabilities = true
        defer { loadingCapabilities = false }
        do {
            let value = try await service.capabilities()
            guard value.supportsV2 else { throw PassportShareServiceError.capabilitiesUnavailable }
            capabilities = value
            draft.selectMode(.verifiedOnly, capabilities: value)
        } catch {
            self.error = .map(error, fallbackTitle: "Sharing policy unavailable")
        }
    }

    func create(now: Date = Date()) async -> Bool {
        guard !isSubmitting, !submissionAttempted, creation == nil else { return false }
        guard let capabilities else {
            error = .map(PassportShareServiceError.capabilitiesUnavailable, fallbackTitle: "Sharing policy unavailable")
            return false
        }
        guard let input = draft.mutationInput(now: now), draft.validationMessage == nil else {
            error = .init(
                title: "Check sharing choices",
                message: draft.validationMessage ?? PassportShareServiceError.invalidDraft.localizedDescription
            )
            return false
        }

        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            try capabilities.validate(input)
            submissionAttempted = true
            creation = try await service.createShare(input)
            return true
        } catch {
            self.error = .map(error, fallbackTitle: "Share result unavailable")
            return false
        }
    }
}

@MainActor
final class PassportShareDetailViewModel: ObservableObject {
    @Published private(set) var share: PassportShare
    @Published private(set) var analytics: PassportShareAnalytics?
    @Published private(set) var isLoading = false
    @Published private(set) var isRevoking = false
    @Published var analyticsError: PassportSharePresentationError?
    @Published var error: PassportSharePresentationError?

    private let service: any PassportShareServiceProtocol

    init(service: any PassportShareServiceProtocol, share: PassportShare) {
        self.service = service
        self.share = share
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            share = try await service.getShare(id: share.id)
        } catch {
            self.error = .map(error, fallbackTitle: "Share unavailable")
            return
        }
        await loadAnalytics()
    }

    func loadAnalytics() async {
        analyticsError = nil
        do {
            analytics = try await service.getAnalytics(shareID: share.id)
        } catch {
            analytics = nil
            analyticsError = .map(error, fallbackTitle: "View summary unavailable")
        }
    }

    func revoke() async -> Bool {
        guard share.state == .active, !isRevoking else { return false }
        isRevoking = true
        error = nil
        defer { isRevoking = false }

        do {
            share = try await service.revokeShare(id: share.id)
            await loadAnalytics()
            return true
        } catch {
            self.error = .map(error, fallbackTitle: "Share not revoked")
            return false
        }
    }

    func applyUpdatedShare(_ updated: PassportShare) async {
        share = updated
        await load()
    }
}

struct PassportShareManagementSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PassportShareManagementViewModel

    private let service: any PassportShareServiceProtocol
    private let onMutation: () -> Void

    init(
        service: any PassportShareServiceProtocol,
        onMutation: @escaping () -> Void
    ) {
        self.service = service
        self.onMutation = onMutation
        _model = StateObject(wrappedValue: PassportShareManagementViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    introduction
                    createEntry
                    shareContent
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Passport shares")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .refreshable { await model.reload() }
        }
        .task { await model.load() }
        .alert(item: $model.error) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                primaryButton: .default(Text("Retry")) { Task { await model.reload() } },
                secondaryButton: .cancel()
            )
        }
        .presentationDetents([.large])
        .accessibilityIdentifier(KairoAccessibilityID.passportShareManagement)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text("Share on your terms")
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
            Text("Choose a mode, sections, Purpose and expiry. Review before creating a link.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var createEntry: some View {
        NavigationLink {
            PassportShareCreateView(
                service: service,
                onCreated: {
                    onMutation()
                    Task { await model.reload() }
                }
            )
        } label: {
            Text("Create Passport share")
                .font(KairoTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoSpacing.medium)
                .background(KairoColors.brandPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(KairoAccessibilityID.passportShareCreateEntry)
    }

    @ViewBuilder
    private var shareContent: some View {
        if model.isLoading, model.shares.isEmpty {
            KairoLoadingStateView(
                title: "Loading Passport shares",
                message: "KairoID is fetching your authoritative share history."
            )
        } else if model.shares.isEmpty {
            KairoEmptyStateView(
                title: "No Passport shares yet",
                message: "Create a privacy-controlled link when you are ready to share your Passport.",
                systemImage: "link.badge.plus"
            )
        } else {
            shareSection(title: "Active", shares: model.activeShares)
            shareSection(title: "Expired", shares: model.expiredShares)
            shareSection(title: "Revoked", shares: model.revokedShares)
        }
    }

    @ViewBuilder
    private func shareSection(title: String, shares: [PassportShare]) -> some View {
        if !shares.isEmpty {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                Text(title)
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                ForEach(shares) { share in
                    NavigationLink {
                        PassportShareDetailView(
                            service: service,
                            share: share,
                            onMutation: {
                                onMutation()
                                Task { await model.reload() }
                            }
                        )
                    } label: {
                        PassportShareRow(share: share)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(KairoAccessibilityID.passportShareRow(share.id))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(KairoAccessibilityID.passportShareList(title.lowercased()))
        }
    }
}

private struct PassportShareRow: View {
    let share: PassportShare

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                Image(systemName: share.state.symbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(share.displayLabel)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(PassportShareHierarchy.modeTitle(share.sharingMode))
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text(share.permissions.conciseSummary)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(expiryText)
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text("Created \(share.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                }

                Spacer(minLength: KairoSpacing.small)
                Text(share.state.title)
                    .font(KairoTypography.caption)
                    .foregroundStyle(statusColor)
            }
        }
        .padding(.vertical, KairoSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Rectangle().fill(KairoColors.border).frame(height: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(share.displayLabel), \(PassportShareHierarchy.modeTitle(share.sharingMode)), \(share.state.title), created \(share.createdAt.formatted(date: .abbreviated, time: .omitted)), \(expiryText), \(share.permissions.conciseSummary)")
    }

    private var expiryText: String {
        if let expiresAt = share.expiresAt {
            return "Expires \(expiresAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No expiry"
    }

    private var statusColor: Color {
        switch share.state {
        case .active: KairoColors.success
        case .expired: KairoColors.warning
        case .revoked, .unknown: KairoColors.textSecondary
        }
    }
}

struct PassportShareCreateView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: PassportShareCreateViewModel
    @State private var showsQRCode = false
    @State private var copiedLink = false

    private let onCreated: () -> Void

    init(
        service: any PassportShareServiceProtocol,
        onCreated: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: PassportShareCreateViewModel(service: service))
        self.onCreated = onCreated
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                if let creation = model.creation {
                    successContent(creation)
                } else {
                    creationContent
                }
            }
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.large)
        }
        .background(KairoColors.background.ignoresSafeArea())
        .navigationTitle(model.creation == nil ? "Create share" : "Share ready")
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $model.error) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showsQRCode) {
            if let creation = model.creation {
                PassportShareQRCodeView(publicURL: creation.publicURL)
            }
        }
        .interactiveDismissDisabled(model.isSubmitting)
        .task { await model.loadCapabilities() }
    }

    private var creationContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            if let capabilities = model.capabilities {
                PassportShareMutationForm(draft: $model.draft, capabilities: capabilities)
            } else {
                KairoSection {
                    Text("Sharing is disabled until the server policy is confirmed.")
                    if model.loadingCapabilities { ProgressView("Loading sharing policy") }
                    else { Button("Retry sharing policy") { Task { await model.loadCapabilities() } } }
                }
            }
            if model.submissionAttempted, model.creation == nil, !model.isSubmitting {
                Text("Do not create another link after an uncertain response. Return to share history and refresh to check the server result.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            KairoSection {
                Text(PassportShareHierarchy.stages[3])
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                PassportShareReview(draft: model.draft)
                Text("Aggregate view tracking is enabled for this link. Only backend-reported views appear in Share Activity; creating or copying a link does not imply a recipient view.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("passport.share.review")

            KairoPrimaryButton(
                title: model.isSubmitting ? "Creating share…" : "Create share",
                isLoading: model.isSubmitting,
                accessibilityIdentifier: KairoAccessibilityID.passportShareCreate,
                action: {
                    Task {
                        if await model.create() {
                            onCreated()
                        }
                    }
                }
            )
            .disabled(model.isSubmitting || model.submissionAttempted || model.capabilities == nil || model.draft.validationMessage != nil)
        }
    }

    private func successContent(_ creation: PassportShareCreation) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoSection {
                Text(PassportShareHierarchy.stages[4])
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                Text("Passport share ready")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(creation.share.displayLabel)
                    .font(KairoTypography.bodyStrong)
                    .fixedSize(horizontal: false, vertical: true)
                Text(PassportShareHierarchy.modeTitle(creation.share.sharingMode))
                    .font(KairoTypography.footnote)
                Text(expiryText(creation.share))
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(creation.share.permissions.enabledOptions.map(\.title).joined(separator: ", "))
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                Text("The public URL is returned only once. Copy or share it now; KairoID does not reconstruct it from share history.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier(KairoAccessibilityID.passportShareSuccess)

            KairoSection {
                Text(creation.publicURL.absoluteString)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(KairoColors.textPrimary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    UIPasteboard.general.url = creation.publicURL
                    copiedLink = true
                } label: {
                    Label(copiedLink ? "Link copied" : "Copy link", systemImage: copiedLink ? "checkmark" : "doc.on.doc")
                        .font(KairoTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoSpacing.medium)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(KairoAccessibilityID.passportShareCopyLink)

                ShareLink(
                    item: creation.publicURL,
                    subject: Text("My KairoID Trust Passport"),
                    message: Text("Here is my KairoID Trust Passport.")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(KairoTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoSpacing.medium)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(KairoAccessibilityID.passportShareNativeShare)

                Button {
                    showsQRCode = true
                } label: {
                    Label("Show QR code", systemImage: "qrcode")
                        .font(KairoTypography.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoSpacing.medium)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(KairoAccessibilityID.passportShareQRCode)

                Link(destination: creation.publicURL) {
                    Label("Preview public Passport", systemImage: "safari")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, KairoSpacing.medium)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("passport.share.preview")
            }

            KairoPrimaryButton(
                title: "Done",
                accessibilityIdentifier: KairoAccessibilityID.passportShareManage,
                action: { dismiss() }
            )

            Text("No recipient view is implied until the backend reports one.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private func expiryText(_ share: PassportShare) -> String {
        if let expiresAt = share.expiresAt {
            return "Expires \(expiresAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No expiry"
    }
}

private struct PassportShareMutationForm: View {
    @Binding var draft: PassportShareDraft
    var capabilities: PassportShareCapabilities? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoSection {
                Text(draft.originalShare == nil ? PassportShareHierarchy.stages[0] : "Sharing policy")
                    .font(KairoTypography.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(draft.sharingMode.title).font(KairoTypography.headline)
                    .accessibilityIdentifier("passport.share.selectedMode")
                if draft.originalShare != nil {
                    Text("Existing links can only be narrowed. To share more information, create a new link. The existing policy will not be converted.")
                        .font(KairoTypography.footnote)
                } else if let capabilities {
                    Text("Verified only is the default: only eligible verified records. Owner attribution is not verified identity; private email and phone are excluded.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                    Toggle("Verified + Candidate-provided", isOn: Binding(
                        get: { draft.sharingMode == .mixed },
                        set: { draft.selectMode($0 ? .mixed : .verifiedOnly, capabilities: capabilities) }
                    ))
                    .disabled(!capabilities.modes.contains(PassportSharingMode.mixed.rawValue))
                    .accessibilityIdentifier("passport.share.mixedOptIn")
                    .frame(minHeight: 44)
                    .accessibilityHint("Explicit opt-in. Off selects Verified only; on includes only the Candidate-provided sections you choose.")
                    Text("Explicit opt-in includes selected information you supplied, labelled Candidate-provided. Changing mode clears optional disclosures; sharing never verifies a record.")
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            }
            permissionGroup(title: draft.originalShare == nil ? PassportShareHierarchy.stages[1] : "Narrow shared content", options: options)
            KairoSection {
                KairoSectionHeading(title: draft.originalShare == nil ? PassportShareHierarchy.stages[2] : "Purpose & expiry")
                KairoTextField(
                    title: "Purpose (required)",
                    prompt: "Recruiter link",
                    text: $draft.label,
                    errorMessage: draft.purposeValidationMessage,
                    accessibilityIdentifier: KairoAccessibilityID.passportShareLabel
                )
                Text("Shown in your share history and public share metadata. Avoid sensitive notes.")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            KairoSection {
                Text("Expiry")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)
                Picker("Expiry", selection: $draft.expiryPreset) {
                    ForEach(PassportShareExpiryPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier(KairoAccessibilityID.passportShareExpiry)

                if draft.expiryPreset == .custom {
                    DatePicker(
                        "Expires",
                        selection: $draft.customExpiry,
                        in: Date().addingTimeInterval(60)...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .accessibilityIdentifier(KairoAccessibilityID.passportShareCustomExpiry)
                }

                Text("Expiry is enforced by the backend. No-expiry links stay active until you revoke them.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

        }
    }

    private var options: [PassportSharePermissionOption] {
        if let original = draft.originalShare { return original.permissions.enabledOptions }
        return capabilities?.options(for: draft.sharingMode) ?? []
    }

    private func permissionGroup(
        title: String,
        options: [PassportSharePermissionOption]
    ) -> some View {
        KairoSection {
            Text(title)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)

            ForEach(options) { option in
                Toggle(isOn: permissionBinding(option)) {
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text(option.title)
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.textPrimary)
                        Text(option.detail)
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityIdentifier(KairoAccessibilityID.passportSharePermission(option.rawValue))
                .frame(minHeight: 44)
            }
        }
    }

    private func permissionBinding(_ option: PassportSharePermissionOption) -> Binding<Bool> {
        Binding(
            get: { draft.permissions.isEnabled(option) },
            set: { enabled in
                if enabled, let original = draft.originalShare, !original.permissions.isEnabled(option) { return }
                draft.permissions.set(enabled, for: option)
                if !enabled && option == .profile { draft.permissions.showPhoto = false }
                if !enabled && option == .documents { draft.permissions.includeUserDocuments = false }
            }
        )
    }
}

struct PassportShareDetailView: View {
    @StateObject private var model: PassportShareDetailViewModel
    @State private var showsEdit = false
    @State private var showsRevokeConfirmation = false

    private let service: any PassportShareServiceProtocol
    private let onMutation: () -> Void

    init(
        service: any PassportShareServiceProtocol,
        share: PassportShare,
        onMutation: @escaping () -> Void
    ) {
        self.service = service
        self.onMutation = onMutation
        _model = StateObject(wrappedValue: PassportShareDetailViewModel(service: service, share: share))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                statusCard
                publicLinkCard
                permissionCard
                analyticsCard
                timestampCard
                actions
            }
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.large)
        }
        .background(KairoColors.background.ignoresSafeArea())
        .navigationTitle(model.share.displayLabel)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(isPresented: $showsEdit) {
            PassportShareEditView(service: service, share: model.share) { updated in
                Task { await model.applyUpdatedShare(updated) }
                onMutation()
            }
        }
        .alert(item: $model.error) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .alert("Revoke this share?", isPresented: $showsRevokeConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Revoke share", role: .destructive) {
                Task {
                    if await model.revoke() { onMutation() }
                }
            }
            .accessibilityIdentifier(KairoAccessibilityID.passportShareRevokeConfirm)
        } message: {
            Text("Revocation is permanent. The public URL will stop resolving and cannot be restored.")
        }
        .accessibilityIdentifier(KairoAccessibilityID.passportShareDetail)
    }

    private var statusCard: some View {
        KairoSection {
            Label(model.share.state.title, systemImage: model.share.state.symbol)
                .font(KairoTypography.title2)
                .foregroundStyle(statusColor)
            Text(expiryText)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
            Text(model.share.permissions.conciseSummary)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
            Text(model.share.sharingMode.title)
                .font(KairoTypography.bodyStrong)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Share status \(model.share.state.title). \(expiryText). Permissions: \(model.share.permissions.conciseSummary)")
    }

    private var publicLinkCard: some View {
        KairoSection {
            Text("Public link")
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
            Text("For security, the backend returns the raw public URL only when a share is created. It cannot be reconstructed from this history entry. Create a new link if you no longer have the original URL.")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if model.share.state != .active {
                Text("This share is \(model.share.state.title.lowercased()); link actions are unavailable.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            }
        }
    }

    private var permissionCard: some View {
        KairoSection {
            Text("Shared content")
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
            Text(model.share.sharingMode.title)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
            Text("Only the enabled permissions below are shared. Candidate attribution does not verify identity.")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)

            if model.share.permissions.enabledOptions.isEmpty {
                Text("No additional Passport sections")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
            } else {
                ForEach(model.share.permissions.enabledOptions) { option in
                    Label(option.title, systemImage: "checkmark.circle.fill")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textPrimary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.share.sharingMode.title). Permissions: \(model.share.permissions.conciseSummary)")
    }

    private var analyticsCard: some View {
        KairoSection {
            Text("View summary")
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)

            if let analytics = model.analytics {
                HStack(spacing: KairoSpacing.xLarge) {
                    metric(value: analytics.totalViews, label: "Total views")
                    metric(value: analytics.uniqueViews, label: "Unique views")
                }
                Text(analytics.lastViewedAt.map {
                    "Last viewed \($0.formatted(date: .abbreviated, time: .shortened))"
                } ?? "No recipient view reported yet")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            } else if let error = model.analyticsError {
                Text(error.message)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                Button("Retry view summary") { Task { await model.loadAnalytics() } }
            } else {
                ProgressView()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(analyticsAccessibilityLabel)
    }

    private var timestampCard: some View {
        KairoSection {
            Text("Share history")
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
            Text("Created \(model.share.createdAt.formatted(date: .abbreviated, time: .shortened))")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textPrimary)
            Text("Updated \(model.share.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textPrimary)
            if let revokedAt = model.share.revokedAt {
                Text("Revoked \(revokedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: KairoSpacing.small) {
            KairoSecondaryButton(
                title: "Update share",
                accessibilityIdentifier: KairoAccessibilityID.passportShareUpdate,
                action: { showsEdit = true }
            )
            .disabled(model.share.state != .active || !model.share.policyEditable)

            Button(role: .destructive) {
                showsRevokeConfirmation = true
            } label: {
                Text(model.isRevoking ? "Revoking…" : "Revoke share")
                    .font(KairoTypography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, KairoSpacing.medium)
            }
            .buttonStyle(KairoActionStyle(role: .destructiveSecondary))
            .disabled(model.share.state != .active || model.isRevoking)
            .accessibilityIdentifier(KairoAccessibilityID.passportShareRevoke)
            .accessibilityHint("Permanently prevents the public Passport link from resolving")
        }
    }

    private func metric(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text("\(value)")
                .font(KairoTypography.title)
                .foregroundStyle(KairoColors.textPrimary)
            Text(label)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private var expiryText: String {
        if let expiresAt = model.share.expiresAt {
            return "Expires \(expiresAt.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No expiry"
    }

    private var analyticsAccessibilityLabel: String {
        guard let analytics = model.analytics else { return "View summary unavailable" }
        let last = analytics.lastViewedAt.map {
            "Last viewed \($0.formatted(date: .abbreviated, time: .shortened))"
        } ?? "No recipient view reported yet"
        return "\(analytics.totalViews) total views, \(analytics.uniqueViews) unique views. \(last)"
    }

    private var statusColor: Color {
        switch model.share.state {
        case .active: KairoColors.success
        case .expired: KairoColors.warning
        case .revoked, .unknown: KairoColors.textSecondary
        }
    }
}

private struct PassportShareEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PassportShareDraft
    @State private var isSaving = false
    @State private var error: PassportSharePresentationError?

    let service: any PassportShareServiceProtocol
    let share: PassportShare
    let onUpdated: (PassportShare) -> Void

    init(
        service: any PassportShareServiceProtocol,
        share: PassportShare,
        onUpdated: @escaping (PassportShare) -> Void
    ) {
        self.service = service
        self.share = share
        self.onUpdated = onUpdated
        _draft = State(initialValue: PassportShareDraft(share: share))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    PassportShareMutationForm(draft: $draft)
                    KairoPrimaryButton(
                        title: isSaving ? "Saving…" : "Save changes",
                        isLoading: isSaving,
                        accessibilityIdentifier: KairoAccessibilityID.passportShareUpdateConfirm,
                        action: { Task { await save() } }
                    )
                    .disabled(isSaving || draft.validationMessage != nil)
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Update share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(isSaving)
                }
            }
        }
        .alert(item: $error) { error in
            Alert(title: Text(error.title), message: Text(error.message), dismissButton: .default(Text("OK")))
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        guard let input = draft.mutationInput(), !isSaving else {
            error = .init(title: "Check sharing choices", message: draft.validationMessage ?? "Choose a valid future expiry.")
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await service.updateShare(id: share.id, input: input)
            onUpdated(updated)
            dismiss()
        } catch {
            self.error = .map(error, fallbackTitle: "Share not updated")
        }
    }
}

private struct PassportShareQRCodeView: View {
    @Environment(\.dismiss) private var dismiss
    let publicURL: URL

    var body: some View {
        NavigationStack {
            VStack(spacing: KairoSpacing.large) {
                if let image = PassportShareQRCode.image(for: publicURL) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 300, maxHeight: 300)
                        .padding(KairoSpacing.medium)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium))
                        .accessibilityLabel("QR code for the public Passport URL")
                } else {
                    KairoErrorStateView(
                        title: "QR unavailable",
                        message: "KairoID could not render this public Passport URL as a QR code."
                    )
                }
                Text("Scan to open this public Passport. The QR contains only the same public URL shown after creation.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(KairoSpacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Passport QR code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

nonisolated enum PassportShareQRCode {
    static func image(for publicURL: URL) -> UIImage? {
        let payload = PassportShareQRPayload.publicURLString(from: publicURL)
        guard let data = payload.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct PassportSharePresentationError: Identifiable, Equatable {
    let title: String
    let message: String
    var id: String { title + "|" + message }

    static func map(_ error: Error, fallbackTitle: String) -> Self {
        if let serviceError = error as? PassportShareServiceError {
            return .init(title: fallbackTitle, message: serviceError.localizedDescription)
        }
        if let sessionError = error as? SessionServiceError {
            return .init(title: "Sign in required", message: sessionError.localizedDescription)
        }
        if let decodingError = error as? DecodingError {
            _ = decodingError
            return .init(
                title: "Response unavailable",
                message: "KairoID could not read the authoritative Passport share response. No local share state was created."
            )
        }
        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return map(apiError, fallbackTitle: fallbackTitle)
            case .transport(let message) where message.localizedCaseInsensitiveContains("timed out"):
                return .init(title: "Request timed out", message: "The server did not confirm the change. Refresh the share list before retrying.")
            case .transport:
                return .init(title: "Network unavailable", message: "KairoID could not reach Passport sharing. Check your connection and retry.")
            case .invalidResponse:
                return .init(title: "Invalid response", message: "The server did not return a usable Passport sharing response.")
            case .invalidURL:
                return .init(title: fallbackTitle, message: "KairoID could not construct the Passport sharing request URL.")
            case .unavailableInDemoMode:
                return .init(title: "Demo data unavailable", message: "Demo Mode cannot call staging Passport sharing services.")
            }
        }
        return .init(title: fallbackTitle, message: error.localizedDescription)
    }

    private static func map(_ error: APIError, fallbackTitle: String) -> Self {
        switch error.statusCode {
        case 400:
            return .init(title: "Share not accepted", message: error.message)
        case 401:
            return .init(title: "Sign in required", message: "Your session is no longer valid. Sign in and refresh before retrying.")
        case 403:
            return .init(title: "Share access denied", message: error.message)
        case 404:
            return .init(title: "Share not found", message: "This Passport share no longer exists or is not available to this account.")
        case 409:
            let lowercased = error.message.lowercased()
            if lowercased.contains("revoked") {
                return .init(title: "Share already revoked", message: error.message)
            }
            if lowercased.contains("expired") {
                return .init(title: "Share expired", message: error.message)
            }
            return .init(title: "Share changed", message: "The authoritative share state changed. Refresh before trying again. \(error.message)")
        case 410:
            return .init(title: "Share no longer available", message: "This public share is no longer available. Refresh the authoritative share list.")
        case 422:
            let details = error.fieldErrors
                .sorted { $0.key < $1.key }
                .flatMap { field, messages in messages.map { "\(field): \($0)" } }
                .joined(separator: " ")
            return .init(title: "Check sharing choices", message: details.isEmpty ? error.message : details)
        case 429:
            return .init(title: "Too many attempts", message: "Passport sharing is temporarily rate-limited. Wait and retry.")
        case 500...599:
            return .init(title: "Passport sharing unavailable", message: "The service could not complete this request. Refresh before retrying.")
        default:
            return .init(title: fallbackTitle, message: error.message)
        }
    }
}
