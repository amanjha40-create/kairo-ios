import SwiftUI

struct OnboardingIllustrationPlaceholder: View {
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
                credentialCard(
                    tint: KairoColors.surfaceMuted,
                    border: KairoColors.border,
                    rotation: -10,
                    xOffset: -26,
                    yOffset: -6
                )

                credentialCard(
                    tint: KairoColors.surface,
                    border: KairoColors.border,
                    rotation: 9,
                    xOffset: 28,
                    yOffset: 6
                )

                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .fill(KairoColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                            .stroke(KairoColors.border, lineWidth: 1)
                    )
                    .frame(maxWidth: 270, maxHeight: 176)
                    .overlay(mainCredentialContent.padding(KairoSpacing.large))
            }
            .padding(KairoSpacing.xxLarge)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.05, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private func credentialCard(
        tint: Color,
        border: Color,
        rotation: Double,
        xOffset: CGFloat,
        yOffset: CGFloat
    ) -> some View {
        RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
            .fill(tint)
            .overlay(
                RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
            .frame(maxWidth: 244, maxHeight: 158)
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
    }

    private var mainCredentialContent: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.medium) {
            HStack {
                Circle()
                    .fill(KairoColors.accent)
                    .frame(width: 12, height: 12)

                Spacer()

                Capsule()
                    .fill(KairoColors.surfaceMuted)
                    .frame(width: 56, height: 10)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Capsule()
                    .fill(KairoColors.textPrimary.opacity(0.14))
                    .frame(width: 118, height: 12)

                Capsule()
                    .fill(KairoColors.textPrimary.opacity(0.1))
                    .frame(width: 162, height: 10)

                HStack(spacing: KairoSpacing.small) {
                    Capsule()
                        .fill(KairoColors.brandPrimary.opacity(0.18))
                        .frame(width: 72, height: 28)
                        .overlay(
                            Text("Verified")
                                .font(KairoTypography.caption)
                                .foregroundStyle(KairoColors.brandPrimary)
                        )

                    Spacer()
                }
            }
        }
    }
}

struct OnboardingActionGroup: View {
    let primaryTitle: String
    let primaryAccessibilityIdentifier: String?
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAccessibilityIdentifier: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: KairoSpacing.small) {
            KairoPrimaryButton(
                title: primaryTitle,
                accessibilityIdentifier: primaryAccessibilityIdentifier,
                action: primaryAction
            )

            if let secondaryTitle, let secondaryAction {
                KairoSecondaryButton(
                    title: secondaryTitle,
                    accessibilityIdentifier: secondaryAccessibilityIdentifier,
                    action: secondaryAction
                )
            }
        }
        .accessibilityElement(children: .contain)
    }
}
