import Foundation

nonisolated struct OnboardingStatusResponseDTO: Decodable, Equatable, Sendable {
    nonisolated enum CurrentStep: String, Equatable, Sendable {
        case verifyIdentity = "verify_identity"
        case completeProfile = "complete_profile"
        case complete
    }

    let currentStep: String
    let emailVerified: Bool
    let phoneVerified: Bool
    let passportReady: Bool
    let completedSteps: [String]
    let missingRequirements: [String]
    let nextRecommendedStep: String?
    let completionPercentage: Int
    let isOnboardingComplete: Bool

    nonisolated init(
        currentStep: String,
        emailVerified: Bool,
        phoneVerified: Bool,
        passportReady: Bool,
        completedSteps: [String],
        missingRequirements: [String],
        nextRecommendedStep: String?,
        completionPercentage: Int,
        isOnboardingComplete: Bool
    ) {
        self.currentStep = currentStep
        self.emailVerified = emailVerified
        self.phoneVerified = phoneVerified
        self.passportReady = passportReady
        self.completedSteps = completedSteps
        self.missingRequirements = missingRequirements
        self.nextRecommendedStep = nextRecommendedStep
        self.completionPercentage = completionPercentage
        self.isOnboardingComplete = isOnboardingComplete
    }

    var resolvedCurrentStep: CurrentStep? {
        CurrentStep(rawValue: currentStep)
    }

    nonisolated static func fixture(
        currentStep: CurrentStep,
        emailVerified: Bool = true,
        phoneVerified: Bool = true,
        passportReady: Bool = false,
        completedSteps: [String] = [],
        missingRequirements: [String] = [],
        nextRecommendedStep: String? = nil,
        completionPercentage: Int = 0,
        isOnboardingComplete: Bool = false
    ) -> OnboardingStatusResponseDTO {
        OnboardingStatusResponseDTO(
            currentStep: currentStep.rawValue,
            emailVerified: emailVerified,
            phoneVerified: phoneVerified,
            passportReady: passportReady,
            completedSteps: completedSteps,
            missingRequirements: missingRequirements,
            nextRecommendedStep: nextRecommendedStep,
            completionPercentage: completionPercentage,
            isOnboardingComplete: isOnboardingComplete
        )
    }
}
