import Foundation

protocol AuthServiceProtocol: Sendable {
    func signupStart(_ request: RegisterRequestDTO) async throws -> SignupStartResponseDTO
    func recoverSignupSession() async throws -> SignupSessionRecoveryResponseDTO
    func sendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO
    func resendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO
    func verifyEmail(email: String?, code: String) async throws
    func sendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO
    func resendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO
    func verifyPhone(mobileNumber: String?, code: String) async throws
    func completeSignup() async throws -> TokenResponseDTO
    func login(email: String, password: String) async throws -> TokenResponseDTO
    func requestPasswordReset(email: String) async throws -> PasswordResetMessageDTO
    func resetPassword(token: String, newPassword: String, confirmPassword: String) async throws -> PasswordResetMessageDTO
    func googleAuthorizationURL() async throws -> URL
    func exchangeGoogleHandoff(code: String) async throws -> GoogleHandoffExchangeResponseDTO
    func startGooglePhoneVerification(phone: String) async throws -> SignupStartResponseDTO
    func logout() async throws
    func currentUser() async throws -> UserPublicDTO
    func onboardingStatus() async throws -> OnboardingStatusResponseDTO
    func addMissingAccountMobile(phone: String) async throws
    func requestAccountMobileVerification() async throws -> AccountMobileVerificationResponse
    func verifyAccountMobile(code: String) async throws -> AccountMobileVerificationResponse
}

extension AuthServiceProtocol {
    // Preview/test implementations must explicitly opt in; never fall back to signup.
    func addMissingAccountMobile(phone: String) async throws {
        throw NetworkError.unavailableInDemoMode
    }

    func requestAccountMobileVerification() async throws -> AccountMobileVerificationResponse {
        throw NetworkError.unavailableInDemoMode
    }

    func verifyAccountMobile(code: String) async throws -> AccountMobileVerificationResponse {
        throw NetworkError.unavailableInDemoMode
    }
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

    func recoverSignupSession() async throws -> SignupSessionRecoveryResponseDTO {
        let signupSessionID = try await requireSignupSessionID()

        do {
            let data = try await networkClient.send(
                NetworkRequest(
                    path: "/auth/signup/session",
                    headers: [
                        "Accept": "application/json",
                        "Cache-Control": "no-store",
                        "X-Signup-Session-ID": signupSessionID,
                        "X-Request-ID": UUID().uuidString,
                        "X-Correlation-ID": UUID().uuidString
                    ]
                )
            )
            return try APIJSONCoder.makeDecoder().decode(
                SignupSessionRecoveryResponseDTO.self,
                from: data
            )
        } catch {
            await invalidateRecoveredSignupSessionIfNeeded(for: error)
            throw error
        }
    }

