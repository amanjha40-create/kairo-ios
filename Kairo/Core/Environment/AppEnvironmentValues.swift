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

    func requestPasswordReset(email: String) async throws -> PasswordResetMessageDTO {
        _ = email
        fatalError("Missing auth service injection.")
    }

    func resetPassword(
        token: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> PasswordResetMessageDTO {
        _ = (token, newPassword, confirmPassword)
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

    func loadEmployment(id: String) async throws -> CareerEmploymentRecord {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func loadEducation(id: String) async throws -> CareerEducationRecord {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func loadCertification(id: String) async throws -> CareerCertificationRecord {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func loadProject(id: String) async throws -> CareerProjectRecord {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func createEmployment(_ request: CareerEmploymentCreateRequestDTO) async throws -> CareerOverview {
        _ = request
        fatalError("Missing career overview service injection.")
    }

    func updateEmployment(id: String, request: CareerEmploymentUpdateRequestDTO) async throws -> CareerOverview {
        _ = (id, request)
        fatalError("Missing career overview service injection.")
    }

    func deleteEmployment(id: String) async throws -> CareerOverview {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func createEducation(_ request: CareerEducationCreateRequestDTO) async throws -> CareerOverview {
        _ = request
        fatalError("Missing career overview service injection.")
    }

    func updateEducation(id: String, request: CareerEducationUpdateRequestDTO) async throws -> CareerOverview {
        _ = (id, request)
        fatalError("Missing career overview service injection.")
    }

    func deleteEducation(id: String) async throws -> CareerOverview {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func createCertification(_ request: CareerCertificationCreateRequestDTO) async throws -> CareerOverview {
        _ = request
        fatalError("Missing career overview service injection.")
    }

    func updateCertification(id: String, request: CareerCertificationUpdateRequestDTO) async throws -> CareerOverview {
        _ = (id, request)
        fatalError("Missing career overview service injection.")
    }

    func deleteCertification(id: String) async throws -> CareerOverview {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func createProject(_ request: CareerProjectCreateRequestDTO) async throws -> CareerOverview {
        _ = request
        fatalError("Missing career overview service injection.")
    }

    func updateProject(id: String, request: CareerProjectUpdateRequestDTO) async throws -> CareerOverview {
        _ = (id, request)
        fatalError("Missing career overview service injection.")
    }

    func deleteProject(id: String) async throws -> CareerOverview {
        _ = id
        fatalError("Missing career overview service injection.")
    }

    func createSkill(_ request: CareerSkillCreateRequestDTO) async throws -> CareerOverview {
        _ = request
        fatalError("Missing career overview service injection.")
    }

    func replaceSkill(id: String, with request: CareerSkillCreateRequestDTO) async throws -> CareerOverview {
        _ = (id, request)
        fatalError("Missing career overview service injection.")
    }

    func deleteSkill(id: String) async throws -> CareerOverview {
        _ = id
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

private struct MissingVerificationInitiationService: VerificationInitiationServiceProtocol {
    func loadEligibility() async throws -> VerificationInitiationEligibility {
        fatalError("Missing verification initiation service injection.")
    }

    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument] {
        _ = subject
        fatalError("Missing verification initiation service injection.")
    }

    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult {
        _ = draft
        fatalError("Missing verification initiation service injection.")
    }
}

private struct MissingPassportOverviewService: PassportOverviewServiceProtocol {
    func loadOverview() async throws -> PassportOverview {
        fatalError("Missing Passport overview service injection.")
    }
}

private struct MissingPassportShareService: PassportShareServiceProtocol {
    func listShares() async throws -> [PassportShare] {
        fatalError("Missing Passport share service injection.")
    }

    func getShare(id: String) async throws -> PassportShare {
        _ = id
        fatalError("Missing Passport share service injection.")
    }

    func getAnalytics(shareID: String) async throws -> PassportShareAnalytics {
        _ = shareID
        fatalError("Missing Passport share service injection.")
    }

    func createShare(_ input: PassportShareMutationInput) async throws -> PassportShareCreation {
        _ = input
        fatalError("Missing Passport share service injection.")
    }

    func updateShare(id: String, input: PassportShareMutationInput) async throws -> PassportShare {
        _ = (id, input)
        fatalError("Missing Passport share service injection.")
    }

    func revokeShare(id: String) async throws -> PassportShare {
        _ = id
        fatalError("Missing Passport share service injection.")
    }
}

private actor MissingPassportPDFExportService: PassportPDFExportServiceProtocol {
    func exportPassportPDF() async throws -> PassportPDFArtifact {
        fatalError("Missing Passport PDF export service injection.")
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        _ = artifact
        fatalError("Missing Passport PDF export service injection.")
    }

    func removeAllArtifacts() async {
        fatalError("Missing Passport PDF export service injection.")
    }
}

private struct MissingMoreOverviewService: MoreOverviewServiceProtocol {
    func loadOverview() async throws -> MoreOverview {
        fatalError("Missing More overview service injection.")
    }

    func updateProfile(_ draft: MoreProfileDraft) async throws -> MoreOverview {
        _ = draft
        fatalError("Missing More overview service injection.")
    }

    func changePassword(
        currentPassword: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> String {
        _ = (currentPassword, newPassword, confirmPassword)
        fatalError("Missing More overview service injection.")
    }

    func loadSessions() async throws -> [MoreSessionRecord] {
        fatalError("Missing More overview service injection.")
    }

    func revokeSession(id: String) async throws {
        _ = id
        fatalError("Missing More overview service injection.")
    }

    func updateNotificationPreference(
        id: String,
        enabled: Bool,
        existingPreferences: [MoreNotificationPreferenceItem]
    ) async throws -> MoreOverview {
        _ = (id, enabled, existingPreferences)
        fatalError("Missing More overview service injection.")
    }

    func withdrawTrustScoreConsent() async throws -> MoreOverview {
        fatalError("Missing More overview service injection.")
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

private struct VerificationInitiationServiceKey: EnvironmentKey {
    static let defaultValue: any VerificationInitiationServiceProtocol = MissingVerificationInitiationService()
}

private struct PassportOverviewServiceKey: EnvironmentKey {
    static let defaultValue: any PassportOverviewServiceProtocol = MissingPassportOverviewService()
}

private struct PassportShareServiceKey: EnvironmentKey {
    static let defaultValue: any PassportShareServiceProtocol = MissingPassportShareService()
}

private struct PassportPDFExportServiceKey: EnvironmentKey {
    static let defaultValue: any PassportPDFExportServiceProtocol = MissingPassportPDFExportService()
}

private struct MoreOverviewServiceKey: EnvironmentKey {
    static let defaultValue: any MoreOverviewServiceProtocol = MissingMoreOverviewService()
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

    var verificationInitiationService: any VerificationInitiationServiceProtocol {
        get { self[VerificationInitiationServiceKey.self] }
        set { self[VerificationInitiationServiceKey.self] = newValue }
    }

    var passportOverviewService: any PassportOverviewServiceProtocol {
        get { self[PassportOverviewServiceKey.self] }
        set { self[PassportOverviewServiceKey.self] = newValue }
    }

    var passportShareService: any PassportShareServiceProtocol {
        get { self[PassportShareServiceKey.self] }
        set { self[PassportShareServiceKey.self] = newValue }
    }

    var passportPDFExportService: any PassportPDFExportServiceProtocol {
        get { self[PassportPDFExportServiceKey.self] }
        set { self[PassportPDFExportServiceKey.self] = newValue }
    }

    var moreOverviewService: any MoreOverviewServiceProtocol {
        get { self[MoreOverviewServiceKey.self] }
        set { self[MoreOverviewServiceKey.self] = newValue }
    }
}
