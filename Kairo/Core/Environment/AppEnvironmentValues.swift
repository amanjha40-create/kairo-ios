import SwiftUI

private struct MissingNetworkClient: NetworkClient {
    func send(_ request: NetworkRequest) async throws -> Data {
        _ = request
        fatalError("Missing network client injection.")
    }
}

private struct MissingAuthService: AuthServiceProtocol {
    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO {
        _ = request
        fatalError("Missing auth service injection.")
    }

    func sendEmailCode(email: String?) async throws {
        _ = email
        fatalError("Missing auth service injection.")
    }

    func resendEmailCode(email: String?) async throws {
        _ = email
        fatalError("Missing auth service injection.")
    }

    func verifyEmail(email: String?, code: String) async throws {
        _ = (email, code)
        fatalError("Missing auth service injection.")
    }

    func sendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
        fatalError("Missing auth service injection.")
    }

    func resendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
        fatalError("Missing auth service injection.")
    }

    func verifyPhone(mobileNumber: String?, code: String) async throws {
        _ = (mobileNumber, code)
        fatalError("Missing auth service injection.")
    }

    func completeSignup() async throws -> TokenResponseDTO {
        fatalError("Missing auth service injection.")
    }

    func login(email: String, password: String) async throws -> TokenResponseDTO {
        _ = (email, password)
        fatalError("Missing auth service injection.")
    }

    func logout() async throws {
        fatalError("Missing auth service injection.")
    }

    func currentUser() async throws -> UserPublicDTO {
        fatalError("Missing auth service injection.")
    }

    func onboardingStatus() async throws -> OnboardingStatusResponseDTO {
        fatalError("Missing auth service injection.")
    }
}

private struct MissingHomeOverviewService: HomeOverviewServiceProtocol {
    func loadOverview() async throws -> DashboardOverview {
        fatalError("Missing home overview service injection.")
    }
}

private struct MissingCareerOverviewService: CareerOverviewServiceProtocol {
    func loadOverview() async throws -> CareerOverview {
        fatalError("Missing career overview service injection.")
    }
}

private struct MissingManualProfileService: ManualProfileServiceProtocol {
    func prepareRemainingProfileDraft(signupDraftFullName: String?) async throws -> ManualProfileFlowState {
        _ = signupDraftFullName
        fatalError("Missing manual profile service injection.")
    }

    func submit(
        draft: ManualProfileFlowState
    ) async throws -> ManualProfileSubmissionResult {
        _ = draft
        fatalError("Missing manual profile service injection.")
    }
}

private struct MissingResumeImportService: ResumeImportServiceProtocol {
    func prepareSelection(from pickedURL: URL) throws -> ResumeImportPreparedSelection {
        _ = pickedURL
        fatalError("Missing Resume Import service injection.")
    }

    func cleanupSelection(at temporaryFileURL: URL) {
        _ = temporaryFileURL
        fatalError("Missing Resume Import service injection.")
    }

    func restoreLatestWorkflow() async throws -> ResumeImportWorkflowSnapshot? {
        fatalError("Missing Resume Import service injection.")
    }

    func upload(selection: ResumeImportPreparedSelection) async throws -> ResumeRecord {
        _ = selection
        fatalError("Missing Resume Import service injection.")
    }

    func startProcessing(resumeID: String) async throws -> ResumeProcessJob {
        _ = resumeID
        fatalError("Missing Resume Import service injection.")
    }

    func processingStatus(resumeID: String) async throws -> ResumeProcessJob {
        _ = resumeID
        fatalError("Missing Resume Import service injection.")
    }

    func loadOrCreateReviewSession(resumeID: String) async throws -> ResumeReviewSession {
        _ = resumeID
        fatalError("Missing Resume Import service injection.")
    }

    func refreshReviewSession(reviewID: String) async throws -> ResumeReviewSession {
        _ = reviewID
        fatalError("Missing Resume Import service injection.")
    }

    func updateReviewItem(
        reviewID: String,
        itemID: String,
        payload: ResumeReviewItemUpdateRequestDTO
    ) async throws -> ResumeReviewSession {
        _ = (reviewID, itemID, payload)
        fatalError("Missing Resume Import service injection.")
    }

    func validateReview(reviewID: String, expectedVersion: Int) async throws -> ResumeReviewPlan {
        _ = (reviewID, expectedVersion)
        fatalError("Missing Resume Import service injection.")
    }

    func importReview(
        reviewID: String,
        expectedVersion: Int,
        idempotencyKey: String
    ) async throws -> ResumeImportBatch {
        _ = (reviewID, expectedVersion, idempotencyKey)
        fatalError("Missing Resume Import service injection.")
    }

    func latestImportStatus(reviewID: String) async throws -> ResumeImportBatch {
        _ = reviewID
        fatalError("Missing Resume Import service injection.")
    }

