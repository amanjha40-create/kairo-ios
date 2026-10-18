import SwiftUI

struct CareerOverviewScreenView: View {
    let state: CareerOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?
    var addEmploymentAction: (() -> Void)?
    var editEmploymentAction: ((CareerEmploymentItem) -> Void)?
    var deleteEmploymentAction: ((CareerEmploymentItem) -> Void)?
    var startEmploymentVerificationAction: ((CareerEmploymentItem) -> Void)?
    var addEducationAction: (() -> Void)?
    var editEducationAction: ((CareerEducationItem) -> Void)?
    var deleteEducationAction: ((CareerEducationItem) -> Void)?
    var startEducationVerificationAction: ((CareerEducationItem) -> Void)?
    var addCertificationAction: (() -> Void)?
    var editCertificationAction: ((CareerCertificationItem) -> Void)?
    var deleteCertificationAction: ((CareerCertificationItem) -> Void)?
    var addProjectAction: (() -> Void)?
    var editProjectAction: ((CareerProjectItem) -> Void)?
    var deleteProjectAction: ((CareerProjectItem) -> Void)?
    var addPortfolioAction: (() -> Void)?
    var editPortfolioAction: ((CareerPortfolioItem) -> Void)?
    var addSkillAction: (() -> Void)?
    var deleteSkillAction: ((CareerSkillItem) -> Void)?

