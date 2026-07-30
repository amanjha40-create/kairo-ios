import SwiftUI

struct ManualProfileScreenView: View {
    @Binding var state: ManualProfileFlowState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        switch state.step {
        case .basicProfile:
            BasicProfileStepView(
                draft: $state.basicProfile,
                onContinue: {
                    state.advance()
                },
                onBack: {
                    router.goBackOnboarding(from: .resumeImportOrQuickProfile)
                }
            )
        case .employment:
            EmploymentStepView(
                state: $state,
                onContinue: {
                    state.advance()
                },
                onBack: {
                    state.goBack()
                }
            )
        case .education:
            EducationStepView(
                state: $state,
                onContinue: {
                    router.advanceOnboarding(from: .resumeImportOrQuickProfile)
                },
                onBack: {
                    state.goBack()
                }
            )
        }
    }
}

private struct BasicProfileStepView: View {
    @Binding var draft: ManualProfileBasicDraft
    let onContinue: () -> Void
    let onBack: () -> Void

    @State private var attemptedSubmission = false

    var body: some View {
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
                KairoCard {
                    Text("Start with the details that anchor your professional identity in Kairo.")
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoCard {
                    VStack(spacing: KairoSpacing.medium) {
                        KairoTextField(
                            title: "Professional Headline",
                            prompt: "Optional",
                            text: $draft.professionalHeadline,
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileHeadline,
                            accessibilityLabel: "Professional headline",
                            textContentType: .jobTitle,
                            textInputAutocapitalization: .words
                        )

                        KairoTextField(
                            title: "Current City",
                            prompt: "Enter your current city",
                            text: $draft.currentCity,
                            errorMessage: basicError(for: .currentCity),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileCurrentCity,
                            accessibilityLabel: "Current city",
                            textInputAutocapitalization: .words
                        )

                        KairoTextField(
                            title: "Current Country",
                            prompt: "Enter your current country",
                            text: $draft.currentCountry,
                            errorMessage: basicError(for: .currentCountry),
                            accessibilityIdentifier: KairoAccessibilityID.manualProfileCurrentCountry,
                            accessibilityLabel: "Current country",
                            textInputAutocapitalization: .words
                        )
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
    }

    private func basicError(for field: ManualProfileBasicField) -> String? {
        guard attemptedSubmission else {
            return nil
        }

        return ManualProfileValidation.basicProfileError(for: field, in: draft)
    }

    private func handleContinue() {
        guard ManualProfileValidation.isBasicProfileValid(draft) else {
            attemptedSubmission = true
            return
        }

        onContinue()
    }
}

private struct EmploymentStepView: View {
    @Binding var state: ManualProfileFlowState
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
                KairoCard {
                    Text("Add the roles you most want reflected in your Trust Passport. You can refine them later.")
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
                                title: "Company",
                                prompt: "Enter the company",
                                text: employmentBinding(for: entry.id, keyPath: \.company),
                                errorMessage: employmentError(for: .company, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentCompany(index),
                                accessibilityLabel: "Company \(index + 1)",
                                textInputAutocapitalization: .words
                            )

                            KairoTextField(
                                title: "Job Title",
                                prompt: "Enter your job title",
                                text: employmentBinding(for: entry.id, keyPath: \.jobTitle),
                                errorMessage: employmentError(for: .jobTitle, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentJobTitle(index),
                                accessibilityLabel: "Job title \(index + 1)",
                                textContentType: .jobTitle,
                                textInputAutocapitalization: .words
                            )

                            KairoTextField(
                                title: "Employment Type",
                                prompt: "Full-time, part-time, contract...",
                                text: employmentBinding(for: entry.id, keyPath: \.employmentType),
                                errorMessage: employmentError(for: .employmentType, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentType(index),
                                accessibilityLabel: "Employment type \(index + 1)",
                                textInputAutocapitalization: .words
                            )

                            ResponsiveFieldPair {
                                KairoTextField(
                                    title: "Start Month",
                                    prompt: "e.g. January",
                                    text: employmentBinding(for: entry.id, keyPath: \.startMonth),
                                    errorMessage: employmentError(for: .startMonth, in: entry),
                                    accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentStartMonth(index),
                                    accessibilityLabel: "Start month \(index + 1)",
                                    textInputAutocapitalization: .words
                                )
                            } trailing: {
                                KairoTextField(
                                    title: "Start Year",
                                    prompt: "YYYY",
                                    text: employmentBinding(for: entry.id, keyPath: \.startYear),
                                    errorMessage: employmentError(for: .startYear, in: entry),
                                    accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentStartYear(index),
                                    accessibilityLabel: "Start year \(index + 1)",
                                    keyboardType: .numberPad
                                )
                            }

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

                            if !entry.isCurrentlyWorking {
                                ResponsiveFieldPair {
                                    KairoTextField(
                                        title: "End Month",
                                        prompt: "e.g. January",
                                        text: employmentBinding(for: entry.id, keyPath: \.endMonth),
                                        errorMessage: employmentError(for: .endMonth, in: entry),
                                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentEndMonth(index),
                                        accessibilityLabel: "End month \(index + 1)",
                                        textInputAutocapitalization: .words
                                    )
                                } trailing: {
                                    KairoTextField(
                                        title: "End Year",
                                        prompt: "YYYY",
                                        text: employmentBinding(for: entry.id, keyPath: \.endYear),
                                        errorMessage: employmentError(for: .endYear, in: entry),
                                        accessibilityIdentifier: KairoAccessibilityID.manualProfileEmploymentEndYear(index),
                                        accessibilityLabel: "End year \(index + 1)",
                                        keyboardType: .numberPad
                                    )
                                }
                            }
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
                KairoCard {
                    Text("Add the learning foundations you want associated with your professional trust.")
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
                                title: "Institution",
                                prompt: "Enter the institution",
                                text: educationBinding(for: entry.id, keyPath: \.institution),
                                errorMessage: educationError(for: .institution, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationInstitution(index),
                                accessibilityLabel: "Institution \(index + 1)",
                                textInputAutocapitalization: .words
                            )

                            KairoTextField(
                                title: "Degree",
                                prompt: "Enter the degree",
                                text: educationBinding(for: entry.id, keyPath: \.degree),
                                errorMessage: educationError(for: .degree, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationDegree(index),
                                accessibilityLabel: "Degree \(index + 1)",
                                textInputAutocapitalization: .words
                            )

                            KairoTextField(
                                title: "Field of Study",
                                prompt: "Enter the field of study",
                                text: educationBinding(for: entry.id, keyPath: \.fieldOfStudy),
                                errorMessage: educationError(for: .fieldOfStudy, in: entry),
                                accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationFieldOfStudy(index),
                                accessibilityLabel: "Field of study \(index + 1)",
                                textInputAutocapitalization: .words
                            )

                            ResponsiveFieldPair {
                                KairoTextField(
                                    title: "Start Year",
                                    prompt: "YYYY",
                                    text: educationBinding(for: entry.id, keyPath: \.startYear),
                                    errorMessage: educationError(for: .startYear, in: entry),
                                    accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationStartYear(index),
                                    accessibilityLabel: "Education start year \(index + 1)",
                                    keyboardType: .numberPad
                                )
                            } trailing: {
                                KairoTextField(
                                    title: "End Year",
                                    prompt: "YYYY",
                                    text: educationBinding(for: entry.id, keyPath: \.endYear),
                                    errorMessage: educationError(for: .endYear, in: entry),
                                    accessibilityIdentifier: KairoAccessibilityID.manualProfileEducationEndYear(index),
                                    accessibilityLabel: "Education end year \(index + 1)",
                                    keyboardType: .numberPad
                                )
                            }
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
            }
        } actions: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
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
