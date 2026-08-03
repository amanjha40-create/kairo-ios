import Foundation

protocol AuthServiceProtocol: Sendable {
    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO
    func sendEmailCode(email: String?) async throws
    func resendEmailCode(email: String?) async throws
    func verifyEmail(email: String?, code: String) async throws
    func sendPhoneCode(mobileNumber: String?) async throws
    func resendPhoneCode(mobileNumber: String?) async throws
    func verifyPhone(mobileNumber: String?, code: String) async throws
    func completeSignup() async throws -> TokenResponseDTO
    func login(email: String, password: String) async throws -> TokenResponseDTO
    func logout() async throws
    func currentUser() async throws -> UserPublicDTO
    func onboardingStatus() async throws -> OnboardingStatusResponseDTO
}

actor AuthService: AuthServiceProtocol {
    private let networkClient: any NetworkClient
    private let sessionService: any SessionServiceProtocol

    init(
        configuration: AppConfiguration,
        networkClient: any NetworkClient,
        sessionService: any SessionServiceProtocol
    ) {
        self.networkClient = networkClient
        self.sessionService = sessionService
        _ = configuration
    }

    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO {
        let response: SignupStartResponseDTO = try await postJSON(
            path: "/auth/signup/start",
            body: request
        )
        try await sessionService.storeSignupSessionID(response.signupSessionId)
        return response
    }

    func sendEmailCode(email: String?) async throws {
        _ = email
        try await performSignupSessionRequest(
            path: "/auth/signup/email/send",
            body: SendEmailCodeRequestDTO(signupSessionID: try await requireSignupSessionID())
        )
    }

    func resendEmailCode(email: String?) async throws {
        _ = email
        try await performSignupSessionRequest(
            path: "/auth/signup/email/resend",
            body: SendEmailCodeRequestDTO(signupSessionID: try await requireSignupSessionID())
        )
    }

    func verifyEmail(email: String?, code: String) async throws {
        _ = email
        try await performSignupSessionRequest(
            path: "/auth/signup/email/verify",
            body: VerifyEmailCodeRequestDTO(
                signupSessionID: try await requireSignupSessionID(),
                code: code
            )
        )
    }

    func sendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
        try await performSignupSessionRequest(
            path: "/auth/signup/phone/send",
            body: SendPhoneCodeRequestDTO(signupSessionID: try await requireSignupSessionID())
        )
    }

    func resendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
        try await performSignupSessionRequest(
            path: "/auth/signup/phone/resend",
            body: SendPhoneCodeRequestDTO(signupSessionID: try await requireSignupSessionID())
        )
    }

    func verifyPhone(mobileNumber: String?, code: String) async throws {
        _ = mobileNumber
        try await performSignupSessionRequest(
            path: "/auth/signup/phone/verify",
            body: VerifyPhoneCodeRequestDTO(
                signupSessionID: try await requireSignupSessionID(),
                code: code
            )
        )
    }

    func completeSignup() async throws -> TokenResponseDTO {
        do {
            let response: TokenResponseDTO = try await postJSON(
                path: "/auth/signup/complete",
                body: SignupCompleteRequestDTO(signupSessionID: try await requireSignupSessionID())
            )
            try await sessionService.persistTokens(response)
            try await sessionService.clearSignupSessionID()
            return response
        } catch {
            await invalidateSignupSessionIfNeeded(for: error)
            throw error
        }
    }

    func login(email: String, password: String) async throws -> TokenResponseDTO {
        let response: TokenResponseDTO = try await postJSON(
            path: "/auth/login",
            body: LoginRequestDTO(
                email: CreateAccountValidation.normalizedEmail(email),
                password: password
            )
        )
        try await sessionService.persistTokens(response)
        try await sessionService.clearSignupSessionID()
        return response
    }

    func logout() async throws {
        do {
            try await sessionService.logoutRemotely()
        } catch {
            // Local session cleanup still takes priority if the remote logout fails.
        }

        try await sessionService.clearSession()
    }

    func currentUser() async throws -> UserPublicDTO {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/users/me",
                headers: ["Accept": "application/json"]
            )
        )
        return try APIJSONCoder.makeDecoder().decode(UserPublicDTO.self, from: data)
    }

    func onboardingStatus() async throws -> OnboardingStatusResponseDTO {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/onboarding/status",
                headers: ["Accept": "application/json"]
            )
        )
        return try APIJSONCoder.makeDecoder().decode(OnboardingStatusResponseDTO.self, from: data)
    }

    private func postJSON<Response: Decodable, Body: Encodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let data = try await rawPost(path: path, body: body)
        return try APIJSONCoder.makeDecoder().decode(Response.self, from: data)
    }

    private func rawPost<Body: Encodable>(path: String, body: Body) async throws -> Data {
        try await networkClient.sendJSON(
            path: path,
            method: .post,
            body: body,
            headers: [
                "Accept": "application/json",
                "X-Request-ID": UUID().uuidString,
                "X-Correlation-ID": UUID().uuidString
            ]
        )
    }

    private func performSignupSessionRequest<Body: Encodable>(
        path: String,
        body: Body
    ) async throws {
        do {
            _ = try await rawPost(path: path, body: body)
        } catch {
            await invalidateSignupSessionIfNeeded(for: error)
            throw error
        }
    }

    private func requireSignupSessionID() async throws -> String {
        guard let signupSessionID = try await sessionService.readSignupSessionID() else {
            throw SessionServiceError.missingSignupSession
        }

        return signupSessionID
    }

    private func invalidateSignupSessionIfNeeded(for error: Error) async {
        guard
            let networkError = error as? NetworkError,
            case .api(let apiError) = networkError,
            signupSessionShouldBeCleared(for: apiError)
        else {
            return
        }

        try? await sessionService.clearSignupSessionID()
    }

    private func signupSessionShouldBeCleared(for apiError: APIError) -> Bool {
        switch apiError.code {
        case .unauthorized, .forbidden, .notFound:
            true
        case .conflict, .validationError, .rateLimited, .internalError, .serviceUnavailable:
            false
        }
    }
}

