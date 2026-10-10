import Foundation
import XCTest
@testable import Kairo

@MainActor
final class SessionServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_sendAuthenticatedAddsBearerAndRequestMetadata() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let service = makeSessionService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Request-ID"))
            XCTAssertNotNil(request.value(forHTTPHeaderField: "X-Correlation-ID"))

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )),
                Data(#"{"ok":true}"#.utf8)
            )
        }

        _ = try await service.sendAuthenticated(NetworkRequest(path: "/users/me"))
    }

    func test_prepareBootstrapSessionRefreshesWhenAccessTokenMissing() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("refresh-123", for: .refreshToken)

        let service = makeSessionService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/refresh")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["refresh_token"] as? String, "refresh-123")

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
                      "access_token": "new-access",
                      "refresh_token": "new-refresh",
                      "token_type": "bearer",
                      "expires_in": 3600
                    }
                    """.utf8
                )
            )
        }

        let didPrepareSession = try await service.prepareBootstrapSession()

        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)

        XCTAssertTrue(didPrepareSession)
        XCTAssertEqual(accessToken, "new-access")
        XCTAssertEqual(refreshToken, "new-refresh")
    }

    func test_logoutRemotelySendsRefreshTokenBody() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("refresh-123", for: .refreshToken)

        let service = makeSessionService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/auth/logout")
            let json = try Self.jsonBody(from: request)
            XCTAssertEqual(json["refresh_token"] as? String, "refresh-123")

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

        try await service.logoutRemotely()
    }

    func test_sendAuthenticatedRefreshesOnceAndReplaysOriginalRequest() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("expired-access", for: .accessToken)
        try await tokenStore.save("refresh-123", for: .refreshToken)

        let service = makeSessionService(tokenStore: tokenStore)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.path {
            case "/api/v1/users/me":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-access" {
                    return (
                        try XCTUnwrap(HTTPURLResponse(
                            url: try XCTUnwrap(request.url),
                            statusCode: 401,
                            httpVersion: nil,
                            headerFields: nil
                        )),
                        Data(#"{"error":{"code":"unauthorized","message":"Expired"}}"#.utf8)
                    )
                }

                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-access")
                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )),
                    Data(#"{"id":"user_123"}"#.utf8)
                )
            case "/api/v1/auth/refresh":
                let json = try Self.jsonBody(from: request)
                XCTAssertEqual(json["refresh_token"] as? String, "refresh-123")

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
                          "access_token": "refreshed-access",
                          "refresh_token": "refreshed-token",
                          "token_type": "bearer",
                          "expires_in": 3600
                        }
                        """.utf8
                    )
                )
            default:
                XCTFail("Unexpected request path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let data = try await service.sendAuthenticated(NetworkRequest(path: "/users/me"))
        let requests = await MockURLProtocolStorage.shared.requests()

        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)

        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"id":"user_123"}"#)
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/v1/users/me", "/api/v1/auth/refresh", "/api/v1/users/me"])
        XCTAssertEqual(accessToken, "refreshed-access")
        XCTAssertEqual(refreshToken, "refreshed-token")
    }

    func test_concurrentRequestsShareSingleRefresh() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("expired-access", for: .accessToken)
        try await tokenStore.save("refresh-123", for: .refreshToken)

        let service = makeSessionService(tokenStore: tokenStore)
        let refreshCounter = RefreshCounter()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.path {
            case "/api/v1/protected":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-access" {
                    return (
                        try XCTUnwrap(HTTPURLResponse(
                            url: try XCTUnwrap(request.url),
                            statusCode: 401,
                            httpVersion: nil,
                            headerFields: nil
                        )),
                        Data(#"{"error":{"code":"unauthorized","message":"Expired"}}"#.utf8)
                    )
                }

                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )),
                    Data(#"{"ok":true}"#.utf8)
                )
            case "/api/v1/auth/refresh":
                await refreshCounter.increment()
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
                          "access_token": "shared-access",
                          "refresh_token": "shared-refresh",
                          "token_type": "bearer",
                          "expires_in": 3600
                        }
                        """.utf8
                    )
                )
            default:
                XCTFail("Unexpected request path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        async let first = service.sendAuthenticated(NetworkRequest(path: "/protected"))
        async let second = service.sendAuthenticated(NetworkRequest(path: "/protected"))

        _ = try await (first, second)

        let refreshCount = await refreshCounter.currentValue()
        XCTAssertEqual(refreshCount, 1)
    }

    func test_accountAToLogoutToAccountBReplacesAllKeychainSessionMaterial() async throws {
        let tokenStore = InMemoryTokenStore()
        let service = makeSessionService(tokenStore: tokenStore)
        try await service.persistTokens(TokenResponseDTO(
            accessToken: "account-a-access",
            refreshToken: "account-a-refresh",
            tokenType: "bearer",
            expiresIn: 3600
        ))

        try await service.clearSession()

        let clearedAccessToken = try await tokenStore.readToken(for: .accessToken)
        let clearedRefreshToken = try await tokenStore.readToken(for: .refreshToken)
        let clearedSignupSessionID = try await tokenStore.readToken(for: .signupSessionID)
        XCTAssertNil(clearedAccessToken)
        XCTAssertNil(clearedRefreshToken)
        XCTAssertNil(clearedSignupSessionID)

        try await service.persistTokens(TokenResponseDTO(
            accessToken: "account-b-access",
            refreshToken: "account-b-refresh",
            tokenType: "bearer",
            expiresIn: 3600
        ))

        let accessToken = try await tokenStore.readToken(for: .accessToken)
        let refreshToken = try await tokenStore.readToken(for: .refreshToken)
        XCTAssertEqual(accessToken, "account-b-access")
        XCTAssertEqual(refreshToken, "account-b-refresh")
        XCTAssertNotEqual(accessToken, "account-a-access")
        XCTAssertNotEqual(refreshToken, "account-a-refresh")
    }

    func test_bootstrapRefreshPreservesCredentialsOnTransientFailuresAndCanRetry() async throws {
        try await assertRecoverableRefreshFailures(bootstrap: true)
    }

    func test_unauthorizedRequestRefreshPreservesCredentialsOnTransientFailuresAndCanRetry() async throws {
        try await assertRecoverableRefreshFailures(bootstrap: false)
    }

    func test_bootstrapRejectedRefreshClearsSession() async throws {
        try await assertRejectedRefresh(bootstrap: true)
    }

    func test_unauthorizedRequestRejectedRefreshClearsSession() async throws {
        try await assertRejectedRefresh(bootstrap: false)
    }

    func test_unauthorizedWithoutRefreshCredentialExpiresSessionWithoutRefreshRequest() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("expired-access", for: .accessToken)
        let service = makeSessionService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            try Self.sessionResponse(request, status: 401)
        }
        do {
            _ = try await service.sendAuthenticated(NetworkRequest(path: "/users/me"))
            XCTFail("Expected expiry when no refresh credential exists")
        } catch {
            XCTAssertEqual(error as? SessionServiceError, .sessionExpired)
        }
        let access = try await tokens.readToken(for: .accessToken)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertNil(access)
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/v1/users/me"])
    }

    func test_secondUnauthorizedAfterSuccessfulRefreshExpiresWithoutRefreshLoop() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("expired-access", for: .accessToken)
        try await tokens.save("refresh-123", for: .refreshToken)
        let service = makeSessionService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            try Self.sessionResponse(request, status: request.url?.path == "/api/v1/auth/refresh" ? 200 : 401)
        }
        do {
            _ = try await service.sendAuthenticated(NetworkRequest(path: "/users/me"))
            XCTFail("Expected expiry after the single replay is rejected")
        } catch {
            XCTAssertEqual(error as? SessionServiceError, .sessionExpired)
        }
        let access = try await tokens.readToken(for: .accessToken)
        let refresh = try await tokens.readToken(for: .refreshToken)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertNil(access)
        XCTAssertNil(refresh)
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/v1/users/me", "/api/v1/auth/refresh", "/api/v1/users/me"])
    }

    private func assertRecoverableRefreshFailures(bootstrap: Bool) async throws {
        // Negative values are transport errors; 200 is a malformed token response.
        for failure in [-1009, -1001, -999, 400, 403, 422, 429, 500, 502, 503, 200] {
            await MockURLProtocolStorage.shared.reset()
            let tokens = InMemoryTokenStore()
            if !bootstrap { try await tokens.save("expired-access", for: .accessToken) }
            try await tokens.save("refresh-123", for: .refreshToken)
            try await tokens.save("pending-signup", for: .signupSessionID)
            let service = makeSessionService(tokenStore: tokens)
            await MockURLProtocolStorage.shared.setHandler { request in
                if request.url?.path == "/api/v1/users/me" {
                    return try Self.sessionResponse(request, status: 401)
                }
                XCTAssertEqual(request.url?.path, "/api/v1/auth/refresh")
                if failure < 0 { throw URLError(URLError.Code(rawValue: failure)) }
                return try Self.sessionResponse(request, status: failure, malformed: failure == 200)
            }
            do {
                try await exerciseRefresh(service, bootstrap: bootstrap)
                XCTFail("Expected refresh failure: \(failure)")
            } catch {
                XCTAssertNil(error as? SessionServiceError, "Transient failure must not become sessionExpired: \(failure)")
            }
            let access = try await tokens.readToken(for: .accessToken)
            let refresh = try await tokens.readToken(for: .refreshToken)
            let signup = try await tokens.readToken(for: .signupSessionID)
            XCTAssertEqual(access, bootstrap ? nil : "expired-access", "Failure \(failure)")
            XCTAssertEqual(refresh, "refresh-123", "Failure \(failure)")
            XCTAssertEqual(signup, "pending-signup", "Failure \(failure)")
            let failedRequests = await MockURLProtocolStorage.shared.requests()
            XCTAssertEqual(failedRequests.map { $0.url?.path }, bootstrap
                ? ["/api/v1/auth/refresh"] : ["/api/v1/users/me", "/api/v1/auth/refresh"])

            // A later user retry can recover without another login.
            await MockURLProtocolStorage.shared.setHandler { request in
                let expired = request.url?.path == "/api/v1/users/me"
                    && request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-access"
                return try Self.sessionResponse(request, status: expired ? 401 : 200)
            }
            try await exerciseRefresh(service, bootstrap: bootstrap)
            let recoveredAccess = try await tokens.readToken(for: .accessToken)
            let recoveredRefresh = try await tokens.readToken(for: .refreshToken)
            XCTAssertEqual(recoveredAccess, "recovered-access")
            XCTAssertEqual(recoveredRefresh, "recovered-refresh")
        }
    }

    private func assertRejectedRefresh(bootstrap: Bool) async throws {
        let tokens = InMemoryTokenStore()
        if !bootstrap { try await tokens.save("expired-access", for: .accessToken) }
        try await tokens.save("rejected-refresh", for: .refreshToken)
        try await tokens.save("pending-signup", for: .signupSessionID)
        let service = makeSessionService(tokenStore: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            try Self.sessionResponse(request, status: 401)
        }
        do {
            try await exerciseRefresh(service, bootstrap: bootstrap)
            XCTFail("Expected expiry for backend-rejected refresh credential")
        } catch {
            XCTAssertEqual(error as? SessionServiceError, .sessionExpired)
        }
        for key in TokenKey.allCases {
            let value = try await tokens.readToken(for: key)
            XCTAssertNil(value)
        }
    }

    private func exerciseRefresh(_ service: SessionService, bootstrap: Bool) async throws {
        if bootstrap {
            let prepared = try await service.prepareBootstrapSession()
            XCTAssertTrue(prepared)
        } else {
            _ = try await service.sendAuthenticated(NetworkRequest(path: "/users/me"))
        }
    }

    private nonisolated static func sessionResponse(
        _ request: URLRequest, status: Int, malformed: Bool = false
    ) throws -> (HTTPURLResponse, Data) {
        let body = status == 200 && !malformed
            ? #"{"access_token":"recovered-access","refresh_token":"recovered-refresh","token_type":"bearer","expires_in":3600}"#
            : "{}"
        return (
            try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil)),
            Data(body.utf8)
        )
    }

    func test_physicalSessionFixtureRequiresExactStagingAndExplicitFlags() {
        for build in AppBuildConfiguration.allCases {
            for environment in AppEnvironment.allCases {
                let configuration = AppConfiguration(buildConfiguration: build, environment: environment,
                    isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: environment), keychainService: "unused")
                XCTAssertEqual(SessionRecoveryQA.isEnabled(configuration: configuration,
                    arguments: ["-KAIRO_UI_TESTING"], environment: ["KAIRO_UI_TEST_SESSION_RECOVERY": "1"]),
                    build == .staging && environment == .staging)
                XCTAssertFalse(SessionRecoveryQA.isEnabled(configuration: configuration,
                    arguments: [], environment: ["KAIRO_UI_TEST_SESSION_RECOVERY": "1"]))
                XCTAssertFalse(SessionRecoveryQA.isEnabled(configuration: configuration,
                    arguments: ["-KAIRO_UI_TESTING"], environment: [:]))
            }
        }
    }

    func test_physicalFixtureNetworkBlocksAllUnrecognizedReadsAndWrites() async {
        let network = SessionRecoveryQANetwork()
        for request in [NetworkRequest(path: "/dashboard"), NetworkRequest(path: "/auth/logout", method: .post),
                        NetworkRequest(path: "/users/me", method: .delete), NetworkRequest(path: "/auth/refresh")] {
            do {
                _ = try await network.send(request)
                XCTFail("Fixture must reject any non-allowlisted request")
            } catch {
                XCTAssertEqual(error as? NetworkError, .unavailableInDemoMode)
            }
        }
    }

    func test_physicalFixtureExercisesRealSessionRecoveryAndSignedOutRouting() async {
        let model = SessionRecoveryQAModel(configuration: makeConfiguration())
        await model.start()
        let identity = model.store.currentUser?.id
        XCTAssertNotNil(identity)
        XCTAssertTrue(model.credentialsPresent)
        await model.failTemporarily()
        XCTAssertTrue(model.credentialsPresent)
        XCTAssertTrue(model.retryAvailable)
        XCTAssertFalse(model.expired)
        XCTAssertEqual(model.store.currentUser?.id, identity)
        await model.retry()
        XCTAssertEqual(model.message, "Authenticated fixture data loaded")
        XCTAssertTrue(model.credentialsPresent)
        XCTAssertFalse(model.retryAvailable)
        await model.reject()
        XCTAssertTrue(model.expired)
        XCTAssertFalse(model.credentialsPresent)
        XCTAssertNil(model.store.currentUser)
        XCTAssertEqual(model.router.rootDestination, .onboarding)
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.session"
        )
    }

    private func makeNetworkClient() -> URLSessionNetworkClient {
        URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
    }

    private func makeSessionService(tokenStore: any TokenStore) -> SessionService {
        SessionService(
            configuration: makeConfiguration(),
            networkClient: makeNetworkClient(),
            tokenStore: tokenStore
        )
    }

    private nonisolated static func jsonBody(from request: URLRequest) throws -> [String: Any] {
        try requestJSONBody(from: request)
    }
}

private actor RefreshCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    func currentValue() -> Int {
        value
    }
}
