import SwiftUI

struct PassportOverviewScreenView: View {
    let state: PassportOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.passportShareService) private var passportShareService
    @Environment(\.passportPDFExportService) private var passportPDFExportService
    @State private var modalDestination: PassportModalDestination?
    @StateObject private var pdfExportModel = PassportPDFExportViewModel()
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize = 40.0

    var body: some View {
        screenContent
            .refreshableIfAvailable(action: refreshAction)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(KairoAccessibilityID.passportScreen)
            .sheet(item: $modalDestination) { destination in
                switch destination {
                case .sharePassport:
                    PassportShareManagementSheet(
                        service: passportShareService,
                        onMutation: { refreshStore.passportSharesChanged() }
                    )
                case .shareActivity:
                    PassportShareActivitySheet(
                        service: passportShareService,
                        onMutation: { refreshStore.passportSharesChanged() }
                    )
                }
            }
            .sheet(item: $pdfExportModel.artifact, onDismiss: {
                Task {
                    await pdfExportModel.cleanupDismissedPreview(using: passportPDFExportService)
                }
            }) { artifact in
                PassportPDFPreviewView(
                    artifact: artifact,
                    onRetry: { pdfExportModel.retryAfterPreviewDismissal() }
                )
            }
            .onAppear { openRequestedActivityIfNeeded() }
            .onChange(of: router.passportActivityRequestID) { _, _ in
                openRequestedActivityIfNeeded()
            }
            .onDisappear {
                Task {
                    await pdfExportModel.endLifecycle(using: passportPDFExportService)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .background, pdfExportModel.artifact == nil else { return }
                Task {
                    await pdfExportModel.endLifecycle(using: passportPDFExportService)
                }
            }
    }

    @ViewBuilder
    private var screenContent: some View {
        switch state.phase {
        case .empty(let content):
            emptyStateScreen(content)
        case .loading, .error, .populated:
            standardScreen
        }
    }

    private var standardScreen: some View {
        KairoScreenContainer(
            title: "Trust Passport",
            subtitle: "Your portable professional identity.",
            titleAccessibilityIdentifier: CandidateTab.passport.titleAccessibilityIdentifier
        ) {
            passportHeader
            content
        }
    }

    private func emptyStateScreen(_ content: PassportOverviewEmptyContent) -> some View {
        KairoScreenContainer(
            title: "Trust Passport",
            subtitle: "Your portable professional identity.",
            titleAccessibilityIdentifier: CandidateTab.passport.titleAccessibilityIdentifier
        ) {
            passportHeader
            emptyStateBody(content)
        }
        .safeAreaInset(edge: .bottom, spacing: KairoSpacing.small) {
            emptyStateActions
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.top, KairoSpacing.small)
                .padding(.bottom, KairoSpacing.medium)
                .background(KairoColors.background.opacity(0.96))
        }
    }

    private var passportHeader: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                profilePlaceholder
                headerCopy
            }
            passportHeroStatus
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passportHeader)
    }

    private var passportHeroStatus: some View {
        Label(state.header.status.style.title, systemImage: state.header.status.style.symbol)
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.textPrimary)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(KairoColors.surfaceMuted, in: Capsule())
            .overlay(Capsule().stroke(KairoColors.border, lineWidth: 1))
    }

    private var passportHeroSummary: some View {
        VStack(alignment: .trailing, spacing: KairoSpacing.xSmall) {
            Text(heroTrustScoreValue)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(KairoColors.textPrimary)

            Text("Trust Score")
                .font(KairoTypography.sectionEyebrow)
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.58))

            passportHeroStatus
        }
        .padding(.horizontal, KairoSpacing.small)
        .padding(.vertical, KairoSpacing.xSmall)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
    }

    private var heroTrustScoreValue: String {
        guard case .populated(let content) = state.phase,
              case .available(let trustScore) = content.trustScore else {
            return "--"
        }

        return String(trustScore.value)
    }

    @ViewBuilder
    private var profilePlaceholder: some View {
        if let avatarURL = state.header.avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    profileMonogram
                }
            }
            .frame(width: 68, height: 68)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(KairoColors.border, lineWidth: 1)
            )
            .accessibilityElement()
            .accessibilityLabel("Profile image for \(state.header.name)")
        } else {
            profileMonogram
                .accessibilityElement()
                .accessibilityLabel("Profile placeholder for \(state.header.name)")
        }
    }

    private var profileMonogram: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                .fill(KairoColors.surfaceMuted)

            Text(state.header.initials)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
        }
        .frame(width: 68, height: 68)
        .overlay(
            RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                .stroke(KairoColors.border, lineWidth: 1)
        )
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text("Passport owner")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)

            Text(state.header.name)
                .font(KairoTypography.title)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(state.header.professionalHeadline)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Label(state.header.location, systemImage: "location")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your Trust Passport",
                message: "KairoID is assembling your portable professional trust preview."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message,
                retryAction: retryAction
            )
        case .empty:
            EmptyView()
        case .populated(let content):
            populatedContent(content)
        }
    }

    private func populatedContent(_ content: PassportOverviewContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            trustScoreCard(content.trustScore, dataSourceLabel: content.dataSourceLabel)
            KairoPrimaryButton(
                title: "Share",
                accessibilityIdentifier: KairoAccessibilityID.passportShareAction,
                action: { modalDestination = .sharePassport }
            )
            disclosureSummary(content, verified: true)
            disclosureSummary(content, verified: false)
            employmentSection(content.employment)
            educationSection(content.education)
            certificationsSection(content.certifications)
            skillsSection(content.skills)
            projectsSection(content.projects)
            strengthSummarySection(content.strengthSummary)
            identitySection(content.identity)
            if case .available = content.timeline {
                trustTimelineSection(content.timeline)
            }
            actionsSection
        }
    }

    private func disclosureSummary(_ content: PassportOverviewContent, verified: Bool) -> some View {
        let counts = PassportHierarchyCounts(content: content)
        return KairoSection {
            PassportSectionTitle(
                title: verified ? "Verified" : "Candidate-provided",
                accessibilityIdentifier: verified ? "passport.summary.verified" : "passport.summary.candidateProvided"
            )
            Text(verified ? "\(counts.verified) verified career records" : "\(counts.candidateProvided) career records not verified")
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textPrimary)
            Text(verified
                 ? "Only records marked Verified by KairoID are counted here."
                 : "Useful information you supplied. Pending and unavailable statuses remain shown on each record; sharing does not verify them.")
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func emptyStateBody(_ content: PassportOverviewEmptyContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoEmptyStateView(
                title: content.title,
                message: content.message,
                systemImage: "person.text.rectangle"
            )
            .accessibilityIdentifier(KairoAccessibilityID.passportEmptyState)

            PassportDataSourceBadge(title: content.dataSourceLabel)
        }
    }

    private var emptyStateActions: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            KairoPrimaryButton(
                title: "Continue profile",
                accessibilityIdentifier: KairoAccessibilityID.passportContinueProfile,
                action: { router.selectTab(.career) }
            )

            KairoSecondaryButton(
                title: "Start verification",
                accessibilityIdentifier: KairoAccessibilityID.passportStartVerification,
                action: { router.selectTab(.verify) }
            )
        }
    }

    private func trustScoreCard(_ trustScoreContent: PassportTrustScoreContent, dataSourceLabel: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Label("Trust Score", systemImage: "shield")
                    .font(KairoTypography.caption)
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: KairoSpacing.small)
                Text(dataSourceLabel)
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.accent)
            }
            switch trustScoreContent {
            case .available(let score):
                HStack(alignment: .firstTextBaseline, spacing: KairoSpacing.xxSmall) {
                    Text(String(score.value))
                        .font(.system(size: scoreSize, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                    Text("/ 100")
                        .font(KairoTypography.recordTitle)
                        .foregroundStyle(.white.opacity(0.65))
                }
                Text(score.status)
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.accent)
                ProgressView(value: score.progress)
                    .tint(KairoColors.accent)
                Text(score.supportingCopy)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                if score.isFixture {
                    Text("Fixture/demo score")
                        .font(KairoTypography.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
            case .unavailable(let unavailable):
                Text("No score yet")
                    .font(KairoTypography.title)
                    .foregroundStyle(.white)
                Text(unavailable.title)
                    .font(KairoTypography.headline)
                    .foregroundStyle(KairoColors.accent)
                Text(unavailable.message)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button { router.showTrustScoreDetails() } label: {
                Text("View score details")
                    .font(KairoTypography.action)
                    .foregroundStyle(.white)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .modifier(KairoTrustSurface())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passportTrustScoreCard)
    }

    private func strengthSummarySection(_ items: [PassportStrengthItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            PassportSectionTitle(
                title: "Completeness & trust signals",
                accessibilityIdentifier: KairoAccessibilityID.passportStrengthSummary
            )

            KairoSection {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                    }

                    HStack(alignment: .center, spacing: KairoSpacing.medium) {
                        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                            Text(item.title)
                                .font(KairoTypography.bodyStrong)
                                .foregroundStyle(KairoColors.textPrimary)

                            Text(item.value)
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                        }

                        Spacer(minLength: KairoSpacing.small)

                        PassportBadge(status: item.status)
                    }
                    .padding(.vertical, KairoSpacing.xxSmall)
                }
            }
        }
    }

    private func identitySection(_ identity: PassportIdentityDetails) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            PassportSectionTitle(
                title: "Identity",
                accessibilityIdentifier: KairoAccessibilityID.passportIdentitySection
            )

            KairoSection {
                identityRow(title: "Full name", value: identity.fullName)
                identityRow(title: "Email", value: identity.emailAddress)
                identityRow(title: "Mobile", value: identity.mobileNumber)
                identityRow(title: "Identity status", value: identity.status.style.title)
                identityRow(title: "Last verified", value: identity.lastVerifiedDate)
            }
        }
    }

    private func identityRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.medium) {
            Text(title)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func employmentSection(_ items: [PassportEmploymentRecord]) -> some View {
        passportRecordSection(
            title: "Employment (\(items.count))",
            accessibilityIdentifier: KairoAccessibilityID.passportEmploymentSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No employment in your Trust Passport yet.")
            } else {
                ForEach(items) { item in
                    PassportRecordCard {
                        passportRecordHeader(
                            title: item.company,
                            subtitle: item.role,
                            status: item.verificationStatus
                        )

                        passportRecordMeta(title: "Dates", value: item.dateRange)
                        if !item.evidenceSummary.isEmpty {
                            passportRecordMeta(title: "Supporting evidence", value: item.evidenceSummary)
                        }
                    }
                }
            }
        }
    }

    private func educationSection(_ items: [PassportEducationRecord]) -> some View {
        passportRecordSection(
            title: "Education (\(items.count))",
            accessibilityIdentifier: KairoAccessibilityID.passportEducationSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No education in your Trust Passport yet.")
            } else {
                ForEach(items) { item in
                    PassportRecordCard {
                        passportRecordHeader(
                            title: item.institution,
                            subtitle: item.qualification,
                            status: item.verificationStatus
                        )

                        passportRecordMeta(title: "Dates", value: item.dateRange)
                        if !item.evidenceSummary.isEmpty {
                            passportRecordMeta(title: "Details", value: item.evidenceSummary)
                        }
                    }
                }
            }
        }
    }

    private func certificationsSection(_ items: [PassportCertificationRecord]) -> some View {
        passportRecordSection(
            title: "Certifications (\(items.count))",
            accessibilityIdentifier: KairoAccessibilityID.passportCertificationsSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No certifications in your Trust Passport yet.")
            } else {
                ForEach(items) { item in
                    PassportRecordCard {
                        passportRecordHeader(
                            title: item.title,
                            subtitle: item.issuer,
                            status: item.verificationStatus
                        )

                        passportRecordMeta(title: "Issue date", value: item.issueDate)
                        if !item.evidenceSummary.isEmpty {
                            passportRecordMeta(title: "Credential", value: item.evidenceSummary)
                        }
                    }
                }
            }
        }
    }

    private func projectsSection(_ items: [PassportProjectRecord]) -> some View {
        passportRecordSection(
            title: "Projects (\(items.count))",
            accessibilityIdentifier: KairoAccessibilityID.passportProjectsSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No projects in your Trust Passport yet.")
            } else {
                ForEach(items) { item in
                    PassportRecordCard {
                        Text(item.title)
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        PassportBadge(status: .notVerified)
                        passportRecordMeta(title: "Role", value: item.role)
                        passportRecordMeta(title: "Date", value: item.date)
                        if !item.evidenceStatus.isEmpty {
                            passportRecordMeta(title: "Project details", value: item.evidenceStatus)
                        }
                        if !item.portfolioLinkTitle.isEmpty {
                            passportRecordMeta(title: "Project link", value: item.portfolioLinkTitle)
                        }
                    }
                }
            }
        }
    }

    private func skillsSection(_ items: [PassportSkillRecord]) -> some View {
        passportRecordSection(
            title: "Skills (\(items.count))",
            accessibilityIdentifier: KairoAccessibilityID.passportSkillsSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No skills in your Trust Passport yet.")
            } else {
                PassportRecordCard {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .center, spacing: KairoSpacing.medium) {
                            Text(item.name)
                                .font(KairoTypography.bodyStrong)
                                .foregroundStyle(KairoColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            PassportBadge(status: item.verificationStatus)
                        }
                        if index < items.count - 1 { Divider() }
                    }
                }
            }
        }
    }

    private func trustTimelineSection(_ timeline: PassportTimelineContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            PassportSectionTitle(
                title: "Trust timeline",
                accessibilityIdentifier: KairoAccessibilityID.passportTimelineSection
            )

            switch timeline {
            case .available(let items):
                KairoSection {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .top, spacing: KairoSpacing.medium) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(KairoColors.accent)
                                    .frame(width: 8, height: 8)

                                if index < items.count - 1 {
                                    Rectangle()
                                        .fill(KairoColors.border)
                                        .frame(width: 1)
                                        .padding(.vertical, KairoSpacing.xxSmall)
                                }
                            }
                            .frame(width: 12, alignment: .top)

                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(item.title)
                                    .font(KairoTypography.bodyStrong)
                                    .foregroundStyle(KairoColors.textPrimary)

                                Text(item.dateLabel)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.textSecondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            case .unavailable(let unavailableState):
                KairoSection {
                    Text(unavailableState.title)
                        .font(KairoTypography.bodyStrong)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text(unavailableState.message)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text("Export & activity")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            if pdfExportModel.isDownloading {
                KairoLoadingStateView(
                    title: "Downloading Passport PDF",
                    message: "KairoID is preparing a fresh, private export for this preview."
                )
                .accessibilityIdentifier(KairoAccessibilityID.passportPDFLoading)
            } else {
                KairoSecondaryButton(
                    title: "Download PDF",
                    accessibilityIdentifier: KairoAccessibilityID.passportDownloadAction,
                    action: { pdfExportModel.startExport(using: passportPDFExportService) }
                )
            }

            if let error = pdfExportModel.error {
                VStack(alignment: .leading, spacing: KairoSpacing.small) {
                    KairoErrorStateView(
                        title: error.title,
                        message: error.message,
                        messageAccessibilityIdentifier: KairoAccessibilityID.passportPDFError
                    )

                    KairoSecondaryButton(
                        title: "Retry PDF download",
                        accessibilityIdentifier: KairoAccessibilityID.passportPDFRetry,
                        action: { pdfExportModel.retry(using: passportPDFExportService) }
                    )
                }
            }
            KairoSecondaryButton(
                title: "Views & Share Activity",
                accessibilityIdentifier: KairoAccessibilityID.passportShareActivityEntry,
                action: { modalDestination = .shareActivity }
            )
        }
    }

    private func openRequestedActivityIfNeeded() {
        guard router.passportActivityRequestID != nil else { return }
        modalDestination = .shareActivity
        router.consumePassportActivityRequest()
    }

    private func passportRecordSection<Content: View>(
        title: String,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        KairoSection {
            PassportSectionTitle(
                title: title,
                accessibilityIdentifier: accessibilityIdentifier
            )

            content()
        }
    }

    private func passportRecordHeader(
        title: String,
        subtitle: String,
        status: PassportVerificationStatus
    ) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            HStack(alignment: .top, spacing: KairoSpacing.small) {
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(title)
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: KairoSpacing.small)
                PassportBadge(status: status)
            }
        }
    }

    private func passportRecordMeta(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title)
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .textCase(.uppercase)

            Text(value)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func emptySectionCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private extension View {
    @ViewBuilder
    func refreshableIfAvailable(action: (() async -> Void)?) -> some View {
        if let action {
            refreshable {
                await action()
            }
        } else {
            self
        }
    }
}

