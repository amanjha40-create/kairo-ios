import SwiftUI

struct OnboardingFlowView: View {
    @Environment(\.appConfiguration) private var appConfiguration
    @Environment(\.manualProfileService) private var manualProfileService
    @EnvironmentObject private var router: AppRouter
    @State private var flowState: OnboardingFlowState
    private let createAccountInitialTouchedFields: Set<CreateAccountField>

    init() {
        let resolvedConfiguration = AppConfiguration.resolve()
        let createAccountConfiguration = UITestCreateAccountConfiguration.current()
        let verifyIdentityConfiguration = UITestVerifyIdentityConfiguration.current()
        let resumeImportConfiguration = UITestResumeImportConfiguration.current()
        let manualProfileConfiguration = UITestManualProfileConfiguration.current()
        let persistedManualProfileState: ManualProfileFlowState? =
            if resolvedConfiguration.isDemoModeEnabled || UITestLaunchConfiguration.current().isEnabled {
                nil
            } else {
                ManualProfileDraftStore.load()
            }
        let initialManualProfileState = manualProfileConfiguration.isActive
            ? manualProfileConfiguration.state
            : (persistedManualProfileState ?? ManualProfileFlowState())
        _flowState = State(initialValue: OnboardingFlowState(
            createAccountDraft: createAccountConfiguration.draft,
            verifyIdentityState: verifyIdentityConfiguration.state,
            chooseStartState: manualProfileConfiguration.isActive || persistedManualProfileState != nil
                ? ChooseStartState(selection: .buildProfileManually)
                : ChooseStartState(),
            resumeImportState: resumeImportConfiguration.state,
            manualProfileState: initialManualProfileState
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
                        LoginScreenView()
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
                ManualProfileScreenView(
                    state: $flowState.manualProfileState,
                    createAccountDraft: flowState.createAccountDraft
                )
            } else {
                ResumeImportScreenView(
                    createAccountDraft: flowState.createAccountDraft,
                    state: $flowState.resumeImportState,
                    onBuildProfileManually: {
                        flowState.chooseStartState.select(.buildProfileManually)
                    },
                    onContinueRemainingProfileCompletion: continueRemainingProfileCompletion
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

    private var shouldPersistManualProfileDraft: Bool {
        !appConfiguration.isDemoModeEnabled && !UITestLaunchConfiguration.current().isEnabled
    }

    private var signupDraftFullName: String? {
        CreateAccountValidation.normalizedFullName(
            firstName: flowState.createAccountDraft.firstName,
            lastName: flowState.createAccountDraft.lastName
        )
    }

    @MainActor
    private func continueRemainingProfileCompletion() async throws {
        let preparedDraft = try await manualProfileService.prepareRemainingProfileDraft(
            signupDraftFullName: signupDraftFullName
        )

        flowState.applyCompletedResumeImportHandoff(manualProfileState: preparedDraft)

        if shouldPersistManualProfileDraft {
            ManualProfileDraftStore.save(preparedDraft)
        }
    }
}
