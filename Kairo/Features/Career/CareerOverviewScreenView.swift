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
    var addSkillAction: (() -> Void)?
    var deleteSkillAction: ((CareerSkillItem) -> Void)?

    @EnvironmentObject private var router: AppRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDetail: CareerRecordDetailPresentation?
    @State private var actionAfterDetailDismissal: (() -> Void)?

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    titleSection
                    phaseContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.large)
            }
            .refreshableIfAvailable(action: refreshAction)
        }
        .background(
            LinearGradient(
                colors: [KairoColors.background, KairoColors.surfaceMuted.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
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

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            Text("Career")
                .font(KairoTypography.screenTitle)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityIdentifier(CandidateTab.career.titleAccessibilityIdentifier)
                .accessibilityAddTraits(.isHeader)

            Text("Manage your professional history.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionTitle(
                title: CareerOverviewSection.professionalSummary.title,
                accessibilityIdentifier: KairoAccessibilityID.careerSummarySection
            )

            KairoSection {
                summaryHeader
                summaryDetails

                KairoSecondaryButton(
                    title: "Edit Profile in More",
                    accessibilityIdentifier: KairoAccessibilityID.careerEditProfileButton,
                    action: { router.selectTab(.more) }
                )
            }
        }
    }

    private var summaryHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: KairoSpacing.medium) {
                profilePhotoPlaceholder
                summaryCopy
                Spacer(minLength: KairoSpacing.small)
                CareerPillBadge(title: state.dataSourceLabel, tone: .neutral)
            }

            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                HStack(alignment: .center, spacing: KairoSpacing.medium) {
                    profilePhotoPlaceholder
                    summaryCopy
                }

                CareerPillBadge(title: state.dataSourceLabel, tone: .neutral)
            }
        }
    }

    private var profilePhotoPlaceholder: some View {
        ZStack {
            Circle()
                .fill(KairoColors.surfaceMuted)

            Text(state.summary.initials)
                .font(KairoTypography.headline)
                .foregroundStyle(KairoColors.textPrimary)
        }
        .frame(width: 64, height: 64)
        .overlay(
            Circle()
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .accessibilityElement()
        .accessibilityLabel("Profile photo placeholder for \(state.summary.name)")
    }

    private var summaryCopy: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(state.summary.name)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(state.summary.professionalHeadline)
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summaryDetails: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            CareerSummaryRow(
                title: "Current company",
                value: state.summary.currentCompany,
                systemImage: "building.2"
            )

            CareerSummaryRow(
                title: "Current location",
                value: state.summary.currentLocation,
                systemImage: "location"
            )

            HStack(alignment: .center, spacing: KairoSpacing.medium) {
                Label("Trust Passport status", systemImage: "checkmark.shield")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)

                Spacer(minLength: KairoSpacing.small)

                CareerPillBadge(
                    title: state.summary.trustPassportStatus,
                    tone: .success
                )
            }
        }
    }

    @ViewBuilder
    private var phaseContent: some View {
        switch state.phase {
        case .loading:
            KairoLoadingStateView(
                title: "Preparing your Career overview",
                message: "KairoID is assembling your professional timeline preview."
            )
        case .error(let errorState):
            KairoErrorStateView(
                title: errorState.title,
                message: errorState.message,
                retryAction: retryAction
            )
        case .populated(let content):
            populatedContent(content)
        case .empty:
            emptyContent
        }
    }

    private func populatedContent(_ content: CareerOverviewContent) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            employmentSection(content.employment)
            educationSection(content.education)
            certificationsSection(content.certifications)
            skillsSection(content.skills)
            projectsSection(content.projects)
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoEmptyStateView(
                title: "Your professional timeline starts here",
                message: "Add your first employment, education, certification, project, or skill to begin shaping your verified career history.",
                systemImage: "briefcase"
            )
            .accessibilityIdentifier(KairoAccessibilityID.careerEmptyState)

            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                if let addEmploymentAction {
                    KairoSecondaryButton(
                        title: "Add Employment",
                        accessibilityIdentifier: KairoAccessibilityID.careerAddEmploymentButton,
                        action: addEmploymentAction
                    )
                }

                if let addEducationAction {
                    KairoSecondaryButton(
                        title: "Add Education",
                        accessibilityIdentifier: KairoAccessibilityID.careerAddEducationButton,
                        action: addEducationAction
                    )
                }

                if let addCertificationAction {
                    KairoSecondaryButton(
                        title: "Add Certification",
                        accessibilityIdentifier: KairoAccessibilityID.careerAddCertificationButton,
                        action: addCertificationAction
                    )
                }

                if let addProjectAction {
                    KairoSecondaryButton(
                        title: "Add Project",
                        accessibilityIdentifier: KairoAccessibilityID.careerAddProjectButton,
                        action: addProjectAction
                    )
                }

                if let addSkillAction {
                    KairoSecondaryButton(
                        title: "Add Skill",
                        accessibilityIdentifier: KairoAccessibilityID.careerAddSkillButton,
                        action: addSkillAction
                    )
                }
            }
        }
    }

    private func employmentSection(_ items: [CareerEmploymentItem]) -> some View {
        KairoSection {
            CareerSectionHeader(
                title: CareerOverviewSection.employment.title,
                systemImage: "briefcase",
                count: items.count,
                accessibilityIdentifier: KairoAccessibilityID.careerEmploymentSection,
                actionTitle: addEmploymentAction == nil ? nil : "Add Employment",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddEmploymentButton,
                action: addEmploymentAction
            )

            if items.isEmpty {
                emptySectionCard(message: "No employment records added yet.")
            } else {
                ForEach(items) { item in
                    CareerRecordCard {
                        careerItemHeader(
                            title: item.role,
                            subtitle: item.company,
                            status: item.verificationStatus,
                            openDetail: {
                                selectedDetail = CareerRecordDetailPresentation(
                                    id: item.routeID, title: item.role, organization: item.company,
                                    status: item.verificationStatus, metadata: [("Employment dates", item.dateRange)] + item.detailMetadata.map { ($0.title, $0.value) },
                                    documents: .employment(id: item.routeID, title: "\(item.role) at \(item.company)", canUpload: item.allowsEdit, canDelete: item.allowsDelete),
                                    edit: item.allowsEdit ? editEmploymentAction.map { action in { action(item) } } : nil,
                                    delete: item.allowsDelete ? deleteEmploymentAction.map { action in { action(item) } } : nil,
                                    verify: item.verificationStatus.canStartVerification ? startEmploymentVerificationAction.map { action in { action(item) } } : nil
                                )
                            }
                        )

                        careerMetadataValue(
                            title: "Employment dates",
                            value: item.dateRange
                        )

                        CareerActionGroup {
                            careerCardActions(
                                editAccessibilityIdentifier: KairoAccessibilityID.careerEmploymentEditButton(item.routeID),
                                editAction: item.allowsEdit ? { editEmploymentAction?(item) } : nil,
                                deleteAccessibilityIdentifier: KairoAccessibilityID.careerEmploymentDeleteButton(item.routeID),
                                deleteAction: item.allowsDelete ? { deleteEmploymentAction?(item) } : nil
                            )

                            Button("Documents") {
                                router.showCareerDocuments(
                                    for: .employment(
                                        id: item.routeID,
                                        title: "\(item.role) at \(item.company)",
                                        canUpload: item.allowsEdit,
                                        canDelete: item.allowsDelete
                                    )
                                )
                            }
                            .buttonStyle(KairoActionStyle())

                        }
                        if item.verificationStatus.canStartVerification,
                           let startEmploymentVerificationAction {
                            Button("Start verification") {
                                startEmploymentVerificationAction(item)
                            }
                            .buttonStyle(.plain)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.brandPrimary)
                            .accessibilityIdentifier(KairoAccessibilityID.careerEmploymentStartVerification(item.routeID))
                        }
                    }
                }
            }
        }
    }

    private func educationSection(_ items: [CareerEducationItem]) -> some View {
        KairoSection {
            CareerSectionHeader(
                title: CareerOverviewSection.education.title,
                systemImage: "graduationcap",
                count: items.count,
                accessibilityIdentifier: KairoAccessibilityID.careerEducationSection,
                actionTitle: addEducationAction == nil ? nil : "Add Education",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddEducationButton,
                action: addEducationAction
            )

            if items.isEmpty {
                emptySectionCard(message: "No education records added yet.")
            } else {
                ForEach(items) { item in
                    CareerRecordCard {
                        careerItemHeader(
                            title: item.degree,
                            subtitle: item.institution,
                            status: item.verificationStatus,
                            openDetail: {
                                selectedDetail = CareerRecordDetailPresentation(
                                    id: item.routeID, title: item.degree, organization: item.institution,
                                    status: item.verificationStatus, metadata: [("Dates", item.dateRange)] + item.detailMetadata.map { ($0.title, $0.value) },
                                    documents: .education(id: item.routeID, title: item.institution),
                                    edit: editEducationAction.map { action in { action(item) } },
                                    delete: deleteEducationAction.map { action in { action(item) } },
                                    verify: item.verificationStatus.canStartVerification ? startEducationVerificationAction.map { action in { action(item) } } : nil
                                )
                            }
                        )

                        careerMetadataValue(
                            title: "Dates",
                            value: item.dateRange
                        )

                        CareerActionGroup {
                            careerCardActions(
                                editAccessibilityIdentifier: KairoAccessibilityID.careerEducationEditButton(item.routeID),
                                editAction: { editEducationAction?(item) },
                                deleteAccessibilityIdentifier: KairoAccessibilityID.careerEducationDeleteButton(item.routeID),
                                deleteAction: { deleteEducationAction?(item) }
                            )

                            Button("Documents") {
                                router.showCareerDocuments(
                                    for: .education(id: item.routeID, title: item.institution)
                                )
                            }
                            .buttonStyle(KairoActionStyle())

                        }
                        if item.verificationStatus.canStartVerification,
                           let startEducationVerificationAction {
                            Button("Start verification") {
                                startEducationVerificationAction(item)
                            }
                            .buttonStyle(.plain)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.brandPrimary)
                            .accessibilityIdentifier(KairoAccessibilityID.careerEducationStartVerification(item.routeID))
                        }
                    }
                }
            }
        }
    }

    private func certificationsSection(_ items: [CareerCertificationItem]) -> some View {
        KairoSection {
            CareerSectionHeader(
                title: CareerOverviewSection.certifications.title,
                systemImage: "checkmark.seal",
                count: items.count,
                accessibilityIdentifier: KairoAccessibilityID.careerCertificationsSection,
                actionTitle: addCertificationAction == nil ? nil : "Add Certification",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddCertificationButton,
                action: addCertificationAction
            )

            if items.isEmpty {
                emptySectionCard(message: "No certifications added yet.")
            } else {
                ForEach(items) { item in
                    CareerRecordCard {
                        careerItemHeader(
                            title: item.title,
                            subtitle: item.issuer,
                            status: item.verificationStatus,
                            openDetail: {
                                selectedDetail = CareerRecordDetailPresentation(
                                    id: item.routeID, title: item.title, organization: item.issuer,
                                    status: item.verificationStatus, metadata: [("Issue date", item.issueDate)] + item.detailMetadata.map { ($0.title, $0.value) },
                                    documents: .certification(id: item.routeID, title: item.title),
                                    edit: editCertificationAction.map { action in { action(item) } },
                                    delete: deleteCertificationAction.map { action in { action(item) } }
                                )
                            }
                        )

                        careerMetadataValue(
                            title: "Issue date",
                            value: item.issueDate
                        )

                        CareerActionGroup {
                            careerCardActions(
                                editAccessibilityIdentifier: KairoAccessibilityID.careerCertificationEditButton(item.routeID),
                                editAction: { editCertificationAction?(item) },
                                deleteAccessibilityIdentifier: KairoAccessibilityID.careerCertificationDeleteButton(item.routeID),
                                deleteAction: { deleteCertificationAction?(item) }
                            )

                            if item.hasDocument {
                                Button("View certificate document") {
                                    router.showCareerDocuments(
                                        for: .certification(id: item.routeID, title: item.title)
                                    )
                                }
                                .buttonStyle(KairoActionStyle())
                            }
                        }
                    }
                }
            }
        }
    }

    private func projectsSection(_ items: [CareerProjectItem]) -> some View {
        KairoSection {
            CareerSectionHeader(
                title: CareerOverviewSection.projects.title,
                systemImage: "folder",
                count: items.count,
                accessibilityIdentifier: KairoAccessibilityID.careerProjectsSection,
                actionTitle: addProjectAction == nil ? nil : "Add Project",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddProjectButton,
                action: addProjectAction
            )

            if items.isEmpty {
                emptySectionCard(message: "No projects added yet.")
            } else {
                ForEach(items) { item in
                    CareerRecordCard {
                        careerItemHeader(
                            title: item.title,
                            subtitle: item.role,
                            status: item.verificationStatus,
                            openDetail: {
                                selectedDetail = CareerRecordDetailPresentation(
                                    id: item.routeID, title: item.title, organization: item.role,
                                    status: item.verificationStatus,
                                    metadata: [("Duration", item.duration), ("Project URL", item.portfolioLinkTitle)].filter { !$0.1.isEmpty } + item.detailMetadata.map { ($0.title, $0.value) },
                                    documents: item.legacyPortfolioID.map { .legacyPortfolio(id: $0, title: item.title) },
                                    edit: item.legacyPortfolioID == nil ? editProjectAction.map { action in { action(item) } } : nil,
                                    delete: item.legacyPortfolioID == nil ? deleteProjectAction.map { action in { action(item) } } : nil
                                )
                            }
                        )

                        careerMetadataValue(
                            title: "Duration",
                            value: item.duration
                        )

                        if !item.portfolioLinkTitle.isEmpty {
                            careerMetadataValue(
                                title: "Project URL",
                                value: item.portfolioLinkTitle
                            )
                        }

                        if item.legacyPortfolioID == nil {
                            careerCardActions(
                                editAccessibilityIdentifier: KairoAccessibilityID.careerProjectEditButton(item.routeID),
                                editAction: { editProjectAction?(item) },
                                deleteAccessibilityIdentifier: KairoAccessibilityID.careerProjectDeleteButton(item.routeID),
                                deleteAction: { deleteProjectAction?(item) }
                            )
                        }
                    }
                }
            }
        }
    }

    private func skillsSection(_ skills: [CareerSkillItem]) -> some View {
        KairoSection {
            CareerSectionHeader(
                title: CareerOverviewSection.skills.title,
                systemImage: "sparkles",
                count: skills.count,
                accessibilityIdentifier: KairoAccessibilityID.careerSkillsSection,
                actionTitle: addSkillAction == nil ? nil : "Add Skill",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddSkillButton,
                action: addSkillAction
            )

            if skills.isEmpty {
                emptySectionCard(message: "No skills added yet.")
            } else {
                CareerRecordCard {
                    VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                        ForEach(Array(skills.enumerated()), id: \.element.routeID) { index, skill in
                            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                                HStack(alignment: .center, spacing: KairoSpacing.small) {
                                    Text(skill.name)
                                        .font(KairoTypography.bodyStrong)
                                        .foregroundStyle(KairoColors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .fixedSize(horizontal: false, vertical: true)

                                    CareerVerificationBadge(status: skill.verificationStatus)
                                }

                                careerCardActions(
                                    editAccessibilityIdentifier: KairoAccessibilityID.careerSkillEditButton(skill.routeID),
                                    editAction: nil,
                                    deleteAccessibilityIdentifier: KairoAccessibilityID.careerSkillDeleteButton(skill.routeID),
                                    deleteAction: { deleteSkillAction?(skill) }
                                )
                            }

                            if index < skills.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func careerItemHeader(
        title: String,
        subtitle: String,
        status: CareerVerificationStatus?,
        openDetail: @escaping () -> Void
    ) -> some View {
        Button(action: openDetail) {
            recordHeaderLayout {
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(title)
                        .font(KairoTypography.recordTitle)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let status {
                    CareerVerificationBadge(status: status)
                        .accessibilityIdentifier("career.record.status.\(title)")
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("career.record.open.\(title)")
        .accessibilityHint("Opens record details.")
    }

    private func performAfterDetailDismissal(_ action: @escaping () -> Void) {
        actionAfterDetailDismissal = action
        selectedDetail = nil
    }

    private var recordHeaderLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: KairoSpacing.small))
            : AnyLayout(HStackLayout(alignment: .top, spacing: KairoSpacing.small))
    }

    private func careerMetadataValue(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: KairoSpacing.xSmall) {
            Text(value)
                .font(KairoTypography.metadata)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityLabel("\(title): \(value)")
    }

    @ViewBuilder
    private func careerCardActions(
        editAccessibilityIdentifier: String?,
        editAction: (() -> Void)?,
        deleteAccessibilityIdentifier: String?,
        deleteAction: (() -> Void)?
    ) -> some View {
        if editAction != nil || deleteAction != nil {
            CareerActionGroup {
                if let editAction {
                    Button("Edit", action: editAction)
                        .buttonStyle(KairoActionStyle())
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.brandPrimary)
                        .accessibilityIdentifier(editAccessibilityIdentifier ?? "career.edit")
                }

                if let deleteAction {
                    Button("Delete", action: deleteAction)
                        .buttonStyle(KairoActionStyle(role: .destructiveSecondary))
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.danger.opacity(0.9))
                        .accessibilityIdentifier(deleteAccessibilityIdentifier ?? "career.delete")
                }
            }
        }
    }

    private func emptySectionCard(message: String) -> some View {
        CareerEmptyRow {
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

private struct CareerSectionTitle: View {
    let title: String
    let accessibilityIdentifier: String

    var body: some View {
        Text(title)
            .font(KairoTypography.title2)
            .foregroundStyle(KairoColors.textPrimary)
            .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CareerSectionHeader: View {
    let title: String
    let systemImage: String
    let count: Int
    let accessibilityIdentifier: String
    let actionTitle: String?
    let actionAccessibilityIdentifier: String
    let action: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: KairoSpacing.medium) {
                sectionLabel

                Spacer(minLength: KairoSpacing.medium)

                if let actionTitle, let action {
                    CareerSectionInlineAction(
                        title: actionTitle,
                        accessibilityIdentifier: actionAccessibilityIdentifier,
                        action: action
                    )
                }
            }

            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                sectionLabel

                if let actionTitle, let action {
                    CareerSectionInlineAction(
                        title: actionTitle,
                        accessibilityIdentifier: actionAccessibilityIdentifier,
                        action: action
                    )
                }
            }
        }
    }

    private var sectionLabel: some View {
        HStack(spacing: KairoSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(KairoColors.textSecondary)
                .frame(width: 34, height: 34)
                .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))

            Text(title)
                .font(KairoTypography.sectionTitle)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text(String(count))
                .font(KairoTypography.caption)
                .foregroundStyle(KairoColors.textSecondary)
                .padding(.horizontal, KairoSpacing.xSmall)
                .padding(.vertical, KairoSpacing.xxSmall)
                .background(KairoColors.surfaceMuted, in: Capsule())
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CareerSectionInlineAction: View {
    let title: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(KairoColors.brandPrimary)
                .frame(width: 44, height: 44)
                .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CareerActionGroup<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: Content

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) { content }
        } else {
            HStack(spacing: KairoSpacing.small) { content }
        }
    }
}

private struct CareerRecordCard<Content: View>: View {
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

private struct CareerEmptyRow<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .center, spacing: KairoSpacing.small) {
            content
        }
        .padding(.horizontal, KairoSpacing.small)
        .padding(.vertical, KairoSpacing.medium)
        .frame(maxWidth: .infinity)
        .background(KairoColors.surfaceMuted.opacity(0.5), in: RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))
    }
}

