import XCTest
@testable import Kairo

@MainActor
final class AppSessionStoreTests: XCTestCase {
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
            sessionService: sessionService
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath, [])
    }

    func test_bootstrapRoutesToVerifyIdentityWhenSignupSessionExists() async {
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
                hasAccessToken: false,
                hasRefreshToken: false,
                signupSessionID: "signup-session-123"
            )
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.verifyIdentity))
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
            )
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
            )
        )

        await store.refreshLaunchRoute()

        XCTAssertEqual(router.rootDestination, .onboarding)
        XCTAssertEqual(router.onboardingPath.last, .step(.chooseStart))
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
            )
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
            )
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
            )
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
    func clearSession() async throws { signupSessionID = nil }
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
    private(set) var didLogout = false

    init(user: UserPublicDTO, onboardingStatus: OnboardingStatusResponseDTO) {
        self.user = user
        self.onboardingStatus = onboardingStatus
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

    func sendEmailCode(email: String?) async throws { _ = email }
    func resendEmailCode(email: String?) async throws { _ = email }
    func verifyEmail(email: String?, code: String) async throws { _ = (email, code) }
    func sendPhoneCode(mobileNumber: String?) async throws { _ = mobileNumber }
    func resendPhoneCode(mobileNumber: String?) async throws { _ = mobileNumber }
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
