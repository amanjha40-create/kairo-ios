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
    static let createAccountFirstName = "onboarding.createAccount.firstName"
    static let createAccountLastName = "onboarding.createAccount.lastName"
    static let createAccountEmail = "onboarding.createAccount.email"
    static let createAccountMobile = "onboarding.createAccount.mobile"
    static let createAccountContinue = "onboarding.createAccount.continue"
    static let createAccountLogin = "onboarding.createAccount.login"
    static let verifyIdentityIntroContinue = "onboarding.verifyIdentity.intro.continue"
    static let verifyIdentityIntroBack = "onboarding.verifyIdentity.intro.back"
    static let verifyIdentityBack = "onboarding.verifyIdentity.back"
    static let verifyIdentityEmailTitle = "onboarding.verifyIdentity.email.title"
    static let verifyIdentityEmailAddress = "onboarding.verifyIdentity.email.address"
    static let verifyIdentityEmailCode = "onboarding.verifyIdentity.email.code"
    static let verifyIdentityEmailSendCode = "onboarding.verifyIdentity.email.sendCode"
    static let verifyIdentityEmailVerify = "onboarding.verifyIdentity.email.verify"
    static let verifyIdentityEmailResendCode = "onboarding.verifyIdentity.email.resendCode"
    static let verifyIdentityEmailChange = "onboarding.verifyIdentity.email.change"
    static let verifyIdentityEmailCountdown = "onboarding.verifyIdentity.email.countdown"
    static let verifyIdentityEmailSuccess = "onboarding.verifyIdentity.email.success"
    static let verifyIdentityMobileTitle = "onboarding.verifyIdentity.mobile.title"
    static let verifyIdentityMobileNumber = "onboarding.verifyIdentity.mobile.number"
    static let verifyIdentityMobileCode = "onboarding.verifyIdentity.mobile.code"
    static let verifyIdentityMobileSendCode = "onboarding.verifyIdentity.mobile.sendCode"
    static let verifyIdentityMobileVerify = "onboarding.verifyIdentity.mobile.verify"
    static let verifyIdentityMobileResendCode = "onboarding.verifyIdentity.mobile.resendCode"
    static let verifyIdentityMobileChange = "onboarding.verifyIdentity.mobile.change"
    static let verifyIdentityMobileCountdown = "onboarding.verifyIdentity.mobile.countdown"
    static let verifyIdentityMobileSuccess = "onboarding.verifyIdentity.mobile.success"
    static let onboardingLoginScreen = "onboarding.login.screen"
    static let onboardingLoginTitle = "onboarding.login.title"
    static let candidateTabShell = "candidate.tabShell"
    static let candidateNavigationVerified = "candidate.navigationVerified"
    static let candidateNetworkStatusMessage = "candidate.networkStatusMessage"
}
