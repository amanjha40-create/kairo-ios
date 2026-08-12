import SwiftUI

enum CareerMutationSheet: Identifiable {
    case employment(mode: CareerMutationMode, recordID: String?, draft: CareerEmploymentDraft)
    case education(mode: CareerMutationMode, recordID: String?, draft: CareerEducationDraft)
    case certification(mode: CareerMutationMode, recordID: String?, draft: CareerCertificationDraft)
    case project(mode: CareerMutationMode, recordID: String?, draft: CareerProjectDraft)
    case skill(mode: CareerMutationMode, recordID: String?, draft: CareerSkillDraft, existingNames: [String])

    var id: String {
        switch self {
        case .employment(let mode, let recordID, _):
            "employment.\(mode.rawValue).\(recordID ?? "new")"
        case .education(let mode, let recordID, _):
            "education.\(mode.rawValue).\(recordID ?? "new")"
        case .certification(let mode, let recordID, _):
            "certification.\(mode.rawValue).\(recordID ?? "new")"
        case .project(let mode, let recordID, _):
            "project.\(mode.rawValue).\(recordID ?? "new")"
        case .skill(let mode, let recordID, _, _):
            "skill.\(mode.rawValue).\(recordID ?? "new")"
        }
    }
}

enum CareerDeleteRequest: Identifiable {
    case employment(CareerEmploymentItem)
    case education(CareerEducationItem)
    case certification(CareerCertificationItem)
    case project(CareerProjectItem)
    case skill(CareerSkillItem)

    var id: String {
        switch self {
        case .employment(let item):
            "employment.\(item.routeID)"
        case .education(let item):
            "education.\(item.routeID)"
        case .certification(let item):
            "certification.\(item.routeID)"
        case .project(let item):
            "project.\(item.routeID)"
        case .skill(let item):
            "skill.\(item.routeID)"
        }
    }

    var title: String {
        switch self {
        case .employment:
            "Delete employment?"
        case .education:
            "Delete education?"
        case .certification:
            "Delete certification?"
        case .project:
            "Delete project?"
        case .skill:
            "Delete skill?"
        }
    }

    var message: String {
        switch self {
        case .employment(let item):
            "Delete \(item.company)? This change only completes after Kairo confirms it with the backend."
        case .education(let item):
            "Delete \(item.institution)? This record will remain until the backend confirms the delete."
        case .certification(let item):
            "Delete \(item.title)? This removes the current certification record if the backend accepts it."
        case .project(let item):
            "Delete \(item.title)? This project stays visible unless the backend confirms the delete."
        case .skill(let item):
            "Delete \(item.name)? This skill will disappear only after Kairo refetches the authoritative Career state."
        }
    }

    var confirmationAccessibilityIdentifier: String {
        switch self {
        case .employment:
            KairoAccessibilityID.careerEmploymentDeleteConfirmation
        case .education:
            KairoAccessibilityID.careerEducationDeleteConfirmation
        case .certification:
            KairoAccessibilityID.careerCertificationDeleteConfirmation
        case .project:
            KairoAccessibilityID.careerProjectDeleteConfirmation
        case .skill:
            KairoAccessibilityID.careerSkillDeleteConfirmation
        }
    }
}