    func sendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return try await performSignupChannelSendRequest(
            path: "/auth/signup/email/send",
            body: SendEmailCodeRequestDTO(signupSessionID: try await requireSignupSessionID())
        )
    }

    func resendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return try await performSignupChannelSendRequest(
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

    func sendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return try await performSignupChannelSendRequest(
            path: "/auth/signup/phone/send",
            body: SendPhoneCodeRequestDTO(signupSessionID: try await requireSignupSessionID())
        )
    }

    func resendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return try await performSignupChannelSendRequest(
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

    func requestPasswordReset(email: String) async throws -> PasswordResetMessageDTO {
        try await postJSON(
            path: "/auth/forgot-password",
            body: ForgotPasswordRequestDTO(
                email: CreateAccountValidation.normalizedEmail(email)
            )
        )
    }

    func resetPassword(
        token: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> PasswordResetMessageDTO {
        let response: PasswordResetMessageDTO = try await postJSON(
            path: "/auth/reset-password",
            body: ResetPasswordRequestDTO(
                token: token,
                newPassword: newPassword,
                confirmPassword: confirmPassword
            )
        )
        try await sessionService.clearSession()
        return response
    }

    func googleAuthorizationURL() async throws -> URL {
        let data = try await networkClient.send(
            NetworkRequest(
                path: "/auth/google/url",
                headers: [
                    "Accept": "application/json",
                    "Cache-Control": "no-store",
                    "X-Request-ID": UUID().uuidString,
                    "X-Correlation-ID": UUID().uuidString
                ]
            )
        )
        let response = try APIJSONCoder.makeDecoder().decode(
            GoogleAuthorizationURLResponseDTO.self,
            from: data
        )
        guard
            response.provider.lowercased() == "google",
            let url = URL(string: response.authURL),
            url.scheme?.lowercased() == "https",
            url.host?.lowercased() == "accounts.google.com"
        else {
            throw NetworkError.invalidResponse
        }
        return url
    }

    func exchangeGoogleHandoff(code: String) async throws -> GoogleHandoffExchangeResponseDTO {
        let response: GoogleHandoffExchangeResponseDTO = try await postJSON(
            path: "/auth/google/handoff/exchange",
            body: GoogleHandoffExchangeRequestDTO(code: code)
        )

        switch response.outcome {
        case .loginComplete:
            guard let tokens = response.tokens, response.signup == nil else {
                throw NetworkError.invalidResponse
            }
            try await sessionService.persistTokens(tokens)
            try await sessionService.clearSignupSessionID()
        case .phoneVerificationRequired:
            guard let signup = response.signup, response.tokens == nil else {
                throw NetworkError.invalidResponse
            }
            try await sessionService.clearSession()
            try await sessionService.storeSignupSessionID(signup.signupSessionId)
        case .accountLinkingRequired, .authFailed:
            guard response.tokens == nil, response.signup == nil else {
                throw NetworkError.invalidResponse
            }
            try await sessionService.clearSession()
        }

        return response
    }

    func startGooglePhoneVerification(phone: String) async throws -> SignupStartResponseDTO {
        guard let e164Phone = CreateAccountValidation.e164PhoneNumber(phone) else {
            throw NetworkError.invalidResponse
        }
        let response: SignupStartResponseDTO = try await postJSON(
            path: "/auth/signup/google/phone",
            body: GooglePhoneStartRequestDTO(
                signupSessionID: try await requireSignupSessionID(),
                phone: e164Phone
            )
        )
        try await sessionService.storeSignupSessionID(response.signupSessionId)
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

    func requestAccountMobileVerification() async throws -> AccountMobileVerificationResponse {
        try await accountMobileVerification(path: "request", body: EmptyMobileVerificationRequest())
    }

    func addMissingAccountMobile(phone: String) async throws {
        guard let normalized = AccountMobileProfileRequest.normalizedPhone(phone) else {
            throw AccountMobileVerificationError.invalidPhone
        }
        let status = try await onboardingStatus()
        guard status.emailVerified else { throw AccountMobileVerificationError.emailRequired }
        let user = try await currentUser()
        // A stale/missing local value must not replace a number already saved.
        guard user.phone?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false else { return }
        guard !status.phoneVerified else { throw NetworkError.invalidResponse }
        let data = try await sessionService.sendAuthenticated(NetworkRequest(
            path: "/users/me", method: .patch,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try APIJSONCoder.makeEncoder().encode(AccountMobileProfileRequest(phone: normalized)),
            allowsSessionRefreshOnUnauthorized: false
        ))
        let updated = try APIJSONCoder.makeDecoder().decode(UserPublicDTO.self, from: data)
        guard updated.id == user.id, updated.phone == normalized,
              updated.phoneVerifiedAt == nil else { throw NetworkError.invalidResponse }
        // No OTP or local verification change: the caller refreshes canonical
        // user/onboarding state before offering a separate Send Code.
    }

    func verifyAccountMobile(code: String) async throws -> AccountMobileVerificationResponse {
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw AccountMobileVerificationError.invalidCode
        }
        return try await accountMobileVerification(
            path: "verify", body: AccountMobileVerificationRequest(code: code)
        )
    }

    private func accountMobileVerification<Body: Encodable & Sendable>(
        path: String, body: Body
    ) async throws -> AccountMobileVerificationResponse {
        // Refresh only through a safe canonical read BEFORE the explicit OTP action.
        // A verification 401 can mean an invalid code, not an expired login.
        let status = try await onboardingStatus()
        guard status.emailVerified else { throw AccountMobileVerificationError.emailRequired }
        if status.phoneVerified {
            return .init(state: .verified, phoneVerified: true, resendAfterSeconds: 0, expiresInSeconds: 0)
        }
        let data = try await sessionService.sendAuthenticated(NetworkRequest(
            path: "/auth/mobile-verification/\(path)",
            method: .post,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try APIJSONCoder.makeEncoder().encode(body),
            allowsSessionRefreshOnUnauthorized: false
        ))
        let response = try APIJSONCoder.makeDecoder().decode(AccountMobileVerificationResponse.self, from: data)
        guard response.isConsistent else { throw NetworkError.invalidResponse }
        return response
    }

    private func postJSON<Response: Decodable, Body: Encodable & Sendable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let data = try await rawPost(path: path, body: body)
        return try APIJSONCoder.makeDecoder().decode(Response.self, from: data)
    }

    private func rawPost<Body: Encodable & Sendable>(path: String, body: Body) async throws -> Data {
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

    private func performSignupChannelSendRequest<Body: Encodable & Sendable>(
        path: String,
        body: Body
    ) async throws -> SignupChannelSendResponseDTO {
        do {
            let data = try await rawPost(path: path, body: body)
            return try APIJSONCoder.makeDecoder().decode(SignupChannelSendResponseDTO.self, from: data)
        } catch {
            await invalidateSignupSessionIfNeeded(for: error)
            throw error
        }
    }

    private func performSignupSessionRequest<Body: Encodable & Sendable>(
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

    private func invalidateRecoveredSignupSessionIfNeeded(for error: Error) async {
        guard
            let networkError = error as? NetworkError,
            case .api(let apiError) = networkError,
            [.unauthorized, .forbidden, .notFound, .validationError].contains(apiError.code)
        else {
            return
        }

        try? await sessionService.clearSignupSessionID()
    }

    private func signupSessionShouldBeCleared(for apiError: APIError) -> Bool {
        switch apiError.code {
        case .unauthorized, .forbidden, .notFound:
            true
        case .badRequest, .conflict, .validationError, .rateLimited, .internalError, .serviceUnavailable:
            false
        }
    }
}

#if !KAIRO_PRODUCTION || KAIRO_LOCAL_BATCH1_QA
// Mock credential producers must not be linked into ordinary Production artifacts.
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

    func recoverSignupSession() async throws -> SignupSessionRecoveryResponseDTO {
        SignupSessionRecoveryResponseDTO(
            state: .valid,
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            emailVerified: false,
            phoneVerified: false,
            nextStep: .verifyEmail,
            expiresAt: Date().addingTimeInterval(900),
            emailResendAvailableAt: nil,
            phoneResendAvailableAt: nil
        )
    }

    func sendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return signupChannelFixture(channel: "email")
    }

    func resendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return signupChannelFixture(channel: "email")
    }

    func verifyEmail(email: String?, code: String) async throws {
        _ = (email, code)
    }

    func sendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return signupChannelFixture(channel: "phone")
    }

    func resendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return signupChannelFixture(channel: "phone")
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
        try await sessionService.clearSession()
        return PasswordResetMessageDTO(message: "Password reset successful.")
    }

    func googleAuthorizationURL() async throws -> URL {
        throw NetworkError.unavailableInDemoMode
    }

    func exchangeGoogleHandoff(code: String) async throws -> GoogleHandoffExchangeResponseDTO {
        _ = code
        throw NetworkError.unavailableInDemoMode
    }

    func startGooglePhoneVerification(phone: String) async throws -> SignupStartResponseDTO {
        _ = phone
        throw NetworkError.unavailableInDemoMode
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

    private func signupChannelFixture(channel: String) -> SignupChannelSendResponseDTO {
        SignupChannelSendResponseDTO(
            signupSessionID: "demo-signup-session",
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

actor UITestAuthService: AuthServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let configuration: UITestAuthConfiguration
    private var accountMobileVerified = false
    private var accountMobileAdded: String?
    private let accountMobileScenario = ProcessInfo.processInfo.environment["KAIRO_UI_TEST_ACCOUNT_MOBILE_RECOVERY"]

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

    func recoverSignupSession() async throws -> SignupSessionRecoveryResponseDTO {
        SignupSessionRecoveryResponseDTO(
            state: .valid,
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            emailVerified: false,
            phoneVerified: false,
            nextStep: .verifyEmail,
            expiresAt: Date().addingTimeInterval(900),
            emailResendAvailableAt: nil,
            phoneResendAvailableAt: nil
        )
    }

    func sendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return signupChannelFixture(channel: "email")
    }

    func resendEmailCode(email: String?) async throws -> SignupChannelSendResponseDTO {
        _ = email
        return signupChannelFixture(channel: "email")
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

    func sendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return signupChannelFixture(channel: "phone")
    }

    func resendPhoneCode(mobileNumber: String?) async throws -> SignupChannelSendResponseDTO {
        _ = mobileNumber
        return signupChannelFixture(channel: "phone")
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

    func requestPasswordReset(email: String) async throws -> PasswordResetMessageDTO {
        _ = email

        switch configuration.passwordResetRequestResult {
        case .success:
            return PasswordResetMessageDTO(
                message: "If an account exists for that email, a password reset email has been sent."
            )
        case .rateLimited:
            throw NetworkError.api(APIError(
                statusCode: 429,
                code: .rateLimited,
                message: "Too many requests — please slow down.",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        case .serverError:
            throw NetworkError.api(APIError(
                statusCode: 503,
                code: .serviceUnavailable,
                message: "Service unavailable",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        }
    }

    func resetPassword(
        token: String,
        newPassword: String,
        confirmPassword: String
    ) async throws -> PasswordResetMessageDTO {
        _ = (token, newPassword, confirmPassword)

        switch configuration.passwordResetCompletionResult {
        case .success:
            try await sessionService.clearSession()
            return PasswordResetMessageDTO(message: "Password reset successful.")
        case .invalidToken:
            throw NetworkError.api(APIError(
                statusCode: 401,
                code: .unauthorized,
                message: "Invalid or expired password reset token",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        case .validationError:
            throw NetworkError.api(APIError(
                statusCode: 422,
                code: .validationError,
                message: "Request validation failed",
                fieldErrors: ["new_password": ["Password must be at least 12 characters"]],
                globalErrors: [],
                validationDetails: []
            ))
        case .serverError:
            throw NetworkError.api(APIError(
                statusCode: 500,
                code: .internalError,
                message: "Internal server error",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        }
    }

    func googleAuthorizationURL() async throws -> URL {
        URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
    }

    func exchangeGoogleHandoff(code: String) async throws -> GoogleHandoffExchangeResponseDTO {
        _ = code
        let tokens = TokenResponseDTO(
            accessToken: "ui-test-google-access-token",
            refreshToken: "ui-test-google-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600
        )
        try await sessionService.persistTokens(tokens)
        try await sessionService.clearSignupSessionID()
        return GoogleHandoffExchangeResponseDTO(
            outcome: .loginComplete,
            message: "Signed in successfully.",
            tokens: tokens,
            signup: nil
        )
    }

    func startGooglePhoneVerification(phone: String) async throws -> SignupStartResponseDTO {
        _ = phone
        return SignupStartResponseDTO(
            signupSessionId: "ui-test-google-signup-session",
            emailMasked: "aa***@example.com",
            phoneMasked: "+91******3210",
            emailVerified: true,
            phoneVerified: false,
            emailResendAfterSeconds: 0,
            phoneResendAfterSeconds: 0,
            expiresInSeconds: 900,
            message: "Phone number added"
        )
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
            phone: accountMobileAdded ?? (accountMobileScenario?.hasPrefix("missingPhone") == true ? nil : "+919876543210"),
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
            phoneVerifiedAt: accountMobileScenario == nil || accountMobileVerified
                ? Date(timeIntervalSince1970: 1_722_902_400) : nil,
            emailVerifiedAt: Date(timeIntervalSince1970: 1_722_902_400),
            employmentOnboardingCompletedAt: nil,
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 75,
            createdAt: Date(timeIntervalSince1970: 1_722_816_000)
        )
    }

    func onboardingStatus() async throws -> OnboardingStatusResponseDTO {
        if accountMobileScenario != nil {
            return .fixture(
                currentStep: accountMobileVerified ? .completeProfile : .verifyIdentity,
                emailVerified: true, phoneVerified: accountMobileVerified,
                completedSteps: accountMobileVerified ? ["verify_email", "verify_phone"] : ["verify_email"],
                missingRequirements: accountMobileVerified ? ["headline"] : ["verify_phone"]
            )
        }
        return configuration.onboardingStatus
    }

    func addMissingAccountMobile(phone: String) async throws {
        guard accountMobileScenario != nil else { throw NetworkError.unavailableInDemoMode }
        guard let normalized = AccountMobileProfileRequest.normalizedPhone(phone) else {
            throw AccountMobileVerificationError.invalidPhone
        }
        if accountMobileScenario == "missingPhoneConflict" {
            throw NetworkError.api(APIError(
                statusCode: 409, code: .conflict, message: "Synthetic conflict",
                fieldErrors: [:], globalErrors: [], validationDetails: []
            ))
        }
        if accountMobileScenario == "missingPhoneSaveFailure" {
            throw NetworkError.transport("synthetic failure")
        }
        accountMobileAdded = normalized
    }

    func requestAccountMobileVerification() async throws -> AccountMobileVerificationResponse {
        guard accountMobileScenario != nil else { throw NetworkError.unavailableInDemoMode }
        if accountMobileScenario == "deliveryFailure" { throw NetworkError.transport("synthetic failure") }
        if (accountMobileScenario == "phoneRequired" ||
            accountMobileScenario?.hasPrefix("missingPhone") == true), accountMobileAdded == nil {
            return .init(state: .phoneRequired, phoneVerified: false, resendAfterSeconds: 0, expiresInSeconds: 0)
        }
        return .init(state: .codeSent, phoneVerified: false, resendAfterSeconds: 30, expiresInSeconds: 300)
    }

    func verifyAccountMobile(code: String) async throws -> AccountMobileVerificationResponse {
        guard accountMobileScenario != nil else { throw NetworkError.unavailableInDemoMode }
        if accountMobileScenario == "invalidCode" || code != "123456" {
            throw NetworkError.api(APIError(
                statusCode: 401, code: .unauthorized, message: "Synthetic invalid code",
                fieldErrors: [:], globalErrors: [], validationDetails: []
            ))
        }
        accountMobileVerified = true
        return .init(state: .verified, phoneVerified: true, resendAfterSeconds: 0, expiresInSeconds: 0)
    }

    private func signupChannelFixture(channel: String) -> SignupChannelSendResponseDTO {
        SignupChannelSendResponseDTO(
            signupSessionID: "ui-test-signup-session",
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

#endif

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

    nonisolated enum PasswordResetRequestResult: String, Sendable {
        case success
        case rateLimited
        case serverError
    }

    nonisolated enum PasswordResetCompletionResult: String, Sendable {
        case success
        case invalidToken
        case validationError
        case serverError
    }

    static let loginResultKey = "KAIRO_UI_TEST_LOGIN_RESULT"
    static let signupStartResultKey = "KAIRO_UI_TEST_SIGNUP_START_RESULT"
    static let emailVerifyResultKey = "KAIRO_UI_TEST_EMAIL_VERIFY_RESULT"
    static let onboardingStatusKey = "KAIRO_UI_TEST_AUTH_ONBOARDING_STATUS"
    static let passwordResetRequestResultKey = "KAIRO_UI_TEST_PASSWORD_RESET_REQUEST_RESULT"
    static let passwordResetCompletionResultKey = "KAIRO_UI_TEST_PASSWORD_RESET_COMPLETION_RESULT"

    let loginResult: LoginResult
    let signupStartResult: SignupStartResult
    let emailVerifyResult: EmailVerifyResult
    let passwordResetRequestResult: PasswordResetRequestResult
    let passwordResetCompletionResult: PasswordResetCompletionResult
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
            passwordResetRequestResult: PasswordResetRequestResult(
                rawValue: environment[passwordResetRequestResultKey] ?? ""
            ) ?? .success,
            passwordResetCompletionResult: PasswordResetCompletionResult(
                rawValue: environment[passwordResetCompletionResultKey] ?? ""
            ) ?? .success,
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