private struct PassportSectionTitle: View {
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        Text(title)
            .font(KairoTypography.sectionTitle)
            .foregroundStyle(KairoColors.textPrimary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct PassportRecordCard<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            content
        }
        .padding(.vertical, KairoSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) { Rectangle().fill(KairoColors.border).frame(height: 1) }
    }
}

private struct PassportBadge: View {
    let status: PassportVerificationStatus

    private var tone: KairoStatusTone {
        switch status.style.tone {
        case .verified: .verified
        case .pending: .pending
        case .neutral: .draft
        case .accent: .candidateProvided
        }
    }

    var body: some View {
        KairoStatusChip(title: status.style.title, tone: tone, systemImage: status.style.symbol)
    }
}

private struct PassportDataSourceBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(KairoTypography.caption)
            .foregroundStyle(KairoColors.textSecondary)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(
                Capsule()
                    .fill(KairoColors.surfaceMuted.opacity(0.9))
            )
            .overlay(
                Capsule()
                    .stroke(KairoColors.border, lineWidth: 1)
            )
    }
}

private struct PassportInlineButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.brandPrimary)
        }
        .buttonStyle(.plain)
    }
}

private enum PassportModalDestination: Identifiable {
    case sharePassport
    case shareActivity

    var id: String {
        switch self {
        case .sharePassport:
            "passport.share"
        case .shareActivity:
            "passport.shareActivity"
        }
    }
}
