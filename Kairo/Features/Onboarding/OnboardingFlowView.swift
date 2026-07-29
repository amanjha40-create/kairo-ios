import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.onboardingPath) {
            WelcomeScreenView()
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .step(let step):
                        if step == .welcome {
                            WelcomeScreenView()
                        } else {
                            OnboardingPlaceholderScreen(step: step)
                        }
                    case .loginPlaceholder:
                        LoginPlaceholderScreen()
                    }
                }
        }
    }
}
