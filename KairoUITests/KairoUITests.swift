//
//  KairoUITests.swift
//  KairoUITests
//
//  Created by Aman on 27/07/26.
//

import XCTest

final class KairoUITests: XCTestCase {
    private let uiTestingArgument = "-KAIRO_UI_TESTING"
    private let uiTestDisableAnimationsKey = "KAIRO_UI_TEST_DISABLE_ANIMATIONS"
    private let uiTestRouteKey = "KAIRO_UI_TEST_ROUTE"
    private let demoModeKey = "KAIRO_DEMO_MODE"
    private let appEnvironmentKey = "KAIRO_APP_ENVIRONMENT"
    private let onboardingWelcomeTitle = "onboarding.step.welcome"
    private let onboardingCreateAccountTitle = "onboarding.step.createAccount"
    private let onboardingVerifyIdentityTitle = "onboarding.step.verifyIdentity"
    private let onboardingVerifyIdentityEmailTitle = "onboarding.verifyIdentity.email.title"
    private let onboardingVerifyIdentityMobileTitle = "onboarding.verifyIdentity.mobile.title"
    private let onboardingChooseStartTitle = "onboarding.step.chooseStart"
    private let onboardingResumeImportTitle = "onboarding.resumeImport.title"
    private let onboardingManualProfileTitle = "onboarding.manualProfile.title"
    private let onboardingManualProfileEmploymentTitle = "onboarding.manualProfile.employment.title"
    private let onboardingManualProfileEducationTitle = "onboarding.manualProfile.education.title"
    private let onboardingPassportCreatedTitle = "onboarding.step.passportCreated"
    private let onboardingGetStartedButton = "onboarding.getStarted"
    private let onboardingContinueButton = "onboarding.continue"
    private let chooseStartContinueButton = "onboarding.chooseStart.continue"
    private let chooseStartResumeOptionButton = "onboarding.chooseStart.resume"
    private let chooseStartManualOptionButton = "onboarding.chooseStart.manual"
    private let welcomeExistingAccountButton = "onboarding.existingAccount"
    private let createAccountFirstNameField = "onboarding.createAccount.firstName"
    private let createAccountLastNameField = "onboarding.createAccount.lastName"
    private let createAccountEmailField = "onboarding.createAccount.email"
    private let createAccountMobileField = "onboarding.createAccount.mobile"
    private let createAccountContinueButton = "onboarding.createAccount.continue"
    private let createAccountLoginButton = "onboarding.createAccount.login"
    private let verifyIdentityIntroContinueButton = "onboarding.verifyIdentity.intro.continue"
    private let verifyIdentityEmailCodeField = "onboarding.verifyIdentity.email.code"
    private let verifyIdentityEmailSendCodeButton = "onboarding.verifyIdentity.email.sendCode"
    private let verifyIdentityEmailVerifyButton = "onboarding.verifyIdentity.email.verify"
    private let verifyIdentityEmailResendCodeButton = "onboarding.verifyIdentity.email.resendCode"
    private let verifyIdentityEmailCountdown = "onboarding.verifyIdentity.email.countdown"
    private let verifyIdentityEmailSuccess = "onboarding.verifyIdentity.email.success"
    private let verifyIdentityMobileCodeField = "onboarding.verifyIdentity.mobile.code"
    private let verifyIdentityMobileSendCodeButton = "onboarding.verifyIdentity.mobile.sendCode"
    private let verifyIdentityMobileVerifyButton = "onboarding.verifyIdentity.mobile.verify"
    private let verifyIdentityMobileSuccess = "onboarding.verifyIdentity.mobile.success"
    private let onboardingLoginTitle = "onboarding.login.title"
    private let onboardingLoginEmailField = "onboarding.login.email"
    private let onboardingLoginPasswordField = "onboarding.login.password"
    private let onboardingLoginSubmitButton = "onboarding.login.submit"
    private let onboardingLoginError = "onboarding.login.error"
    private let resumeImportChooseButton = "onboarding.resumeImport.choose"
    private let resumeImportPrepareButton = "onboarding.resumeImport.prepare"
    private let resumeImportManualButton = "onboarding.resumeImport.manual"
    private let resumeImportProcessingTitle = "onboarding.resumeImport.processing.title"
    private let resumeImportFileName = "onboarding.resumeImport.fileName"
    private let resumeImportRetryButton = "onboarding.resumeImport.retry"
    private let resumeImportChooseAnotherButton = "onboarding.resumeImport.chooseAnother"
    private let resumeImportLooksGoodButton = "onboarding.resumeImport.looksGood"
    private let resumeImportFailureMessage = "onboarding.resumeImport.failure.message"
    private let passportCreatedSummaryCard = "onboarding.passportCreated.summary"
    private let passportCreatedTrustScoreMessage = "onboarding.passportCreated.trustScoreMessage"
    private let passportCreatedContinueHomeButton = "onboarding.passportCreated.continueHome"
    private let passportCreatedReviewProfileButton = "onboarding.passportCreated.reviewProfile"
    private let manualProfileHeadlineField = "onboarding.manualProfile.headline"
    private let manualProfileCurrentCityField = "onboarding.manualProfile.currentCity"
    private let manualProfileCurrentCountryField = "onboarding.manualProfile.currentCountry"
    private let manualProfileBasicContinueButton = "onboarding.manualProfile.basic.continue"
    private let manualProfileEmploymentAddButton = "onboarding.manualProfile.employment.add"
    private let manualProfileEmploymentContinueButton = "onboarding.manualProfile.employment.continue"
    private let manualProfileEducationAddButton = "onboarding.manualProfile.education.add"
    private let manualProfileEducationContinueButton = "onboarding.manualProfile.education.continue"
    private let homeScreen = "candidate.home.screen"
    private let homeTrustScoreCard = "candidate.home.trustScore"
    private let homeViewTrustPassportButton = "candidate.home.viewTrustPassport"
    private let homeStartVerificationButton = "candidate.home.startVerification"
    private let homeVerificationRequest = "candidate.home.verificationRequest"
    private let homeVerificationRequestActionButton = "candidate.home.verificationRequest.action"
    private let homeProfileCompletion = "candidate.home.profileCompletion"
    private let homeContinueProfileButton = "candidate.home.continueProfile"
    private let homeRecentActivity = "candidate.home.recentActivity"
    private let homeRecentPassportViews = "candidate.home.recentPassportViews"
    private let homeRecentPassportViewsOpen = "candidate.home.recentPassportViews.open"
    private let careerScreen = "candidate.career.screen"
    private let careerSummarySection = "candidate.career.summary"
    private let careerEmploymentSection = "candidate.career.employment"
    private let careerEducationSection = "candidate.career.education"
    private let careerCertificationsSection = "candidate.career.certifications"
    private let careerProjectsSection = "candidate.career.projects"
    private let careerSkillsSection = "candidate.career.skills"
    private let careerEmptyState = "candidate.career.empty"
    private let passportScreen = "candidate.passport.screen"
    private let passportHeader = "candidate.passport.header"
    private let passportTrustScoreCard = "candidate.passport.trustScore"
    private let passportStrengthSummary = "candidate.passport.strength"
    private let passportIdentitySection = "candidate.passport.identity"
    private let passportEmploymentSection = "candidate.passport.employment"
    private let passportEducationSection = "candidate.passport.education"
    private let passportCertificationsSection = "candidate.passport.certifications"
    private let passportProjectsSection = "candidate.passport.projects"
    private let passportTimelineSection = "candidate.passport.timeline"
    private let passportShareAction = "candidate.passport.share"
    private let passportShareActivityEntry = "candidate.passport.share.activity.entry"
    private let passportShareActivity = "candidate.passport.share.activity"
    private let passportPreviewAction = "candidate.passport.preview"
    private let passportDownloadAction = "candidate.passport.download"
    private let passportEmptyState = "candidate.passport.empty"
    private let passportContinueProfile = "candidate.passport.continueProfile"
    private let passportStartVerification = "candidate.passport.startVerification"
    private let verifyScreen = "candidate.verify.screen"
    private let verifyPriorityRecommendation = "candidate.verify.priorityRecommendation"
    private let verifyStartVerificationButton = "candidate.verify.startVerification"
    private let verifyPendingRequestsSection = "candidate.verify.pendingRequests"
    private let verifyInProgressSection = "candidate.verify.inProgress"
    private let verifyCompletedSection = "candidate.verify.completed"
    private let verifySuggestedNextSection = "candidate.verify.suggestedNext"
    private let verifyRequestDetail = "candidate.verify.requestDetail"
    private let verifyAcceptRequest = "candidate.verify.request.accept"
    private let verifyProvideInformation = "candidate.verify.request.provideInformation"
    private let verifyDeclineRequest = "candidate.verify.request.decline"
    private let verifyStartVerificationSheet = "candidate.verify.startVerificationSheet"
    private let verifyEmptyState = "candidate.verify.empty"
    private let verifyViewTrustPassport = "candidate.verify.viewTrustPassport"
    private let moreScreen = "candidate.more.screen"
    private let moreAccountSummary = "candidate.more.accountSummary"
    private let moreViewProfileButton = "candidate.more.viewProfile"
    private let moreAccountSection = "candidate.more.account"
    private let morePreferencesSection = "candidate.more.preferences"
    private let morePrivacyDataSection = "candidate.more.privacyData"
    private let moreHelpSupportSection = "candidate.more.helpSupport"
    private let moreAboutSection = "candidate.more.about"
    private let moreNotificationsVerificationUpdates = "candidate.more.notifications.verificationUpdates"
    private let moreNotificationsPassportViews = "candidate.more.notifications.passportViews"
    private let moreNotificationsProductUpdates = "candidate.more.notifications.productUpdates"
    private let moreAppearanceSelection = "candidate.more.appearance"
    private let moreAppearanceSystemButton = "candidate.more.appearance.system"
    private let moreAppearanceLightButton = "candidate.more.appearance.light"
    private let moreAppearanceDarkButton = "candidate.more.appearance.dark"
    private let moreContactSupportButton = "candidate.more.contactSupport"
    private let moreDeleteAccountButton = "candidate.more.deleteAccount"
    private let moreTermsOfServiceButton = "candidate.more.terms"
    private let morePrivacyPolicyButton = "candidate.more.privacyPolicy"
    private let moreCookiePolicyButton = "candidate.more.cookiePolicy"
    private let moreSignOutButton = "candidate.more.signOut"
    private let moreSignOutConfirmation = "candidate.more.signOut.confirmation"
    private var baseLaunchArguments: [String] {
        [
            "-ApplePersistenceIgnoreState",
            "YES",
            uiTestingArgument
        ]
    }
    private var baseLaunchEnvironment: [String: String] {
        [
            uiTestDisableAnimationsKey: "1",
            uiTestRouteKey: "onboarding"
        ]
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIApplication().terminate()
    }

