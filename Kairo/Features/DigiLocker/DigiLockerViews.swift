import SwiftUI

struct DigiLockerStatusChip: View {
    let state: DigiLockerConnectionState

    var body: some View {
        KairoStatusChip(title: state.title, tone: tone, systemImage: symbol)
            .accessibilityValue(state.title)
    }

    private var tone: KairoStatusTone {
        switch state {
        case .active: .verified
        case .pending: .pending
        case .reconnectRequired: .attention
        case .disconnected: .draft
        }
    }

    private var symbol: String {
        switch state {
        case .active: "checkmark.shield"
        case .pending: "clock"
        case .reconnectRequired: "arrow.clockwise.circle"
        case .disconnected: "link.badge.plus"
        }
    }
}

struct DigiLockerHomeCard: View {
    @EnvironmentObject private var store: DigiLockerStore
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        KairoSection(compact: true) {
            HStack(alignment: .center, spacing: KairoSpacing.small) {
                Label("DigiLocker", systemImage: "checkmark.shield")
                    .font(KairoTypography.sectionTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                Spacer(minLength: KairoSpacing.small)
                if let status = store.status, !store.summaryError {
                    DigiLockerStatusChip(state: status.status)
                }
            }

            if store.isLoadingSummary && store.status == nil {
                Text("Checking connection…")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            } else if store.summaryError {
                Text("DigiLocker status unavailable")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            } else if store.status?.connected == true {
                Text("\(store.verifiedDigiLockerSources.count) verified · \(store.attentionDigiLockerSources.count) needs review")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            } else {
                Text("Connect your records to build trust.")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            Button(actionTitle) { router.showDigiLocker() }
                .buttonStyle(KairoActionStyle())
                .frame(minHeight: 44)
                .accessibilityIdentifier("candidate.home.digilocker")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.home.digilocker.card")
    }

    private var actionTitle: String {
        if store.summaryError || store.isLoadingSummary { return "View DigiLocker" }
        if store.status?.status == .reconnectRequired { return "Reconnect DigiLocker" }
        return store.status?.connected == true ? "View details" : "Connect DigiLocker"
    }
}

struct DigiLockerMoreRow: View {
    @EnvironmentObject private var store: DigiLockerStore
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        KairoCompactDestinationRow(
            title: "DigiLocker",
            metadata: metadata,
            systemImage: "checkmark.shield",
            accessibilityIdentifier: "candidate.more.digilocker",
            action: { router.showDigiLocker() }
        )
        .accessibilityValue(metadata)
    }

    private var metadata: String {
        if store.isLoadingSummary && store.status == nil { return "Checking connection"
        }
        if store.summaryError { return "Status unavailable" }
        return store.status?.status.title ?? "Not connected"
    }
}

struct DigiLockerVerifySections: View {
    @EnvironmentObject private var store: DigiLockerStore
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            if store.status?.status == .pending {
                KairoSection(compact: true) {
                    KairoSectionHeading(title: "In progress", count: 1)
                    sourceRow(title: "DigiLocker", status: "Connection pending", tone: .pending, detail: "Complete the secure connection in your browser.")
                }
            }
            if !store.attentionDigiLockerSources.isEmpty {
                KairoSection(compact: true) {
                    KairoSectionHeading(title: "Needs attention", count: store.attentionDigiLockerSources.count)
                    ForEach(store.attentionDigiLockerSources) { source in
                        sourceRow(
                            title: DigiLockerPresentation.documentTitle(source.documentType),
                            status: DigiLockerPresentation.resultTitle(source.matchResult, current: source.current),
                            tone: .attention,
                            detail: DigiLockerPresentation.safeReason(source.reason)
                        )
                    }
                }
            }
            if store.identityIsVerified {
                KairoSection(compact: true) {
                    KairoSectionHeading(title: "Completed", count: 1)
                    sourceRow(
                        title: "Identity",
                        status: "Verified",
                        tone: .verified,
                        detail: store.identityVerifiedViaDigiLocker ? "Verified via DigiLocker" : "Verified via KairoID"
                    )
                }
            }
        }
    }

    private func sourceRow(title: String, status: String, tone: KairoStatusTone, detail: String) -> some View {
        Button { router.showDigiLocker() } label: {
            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                HStack(alignment: .center, spacing: KairoSpacing.small) {
                    Text(title)
                        .font(KairoTypography.recordTitle)
                        .foregroundStyle(KairoColors.textPrimary)
                    Spacer(minLength: KairoSpacing.small)
                    KairoStatusChip(title: status, tone: tone)
                }
                Text(detail)
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

struct DigiLockerIdentitySummary: View {
    @EnvironmentObject private var store: DigiLockerStore

    var body: some View {
        KairoSection {
            HStack(alignment: .center, spacing: KairoSpacing.small) {
                Text("Identity")
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.textPrimary)
                Spacer(minLength: KairoSpacing.small)
                KairoStatusChip(
                    title: store.identityIsVerified ? "Verified" : "Not currently verified",
                    tone: store.identityIsVerified ? .verified : .draft
                )
            }
            if store.identityVerifiedViaDigiLocker {
                Text("Source: DigiLocker")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("candidate.identity.provenance")
    }
}

struct DigiLockerTrustScoreProvenance: View {
    let state: DigiLockerIdentityState
    let sources: [DigiLockerTrustSourceDTO]

    var body: some View {
        KairoCard {
            HStack {
                Text("Identity")
                    .font(KairoTypography.bodyStrong)
                    .foregroundStyle(KairoColors.textPrimary)
                Spacer()
                KairoStatusChip(title: state == .verified ? "Verified" : "Not currently verified",
                                tone: state == .verified ? .verified : .draft)
            }
            if sources.contains(where: { $0.source == .digilocker && $0.current }) {
                Text("Verified via DigiLocker")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
            }
            Text("Identity sources explain the backend result; they do not create extra score categories or duplicate contributions.")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.trustScore.identityProvenance")
    }
}

struct DigiLockerHubView: View {
    @EnvironmentObject private var store: DigiLockerStore
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var selected = Set<DigiLockerDocumentType>()
    @State private var consent = false
    @State private var awaitingBrowserReturn = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    header
                    savedSection
                    availableSection
                    connectionSection
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("DigiLocker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .refreshable { await refresh() }
            .task {
                await store.refreshAll()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active, awaitingBrowserReturn else { return }
                awaitingBrowserReturn = false
                Task { await refresh() }
            }
        }
        .accessibilityIdentifier("candidate.digilocker.hub")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            Label("Secure connection for verified records", systemImage: "checkmark.shield")
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
            if store.isLoadingSummary && store.status == nil {
                ProgressView("Checking connection…")
            } else if let status = store.status, !store.summaryError {
                DigiLockerStatusChip(state: status.status)
            } else {
                Text("Connection status unavailable")
                    .font(KairoTypography.metadata)
                    .foregroundStyle(KairoColors.textSecondary)
                    .accessibilityLabel("DigiLocker connection status unavailable")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var savedSection: some View {
        KairoSection {
            KairoSectionHeading(title: "Verified through DigiLocker", count: store.history?.items.count)
            if store.isLoadingSummary && store.history == nil {
                ProgressView("Loading saved verification results…")
            } else if store.summaryError && store.history == nil {
                failureCopy("Verification results unavailable. Refresh to try again.")
            } else if let items = store.history?.items, !items.isEmpty {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider() }
                    verificationRow(item)
                }
            } else {
                KairoEmptyStateView(title: "No saved verifications", message: "No saved DigiLocker verifications yet.", systemImage: "shield")
            }
        }
        .accessibilityIdentifier("candidate.digilocker.verified")
    }

    @ViewBuilder
    private var availableSection: some View {
        KairoSection {
            KairoSectionHeading(title: "Available in DigiLocker", count: store.status?.connected == true ? store.issuedDocuments.count : nil)
            if store.status?.status == .reconnectRequired {
                Text("Reconnect DigiLocker to refresh available documents.")
                    .font(KairoTypography.metadata).foregroundStyle(KairoColors.textSecondary)
            } else if store.status?.connected != true {
                Text("Connect to see your available documents.")
                    .font(KairoTypography.metadata).foregroundStyle(KairoColors.textSecondary)
            } else if store.isLoadingInventory {
                ProgressView("Loading available documents…")
            } else if store.inventoryError {
                failureCopy("Available documents could not be loaded. Refresh to try again.")
            } else if store.issuedDocuments.isEmpty {
                KairoEmptyStateView(title: "No documents available", message: "DigiLocker did not return available documents.", systemImage: "doc")
            } else {
                Text("Available documents and their saved KairoID status.")
                    .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                ForEach(Array(store.issuedDocuments.enumerated()), id: \.element.id) { index, document in
                    if index > 0 { Divider() }
                    availableRow(document)
                }
                verificationControls
            }
        }
        .accessibilityIdentifier("candidate.digilocker.available")
    }

    private var connectionSection: some View {
        KairoSection {
            KairoSectionHeading(title: "Connection")
            Text("Your credentials stay with DigiLocker. KairoID displays privacy-safe verification results, not source files or identifiers.")
                .font(KairoTypography.metadata)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.status?.connected != true && store.status?.status != .pending && !store.summaryError {
                KairoPrimaryButton(
                    title: store.status?.status == .reconnectRequired ? "Reconnect DigiLocker" : "Connect DigiLocker",
                    isLoading: store.isConnecting,
                    accessibilityIdentifier: "candidate.digilocker.connect",
                    action: connect
                )
                .disabled(store.isConnecting)
            }

            if awaitingBrowserReturn || store.status?.status == .pending {
                Text("Complete sign-in in the secure browser, then return to KairoID. Status and saved results refresh when the app becomes active.")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            KairoSecondaryButton(title: "Refresh status and results") {
                Task { await refresh() }
            }
            .disabled(store.isLoadingSummary || store.isLoadingInventory)

            if let error = store.actionErrorMessage {
                Text(error)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("DigiLocker action failed. \(error)")
            }
        }
    }

    private func verificationRow(_ item: DigiLockerVerificationDTO) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            HStack {
                Text(DigiLockerPresentation.documentTitle(item.documentType))
                    .font(KairoTypography.recordTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                Spacer(minLength: KairoSpacing.small)
                KairoStatusChip(
                    title: DigiLockerPresentation.resultTitle(item.matchResult, current: item.current),
                    tone: item.current ? .verified : .attention
                )
            }
            if item.current, let verifiedAt = item.verifiedAt {
                Text("Verified \(verifiedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
            } else if !item.current {
                Text(DigiLockerPresentation.safeReason(item.matchReason))
                    .font(KairoTypography.metadata).foregroundStyle(KairoColors.textSecondary)
            }
        }
        .padding(.vertical, KairoSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private func availableRow(_ document: DigiLockerIssuedDocumentDTO) -> some View {
        let source = store.trust?.sources.first { $0.source == .digilocker && $0.documentType == document.documentType && $0.current }
            ?? store.trust?.sources.first { $0.source == .digilocker && $0.documentType == document.documentType }
        return VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            HStack {
                Text(DigiLockerPresentation.documentTitle(document.documentType))
                    .font(KairoTypography.recordTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                Spacer(minLength: KairoSpacing.small)
                if let source {
                    KairoStatusChip(
                        title: DigiLockerPresentation.resultTitle(source.matchResult, current: source.current),
                        tone: source.current ? .verified : .attention
                    )
                } else {
                    KairoStatusChip(title: "Available", tone: .draft, systemImage: "doc")
                }
            }
            if !document.supported {
                Text("Verification is not yet available for this document.")
                    .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
            }
        }
        .padding(.vertical, KairoSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }

    private var verificationControls: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            Text("Choose identity documents to verify")
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
            ForEach(availableVerificationTypes, id: \.self) { type in
                Toggle(type.title, isOn: Binding(
                    get: { selected.contains(type) },
                    set: { enabled in
                        if enabled { selected.insert(type) } else { selected.remove(type) }
                        consent = false
                    }
                ))
                .frame(minHeight: 44)
            }
            Toggle(isOn: $consent) {
                Text("I consent to KairoID retrieving the selected identity documents from DigiLocker for identity verification.")
                    .font(KairoTypography.metadata)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(selected.isEmpty)
            .frame(minHeight: 44)
            KairoPrimaryButton(title: "Verify selected documents", isLoading: store.isVerifying) {
                Task {
                    if await store.verify(selected) {
                        selected.removeAll()
                        consent = false
                        refreshStore.candidateDataChanged()
                    }
                }
            }
            .disabled(selected.isEmpty || !consent || store.isVerifying)
        }
        .padding(.top, KairoSpacing.small)
    }

    private var availableVerificationTypes: [DigiLockerDocumentType] {
        DigiLockerDocumentType.allCases.filter { type in
            store.issuedDocuments.contains { $0.documentType == type.rawValue && $0.supported }
        }
    }

    private func failureCopy(_ message: String) -> some View {
        Text(message)
            .font(KairoTypography.metadata)
            .foregroundStyle(KairoColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("DigiLocker unavailable. \(message)")
    }

    private func connect() {
        Task {
            guard let url = await store.startConnection() else { return }
            awaitingBrowserReturn = true
            openURL(url) { accepted in
                if !accepted {
                    awaitingBrowserReturn = false
                    store.markBrowserOpenFailed()
                }
            }
        }
    }

    private func refresh() async {
        await store.refreshAll()
        refreshStore.candidateDataChanged()
    }
}
