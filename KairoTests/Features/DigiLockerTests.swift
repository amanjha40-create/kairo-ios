import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DigiLockerTests: XCTestCase {
    func testVerificationSuccessNeedsReviewAndSafeFailureAlwaysFinishWithoutOAuth() async throws {
        for verified in [true, false] {
            let service = DigiLockerServiceStub(
                status: .init(connected: true, status: .active),
                trust: try decode(DigiLockerIdentityTrustDTO.self, verified ? String(decoding: Self.trustPayload, as: UTF8.self) : #"{"state":"unverified","sources":[]}"#),
                history: .init(items: [], identityVerified: verified))
            let store = DigiLockerStore(service: service)
            await store.refreshSummary()
            let success = await store.verify([.pan])
            XCTAssertTrue(success)
            XCTAssertFalse(store.isVerifying)
            XCTAssertEqual(store.history?.identityVerified, verified)
            XCTAssertEqual(store.identityIsVerified, verified)
            XCTAssertNil(store.actionErrorMessage)
            let before = store.history
            await service.failVerification()
            let failed = await store.verify([.pan])
            XCTAssertFalse(failed)
            XCTAssertFalse(store.isVerifying)
            XCTAssertEqual(store.history, before)
            XCTAssertNotNil(store.verificationErrorMessage)
            XCTAssertNil(store.actionErrorMessage, "Verify must not attach its error to Refresh or Connect")
            XCTAssertFalse(store.isConnecting)
            await store.refreshSummary()
            XCTAssertEqual(store.history, before)
            XCTAssertNotNil(store.verificationErrorMessage, "Refreshing saved results must not hide the failed Verify action")
            store.resetForIdentityChange()
            XCTAssertNil(store.verificationErrorMessage)
        }
    }

    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_statusMappingCoversEveryBackendStateAndRejectsContradiction() throws {
        for (raw, connected) in [
            ("active", true),
            ("disconnected", false),
            ("pending", false),
            ("reconnect_required", false)
        ] {
            let status = try decode(
                DigiLockerStatusDTO.self,
                #"{"connected":\#(connected),"status":"\#(raw)","connected_at":null,"consent_valid_until":null,"scopes":[]}"#
            )
            XCTAssertEqual(status.status.rawValue, raw)
            XCTAssertEqual(status.connected, connected)
        }

        XCTAssertThrowsError(try decode(
            DigiLockerStatusDTO.self,
            #"{"connected":true,"status":"disconnected","connected_at":null,"consent_valid_until":null,"scopes":[]}"#
        ))
    }

    func test_authorizationURLValidatorAllowsOnlyExactGovernmentEndpoint() throws {
        let valid = "https://digilocker.meripehchaan.gov.in/public/oauth2/2/authorize?client_id=safe"
        XCTAssertEqual(try DigiLockerAuthorizationURLValidator.validate(valid).absoluteString, valid)

        for invalid in [
            "http://digilocker.meripehchaan.gov.in/public/oauth2/2/authorize",
            "https://evil.invalid/public/oauth2/2/authorize",
            "https://digilocker.meripehchaan.gov.in.evil.invalid/public/oauth2/2/authorize",
            "https://user:password@digilocker.meripehchaan.gov.in/public/oauth2/2/authorize",
            "https://digilocker.meripehchaan.gov.in:443/public/oauth2/2/authorize",
            "https://digilocker.meripehchaan.gov.in/public/oauth2/2/token",
            "https://digilocker.meripehchaan.gov.in/public/oauth2/2/authorize#fragment"
        ] {
            XCTAssertThrowsError(try DigiLockerAuthorizationURLValidator.validate(invalid), invalid)
        }
    }

    func test_serviceUsesOnlyKairoBackendContractsAndSafeRequestBodies() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/integrations/digilocker/status"):
                return (try Self.response(for: request), Self.statusPayload)
            case ("POST", "/api/v1/integrations/digilocker/connect"):
                XCTAssertEqual(try requestBodyData(from: request), Data("{}".utf8))
                return (try Self.response(for: request), Self.connectPayload)
            case ("GET", "/api/v1/integrations/digilocker/documents/issued"):
                return (try Self.response(for: request), Self.issuedPayload)
            case ("GET", "/api/v1/integrations/digilocker/identity/verifications"):
                return (try Self.response(for: request), Self.historyPayload)
            case ("GET", "/api/v1/integrations/digilocker/identity/trust"):
                return (try Self.response(for: request), Self.trustPayload)
            case ("POST", "/api/v1/integrations/digilocker/identity/verify"):
                let body = try requestBodyData(from: request)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(json["document_types"] as? [String], ["PANCR"])
                XCTAssertEqual(json["consent"] as? Bool, true)
                XCTAssertEqual(json["consent_version"] as? String, "v1")
                XCTAssertNil(json["uri"])
                return (try Self.response(for: request), Self.historyPayload)
            default:
                XCTFail("Unexpected DigiLocker request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                return (try Self.response(for: request, statusCode: 404), Data())
            }
        }

        let status = try await service.status()
        let connection = try await service.connect()
        let issued = try await service.issuedDocuments()
        let history = try await service.verificationHistory()
        let trust = try await service.identityTrust()
        let verified = try await service.verify(documentTypes: [.pan])
        XCTAssertEqual(status.status, .active)
        XCTAssertEqual(connection.connectionState, .pending)
        XCTAssertEqual(issued.items.map(\.documentType), ["PANCR", "DRVLC"])
        XCTAssertTrue(history.identityVerified)
        XCTAssertEqual(trust.state, .verified)
        XCTAssertTrue(verified.identityVerified)

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 6)
        XCTAssertTrue(requests.allSatisfy { $0.url?.host == "staging-api.kairoid.com" })
    }

    func test_issuedInventoryDropsProviderMetadataAndIdentifiersAtDecodeBoundary() throws {
        let response = try APIJSONCoder.makeDecoder().decode(
            DigiLockerIssuedDocumentsDTO.self,
            from: Self.issuedPayload
        )
        let reflected = String(reflecting: response)

        XCTAssertEqual(response.items.map(\.documentType), ["PANCR", "DRVLC"])
        XCTAssertFalse(reflected.contains("ABCDE1234F"))
        XCTAssertFalse(reflected.contains("provider-private-uri"))
        XCTAssertFalse(reflected.contains("Private Source Name"))
        XCTAssertFalse(reflected.contains("opaque-reference"))
    }

    func test_historicalVerificationRemainsVisibleWhenDisconnected() async throws {
        let service = DigiLockerServiceStub(
            status: DigiLockerStatusDTO(connected: false, status: .disconnected),
            trust: try decode(DigiLockerIdentityTrustDTO.self, String(decoding: Self.trustPayload, as: UTF8.self)),
            history: try decode(DigiLockerVerificationHistoryDTO.self, String(decoding: Self.historyPayload, as: UTF8.self))
        )
        let store = DigiLockerStore(service: service)

        await store.refreshSummary()

        XCTAssertEqual(store.status?.status, .disconnected)
        XCTAssertTrue(store.identityIsVerified)
        XCTAssertTrue(store.identityVerifiedViaDigiLocker)
        XCTAssertEqual(store.history?.items.first?.documentType, "DRVLC")
    }

    func test_refreshAfterReturnReplacesPendingWithAuthoritativeActiveState() async throws {
        let service = DigiLockerServiceStub(
            status: DigiLockerStatusDTO(connected: false, status: .pending),
            trust: try decode(DigiLockerIdentityTrustDTO.self, String(decoding: Self.trustPayload, as: UTF8.self)),
            history: try decode(DigiLockerVerificationHistoryDTO.self, String(decoding: Self.historyPayload, as: UTF8.self))
        )
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        XCTAssertEqual(store.status?.status, .pending)

        await service.setStatus(DigiLockerStatusDTO(connected: true, status: .active))
        await store.refreshAll()

        XCTAssertEqual(store.status?.status, .active)
        let readCount = await service.statusReads()
        XCTAssertEqual(readCount, 2)
    }

    func test_safePresentationNeverExposesTechnicalSuccessReasonOrIdentityValues() {
        XCTAssertEqual(DigiLockerPresentation.resultTitle(.verifiedMatch, current: true), "Verified")
        XCTAssertEqual(DigiLockerPresentation.safeReason(.nameMismatch), "Name does not match your KairoID profile")
        XCTAssertFalse(DigiLockerPresentation.resultTitle(.verifiedMatch, current: true).contains("FIRST_LAST"))
    }

    func test_rejectedBrowserHandoffUsesSafeRetryableCopy() throws {
        let store = DigiLockerStore(service: DigiLockerServiceStub(
            status: DigiLockerStatusDTO(connected: false, status: .disconnected),
            trust: try decode(DigiLockerIdentityTrustDTO.self, #"{"state":"unverified","sources":[]}"#),
            history: try decode(DigiLockerVerificationHistoryDTO.self, #"{"items":[],"identity_verified":false}"#)
        ))

        store.markBrowserOpenFailed()

        XCTAssertEqual(
            store.actionErrorMessage,
            "We couldn't open the secure DigiLocker browser. Refresh the status before trying again."
        )
        XCTAssertFalse(store.actionErrorMessage?.lowercased().contains("token") == true)
    }

    func test_trustScoreDecodesBackendValueAndSingleIdentityProvenanceWithoutLocalMath() throws {
        let score = try decode(
            TrustScoreResponseDTO.self,
            """
            {"overall":81,"breakdown":{"identity":100,"employment":70,"education":60},
             "status":"calculated","positive_contributors":[],"negative_contributors":[],
             "critical_overrides":[],"score_version":"v1","verification_completeness_percentage":82,
             "identity_state":"verified","identity_sources":[
               {"source":"digilocker","document_type":"PANCR","current":true,"match_result":"VERIFIED_MATCH","reason":null},
               {"source":"digilocker","document_type":"DRVLC","current":true,"match_result":"VERIFIED_MATCH","reason":null}
             ]}
            """
        )
        XCTAssertEqual(score.overall, 81)
        XCTAssertEqual(score.breakdown?.identity, 100)
        XCTAssertEqual(score.identityState, .verified)
        XCTAssertEqual(score.identitySources.count, 2)
    }

    func testReadOnlyStatusUsesCanonicalSessionRefreshButConnectDoesNotRetry() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.path {
            case "/api/v1/auth/refresh":
                return (try Self.response(for: request), Data(#"{"access_token":"synthetic-new","refresh_token":"synthetic-refresh-new","token_type":"bearer","expires_in":3600}"#.utf8))
            case "/api/v1/integrations/digilocker/status":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer access-123" {
                    return (try Self.response(for: request, statusCode: 401), Data(#"{"error":{"code":"unauthorized","message":"Expired"}}"#.utf8))
                }
                return (try Self.response(for: request), Self.statusPayload)
            default:
                XCTFail("Unexpected route")
                return (try Self.response(for: request, statusCode: 404), Data())
            }
        }
        let result = try await service.status()
        XCTAssertTrue(result.connected)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.map { $0.url?.path }, ["/api/v1/integrations/digilocker/status", "/api/v1/auth/refresh", "/api/v1/integrations/digilocker/status"])

        await MockURLProtocolStorage.shared.reset()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/integrations/digilocker/connect")
            return (try Self.response(for: request, statusCode: 401), Data(#"{"error":{"code":"unauthorized","message":"Expired"}}"#.utf8))
        }
        do { _ = try await service.connect(); XCTFail("Expected rejection") } catch { }
        let mutationRequests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(mutationRequests.count, 1)
    }

    private func makeService() async throws -> DigiLockerService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        try await tokenStore.save("synthetic-refresh", for: .refreshToken)
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.digilocker"
        )
        return DigiLockerService(
            sessionService: SessionService(
                configuration: configuration,
                networkClient: URLSessionNetworkClient(
                    baseURL: configuration.apiBaseURL,
                    session: makeMockedURLSession()
                ),
                tokenStore: tokenStore
            )
        )
    }

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try APIJSONCoder.makeDecoder().decode(type, from: Data(json.utf8))
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int = 200) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: statusCode, httpVersion: nil, headerFields: ["Cache-Control": "no-store", "Content-Type": "application/json"]))
    }

    private nonisolated static let statusPayload = Data(#"{"connected":true,"status":"active","connected_at":"2026-09-25T10:00:00Z","consent_valid_until":null,"scopes":["files.issueddocs"]}"#.utf8)
    private nonisolated static let connectPayload = Data(#"{"authorization_url":"https://digilocker.meripehchaan.gov.in/public/oauth2/2/authorize?client_id=safe","expires_at":"2026-09-25T10:05:00Z","connection_state":"pending"}"#.utf8)
    private nonisolated static let trustPayload = Data(#"{"state":"verified","sources":[{"source":"digilocker","document_type":"DRVLC","current":true,"match_result":"VERIFIED_MATCH","reason":null}]}"#.utf8)
    private nonisolated static let historyPayload = Data(#"{"items":[{"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z"}],"identity_verified":true}"#.utf8)
    private nonisolated static let issuedPayload = Data(#"{"items":[{"doctype":"PANCR","supported":true,"name":"Private Source Name","description":"ABCDE1234F","uri":"provider-private-uri","reference":"opaque-reference"},{"doctype":"DRVLC","supported":true}],"count":2,"malformed_count":0}"#.utf8)
}

private actor DigiLockerServiceStub: DigiLockerServiceProtocol {
    private var verificationFails = false
    func failVerification() { verificationFails = true }
    private var currentStatus: DigiLockerStatusDTO
    private let trustValue: DigiLockerIdentityTrustDTO
    private let historyValue: DigiLockerVerificationHistoryDTO
    private var reads = 0

    init(status: DigiLockerStatusDTO, trust: DigiLockerIdentityTrustDTO, history: DigiLockerVerificationHistoryDTO) {
        currentStatus = status
        trustValue = trust
        historyValue = history
    }

    func status() async throws -> DigiLockerStatusDTO { reads += 1; return currentStatus }
    func connect() async throws -> DigiLockerConnectResponseDTO { throw DigiLockerServiceError.invalidResponse }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO { DigiLockerIssuedDocumentsDTO(items: []) }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO { historyValue }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO { trustValue }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        if verificationFails { throw URLError(.timedOut) }
        return historyValue
    }
    func setStatus(_ status: DigiLockerStatusDTO) { currentStatus = status }
    func statusReads() -> Int { reads }
}
