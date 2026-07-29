import SwiftUI

struct OnboardingPlaceholderScreen: View {
    let step: OnboardingStep

    @EnvironmentObject private var router: AppRouter

    var body: some View {
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
}
