import XCTest
@testable import Kairo

@MainActor
final class DigiLockerReadQATests: XCTestCase {
    private var configuration: AppConfiguration {
        AppConfiguration.resolve(bundleValues: ["KAIROBuildConfiguration": "Staging"], environmentVariables: [:])
    }

    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func testGateRequiresExactStagingAndExplicitNonUITestOptIn() {
        let args = ["-KAIRO_DIGILOCKER_READ_QA"]
        let env = ["KAIRO_DIGILOCKER_READ_QA_MODE": "success"]
        XCTAssertEqual(DigiLockerReadQA.resolve(configuration: configuration, arguments: args, environment: env), .success)
        for name in ["Production", "Development", "Demo"] {
            let other = AppConfiguration.resolve(bundleValues: ["KAIROBuildConfiguration": name], environmentVariables: [:])
            XCTAssertNil(DigiLockerReadQA.resolve(configuration: other, arguments: args, environment: env))
        }
        XCTAssertNil(DigiLockerReadQA.resolve(configuration: configuration, arguments: [], environment: env))
        XCTAssertNil(DigiLockerReadQA.resolve(configuration: configuration, arguments: args + ["-KAIRO_UI_TESTING"], environment: env))
        XCTAssertNil(DigiLockerReadQA.resolve(configuration: configuration, arguments: args, environment: [:]))
        #if !KAIRO_DIGILOCKER_READ_QA
        XCTAssertNil(DigiLockerReadQA.current(configuration: configuration))
        #endif
    }

    func testCanonicalServiceSessionAndHTTPClientReadAfterCallbackWithoutReplacingHubOrTokens() async throws {
        let (store, _, tokens, evidence) = try await makeHarness()
        await store.refreshAll()
        let identity = store.identityRevision
        let before = await MockURLProtocolStorage.shared.requests().count
        await evidence.beginCallback(mode: .success)
        await store.finishAuthentication(.connected, revision: identity)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(before, 3)
        XCTAssertEqual(requests.count, 6)
        XCTAssertEqual(store.identityRevision, identity)
        XCTAssertFalse(store.summaryError)
        XCTAssertEqual(store.status?.connected, false)
        XCTAssertEqual(store.history?.items.count, 1)
        XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "GET" && $0.url?.host == "staging-api.kairoid.com" })
        let retained = try await tokens.readToken(for: .accessToken)
        XCTAssertTrue(retained == "synthetic-unit-access")
    }

    func testPostResponseFailurePreservesServerHistoryAndRetryRecovers() async throws {
        let (store, _, _, evidence) = try await makeHarness()
        await store.refreshAll()
        await evidence.beginCallback(mode: .refreshFailure)
        await store.finishAuthentication(.connected, revision: store.identityRevision)
        XCTAssertTrue(store.summaryError)
        XCTAssertEqual(store.status?.connected, false)
        XCTAssertEqual(store.history?.items.count, 1)
        await store.refreshAll()
        XCTAssertFalse(store.summaryError)
        XCTAssertEqual(store.status?.connected, false)
    }

    func testConnectVerifyInventoryAndAllNonAllowlistedRequestsBlockedBeforeHTTP() async throws {
        let (_, service, _, _) = try await makeHarness()
        do { _ = try await service.connect(); XCTFail("OAuth must be blocked") } catch {}
        do { _ = try await service.verify(documentTypes: [.pan]); XCTFail("Verify must be blocked") } catch {}
        do { _ = try await service.issuedDocuments(); XCTFail("Provider inventory must be blocked") } catch {}
        let count = await MockURLProtocolStorage.shared.requests().count
        XCTAssertEqual(count, 0)
    }

    func testUnauthorizedResponseDoesNotRefreshOrClearExistingCredentials() async throws {
        let (_, service, tokens, _) = try await makeHarness()
        await MockURLProtocolStorage.shared.setHandler { request in
            (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, Data())
        }
        do { _ = try await service.status(); XCTFail("Expired access must stop QA") } catch {}
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.httpMethod, "GET")
        let access = try await tokens.readToken(for: .accessToken)
        let refresh = try await tokens.readToken(for: .refreshToken)
        XCTAssertTrue(access == "synthetic-unit-access")
        XCTAssertTrue(refresh == "synthetic-unit-refresh")
        let protected = DigiLockerReadOnlyTokens(underlying: tokens)
        do { try await protected.deleteAllTokens(); XCTFail("Must not clear session") } catch {}
        do { try await protected.save("replacement", for: .accessToken); XCTFail("Must not replace session") } catch {}
    }

    private func makeHarness() async throws -> (DigiLockerStore, DigiLockerService, InMemoryTokenStore, DigiLockerReadQAEvidence) {
        let tokens = InMemoryTokenStore()
        try await tokens.save("synthetic-unit-access", for: .accessToken)
        try await tokens.save("synthetic-unit-refresh", for: .refreshToken)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let evidence = DigiLockerReadQAEvidence()
        let client = DigiLockerReadOnlyNetwork(underlying: URLSessionNetworkClient(baseURL: configuration.apiBaseURL, session: URLSession(configuration: config)), evidence: evidence)
        let session = SessionService(configuration: configuration, networkClient: client, tokenStore: DigiLockerReadOnlyTokens(underlying: tokens))
        let service = DigiLockerService(sessionService: session)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-unit-access")
            let payload: String
            switch request.url?.path {
            case "/api/v1/integrations/digilocker/status":
                payload = #"{"connected":false,"status":"reconnect_required"}"#
            case "/api/v1/integrations/digilocker/identity/trust":
                payload = #"{"state":"verified","sources":[]}"#
            case "/api/v1/integrations/digilocker/identity/verifications":
                payload = #"{"items":[{"document_type":"PANCR","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","integrity_result":"verified"}],"identity_verified":true}"#
            default: XCTFail("Unexpected request"); payload = "{}"
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, Data(payload.utf8))
        }
        return (DigiLockerStore(service: service), service, tokens, evidence)
    }
}
