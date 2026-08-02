import SwiftUI

struct WelcomeScreenView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        OnboardingScreenLayout(
            eyebrow: "Once verified. Always yours.",
            title: "Your trust.\nYour career.\nAnywhere.",
            subtitle: "Build, own, and share your professional trust\nthat moves with you.",
            titleAccessibilityIdentifier: OnboardingStep.welcome.titleAccessibilityIdentifier
        ) {
            OnboardingIllustrationPlaceholder()
                .frame(maxWidth: 216)
        } content: {
            EmptyView()
        } actions: {
            OnboardingActionGroup(
                primaryTitle: "Get Started",
                primaryAccessibilityIdentifier: KairoAccessibilityID.onboardingGetStarted,
                primaryAction: { router.advanceOnboarding(from: .welcome) },
                secondaryTitle: "I already have an account",
                secondaryAccessibilityIdentifier: KairoAccessibilityID.onboardingExistingAccount,
                secondaryAction: { router.showLogin() }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