private struct CareerSummaryRow: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: KairoSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(KairoColors.textSecondary)

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
    }
}

private struct CareerVerificationBadge: View {
    let status: CareerVerificationStatus

    private var tone: KairoStatusTone {
        switch status {
        case .verified: .verified
        case .pendingVerification: .pending
        case .notVerified: .candidateProvided
        case .precise: .draft
        }
    }

    var body: some View {
        KairoStatusChip(title: status.badgeStyle.title, tone: tone, systemImage: status.badgeStyle.symbol)
    }
}

private enum CareerPlaceholderTone {
    case neutral
    case success
}

private struct CareerPillBadge: View {
    let title: String
    let tone: CareerPlaceholderTone

    private var colors: (foreground: Color, background: Color, border: Color) {
        switch tone {
        case .neutral:
            (
                KairoColors.textSecondary,
                KairoColors.surfaceMuted.opacity(0.9),
                KairoColors.border
            )
        case .success:
            (
                KairoColors.accent,
                KairoColors.accent.opacity(0.12),
                KairoColors.accent.opacity(0.24)
            )
        }
    }

    var body: some View {
        let resolvedColors = colors

        Text(title)
            .font(KairoTypography.caption)
            .foregroundStyle(resolvedColors.foreground)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, KairoSpacing.xSmall)
            .background(
                Capsule()
                    .fill(resolvedColors.background)
            )
            .overlay(
                Capsule()
                    .stroke(resolvedColors.border, lineWidth: 1)
            )
    }
}