actor DemoAuthService: AuthServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private var currentOnboardingStatus = OnboardingStatusResponseDTO.fixture(
        currentStep: .complete,
        passportReady: true,
        completionPercentage: 100,
        isOnboardingComplete: true
    )

    init(sessionService: any SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO {
        let response = SignupStartResponseDTO(
            signupSessionId: "demo-signup-session",
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            emailResendAfterSeconds: 30,
            phoneResendAfterSeconds: 30,
            expiresInSeconds: 900,
            message: "Signup session created"
        )
        try await sessionService.storeSignupSessionID(response.signupSessionId)
        currentOnboardingStatus = .fixture(
            currentStep: .verifyIdentity,
            nextRecommendedStep: "verify_identity",
            completionPercentage: 25
        )
        _ = request
        return response
    }

    func sendEmailCode(email: String?) async throws {
        _ = email
    }

    func resendEmailCode(email: String?) async throws {
        _ = email
    }

    func verifyEmail(email: String?, code: String) async throws {
        _ = (email, code)
    }

    func sendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
    }

    func resendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
    }

    func verifyPhone(mobileNumber: String?, code: String) async throws {
        _ = (mobileNumber, code)
    }

    func completeSignup() async throws -> TokenResponseDTO {
        let tokens = TokenResponseDTO(
            accessToken: "demo-access-token",
            refreshToken: "demo-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600
        )
        try await sessionService.persistTokens(tokens)
        try await sessionService.clearSignupSessionID()
        currentOnboardingStatus = .fixture(
            currentStep: .completeProfile,
            completedSteps: ["verify_email", "verify_phone"],
            missingRequirements: ["headline"],
            nextRecommendedStep: "complete_profile",
            completionPercentage: 75
        )
        return tokens
    }

    func login(email: String, password: String) async throws -> TokenResponseDTO {
        let tokens = TokenResponseDTO(
            accessToken: "demo-access-token",
            refreshToken: "demo-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600
        )
        _ = (email, password)
        try await sessionService.persistTokens(tokens)
        currentOnboardingStatus = .fixture(
            currentStep: .complete,
            passportReady: true,
            completionPercentage: 100,
            isOnboardingComplete: true
        )
        return tokens
    }

    func logout() async throws {
        try await sessionService.clearSession()
        currentOnboardingStatus = .fixture(
            currentStep: .complete,
            passportReady: true,
            completionPercentage: 100,
            isOnboardingComplete: true
        )
    }

    func currentUser() async throws -> UserPublicDTO {
        UserPublicDTO(
            id: "demo-user",
            email: "aarav@example.com",
            fullName: "Aarav Mehta",
            profileSlug: "aarav-mehta",
            phone: "+919876543210",
            currentRole: "Candidate",
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

    func onboardingStatus() async throws -> OnboardingStatusResponseDTO {
        currentOnboardingStatus
    }
}

actor UITestAuthService: AuthServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let configuration: UITestAuthConfiguration

    init(
        sessionService: any SessionServiceProtocol,
        configuration: UITestAuthConfiguration = .current()
    ) {
        self.sessionService = sessionService
        self.configuration = configuration
    }

    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO {
        switch configuration.signupStartResult {
        case .success:
            let response = SignupStartResponseDTO(
                signupSessionId: "ui-test-signup-session",
                emailMasked: "aa***@example.com",
                phoneMasked: "+91******3210",
                emailResendAfterSeconds: 30,
                phoneResendAfterSeconds: 30,
                expiresInSeconds: 900,
                message: "Signup session created"
            )
            try await sessionService.storeSignupSessionID(response.signupSessionId)
            _ = request
            return response
        case .conflict:
            throw NetworkError.api(APIError(
                statusCode: 409,
                code: .conflict,
                message: "An account with this email already exists.",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        }
    }

    func sendEmailCode(email: String?) async throws {
        _ = email
    }

    func resendEmailCode(email: String?) async throws {
        _ = email
    }

    func verifyEmail(email: String?, code: String) async throws {
        _ = (email, code)
        if configuration.emailVerifyResult == .invalidCode {
            throw NetworkError.api(APIError(
                statusCode: 422,
                code: .validationError,
                message: "Enter a valid 6-digit code.",
                fieldErrors: ["code": ["Enter a valid 6-digit code."]],
                globalErrors: [],
                validationDetails: []
            ))
        }
    }

    func sendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
    }

    func resendPhoneCode(mobileNumber: String?) async throws {
        _ = mobileNumber
    }

    func verifyPhone(mobileNumber: String?, code: String) async throws {
        _ = (mobileNumber, code)
    }

    func completeSignup() async throws -> TokenResponseDTO {
        let tokens = TokenResponseDTO(
            accessToken: "ui-test-access-token",
            refreshToken: "ui-test-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600
        )
        try await sessionService.persistTokens(tokens)
        try await sessionService.clearSignupSessionID()
        return tokens
    }

    func login(email: String, password: String) async throws -> TokenResponseDTO {
        _ = (email, password)

        switch configuration.loginResult {
        case .success:
            let tokens = TokenResponseDTO(
                accessToken: "ui-test-access-token",
                refreshToken: "ui-test-refresh-token",
                tokenType: "Bearer",
                expiresIn: 3600
            )
            try await sessionService.persistTokens(tokens)
            try await sessionService.clearSignupSessionID()
            return tokens
        case .invalidCredentials:
            throw NetworkError.api(APIError(
                statusCode: 401,
                code: .unauthorized,
                message: "Invalid email or password.",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        }
    }

    func logout() async throws {
        try await sessionService.clearSession()
    }

    func currentUser() async throws -> UserPublicDTO {
        UserPublicDTO(
            id: "ui-test-user",
            email: "aarav@example.com",
            fullName: "Aarav Mehta",
            profileSlug: "aarav-mehta",
            phone: "+919876543210",
            currentRole: "Candidate",
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

    func onboardingStatus() async throws -> OnboardingStatusResponseDTO {
        configuration.onboardingStatus
    }
}

nonisolated struct UITestAuthConfiguration: Equatable, Sendable {
    nonisolated enum LoginResult: String, Sendable {
        case success
        case invalidCredentials
    }

    nonisolated enum SignupStartResult: String, Sendable {
        case success
        case conflict
    }

    nonisolated enum EmailVerifyResult: String, Sendable {
        case success
        case invalidCode
    }

    static let loginResultKey = "KAIRO_UI_TEST_LOGIN_RESULT"
    static let signupStartResultKey = "KAIRO_UI_TEST_SIGNUP_START_RESULT"
    static let emailVerifyResultKey = "KAIRO_UI_TEST_EMAIL_VERIFY_RESULT"
    static let onboardingStatusKey = "KAIRO_UI_TEST_AUTH_ONBOARDING_STATUS"

    let loginResult: LoginResult
    let signupStartResult: SignupStartResult
    let emailVerifyResult: EmailVerifyResult
    let onboardingStatus: OnboardingStatusResponseDTO

    nonisolated static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestAuthConfiguration {
        let resolvedStep = OnboardingStatusResponseDTO.CurrentStep(
            rawValue: environment[onboardingStatusKey] ?? ""
        ) ?? .completeProfile

        return UITestAuthConfiguration(
            loginResult: LoginResult(rawValue: environment[loginResultKey] ?? "") ?? .success,
            signupStartResult: SignupStartResult(rawValue: environment[signupStartResultKey] ?? "") ?? .success,
            emailVerifyResult: EmailVerifyResult(rawValue: environment[emailVerifyResultKey] ?? "") ?? .success,
            onboardingStatus: .fixture(
                currentStep: resolvedStep,
                completedSteps: resolvedStep == .verifyIdentity ? [] : ["verify_email", "verify_phone"],
                missingRequirements: resolvedStep == .completeProfile ? ["headline"] : [],
                nextRecommendedStep: resolvedStep == .completeProfile ? "complete_profile" : resolvedStep.rawValue,
                completionPercentage: resolvedStep == .complete ? 100 : (resolvedStep == .completeProfile ? 75 : 25),
                isOnboardingComplete: resolvedStep == .complete
            )
        )
    }
}
