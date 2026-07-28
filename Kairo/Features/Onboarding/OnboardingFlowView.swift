import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.onboardingPath) {
            OnboardingPlaceholderScreen(step: .welcome)
                .navigationDestination(for: OnboardingStep.self) { step in
                    OnboardingPlaceholderScreen(step: step)
                }
        }
    }
}
