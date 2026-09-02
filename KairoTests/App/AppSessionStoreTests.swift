import XCTest
@testable import Kairo

@MainActor
final class AppSessionStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ManualProfileDraftStore.clear()
    }

    override func tearDown() {
        ManualProfileDraftStore.clear()
        super.tearDown()
    }

    func test_bootstrapRoutesSignedOutWhenNoStoredSessionExists() async {
        let router = AppRouter()
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(
                currentStep: .complete,
                passportReady: true,
                completionPercentage: 100,
                isOnboardingComplete: true
            )
        )
        let sessionService = StubSessionService(
            hasAccessToken: false,
            hasRefreshToken: false,
            signupSessionID: nil
        )

        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: authService,
            sessionService: sessionService,
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
    }

    func test_bootstrapRoutesToVerifyIdentityWhenSignupSessionExists() async {
        let router = AppRouter()
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(
                currentStep: .complete,
                passportReady: true,
                completionPercentage: 100,
                isOnboardingComplete: true
            )
        )
        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: authService,
            sessionService: StubSessionService(
                hasAccessToken: false,
                hasRefreshToken: false,
                signupSessionID: "signup-session-123"
            ),
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.verifyIdentity))
        XCTAssertEqual(store.signupRecovery?.emailMasked, "aa***@example.com")
        XCTAssertEqual(store.signupRecovery?.phoneMasked, "+91******3210")
        XCTAssertEqual(authService.recoveryCallCount, 1)
    }

    func test_expiredRecoveredSignupSessionIsDiscardedAndRoutesSignedOut() async {
        let router = AppRouter()
        let sessionService = StubSessionService(
            hasAccessToken: false,
            hasRefreshToken: false,
            signupSessionID: "expired-signup-session"
        )
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(currentStep: .verifyIdentity),
            recoveryResponse: .fixture(state: .expired, nextStep: nil)
        )
        let store = makeStore(
            router: router,
            authService: authService,
            sessionService: sessionService
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
        XCTAssertNil(store.signupRecovery)
        let signupSessionID = await sessionService.signupSessionID
        XCTAssertNil(signupSessionID)
    }

    func test_unknownRecoveredSignupSessionIsDiscardedWithoutCreatingReplacement() async {
        let router = AppRouter()
        let sessionService = StubSessionService(
            hasAccessToken: false,
            hasRefreshToken: false,
            signupSessionID: "unknown-signup-session"
        )
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(currentStep: .verifyIdentity),
            recoveryError: NetworkError.api(APIError(
                statusCode: 404,
                code: .notFound,
                message: "Signup session not found",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        )
        let store = makeStore(
            router: router,
            authService: authService,
            sessionService: sessionService
        )

        await store.refreshLaunchRoute()

        let signupSessionID = await sessionService.signupSessionID
        XCTAssertNil(signupSessionID)
        XCTAssertEqual(authService.recoveryCallCount, 1)
        XCTAssertNil(store.signupRecovery)
        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
    }

    func test_completedRecoveredSignupSessionRoutesSignedOutWithoutCreatingReplacement() async {
        let router = AppRouter()
        let sessionService = StubSessionService(
            hasAccessToken: false,
            hasRefreshToken: false,
            signupSessionID: "completed-signup-session"
        )
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(currentStep: .complete),
            recoveryResponse: .fixture(state: .completed, nextStep: .completed)
        )
        let store = makeStore(
            router: router,
            authService: authService,
            sessionService: sessionService
        )

        await store.refreshLaunchRoute()

        let signupSessionID = await sessionService.signupSessionID
        XCTAssertNil(signupSessionID)
        XCTAssertEqual(authService.recoveryCallCount, 1)
        XCTAssertNil(store.signupRecovery)
        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
    }

    func test_transportFailurePreservesSignupCredentialForRetry() async {
        let router = AppRouter()
        let sessionService = StubSessionService(
            hasAccessToken: false,
            hasRefreshToken: false,
            signupSessionID: "recoverable-signup-session"
        )
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(currentStep: .verifyIdentity),
            recoveryError: NetworkError.transport("offline")
        )
        let store = makeStore(
            router: router,
            authService: authService,
            sessionService: sessionService
        )

        await store.refreshLaunchRoute()

        guard case .failed(let message) = store.launchPhase else {
            return XCTFail("Expected recovery to remain retryable after a transport failure.")
        }
        XCTAssertTrue(message.contains("network"))
        let signupSessionID = await sessionService.signupSessionID
        XCTAssertEqual(signupSessionID, "recoverable-signup-session")
        XCTAssertNil(store.signupRecovery)
    }

    func test_startingOverRecoveredSignupClearsOnlySignupCredentialAndRoutesToCreateAccount() async {
        let router = AppRouter()
        let sessionService = StubSessionService(
            hasAccessToken: false,
            hasRefreshToken: false,
            signupSessionID: "recoverable-signup-session"
        )
        let store = makeStore(
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: .fixture(currentStep: .verifyIdentity)
            ),
            sessionService: sessionService
        )

        await store.refreshLaunchRoute()
        await store.abandonPendingSignup()

        let signupSessionID = await sessionService.signupSessionID
        XCTAssertNil(signupSessionID)
        XCTAssertNil(store.signupRecovery)
        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.createAccount))
    }

    func test_completedAccountDeletionClearsLocalSessionAndRoutesSignedOut() async {
        let router = AppRouter(rootDestination: .mainTabs, selectedTab: .more, onboardingPath: [])
        let sessionService = StubSessionService(
            hasAccessToken: true,
            hasRefreshToken: true,
            signupSessionID: "stale-signup-session"
        )
        let store = makeStore(
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: .fixture(currentStep: .complete, isOnboardingComplete: true)
            ),
            sessionService: sessionService
        )

        await store.completeAccountDeletion()

        let didClearSession = await sessionService.didClearSession
        let signupSessionID = await sessionService.signupSessionID
        XCTAssertTrue(didClearSession)
        XCTAssertNil(signupSessionID)
        XCTAssertNil(store.currentUser)
        XCTAssertNil(store.signupRecovery)
        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
    }

    func test_bootstrapRoutesToMainTabsForCompletedOnboarding() async {
        let router = AppRouter()
        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: .fixture(
                    currentStep: .complete,
                    passportReady: true,
                    completionPercentage: 100,
                    isOnboardingComplete: true
                )
            ),
            sessionService: StubSessionService(
                hasAccessToken: true,
                hasRefreshToken: true,
                signupSessionID: nil
            ),
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .mainTabs)
        XCTAssertEqual(router.selectedTab, .home)
        XCTAssertEqual(store.currentUser?.email, "aarav@example.com")
        XCTAssertEqual(store.currentUser?.fullName, "Aarav Mehta")
    }

    func test_bootstrapRoutesToChooseStartForIncompleteProfile() async {
        let router = AppRouter()
        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: .fixture(
                    currentStep: .completeProfile,
                    completedSteps: ["verify_email", "verify_phone"],
                    missingRequirements: ["headline"],
                    nextRecommendedStep: "complete_profile",
                    completionPercentage: 75
                )
            ),
            sessionService: StubSessionService(
                hasAccessToken: true,
                hasRefreshToken: true,
                signupSessionID: nil
            ),
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.chooseStart))
    }

    func test_bootstrapRoutesToManualProfileAfterCompletedResumeImport() async {
        let router = AppRouter()
        let preparedDraft = ManualProfileFlowState(
            basicProfile: ManualProfileBasicDraft(
                fullName: "Aarav Mehta",
                professionalHeadline: "Product Operations Manager",
                currentRole: "",
                industry: "",
                yearsOfExperience: "",
                currentCity: "Bengaluru",
                currentCountry: "India"
            )
        )
        let manualProfileService = StubManualProfileService(preparedDraft: preparedDraft)
        let resumeImportService = StubResumeImportService(
            workflowSnapshot: ResumeImportWorkflowSnapshot(
                resume: ResumeRecord(
                    id: "resume_123",
                    originalFilename: "Kairo_Synthetic_Resume_QA.pdf",
                    contentType: "application/pdf",
                    fileSizeBytes: 3_072,
                    uploadStatus: .uploaded,
                    processingStatus: .needsReview,
                    createdAt: Date(timeIntervalSince1970: 1_786_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_786_000_100)
                ),
                reviewSession: ResumeReviewSession(
                    id: "review_123",
                    resumeID: "resume_123",
                    parsedResultID: "parsed_123",
                    status: .imported,
                    schemaVersion: "resume_review.v1",
                    version: 3,
                    items: [],
                    createdAt: Date(timeIntervalSince1970: 1_786_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_786_000_100)
                ),
                importBatch: nil
            ),
            recoveryState: ResumeImportRecoveryState(
                reviewSession: ResumeReviewSession(
                    id: "review_123",
                    resumeID: "resume_123",
                    parsedResultID: "parsed_123",
                    status: .imported,
                    schemaVersion: "resume_review.v1",
                    version: 3,
                    items: [],
                    createdAt: Date(timeIntervalSince1970: 1_786_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_786_000_100)
                ),
                importBatch: ResumeImportBatch(
                    id: "batch_123",
                    reviewSessionID: "review_123",
                    status: "completed",
                    totalCount: 12,
                    importedCount: 12,
                    linkedCount: 0,
                    skippedCount: 0,
                    failedCount: 0,
                    blockedCount: 0,
                    incompleteCount: 5,
                    entityCounts: [:],
                    results: [],
                    createdAt: Date(timeIntervalSince1970: 1_786_000_000),
                    updatedAt: Date(timeIntervalSince1970: 1_786_000_100)
                ),
                completionResult: ResumeImportCompletionResult(
                    user: UserPublicDTO.fixture.asDomainModel(),
                    onboardingStatus: .fixture(
                        currentStep: .completeProfile,
                        completedSteps: ["verify_email", "verify_phone", "resume_import"],
                        missingRequirements: ["current_role", "industry", "years_of_experience"],
                        nextRecommendedStep: "complete_profile",
                        completionPercentage: 88,
                        isOnboardingComplete: false
                    )
                ),
                disposition: .importCompleted
            )
        )

        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: .fixture(
                    currentStep: .completeProfile,
                    completedSteps: ["verify_email", "verify_phone"],
                    missingRequirements: ["current_role", "industry", "years_of_experience"],
                    nextRecommendedStep: "complete_profile",
                    completionPercentage: 75
                )
            ),
            sessionService: StubSessionService(
                hasAccessToken: true,
                hasRefreshToken: true,
                signupSessionID: nil
            ),
            manualProfileService: manualProfileService,
            resumeImportService: resumeImportService
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.resumeImportOrQuickProfile))
        XCTAssertEqual(ManualProfileDraftStore.load(), preparedDraft)
        let prepareDraftCallCount = await manualProfileService.prepareDraftCallCount
        XCTAssertEqual(prepareDraftCallCount, 1)
        let restoreWorkflowCallCount = await resumeImportService.restoreWorkflowCallCount
        let reconcileCallCount = await resumeImportService.reconcileCallCount
        XCTAssertEqual(restoreWorkflowCallCount, 1)
        XCTAssertEqual(reconcileCallCount, 1)
    }

    func test_signOutReturnsToOnboarding() async {
        let router = AppRouter(rootDestination: .mainTabs, selectedTab: .more, onboardingPath: [])
        let authService = StubAuthService(
            user: .fixture,
            onboardingStatus: .fixture(
                currentStep: .complete,
                passportReady: true,
                completionPercentage: 100,
                isOnboardingComplete: true
            )
        )

        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: authService,
            sessionService: StubSessionService(
                hasAccessToken: true,
                hasRefreshToken: true,
                signupSessionID: nil
            ),
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.signOut()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
        XCTAssertTrue(authService.didLogout)
        XCTAssertNil(store.currentUser)
    }

    func test_bootstrapRoutesToVerifyIdentityForBackendVerifyIdentityStep() async {
        let router = AppRouter()
        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: .fixture(
                    currentStep: .verifyIdentity,
                    nextRecommendedStep: "verify_identity",
                    completionPercentage: 25
                )
            ),
            sessionService: StubSessionService(
                hasAccessToken: true,
                hasRefreshToken: true,
                signupSessionID: nil
            ),
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.verifyIdentity))
    }

    func test_bootstrapFailsRecoverablyForUnknownOnboardingStep() async {
        let router = AppRouter()
        let store = AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: StubAuthService(
                user: .fixture,
                onboardingStatus: OnboardingStatusResponseDTO(
                    currentStep: "future_step",
                    emailVerified: true,
                    phoneVerified: true,
                    passportReady: false,
                    completedSteps: ["verify_email", "verify_phone"],
                    missingRequirements: ["headline"],
                    nextRecommendedStep: "future_step",
                    completionPercentage: 80,
                    isOnboardingComplete: false
                )
            ),
            sessionService: StubSessionService(
                hasAccessToken: true,
                hasRefreshToken: true,
                signupSessionID: nil
            ),
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )

        await store.refreshLaunchRoute()

        switch store.launchPhase {
        case .failed(let message):
            XCTAssertTrue(message.contains("future_step"))
        default:
            XCTFail("Expected a recoverable launch failure for an unknown onboarding step.")
        }
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.appSession"
        )
    }

    private func makeStore(
        router: AppRouter,
        authService: any AuthServiceProtocol,
        sessionService: any SessionServiceProtocol
    ) -> AppSessionStore {
        AppSessionStore(
            configuration: makeConfiguration(),
            uiTestConfiguration: .disabled,
            router: router,
            authService: authService,
            sessionService: sessionService,
            manualProfileService: StubManualProfileService(),
            resumeImportService: StubResumeImportService()
        )
    }
}

