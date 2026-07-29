import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var createAccountDraft = CreateAccountDraft()
    private let createAccountInitialTouchedFields: Set<CreateAccountField>

    init() {
        let uiTestConfiguration = UITestCreateAccountConfiguration.current()
        _createAccountDraft = State(initialValue: uiTestConfiguration.draft)
        createAccountInitialTouchedFields = uiTestConfiguration.touchedFields
    }

    var body: some View {
        NavigationStack(path: $router.onboardingPath) {
            WelcomeScreenView()
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .step(let step):
                        if step == .welcome {
                            WelcomeScreenView()
                        } else if step == .createAccount {
                            CreateAccountScreenView(
                                draft: $createAccountDraft,
                                initialTouchedFields: createAccountInitialTouchedFields
                            )
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
