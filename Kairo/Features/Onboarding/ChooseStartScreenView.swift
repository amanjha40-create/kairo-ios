import SwiftUI

struct ChooseStartScreenView: View {
    @Binding var state: ChooseStartState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .choice,
            eyebrow: nil,
            title: "How would you like to begin?",
            subtitle: "Choose how you'd like to begin building your Trust Passport.",
            titleAccessibilityIdentifier: OnboardingStep.chooseStart.titleAccessibilityIdentifier
        ) {
            ChooseStartHero()
                .frame(maxWidth: 72)
        } content: {
            VStack(spacing: KairoSpacing.small) {
                ForEach(ChooseStartOption.allCases) { option in
                    ChooseStartOptionCard(
                        option: option,
                        isSelected: state.selection == option,
                        action: { state.select(option) }
                    )
                }
            }
        } actions: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        accessibilityIdentifier: KairoAccessibilityID.chooseStartContinue,
                        action: { router.advanceOnboarding(from: .chooseStart) }
                    )
                    .disabled(!state.canContinue)

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                        action: { router.goBackOnboarding(from: .chooseStart) }
                    )
                }

                VStack(spacing: KairoSpacing.small) {
                    KairoPrimaryButton(
                        title: "Continue",
                        accessibilityIdentifier: KairoAccessibilityID.chooseStartContinue,
                        action: { router.advanceOnboarding(from: .chooseStart) }
                    )
                    .disabled(!state.canContinue)

                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                        action: { router.goBackOnboarding(from: .chooseStart) }
                    )
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

private struct ChooseStartOptionCard: View {
    let option: ChooseStartOption
    let isSelected: Bool
    let action: () -> Void

    private var iconTint: Color {
        switch option {
        case .importResume:
            KairoColors.brandPrimary
        case .buildProfileManually:
            KairoColors.textPrimary
        }
    }

    private var accentColor: Color {
        switch option {
        case .importResume:
            KairoColors.brandPrimary
        case .buildProfileManually:
            KairoColors.textPrimary
        }
    }

    private var backgroundColor: Color {
        switch (option, isSelected) {
        case (.importResume, true):
            KairoColors.brandPrimary.opacity(0.1)
        case (.buildProfileManually, true):
            KairoColors.surfaceMuted
        case (.importResume, false):
            KairoColors.brandPrimary.opacity(0.04)
        case (.buildProfileManually, false):
            KairoColors.surface
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                HStack(alignment: .top, spacing: KairoSpacing.medium) {
                    iconBadge

                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                        Text(option.title)
                            .font(KairoTypography.bodyStrong)
                            .foregroundStyle(KairoColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(option.supportingCopy)
                            .font(KairoTypography.footnote)
                            .foregroundStyle(KairoColors.textSecondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Spacer(minLength: KairoSpacing.small)

                    selectionBadge
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .stroke(
                        isSelected ? KairoColors.brandPrimary : KairoColors.border,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
            .kairoShadow(KairoShadow.card)
            .contentShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(option.accessibilityIdentifier)
        .accessibilityLabel(option.title)
        .accessibilityHint(option.supportingCopy.replacingOccurrences(of: "\n", with: " "))
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var iconBadge: some View {
        RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
            .fill(iconTint.opacity(option == .importResume ? 0.14 : 0.08))
            .frame(width: 38, height: 38)
            .overlay(
                Image(systemName: option.systemImage)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(iconTint)
            )
    }

    private var selectionBadge: some View {
        Group {
            if isSelected {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.brandPrimary)
                    .padding(.horizontal, KairoSpacing.xSmall)
                    .padding(.vertical, 6)
                    .background(KairoColors.brandPrimary.opacity(0.1), in: Capsule())
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(KairoColors.border)
                    .padding(.top, 2)
            }
        }
    }
}

private struct ChooseStartHero: View {
    var body: some View {
        HStack(spacing: KairoSpacing.small) {
            branchBadge(
                systemImage: ChooseStartOption.importResume.systemImage,
                tint: KairoColors.brandPrimary
            )

            passportMarker

            branchBadge(
                systemImage: ChooseStartOption.buildProfileManually.systemImage,
                tint: KairoColors.textPrimary
            )
        }
        .accessibilityHidden(true)
    }

    private func branchBadge(systemImage: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
            .fill(tint.opacity(0.1))
            .frame(width: 22, height: 22)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(tint)
            )
    }

    private var passportMarker: some View {
        RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
            .fill(KairoColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .stroke(KairoColors.border, lineWidth: 1)
            )
            .frame(width: 28, height: 18)
            .overlay(
                Capsule()
                    .fill(KairoColors.brandPrimary.opacity(0.16))
                    .frame(width: 16, height: 6)
            )
            .kairoShadow(KairoShadow.card)
    }
}

struct ChooseStartDestinationPlaceholderScreen: View {
    let selection: ChooseStartOption?

    @EnvironmentObject private var router: AppRouter

    private var resolvedSelection: ChooseStartOption {
        selection ?? .importResume
    }

    var body: some View {
        OnboardingScreenLayout(
            eyebrow: "Coming Next",
            title: resolvedSelection.placeholderTitle,
            subtitle: resolvedSelection.placeholderSubtitle,
            titleAccessibilityIdentifier: resolvedSelection.placeholderTitleAccessibilityIdentifier
        ) {
            ChooseStartDestinationHero(option: resolvedSelection)
                .frame(maxWidth: 152)
        } content: {
            KairoCard {
                Text(resolvedSelection.placeholderMessage)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            OnboardingActionGroup(
                primaryTitle: "Continue",
                primaryAccessibilityIdentifier: KairoAccessibilityID.onboardingContinue,
                primaryAction: { router.advanceOnboarding(from: .resumeImportOrQuickProfile) },
                secondaryTitle: "Back",
                secondaryAccessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                secondaryAction: { router.goBackOnboarding(from: .resumeImportOrQuickProfile) }
            )
        }
    }
}

private struct ChooseStartDestinationHero: View {
    let option: ChooseStartOption

    private var tint: Color {
        option == .importResume ? KairoColors.brandPrimary : KairoColors.textPrimary
    }

    var body: some View {
        RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
            .fill(KairoColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                    .stroke(KairoColors.border, lineWidth: 1)
            )
            .kairoShadow(KairoShadow.card)
            .overlay(
                VStack(spacing: KairoSpacing.medium) {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Image(systemName: option.systemImage)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(tint)
                        )

                    Capsule()
                        .fill(KairoColors.surfaceMuted)
                        .frame(width: 84, height: 10)
                }
                .padding(KairoSpacing.large)
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(1.04, contentMode: .fit)
            .accessibilityHidden(true)
    }
}
