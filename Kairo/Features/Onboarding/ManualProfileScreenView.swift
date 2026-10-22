import SwiftUI

struct ManualProfileScreenView: View {
    @Binding var state: ManualProfileFlowState
    let createAccountDraft: CreateAccountDraft

    @Environment(\.manualProfileService) private var manualProfileService
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var sessionStore: AppSessionStore

    @State private var isSubmitting = false
    @State private var serverErrorMessage: String?
    @State private var profileBackendErrors: [ManualProfileBasicField: String] = [:]
    @State private var employmentBackendErrors: [Int: [ManualEmploymentField: String]] = [:]
    @State private var educationBackendErrors: [Int: [ManualEducationField: String]] = [:]

    var body: some View {
        Group {
            switch state.step {
            case .basicProfile:
                BasicProfileStepView(
                    draft: $state.basicProfile,
                    backendErrors: profileBackendErrors,
                    serverErrorMessage: serverErrorMessage,
                    onContinue: {
                        clearSubmissionFeedback()
                        state.advance()
                    },
                    onBack: {
                        clearSubmissionFeedback()
                        router.goBackOnboarding(from: .resumeImportOrQuickProfile)
                    }
                )
            case .employment:
                EmploymentStepView(
                    state: $state,
                    backendErrors: employmentBackendErrors,
                    serverErrorMessage: serverErrorMessage,
                    onContinue: {
                        clearSubmissionFeedback()
                        state.advance()
                    },
                    onBack: {
                        clearSubmissionFeedback()
                        state.goBack()
                    }
                )
            case .education:
                EducationStepView(
                    state: $state,
                    backendErrors: educationBackendErrors,
                    serverErrorMessage: serverErrorMessage,
                    isSubmitting: isSubmitting,
                    onContinue: submitManualProfile,
                    onBack: {
                        clearSubmissionFeedback()
                        state.goBack()
                    }
                )
            }
        }
        .task(id: fullNamePrefillSeed) {
            state.reconcileBasicProfilePrefill(
                backendFullName: sessionStore.currentUser?.fullName,
                signupDraftFullName: signupDraftFullName
            )
        }
        .onChange(of: state) { _, newValue in
            guard shouldPersistDraft else {
                return
            }

            ManualProfileDraftStore.save(newValue)
        }
    }

    private var shouldPersistDraft: Bool {
        !UITestLaunchConfiguration.current().isEnabled && !AppConfiguration.resolve().isDemoModeEnabled
    }

    private var signupDraftFullName: String? {
        CreateAccountValidation.normalizedFullName(
            firstName: createAccountDraft.firstName,
            lastName: createAccountDraft.lastName
        )
    }

    private var fullNamePrefillSeed: String {
        [
            sessionStore.currentUser?.fullName ?? "",
            signupDraftFullName ?? ""
        ].joined(separator: "|")
    }

    private func submitManualProfile() {
        guard !isSubmitting else {
            return
        }

        clearSubmissionFeedback()
        isSubmitting = true
        let submissionState = state

        Task {
            do {
                _ = try await manualProfileService.submit(draft: submissionState)

                await MainActor.run {
                    isSubmitting = false
                    if shouldPersistDraft {
                        ManualProfileDraftStore.clear()
                    }
                    router.advanceOnboarding(from: .resumeImportOrQuickProfile)
                }
            } catch let error as ManualProfileSubmissionError {
                await MainActor.run {
                    isSubmitting = false
                    applySubmissionError(error)
                }
            } catch {
                if requiresSessionRecovery(for: error) {
                    await sessionStore.refreshLaunchRoute()
                    await MainActor.run {
                        isSubmitting = false
                    }
                    return
                }

                await MainActor.run {
                    isSubmitting = false
                    serverErrorMessage = message(for: error)
                }
            }
        }
    }

    private func clearSubmissionFeedback() {
        serverErrorMessage = nil
        profileBackendErrors = [:]
        employmentBackendErrors = [:]
        educationBackendErrors = [:]
    }