struct CareerEmploymentEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: CareerMutationMode
    let seedDraft: CareerEmploymentDraft
    let onSave: (CareerEmploymentDraft) async throws -> Void

    @State private var draft: CareerEmploymentDraft
    @State private var isSaving = false
    @State private var presentationError: CareerMutationPresentationError?

    init(
        mode: CareerMutationMode,
        draft: CareerEmploymentDraft,
        onSave: @escaping (CareerEmploymentDraft) async throws -> Void
    ) {
        self.mode = mode
        seedDraft = draft
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    private var fieldErrors: [String: String] {
        draft.validationErrors().merging(presentationError?.fieldErrors ?? [:]) { current, _ in current }
    }

    private var canSave: Bool {
        fieldErrors.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            CareerMutationScaffold(
                title: mode == .create ? "Add Employment" : "Edit Employment",
                subtitle: "Create or update the backend-backed employment record shown in Career.",
                isSaving: isSaving,
                isSaveEnabled: canSave,
                saveTitle: mode == .create ? "Add Employment" : "Save Employment",
                onSave: save,
                onCancel: { dismiss() }
            ) {
                if let presentationError {
                    CareerMutationErrorCard(error: presentationError)
                }

                KairoCard {
                    KairoTextField(
                        title: "Employer legal name",
                        prompt: "Northstar Analytics Private Limited",
                        text: $draft.employerLegalName,
                        errorMessage: fieldErrors["employer_legal_name"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "employerLegalName")
                    )

                    KairoTextField(
                        title: "Employer trade name",
                        prompt: "Northstar Analytics",
                        text: $draft.employerTradeName,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "employerTradeName")
                    )

                    KairoTextField(
                        title: "Job title",
                        prompt: "Product Operations Manager",
                        text: $draft.jobTitle,
                        errorMessage: fieldErrors["job_title"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "jobTitle")
                    )

                    CareerSelectionMenu(
                        title: "Employment type",
                        value: draft.employmentType.title,
                        errorMessage: nil,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "employmentType")
                    ) {
                        ForEach(CareerEmploymentTypeOption.allCases) { option in
                            Button(option.title) {
                                draft.employmentType = option
                            }
                        }
                    }

                    CareerDateField(
                        title: "Start date",
                        selection: $draft.startDate,
                        errorMessage: nil,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "startDate")
                    )

                    Toggle("I'm currently working here", isOn: $draft.isCurrentlyWorking)
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("employment", "currentlyWorking"))

                    if !draft.isCurrentlyWorking {
                        CareerDateField(
                            title: "End date",
                            selection: $draft.endDate,
                            errorMessage: fieldErrors["end_date"],
                            accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "endDate")
                        )
                    }

                    KairoTextField(
                        title: "Work location country",
                        prompt: "India",
                        text: $draft.workLocationCountry,
                        errorMessage: fieldErrors["work_location_country"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "workLocationCountry")
                    )

                    KairoTextField(
                        title: "Work location region",
                        prompt: "Karnataka",
                        text: $draft.workLocationRegion,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("employment", "workLocationRegion")
                    )
                }
            }
            .interactiveDismissDisabled(isSaving)
            .disabled(isSaving)
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        presentationError = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: "Employment unavailable")
                await MainActor.run {
                    isSaving = false
                    presentationError = mapped
                }
            }
        }
    }
}

struct CareerEducationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: CareerMutationMode
    let seedDraft: CareerEducationDraft
    let onSave: (CareerEducationDraft) async throws -> Void

    @State private var draft: CareerEducationDraft
    @State private var isSaving = false
    @State private var presentationError: CareerMutationPresentationError?

    init(
        mode: CareerMutationMode,
        draft: CareerEducationDraft,
        onSave: @escaping (CareerEducationDraft) async throws -> Void
    ) {
        self.mode = mode
        seedDraft = draft
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    private var fieldErrors: [String: String] {
        draft.validationErrors().merging(presentationError?.fieldErrors ?? [:]) { current, _ in current }
    }

    private var canSave: Bool {
        fieldErrors.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            CareerMutationScaffold(
                title: mode == .create ? "Add Education" : "Edit Education",
                subtitle: "Create or update the canonical education record shown in Career.",
                isSaving: isSaving,
                isSaveEnabled: canSave,
                saveTitle: mode == .create ? "Add Education" : "Save Education",
                onSave: save,
                onCancel: { dismiss() }
            ) {
                if let presentationError {
                    CareerMutationErrorCard(error: presentationError)
                }

                KairoCard {
                    KairoTextField(
                        title: "Institution",
                        prompt: "Riverdale Institute of Technology",
                        text: $draft.institutionName,
                        errorMessage: fieldErrors["institution_name"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "institution")
                    )

                    KairoTextField(
                        title: "Degree",
                        prompt: "Bachelor of Technology",
                        text: $draft.degree,
                        errorMessage: fieldErrors["degree"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "degree")
                    )

                    KairoTextField(
                        title: "Field of study",
                        prompt: "Information Technology",
                        text: $draft.fieldOfStudy,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "fieldOfStudy")
                    )

                    CareerSelectionMenu(
                        title: "Education level",
                        value: draft.educationLevel?.title ?? "Choose the education level",
                        errorMessage: fieldErrors["education_level"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "educationLevel")
                    ) {
                        ForEach(CareerEducationLevelOption.allCases) { option in
                            Button(option.title) {
                                draft.educationLevel = option
                            }
                        }
                    }

                    KairoTextField(
                        title: "Grade",
                        prompt: "Optional",
                        text: $draft.grade,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "grade")
                    )

                    CareerDateField(
                        title: "Start date",
                        selection: $draft.startDate,
                        errorMessage: nil,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "startDate")
                    )

                    CareerSelectionMenu(
                        title: "Start date precision",
                        value: draft.startPrecision.title,
                        errorMessage: nil,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "startPrecision")
                    ) {
                        ForEach(CareerDatePrecisionOption.allCases) { option in
                            Button(option.title) {
                                draft.startPrecision = option
                            }
                        }
                    }

                    Toggle("I'm currently studying here", isOn: $draft.isCurrentlyStudying)
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("education", "currentlyStudying"))

                    if !draft.isCurrentlyStudying {
                        Toggle("Include an end date", isOn: $draft.includesEndDate)
                            .tint(KairoColors.brandPrimary)
                            .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("education", "includesEndDate"))
                    }

                    if !draft.isCurrentlyStudying, draft.includesEndDate {
                        CareerDateField(
                            title: "End date",
                            selection: $draft.endDate,
                            errorMessage: fieldErrors["end_date"],
                            accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "endDate")
                        )

                        CareerSelectionMenu(
                            title: "End date precision",
                            value: draft.endPrecision.title,
                            errorMessage: nil,
                            accessibilityIdentifier: KairoAccessibilityID.careerMutationField("education", "endPrecision")
                        ) {
                            ForEach(CareerDatePrecisionOption.allCases) { option in
                                Button(option.title) {
                                    draft.endPrecision = option
                                }
                            }
                        }
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .disabled(isSaving)
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        presentationError = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: "Education unavailable")
                await MainActor.run {
                    isSaving = false
                    presentationError = mapped
                }
            }
        }
    }
}

