import Foundation
import XCTest
@testable import Kairo

@MainActor
final class AuthServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_signupStartEncodesFrozenBackendRequestAndStoresSignupSessionID() async throws {
        let tokenStore = InMemoryTokenStore()
        let client = makeNetworkClient()
        let sessionService = makeSessionService(networkClient: client, tokenStore: tokenStore)
        let authService = AuthService(
            configuration: makeConfiguration(),
            networkClient: client,
            sessionService: sessionService
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/start")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try requestBodyData(from: request)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])

            XCTAssertEqual(json["full_name"] as? String, "Aman Jha")
            XCTAssertEqual(json["email"] as? String, "aman@example.com")
            XCTAssertEqual(json["phone"] as? String, "+919876543210")
            XCTAssertEqual(json["password"] as? String, "StrongPassword123!")
            XCTAssertNil(json["first_name"])
            XCTAssertNil(json["last_name"])
            XCTAssertNil(json["mobile_number"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(
                    """
                    {
                      "signup_session_id": "signup-session-123",
                      "email_masked": "am**@example.com",
                      "phone_masked": "+91******3210",
                      "email_verified": false,
                      "phone_verified": false,
                      "email_resend_after_seconds": 30,
                      "phone_resend_after_seconds": 30,
                      "expires_in_seconds": 900,
                      "message": "Signup session created"
                    }
                    """.utf8
                )
            )
        }

        let response = try await authService.signupStart(
            RegisterRequestDTO(
                fullName: "Aman Jha",
                email: "aman@example.com",
                phone: "+919876543210",
                password: "StrongPassword123!"
            )
        )

        XCTAssertEqual(response.signupSessionId, "signup-session-123")
        XCTAssertEqual(response.emailMasked, "am**@example.com")
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)
        XCTAssertEqual(signupSessionID, "signup-session-123")
    }

    func test_sendEmailCodeBodyContainsOnlySignupSessionID() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/email/send")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["signup_session_id"] as? String, "signup-session-123")
            XCTAssertEqual(Set(json.keys), ["signup_session_id"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Self.signupChannelSendPayload(channel: "email")
            )
        }

        _ = try await authService.sendEmailCode(email: "aman@example.com")
    }

    func test_resendEmailCodeUsesResendEndpointAndSignupSessionOnly() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/email/resend")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["signup_session_id"] as? String, "signup-session-123")
            XCTAssertEqual(Set(json.keys), ["signup_session_id"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Self.signupChannelSendPayload(channel: "email")
            )
        }

        _ = try await authService.resendEmailCode(email: "aman@example.com")
    }

    func test_verifyPhoneBodyContainsSignupSessionIDAndCodeOnly() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/phone/verify")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["signup_session_id"] as? String, "signup-session-123")
            XCTAssertEqual(json["code"] as? String, "123456")
            XCTAssertEqual(Set(json.keys), ["signup_session_id", "code"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Self.signupChannelSendPayload(channel: "phone")
            )
        }

        try await authService.verifyPhone(mobileNumber: "9876543210", code: "123456")
    }

    func test_resendPhoneCodeUsesResendEndpointAndSignupSessionOnly() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/phone/resend")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["signup_session_id"] as? String, "signup-session-123")
            XCTAssertEqual(Set(json.keys), ["signup_session_id"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Self.signupChannelSendPayload(channel: "phone")
            )
        }

        _ = try await authService.resendPhoneCode(mobileNumber: "9876543210")
    }

    func test_loginPersistsTokensAndClearsSignupSession() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("stale-signup", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/login")
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(
                    """
                    {
                      "access_token": "access-123",
                      "refresh_token": "refresh-456",
                      "token_type": "bearer",
                      "expires_in": 3600
                    }
                    """.utf8
                )
            )
        }

        _ = try await authService.login(email: "aman@example.com", password: "StrongPassword123!")

        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)

        XCTAssertEqual(accessToken, "access-123")
        XCTAssertEqual(refreshToken, "refresh-456")
        XCTAssertNil(signupSessionID)
    }

    func test_recoverSignupSessionUsesHeaderCredentialAndDecodesAuthoritativeState() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/session")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.url?.query)
            XCTAssertNil(request.httpBody)
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-Signup-Session-ID"),
                "signup-session-123"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Cache-Control": "private, no-store"]
                )),
                Data(
                    """
                    {
                      "state": "valid",
                      "email_masked": "a***@example.com",
                      "phone_masked": "+91******3210",
                      "email_verified": true,
                      "phone_verified": false,
                      "next_step": "verify_phone",
                      "expires_at": "2026-09-03T09:01:12Z",
                      "email_resend_available_at": null,
                      "phone_resend_available_at": "2026-09-02T09:02:00Z"
                    }
                    """.utf8
                )
            )
        }

        let recovery = try await authService.recoverSignupSession()

        XCTAssertEqual(recovery.state, .valid)
        XCTAssertEqual(recovery.emailMasked, "a***@example.com")
        XCTAssertEqual(recovery.phoneMasked, "+91******3210")
        XCTAssertTrue(recovery.emailVerified)
        XCTAssertFalse(recovery.phoneVerified)
        XCTAssertEqual(recovery.nextStep, .verifyPhone)
        XCTAssertNotNil(recovery.phoneResendAvailableAt)
        let persistedSignupSessionID = try await tokenStore.readToken(for: .signupSessionID)
        XCTAssertEqual(persistedSignupSessionID, "signup-session-123")
    }

    func test_unknownRecoveredSignupSessionClearsPersistedCredential() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 404,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(#"{"error":{"code":"not_found","message":"Signup session not found"}}"#.utf8)
            )
        }

        do {
            _ = try await authService.recoverSignupSession()
            XCTFail("Expected recovery to fail.")
        } catch {
            let persistedSignupSessionID = try await tokenStore.readToken(for: .signupSessionID)
            XCTAssertNil(persistedSignupSessionID)
        }
    }

    func test_requestPasswordResetUsesCanonicalGenericContract() async throws {
        let tokenStore = InMemoryTokenStore()
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/forgot-password")
            XCTAssertEqual(request.httpMethod, "POST")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["email"] as? String, "AMAN@EXAMPLE.COM")
            XCTAssertEqual(Set(json.keys), ["email"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 202,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(
                    #"{"message":"If an account exists for that email, a password reset email has been sent."}"#.utf8
                )
            )
        }

        let response = try await authService.requestPasswordReset(email: " AMAN@EXAMPLE.COM ")

        XCTAssertEqual(
            response.message,
            "If an account exists for that email, a password reset email has been sent."
        )
    }

    func test_resetPasswordUsesCanonicalSchemaAndDoesNotCreateSession() async throws {
        let tokenStore = InMemoryTokenStore()
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/reset-password")
            XCTAssertEqual(request.httpMethod, "POST")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["token"] as? String, "one-time-private-token")
            XCTAssertEqual(json["new_password"] as? String, "a-valid-password")
            XCTAssertEqual(json["confirm_password"] as? String, "a-valid-password")
            XCTAssertEqual(Set(json.keys), ["token", "new_password", "confirm_password"])

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(#"{"message":"Password reset successful."}"#.utf8)
            )
        }

        let response = try await authService.resetPassword(
            token: "one-time-private-token",
            newPassword: "a-valid-password",
            confirmPassword: "a-valid-password"
        )

        XCTAssertEqual(response.message, "Password reset successful.")
        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)
        XCTAssertNil(accessToken)
        XCTAssertNil(refreshToken)
        XCTAssertNil(signupSessionID)
    }

    func test_googleAuthorizationURLUsesBackendAuthoritativeHTTPSContract() async throws {
        let authService = makeAuthService(tokenStore: InMemoryTokenStore())

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/google/url")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Cache-Control": "private, no-store"]
                )),
                Data(
                    #"{"provider":"google","auth_url":"https://accounts.google.com/o/oauth2/v2/auth?client_id=public-client"}"#.utf8
                )
            )
        }

        let url = try await authService.googleAuthorizationURL()

        XCTAssertEqual(url.host, "accounts.google.com")
        XCTAssertEqual(url.scheme, "https")
    }

    func test_googleLoginHandoffExchangesOnlyOpaqueCodeAndPersistsReturnedTokens() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("stale-signup", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)
        let code = String(repeating: "G", count: 43)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/google/handoff/exchange")
            XCTAssertEqual(request.httpMethod, "POST")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["code"] as? String, code)
            XCTAssertEqual(Set(json.keys), ["code"])
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(
                    """
                    {
                      "outcome": "LOGIN_COMPLETE",
                      "message": "Signed in successfully.",
                      "tokens": {
                        "access_token": "google-access",
                        "refresh_token": "google-refresh",
                        "token_type": "bearer",
                        "expires_in": 3600
                      },
                      "signup": null
                    }
                    """.utf8
                )
            )
        }

        let response = try await authService.exchangeGoogleHandoff(code: code)
        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)

        XCTAssertEqual(response.outcome, .loginComplete)
        XCTAssertEqual(accessToken, "google-access")
        XCTAssertEqual(refreshToken, "google-refresh")
        XCTAssertNil(signupSessionID)
    }

    func test_productionParsedHandoffUsesMockedBackendExchangeNotLocalGoogleCredentials() async throws {
        let configuration = AppConfiguration(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production),
            keychainService: "synthetic.production.google.exchange")
        let tokens = InMemoryTokenStore()
        let client = URLSessionNetworkClient(baseURL: configuration.apiBaseURL, session: makeMockedURLSession())
        let session = SessionService(configuration: configuration, networkClient: client, tokenStore: tokens)
        let auth = AuthService(configuration: configuration, networkClient: client, sessionService: session)
        let opaque = String(repeating: "synthetic", count: 6)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "api.kairoid.com")
            XCTAssertEqual(request.url?.path, "/api/v1/auth/google/handoff/exchange")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try Self.jsonBody(from: request)
            XCTAssertEqual(Set(body.keys), ["code"])
            XCTAssertEqual(body["code"] as? String, opaque)
            return (try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200,
                httpVersion: nil, headerFields: nil)), Data(#"{"outcome":"LOGIN_COMPLETE","message":"Synthetic success","tokens":{"access_token":"synthetic-access","refresh_token":"synthetic-refresh","token_type":"bearer","expires_in":3600},"signup":null}"#.utf8))
        }
        let url = try XCTUnwrap(URL(string: "https://api.kairoid.com/auth/google/complete?code=\(opaque)"))
        guard case .googleHandoff(let code) = AppLinkParser.parse(url, configuration: configuration) else {
            return XCTFail("Expected canonical handoff")
        }
        let result = try await auth.exchangeGoogleHandoff(code: code)
        XCTAssertEqual(result.outcome, .loginComplete)
        let access = try await tokens.readToken(for: .accessToken)
        let refresh = try await tokens.readToken(for: .refreshToken)
        XCTAssertEqual(access, "synthetic-access")
        XCTAssertEqual(refresh, "synthetic-refresh")
    }

    func test_newGoogleIdentityRequiresPhoneAndCannotLeaveAuthenticatedTokens() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("stale-access", for: .accessToken)
        try await tokenStore.save("stale-refresh", for: .refreshToken)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/google/handoff/exchange")
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Self.googlePhoneRequiredPayload
            )
        }

        let response = try await authService.exchangeGoogleHandoff(code: String(repeating: "H", count: 43))
        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)

        XCTAssertEqual(response.outcome, .phoneVerificationRequired)
        XCTAssertEqual(response.signup?.emailVerified, true)
        XCTAssertNil(accessToken)
        XCTAssertNil(refreshToken)
        XCTAssertEqual(signupSessionID, "google-signup-session")
    }

    func test_googlePhoneCompletionUsesExistingSignupIdentityAndCanonicalPhone() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("google-signup-session", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/google/phone")
            XCTAssertEqual(request.httpMethod, "POST")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["signup_session_id"] as? String, "google-signup-session")
            XCTAssertEqual(json["phone"] as? String, "+919876543210")
            XCTAssertEqual(Set(json.keys), ["signup_session_id", "phone"])
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Self.googlePhoneSignupPayload
            )
        }

        let response = try await authService.startGooglePhoneVerification(phone: "9876543210")

        XCTAssertEqual(response.signupSessionId, "google-signup-session")
        XCTAssertEqual(response.phoneMasked, "+91******3210")
    }

    func test_sameEmailUnlinkedGoogleOutcomeFailsClosedWithoutCredentials() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("stale-access", for: .accessToken)
        try await tokenStore.save("stale-refresh", for: .refreshToken)
        try await tokenStore.save("stale-signup", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/google/handoff/exchange")
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(
                    #"{"outcome":"ACCOUNT_LINKING_REQUIRED","message":"Sign in with your password.","tokens":null,"signup":null}"#.utf8
                )
            )
        }

        let response = try await authService.exchangeGoogleHandoff(code: String(repeating: "J", count: 43))
        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)

        XCTAssertEqual(response.outcome, .accountLinkingRequired)
        XCTAssertNil(accessToken)
        XCTAssertNil(refreshToken)
        XCTAssertNil(signupSessionID)
    }

    func test_completeSignupPersistsTokensAndClearsSignupSession() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/complete")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["signup_session_id"] as? String, "signup-session-123")

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(
                    """
                    {
                      "access_token": "access-complete",
                      "refresh_token": "refresh-complete",
                      "token_type": "bearer",
                      "expires_in": 3600
                    }
                    """.utf8
                )
            )
        }

        _ = try await authService.completeSignup()

        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)

        XCTAssertEqual(accessToken, "access-complete")
        XCTAssertEqual(refreshToken, "refresh-complete")
        XCTAssertNil(signupSessionID)
    }

    func test_invalidSignupSessionClearsSignupSessionID() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/signup/email/send")
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 401,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(#"{"error":{"code":"unauthorized","message":"Signup session expired"}}"#.utf8)
            )
        }

        do {
            _ = try await authService.sendEmailCode(email: "aman@example.com")
            XCTFail("Expected the signup-session request to fail.")
        } catch {
            let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)
            XCTAssertNil(signupSessionID)
        }
    }

    func test_logoutClearsLocalSessionEvenIfRemoteLogoutFails() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        try await tokenStore.save("refresh-456", for: .refreshToken)
        try await tokenStore.save("signup-session-123", for: .signupSessionID)
        let authService = makeAuthService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/logout")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["refresh_token"] as? String, "refresh-456")
            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 503,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(#"{"error":{"code":"service_unavailable","message":"Unavailable"}}"#.utf8)
            )
        }

        try await authService.logout()

        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        let signupSessionID = try await tokenStore.readToken(for: .signupSessionID)

        XCTAssertNil(accessToken)
        XCTAssertNil(refreshToken)
        XCTAssertNil(signupSessionID)
    }

    func test_passwordResetLoginThenMobileRecoveryUsesAuthenticatedContractWithoutSignup() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("old-signup", for: .signupSessionID)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            let path = request.url!.path
            let payload: String
            switch path {
            case "/api/v1/auth/reset-password":
                payload = #"{"message":"Password reset"}"#
            case "/api/v1/auth/login":
                payload = #"{"access_token":"test-access","refresh_token":"test-refresh","token_type":"bearer","expires_in":3600}"#
            case "/api/v1/onboarding/status":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
                payload = Self.accountRecoveryStatus
            case "/api/v1/auth/mobile-verification/request":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
                XCTAssertEqual(try Self.jsonBody(from: request).count, 0)
                payload = #"{"state":"code_sent","phone_verified":false,"resend_after_seconds":30,"expires_in_seconds":300}"#
            case "/api/v1/auth/mobile-verification/verify":
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
                let body = try Self.jsonBody(from: request)
                XCTAssertEqual(Set(body.keys), ["code"])
                XCTAssertEqual(body["code"] as? String, "123456")
                payload = #"{"state":"verified","phone_verified":true,"resend_after_seconds":0,"expires_in_seconds":0}"#
            default:
                XCTFail("Unexpected route: \(path)")
                throw NetworkError.invalidURL
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        _ = try await auth.resetPassword(token: "synthetic-reset", newPassword: "SyntheticPassword123!", confirmPassword: "SyntheticPassword123!")
        _ = try await auth.login(email: "synthetic@example.com", password: "SyntheticPassword123!")
        let signup = try await tokens.readToken(for: .signupSessionID)
        XCTAssertNil(signup)
        let sent = try await auth.requestAccountMobileVerification()
        XCTAssertEqual(sent.state, .codeSent)
        let verified = try await auth.verifyAccountMobile(code: "123456")
        XCTAssertEqual(verified.state, .verified)
        let access = try await tokens.readToken(for: .accessToken)
        XCTAssertEqual(access, "test-access")
    }

    func test_mobileInvalidCodeDoesNotRefreshReplayOrClearSession() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        try await tokens.save("test-refresh", for: .refreshToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            let path = request.url!.path
            if path == "/api/v1/onboarding/status" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(Self.accountRecoveryStatus.utf8))
            }
            XCTAssertEqual(path, "/api/v1/auth/mobile-verification/verify")
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                    Data(#"{"error":{"code":"unauthorized","message":"Invalid or expired code"}}"#.utf8))
        }
        do {
            _ = try await auth.verifyAccountMobile(code: "123456")
            XCTFail("Invalid code must fail")
        } catch NetworkError.api(let error) {
            XCTAssertEqual(error.code, .unauthorized)
        } catch {
            XCTFail("Expected an invalid-code API error, not \(type(of: error))")
        }
        let access = try await tokens.readToken(for: .accessToken)
        let refresh = try await tokens.readToken(for: .refreshToken)
        XCTAssertEqual(access, "test-access")
        XCTAssertEqual(refresh, "test-refresh")
    }

    func test_mobileRecoveryRejectsInvalidCodeBeforeNetworking() async throws {
        let auth = makeAuthService(tokenStore: InMemoryTokenStore())
        await MockURLProtocolStorage.shared.setHandler { _ in
            XCTFail("Malformed code must not cause a request")
            throw NetworkError.invalidURL
        }
        for code in ["", "12345", "1234567", "１２３４５６", "12a456"] {
            do {
                _ = try await auth.verifyAccountMobile(code: code)
                XCTFail("Malformed code accepted")
            } catch AccountMobileVerificationError.invalidCode {} catch {
                XCTFail("Wrong error \(type(of: error))")
            }
        }
    }

    func test_mobileRecoveryHonorsVerifiedServerStateWithoutSendingOTP() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url!.path, "/api/v1/onboarding/status")
            let payload = Self.accountRecoveryStatus.replacingOccurrences(of: #""phone_verified":false"#, with: #""phone_verified":true"#)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        let result = try await auth.requestAccountMobileVerification()
        XCTAssertEqual(result.state, .verified)
    }

    func test_mobileRecoveryRequiresVerifiedEmailAndDoesNotFallBackToSignup() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url!.path, "/api/v1/onboarding/status")
            let payload = Self.accountRecoveryStatus.replacingOccurrences(of: #""email_verified":true"#, with: #""email_verified":false"#)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        do {
            _ = try await auth.requestAccountMobileVerification()
            XCTFail("Unverified email must fail closed")
        } catch AccountMobileVerificationError.emailRequired {} catch {
            XCTFail("Wrong error \(type(of: error))")
        }
    }

    func test_mobileRecoveryStateCooldownAndServerTruth() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            let path = request.url!.path
            let payload: String
            switch path {
            case "/api/v1/onboarding/status": payload = Self.accountRecoveryStatus
            case "/api/v1/auth/mobile-verification/request":
                payload = #"{"state":"code_sent","phone_verified":false,"resend_after_seconds":30,"expires_in_seconds":300}"#
            case "/api/v1/auth/mobile-verification/verify":
                payload = #"{"state":"verified","phone_verified":true,"resend_after_seconds":0,"expires_in_seconds":0}"#
            default: throw NetworkError.invalidURL
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        let state = AccountMobileVerificationState()
        XCTAssertFalse(state.hasSentCode)
        let sent = await state.send(using: auth)
        XCTAssertFalse(sent)
        XCTAssertTrue(state.hasSentCode)
        XCTAssertGreaterThan(state.cooldown(), 0)
        let resend = await state.send(using: auth)
        XCTAssertFalse(resend)
        state.code = "123456"
        XCTAssertTrue(state.canVerify)
        let needsRefresh = await state.verify(using: auth)
        XCTAssertTrue(needsRefresh)
        XCTAssertTrue(state.awaitingStatusRefresh)
        XCTAssertFalse(state.canVerify)
        XCTAssertEqual(state.code, "")
    }

    func test_mobileRecoveryMissingPhoneAndMalformedResponseFailClosed() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            let payload = request.url!.path == "/api/v1/onboarding/status"
                ? Self.accountRecoveryStatus
                : #"{"state":"phone_required","phone_verified":false,"resend_after_seconds":0,"expires_in_seconds":0}"#
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        let state = AccountMobileVerificationState()
        _ = await state.send(using: auth)
        XCTAssertTrue(state.phoneRequired)
        XCTAssertFalse(state.canVerify)
        XCTAssertFalse(AccountMobileVerificationResponse(state: .verified, phoneVerified: false, resendAfterSeconds: 0, expiresInSeconds: 0).isConsistent)
        XCTAssertFalse(AccountMobileVerificationResponse(state: .codeSent, phoneVerified: true, resendAfterSeconds: 30, expiresInSeconds: 300).isConsistent)
    }

    func test_missingMobileSavePatchesOnlyPhoneWithoutSendingCodeOrChangingSession() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        try await tokens.save("test-refresh", for: .refreshToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-access")
            let payload: String
            switch (request.url!.path, request.httpMethod!) {
            case ("/api/v1/onboarding/status", "GET"): payload = Self.accountRecoveryStatus
            case ("/api/v1/users/me", "GET"): payload = Self.recoveryUser(phone: nil)
            case ("/api/v1/users/me", "PATCH"):
                let body = try Self.jsonBody(from: request)
                XCTAssertEqual(Set(body.keys), ["phone"])
                XCTAssertEqual(body["phone"] as? String, "+919876543210")
                payload = Self.recoveryUser(phone: "+919876543210")
            default:
                XCTFail("Saving must not send OTP, create signup, or modify another route")
                throw NetworkError.invalidURL
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        let state = AccountMobileVerificationState()
        state.phone = "98765 43210"
        let saved = await state.savePhone(using: auth)
        XCTAssertTrue(saved)
        XCTAssertFalse(state.hasSentCode)
        XCTAssertFalse(state.awaitingStatusRefresh)
        XCTAssertFalse(state.canVerify)
        XCTAssertEqual(state.phone, "")
        let access = try await tokens.readToken(for: .accessToken)
        let refresh = try await tokens.readToken(for: .refreshToken)
        let signup = try await tokens.readToken(for: .signupSessionID)
        XCTAssertEqual(access, "test-access")
        XCTAssertEqual(refresh, "test-refresh")
        XCTAssertNil(signup)
    }

    func test_missingMobileRecoveryNeverOverwritesExistingServerPhone() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET", "Existing number must not be replaced")
            let payload = request.url!.path == "/api/v1/onboarding/status"
                ? Self.accountRecoveryStatus : Self.recoveryUser(phone: "+919000000001")
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        try await auth.addMissingAccountMobile(phone: "9876543210")
    }

    func test_missingMobileRejectsMalformedInputWithoutNetworkOrTruncation() async throws {
        let auth = makeAuthService(tokenStore: InMemoryTokenStore())
        await MockURLProtocolStorage.shared.setHandler { _ in
            XCTFail("Invalid input must never reach a request")
            throw NetworkError.invalidURL
        }
        for input in ["", "12345", "987654321012", "+91987654321012345", "9876543210abc", "９８７６５４３２１０", "++919876543210"] {
            do {
                try await auth.addMissingAccountMobile(phone: input)
                XCTFail("Invalid input accepted")
            } catch AccountMobileVerificationError.invalidPhone {} catch {
                XCTFail("Wrong error type")
            }
        }
        XCTAssertEqual(AccountMobileProfileRequest.normalizedPhone("+91 (98765) 43210"), "+919876543210")
        XCTAssertEqual(AccountMobileProfileRequest.normalizedPhone("+1 202-555-0123"), "+12025550123")
    }

    func test_missingMobileConflictIsSafeAndPreservesDraftAndSession() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            let isPatch = request.httpMethod == "PATCH"
            let payload = isPatch
                ? #"{"error":{"code":"conflict","message":"Private server detail must not be displayed"}}"#
                : (request.url!.path == "/api/v1/onboarding/status"
                   ? Self.accountRecoveryStatus : Self.recoveryUser(phone: nil))
            return (HTTPURLResponse(url: request.url!, statusCode: isPatch ? 409 : 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        let state = AccountMobileVerificationState()
        state.phone = "9876543210"
        let saved = await state.savePhone(using: auth)
        XCTAssertFalse(saved)
        XCTAssertEqual(state.phone, "9876543210")
        XCTAssertTrue(state.canSavePhone)
        XCTAssertFalse(state.hasSentCode)
        XCTAssertFalse(state.message?.contains("Private server detail") ?? true)
        let token = try await tokens.readToken(for: .accessToken)
        XCTAssertEqual(token, "test-access")
    }

    func test_missingMobileSaveFailureDoesNotAdvanceOrSendCode() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.httpMethod == "PATCH" { throw URLError(.notConnectedToInternet) }
            let payload = request.url!.path == "/api/v1/onboarding/status"
                ? Self.accountRecoveryStatus : Self.recoveryUser(phone: nil)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        let state = AccountMobileVerificationState()
        state.phone = "9876543210"
        let saved = await state.savePhone(using: auth)
        XCTAssertFalse(saved)
        XCTAssertFalse(state.hasSentCode)
        XCTAssertFalse(state.canVerify)
        XCTAssertTrue(state.canSavePhone)
        XCTAssertNotNil(state.message)
    }

    func test_missingMobileRequiresVerifiedEmailBeforeProfileWrite() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("test-access", for: .accessToken)
        let auth = makeAuthService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url!.path, "/api/v1/onboarding/status")
            XCTAssertEqual(request.httpMethod, "GET")
            let payload = Self.accountRecoveryStatus.replacingOccurrences(of: #""email_verified":true"#, with: #""email_verified":false"#)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(payload.utf8))
        }
        do {
            try await auth.addMissingAccountMobile(phone: "9876543210")
            XCTFail("Unverified email must fail closed")
        } catch AccountMobileVerificationError.emailRequired {} catch {
            XCTFail("Wrong error type")
        }
    }

    private nonisolated static func recoveryUser(phone: String?) -> String {
        let phoneJSON = phone.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"synthetic-user","email":"synthetic@example.com","full_name":"Synthetic",
        "phone":\(phoneJSON),"phone_verified_at":null,"email_verified_at":"2026-10-01T00:00:00Z",
        "role":"user","is_active":true,"created_at":"2026-10-01T00:00:00Z"}
        """
    }

    private nonisolated static let accountRecoveryStatus = """
    {"current_step":"verify_identity","email_verified":true,"phone_verified":false,
    "passport_ready":false,"completed_steps":["verify_email"],"missing_requirements":["verify_phone"],
    "next_recommended_step":"verify_identity","completion_percentage":25,"is_onboarding_complete":false}
    """

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.auth"
        )
    }

    private func makeNetworkClient() -> URLSessionNetworkClient {
        URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
    }

    private func makeSessionService(
        networkClient: any NetworkClient,
        tokenStore: any TokenStore
    ) -> SessionService {
        SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
    }

    private func makeAuthService(tokenStore: any TokenStore) -> AuthService {
        let client = makeNetworkClient()
        let sessionService = makeSessionService(networkClient: client, tokenStore: tokenStore)
        return AuthService(
            configuration: makeConfiguration(),
            networkClient: client,
            sessionService: sessionService
        )
    }

    private nonisolated static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        try requestJSONBody(from: request)
    }

    private nonisolated static func signupChannelSendPayload(channel: String) -> Data {
        Data(
            """
            {
              "signup_session_id": "signup-session-123",
              "channel": "\(channel)",
              "verified": false,
              "email_verified": false,
              "phone_verified": false,
              "resend_after_seconds": 41,
              "expires_in_seconds": 900,
              "email_masked": "a***@example.com",
              "phone_masked": "+91******3210",
              "message": "Verification code sent"
            }
            """.utf8
        )
    }

    private nonisolated static var googlePhoneRequiredPayload: Data {
        googlePhoneRequiredPayload(requiringMaskedPhone: false)
    }

    private nonisolated static func googlePhoneRequiredPayload(requiringMaskedPhone: Bool) -> Data {
        Data(
            """
            {
              "outcome": "PHONE_VERIFICATION_REQUIRED",
              "message": "Add and verify a mobile number.",
              "tokens": null,
              "signup": {
                "signup_session_id": "google-signup-session",
                "email_masked": "a***@example.com",
                "phone_masked": "\(requiringMaskedPhone ? "+91******3210" : "")",
                "email_verified": true,
                "phone_verified": false,
                "email_resend_after_seconds": 0,
                "phone_resend_after_seconds": 30,
                "expires_in_seconds": 900,
                "message": "Phone verification required"
              }
            }
            """.utf8
        )
    }

    private nonisolated static var googlePhoneSignupPayload: Data {
        Data(
            """
            {
              "signup_session_id": "google-signup-session",
              "email_masked": "a***@example.com",
              "phone_masked": "+91******3210",
              "email_verified": true,
              "phone_verified": false,
              "email_resend_after_seconds": 0,
              "phone_resend_after_seconds": 30,
              "expires_in_seconds": 900,
              "message": "Phone verification required"
            }
            """.utf8
        )
    }
}