    private func applySubmissionError(_ error: ManualProfileSubmissionError) {
        switch error {
        case .missingRequiredAccountData(let message):
            serverErrorMessage = message
            state.step = .basicProfile
        case .onboardingIncomplete(let onboardingStatus):
            serverErrorMessage = onboardingIncompleteMessage(for: onboardingStatus)
            state.step = .basicProfile
        case .fieldValidation(let step, let fieldErrors, let message):
            serverErrorMessage = message
            switch step {
            case .basicProfile:
                state.step = .basicProfile
                profileBackendErrors = fieldErrors.reduce(into: [ManualProfileBasicField: String]()) { partialResult, pair in
                    if let field = profileField(for: pair.key) {
                        partialResult[field] = pair.value
                    }
                }
            case .employment(let entryID):
                state.step = .employment
                employmentBackendErrors[entryID] = fieldErrors.reduce(into: [ManualEmploymentField: String]()) { partialResult, pair in
                    if let field = employmentField(for: pair.key) {
                        partialResult[field] = pair.value
                    }
                }
            case .education(let entryID):
                state.step = .education
                educationBackendErrors[entryID] = fieldErrors.reduce(into: [ManualEducationField: String]()) { partialResult, pair in
                    if let field = educationField(for: pair.key) {
                        partialResult[field] = pair.value
                    }
                }
            case .completion:
                serverErrorMessage = message
            }
        }
    }

    private func onboardingIncompleteMessage(for status: OnboardingStatusResponseDTO) -> String {
        guard !status.missingRequirements.isEmpty else {
            return "KairoID saved your profile, but onboarding is still incomplete. Please review your details and try again."
        }

        return "KairoID still needs: \(status.missingRequirements.joined(separator: ", "))."
    }

    private func requiresSessionRecovery(for error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError, sessionError == .sessionExpired {
            return true
        }

        if let networkError = error as? NetworkError,
           case .api(let apiError) = networkError,
           apiError.code == .unauthorized {
            return true
        }

        return false
    }

    private func message(for error: Error) -> String {
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .api:
                return "Review your profile details and try again."
            case .transport:
                return "KairoID couldn't reach the network. Check your connection and try again."
            case .unavailableInDemoMode:
                return "Demo Mode keeps Manual Profile local."
            case .invalidResponse:
                return "KairoID received an unexpected Manual Profile response. Please try again."
            case .invalidURL:
                return "KairoID's Manual Profile configuration is invalid."
            }
        case let sessionError as SessionServiceError:
            return sessionError.errorDescription ?? "KairoID couldn't continue your Manual Profile."
        default:
            return "KairoID couldn't save your profile. Please try again."
        }
    }

    private func profileField(for key: String) -> ManualProfileBasicField? {
        switch key {
        case "full_name", "fullName", "name":
            .fullName
        case "headline":
            .professionalHeadline
        case "current_role":
            .currentRole
        case "industry":
            .industry
        case "years_of_experience":
            .yearsOfExperience
        case "location_city":
            .currentCity
        case "location_country":
            .currentCountry
        default:
            nil
        }
    }

    private func employmentField(for key: String) -> ManualEmploymentField? {
        switch key {
        case "employer_legal_name":
            .company
        case "job_title":
            .jobTitle
        case "employment_type":
            .employmentType
        case "work_location_country":
            .workCountry
        case "start_date":
            .startDay
        case "end_date":
            .endDay
        default:
            nil
        }
    }

    private func educationField(for key: String) -> ManualEducationField? {
        switch key {
        case "institution_name":
            .institution
        case "degree":
            .degree
        case "education_level":
            .educationLevel
        case "field_of_study":
            .fieldOfStudy
        case "start_date":
            .startYear
        case "end_date":
            .endYear
        default:
            nil
        }
    }
}

private struct BasicProfileStepView: View {
    @Binding var draft: ManualProfileBasicDraft
    let backendErrors: [ManualProfileBasicField: String]
    let serverErrorMessage: String?
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var attemptedSubmission = false
    @FocusState private var focusedField: ManualProfileBasicField?

