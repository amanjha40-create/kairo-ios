import SwiftUI

struct TabPlaceholderScreen: View {
    let tab: CandidateTab

    @EnvironmentObject private var router: AppRouter
    @Environment(\.appConfiguration) private var appConfiguration

    var body: some View {
        KairoScreenContainer(
            title: tab.title,
            subtitle: "The locked candidate tab shell is in place. Real \(tab.title) content will be added in a later milestone.",
            titleAccessibilityIdentifier: tab.titleAccessibilityIdentifier
        ) {
            KairoCard {
                Text("Navigation Verified")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)
                    .accessibilityIdentifier(KairoAccessibilityID.candidateNavigationVerified)
                Text("This placeholder confirms the permanent tab order: Home, Career, Verify, Passport, More.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            KairoLoadingStateView(
                title: "Foundation Ready",
                message: "Loading, empty, and error building blocks are now available to future feature screens."
            )

            KairoErrorStateView(
                title: "No Live Data Connected",
                message: appConfiguration.isDemoModeEnabled
                    ? "Demo Mode is active, so network requests are intentionally disabled."
                    : "API integration is intentionally deferred for this milestone.",
                messageAccessibilityIdentifier: KairoAccessibilityID.candidateNetworkStatusMessage
            )

            KairoSecondaryButton(
                title: "Return to Welcome",
                action: { router.showOnboarding() }
            )
        }
    }
}