private extension UITestLaunchConfiguration {
    static let disabled = UITestLaunchConfiguration(
        isEnabled: false,
        route: .onboarding,
        onboardingStep: nil,
        disablesAnimations: false
    )
}

private actor StubSessionService: SessionServiceProtocol {
    let hasAccessToken: Bool
    let hasRefreshToken: Bool
    var signupSessionID: String?
    private(set) var didClearSession = false

    init(
        hasAccessToken: Bool,
        hasRefreshToken: Bool,
        signupSessionID: String?
    ) {
        self.hasAccessToken = hasAccessToken
        self.hasRefreshToken = hasRefreshToken
        self.signupSessionID = signupSessionID
    }

    func hasStoredAccessToken() async throws -> Bool { hasAccessToken }
    func hasStoredRefreshToken() async throws -> Bool { hasRefreshToken }
    func readSignupSessionID() async throws -> String? { signupSessionID }
    func storeSignupSessionID(_ signupSessionID: String) async throws { self.signupSessionID = signupSessionID }
    func clearSignupSessionID() async throws { signupSessionID = nil }
    func persistTokens(_ tokens: TokenResponseDTO) async throws { _ = tokens }
    func clearSession() async throws {
        signupSessionID = nil
        didClearSession = true
    }
    func logoutRemotely() async throws {}
    func prepareBootstrapSession() async throws -> Bool { hasAccessToken || hasRefreshToken }
    func sendAuthenticated(_ request: NetworkRequest) async throws -> Data {
        _ = request
        return Data()
    }
}

