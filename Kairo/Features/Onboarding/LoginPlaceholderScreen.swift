import SwiftUI

struct LoginPlaceholderScreen: View {
    var body: some View {
        OnboardingScreenLayout(
            eyebrow: "Future Route",
            title: "Login",
            subtitle: "This placeholder confirms that returning candidates can route into the future sign-in experience without changing the locked onboarding sequence.",
            titleAccessibilityIdentifier: KairoAccessibilityID.onboardingLoginTitle
        ) {
            OnboardingIllustrationPlaceholder()
        } content: {
            KairoCard {
                Text("Login is intentionally deferred.")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("Authentication, OTP, and backend integration remain out of scope for this milestone.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } actions: {
            EmptyView()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(KairoAccessibilityID.onboardingLoginScreen)
    }
}