struct CareerCertificationEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: CareerMutationMode
    let seedDraft: CareerCertificationDraft
    let onSave: (CareerCertificationDraft) async throws -> Void

    @State private var draft: CareerCertificationDraft
    @State private var isSaving = false
    @State private var presentationError: CareerMutationPresentationError?

    init(
        mode: CareerMutationMode,
        draft: CareerCertificationDraft,
        onSave: @escaping (CareerCertificationDraft) async throws -> Void
    ) {
        self.mode = mode
        seedDraft = draft
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    private var fieldErrors: [String: String] {
        draft.validationErrors().merging(presentationError?.fieldErrors ?? [:]) { current, _ in current }
    }

    private var canSave: Bool {
        fieldErrors.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            CareerMutationScaffold(
                title: mode == .create ? "Add Certification" : "Edit Certification",
                subtitle: "Create or update the certification record shown in Career.",
                isSaving: isSaving,
                isSaveEnabled: canSave,
                saveTitle: mode == .create ? "Add Certification" : "Save Certification",
                onSave: save,
                onCancel: { dismiss() }
            ) {
                if let presentationError {
                    CareerMutationErrorCard(error: presentationError)
                }

                KairoCard {
                    KairoTextField(
                        title: "Certification title",
                        prompt: "Certified Scrum Product Owner",
                        text: $draft.title,
                        errorMessage: fieldErrors["title"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("certification", "title")
                    )

                    KairoTextField(
                        title: "Issuer",
                        prompt: "Scrum Alliance",
                        text: $draft.issuingOrganization,
                        errorMessage: fieldErrors["issuing_organization"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("certification", "issuer")
                    )

                    CareerDateField(
                        title: "Issue date",
                        selection: $draft.issuedDate,
                        errorMessage: nil,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("certification", "issuedDate")
                    )

                    Toggle("This certification never expires", isOn: $draft.doesNotExpire)
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("certification", "doesNotExpire"))

                    if !draft.doesNotExpire {
                        Toggle("Include an expiry date", isOn: $draft.includesExpiryDate)
                            .tint(KairoColors.brandPrimary)
                            .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("certification", "includesExpiryDate"))
                    }

                    if !draft.doesNotExpire, draft.includesExpiryDate {
                        CareerDateField(
                            title: "Expiry date",
                            selection: $draft.expiryDate,
                            errorMessage: fieldErrors["expiry_date"],
                            accessibilityIdentifier: KairoAccessibilityID.careerMutationField("certification", "expiryDate")
                        )
                    }

                    KairoTextField(
                        title: "Credential ID",
                        prompt: "Optional",
                        text: $draft.credentialID,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("certification", "credentialID")
                    )

                    KairoTextField(
                        title: "Credential URL",
                        prompt: "https://example.com/credential",
                        text: $draft.credentialURL,
                        errorMessage: fieldErrors["credential_url"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("certification", "credentialURL"),
                        keyboardType: .URL,
                        textInputAutocapitalization: .never
                    )
                }
            }
            .interactiveDismissDisabled(isSaving)
            .disabled(isSaving)
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        presentationError = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: "Certification unavailable")
                await MainActor.run {
                    isSaving = false
                    presentationError = mapped
                }
            }
        }
    }
}