private final class StubAuthService: AuthServiceProtocol, @unchecked Sendable {
    let user: UserPublicDTO
    let onboardingStatus: OnboardingStatusResponseDTO
    let recoveryResponse: SignupSessionRecoveryResponseDTO
    let recoveryError: Error?
    private(set) var didLogout = false
    private(set) var recoveryCallCount = 0

    init(
        user: UserPublicDTO,
        onboardingStatus: OnboardingStatusResponseDTO,
        recoveryResponse: SignupSessionRecoveryResponseDTO = .fixture(),
        recoveryError: Error? = nil
    ) {
        self.user = user
        self.onboardingStatus = onboardingStatus
        self.recoveryResponse = recoveryResponse
        self.recoveryError = recoveryError
    }

    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO {
        _ = request
        return SignupStartResponseDTO(
            signupSessionId: "signup-session-123",
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            emailResendAfterSeconds: 30,
            phoneResendAfterSeconds: 30,
            expiresInSeconds: 900,
            message: "Signup session created"
        )
    }

    func recoverSignupSession() async throws -> SignupSessionRecoveryResponseDTO {
        recoveryCallCount += 1
        if let recoveryError {
            throw recoveryError
        }
        return recoveryResponse
    }

    func sendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return .fixture(channel: "email")
    }

    func resendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return .fixture(channel: "email")
    }

    func verifyEmail(email: String?, code: String) async throws { _ = (email, code) }

    func sendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return .fixture(channel: "phone")
    }

    func resendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return .fixture(channel: "phone")
    }

    func verifyPhone(mobileNumber: String?, code: String) async throws { _ = (mobileNumber, code) }

    func completeSignup() async throws -> TokenResponseDTO {
        TokenResponseDTO(
            accessToken: "access",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600
        )
    }

    func login(email: String, password: String) async throws -> TokenResponseDTO {
        _ = (email, password)
        return TokenResponseDTO(
            accessToken: "access",
            refreshToken: "refresh",
            tokenType: "Bearer",
            expiresIn: 3600
        )
    }

    func requestPasswordReset(email: String) async throws -> PasswordResetMessageDTO {
        _ = email
        return PasswordResetMessageDTO(
            message: "If an account exists for that email, a password reset email has been sent."
        )
    }

    func resetPassword(
        token: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> PasswordResetMessageDTO {
        _ = (token, newPassword, confirmPassword)
        return PasswordResetMessageDTO(message: "Password reset successful.")
    }

    func logout() async throws {
        didLogout = true
    }

    func currentUser() async throws -> UserPublicDTO {
        user
    }

    func onboardingStatus() async throws -> OnboardingStatusResponseDTO {
        onboardingStatus
    }
}