    var body: some View {
        ScrollViewReader { proxy in
        OnboardingScreenLayout(
            layoutMode: .task,
            eyebrow: ManualProfileStep.basicProfile.stepLabel,
            title: ManualProfileStep.basicProfile.title,
            subtitle: ManualProfileStep.basicProfile.subtitle,
            titleAccessibilityIdentifier: ManualProfileStep.basicProfile.titleAccessibilityIdentifier
        ) {
            ManualProfileHero(step: .basicProfile)
                .frame(maxWidth: 132)
        } content: {
            VStack(spacing: KairoSpacing.medium) {
                if firstInvalidField != nil {
                    Text("Check the highlighted profile details before continuing.")
                        .font(KairoTypography.footnote).foregroundStyle(KairoColors.danger)
                        .accessibilityIdentifier("onboarding.manualProfile.validationSummary")
                }
                if let serverErrorMessage {
                    ManualProfileInlineMessage(message: serverErrorMessage)
                }

                KairoCard {
                    Text("Start with the profile details KairoID needs to create a reusable Trust Passport foundation.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoCard {
                    VStack(spacing: KairoSpacing.medium) {
                        KairoTextField(
                            title: "Full Name *",
                            prompt: "Enter your full name",
                            text: $draft.fullName,
                            errorMessage: basicError(for: .fullName),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileFullName,
                            accessibilityLabel: "Full name, required",
                            textContentType: .name,
                            textInputAutocapitalization: .words,
                            focus: $focusedField, focusedField: .fullName
                        )
                        .id(ManualProfileBasicField.fullName)

                        KairoTextField(
                            title: "Professional Headline *",
                            prompt: "Describe your professional focus",
                            text: $draft.professionalHeadline,
                            errorMessage: basicError(for: .professionalHeadline),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileHeadline,
                            accessibilityLabel: "Professional headline, required",
                            textContentType: .jobTitle,
                            textInputAutocapitalization: .words,
                            focus: $focusedField, focusedField: .professionalHeadline
                        )
                        .id(ManualProfileBasicField.professionalHeadline)

                        KairoTextField(
                            title: "Current Role *",
                            prompt: "Enter your current role",
                            text: $draft.currentRole,
                            errorMessage: basicError(for: .currentRole),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileCurrentRole,
                            accessibilityLabel: "Current role, required",
                            textContentType: .jobTitle,
                            textInputAutocapitalization: .words,
                            focus: $focusedField, focusedField: .currentRole
                        )
                        .id(ManualProfileBasicField.currentRole)

                        KairoTextField(
                            title: "Industry *",
                            prompt: "Enter your industry",
                            text: $draft.industry,
                            errorMessage: basicError(for: .industry),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileIndustry,
                            accessibilityLabel: "Industry, required",
                            textInputAutocapitalization: .words,
                            focus: $focusedField, focusedField: .industry
                        )
                        .id(ManualProfileBasicField.industry)

                        KairoTextField(
                            title: "Years of Experience *",
                            prompt: "Whole years",
                            text: $draft.yearsOfExperience,
                            errorMessage: basicError(for: .yearsOfExperience),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileYearsOfExperience,
                            accessibilityLabel: "Years of experience, required",
                            keyboardType: .numberPad,
                            focus: $focusedField, focusedField: .yearsOfExperience
                        )
                        .id(ManualProfileBasicField.yearsOfExperience)

                        CandidateLocationFields(country: $draft.currentCountry,
                            region: Binding(get: { draft.currentRegion ?? "" }, set: { draft.currentRegion = $0 }),
                            city: $draft.currentCity, identifier: "candidate.manualProfile.location")
                        if let error = basicError(for: .currentCity) { Text(error).foregroundStyle(KairoColors.danger) }
                        if let error = basicError(for: .currentCountry) { Text(error).foregroundStyle(KairoColors.danger) }
                    }
                }
            }
        } actions: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileBasicContinue,
                        action: handleContinue
                    )

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileBasicBack,
                        action: onBack
                    )
                }

                VStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileBasicContinue,
                        action: handleContinue
                    )

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileBasicBack,
                        action: onBack
                    )
                }
            }
        }
        .onChange(of: focusedField) { _, field in
            if let field { proxy.scrollTo(field, anchor: .center) }
        }
        .onChange(of: backendErrors) { _, _ in
            focusedField = firstInvalidField
        }
        }
    }

    private var firstInvalidField: ManualProfileBasicField? {
        ManualProfileBasicField.allCases.first { basicError(for: $0) != nil }
    }

    private func basicError(for field: ManualProfileBasicField) -> String? {
        if let backendMessage = backendErrors[field] {
            return backendMessage
        }

        guard attemptedSubmission else {
            return nil
        }

        return ManualProfileValidation.basicProfileError(for: field, in: draft)
    }

    private func handleContinue() {
        guard ManualProfileValidation.isBasicProfileValid(draft) else {
            attemptedSubmission = true
            focusedField = ManualProfileBasicField.allCases.first {
                ManualProfileValidation.basicProfileError(for: $0, in: draft) != nil
            }
            return
        }

        onContinue()
    }
}