    func reconcileImportRecovery(reviewID: String) async throws -> ResumeImportRecoveryState {
        _ = reviewID
        fatalError("Missing Resume Import service injection.")
    }

    func completeOnboardingIfNeeded() async throws -> ResumeImportCompletionResult {
        fatalError("Missing Resume Import service injection.")
    }
}

private struct MissingVerifyOverviewService: VerifyOverviewServiceProtocol {
    func loadOverview() async throws -> VerifyOverview {
        fatalError("Missing Verify overview service injection.")
    }

    func performAction(
        requestID: String,
        action: VerifyRequestAction,
        response: String?
    ) async throws {
        _ = (requestID, action, response)
        fatalError("Missing Verify overview service injection.")
    }
}

private struct MissingPassportOverviewService: PassportOverviewServiceProtocol {
    func loadOverview() async throws -> PassportOverview {
        fatalError("Missing Passport overview service injection.")
    }
}

private actor MissingTokenStore: TokenStore {
    func save(_ token: String, for key: TokenKey) async throws {
        _ = (token, key)
        fatalError("Missing token store injection.")
    }

    func readToken(for key: TokenKey) async throws -> String? {
        _ = key
        fatalError("Missing token store injection.")
    }

    func deleteToken(for key: TokenKey) async throws {
        _ = key
        fatalError("Missing token store injection.")
    }
}

private struct AppConfigurationKey: EnvironmentKey {
    static let defaultValue = AppConfiguration(
        buildConfiguration: .development,
        environment: .development,
        isDemoModeEnabled: false,
        apiBaseURL: APIConfiguration.make(for: .development).baseURL,
        keychainService: "com.kairoid.Kairo.preview"
    )
}

private struct NetworkClientKey: EnvironmentKey {
    static let defaultValue: any NetworkClient = MissingNetworkClient()
}

private struct TokenStoreKey: EnvironmentKey {
    static let defaultValue: any TokenStore = MissingTokenStore()
}

private struct AuthServiceKey: EnvironmentKey {
    static let defaultValue: any AuthServiceProtocol = MissingAuthService()
}

private struct HomeOverviewServiceKey: EnvironmentKey {
    static let defaultValue: any HomeOverviewServiceProtocol = MissingHomeOverviewService()
}

private struct CareerOverviewServiceKey: EnvironmentKey {
    static let defaultValue: any CareerOverviewServiceProtocol = MissingCareerOverviewService()
}

private struct ManualProfileServiceKey: EnvironmentKey {
    static let defaultValue: any ManualProfileServiceProtocol = MissingManualProfileService()
}

private struct ResumeImportServiceKey: EnvironmentKey {
    static let defaultValue: any ResumeImportServiceProtocol = MissingResumeImportService()
}

private struct VerifyOverviewServiceKey: EnvironmentKey {
    static let defaultValue: any VerifyOverviewServiceProtocol = MissingVerifyOverviewService()
}

private struct PassportOverviewServiceKey: EnvironmentKey {
    static let defaultValue: any PassportOverviewServiceProtocol = MissingPassportOverviewService()
}

extension EnvironmentValues {
    var appConfiguration: AppConfiguration {
        get { self[AppConfigurationKey.self] }
        set { self[AppConfigurationKey.self] = newValue }
    }

    var networkClient: any NetworkClient {
        get { self[NetworkClientKey.self] }
        set { self[NetworkClientKey.self] = newValue }
    }

    var tokenStore: any TokenStore {
        get { self[TokenStoreKey.self] }
        set { self[TokenStoreKey.self] = newValue }
    }

    var authService: any AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    var homeOverviewService: any HomeOverviewServiceProtocol {
        get { self[HomeOverviewServiceKey.self] }
        set { self[HomeOverviewServiceKey.self] = newValue }
    }

    var careerOverviewService: any CareerOverviewServiceProtocol {
        get { self[CareerOverviewServiceKey.self] }
        set { self[CareerOverviewServiceKey.self] = newValue }
    }

    var manualProfileService: any ManualProfileServiceProtocol {
        get { self[ManualProfileServiceKey.self] }
        set { self[ManualProfileServiceKey.self] = newValue }
    }

    var resumeImportService: any ResumeImportServiceProtocol {
        get { self[ResumeImportServiceKey.self] }
        set { self[ResumeImportServiceKey.self] = newValue }
    }

    var verifyOverviewService: any VerifyOverviewServiceProtocol {
        get { self[VerifyOverviewServiceKey.self] }
        set { self[VerifyOverviewServiceKey.self] = newValue }
    }

    var passportOverviewService: any PassportOverviewServiceProtocol {
        get { self[PassportOverviewServiceKey.self] }
        set { self[PassportOverviewServiceKey.self] = newValue }
    }
}
