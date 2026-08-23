import SwiftUI

struct ChooseStartScreenView: View {
    @Binding var state: ChooseStartState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Choose your starting point",
            title: "How would you like to begin?",
            subtitle: "Choose how you'd like to begin building your Trust Passport.",
            titleAccessibilityIdentifier: OnboardingStep.chooseStart.titleAccessibilityIdentifier
        ) {
            EmptyView()
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

    private var backgroundColor: Color {
        switch (option, isSelected) {
        case (.importResume, true):
            KairoColors.brandPrimary.opacity(0.08)
        case (.buildProfileManually, true):
            KairoColors.surfaceMuted
        case (.importResume, false):
            KairoColors.surface
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
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: KairoSpacing.small)

                    selectionBadge
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
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
