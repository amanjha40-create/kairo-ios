import SwiftUI

struct PassportCreatedScreenView: View {
    let state: PassportCreatedState

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        OnboardingScreenLayout(
            layoutMode: .task,
            eyebrow: "Verify once. Trusted everywhere.",
            title: state.title,
            subtitle: state.subtitle,
            titleAccessibilityIdentifier: OnboardingStep.passportCreated.titleAccessibilityIdentifier
        ) {
            PassportCreatedIllustration()
                .frame(maxWidth: 192)
        } content: {
            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                PassportCreatedSupportingCopy(text: state.supportingCopy)

                PassportCreatedSummaryCard(rows: state.summaryRows)
                    .accessibilityIdentifier(KairoAccessibilityID.passportCreatedSummary)

                PassportCreatedTrustScoreCard(
                    title: state.trustScoreTitle,
                    message: state.trustScoreMessage
                )
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
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text("This is only the beginning.")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text(text.replacingOccurrences(of: "This is only the beginning.\n\n", with: ""))
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct PassportCreatedSummaryCard: View {
    let rows: [PassportCreatedState.SummaryRow]

    var body: some View {
        KairoCard {
            Text("Passport Summary")
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            VStack(spacing: KairoSpacing.small) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    VStack(spacing: KairoSpacing.small) {
                        HStack(alignment: .firstTextBaseline, spacing: KairoSpacing.small) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title)
                                    .font(KairoTypography.bodyStrong)
                                    .foregroundStyle(KairoColors.textPrimary)

                                Text(row.status.rawValue)
                                    .font(KairoTypography.footnote)
                                    .foregroundStyle(KairoColors.textSecondary)
                            }

                            Spacer(minLength: KairoSpacing.small)

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text(row.status.rawValue)
                                    .font(KairoTypography.caption)
                            }
                            .foregroundStyle(KairoColors.success)
                            .frame(minWidth: 84, alignment: .leading)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(row.title), \(row.status.rawValue)")

                        if index < rows.index(before: rows.endIndex) {
                            Divider()
                                .overlay(KairoColors.border)
                        }
                    }
                }
            }
        }
    }
}

private struct PassportCreatedTrustScoreCard: View {
    let title: String
    let message: String

    var body: some View {
        KairoCard {
            Text(title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)

            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(KairoAccessibilityID.passportCreatedTrustScoreMessage)
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
                    .frame(width: 214, height: 152)
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
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(KairoColors.success)
            }

            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Capsule()
                    .fill(KairoColors.textPrimary.opacity(0.12))
                    .frame(width: 124, height: 12)

                Capsule()
                    .fill(KairoColors.textPrimary.opacity(0.08))
                    .frame(width: 154, height: 10)
            }

            Spacer(minLength: 0)

            HStack(spacing: KairoSpacing.small) {
                statusBadge(title: "Verified", tint: KairoColors.success.opacity(0.16), text: KairoColors.success)
                statusBadge(title: "Active", tint: KairoColors.brandPrimary.opacity(0.12), text: KairoColors.brandPrimary)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(KairoColors.surface, in: Capsule())
        .overlay(
            Capsule()
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .kairoShadow(KairoShadow.card)
    }

    private func statusBadge(title: String, tint: Color, text: Color) -> some View {
        Text(title)
            .font(KairoTypography.caption)
            .foregroundStyle(text)
            .padding(.horizontal, KairoSpacing.small)
            .padding(.vertical, 6)
            .background(tint, in: Capsule())
    }
}