private extension SignupSessionRecoveryResponseDTO {
    static func fixture(
        state: SignupSessionRecoveryStateDTO = .valid,
        nextStep: SignupSessionNextStepDTO? = .verifyEmail
    ) -> SignupSessionRecoveryResponseDTO {
        SignupSessionRecoveryResponseDTO(
            state: state,
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            emailVerified: false,
            phoneVerified: false,
            nextStep: nextStep,
            expiresAt: Date(timeIntervalSince1970: 1_788_400_000),
            emailResendAvailableAt: nil,
            phoneResendAvailableAt: nil
        )
    }
}

private extension SignupChannelSendResponseDTO {
    static func fixture(channel: String) -> SignupChannelSendResponseDTO {
        SignupChannelSendResponseDTO(
            signupSessionID: "signup-session-123",
            channel: channel,
            verified: false,
            emailVerified: false,
            phoneVerified: false,
            resendAfterSeconds: 30,
            expiresInSeconds: 900,
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            message: "Verification code sent"
        )
    }
}

private actor StubManualProfileService: ManualProfileServiceProtocol {
    private let preparedDraftValue: ManualProfileFlowState
    private(set) var prepareDraftCallCount = 0

    init(preparedDraft: ManualProfileFlowState = ManualProfileFlowState()) {
        self.preparedDraftValue = preparedDraft
    }

    func prepareRemainingProfileDraft(signupDraftFullName: String?) async throws -> ManualProfileFlowState {
        _ = signupDraftFullName
        prepareDraftCallCount += 1
        return preparedDraftValue
    }

    func submit(draft: ManualProfileFlowState) async throws -> ManualProfileSubmissionResult {
        _ = draft
        fatalError("submit(draft:) should not be called in AppSessionStoreTests")
    }
}

