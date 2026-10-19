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
