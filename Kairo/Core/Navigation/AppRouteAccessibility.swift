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

nonisolated enum KairoAccessibilityID {
    static let passwordResetForgotPassword = "auth.passwordReset.forgotPassword"
    static let passwordResetRequestScreen = "auth.passwordReset.request.screen"
    static let passwordResetRequestTitle = "auth.passwordReset.request.title"
    static let passwordResetEmail = "auth.passwordReset.email"
    static let passwordResetSendEmail = "auth.passwordReset.sendEmail"
    static let passwordResetCheckEmailScreen = "auth.passwordReset.checkEmail.screen"
    static let passwordResetCheckEmailSuccess = "auth.passwordReset.checkEmail.success"
    static let passwordResetEnterToken = "auth.passwordReset.enterToken"
    static let passwordResetTokenScreen = "auth.passwordReset.token.screen"
    static let passwordResetToken = "auth.passwordReset.token"
    static let passwordResetNewPassword = "auth.passwordReset.newPassword"
    static let passwordResetConfirmPassword = "auth.passwordReset.confirmPassword"
    static let passwordResetSubmit = "auth.passwordReset.submit"
    static let passwordResetSuccessScreen = "auth.passwordReset.success.screen"
    static let passwordResetSuccess = "auth.passwordReset.success"
    static let passwordResetRequestNew = "auth.passwordReset.requestNew"
    static let passwordResetError = "auth.passwordReset.error"
    static let onboardingContinue = "onboarding.continue"
    static let onboardingBack = "onboarding.back"
    static let onboardingGetStarted = "onboarding.getStarted"
    static let onboardingExistingAccount = "onboarding.existingAccount"
    static let createAccountFirstName = "onboarding.createAccount.firstName"
    static let createAccountLastName = "onboarding.createAccount.lastName"
    static let createAccountEmail = "onboarding.createAccount.email"
    static let createAccountMobile = "onboarding.createAccount.mobile"
    static let createAccountPassword = "onboarding.createAccount.password"
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
    static let manualProfileFullName = "onboarding.manualProfile.fullName"
    static let manualProfileHeadline = "onboarding.manualProfile.headline"
    static let manualProfileCurrentRole = "onboarding.manualProfile.currentRole"
    static let manualProfileIndustry = "onboarding.manualProfile.industry"
    static let manualProfileYearsOfExperience = "onboarding.manualProfile.yearsOfExperience"
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
    static let passportCreatedSummary = "onboarding.passportCreated.summary"
    static let passportCreatedTrustScoreMessage = "onboarding.passportCreated.trustScoreMessage"
    static let passportCreatedContinueHome = "onboarding.passportCreated.continueHome"
    static let passportCreatedReviewProfile = "onboarding.passportCreated.reviewProfile"
    static let onboardingLoginScreen = "onboarding.login.screen"
    static let onboardingLoginTitle = "onboarding.login.title"
    static let onboardingLoginEmail = "onboarding.login.email"
    static let onboardingLoginPassword = "onboarding.login.password"
    static let onboardingLoginSubmit = "onboarding.login.submit"
    static let onboardingLoginError = "onboarding.login.error"
    static let candidateTabShell = "candidate.tabShell"
    static let candidateNavigationVerified = "candidate.navigationVerified"
    static let candidateNetworkStatusMessage = "candidate.networkStatusMessage"
    static let homeScreen = "candidate.home.screen"
    static let homeNotificationsButton = "candidate.home.notifications"
    static let homeTrustScoreCard = "candidate.home.trustScore"
    static let homeViewTrustPassport = "candidate.home.viewTrustPassport"
    static let homeRecommendation = "candidate.home.recommendation"
    static let homeStartVerification = "candidate.home.startVerification"
    static let homeVerificationRequest = "candidate.home.verificationRequest"
    static let homeVerificationRequestAction = "candidate.home.verificationRequest.action"
    static let homeProfileCompletion = "candidate.home.profileCompletion"
    static let homeContinueProfile = "candidate.home.continueProfile"
    static let homeRecentActivity = "candidate.home.recentActivity"
    static let homeRecentPassportViews = "candidate.home.recentPassportViews"
    static let homeRecentPassportViewsOpen = "candidate.home.recentPassportViews.open"
    static let careerScreen = "candidate.career.screen"
    static let careerSummarySection = "candidate.career.summary"
    static let careerEditProfileButton = "candidate.career.editProfile"
    static let careerEmploymentSection = "candidate.career.employment"
    static let careerEducationSection = "candidate.career.education"
    static let careerCertificationsSection = "candidate.career.certifications"
    static let careerProjectsSection = "candidate.career.projects"
    static let careerSkillsSection = "candidate.career.skills"
    static let careerEmptyState = "candidate.career.empty"
    static let careerAddEmploymentButton = "candidate.career.employment.add"
    static let careerAddEducationButton = "candidate.career.education.add"
    static let careerAddCertificationButton = "candidate.career.certifications.add"
    static let careerAddProjectButton = "candidate.career.projects.add"
    static let careerAddSkillButton = "candidate.career.skills.add"
    static let careerMutationSave = "candidate.career.mutation.save"
    static let careerMutationCancel = "candidate.career.mutation.cancel"
    static let careerMutationDelete = "candidate.career.mutation.delete"
    static let careerMutationError = "candidate.career.mutation.error"
    static let careerEmploymentDeleteConfirmation = "candidate.career.employment.delete.confirmation"
    static let careerEducationDeleteConfirmation = "candidate.career.education.delete.confirmation"
    static let careerCertificationDeleteConfirmation = "candidate.career.certification.delete.confirmation"
    static let careerProjectDeleteConfirmation = "candidate.career.project.delete.confirmation"
    static let careerSkillDeleteConfirmation = "candidate.career.skill.delete.confirmation"
    static let passportScreen = "candidate.passport.screen"
    static let passportHeader = "candidate.passport.header"
    static let passportTrustScoreCard = "candidate.passport.trustScore"
    static let passportStrengthSummary = "candidate.passport.strength"
    static let passportIdentitySection = "candidate.passport.identity"
    static let passportEmploymentSection = "candidate.passport.employment"
    static let passportEducationSection = "candidate.passport.education"
    static let passportCertificationsSection = "candidate.passport.certifications"
    static let passportProjectsSection = "candidate.passport.projects"
    static let passportTimelineSection = "candidate.passport.timeline"
    static let passportShareAction = "candidate.passport.share"
    static let passportPreviewAction = "candidate.passport.preview"
    static let passportDownloadAction = "candidate.passport.download"
    static let passportShareManagement = "candidate.passport.share.management"
    static let passportShareActivityEntry = "candidate.passport.share.activity.entry"
    static let passportShareActivity = "candidate.passport.share.activity"
    static let passportShareActivityList = "candidate.passport.share.activity.list"
    static let passportShareCreateEntry = "candidate.passport.share.createEntry"
    static let passportShareLabel = "candidate.passport.share.label"
    static let passportShareExpiry = "candidate.passport.share.expiry"
    static let passportShareCustomExpiry = "candidate.passport.share.expiry.custom"
    static let passportShareCreate = "candidate.passport.share.create"
    static let passportShareSuccess = "candidate.passport.share.success"
    static let passportShareCopyLink = "candidate.passport.share.copyLink"
    static let passportShareNativeShare = "candidate.passport.share.nativeShare"
    static let passportShareQRCode = "candidate.passport.share.qrCode"
    static let passportShareManage = "candidate.passport.share.manage"
    static let passportShareDetail = "candidate.passport.share.detail"
    static let passportShareUpdate = "candidate.passport.share.update"
    static let passportShareUpdateConfirm = "candidate.passport.share.update.confirm"
    static let passportShareRevoke = "candidate.passport.share.revoke"
    static let passportShareRevokeConfirm = "candidate.passport.share.revoke.confirm"
    static let publicPassportContent = "public.passport.content"
    static let publicPassportUnavailable = "public.passport.unavailable"
    static let publicPassportOpenInBrowser = "public.passport.openInBrowser"
    static let passportEmptyState = "candidate.passport.empty"
    static let passportContinueProfile = "candidate.passport.continueProfile"
    static let passportStartVerification = "candidate.passport.startVerification"

    static func passportSharePermission(_ permission: String) -> String {
        "candidate.passport.share.permission.\(permission)"
    }

    static func passportShareList(_ state: String) -> String {
        "candidate.passport.share.list.\(state)"
    }

    static func passportShareRow(_ id: String) -> String {
        "candidate.passport.share.row.\(id)"
    }

    static func passportShareActivityRow(_ id: String) -> String {
        "candidate.passport.share.activity.row.\(id)"
    }
    static let verifyScreen = "candidate.verify.screen"
    static let verifyPriorityRecommendation = "candidate.verify.priorityRecommendation"
    static let verifyStartVerification = "candidate.verify.startVerification"
    static let verifyPendingRequestsSection = "candidate.verify.pendingRequests"
    static let verifyInProgressSection = "candidate.verify.inProgress"
    static let verifyCompletedSection = "candidate.verify.completed"
    static let verifySuggestedNextSection = "candidate.verify.suggestedNext"
    static let verifyRequestDetail = "candidate.verify.requestDetail"
    static let verifyAcceptRequest = "candidate.verify.request.accept"
    static let verifyProvideInformation = "candidate.verify.request.provideInformation"
    static let verifyDeclineRequest = "candidate.verify.request.decline"
    static let verifyStartVerificationSheet = "candidate.verify.startVerificationSheet"
    static let verifyEmptyState = "candidate.verify.empty"
    static let verifyViewTrustPassport = "candidate.verify.viewTrustPassport"
    static let verificationInitiationContinue = "candidate.verificationInitiation.continue"
    static let verificationInitiationConfirmation = "candidate.verificationInitiation.confirmation"
    static let verificationInitiationClaimConsent = "candidate.verificationInitiation.claimConsent"
    static let verificationInitiationEvidenceConsent = "candidate.verificationInitiation.evidenceConsent"
    static let verificationInitiationSubmit = "candidate.verificationInitiation.submit"
    static let verificationInitiationSuccess = "candidate.verificationInitiation.success"
    static let verificationInitiationError = "candidate.verificationInitiation.error"
    static let verificationInitiationRetry = "candidate.verificationInitiation.retry"
    static let verificationInitiationViewRequest = "candidate.verificationInitiation.viewRequest"
    static let moreScreen = "candidate.more.screen"
    static let moreAccountSummary = "candidate.more.accountSummary"
    static let moreViewProfile = "candidate.more.viewProfile"
    static let moreAccountSection = "candidate.more.account"
    static let morePreferencesSection = "candidate.more.preferences"
    static let morePrivacyDataSection = "candidate.more.privacyData"
    static let moreHelpSupportSection = "candidate.more.helpSupport"
    static let moreAboutSection = "candidate.more.about"
    static let moreNotificationsVerificationUpdates = "candidate.more.notifications.verificationUpdates"
    static let moreNotificationsPassportViews = "candidate.more.notifications.passportViews"
    static let moreNotificationsProductUpdates = "candidate.more.notifications.productUpdates"
    static let moreAppearanceSelection = "candidate.more.appearance"
    static let moreAppearanceSystem = "candidate.more.appearance.system"
    static let moreAppearanceLight = "candidate.more.appearance.light"
    static let moreAppearanceDark = "candidate.more.appearance.dark"
    static let moreContactSupport = "candidate.more.contactSupport"
    static let moreDownloadMyDataConfirmation = "candidate.more.downloadMyData.confirmation"
    static let moreDeleteAccount = "candidate.more.deleteAccount"
    static let moreDeleteAccountConfirmation = "candidate.more.deleteAccount.confirmation"
    static let moreTermsOfService = "candidate.more.terms"
    static let morePrivacyPolicy = "candidate.more.privacyPolicy"
    static let moreCookiePolicy = "candidate.more.cookiePolicy"
    static let moreSignOut = "candidate.more.signOut"
    static let moreSignOutConfirmation = "candidate.more.signOut.confirmation"

    static func manualProfileEmploymentCompany(_ index: Int) -> String {
        "onboarding.manualProfile.employment.company.\(index)"
    }

    static func verifyRequestCard(_ id: String) -> String {
        "candidate.verify.request.\(id)"
    }

    static func verifyRequestAction(_ id: String) -> String {
        "candidate.verify.request.action.\(id)"
    }

    static func verifySuggestedAction(_ type: String) -> String {
        "candidate.verify.suggested.\(type)"
    }

    static func verificationInitiationSubject(_ id: String) -> String {
        "candidate.verificationInitiation.subject.\(id)"
    }

    static func verificationInitiationEvidence(_ id: String) -> String {
        "candidate.verificationInitiation.evidence.\(id)"
    }

    static func careerEmploymentStartVerification(_ id: String) -> String {
        "candidate.career.employment.verification.\(id)"
    }

    static func careerEducationStartVerification(_ id: String) -> String {
        "candidate.career.education.verification.\(id)"
    }

    static func manualProfileEmploymentJobTitle(_ index: Int) -> String {
        "onboarding.manualProfile.employment.jobTitle.\(index)"
    }

    static func manualProfileEmploymentType(_ index: Int) -> String {
        "onboarding.manualProfile.employment.type.\(index)"
    }

    static func manualProfileEmploymentCountry(_ index: Int) -> String {
        "onboarding.manualProfile.employment.country.\(index)"
    }

    static func manualProfileEmploymentStartDay(_ index: Int) -> String {
        "onboarding.manualProfile.employment.startDay.\(index)"
    }

    static func manualProfileEmploymentStartMonth(_ index: Int) -> String {
        "onboarding.manualProfile.employment.startMonth.\(index)"
    }

    static func manualProfileEmploymentStartYear(_ index: Int) -> String {
        "onboarding.manualProfile.employment.startYear.\(index)"
    }

    static func manualProfileEmploymentEndDay(_ index: Int) -> String {
        "onboarding.manualProfile.employment.endDay.\(index)"
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

    static func manualProfileEducationLevel(_ index: Int) -> String {
        "onboarding.manualProfile.education.level.\(index)"
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

    static func careerEmploymentEditButton(_ id: String) -> String {
        "candidate.career.employment.edit.\(id)"
    }

    static func careerEmploymentDeleteButton(_ id: String) -> String {
        "candidate.career.employment.delete.\(id)"
    }

    static func careerEducationEditButton(_ id: String) -> String {
        "candidate.career.education.edit.\(id)"
    }

    static func careerEducationDeleteButton(_ id: String) -> String {
        "candidate.career.education.delete.\(id)"
    }

    static func careerCertificationEditButton(_ id: String) -> String {
        "candidate.career.certification.edit.\(id)"
    }

    static func careerCertificationDeleteButton(_ id: String) -> String {
        "candidate.career.certification.delete.\(id)"
    }

    static func careerProjectEditButton(_ id: String) -> String {
        "candidate.career.project.edit.\(id)"
    }

    static func careerProjectDeleteButton(_ id: String) -> String {
        "candidate.career.project.delete.\(id)"
    }

    static func careerSkillEditButton(_ id: String) -> String {
        "candidate.career.skill.edit.\(id)"
    }

    static func careerSkillDeleteButton(_ id: String) -> String {
        "candidate.career.skill.delete.\(id)"
    }

    static func careerMutationField(_ type: String, _ field: String) -> String {
        "candidate.career.\(type).field.\(field)"
    }
}
