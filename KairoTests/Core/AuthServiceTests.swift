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
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data()
            )
        }

        try await authService.sendEmailCode(email: "aman@example.com")
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
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data()
            )
        }

        try await authService.resendEmailCode(email: "aman@example.com")
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
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data()
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
                    statusCode: 204,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data()
            )
        }

        try await authService.resendPhoneCode(mobileNumber: "9876543210")
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
            try await authService.sendEmailCode(email: "aman@example.com")
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
}
