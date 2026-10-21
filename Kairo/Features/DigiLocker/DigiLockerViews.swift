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
        KairoCompactDestinationRow(title: "DigiLocker", metadata: metadata,
            systemImage: "checkmark.shield", accessibilityIdentifier: "candidate.home.digilocker",
            action: { router.showDigiLocker() })
        .accessibilityHint(actionTitle)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.home.digilocker.card")
    }

    private var actionTitle: String {
        if store.summaryError || store.isLoadingSummary { return "View DigiLocker" }
        if store.status?.status == .reconnectRequired { return "Reconnect DigiLocker" }
        return store.status?.connected == true ? "View details" : "Connect DigiLocker"
    }
    private var metadata: String {
        if store.isLoadingSummary && store.status == nil { return "Checking connection…" }
        if store.summaryError { return "DigiLocker status unavailable" }
        if store.status?.connected == true { return "\(store.verifiedDigiLockerSources.count) verified · \(store.attentionDigiLockerSources.count) needs review" }
        return store.status?.status.title ?? "Not connected"
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
    @Environment(\.appConfiguration) private var configuration
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var consent = DigiLockerConsent()
    @StateObject private var authentication = DigiLockerAuthenticationCoordinator()
    @State private var isFinishingReturn = false
    @State private var awaitingBrowserReturn = false
    @State private var connectionMotion = 0
    @State private var recoveryTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    header
                    connectionSection
                    ProductGuidanceView(topic: .digiLocker)
                    if DigiLockerReadQA.current(configuration: configuration) != nil {
                        Text("Staging authenticated read QA — writes and OAuth blocked")
                            .font(KairoTypography.caption)
                        Button("Open safe completion fixture") { connect() }
                            .accessibilityIdentifier("candidate.digilocker.readQA")
                    }
                    if DigiLockerReturnFixture.current(configuration: configuration) != nil {
                        Text("Synthetic DigiLocker return QA — writes blocked")
                            .font(KairoTypography.caption)
                            .accessibilityIdentifier("candidate.digilocker.fixture")
                    }
                    savedSection
                    availableSection
                    DigiLockerAadhaarView()
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
                recoveryTask?.cancel()
                let task = Task {
                    await recoverInterruptedVerification()
                    guard !Task.isCancelled else { return }
                    await store.refreshAll()
                }
                recoveryTask = task
                await task.value
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    recoveryTask?.cancel()
                    recoveryTask = nil
                    store.cancelAadhaarOperation()
                }
                if phase == .active && store.aadhaarNeedsReconciliation {
                    recoveryTask?.cancel()
                    recoveryTask = Task { await recoverInterruptedVerification() }
                }
                guard phase == .active, awaitingBrowserReturn else { return }
                awaitingBrowserReturn = false
                Task { await refresh() }
            }
            .onChange(of: sessionStore.currentUser?.id) { _, _ in
                recoveryTask?.cancel()
                recoveryTask = nil
                authentication.cancel()
                consent = DigiLockerConsent()
                store.cancelAadhaarOperation()
            }
            .onDisappear {
                recoveryTask?.cancel()
                recoveryTask = nil
                authentication.cancel()
                store.cancelAadhaarOperation()
            }
            .onChange(of: store.status?.connected) { previous, current in
                if previous == false && current == true && !store.summaryError { connectionMotion += 1 }
            }
        }
        .accessibilityIdentifier("candidate.digilocker.hub")
    }

    private func recoverInterruptedVerification() async {
        guard store.aadhaarNeedsReconciliation else { return }
        let revision = store.identityRevision
        await store.reconcileAadhaarSavedResults()
        guard !Task.isCancelled, revision == store.identityRevision,
              !store.aadhaarNeedsReconciliation, !store.summaryError else { return }
        refreshStore.candidateDataChanged()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            DigiLockerBrandView()
            HStack {
                KairoTrustSignature(kind: .connected, trigger: connectionMotion, size: 36)
                Text(store.status?.connected == true && !store.summaryError ? "DigiLocker connected" : "Connect your DigiLocker")
            }
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("candidate.digilocker.available")
    }

    private var connectionSection: some View {
        KairoSection {
            KairoSectionHeading(title: "Connection")
            if store.status != nil && store.status?.connected != true && store.status?.status != .pending && !store.summaryError {
                KairoPrimaryButton(
                    title: store.status?.status == .reconnectRequired ? "Reconnect DigiLocker" : "Connect DigiLocker",
                    isLoading: store.isConnecting || authentication.isActive || isFinishingReturn,
                    accessibilityIdentifier: "candidate.digilocker.connect",
                    action: connect
                )
                .disabled(store.isConnecting || authentication.isActive || isFinishingReturn || store.isLoadingSummary)
            }

            Text("Connecting does not verify your Career records. Choose supported identity documents and give consent separately. Manual uploads remain a separate source.")
                .font(KairoTypography.metadata)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if store.isConnecting || authentication.isActive || isFinishingReturn {
                ProgressView(isFinishingReturn ? "Checking connection and saved results…" : "Connecting securely…")
                    .accessibilityIdentifier("candidate.digilocker.connectionProgress")
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
            .disabled(store.isLoadingSummary || store.isLoadingInventory || store.actionInProgress || authentication.isActive || isFinishingReturn)

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
                    title: item.documentType == "EAADHAAR" ? (item.isVerified ? "Verified" : "Needs review") : DigiLockerPresentation.resultTitle(item.matchResult, current: item.current),
                    tone: item.isVerified ? .verified : .attention
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
            if document.supported, let type = DigiLockerDocumentType(rawValue: document.documentType), availableVerificationTypes.contains(type) {
                Toggle("Select \(type.title)", isOn: Binding(
                    get: { consent.selected.contains(type) },
                    set: { consent.select(type, enabled: $0) }))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("candidate.digilocker.select.\(type.rawValue)")
                    .accessibilityValue(consent.selected.contains(type) ? "Selected" : "Not selected")
                    .disabled(store.actionInProgress)
            }
        }
        .padding(.vertical, KairoSpacing.xSmall)
        .accessibilityElement(children: .contain)
    }

    private var verificationControls: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            Text(consent.selected.isEmpty ? "Select at least one document to give consent." : DigiLockerDocumentType.allCases.filter(consent.selected.contains).map(\.title).joined(separator: ", "))
                .font(KairoTypography.metadata).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("candidate.digilocker.selected")
            if !consent.selected.isEmpty {
                Text("Consent to verify")
                    .font(KairoTypography.headline).accessibilityAddTraits(.isHeader)
                Button {
                    consent.accepted.toggle()
                } label: {
                    HStack(alignment: .top, spacing: KairoSpacing.small) {
                        Image(systemName: consent.accepted ? "checkmark.square.fill" : "square")
                            .accessibilityHidden(true)
                        Text("I consent to KairoID retrieving the selected documents from DigiLocker for identity verification.")
                            .font(KairoTypography.metadata).fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(consent.selected.isEmpty || store.actionInProgress)
                .accessibilityLabel("Consent to verify. I consent to KairoID retrieving the selected documents from DigiLocker for identity verification.")
                .accessibilityValue(consent.accepted ? "Checked" : "Unchecked")
                .accessibilityHint("Required. Select at least one document and check consent to enable Verify.")
                .accessibilityIdentifier("candidate.digilocker.consent")
                Text("KairoID stores verification results, not the source files.")
                    .font(KairoTypography.caption).fixedSize(horizontal: false, vertical: true)
                Text(consent.canVerify ? "Verify checks the selected documents against your KairoID profile." : "Select at least one document and give consent to enable Verify.")
                    .font(KairoTypography.caption).fixedSize(horizontal: false, vertical: true)
            }
                KairoPrimaryButton(title: "Verify selected", isLoading: store.isVerifying,
                                   accessibilityIdentifier: "candidate.digilocker.verify") {
                    guard consent.canVerify else { return }
                    let selected = consent.selected
                    Task {
                        if await store.verify(selected) {
                            consent = DigiLockerConsent()
                            refreshStore.candidateDataChanged()
                        } else { consent.accepted = false }
                    }
                }
                .disabled(!consent.canVerify || store.actionInProgress)
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
        guard !authentication.isActive, !isFinishingReturn else { return }
        Task {
            if DigiLockerReturnParser.scheme(for: configuration.environment) != nil {
                let revision = store.identityRevision
                let fixture = DigiLockerReturnFixture.current(configuration: configuration)
                let readQA = DigiLockerReadQA.current(configuration: configuration)
                let result: DigiLockerReturnOutcome?
                if fixture == .invalid {
                    // Parser-only negative fixture; not evidence of system-browser handoff.
                    result = DigiLockerReturnParser.parse(URL(string: "com.kairoid.staging.digilocker://complete?unexpected=fixture")!, environment: configuration.environment)
                } else {
                    result = await authentication.connect(environment: configuration.environment, authorize: {
                        if let readQA { return readQA.completionURL }
                        if let fixture { return fixture.completionURL }
                        return await store.startConnection()
                    })
                }
                guard let outcome = result,
                      revision == store.identityRevision else { return }
                isFinishingReturn = true
                defer { isFinishingReturn = false }
                consent = DigiLockerConsent()
                if let readQA { await DigiLockerReadQAEvidence.shared.beginCallback(mode: readQA) }
                await store.finishAuthentication(outcome, revision: revision)
                if readQA != nil {
                    print("[DigiLockerReadQA] hub_return same_identity=\(revision == store.identityRevision) summary_error=\(store.summaryError) server_connected=\(store.status?.connected == true) saved_history_present=\(store.history != nil)")
                }
                if revision == store.identityRevision { refreshStore.candidateDataChanged() }
                return
            }
            // Other environments retain their existing browser behavior.
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
        guard !store.actionInProgress else { return }
        let revision = store.identityRevision
        recoveryTask?.cancel()
        let task = Task {
            if store.aadhaarNeedsReconciliation { await store.reconcileAadhaarSavedResults() }
            guard !Task.isCancelled, revision == store.identityRevision else { return }
            await store.refreshAll()
            guard !Task.isCancelled, revision == store.identityRevision else { return }
            refreshStore.candidateDataChanged()
        }
        recoveryTask = task
        await task.value
    }
}