    @EnvironmentObject private var router: AppRouter
    @State private var selectedDetail: CareerRecordDetailPresentation?
    @State private var actionAfterDetailDismissal: (() -> Void)?

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                Text("Career")
                    .font(KairoTypography.screenTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                    .accessibilityIdentifier(CandidateTab.career.titleAccessibilityIdentifier)
                    .accessibilityAddTraits(.isHeader)
                Text(overviewSubtitle)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(KairoAccessibilityID.careerSummarySection)
                KairoCompactDestinationRow(
                    title: "Verification activity",
                    metadata: "Review invitations, requests and next steps",
                    systemImage: "checkmark.shield",
                    accessibilityIdentifier: "career.verification.activity",
                    action: { router.selectTab(.verify) }
                )
                ProductGuidanceView(topic: .career)
                phaseContent
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.large)
            .kairoPageEntrance()
        }
        .refreshableIfAvailable(action: refreshAction)
        .background(KairoColors.background.ignoresSafeArea())
        .accessibilityIdentifier(KairoAccessibilityID.careerScreen)
        .sheet(item: $selectedDetail, onDismiss: {
            let action = actionAfterDetailDismissal
            actionAfterDetailDismissal = nil
            action?()
        }) { record in
            CareerRecordDetailView(record: record, perform: performAfterDetailDismissal, openDocuments: { parent in
                performAfterDetailDismissal { router.showCareerDocuments(for: parent) }
            })
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .loading:
            KairoLoadingStateView(title: "Preparing your Career overview", message: "Loading your professional history.")
        case .error(let error):
            KairoErrorStateView(title: error.title, message: error.message, retryAction: retryAction)
        case .populated(let content):
            sections(content)
        case .empty(let content):
            Text("Your professional timeline starts here")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .accessibilityIdentifier(KairoAccessibilityID.careerEmptyState)
            sections(content)
        }
    }

    private func sections(_ content: CareerOverviewContent) -> some View {
        Group {
            employmentSection(content.employment)
            educationSection(content.education)
            certificationsSection(content.certifications)
            skillsSection(content.skills)
            projectsSection(content.projects)
            portfolioSection(content.portfolio)
        }
    }

    private var overviewSubtitle: String {
        let content: CareerOverviewContent?
        switch state.phase {
        case .populated(let value), .empty(let value): content = value
        case .loading, .error: content = nil
        }
        guard let content else { return "Manage your professional history" }
        let total = content.employment.count + content.education.count
        if total == 0 { return "Build your professional history" }
        return "\(total) \(total == 1 ? "career record" : "career records")"
    }

    private func employmentSection(_ items: [CareerEmploymentItem]) -> some View {
        KairoSection(compact: true) {
            CareerSectionHeader(title: "Employment", count: items.count,
                identifier: KairoAccessibilityID.careerEmploymentSection,
                addTitle: "Add Employment", addIdentifier: KairoAccessibilityID.careerAddEmploymentButton, add: addEmploymentAction)
            if items.isEmpty { emptyRow("No employment records added yet.") }
            ForEach(items) { item in
                CareerCompactRecordRow(title: item.role, subtitle: item.company, metadata: [item.dateRange], status: item.verificationStatus,
                    leadingText: CareerRecordLeadingVisual.initials(item.company)) {
                    selectedDetail = .employment(item,
                        edit: editEmploymentAction.map { action in { action(item) } },
                        delete: deleteEmploymentAction.map { action in { action(item) } },
                        verify: startEmploymentVerificationAction.map { action in { action(item) } })
                }
            }
        }
    }

    private func educationSection(_ items: [CareerEducationItem]) -> some View {
        KairoSection(compact: true) {
            CareerSectionHeader(title: "Education", count: items.count,
                identifier: KairoAccessibilityID.careerEducationSection,
                addTitle: "Add Education", addIdentifier: KairoAccessibilityID.careerAddEducationButton, add: addEducationAction)
            if items.isEmpty { emptyRow("No education records added yet.") }
            ForEach(items) { item in
                CareerCompactRecordRow(title: item.degree, subtitle: item.institution, metadata: [item.dateRange], status: item.verificationStatus,
                    leadingText: CareerRecordLeadingVisual.initials(item.institution)) {
                    selectedDetail = .education(item,
                        edit: editEducationAction.map { action in { action(item) } },
                        delete: deleteEducationAction.map { action in { action(item) } },
                        verify: startEducationVerificationAction.map { action in { action(item) } })
                }
            }
        }
    }

    private func certificationsSection(_ items: [CareerCertificationItem]) -> some View {
        KairoSection(compact: true) {
            CareerSectionHeader(title: "Certifications", count: items.count,
                identifier: KairoAccessibilityID.careerCertificationsSection,
                addTitle: "Add Certification", addIdentifier: KairoAccessibilityID.careerAddCertificationButton, add: addCertificationAction)
            if items.isEmpty { emptyRow("No certifications added yet.") }
            ForEach(items) { item in
                CareerCompactRecordRow(title: item.title, subtitle: item.issuer,
                    metadata: [item.issueDate] + item.detailMetadata.filter { $0.title == "Expiry" }.map(\.value),
                    status: item.verificationStatus, attachment: item.hasDocument ? "Attachment added" : "No attachment",
                    leadingSystemImage: "rosette", optionalRecord: true) {
                    selectedDetail = .certification(item,
                        edit: editCertificationAction.map { action in { action(item) } },
                        delete: deleteCertificationAction.map { action in { action(item) } })
                }
            }
        }
    }

    private func projectsSection(_ items: [CareerProjectItem]) -> some View {
        KairoSection(compact: true) {
            CareerSectionHeader(title: "Projects", count: items.count,
                identifier: KairoAccessibilityID.careerProjectsSection,
                addTitle: "Add Project", addIdentifier: KairoAccessibilityID.careerAddProjectButton, add: addProjectAction)
            if items.isEmpty { emptyRow("No projects added yet.") }
            ForEach(items) { item in
                CareerCompactRecordRow(title: item.title, subtitle: item.role,
                    metadata: item.detailMetadata.filter { $0.title == "Organization" }.map(\.value) + [item.duration] + item.links.map { "\($0.title): \($0.url.host ?? "")" },
                    status: item.verificationStatus ?? .notVerified, leadingSystemImage: "folder", optionalRecord: true) {
                    selectedDetail = .project(item,
                        edit: editProjectAction.map { action in { action(item) } },
                        delete: deleteProjectAction.map { action in { action(item) } })
                }
            }
        }
    }

    private func portfolioSection(_ items: [CareerPortfolioItem]) -> some View {
        KairoSection(compact: true) {
            CareerSectionHeader(title: "Portfolio", count: items.count,
                identifier: KairoAccessibilityID.careerPortfolioSection,
                addTitle: "Add Portfolio Item", addIdentifier: KairoAccessibilityID.careerAddPortfolioButton, add: addPortfolioAction)
            if items.isEmpty { emptyRow("No portfolio items yet.") }
            ForEach(items) { item in
                CareerCompactRecordRow(
                    title: item.title,
                    subtitle: "Portfolio",
                    metadata: [item.description].compactMap { $0 },
                    status: item.verificationStatus,
                    attachment: item.hasDocument ? "Attachment added" : nil,
                    leadingSystemImage: "rectangle.stack"
                ) {
                    selectedDetail = .portfolio(item, edit: editPortfolioAction.map { action in { action(item) } })
                }
            }
        }
    }

    private func skillsSection(_ items: [CareerSkillItem]) -> some View {
        KairoSection(compact: true) {
            CareerSectionHeader(title: "Skills", count: items.count,
                identifier: KairoAccessibilityID.careerSkillsSection,
                addTitle: "Add Skill", addIdentifier: KairoAccessibilityID.careerAddSkillButton, add: addSkillAction)
            if items.isEmpty { emptyRow("No skills added yet.") }
            ForEach(items) { item in
                Divider()
                HStack(alignment: .top, spacing: KairoSpacing.small) {
                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                        Text(item.name).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                        if ProductStatusLanguage.optionalRecordTitle(item.verificationStatus.badgeStyle.title) != nil {
                            CareerRecordStatus(status: item.verificationStatus)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if let deleteSkillAction {
                        Menu {
                            Button("Delete", role: .destructive) { deleteSkillAction(item) }
                                .accessibilityIdentifier(KairoAccessibilityID.careerSkillDeleteButton(item.routeID))
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Rectangle())
                        }
                        .accessibilityLabel("Actions for \(item.name)")
                    }
                }
            }
        }
    }

    private func emptyRow(_ message: String) -> some View {
        Text(message).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, KairoSpacing.xSmall)
    }

    private func performAfterDetailDismissal(_ action: @escaping () -> Void) {
        actionAfterDetailDismissal = action
        selectedDetail = nil
    }
}