    override func tearDownWithError() throws {
        XCUIApplication().terminate()
    }

    @MainActor
    func testOnboardingFlowReachesLockedHomeShell() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(resumeImportEnvironment(phase: "readyForReview")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingResumeImportTitle].waitForExistence(timeout: 10))
        tapWhenHittable(app.buttons[resumeImportLooksGoodButton], in: app)
        XCTAssertTrue(app.staticTexts[onboardingPassportCreatedTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[passportCreatedContinueHomeButton].waitForExistence(timeout: 10))
        app.buttons[passportCreatedContinueHomeButton].tap()

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(homeScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testDemoModeLaunchOverrideReachesDemoHomeShell() throws {
        let app = launchApp(environment: [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome"
        ])

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(homeScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(homeTrustScoreCardElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeTrustScoreIsVisibleInDemoMode() throws {
        let app = launchApp(environment: homeEnvironment())

        XCTAssertTrue(homeScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(homeTrustScoreCardElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Trust Score"].exists)
    }

    @MainActor
    func testHomeViewTrustPassportRoutesToPassportTab() throws {
        let app = launchApp(environment: homeEnvironment())
        let trustScoreCard = homeTrustScoreCardElement(in: app)
        let action = trustScoreCard.descendants(matching: .any)
            .matching(identifier: homeViewTrustPassportButton)
            .firstMatch

        XCTAssertTrue(trustScoreCard.waitForExistence(timeout: 10))
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()

        XCTAssertTrue(passportScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[passportTrustScoreCard].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeRecentPassportViewsOpensCanonicalShareActivity() throws {
        let app = launchApp(environment: homeEnvironment())
        let activityButton = app.buttons[homeRecentPassportViewsOpen]

        XCTAssertTrue(waitForElementAfterScrolling(activityButton, in: app))
        activityButton.tap()

        XCTAssertTrue(app.navigationBars["Share Activity"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements[passportShareActivity].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeStartVerificationRoutesToVerifyTab() throws {
        let app = launchApp(environment: homeEnvironment())

        XCTAssertTrue(app.buttons[homeStartVerificationButton].waitForExistence(timeout: 10))
        app.buttons[homeStartVerificationButton].tap()

        XCTAssertTrue(app.staticTexts["candidate.screen.verify"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeContinueProfileRoutesToCareerTab() throws {
        let app = launchApp(environment: homeEnvironment())

        let continueProfileButton = app.buttons[homeContinueProfileButton]
        XCTAssertTrue(waitForElementAfterScrolling(continueProfileButton, in: app))
        continueProfileButton.tap()

        XCTAssertTrue(careerScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["candidate.screen.career"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[careerEmploymentSection].exists)
    }

    @MainActor
    func testHomeVerificationRequestActionRoutesToVerifyTab() throws {
        let app = launchApp(environment: homeEnvironment())

        let requestCard = app.descendants(matching: .any)
            .matching(identifier: homeVerificationRequest)
            .firstMatch
        let requestAction = requestCard.descendants(matching: .any)
            .matching(identifier: homeVerificationRequestActionButton)
            .firstMatch

        XCTAssertTrue(waitForElementAfterScrolling(requestCard, in: app))
        XCTAssertTrue(waitForElementAfterScrolling(requestAction, in: app))
        requestAction.tap()

        XCTAssertTrue(app.staticTexts["candidate.screen.verify"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testHomeEmptyStateRendersCorrectly() throws {
        let app = launchApp(environment: homeEnvironment(state: "empty"))
        let profileCompletionCard = app.descendants(matching: .any)
            .matching(identifier: homeProfileCompletion)
            .firstMatch
        let recentActivitySection = app.descendants(matching: .any)
            .matching(identifier: homeRecentActivity)
            .firstMatch
        let recentPassportViewsSection = app.descendants(matching: .any)
            .matching(identifier: homeRecentPassportViews)
            .firstMatch

        XCTAssertTrue(homeScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(homeTrustScoreCardElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your Home is ready to grow"].waitForExistence(timeout: 10))
        XCTAssertTrue(waitForElementAfterScrolling(profileCompletionCard, in: app))
        XCTAssertTrue(waitForElementAfterScrolling(recentActivitySection, in: app))
        XCTAssertTrue(waitForElementAfterScrolling(recentPassportViewsSection, in: app))
    }

    @MainActor
    func testCareerTabDisplaysProfessionalSummary() throws {
        let app = launchApp(environment: careerEnvironment())

        openCareerTab(in: app)

        XCTAssertTrue(careerScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[careerSummarySection].exists)
        XCTAssertTrue(app.staticTexts["Aarav Anand"].exists)
    }

    @MainActor
    func testCareerEmploymentSectionRendersFixtureCards() throws {
        let app = launchApp(environment: careerEnvironment())

        openCareerTab(in: app)

        XCTAssertTrue(app.staticTexts[careerEmploymentSection].exists)
        XCTAssertTrue(app.staticTexts["Northline Career Services"].exists)
        XCTAssertTrue(app.staticTexts["Pending Verification"].exists)
    }

    @MainActor
    func testCareerEducationSectionRendersFixtureCards() throws {
        let app = launchApp(environment: careerEnvironment())

        openCareerTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[careerEducationSection], in: app))
        XCTAssertTrue(app.staticTexts["Christ University"].exists)
    }

    @MainActor
    func testCareerCertificationSectionRendersFixtureCards() throws {
        let app = launchApp(environment: careerEnvironment())

        openCareerTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[careerCertificationsSection], in: app))
        XCTAssertTrue(app.staticTexts["People Operations Foundations"].exists)
    }

    @MainActor
    func testCareerProjectsSectionRendersFixtureCards() throws {
        let app = launchApp(environment: careerEnvironment())

        openCareerTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[careerProjectsSection], in: app))
        XCTAssertTrue(app.staticTexts["Career Trust Onboarding Pilot"].exists)
        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[careerSkillsSection], in: app))
    }

    @MainActor
    func testCareerEmptyStateRendersCorrectly() throws {
        let app = launchApp(environment: careerEnvironment(state: "empty"))

        openCareerTab(in: app)

        XCTAssertTrue(careerScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[careerEmptyState].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Your professional timeline starts here"].exists)
    }

    @MainActor
    func testPassportTabOpensRealPassportScreen() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(passportScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[passportHeader].exists)
        XCTAssertTrue(app.staticTexts["Aarav Mehta"].exists)
    }

    @MainActor
    func testPassportTrustScoreIsVisible() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[passportTrustScoreCard].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Trust Score"].exists)
        XCTAssertTrue(app.staticTexts["72"].exists)
    }

    @MainActor
    func testPassportIdentitySectionRenders() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[passportIdentitySection], in: app))
        XCTAssertTrue(app.staticTexts["aarav.mehta@example.com"].exists)
    }

    @MainActor
    func testPassportEmploymentSectionRenders() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[passportEmploymentSection], in: app))
        XCTAssertTrue(app.staticTexts["BrightPath Technologies"].exists)
    }

    @MainActor
    func testPassportEducationSectionRenders() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[passportEducationSection], in: app))
        XCTAssertTrue(app.staticTexts["Welingkar Institute of Management"].exists)
    }

    @MainActor
    func testPassportCertificationsSectionRenders() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[passportCertificationsSection], in: app))
        XCTAssertTrue(app.staticTexts["Certified Scrum Product Owner"].exists)
    }

    @MainActor
    func testPassportProjectsSectionRenders() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[passportProjectsSection], in: app))
        XCTAssertTrue(app.staticTexts["Trust Operations Workflow Redesign"].exists)
    }

    @MainActor
    func testPassportTrustTimelineRenders() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[passportTimelineSection], in: app))
        XCTAssertTrue(app.staticTexts["Identity verified"].exists)
    }

    @MainActor
    func testPassportShareManagementOpens() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        let button = app.buttons[passportShareAction]
        XCTAssertTrue(waitForElementAfterScrolling(button, in: app))
        button.tap()

        XCTAssertTrue(app.navigationBars["Passport shares"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["candidate.passport.share.createEntry"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPassportShareActivityOpensFromOwnerPassport() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        let button = app.buttons[passportShareActivityEntry]
        XCTAssertTrue(waitForElementAfterScrolling(button, in: app))
        button.tap()

        XCTAssertTrue(app.navigationBars["Share Activity"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements[passportShareActivity].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPassportPreviewIsOnlyPromisedAfterBackendCreation() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        XCTAssertFalse(app.buttons[passportPreviewAction].exists)
        XCTAssertTrue(waitForElementAfterScrolling(
            app.staticTexts["Public preview, Copy, Share, and QR are available from the authoritative URL immediately after a share is created."],
            in: app
        ))
    }

    @MainActor
    func testPassportDownloadPDFRemainsTruthfullyUnavailable() throws {
        let app = launchApp(environment: passportEnvironment())

        openPassportTab(in: app)

        let button = app.buttons[passportDownloadAction]
        XCTAssertTrue(waitForElementAfterScrolling(button, in: app))
        XCTAssertFalse(button.isEnabled)
    }

    @MainActor
    func testPassportEmptyStateContinueProfileRoutesToCareer() throws {
        let app = launchApp(environment: passportEnvironment(state: "empty"))

        openPassportTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[passportEmptyState].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[passportContinueProfile].waitForExistence(timeout: 10))
        app.buttons[passportContinueProfile].tap()

        XCTAssertTrue(careerScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testPassportEmptyStateStartVerificationRoutesToVerify() throws {
        let app = launchApp(environment: passportEnvironment(state: "empty"))

        openPassportTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[passportEmptyState].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[passportStartVerification].waitForExistence(timeout: 10))
        app.buttons[passportStartVerification].tap()

        XCTAssertTrue(app.staticTexts["candidate.screen.verify"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyTabOpensRealVerifyScreen() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        XCTAssertTrue(verifyScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[verifyPriorityRecommendation].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Verify your current employment"].exists)
    }

    @MainActor
    func testVerifyPriorityRecommendationIsVisible() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[verifyPriorityRecommendation].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[verifyStartVerificationButton].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyStartVerificationOpensLocalSheet() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        XCTAssertTrue(app.buttons[verifyStartVerificationButton].waitForExistence(timeout: 10))
        app.buttons[verifyStartVerificationButton].tap()

        XCTAssertTrue(app.otherElements[verifyStartVerificationSheet].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Start verification"].exists)
    }

    @MainActor
    func testVerifyPendingRequestOpensDetail() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        let button = app.buttons[verifyRequestActionButton(id: "employment-brightpath")]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        XCTAssertTrue(app.otherElements[verifyRequestDetail].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["BrightPath Technologies"].exists)
    }

    @MainActor
    func testVerifyAcceptRequestUpdatesLocalState() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        app.buttons[verifyRequestActionButton(id: "employment-brightpath")].tap()
        XCTAssertTrue(app.buttons[verifyAcceptRequest].waitForExistence(timeout: 10))
        app.buttons[verifyAcceptRequest].tap()

        XCTAssertTrue(app.staticTexts["Approved and submitted locally"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyProvideInformationOpensLocalPlaceholder() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        app.buttons[verifyRequestActionButton(id: "education-welingkar-pending")].tap()
        XCTAssertTrue(app.buttons[verifyProvideInformation].waitForExistence(timeout: 10))
        app.buttons[verifyProvideInformation].tap()

        XCTAssertTrue(app.staticTexts["Provide information"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyDeclineRequestOpensConfirmation() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        app.buttons[verifyRequestActionButton(id: "education-welingkar-pending")].tap()
        XCTAssertTrue(app.buttons[verifyDeclineRequest].waitForExistence(timeout: 10))
        app.buttons[verifyDeclineRequest].tap()

        XCTAssertTrue(app.sheets.buttons["Decline request"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyInProgressSectionRenders() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[verifyInProgressSection], in: app))
        XCTAssertTrue(app.staticTexts["Northstar Labs"].exists)
    }

    @MainActor
    func testVerifyCompletedSectionRenders() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[verifyCompletedSection], in: app))
        XCTAssertTrue(app.staticTexts["aarav@example.com"].exists)
    }

    @MainActor
    func testVerifySuggestedNextSectionRenders() throws {
        let app = launchApp(environment: verifyEnvironment())

        openVerifyTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[verifySuggestedNextSection], in: app))
        XCTAssertTrue(app.staticTexts["Verify your highest education"].exists)
    }

    @MainActor
    func testVerifyEmptyStateStartVerificationWorks() throws {
        let app = launchApp(environment: verifyEnvironment(state: "empty"))

        openVerifyTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[verifyEmptyState].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[verifyStartVerificationButton].waitForExistence(timeout: 10))
        app.buttons[verifyStartVerificationButton].tap()

        XCTAssertTrue(app.otherElements[verifyStartVerificationSheet].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyEmptyStateViewTrustPassportOpensPassport() throws {
        let app = launchApp(environment: verifyEnvironment(state: "empty"))

        openVerifyTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[verifyEmptyState].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[verifyViewTrustPassport].waitForExistence(timeout: 10))
        app.buttons[verifyViewTrustPassport].tap()

        XCTAssertTrue(passportScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreTabOpensRealMoreScreen() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        XCTAssertTrue(moreScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[moreAccountSummary].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreAccountSummaryRenders() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        XCTAssertTrue(app.descendants(matching: .any)[moreAccountSummary].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Aarav Mehta"].exists)
        XCTAssertTrue(app.staticTexts["aarav@example.com"].exists)
    }

    @MainActor
    func testMoreViewProfileRoutesToPassportTab() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        XCTAssertTrue(app.buttons[moreViewProfileButton].waitForExistence(timeout: 10))
        app.buttons[moreViewProfileButton].tap()

        XCTAssertTrue(passportScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreAccountRowsOpenLocalPlaceholders() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        XCTAssertTrue(app.staticTexts[moreAccountSection].exists)
        app.buttons["personalInformation"].tap()
        XCTAssertTrue(app.navigationBars["Personal information"].waitForExistence(timeout: 10))
        dismissPresentedSheet(in: app)

        XCTAssertTrue(app.buttons["loginSecurity"].waitForExistence(timeout: 10))
        app.buttons["loginSecurity"].tap()
        XCTAssertTrue(app.navigationBars["Login & security"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreNotificationTogglesWorkLocally() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let productUpdatesToggle = app.switches[moreNotificationsProductUpdates]
        XCTAssertTrue(waitForElementAfterScrolling(productUpdatesToggle, in: app))
        XCTAssertEqual(productUpdatesToggle.value as? String, "0")

        productUpdatesToggle.tap()

        XCTAssertEqual(productUpdatesToggle.value as? String, "1")
    }

    @MainActor
    func testMoreAppearanceSelectionRendersAndUpdatesLocally() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.otherElements[moreAppearanceSelection], in: app))
        let darkAppearanceButton = app.buttons[moreAppearanceDarkButton]
        XCTAssertTrue(darkAppearanceButton.waitForExistence(timeout: 10))
        darkAppearanceButton.tap()

        XCTAssertEqual(darkAppearanceButton.value as? String, "Selected")
        XCTAssertEqual(app.buttons[moreAppearanceSystemButton].value as? String, "Not selected")
    }

    @MainActor
    func testMorePrivacySectionRenders() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        XCTAssertTrue(waitForElementAfterScrolling(app.staticTexts[morePrivacyDataSection], in: app))
        XCTAssertTrue(app.staticTexts["Privacy settings"].exists)
        XCTAssertTrue(app.staticTexts["Delete account"].exists)
    }

    @MainActor
    func testMoreDeleteAccountConfirmationOpensAndCancels() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let deleteButton = app.buttons[moreDeleteAccountButton]
        XCTAssertTrue(waitForElementAfterScrolling(deleteButton, in: app))
        deleteButton.tap()

        XCTAssertTrue(app.navigationBars["Delete account"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(moreScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreContactSupportSheetOpens() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let contactSupport = app.buttons[moreContactSupportButton]
        XCTAssertTrue(waitForElementAfterScrolling(contactSupport, in: app))
        contactSupport.tap()

        XCTAssertTrue(app.navigationBars["Contact support"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["contact@kairoid.com"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreLegalPlaceholdersOpen() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let termsButton = app.buttons[moreTermsOfServiceButton]
        XCTAssertTrue(waitForElementAfterScrolling(termsButton, in: app))
        termsButton.tap()
        XCTAssertTrue(app.navigationBars["Terms of Service"].waitForExistence(timeout: 10))
        dismissPresentedSheet(in: app)

        let privacyButton = app.buttons[morePrivacyPolicyButton]
        XCTAssertTrue(waitForElementAfterScrolling(privacyButton, in: app))
        privacyButton.tap()
        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 10))
        dismissPresentedSheet(in: app)

        let cookieButton = app.buttons[moreCookiePolicyButton]
        XCTAssertTrue(waitForElementAfterScrolling(cookieButton, in: app))
        cookieButton.tap()
        XCTAssertTrue(app.navigationBars["Cookie Policy"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreSignOutConfirmationOpens() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let signOutButton = app.buttons[moreSignOutButton]
        XCTAssertTrue(waitForElementAfterScrolling(signOutButton, in: app))
        signOutButton.tap()

        XCTAssertTrue(app.navigationBars["Sign Out"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMoreCancellingSignOutPreservesMoreScreen() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let signOutButton = app.buttons[moreSignOutButton]
        XCTAssertTrue(waitForElementAfterScrolling(signOutButton, in: app))
        signOutButton.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 10))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(moreScreenElement(in: app).waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)[moreAccountSummary].exists)
    }

    @MainActor
    func testMoreConfirmingSignOutReturnsToLoginPlaceholder() throws {
        let app = launchApp(environment: moreEnvironment())

        openMoreTab(in: app)

        let signOutButton = app.buttons[moreSignOutButton]
        XCTAssertTrue(waitForElementAfterScrolling(signOutButton, in: app))
        signOutButton.tap()

        XCTAssertTrue(app.buttons["Sign Out"].waitForExistence(timeout: 10))
        app.buttons["Sign Out"].tap()

        assertLoginPlaceholderVisible(in: app)
    }

    @MainActor
    func testExistingAccountRoutesToLoginPlaceholder() throws {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts[onboardingWelcomeTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[welcomeExistingAccountButton].waitForExistence(timeout: 10))

        app.buttons[welcomeExistingAccountButton].tap()

        assertLoginPlaceholderVisible(in: app)
    }

    @MainActor
    func testLoginSuccessRoutesToMainTabs() throws {
        let app = launchApp(environment: authEnvironment(
            loginResult: "success",
            onboardingStatus: "complete"
        ))

        navigateToLogin(in: app)
        enterText("aman@example.com", into: app.textFields[onboardingLoginEmailField])
        enterText("Password123", into: app.secureTextFields[onboardingLoginPasswordField])

        let submitButton = app.buttons[onboardingLoginSubmitButton]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 10))
        XCTAssertTrue(submitButton.isEnabled)
        submitButton.tap()

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(homeScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    func testLoginInvalidCredentialsShowsInlineError() throws {
        let app = launchApp(environment: authEnvironment(
            loginResult: "invalidCredentials",
            onboardingStatus: "complete"
        ))

        navigateToLogin(in: app)
        enterText("aman@example.com", into: app.textFields[onboardingLoginEmailField])
        enterText("wrong-password", into: app.secureTextFields[onboardingLoginPasswordField])

        let submitButton = app.buttons[onboardingLoginSubmitButton]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 10))
        submitButton.tap()

        XCTAssertTrue(app.staticTexts[onboardingLoginError].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Check your email and password, then try again."].exists)
        XCTAssertTrue(app.staticTexts[onboardingLoginTitle].exists)
    }

    @MainActor
    func testCreateAccountEmptyFormKeepsContinueDisabled() throws {
        let app = launchApp()

        navigateToCreateAccount(in: app)

        let continueButton = app.buttons[createAccountContinueButton]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)
        XCTAssertFalse(app.staticTexts["Enter your first name."].exists)
    }

    @MainActor
    func testCreateAccountShowsInvalidEmailMessage() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@",
            mobile: "9876543210",
            touchedFields: ["emailAddress"]
        ))

        navigateToCreateAccount(in: app)

        XCTAssertTrue(app.staticTexts["Enter a valid email address."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[createAccountContinueButton].isEnabled)
    }

    @MainActor
    func testCreateAccountShowsInvalidMobileMessage() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@example.com",
            mobile: "987654321",
            touchedFields: ["mobileNumber"]
        ))

        navigateToCreateAccount(in: app)

        XCTAssertTrue(app.staticTexts["Enter a valid 10-digit Indian mobile number."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[createAccountContinueButton].isEnabled)
    }

    @MainActor
    func testCreateAccountValidFormEnablesContinue() throws {
        let app = launchApp(environment: createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@example.com",
            mobile: "9876543210"
        ))

        navigateToCreateAccount(in: app)

        let continueButton = app.buttons[createAccountContinueButton]
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    func testCreateAccountLoginButtonRoutesToLoginPlaceholder() throws {
        let app = launchApp()

        navigateToCreateAccount(in: app)

        let loginButton = app.buttons[createAccountLoginButton]
        XCTAssertTrue(loginButton.waitForExistence(timeout: 10))
        loginButton.tap()

        assertLoginPlaceholderVisible(in: app)
    }

    @MainActor
    func testCreateAccountConflictShowsSubmissionError() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(authEnvironment(signupStartResult: "conflict")) { _, override in override })

        navigateToCreateAccount(in: app)

        let continueButton = app.buttons[createAccountContinueButton]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        XCTAssertTrue(app.staticTexts["An account with this email already exists."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[onboardingCreateAccountTitle].exists)
    }

    @MainActor
    func testAuthenticatedSignupHappyPathRoutesToChooseStart() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(authEnvironment(
                signupStartResult: "success",
                emailVerifyResult: "success",
                onboardingStatus: "complete_profile"
            )) { _, override in override })

        navigateToVerifyIdentityIntroduction(in: app)
        continueToEmailVerification(in: app)
        completeEmailVerification(in: app)
        continueFromEmailSuccess(in: app)
        completeMobileVerification(in: app)

        XCTAssertTrue(app.buttons[onboardingContinueButton].waitForExistence(timeout: 10))
        app.buttons[onboardingContinueButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingChooseStartTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    func testVerifyIdentityIntroductionContinuesToEmailVerification() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("verifyIdentity")) { _, override in override })

        XCTAssertTrue(app.buttons[verifyIdentityIntroContinueButton].waitForExistence(timeout: 10))
        app.buttons[verifyIdentityIntroContinueButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityEmailTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    func testEmailVerificationSendCodeEnablesCountdownState() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("verifyIdentity")) { _, override in override }
            .merging(verifyIdentityEnvironment(phase: "email", emailState: "codeSent")) { _, override in override })

        let resendCodeControl = app.descendants(matching: .any)
            .matching(identifier: verifyIdentityEmailResendCodeButton)
            .firstMatch

        XCTAssertTrue(resendCodeControl.waitForExistence(timeout: 10))
        XCTAssertFalse(resendCodeControl.isEnabled)
    }

    @MainActor
    func testEmailVerificationShowsInvalidOTPMessage() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("verifyIdentity")) { _, override in override }
            .merging(verifyIdentityEnvironment(phase: "email", emailState: "invalidCode")) { _, override in override })

        XCTAssertTrue(app.staticTexts["Enter the full 6-digit code."].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons[verifyIdentityEmailVerifyButton].isEnabled)
    }

    @MainActor
    func testEmailVerificationValidOTPEnablesVerify() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("verifyIdentity")) { _, override in override }
            .merging(verifyIdentityEnvironment(phase: "email", emailState: "validCode")) { _, override in override })

        XCTAssertTrue(app.buttons[verifyIdentityEmailVerifyButton].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[verifyIdentityEmailVerifyButton].isEnabled)
    }

    @MainActor
    func testEmailVerificationShowsSuccessState() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("verifyIdentity")) { _, override in override }
            .merging(verifyIdentityEnvironment(phase: "email", emailState: "verified")) { _, override in override })

        XCTAssertTrue(app.staticTexts[verifyIdentityEmailSuccess].waitForExistence(timeout: 10))
    }

    @MainActor
    func testMobileVerificationShowsSuccessAndRoutesToChooseStartPlaceholder() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("verifyIdentity")) { _, override in override }
            .merging(verifyIdentityEnvironment(phase: "mobile", mobileState: "verified")) { _, override in override })

        XCTAssertTrue(app.staticTexts[verifyIdentityMobileSuccess].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[onboardingContinueButton].waitForExistence(timeout: 10))
        app.buttons[onboardingContinueButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingChooseStartTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    func testChooseStartContinueRemainsDisabledUntilSelectionIsMade() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("chooseStart")) { _, override in override })

        let continueButton = app.buttons[chooseStartContinueButton]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        XCTAssertFalse(continueButton.isEnabled)
    }

    @MainActor
    func testChooseStartResumeSelectionEnablesContinue() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("chooseStart")) { _, override in override })

        let resumeOption = app.buttons[chooseStartResumeOptionButton]
        XCTAssertTrue(resumeOption.waitForExistence(timeout: 10))
        resumeOption.tap()

        XCTAssertEqual(resumeOption.value as? String, "Selected")
        XCTAssertTrue(app.buttons[chooseStartContinueButton].isEnabled)
    }

    @MainActor
    func testChooseStartManualSelectionEnablesContinue() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("chooseStart")) { _, override in override })

        let manualOption = app.buttons[chooseStartManualOptionButton]
        XCTAssertTrue(manualOption.waitForExistence(timeout: 10))
        manualOption.tap()

        XCTAssertEqual(manualOption.value as? String, "Selected")
        XCTAssertTrue(app.buttons[chooseStartContinueButton].isEnabled)
    }

    @MainActor
    func testChooseStartContinueRoutesToResumeImportPlaceholder() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("chooseStart")) { _, override in override })

        continueFromChooseStart(in: app, selecting: chooseStartResumeOptionButton)

        XCTAssertTrue(app.staticTexts[onboardingResumeImportTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[resumeImportChooseButton].waitForExistence(timeout: 10))
    }

    @MainActor
    func testChooseStartContinueRoutesToManualProfileFlow() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("chooseStart")) { _, override in override })

        continueFromChooseStart(in: app, selecting: chooseStartManualOptionButton)

        XCTAssertTrue(app.staticTexts[onboardingManualProfileTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields[manualProfileCurrentCityField].waitForExistence(timeout: 10))
    }

    @MainActor
    func testResumeImportManualButtonRoutesToManualProfileFlow() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override })

        XCTAssertTrue(app.buttons[resumeImportManualButton].waitForExistence(timeout: 10))
        app.buttons[resumeImportManualButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingManualProfileTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields[manualProfileCurrentCountryField].waitForExistence(timeout: 10))
    }

    @MainActor
    func testManualProfileCompletePathRoutesToPassportCreatedExperience() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("chooseStart")) { _, override in override }
            .merging(manualProfileEnvironment(phase: "basicProfile")) { _, override in override })

        continueFromChooseStart(in: app, selecting: chooseStartManualOptionButton)
        XCTAssertTrue(app.staticTexts[onboardingManualProfileTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[manualProfileBasicContinueButton].isEnabled)
        app.buttons[manualProfileBasicContinueButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingManualProfileEmploymentTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[manualProfileEmploymentContinueButton].isEnabled)
        app.buttons[manualProfileEmploymentContinueButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingManualProfileEducationTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[manualProfileEducationContinueButton].isEnabled)
        app.buttons[manualProfileEducationContinueButton].tap()

        XCTAssertTrue(app.staticTexts[onboardingPassportCreatedTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements[passportCreatedSummaryCard].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[passportCreatedTrustScoreMessage].waitForExistence(timeout: 10))
    }

    @MainActor
    func testManualProfileEmploymentCanAddAndRemoveEntry() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(manualProfileEnvironment(phase: "employment")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingManualProfileEmploymentTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[manualProfileEmploymentAddButton].waitForExistence(timeout: 10))
        app.buttons[manualProfileEmploymentAddButton].tap()

        let secondCompanyField = app.textFields[manualProfileEmploymentCompanyField(index: 1)]
        XCTAssertTrue(secondCompanyField.waitForExistence(timeout: 10))

        let secondDeleteButton = app.buttons[manualProfileEmploymentDeleteButton(index: 1)]
        XCTAssertTrue(secondDeleteButton.waitForExistence(timeout: 10))
        secondDeleteButton.tap()

        XCTAssertFalse(secondCompanyField.exists)
    }

    @MainActor
    func testManualProfileEducationCanAddAndRemoveEntry() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(manualProfileEnvironment(phase: "education")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingManualProfileEducationTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[manualProfileEducationAddButton].waitForExistence(timeout: 10))
        app.buttons[manualProfileEducationAddButton].tap()

        let secondInstitutionField = app.textFields[manualProfileEducationInstitutionField(index: 1)]
        XCTAssertTrue(secondInstitutionField.waitForExistence(timeout: 10))

        let secondDeleteButton = app.buttons[manualProfileEducationDeleteButton(index: 1)]
        XCTAssertTrue(secondDeleteButton.waitForExistence(timeout: 10))
        secondDeleteButton.tap()

        XCTAssertFalse(secondInstitutionField.exists)
    }

    @MainActor
    func testResumeImportInitialStateHasNoSelectedFile() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingResumeImportTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[resumeImportChooseButton].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Resume selected"].exists)
    }

    @MainActor
    func testResumeImportSeededSelectedStateShowsFileMetadata() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(resumeImportEnvironment(phase: "selected", fileName: "Candidate_Resume.docx")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingResumeImportTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Resume selected"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[resumeImportFileName].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[resumeImportPrepareButton].waitForExistence(timeout: 10))
    }

    @MainActor
    func testResumeImportProcessingStateShowsDeterministicStatus() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(resumeImportEnvironment(
                phase: "processingPreparing",
                autoAdvance: false
            )) { _, override in override })

        XCTAssertTrue(app.staticTexts[resumeImportProcessingTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Preparing your resume"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testResumeImportFailureStateShowsRetryAction() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(resumeImportEnvironment(phase: "failed")) { _, override in override })

        XCTAssertTrue(app.staticTexts[resumeImportFailureMessage].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[resumeImportRetryButton].waitForExistence(timeout: 10))
    }

    @MainActor
    func testResumeImportReviewStateCanChooseAnotherResume() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(resumeImportEnvironment(phase: "readyForReview")) { _, override in override })

        XCTAssertTrue(app.buttons[resumeImportChooseAnotherButton].waitForExistence(timeout: 10))
        app.buttons[resumeImportChooseAnotherButton].tap()

        XCTAssertTrue(app.buttons[resumeImportChooseButton].waitForExistence(timeout: 10))
    }

    @MainActor
    func testResumeImportLooksGoodRoutesToPassportCreatedExperience() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("resumeImportOrQuickProfile")) { _, override in override }
            .merging(resumeImportEnvironment(phase: "readyForReview")) { _, override in override })

        tapWhenHittable(app.buttons[resumeImportLooksGoodButton], in: app)

        XCTAssertTrue(app.staticTexts[onboardingPassportCreatedTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements[passportCreatedSummaryCard].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPassportCreatedContinueRoutesToHomeOverview() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("passportCreated")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingPassportCreatedTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[passportCreatedContinueHomeButton].waitForExistence(timeout: 10))
        app.buttons[passportCreatedContinueHomeButton].tap()

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["candidate.home.screen"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testPassportCreatedReviewProfileRoutesToPassportPlaceholder() throws {
        let app = launchApp(environment: validCreateAccountEnvironment()
            .merging(onboardingStepEnvironment("passportCreated")) { _, override in override })

        XCTAssertTrue(app.staticTexts[onboardingPassportCreatedTitle].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[passportCreatedReviewProfileButton].waitForExistence(timeout: 10))
        app.buttons[passportCreatedReviewProfileButton].tap()

        XCTAssertTrue(app.otherElements["candidate.tabShell"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["candidate.screen.passport"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func launchApp(environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = baseLaunchArguments
        app.launchEnvironment = baseLaunchEnvironment.merging(environment) { _, override in override }
        app.launch()
        return app
    }

    @MainActor
    private func navigateToCreateAccount(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[onboardingGetStartedButton].waitForExistence(timeout: 10))
        app.buttons[onboardingGetStartedButton].tap()
        XCTAssertTrue(app.textFields[createAccountFirstNameField].waitForExistence(timeout: 10))
    }

    @MainActor
    private func navigateToLogin(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[welcomeExistingAccountButton].waitForExistence(timeout: 10))
        app.buttons[welcomeExistingAccountButton].tap()
        XCTAssertTrue(app.otherElements[onboardingLoginTitle].waitForExistence(timeout: 10) || app.staticTexts[onboardingLoginTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func navigateToVerifyIdentityIntroduction(in app: XCUIApplication) {
        navigateToCreateAccount(in: app)
        XCTAssertTrue(app.buttons[createAccountContinueButton].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[createAccountContinueButton].isEnabled)
        app.buttons[createAccountContinueButton].tap()
        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func navigateToEmailVerification(in app: XCUIApplication) {
        navigateToVerifyIdentityIntroduction(in: app)
        continueToEmailVerification(in: app)
    }

    @MainActor
    private func continueToEmailVerification(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[verifyIdentityIntroContinueButton].waitForExistence(timeout: 10))
        app.buttons[verifyIdentityIntroContinueButton].tap()
        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityEmailTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func navigateToMobileVerification(in app: XCUIApplication) {
        navigateToEmailVerification(in: app)
        completeEmailVerification(in: app)
        continueFromEmailSuccess(in: app)
        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityMobileTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func navigateToChooseStart(in app: XCUIApplication) {
        navigateToMobileVerification(in: app)
        completeMobileVerification(in: app)
        XCTAssertTrue(app.buttons[onboardingContinueButton].waitForExistence(timeout: 10))
        app.buttons[onboardingContinueButton].tap()
        XCTAssertTrue(app.staticTexts[onboardingChooseStartTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func sendEmailCode(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[verifyIdentityEmailSendCodeButton].waitForExistence(timeout: 10))
        app.buttons[verifyIdentityEmailSendCodeButton].tap()
        XCTAssertTrue(app.textFields[verifyIdentityEmailCodeField].waitForExistence(timeout: 10))
    }

    @MainActor
    private func completeEmailVerification(in app: XCUIApplication) {
        sendEmailCode(in: app)
        focusOTPField(identifier: verifyIdentityEmailCodeField, in: app)
        app.typeText("123456")
        XCTAssertTrue(app.buttons[verifyIdentityEmailVerifyButton].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[verifyIdentityEmailVerifyButton].isEnabled)
        app.buttons[verifyIdentityEmailVerifyButton].tap()
        XCTAssertTrue(app.staticTexts[verifyIdentityEmailSuccess].waitForExistence(timeout: 10))
    }

    @MainActor
    private func continueFromEmailSuccess(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[onboardingContinueButton].waitForExistence(timeout: 10))
        app.buttons[onboardingContinueButton].tap()
        XCTAssertTrue(app.staticTexts[onboardingVerifyIdentityMobileTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func completeMobileVerification(in app: XCUIApplication) {
        XCTAssertTrue(app.buttons[verifyIdentityMobileSendCodeButton].waitForExistence(timeout: 10))
        app.buttons[verifyIdentityMobileSendCodeButton].tap()
        focusOTPField(identifier: verifyIdentityMobileCodeField, in: app)
        app.typeText("123456")
        XCTAssertTrue(app.buttons[verifyIdentityMobileVerifyButton].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[verifyIdentityMobileVerifyButton].isEnabled)
        app.buttons[verifyIdentityMobileVerifyButton].tap()
        XCTAssertTrue(app.staticTexts[verifyIdentityMobileSuccess].waitForExistence(timeout: 10))
    }

    @MainActor
    private func focusOTPField(identifier: String, in app: XCUIApplication) {
        let otpField = app.textFields[identifier]
        XCTAssertTrue(otpField.waitForExistence(timeout: 10))
        otpField.tap()
    }

    @MainActor
    private func continueFromChooseStart(in app: XCUIApplication, selecting optionIdentifier: String) {
        let option = app.buttons[optionIdentifier]
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()

        let continueButton = app.buttons[chooseStartContinueButton]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        let enabledPredicate = NSPredicate(format: "isEnabled == true")
        let enabledExpectation = XCTNSPredicateExpectation(
            predicate: enabledPredicate,
            object: continueButton
        )
        XCTAssertEqual(XCTWaiter().wait(for: [enabledExpectation], timeout: 5), .completed)
        continueButton.tap()
    }

    @MainActor
    private func assertLoginPlaceholderVisible(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts[onboardingLoginTitle].waitForExistence(timeout: 10))
    }

    @MainActor
    private func homeScreenElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: homeScreen)
            .firstMatch
    }

    @MainActor
    private func homeTrustScoreCardElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: homeTrustScoreCard)
            .firstMatch
    }

    @MainActor
    private func careerScreenElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: careerScreen)
            .firstMatch
    }

    @MainActor
    private func passportScreenElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: passportScreen)
            .firstMatch
    }

    @MainActor
    private func verifyScreenElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: verifyScreen)
            .firstMatch
    }

    @MainActor
    private func moreScreenElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: moreScreen)
            .firstMatch
    }

    @MainActor
    private func openCareerTab(in app: XCUIApplication) {
        let careerTab = app.tabBars.buttons["Career"]
        XCTAssertTrue(careerTab.waitForExistence(timeout: 10))
        let careerScreen = careerScreenElement(in: app)

        if careerScreen.exists {
            return
        }

        let deadline = Date().addingTimeInterval(10)

        while Date() < deadline {
            tapWhenHittable(careerTab, in: app, timeout: 2)

            if careerScreen.waitForExistence(timeout: 1) {
                return
            }
        }

        XCTAssertTrue(careerScreen.waitForExistence(timeout: 1))
    }

    @MainActor
    private func openPassportTab(in app: XCUIApplication) {
        let passportTab = app.tabBars.buttons["Passport"]
        XCTAssertTrue(passportTab.waitForExistence(timeout: 10))
        passportTab.tap()
        XCTAssertTrue(passportScreenElement(in: app).waitForExistence(timeout: 10))
    }

    @MainActor
    private func openVerifyTab(in app: XCUIApplication) {
        let verifyTab = app.tabBars.buttons["Verify"]
        XCTAssertTrue(verifyTab.waitForExistence(timeout: 10))
        let verifyScreen = verifyScreenElement(in: app)

        if verifyScreen.exists {
            return
        }

        let deadline = Date().addingTimeInterval(10)

        while Date() < deadline {
            tapWhenHittable(verifyTab, in: app, timeout: 2)

            if verifyScreen.waitForExistence(timeout: 1) {
                return
            }
        }

        XCTAssertTrue(verifyScreen.waitForExistence(timeout: 1))
    }

    @MainActor
    private func openMoreTab(in app: XCUIApplication) {
        let moreTab = app.tabBars.buttons["More"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        let moreScreen = moreScreenElement(in: app)

        if moreScreen.exists {
            return
        }

        let deadline = Date().addingTimeInterval(10)

        while Date() < deadline {
            tapWhenHittable(moreTab, in: app, timeout: 2)

            if moreScreen.waitForExistence(timeout: 1) {
                return
            }
        }

        XCTAssertTrue(moreScreen.waitForExistence(timeout: 1))
    }

    @MainActor
    private func waitForElementAfterScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) -> Bool {
        if element.waitForExistence(timeout: 2) {
            return true
        }

        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            app.swipeUp()

            if element.exists {
                return true
            }
        }

        return element.exists
    }

    @MainActor
    private func enterText(_ value: String, into element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 10))

        let focusedPredicate = NSPredicate(format: "hasKeyboardFocus == true")
        func waitForKeyboardFocus() -> XCTWaiter.Result {
            let expectation = XCTNSPredicateExpectation(
                predicate: focusedPredicate,
                object: element
            )
            return XCTWaiter().wait(for: [expectation], timeout: 2)
        }

        if waitForKeyboardFocus() != .completed {
            element.tap()
        }

        if waitForKeyboardFocus() != .completed {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }

        XCTAssertEqual(waitForKeyboardFocus(), .completed)
        element.typeText(value)
    }

    @MainActor
    private func tapWhenHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 10
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout))

        let scrollView = app.scrollViews.firstMatch
        let deadline = Date().addingTimeInterval(timeout)

        while !element.isHittable, Date() < deadline {
            guard scrollView.exists else {
                break
            }

            scrollView.swipeUp()
        }

        XCTAssertTrue(element.isHittable)
        element.tap()
    }

    @MainActor
    private func dismissPresentedSheet(in app: XCUIApplication) {
        let doneButton = app.navigationBars.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        doneButton.tap()
    }

    private func createAccountEnvironment(
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        mobile: String = "",
        password: String = "",
        touchedFields: Set<String> = []
    ) -> [String: String] {
        [
            "KAIRO_UI_TEST_CREATE_ACCOUNT_FIRST_NAME": firstName,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_LAST_NAME": lastName,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_EMAIL": email,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_MOBILE": mobile,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_PASSWORD": password,
            "KAIRO_UI_TEST_CREATE_ACCOUNT_TOUCHED_FIELDS": touchedFields.sorted().joined(separator: ",")
        ]
    }

    private func validCreateAccountEnvironment() -> [String: String] {
        createAccountEnvironment(
            firstName: "Aman",
            lastName: "Jha",
            email: "aman@example.com",
            mobile: "9876543210",
            password: "StrongPassword123!"
        )
    }

    private func onboardingStepEnvironment(_ step: String) -> [String: String] {
        [
            "KAIRO_UI_TEST_ONBOARDING_STEP": step
        ]
    }

    private func authEnvironment(
        loginResult: String = "success",
        signupStartResult: String = "success",
        emailVerifyResult: String = "success",
        onboardingStatus: String = "complete_profile"
    ) -> [String: String] {
        [
            "KAIRO_UI_TEST_LOGIN_RESULT": loginResult,
            "KAIRO_UI_TEST_SIGNUP_START_RESULT": signupStartResult,
            "KAIRO_UI_TEST_EMAIL_VERIFY_RESULT": emailVerifyResult,
            "KAIRO_UI_TEST_AUTH_ONBOARDING_STATUS": onboardingStatus
        ]
    }

    private func verifyIdentityEnvironment(
        phase: String,
        emailState: String = "pristine",
        mobileState: String = "pristine"
    ) -> [String: String] {
        [
            "KAIRO_UI_TEST_VERIFY_IDENTITY_PHASE": phase,
            "KAIRO_UI_TEST_VERIFY_IDENTITY_EMAIL_STATE": emailState,
            "KAIRO_UI_TEST_VERIFY_IDENTITY_MOBILE_STATE": mobileState
        ]
    }

    private func resumeImportEnvironment(
        phase: String,
        fileName: String = "Aman_Jha_Resume.pdf",
        autoAdvance: Bool = true
    ) -> [String: String] {
        [
            "KAIRO_UI_TEST_RESUME_IMPORT_PHASE": phase,
            "KAIRO_UI_TEST_RESUME_IMPORT_FILE_NAME": fileName,
            "KAIRO_UI_TEST_RESUME_IMPORT_AUTO_ADVANCE": autoAdvance ? "1" : "0"
        ]
    }

    private func manualProfileEnvironment(
        phase: String,
        prefill: Bool = true
    ) -> [String: String] {
        [
            "KAIRO_UI_TEST_MANUAL_PROFILE_PHASE": phase,
            "KAIRO_UI_TEST_MANUAL_PROFILE_PREFILL": prefill ? "1" : "0"
        ]
    }

    private func homeEnvironment(state: String = "populated") -> [String: String] {
        [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome",
            "KAIRO_UI_TEST_HOME_STATE": state
        ]
    }

    private func careerEnvironment(state: String = "populated") -> [String: String] {
        [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome",
            "KAIRO_UI_TEST_CAREER_STATE": state
        ]
    }

    private func passportEnvironment(state: String = "populated") -> [String: String] {
        [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome",
            "KAIRO_UI_TEST_PASSPORT_STATE": state
        ]
    }

    private func verifyEnvironment(state: String = "populated") -> [String: String] {
        [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome",
            "KAIRO_UI_TEST_VERIFY_STATE": state
        ]
    }

    private func moreEnvironment(state: String = "populated") -> [String: String] {
        [
            demoModeKey: "true",
            appEnvironmentKey: "staging",
            uiTestRouteKey: "demoHome",
            "KAIRO_UI_TEST_MORE_STATE": state
        ]
    }

    private func verifyRequestActionButton(id: String) -> String {
        "candidate.verify.request.action.\(id)"
    }

    private func manualProfileEmploymentCompanyField(index: Int) -> String {
        "onboarding.manualProfile.employment.company.\(index)"
    }

    private func manualProfileEmploymentJobTitleField(index: Int) -> String {
        "onboarding.manualProfile.employment.jobTitle.\(index)"
    }

    private func manualProfileEmploymentTypeField(index: Int) -> String {
        "onboarding.manualProfile.employment.type.\(index)"
    }

    private func manualProfileEmploymentStartMonthField(index: Int) -> String {
        "onboarding.manualProfile.employment.startMonth.\(index)"
    }

    private func manualProfileEmploymentStartYearField(index: Int) -> String {
        "onboarding.manualProfile.employment.startYear.\(index)"
    }

    private func manualProfileEmploymentDeleteButton(index: Int) -> String {
        "onboarding.manualProfile.employment.delete.\(index)"
    }

    private func manualProfileEmploymentCurrentToggle(index: Int) -> String {
        "onboarding.manualProfile.employment.current.\(index)"
    }

    private func manualProfileEmploymentEndMonthField(index: Int) -> String {
        "onboarding.manualProfile.employment.endMonth.\(index)"
    }

    private func manualProfileEmploymentEndYearField(index: Int) -> String {
        "onboarding.manualProfile.employment.endYear.\(index)"
    }

    private func manualProfileEducationInstitutionField(index: Int) -> String {
        "onboarding.manualProfile.education.institution.\(index)"
    }

    private func manualProfileEducationDegreeField(index: Int) -> String {
        "onboarding.manualProfile.education.degree.\(index)"
    }

    private func manualProfileEducationFieldOfStudyField(index: Int) -> String {
        "onboarding.manualProfile.education.fieldOfStudy.\(index)"
    }

    private func manualProfileEducationStartYearField(index: Int) -> String {
        "onboarding.manualProfile.education.startYear.\(index)"
    }

    private func manualProfileEducationEndYearField(index: Int) -> String {
        "onboarding.manualProfile.education.endYear.\(index)"
    }

    private func manualProfileEducationDeleteButton(index: Int) -> String {
        "onboarding.manualProfile.education.delete.\(index)"
    }
}
