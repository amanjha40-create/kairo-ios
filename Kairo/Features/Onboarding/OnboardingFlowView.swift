import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var flowState: OnboardingFlowState
    private let createAccountInitialTouchedFields: Set<CreateAccountField>

    init() {
        let uiTestConfiguration = UITestCreateAccountConfiguration.current()
        _flowState = State(initialValue: OnboardingFlowState(
            createAccountDraft: uiTestConfiguration.draft
        ))
        createAccountInitialTouchedFields = uiTestConfiguration.touchedFields
    }

    var body: some View {
        NavigationStack(path: $router.onboardingPath) {
            WelcomeScreenView()
                .navigationDestination(for: OnboardingDestination.self) { destination in
                    switch destination {
                    case .step(let step):
                        destinationView(for: step)
                    case .loginPlaceholder:
                        LoginPlaceholderScreen()
                    }
                }
        }
    }

    @ViewBuilder
    private func destinationView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeScreenView()
        case .createAccount:
            CreateAccountScreenView(
                draft: $flowState.createAccountDraft,
                initialTouchedFields: createAccountInitialTouchedFields,
                onContinue: beginVerifyIdentity
            )
        case .verifyIdentity:
            VerifyIdentityScreenView(
                createAccountDraft: $flowState.createAccountDraft,
                state: $flowState.verifyIdentityState
            )
        case .chooseStart, .resumeImportOrQuickProfile, .passportCreated:
            OnboardingPlaceholderScreen(step: step)
        }
    }

    private func beginVerifyIdentity() {
        flowState.verifyIdentityState = VerifyIdentityFlowState()
        router.advanceOnboarding(from: .createAccount)
    }
}