struct CareerProjectEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: CareerMutationMode
    let seedDraft: CareerProjectDraft
    let onSave: (CareerProjectDraft) async throws -> Void

    @State private var draft: CareerProjectDraft
    @State private var isSaving = false
    @State private var presentationError: CareerMutationPresentationError?

    init(
        mode: CareerMutationMode,
        draft: CareerProjectDraft,
        onSave: @escaping (CareerProjectDraft) async throws -> Void
    ) {
        self.mode = mode
        seedDraft = draft
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    private var fieldErrors: [String: String] {
        draft.validationErrors().merging(presentationError?.fieldErrors ?? [:]) { current, _ in current }
    }

    private var canSave: Bool {
        fieldErrors.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            CareerMutationScaffold(
                title: mode == .create ? "Add Project" : "Edit Project",
                subtitle: "Create or update the canonical project record shown in Career.",
                isSaving: isSaving,
                isSaveEnabled: canSave,
                saveTitle: mode == .create ? "Add Project" : "Save Project",
                onSave: save,
                onCancel: { dismiss() }
            ) {
                if let presentationError {
                    CareerMutationErrorCard(error: presentationError)
                }

                KairoCard {
                    KairoTextField(
                        title: "Project title",
                        prompt: "Vendor Intelligence Platform",
                        text: $draft.title,
                        errorMessage: fieldErrors["title"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "title")
                    )

                    KairoTextField(
                        title: "Role",
                        prompt: "Program Lead",
                        text: $draft.role,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "role")
                    )

                    KairoTextField(
                        title: "Organization",
                        prompt: "Optional",
                        text: $draft.organizationName,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "organization")
                    )

                    KairoTextField(
                        title: "Description",
                        prompt: "Optional",
                        text: $draft.description,
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "description")
                    )

                    Toggle("Include a start date", isOn: $draft.includesStartDate)
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("project", "includesStartDate"))

                    if draft.includesStartDate {
                        CareerDateField(
                            title: "Start date",
                            selection: $draft.startDate,
                            errorMessage: nil,
                            accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "startDate")
                        )
                    }

                    Toggle("This project is ongoing", isOn: $draft.isOngoing)
                        .tint(KairoColors.brandPrimary)
                        .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("project", "isOngoing"))

                    if !draft.isOngoing {
                        Toggle("Include an end date", isOn: $draft.includesEndDate)
                            .tint(KairoColors.brandPrimary)
                            .accessibilityIdentifier(KairoAccessibilityID.careerMutationField("project", "includesEndDate"))
                    }

                    if !draft.isOngoing, draft.includesEndDate {
                        CareerDateField(
                            title: "End date",
                            selection: $draft.endDate,
                            errorMessage: fieldErrors["end_date"],
                            accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "endDate")
                        )
                    }

                    KairoTextField(
                        title: "Project URL",
                        prompt: "https://example.com/project",
                        text: $draft.projectURL,
                        errorMessage: fieldErrors["project_url"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "projectURL"),
                        keyboardType: .URL,
                        textInputAutocapitalization: .never
                    )

                    KairoTextField(
                        title: "Repository URL",
                        prompt: "https://github.com/example/repo",
                        text: $draft.repositoryURL,
                        errorMessage: fieldErrors["repository_url"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("project", "repositoryURL"),
                        keyboardType: .URL,
                        textInputAutocapitalization: .never
                    )
                }
            }
            .interactiveDismissDisabled(isSaving)
            .disabled(isSaving)
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        presentationError = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: "Project unavailable")
                await MainActor.run {
                    isSaving = false
                    presentationError = mapped
                }
            }
        }
    }
}

