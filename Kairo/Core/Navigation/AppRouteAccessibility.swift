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
    static let chooseStartResumeOption = "onboarding.chooseStart.resume"
    static let chooseStartManualOption = "onboarding.chooseStart.manual"
    static let chooseStartContinue = "onboarding.chooseStart.continue"
    static let resumeImportPlaceholderTitle = "onboarding.resumeImport.title"
    static let resumeImportChooseButton = "onboarding.resumeImport.choose"
    static let resumeImportPrepareButton = "onboarding.resumeImport.prepare"
    static let resumeImportManualButton = "onboarding.resumeImport.manual"
    static let resumeImportProcessingButton = "onboarding.resumeImport.processing.button"
    static let resumeImportProcessingTitle = "onboarding.resumeImport.processing.title"
    static let resumeImportFileName = "onboarding.resumeImport.fileName"
    static let resumeImportReplaceButton = "onboarding.resumeImport.replace"
    static let resumeImportRemoveButton = "onboarding.resumeImport.remove"
    static let resumeImportRetryButton = "onboarding.resumeImport.retry"
    static let resumeImportChooseAnotherButton = "onboarding.resumeImport.chooseAnother"
    static let resumeImportLooksGoodButton = "onboarding.resumeImport.looksGood"
    static let resumeImportFailureMessage = "onboarding.resumeImport.failure.message"
    static let resumeImportUnsupportedMessage = "onboarding.resumeImport.unsupported.message"
    static let manualProfilePlaceholderTitle = "onboarding.manualProfile.title"
    static let manualProfileTitle = "onboarding.manualProfile.title"
    static let manualProfileHeadline = "onboarding.manualProfile.headline"
    static let manualProfileCurrentCity = "onboarding.manualProfile.currentCity"
    static let manualProfileCurrentCountry = "onboarding.manualProfile.currentCountry"
    static let manualProfileBasicContinue = "onboarding.manualProfile.basic.continue"
    static let manualProfileBasicBack = "onboarding.manualProfile.basic.back"
    static let manualProfileEmploymentTitle = "onboarding.manualProfile.employment.title"
    static let manualProfileEmploymentAdd = "onboarding.manualProfile.employment.add"
    static let manualProfileEmploymentContinue = "onboarding.manualProfile.employment.continue"
    static let manualProfileEmploymentBack = "onboarding.manualProfile.employment.back"
    static let manualProfileEducationTitle = "onboarding.manualProfile.education.title"
    static let manualProfileEducationAdd = "onboarding.manualProfile.education.add"
    static let manualProfileEducationContinue = "onboarding.manualProfile.education.continue"
    static let manualProfileEducationBack = "onboarding.manualProfile.education.back"
    static let onboardingLoginScreen = "onboarding.login.screen"
    static let onboardingLoginTitle = "onboarding.login.title"
    static let candidateTabShell = "candidate.tabShell"
    static let candidateNavigationVerified = "candidate.navigationVerified"
    static let candidateNetworkStatusMessage = "candidate.networkStatusMessage"

    static func manualProfileEmploymentCompany(_ index: Int) -> String {
        "onboarding.manualProfile.employment.company.\(index)"
    }

    static func manualProfileEmploymentJobTitle(_ index: Int) -> String {
        "onboarding.manualProfile.employment.jobTitle.\(index)"
    }

    static func manualProfileEmploymentType(_ index: Int) -> String {
        "onboarding.manualProfile.employment.type.\(index)"
    }

    static func manualProfileEmploymentStartMonth(_ index: Int) -> String {
        "onboarding.manualProfile.employment.startMonth.\(index)"
    }

    static func manualProfileEmploymentStartYear(_ index: Int) -> String {
        "onboarding.manualProfile.employment.startYear.\(index)"
    }

    static func manualProfileEmploymentEndMonth(_ index: Int) -> String {
        "onboarding.manualProfile.employment.endMonth.\(index)"
    }

    static func manualProfileEmploymentEndYear(_ index: Int) -> String {
        "onboarding.manualProfile.employment.endYear.\(index)"
    }

    static func manualProfileEmploymentDelete(_ index: Int) -> String {
        "onboarding.manualProfile.employment.delete.\(index)"
    }

    static func manualProfileEmploymentCurrentToggle(_ index: Int) -> String {
        "onboarding.manualProfile.employment.current.\(index)"
    }

    static func manualProfileEducationInstitution(_ index: Int) -> String {
        "onboarding.manualProfile.education.institution.\(index)"
    }

    static func manualProfileEducationDegree(_ index: Int) -> String {
        "onboarding.manualProfile.education.degree.\(index)"
    }

    static func manualProfileEducationFieldOfStudy(_ index: Int) -> String {
        "onboarding.manualProfile.education.fieldOfStudy.\(index)"
    }

    static func manualProfileEducationStartYear(_ index: Int) -> String {
        "onboarding.manualProfile.education.startYear.\(index)"
    }

    static func manualProfileEducationEndYear(_ index: Int) -> String {
        "onboarding.manualProfile.education.endYear.\(index)"
    }

    static func manualProfileEducationDelete(_ index: Int) -> String {
        "onboarding.manualProfile.education.delete.\(index)"
    }
}