/// One control owns the complete visible row, including metadata, status and whitespace.
/// Lifecycle controls live in the canonical detail, never nested inside this button.
struct CareerCompactRecordRow: View {
    let title: String
    let subtitle: String
    let metadata: [String]
    let status: CareerVerificationStatus
    var attachment: String? = nil
    var leadingText: String? = nil
    var leadingSystemImage: String? = nil
    var optionalRecord = false
    let open: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: open) {
                HStack(alignment: .center, spacing: KairoSpacing.small) {
                    if leadingText != nil || leadingSystemImage != nil {
                        ZStack {
                            RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                                .fill(KairoColors.surfaceMuted)
                                .frame(width: 40, height: 40)
                            if let leadingText {
                                Text(leadingText)
                                    .font(KairoTypography.caption)
                                    .foregroundStyle(KairoColors.brandPrimary)
                            } else if let leadingSystemImage {
                                Image(systemName: leadingSystemImage)
                                    .font(KairoTypography.bodyStrong)
                                    .foregroundStyle(KairoColors.brandPrimary)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                        Text(title).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
                        if !subtitle.isEmpty {
                            Text(subtitle).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                        }
                        ForEach(Array(metadata.filter { !$0.isEmpty }.enumerated()), id: \.offset) { _, value in
                            Text(value).font(KairoTypography.metadata).foregroundStyle(KairoColors.textSecondary)
                        }
                        if !optionalRecord || ProductStatusLanguage.optionalRecordTitle(status.badgeStyle.title) != nil {
                            CareerRecordStatus(status: status)
                                .accessibilityIdentifier("career.record.status.\(title)")
                        }
                        if let attachment {
                            Label(attachment, systemImage: "paperclip")
                                .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.right")
                        .font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.vertical, KairoSpacing.small)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("career.record.open.\(title)")
            .accessibilityHint("Opens record details and available actions.")
        }
    }
}

struct CareerSectionHeader: View {
    let title: String
    let count: Int
    let identifier: String
    let addTitle: String
    let addIdentifier: String
    let add: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: KairoSpacing.small) {
            Text(title).font(KairoTypography.sectionTitle)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(identifier)
            Text(String(count)).font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .padding(KairoSpacing.xSmall)
                .background(KairoColors.surfaceMuted, in: Capsule())
                .accessibilityLabel("\(title): \(count) \(count == 1 ? "record" : "records")")
                .accessibilityIdentifier("\(identifier).count")
            Spacer(minLength: 0)
            if let add {
                Button(action: add) {
                    Image(systemName: "plus").font(KairoTypography.bodyStrong)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(KairoColors.brandPrimary)
                .accessibilityLabel(addTitle).accessibilityIdentifier(addIdentifier)
            }
        }
    }
}

struct CareerRecordStatus: View {
    let status: CareerVerificationStatus
    var body: some View {
        let style = status.badgeStyle
        KairoStatusChip(title: style.title, tone: style.kairoTone, systemImage: style.symbol)
    }
}

nonisolated enum CareerRecordLeadingVisual {
    static func initials(_ value: String) -> String {
        let words = value.split(whereSeparator: { $0.isWhitespace })
        guard let first = words.first else { return "?" }
        if words.count == 1 || first == first.uppercased() {
            return String(first.prefix(2)).uppercased()
        }
        return words.prefix(2).compactMap(\.first).map { String($0).uppercased() }.joined()
    }
}

private extension CareerVerificationBadgeStyle {
    var kairoTone: KairoStatusTone {
        switch tone {
        case .success: .verified
        case .pending: .pending
        case .attention: .attention
        case .rejected: .rejected
        case .withdrawn: .withdrawn
        case .draft: .draft
        case .candidateProvided: .candidateProvided
        }
    }
}

private extension View {
    @ViewBuilder func refreshableIfAvailable(action: (() async -> Void)?) -> some View {
        if let action { refreshable { await action() } } else { self }
    }
}
