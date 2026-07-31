import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var flowState: OnboardingFlowState
    private let createAccountInitialTouchedFields: Set<CreateAccountField>

    init() {
        let createAccountConfiguration = UITestCreateAccountConfiguration.current()
        let verifyIdentityConfiguration = UITestVerifyIdentityConfiguration.current()
        let resumeImportConfiguration = UITestResumeImportConfiguration.current()
        let manualProfileConfiguration = UITestManualProfileConfiguration.current()
        _flowState = State(initialValue: OnboardingFlowState(
            createAccountDraft: createAccountConfiguration.draft,
            verifyIdentityState: verifyIdentityConfiguration.state,
            chooseStartState: manualProfileConfiguration.isActive
                ? ChooseStartState(selection: .buildProfileManually)
                : ChooseStartState(),
            resumeImportState: resumeImportConfiguration.state,
            manualProfileState: manualProfileConfiguration.state
        ))
        createAccountInitialTouchedFields = createAccountConfiguration.touchedFields
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
        case .chooseStart:
            ChooseStartScreenView(state: $flowState.chooseStartState)
        case .resumeImportOrQuickProfile:
            if flowState.chooseStartState.selection == .buildProfileManually {
                ManualProfileScreenView(state: $flowState.manualProfileState)
            } else {
                ResumeImportScreenView(
                    createAccountDraft: flowState.createAccountDraft,
                    state: $flowState.resumeImportState,
                    onBuildProfileManually: {
                        flowState.chooseStartState.select(.buildProfileManually)
                    }
                )
            }
        case .passportCreated:
            PassportCreatedScreenView(state: flowState.passportCreatedState)
        }
    }

    private func beginVerifyIdentity() {
        flowState.verifyIdentityState = VerifyIdentityFlowState()
        router.advanceOnboarding(from: .createAccount)
    }
}
