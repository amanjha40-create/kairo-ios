import SwiftUI

struct ChooseStartScreenView: View {
    @Binding var state: ChooseStartState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Step 3 of 5",
            title: "How would you like to start?",
            subtitle: "Pick the fastest way to build your Trust Passport.",
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

    private var backgroundColor: Color {
        isSelected ? KairoColors.accent.opacity(0.08) : KairoColors.surface
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
            .padding(KairoSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .stroke(
                        isSelected ? KairoColors.accent : KairoColors.border,
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
            .fill(Color(hex: 0x07122B))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: option.systemImage)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
            )
    }

    private var selectionBadge: some View {
        Group {
            if isSelected {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.accent)
                    .padding(.horizontal, KairoSpacing.xSmall)
                    .padding(.vertical, 6)
                    .background(KairoColors.accent.opacity(0.1), in: Capsule())
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(KairoColors.border)
                    .padding(.top, 2)
            }
        }
    }
}