private struct EmploymentStepView: View {
    @Binding var state: ManualProfileFlowState
    let backendErrors: [Int: [ManualEmploymentField: String]]
    let serverErrorMessage: String?
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var attemptedSubmission = false

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .task,
            eyebrow: ManualProfileStep.employment.stepLabel,
            title: ManualProfileStep.employment.title,
            subtitle: ManualProfileStep.employment.subtitle,
            titleAccessibilityIdentifier: ManualProfileStep.employment.titleAccessibilityIdentifier
        ) {
            ManualProfileHero(step: .employment)
                .frame(maxWidth: 128)
        } content: {
            VStack(spacing: KairoSpacing.medium) {
                if let serverErrorMessage {
                    ManualProfileInlineMessage(message: serverErrorMessage)
                }

                KairoCard {
                    Text("Add each role with an exact country and full calendar dates so KairoID can persist it accurately.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(state.employmentEntries.enumerated()), id: \.element.id) { index, entry in
                    KairoCard {
                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Role \(index + 1)")
                                    .font(KairoTypography.title2)
                                    .foregroundStyle(KairoColors.textPrimary)

                                Spacer()

                                Button("Delete") {
                                    state.deleteEmployment(id: entry.id)
                                }
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                                .accessibilityIdentifier(
                                    KairoAccessibilityID.manualProfileEmploymentDelete(index)
                                )
                            }

                            KairoTextField(
                                title: "Company *",
                                prompt: "Enter the company",
                                text: employmentBinding(for: entry.id, keyPath: \.company),
                                errorMessage: employmentError(for: .company, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentCompany(index),
                                accessibilityLabel: "Company \(index + 1), required",
                                textInputAutocapitalization: .words
                            )

                            KairoTextField(
                                title: "Job Title *",
                                prompt: "Enter your job title",
                                text: employmentBinding(for: entry.id, keyPath: \.jobTitle),
                                errorMessage: employmentError(for: .jobTitle, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentJobTitle(index),
                                accessibilityLabel: "Job title \(index + 1), required",
                                textContentType: .jobTitle,
                                textInputAutocapitalization: .words
                            )

                            CandidatePlacePicker(title: "Employment type", value: ManualProfileNormalization.normalizedEmploymentType(entry.employmentType) ?? entry.employmentType, options: CareerEmploymentTypeOption.allCases.map(\.rawValue), display: { CareerEmploymentTypeOption(rawValue: $0)?.title ?? $0 }) { value in state.updateEmployment(id: entry.id) { $0.employmentType = value } }
                                .accessibilityIdentifier(KairoAccessibilityID.manualProfileEmploymentType(index))
                            if let error = employmentError(for: .employmentType, in: entry) { Text(error).foregroundStyle(KairoColors.danger) }
                            CandidatePlacePicker(title: "Work country", value: entry.workCountry, options: Locale.Region.isoRegions.map(\.identifier), allowClear: true, display: CandidateLocationCatalogue.countryName) { value in state.updateEmployment(id: entry.id) { $0.workCountry = value } }
                                .accessibilityIdentifier(KairoAccessibilityID.manualProfileEmploymentCountry(index))
                            if let error = employmentError(for: .workCountry, in: entry) { Text(error).foregroundStyle(KairoColors.danger) }
                            CandidateDateField(title: "Start date", selection: employmentDateBinding(entry.id, end: false), required: true, hasIncompleteValue: ![entry.startDay, entry.startMonth, entry.startYear].allSatisfy(\.isEmpty), errorMessage: employmentError(for: .startDay, in: entry) ?? employmentError(for: .startMonth, in: entry) ?? employmentError(for: .startYear, in: entry), identifier: "manual.employment.\(index).startDate")

                            Toggle(isOn: employmentToggleBinding(for: entry.id)) {
                                Text("Currently working here")
                                    .font(KairoTypography.body)
                                    .foregroundStyle(KairoColors.textPrimary)
                            }
                            .toggleStyle(.switch)
                            .tint(KairoColors.brandPrimary)
                            .accessibilityIdentifier(
                                KairoAccessibilityID.manualProfileEmploymentCurrentToggle(index)
                            )

                            CandidateDateField(title: "End date", selection: employmentDateBinding(entry.id, end: true), disabled: entry.isCurrentlyWorking, hasIncompleteValue: ![entry.endDay, entry.endMonth, entry.endYear].allSatisfy(\.isEmpty), errorMessage: employmentError(for: .endDay, in: entry) ?? employmentError(for: .endMonth, in: entry) ?? employmentError(for: .endYear, in: entry), identifier: "manual.employment.\(index).endDate")
                        }
                    }
                }

                ManualProfileAddButton(
                    title: "Add another employment",
                    accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentAdd,
                    action: {
                        state.addEmployment()
                    }
                )
                KairoSecondaryButton(title: "Continue without employment", action: {
                    state.skipEmployment()
                    onContinue()
                })
            }
        } actions: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentContinue,
                        action: handleContinue
                    )

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentBack,
                        action: onBack
                    )
                }

                VStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentContinue,
                        action: handleContinue
                    )

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentBack,
                        action: onBack
                    )
                }
            }
        }
    }

    private func employmentBinding(
        for entryID: Int,
        keyPath: WritableKeyPath<ManualEmploymentEntry, String>
    ) -> Binding<String> {
        Binding(
            get: {
                state.employmentEntries.first(where: { $0.id == entryID })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                state.updateEmployment(id: entryID) { entry in
                    entry[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func employmentDateBinding(_ id: Int, end: Bool) -> Binding<Date?> {
        Binding(get: {
            guard let entry = state.employmentEntries.first(where: { $0.id == id }) else { return nil }
            let year = end ? entry.endYear : entry.startYear
            guard let month = ManualProfileNormalization.normalizedMonthNumber(end ? entry.endMonth : entry.startMonth),
                  let day = Int(end ? entry.endDay : entry.startDay) else { return nil }
            return CandidateDateInput.date(year: year, month: month, day: day)
        }, set: { value in
            state.updateEmployment(id: id) { entry in
                let components = value.map { CandidateDateInput.calendar.dateComponents([.day, .month, .year], from: $0) }
                if end { entry.endDay = components?.day.map(String.init) ?? ""; entry.endMonth = components?.month.map(String.init) ?? ""; entry.endYear = components?.year.map(String.init) ?? "" }
                else { entry.startDay = components?.day.map(String.init) ?? ""; entry.startMonth = components?.month.map(String.init) ?? ""; entry.startYear = components?.year.map(String.init) ?? "" }
            }
        })
    }

    private func employmentToggleBinding(for entryID: Int) -> Binding<Bool> {
        Binding(
            get: {
                state.employmentEntries.first(where: { $0.id == entryID })?.isCurrentlyWorking ?? false
            },
            set: { newValue in
                state.updateEmployment(id: entryID) { entry in
                    entry.isCurrentlyWorking = newValue
                }
            }
        )
    }

    private func employmentError(
        for field: ManualEmploymentField,
        in entry: ManualEmploymentEntry
    ) -> String? {
        if let backendMessage = backendErrors[entry.id]?[field] {
            return backendMessage
        }

        guard attemptedSubmission else {
            return nil
        }

        return ManualProfileValidation.employmentError(for: field, in: entry)
    }

    private func handleContinue() {
        guard ManualProfileValidation.areEmploymentEntriesValid(state.employmentEntries) else {
            attemptedSubmission = true
            return
        }

        onContinue()
    }
}

private struct EducationStepView: View {
    @Binding var state: ManualProfileFlowState
    let backendErrors: [Int: [ManualEducationField: String]]
    let serverErrorMessage: String?
    let isSubmitting: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var attemptedSubmission = false

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .task,
            eyebrow: ManualProfileStep.education.stepLabel,
            title: ManualProfileStep.education.title,
            subtitle: ManualProfileStep.education.subtitle,
            titleAccessibilityIdentifier: ManualProfileStep.education.titleAccessibilityIdentifier
        ) {
            ManualProfileHero(step: .education)
                .frame(maxWidth: 124)
        } content: {
            VStack(spacing: KairoSpacing.medium) {
                if let serverErrorMessage {
                    ManualProfileInlineMessage(message: serverErrorMessage)
                }

                KairoCard {
                    Text("Add each credential at the right level so KairoID can classify and verify it cleanly.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(Array(state.educationEntries.enumerated()), id: \.element.id) { index, entry in
                    KairoCard {
                        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Education \(index + 1)")
                                    .font(KairoTypography.title2)
                                    .foregroundStyle(KairoColors.textPrimary)

                                Spacer()

                                Button("Delete") {
                                    state.deleteEducation(id: entry.id)
                                }
                                .font(KairoTypography.footnote)
                                .foregroundStyle(KairoColors.textSecondary)
                                .accessibilityIdentifier(
                                    KairoAccessibilityID.manualProfileEducationDelete(index)
                                )
                            }

                            KairoTextField(
                                title: "Institution *",
                                prompt: "Enter the institution",
                                text: educationBinding(for: entry.id, keyPath: \.institution),
                                errorMessage: educationError(for: .institution, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationInstitution(index),
                                accessibilityLabel: "Institution \(index + 1), required",
                                textInputAutocapitalization: .words
                            )

                            CandidateDegreeField(degree: educationBinding(for: entry.id, keyPath: \.degree),
                                required: true, identifier: KairoAccessibilityID.manualProfileEducationDegree(index))
                            if let error = educationError(for: .degree, in: entry) {
                                Text(error).foregroundStyle(KairoColors.danger).fixedSize(horizontal: false, vertical: true)
                            }
                            CandidatePlacePicker(title: "Education level", value: ManualProfileNormalization.normalizedEducationLevel(entry.educationLevel) ?? entry.educationLevel, options: CareerEducationLevelOption.allCases.map(\.rawValue), required: true, display: { CareerEducationLevelOption(rawValue: $0)?.title ?? $0 }) { value in state.updateEducation(id: entry.id) { $0.educationLevel = value } }
                                .accessibilityIdentifier(KairoAccessibilityID.manualProfileEducationLevel(index))
                            if let error = educationError(for: .educationLevel, in: entry) {
                                Text(error).foregroundStyle(KairoColors.danger).fixedSize(horizontal: false, vertical: true)
                            }

                            KairoTextField(
                                title: "Field of Study — Optional",
                                prompt: "Enter the field of study",
                                text: educationBinding(for: entry.id, keyPath: \.fieldOfStudy),
                                errorMessage: educationError(for: .fieldOfStudy, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationFieldOfStudy(index),
                                accessibilityLabel: "Field of study \(index + 1), optional",
                                textInputAutocapitalization: .words
                            )

                            CandidateDateField(title: "Start year", selection: educationYearBinding(entry.id, end: false), precision: .year, required: true, hasIncompleteValue: !entry.startYear.isEmpty, errorMessage: educationError(for: .startYear, in: entry), identifier: "manual.education.\(index).startDate")
                            Toggle("Currently studying here", isOn: Binding(get: { entry.isCurrentlyStudying == true }, set: { value in state.updateEducation(id: entry.id) { $0.isCurrentlyStudying = value } }))
                            CandidateDateField(title: "End year", selection: educationYearBinding(entry.id, end: true), precision: .year, disabled: entry.isCurrentlyStudying == true, hasIncompleteValue: !entry.endYear.isEmpty, errorMessage: educationError(for: .endYear, in: entry), identifier: "manual.education.\(index).endDate")
                        }
                    }
                }

                ManualProfileAddButton(
                    title: "Add another education",
                    accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationAdd,
                    action: {
                        state.addEducation()
                    }
                )
                KairoSecondaryButton(title: "Continue without education", action: {
                    state.skipEducation()
                    onContinue()
                })
                .disabled(isSubmitting)
            }
        } actions: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        isLoading: isSubmitting,
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationContinue,
                        action: handleContinue
                    )

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationBack,
                        action: onBack
                    )
                }

                VStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        isLoading: isSubmitting,
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationContinue,
                        action: handleContinue
                    )

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationBack,
                        action: onBack
                    )
                }
            }
        }
    }

    private func educationYearBinding(_ id: Int, end: Bool) -> Binding<Date?> {
        Binding(get: {
            guard let entry = state.educationEntries.first(where: { $0.id == id }) else { return nil }
            return CandidateDateInput.date(year: end ? entry.endYear : entry.startYear)
        }, set: { value in
            let year = value.map { String(CandidateDateInput.calendar.component(.year, from: $0)) } ?? ""
            state.updateEducation(id: id) { entry in if end { entry.endYear = year } else { entry.startYear = year } }
        })
    }

    private func educationBinding(
        for entryID: Int,
        keyPath: WritableKeyPath<ManualEducationEntry, String>
    ) -> Binding<String> {
        Binding(
            get: {
                state.educationEntries.first(where: { $0.id == entryID })?[keyPath: keyPath] ?? ""
            },
            set: { newValue in
                state.updateEducation(id: entryID) { entry in
                    entry[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func educationError(
        for field: ManualEducationField,
        in entry: ManualEducationEntry
    ) -> String? {
        if let backendMessage = backendErrors[entry.id]?[field] {
            return backendMessage
        }

        guard attemptedSubmission else {
            return nil
        }

        return ManualProfileValidation.educationError(for: field, in: entry)
    }

    private func handleContinue() {
        guard ManualProfileValidation.areEducationEntriesValid(state.educationEntries) else {
            attemptedSubmission = true
            return
        }

        onContinue()
    }
}

private struct ManualProfileInlineMessage: View {
    let message: String

    var body: some View {
        KairoCard {
            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ManualProfileAddButton: View {
    let title: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus.circle.fill")
                .font(KairoTypography.bodyStrong)
                .foregroundStyle(KairoColors.brandPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, KairoSpacing.medium)
                .padding(.horizontal, KairoSpacing.medium)
                .background(KairoColors.brandPrimary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                        .stroke(KairoColors.brandPrimary.opacity(0.16), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct ManualProfileDateTriplet<Day: View, Month: View, Year: View>: View {
    let title: String
    let dayField: Day
    let monthField: Month
    let yearField: Year

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            Text(title)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: KairoSpacing.medium) {
                    dayField
                    monthField
                    yearField
                }

                VStack(spacing: KairoSpacing.medium) {
                    dayField
                    monthField
                    yearField
                }
            }
        }
    }
}

private struct ResponsiveFieldPair<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: KairoSpacing.medium) {
                leading
                trailing
            }

            VStack(spacing: KairoSpacing.medium) {
                leading
                trailing
            }
        }
    }
}

private struct ManualProfileHero: View {
    let step: ManualProfileStep

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .fill(KairoColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            VStack(spacing: KairoSpacing.medium) {
                HStack(spacing: KairoSpacing.small) {
                    Circle()
                        .fill(KairoColors.brandPrimary.opacity(0.14))
                        .frame(width: 28, height: 28)
                        .overlay(
                            Image(systemName: iconName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(KairoColors.brandPrimary)
                        )

                    Capsule()
                        .fill(KairoColors.textPrimary.opacity(0.1))
                        .frame(width: 54, height: 8)
                }

                VStack(spacing: KairoSpacing.small) {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .fill(KairoColors.surfaceMuted)
                        .frame(height: 38)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(KairoColors.textPrimary.opacity(0.12))
                                .frame(width: 76, height: 8)
                                .padding(.horizontal, KairoSpacing.medium)
                        }

                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .fill(KairoColors.surfaceMuted.opacity(step == .basicProfile ? 0.65 : 1))
                        .frame(height: 38)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(KairoColors.textPrimary.opacity(0.08))
                                .frame(width: step == .education ? 82 : 70, height: 8)
                                .padding(.horizontal, KairoSpacing.medium)
                        }

                    if step != .basicProfile {
                        RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                            .fill(KairoColors.surfaceMuted.opacity(0.7))
                            .frame(height: 38)
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(KairoColors.textPrimary.opacity(0.08))
                                    .frame(width: 64, height: 8)
                                    .padding(.horizontal, KairoSpacing.medium)
                            }
                    }
                }
            }
            .padding(KairoSpacing.large)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.02, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var iconName: String {
        switch step {
        case .basicProfile:
            "person.crop.rectangle"
        case .employment:
            "briefcase"
        case .education:
            "graduationcap"
        }
    }
}