private actor StubResumeImportService: ResumeImportServiceProtocol {
    let workflowSnapshot: ResumeImportWorkflowSnapshot?
    let recoveryState: ResumeImportRecoveryState?
    private(set) var restoreWorkflowCallCount = 0
    private(set) var reconcileCallCount = 0

    init(
        workflowSnapshot: ResumeImportWorkflowSnapshot? = nil,
        recoveryState: ResumeImportRecoveryState? = nil
    ) {
        self.workflowSnapshot = workflowSnapshot
        self.recoveryState = recoveryState
    }

    func prepareSelection(from pickedURL: URL) throws -> ResumeImportPreparedSelection {
        _ = pickedURL
        fatalError("prepareSelection(from:) should not be called in AppSessionStoreTests")
    }

    func cleanupSelection(at temporaryFileURL: URL) {
        _ = temporaryFileURL
    }

    func restoreLatestWorkflow() async throws -> ResumeImportWorkflowSnapshot? {
        restoreWorkflowCallCount += 1
        return workflowSnapshot
    }

    func upload(selection: ResumeImportPreparedSelection) async throws -> ResumeRecord {
        _ = selection
        fatalError("upload(selection:) should not be called in AppSessionStoreTests")
    }

    func startProcessing(resumeID: String) async throws -> ResumeProcessJob {
        _ = resumeID
        fatalError("startProcessing(resumeID:) should not be called in AppSessionStoreTests")
    }

    func processingStatus(resumeID: String) async throws -> ResumeProcessJob {
        _ = resumeID
        fatalError("processingStatus(resumeID:) should not be called in AppSessionStoreTests")
    }

    func loadOrCreateReviewSession(resumeID: String) async throws -> ResumeReviewSession {
        _ = resumeID
        fatalError("loadOrCreateReviewSession(resumeID:) should not be called in AppSessionStoreTests")
    }

    func refreshReviewSession(reviewID: String) async throws -> ResumeReviewSession {
        _ = reviewID
        fatalError("refreshReviewSession(reviewID:) should not be called in AppSessionStoreTests")
    }

    func updateReviewItem(
        reviewID: String,
        itemID: String,
        payload: ResumeReviewItemUpdateRequestDTO
    ) async throws -> ResumeReviewSession {
        _ = (reviewID, itemID, payload)
        fatalError("updateReviewItem(...) should not be called in AppSessionStoreTests")
    }

    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan {
        _ = (reviewID, expectedVersion)
        fatalError("validateReview(reviewID:expectedVersion:) should not be called in AppSessionStoreTests")
    }

    func importReview(
        reviewID: String,
        expectedVersion: Int,
        idempotencyKey: String
    ) async throws -> ResumeImportBatch {
        _ = (reviewID, expectedVersion, idempotencyKey)
        fatalError("importReview(...) should not be called in AppSessionStoreTests")
    }

    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch {
        _ = reviewID
        fatalError("latestImportStatus(reviewID:) should not be called in AppSessionStoreTests")
    }

    func reconcileImportRecovery(reviewID: String) async throws -> ResumeImportRecoveryState {
        _ = reviewID
        reconcileCallCount += 1
        guard let recoveryState else {
            fatalError("reconcileImportRecovery(reviewID:) was not stubbed")
        }
        return recoveryState
    }

    func completeOnboardingIfNeeded() async throws -> ResumeImportCompletionResult {
        fatalError("completeOnboardingIfNeeded() should not be called in AppSessionStoreTests")
    }
}

private extension UserPublicDTO {
    static let fixture = UserPublicDTO(
        id: "user_123",
        email: "aarav@example.com",
        fullName: "Aarav Mehta",
        profileSlug: "aarav-mehta",
        phone: "+919876543210",
        currentRole: "People Operations Lead",
        industry: "Technology",
        yearsOfExperience: 6,
        location: "Bengaluru, India",
        locationCity: "Bengaluru",
        locationRegion: "Karnataka",
        locationCountry: "India",
        headline: "People Operations Lead",
        bio: "Building verified professional trust.",
        dateOfBirth: nil,
        avatarURL: nil,
        role: "user",
        isActive: true,
        phoneVerifiedAt: Date(timeIntervalSince1970: 1_722_902_400),
        emailVerifiedAt: Date(timeIntervalSince1970: 1_722_902_400),
        employmentOnboardingCompletedAt: nil,
        languages: [],
        professionalLinks: [],
        profileCompletionPercentage: 75,
        createdAt: Date(timeIntervalSince1970: 1_722_816_000)
    )
}
