import SwiftUI

struct CareerOverviewScreenView: View {
    let state: CareerOverviewState
    var retryAction: (() -> Void)?
    var refreshAction: (() async -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var placeholderDestination: CareerPlaceholderDestination?

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    titleSection
                    summarySection
                    phaseContent
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, KairoSpacing.large)
                .padding(.vertical, KairoSpacing.xLarge)
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
        .sheet(item: $placeholderDestination) { destination in
            CareerPlaceholderSheet(destination: destination)
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            Text("Career")
                .font(KairoTypography.largeTitle)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityIdentifier(CandidateTab.career.titleAccessibilityIdentifier)

            Text("Build and manage your professional history.")
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionTitle(
                title: CareerOverviewSection.professionalSummary.title,
                accessibilityIdentifier: KairoAccessibilityID.careerSummarySection
            )

            KairoCard {
                summaryHeader
                summaryDetails

                KairoSecondaryButton(
                    title: "Edit Profile",
                    accessibilityIdentifier: KairoAccessibilityID.careerEditProfileButton,
                    action: {
                        placeholderDestination = .editProfile
                    }
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
                message: "Kairo is assembling your professional timeline preview."
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
        VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
            employmentSection(content.employment)
            educationSection(content.education)
            certificationsSection(content.certifications)
            projectsSection(content.projects)
            skillsSection(content.skills)
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoEmptyStateView(
                title: "Your professional timeline starts here",
                message: "Add your first employment, education, certification, or project to begin shaping your verified career history.",
                systemImage: "briefcase"
            )
            .accessibilityIdentifier(KairoAccessibilityID.careerEmptyState)

            KairoSecondaryButton(
                title: "Add Employment",
                accessibilityIdentifier: KairoAccessibilityID.careerAddEmploymentButton,
                action: {
                    placeholderDestination = .addEmployment
                }
            )
        }
    }

    private func employmentSection(_ items: [CareerEmploymentItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionHeader(
                title: CareerOverviewSection.employment.title,
                accessibilityIdentifier: KairoAccessibilityID.careerEmploymentSection,
                actionTitle: "Add Employment",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddEmploymentButton,
                action: { placeholderDestination = .addEmployment }
            )

            ForEach(items) { item in
                KairoCard {
                    careerItemHeader(
                        title: item.company,
                        subtitle: item.role,
                        status: item.verificationStatus
                    )

                    careerMetadataValue(
                        title: "Employment dates",
                        value: item.dateRange
                    )

                    careerCardActions(
                        editAction: { placeholderDestination = .editEmployment(item.company) },
                        deleteAction: { placeholderDestination = .deleteEmployment(item.company) }
                    )
                }
            }
        }
    }

    private func educationSection(_ items: [CareerEducationItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionHeader(
                title: CareerOverviewSection.education.title,
                accessibilityIdentifier: KairoAccessibilityID.careerEducationSection,
                actionTitle: "Add Education",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddEducationButton,
                action: { placeholderDestination = .addEducation }
            )

            ForEach(items) { item in
                KairoCard {
                    careerItemHeader(
                        title: item.institution,
                        subtitle: item.degree,
                        status: item.verificationStatus
                    )

                    careerMetadataValue(
                        title: "Dates",
                        value: item.dateRange
                    )

                    careerCardActions(
                        editAction: { placeholderDestination = .editEducation(item.institution) },
                        deleteAction: { placeholderDestination = .deleteEducation(item.institution) }
                    )
                }
            }
        }
    }

    private func certificationsSection(_ items: [CareerCertificationItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionHeader(
                title: CareerOverviewSection.certifications.title,
                accessibilityIdentifier: KairoAccessibilityID.careerCertificationsSection,
                actionTitle: "Add Certification",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddCertificationButton,
                action: { placeholderDestination = .addCertification }
            )

            if items.isEmpty {
                emptySectionCard(message: "No certifications added yet.")
            } else {
                ForEach(items) { item in
                    KairoCard {
                        careerItemHeader(
                            title: item.title,
                            subtitle: item.issuer,
                            status: item.verificationStatus
                        )

                        careerMetadataValue(
                            title: "Issue date",
                            value: item.issueDate
                        )
                    }
                }
            }
        }
    }

    private func projectsSection(_ items: [CareerProjectItem]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionHeader(
                title: CareerOverviewSection.projects.title,
                accessibilityIdentifier: KairoAccessibilityID.careerProjectsSection,
                actionTitle: "Add Project",
                actionAccessibilityIdentifier: KairoAccessibilityID.careerAddProjectButton,
                action: { placeholderDestination = .addProject }
            )

            if items.isEmpty {
                emptySectionCard(message: "No projects added yet.")
            } else {
                ForEach(items) { item in
                    KairoCard {
                        careerItemHeader(
                            title: item.title,
                            subtitle: item.role,
                            status: item.verificationStatus
                        )

                        careerMetadataValue(
                            title: "Duration",
                            value: item.duration
                        )

                        Button(item.portfolioLinkTitle) {
                            placeholderDestination = .portfolioLink(item.title)
                        }
                        .buttonStyle(.plain)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.brandPrimary)
                    }
                }
            }
        }
    }

    private func skillsSection(_ skills: [String]) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            CareerSectionTitle(
                title: CareerOverviewSection.skills.title,
                accessibilityIdentifier: KairoAccessibilityID.careerSkillsSection
            )

            KairoCard {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 160 : 110), spacing: KairoSpacing.small)
                    ],
                    alignment: .leading,
                    spacing: KairoSpacing.small
                ) {
                    ForEach(Array(skills.enumerated()), id: \.offset) { _, skill in
                        Text(skill)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textPrimary)
                            .padding(.horizontal, KairoSpacing.medium)
                            .padding(.vertical, KairoSpacing.small)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Capsule()
                                    .fill(KairoColors.surfaceMuted.opacity(0.8))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(KairoColors.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func careerItemHeader(
        title: String,
        subtitle: String,
        status: CareerVerificationStatus?
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

                if let status {
                    CareerVerificationBadge(status: status)
                }
            }
        }
    }

    private func careerMetadataValue(title: String, value: String) -> some View {
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

    private func careerCardActions(
        editAction: @escaping () -> Void,
        deleteAction: @escaping () -> Void
    ) -> some View {
        HStack(spacing: KairoSpacing.large) {
            Button("Edit", action: editAction)
                .buttonStyle(.plain)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.brandPrimary)

            Button("Delete", action: deleteAction)
                .buttonStyle(.plain)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.danger.opacity(0.9))
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
    let accessibilityIdentifier: String
    let actionTitle: String
    let actionAccessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: KairoSpacing.medium) {
                CareerSectionTitle(
                    title: title,
                    accessibilityIdentifier: accessibilityIdentifier
                )

                Spacer(minLength: KairoSpacing.medium)

                CareerSectionInlineAction(
                    title: actionTitle,
                    accessibilityIdentifier: actionAccessibilityIdentifier,
                    action: action
                )
            }

            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                CareerSectionTitle(
                    title: title,
                    accessibilityIdentifier: accessibilityIdentifier
                )

                CareerSectionInlineAction(
                    title: actionTitle,
                    accessibilityIdentifier: actionAccessibilityIdentifier,
                    action: action
                )
            }
        }
    }
}

