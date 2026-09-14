import SwiftUI

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
