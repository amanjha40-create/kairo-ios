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
        try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.httpBody)) as? [String: Any])
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
