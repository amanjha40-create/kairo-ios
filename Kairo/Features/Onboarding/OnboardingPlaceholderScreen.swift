import SwiftUI

struct OnboardingPlaceholderScreen: View {
    let step: OnboardingStep

    @EnvironmentObject private var router: AppRouter
    @State private var sampleInput = ""

    var body: some View {
        KairoScreenContainer(
            title: step.title,
            subtitle: "Navigation is wired to the locked onboarding flow while product content remains intentionally unimplemented.",
            titleAccessibilityIdentifier: step.titleAccessibilityIdentifier
        ) {
            KairoCard {
                Text("Foundation Placeholder")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                Text(step.subtitle)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            KairoTextField(
                title: "Sample Input",
                prompt: "Used only to validate the reusable text field foundation",
                text: $sampleInput
            )

            KairoEmptyStateView(
                title: "No Product Screen Yet",
                message: "This milestone sets up navigation, shared UI, and app infrastructure without building the actual \(step.title) screen.",
                systemImage: "square.stack.3d.up"
            )

            VStack(spacing: KairoSpacing.small) {
                KairoPrimaryButton(
                    title: step.next == nil ? "Enter Home" : "Continue",
                    accessibilityIdentifier: KairoAccessibilityID.onboardingContinue,
                    action: { router.advanceOnboarding(from: step) }
                )

                if step != .welcome {
                    KairoSecondaryButton(
                        title: "Back",
                        accessibilityIdentifier: KairoAccessibilityID.onboardingBack,
                        action: { router.goBackOnboarding(from: step) }
                    )
                }
            }
        }
    }
}
