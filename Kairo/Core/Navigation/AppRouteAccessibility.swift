import Foundation

extension OnboardingStep {
    var titleAccessibilityIdentifier: String {
        "onboarding.step.\(rawValue)"
    }
}

extension CandidateTab {
    var titleAccessibilityIdentifier: String {
        "candidate.screen.\(id)"
    }
}

enum KairoAccessibilityID {
    static let onboardingContinue = "onboarding.continue"
    static let onboardingBack = "onboarding.back"
    static let onboardingGetStarted = "onboarding.getStarted"
    static let onboardingExistingAccount = "onboarding.existingAccount"
    static let onboardingLoginScreen = "onboarding.login.screen"
    static let onboardingLoginTitle = "onboarding.login.title"
    static let candidateTabShell = "candidate.tabShell"
    static let candidateNavigationVerified = "candidate.navigationVerified"
    static let candidateNetworkStatusMessage = "candidate.networkStatusMessage"
}