struct CareerSkillEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let mode: CareerMutationMode
    let existingNames: [String]
    let seedDraft: CareerSkillDraft
    let onSave: (CareerSkillDraft) async throws -> Void

    @State private var draft: CareerSkillDraft
    @State private var isSaving = false
    @State private var presentationError: CareerMutationPresentationError?

    init(
        mode: CareerMutationMode,
        existingNames: [String],
        draft: CareerSkillDraft,
        onSave: @escaping (CareerSkillDraft) async throws -> Void
    ) {
        self.mode = mode
        self.existingNames = existingNames
        seedDraft = draft
        self.onSave = onSave
        _draft = State(initialValue: draft)
    }

    private var fieldErrors: [String: String] {
        draft.validationErrors(existingNames: existingNames)
            .merging(presentationError?.fieldErrors ?? [:]) { current, _ in current }
    }

    private var canSave: Bool {
        fieldErrors.isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            CareerMutationScaffold(
                title: mode == .create ? "Add Skill" : "Edit Skill",
                subtitle: "Create or update the backend-backed skill associated with this candidate.",
                isSaving: isSaving,
                isSaveEnabled: canSave,
                saveTitle: mode == .create ? "Add Skill" : "Save Skill",
                onSave: save,
                onCancel: { dismiss() }
            ) {
                if let presentationError {
                    CareerMutationErrorCard(error: presentationError)
                }

                KairoCard {
                    KairoTextField(
                        title: "Skill name",
                        prompt: "SQL",
                        text: $draft.name,
                        errorMessage: fieldErrors["name"],
                        accessibilityIdentifier: KairoAccessibilityID.careerMutationField("skill", "name")
                    )
                }
            }
            .interactiveDismissDisabled(isSaving)
            .disabled(isSaving)
        }
    }

    private func save() {
        guard canSave else {
            return
        }

        presentationError = nil
        isSaving = true

        Task {
            do {
                try await onSave(draft)
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                let mapped = CareerMutationErrorMapper.map(error, fallbackTitle: "Skill unavailable")
                await MainActor.run {
                    isSaving = false
                    presentationError = mapped
                }
            }
        }
    }
}

private struct CareerMutationScaffold<Content: View>: View {
    let title: String
    let subtitle: String
    let isSaving: Bool
    let isSaveEnabled: Bool
    let saveTitle: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        KairoScreenContainer(
            title: title,
            subtitle: subtitle,
            titleAccessibilityIdentifier: "candidate.career.mutation.title",
            scrollBehavior: .scrolls
        ) {
            content

            VStack(spacing: KairoSpacing.medium) {
                KairoPrimaryButton(
                    title: saveTitle,
                    isLoading: isSaving,
                    accessibilityIdentifier: KairoAccessibilityID.careerMutationSave,
                    action: onSave
                )
                .disabled(!isSaveEnabled)

                KairoSecondaryButton(
                    title: "Cancel",
                    accessibilityIdentifier: KairoAccessibilityID.careerMutationCancel,
                    action: onCancel
                )
            }
        }
    }
}

private struct CareerMutationErrorCard: View {
    let error: CareerMutationPresentationError

    var body: some View {
        KairoCard {
            Text(error.title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.danger)

            Text(error.message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier(KairoAccessibilityID.careerMutationError)
    }
}

private struct CareerDateField: View {
    let title: String
    @Binding var selection: Date
    let errorMessage: String?
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(title)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            DatePicker(
                "",
                selection: $selection,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, KairoSpacing.medium)
            .padding(.vertical, KairoSpacing.medium)
            .background(KairoColors.surfaceMuted.opacity(0.65))
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                    .stroke(errorMessage == nil ? KairoColors.border : KairoColors.danger, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))
            .accessibilityIdentifier(accessibilityIdentifier)

            if let errorMessage {
                Text(errorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct CareerSelectionMenu<MenuContent: View>: View {
    let title: String
    let value: String
    let errorMessage: String?
    let accessibilityIdentifier: String
    @ViewBuilder let content: MenuContent

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(title)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            Menu {
                content
            } label: {
                HStack(spacing: KairoSpacing.small) {
                    Text(value)
                        .font(KairoTypography.body)
                        .foregroundStyle(value.hasPrefix("Choose ") ? KairoColors.textSecondary : KairoColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KairoColors.textSecondary)
                }
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.medium)
                .background(KairoColors.surfaceMuted.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .stroke(errorMessage == nil ? KairoColors.border : KairoColors.danger, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))
            }
            .accessibilityIdentifier(accessibilityIdentifier)

            if let errorMessage {
                Text(errorMessage)
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
