import SwiftUI

struct PassportCreatedScreenView: View {
    let state: PassportCreatedState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .form,
            eyebrow: "Verify once. Trusted everywhere.",
            title: state.title,
            subtitle: state.subtitle,
            titleAccessibilityIdentifier: OnboardingStep.passportCreated.titleAccessibilityIdentifier
        ) {
            EmptyView()
        } content: {
            VStack(spacing: KairoSpacing.medium) {
                PassportCreatedIllustration()
                    .frame(maxWidth: 132)
                    .frame(maxWidth: .infinity, alignment: .center)

                PassportCreatedSupportingCopy(state: state)
            }
        } actions: {
            OnboardingActionGroup(
                primaryTitle: state.primaryActionTitle,
                primaryAccessibilityIdentifier: KairoAccessibilityID.passportCreatedContinueHome,
                primaryAction: { router.enterMainTabs(selectedTab: .home) },
                secondaryTitle: state.reviewDestination == nil ? nil : state.secondaryActionTitle,
                secondaryAccessibilityIdentifier: KairoAccessibilityID.passportCreatedReviewProfile,
                secondaryAction: reviewProfileAction
            )
        }
    }

    private var reviewProfileAction: (() -> Void)? {
        guard let reviewDestination = state.reviewDestination else {
            return nil
        }

        return {
            router.enterMainTabs(selectedTab: reviewDestination)
        }
    }
}

private struct PassportCreatedSupportingCopy: View {
    let state: PassportCreatedState

    var body: some View {
        KairoCard {
            Text(state.supportingCopy)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PassportCreatedIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                .fill(KairoColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            ZStack {
                Circle()
                    .fill(KairoColors.brandPrimary.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .offset(x: 18, y: -14)

                Circle()
                    .fill(KairoColors.accent.opacity(0.12))
                    .frame(width: 116, height: 116)
                    .offset(x: -44, y: 34)

                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .fill(KairoColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                            .stroke(KairoColors.border, lineWidth: 1)
                    )
                    .frame(width: 188, height: 132)
                    .overlay(passportContent.padding(KairoSpacing.large))

                growthPill
                    .offset(x: 74, y: 48)
            }
            .padding(KairoSpacing.xxLarge)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.08, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var passportContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            HStack(spacing: KairoSpacing.small) {
                Circle()
                    .fill(KairoColors.brandPrimary)
                    .frame(width: 14, height: 14)

                Capsule()
                    .fill(KairoColors.brandPrimary.opacity(0.16))
                    .frame(width: 82, height: 12)

                Spacer(minLength: 0)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(KairoColors.success)
            }

            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Capsule()
                    .fill(KairoColors.textPrimary.opacity(0.12))
                    .frame(width: 108, height: 10)

                Capsule()
                    .fill(KairoColors.textPrimary.opacity(0.08))
                    .frame(width: 128, height: 9)
            }

            Spacer(minLength: 0)

            HStack(spacing: KairoSpacing.small) {
                abstractBadge(width: 60, tint: KairoColors.brandPrimary.opacity(0.12))
                abstractBadge(width: 46, tint: KairoColors.success.opacity(0.12))
            }
        }
    }

    private var growthPill: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(KairoColors.brandPrimary)

            Capsule()
                .fill(KairoColors.brandPrimary.opacity(0.16))
                .frame(width: 4, height: 34)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(KairoColors.surface, in: Capsule())
        .overlay(
            Capsule()
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .kairoShadow(KairoShadow.card)
    }

    private func abstractBadge(width: CGFloat, tint: Color) -> some View {
        Capsule()
            .fill(tint)
            .frame(width: width, height: 28)
            .overlay(
                Capsule()
                    .fill(KairoColors.surface.opacity(0.75))
                    .frame(width: width * 0.44, height: 7)
            )
    }
}
