import SwiftUI

struct PassportOverviewScreenView: View {
    let state: PassportOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?

    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @Environment(\.passportShareService) private var passportShareService
    @State private var modalDestination: PassportModalDestination?

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
                default:
                    PassportPlaceholderSheet(destination: destination)
                }
            }
            .onAppear { openRequestedActivityIfNeeded() }
            .onChange(of: router.passportActivityRequestID) { _, _ in
                openRequestedActivityIfNeeded()
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
            title: "Passport",
            subtitle: "Your verified professional identity, ready to grow and travel with your career.",
            titleAccessibilityIdentifier: CandidateTab.passport.titleAccessibilityIdentifier
        ) {
            passportHeader
            content
        }
    }

    private func emptyStateScreen(_ content: PassportOverviewEmptyContent) -> some View {
        KairoScreenContainer(
            title: "Passport",
            subtitle: "Your verified professional identity, ready to grow and travel with your career.",
            titleAccessibilityIdentifier: CandidateTab.passport.titleAccessibilityIdentifier
        ) {
            passportHeader
            emptyStateBody(content)
        }
        .safeAreaInset(edge: .bottom, spacing: KairoSpacing.small) {
            emptyStateActions
                .padding(.horizontal, KairoSpacing.large)
                .padding(.top, KairoSpacing.small)
                .padding(.bottom, KairoSpacing.medium)
                .background(KairoColors.background.opacity(0.96))
        }
    }

    private var passportHeader: some View {
        KairoCard {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: KairoSpacing.medium) {
                    profilePlaceholder
                    headerCopy
                    Spacer(minLength: KairoSpacing.small)
                    PassportBadge(status: state.header.status)
                }

                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    HStack(alignment: .center, spacing: KairoSpacing.medium) {
                        profilePlaceholder
                        headerCopy
                    }

                    PassportBadge(status: state.header.status)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passportHeader)
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
            Circle()
                .fill(KairoColors.surfaceMuted)

            Text(state.header.initials)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
        }
        .frame(width: 68, height: 68)
        .overlay(
            Circle()
                .stroke(KairoColors.border, lineWidth: 1)
        )
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(state.header.identityTreatment.uppercased())
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
                message: "Kairo is assembling your portable professional trust preview."
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
        VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
            trustScoreCard(content.trustScore, dataSourceLabel: content.dataSourceLabel)
            strengthSummarySection(content.strengthSummary)
            identitySection(content.identity)
            employmentSection(content.employment)
            educationSection(content.education)
            certificationsSection(content.certifications)
            projectsSection(content.projects)
            trustTimelineSection(content.timeline)
            actionsSection
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
        KairoCard {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                HStack(alignment: .center, spacing: KairoSpacing.small) {
                    Text("Trust Score")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)

                    Spacer(minLength: KairoSpacing.small)

                    PassportDataSourceBadge(title: dataSourceLabel)
                }

                switch trustScoreContent {
                case .available(let trustScore):
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: KairoSpacing.large) {
                            trustScoreValue(trustScore)
                            trustScoreNarrative(trustScore.supportingCopy)
                        }

                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            trustScoreValue(trustScore)
                            trustScoreNarrative(trustScore.supportingCopy)
                        }
                    }

                    ProgressView(value: trustScore.progress)
                        .tint(KairoColors.brandPrimary)
                        .progressViewStyle(.linear)

                    if trustScore.isFixture {
                        Text("Fixture/demo score")
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                case .unavailable(let unavailableState):
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: KairoSpacing.large) {
                            trustScoreUnavailableValue(unavailableState)
                            trustScoreNarrative(unavailableState.message)
                        }

                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            trustScoreUnavailableValue(unavailableState)
                            trustScoreNarrative(unavailableState.message)
                        }
                    }
                }

                PassportInlineButton(
                    title: "View score details",
                    action: { modalDestination = .scoreDetails }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.passportTrustScoreCard)
    }

    private func trustScoreValue(_ trustScore: PassportTrustScore) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text("\(trustScore.value)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(KairoColors.textPrimary)
                .minimumScaleFactor(0.7)

            Text(trustScore.status)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trustScoreUnavailableValue(_ unavailableState: PassportTrustScoreUnavailableState) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text("No score yet")
                .font(KairoTypography.title)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(unavailableState.title)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.accent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trustScoreNarrative(_ supportingCopy: String) -> some View {
        Text(supportingCopy)
            .font(KairoTypography.body)
            .foregroundStyle(KairoColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func strengthSummarySection(_ items: [PassportStrengthItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            PassportSectionTitle(
                title: "Passport strength",
                accessibilityIdentifier: KairoAccessibilityID.passportStrengthSummary
            )

            KairoCard {
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

            KairoCard {
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
            title: "Employment",
            accessibilityIdentifier: KairoAccessibilityID.passportEmploymentSection
        ) {
            ForEach(items) { item in
                KairoCard {
                    passportRecordHeader(
                        title: item.company,
                        subtitle: item.role,
                        status: item.verificationStatus
                    )

                    passportRecordMeta(title: "Dates", value: item.dateRange)
                    passportRecordMeta(title: "Evidence", value: item.evidenceSummary)

                    PassportInlineButton(
                        title: "View details",
                        action: { modalDestination = .employmentDetails(item.company) }
                    )
                }
            }
        }
    }

    private func educationSection(_ items: [PassportEducationRecord]) -> some View {
        passportRecordSection(
            title: "Education",
            accessibilityIdentifier: KairoAccessibilityID.passportEducationSection
        ) {
            ForEach(items) { item in
                KairoCard {
                    passportRecordHeader(
                        title: item.institution,
                        subtitle: item.qualification,
                        status: item.verificationStatus
                    )

                    passportRecordMeta(title: "Dates", value: item.dateRange)
                    passportRecordMeta(title: "Evidence", value: item.evidenceSummary)
                }
            }
        }
    }

    private func certificationsSection(_ items: [PassportCertificationRecord]) -> some View {
        passportRecordSection(
            title: "Certifications",
            accessibilityIdentifier: KairoAccessibilityID.passportCertificationsSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No certifications in your Trust Passport yet.")
            } else {
                ForEach(items) { item in
                    KairoCard {
                        passportRecordHeader(
                            title: item.title,
                            subtitle: item.issuer,
                            status: item.verificationStatus
                        )

                        passportRecordMeta(title: "Issue date", value: item.issueDate)
                        passportRecordMeta(title: "Evidence", value: item.evidenceSummary)
                    }
                }
            }
        }
    }

    private func projectsSection(_ items: [PassportProjectRecord]) -> some View {
        passportRecordSection(
            title: "Projects & Portfolio",
            accessibilityIdentifier: KairoAccessibilityID.passportProjectsSection
        ) {
            if items.isEmpty {
                emptySectionCard(message: "No projects in your Trust Passport yet.")
            } else {
                ForEach(items) { item in
                    KairoCard {
                        Text(item.title)
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        passportRecordMeta(title: "Role", value: item.role)
                        passportRecordMeta(title: "Date", value: item.date)
                        passportRecordMeta(title: "Evidence", value: item.evidenceStatus)
                        passportRecordMeta(title: "Portfolio", value: item.portfolioLinkTitle)
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
                KairoCard {
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
                KairoCard {
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
            Text("Passport actions")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            KairoPrimaryButton(
                title: "Share Passport",
                accessibilityIdentifier: KairoAccessibilityID.passportShareAction,
                action: { modalDestination = .sharePassport }
            )

            KairoSecondaryButton(
                title: "Views & Share Activity",
                accessibilityIdentifier: KairoAccessibilityID.passportShareActivityEntry,
                action: { modalDestination = .shareActivity }
            )

            Text("Public preview, Copy, Share, and QR are available from the authoritative URL immediately after a share is created.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Download PDF — not available yet") {}
            .buttonStyle(.plain)
            .font(KairoTypography.footnote)
            .foregroundStyle(KairoColors.textSecondary)
            .disabled(true)
            .accessibilityIdentifier(KairoAccessibilityID.passportDownloadAction)
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
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
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
        KairoCard {
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
            .font(KairoTypography.title2)
            .foregroundStyle(KairoColors.textPrimary)
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct PassportBadge: View {
    let status: PassportVerificationStatus

    private var colors: (foreground: Color, background: Color, border: Color) {
        switch status.style.tone {
        case .verified:
            (KairoColors.accent, KairoColors.accent.opacity(0.12), KairoColors.accent.opacity(0.24))
        case .pending:
            (KairoColors.warning, KairoColors.warning.opacity(0.12), KairoColors.warning.opacity(0.24))
        case .neutral:
            (KairoColors.textSecondary, KairoColors.surfaceMuted.opacity(0.9), KairoColors.border)
        case .accent:
            (KairoColors.brandPrimary, KairoColors.brandPrimary.opacity(0.12), KairoColors.brandPrimary.opacity(0.22))
        }
    }

    var body: some View {
        let style = status.style
        let palette = colors

        Label(style.title, systemImage: style.symbol)
            .font(KairoTypography.caption)
            .foregroundStyle(palette.foreground)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(
                Capsule()
                    .fill(palette.background)
            )
            .overlay(
                Capsule()
                    .stroke(palette.border, lineWidth: 1)
            )
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(style.title)
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
    case scoreDetails
    case employmentDetails(String)
    case sharePassport
    case shareActivity
    case previewPassport
    case downloadPDF

    var id: String {
        switch self {
        case .scoreDetails:
            "passport.scoreDetails"
        case .employmentDetails(let company):
            "passport.employment.\(company)"
        case .sharePassport:
            "passport.share"
        case .shareActivity:
            "passport.shareActivity"
        case .previewPassport:
            "passport.preview"
        case .downloadPDF:
            "passport.pdf"
        }
    }

    var title: String {
        switch self {
        case .scoreDetails:
            "Trust Score details"
        case .employmentDetails:
            "Employment details"
        case .sharePassport:
            "Share Trust Passport"
        case .shareActivity:
            "Views & Share Activity"
        case .previewPassport:
            "Preview public Passport"
        case .downloadPDF:
            "Download PDF"
        }
    }

    var message: String {
        switch self {
        case .scoreDetails:
            "Trust Score calculation and score history will be connected in a later milestone. This screen currently preserves the approved local placeholder experience."
        case .employmentDetails(let company):
            "Detailed verification evidence for \(company) will be connected in a later milestone."
        case .sharePassport:
            "Sharing flows and public destinations will be connected in a later milestone."
        case .shareActivity:
            "Authoritative Passport view and share history."
        case .previewPassport:
            "Public Passport preview will be connected in a later milestone."
        case .downloadPDF:
            "PDF export will be connected in a later milestone."
        }
    }
}

private struct PassportPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let destination: PassportModalDestination

    var body: some View {
        NavigationStack {
            KairoScreenContainer(
                title: destination.title,
                subtitle: destination.message,
                titleAccessibilityIdentifier: "passport.placeholder.title",
                scrollBehavior: .fixed
            ) {
                KairoCard {
                    Text("Placeholder")
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)

                    Text(destination.message)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoPrimaryButton(
                    title: "Done",
                    action: { dismiss() }
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