private struct CareerSectionInlineAction: View {
    let title: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.brandPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
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

    private var colors: (foreground: Color, background: Color, border: Color) {
        switch status.badgeStyle.tone {
        case .success:
            (
                KairoColors.success,
                KairoColors.success.opacity(0.12),
                KairoColors.success.opacity(0.22)
            )
        case .pending:
            (
                KairoColors.warning,
                KairoColors.warning.opacity(0.12),
                KairoColors.warning.opacity(0.22)
            )
        case .neutral:
            (
                KairoColors.textSecondary,
                KairoColors.surfaceMuted.opacity(0.9),
                KairoColors.border
            )
        }
    }

    var body: some View {
        let style = status.badgeStyle
        let resolvedColors = colors

        Label(style.title, systemImage: style.symbol)
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
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(style.title)
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

private enum CareerPlaceholderDestination: Identifiable {
    case editProfile
    case addEmployment
    case editEmployment(String)
    case deleteEmployment(String)
    case addEducation
    case editEducation(String)
    case deleteEducation(String)
    case addCertification
    case addProject
    case portfolioLink(String)

    var id: String {
        switch self {
        case .editProfile:
            "career.editProfile"
        case .addEmployment:
            "career.addEmployment"
        case .editEmployment(let value):
            "career.editEmployment.\(value)"
        case .deleteEmployment(let value):
            "career.deleteEmployment.\(value)"
        case .addEducation:
            "career.addEducation"
        case .editEducation(let value):
            "career.editEducation.\(value)"
        case .deleteEducation(let value):
            "career.deleteEducation.\(value)"
        case .addCertification:
            "career.addCertification"
        case .addProject:
            "career.addProject"
        case .portfolioLink(let value):
            "career.portfolioLink.\(value)"
        }
    }

    var title: String {
        switch self {
        case .editProfile:
            "Edit Profile"
        case .addEmployment:
            "Add Employment"
        case .editEmployment:
            "Edit Employment"
        case .deleteEmployment:
            "Delete Employment"
        case .addEducation:
            "Add Education"
        case .editEducation:
            "Edit Education"
        case .deleteEducation:
            "Delete Education"
        case .addCertification:
            "Add Certification"
        case .addProject:
            "Add Project"
        case .portfolioLink:
            "Portfolio Link"
        }
    }

    var message: String {
        switch self {
        case .editProfile:
            "Profile editing will be connected in a later milestone."
        case .addEmployment:
            "Employment creation will be connected in a later milestone."
        case .editEmployment(let company):
            "Editing for \(company) will be connected in a later milestone."
        case .deleteEmployment(let company):
            "Delete controls for \(company) will be connected in a later milestone."
        case .addEducation:
            "Education creation will be connected in a later milestone."
        case .editEducation(let institution):
            "Editing for \(institution) will be connected in a later milestone."
        case .deleteEducation(let institution):
            "Delete controls for \(institution) will be connected in a later milestone."
        case .addCertification:
            "Certification creation will be connected in a later milestone."
        case .addProject:
            "Project creation will be connected in a later milestone."
        case .portfolioLink(let project):
            "Portfolio links for \(project) will be connected in a later milestone."
        }
    }
}

private struct CareerPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let destination: CareerPlaceholderDestination

    var body: some View {
        NavigationStack {
            KairoScreenContainer(
                title: destination.title,
                subtitle: destination.message,
                titleAccessibilityIdentifier: "career.placeholder.title",
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
