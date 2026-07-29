import SwiftUI

struct OnboardingPlaceholderScreen: View {
    let step: OnboardingStep

    @EnvironmentObject private var router: AppRouter

    var body: some View {
        if step == .createAccount {
            createAccountPlaceholder
        } else {
            genericPlaceholder
        }
    }

    private var genericPlaceholder: some View {
        OnboardingScreenLayout(
            eyebrow: "Coming Next",
            title: step.title,
            subtitle: step.subtitle,
            titleAccessibilityIdentifier: step.titleAccessibilityIdentifier
        ) {
            OnboardingIllustrationPlaceholder()
        } content: {
            KairoCard {
                Text("Product content is intentionally deferred.")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("This placeholder keeps the locked onboarding flow testable while the real \(step.title) experience is still pending.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            OnboardingActionGroup(
                primaryTitle: step.next == nil ? "Enter Home" : "Continue",
                primaryAccessibilityIdentifier: KairoAccessibilityID.onboardingContinue,
                primaryAction: { router.advanceOnboarding(from: step) },
                secondaryTitle: "Back",
                secondaryAccessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                secondaryAction: { router.goBackOnboarding(from: step) }
            )
        }
    }

    private var createAccountPlaceholder: some View {
        OnboardingScreenLayout(
            eyebrow: "Coming Next",
            title: "Create your account",
            subtitle: "Account creation arrives next milestone. This placeholder keeps the locked route available for onboarding validation today.",
            titleAccessibilityIdentifier: step.titleAccessibilityIdentifier
        ) {
            createAccountHero
        } content: {
            KairoCard {
                Text("Placeholder only")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Real account creation ships next milestone.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            OnboardingActionGroup(
                primaryTitle: "Continue",
                primaryAccessibilityIdentifier: KairoAccessibilityID.onboardingContinue,
                primaryAction: { router.advanceOnboarding(from: step) },
                secondaryTitle: nil,
                secondaryAccessibilityIdentifier: nil,
                secondaryAction: nil
            )
        }
    }

    private var createAccountHero: some View {
        ZStack {
            Circle()
                .fill(KairoColors.surface)
                .overlay(
                    Circle()
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .kairoShadow(KairoShadow.card)

            Image(systemName: "person.badge.plus")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(KairoColors.brandPrimary)
        }
        .frame(width: 84, height: 84)
    }
}
