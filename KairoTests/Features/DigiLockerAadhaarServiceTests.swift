import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DigiLockerAadhaarServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func testDedicatedWireContractsArePrivateAuthenticatedAndOneShot() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "digilocker-tests.invalid")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-access")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Pragma"), "no-cache")
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.timeoutInterval, 30)
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Referer"))
            XCTAssertNil(request.url?.query)
            switch (request.httpMethod, request.url?.path) {
            case ("GET", Self.root + "/eaadhaar/availability"):
                XCTAssertNil(request.httpBody)
                return (try Self.response(request), Data(#"{"available":true,"entitlement_confirmed":false}"#.utf8))
            case ("POST", Self.root + "/eaadhaar/verify"):
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(Set(body.keys), ["consent", "consent_version"])
                XCTAssertEqual(body["consent"] as? Bool, true)
                XCTAssertEqual(body["consent_version"] as? String, "v1")
                return (try Self.response(request), Self.verificationPayload)
            default:
                XCTFail("Unexpected backend route")
                return (try Self.response(request, status: 404), Data())
            }
        }
        let availability = try await service.aadhaarAvailability()
        XCTAssertTrue(availability.available)
        XCTAssertFalse(availability.entitlementConfirmed)
        let afterCheck = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(afterCheck.count, 1, "Availability must not trigger verification")
        let verification = try await service.verifyAadhaar()
        XCTAssertTrue(verification.isVerified)
        XCTAssertEqual(verification.documentType, "EAADHAAR")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 2)
    }

    func testEverySafeBackendErrorSurvivesRealSessionAndPrivateTransport() async throws {
        let cases: [(Int, String, DigiLockerAadhaarState)] = [
            (400, "digilocker_aadhaar_not_linked", .notLinked),
            (400, "digilocker_insufficient_scope", .accessUnavailable),
            (400, "digilocker_account_unavailable", .accessUnavailable),
            (400, "digilocker_invalid_token", .reconnectRequired),
            (400, "digilocker_reconnect_required", .reconnectRequired),
            (400, "digilocker_access_unavailable", .reconnectRequired),
            (503, "digilocker_integrity_failed", .integrityFailure),
            (404, "not_found", .unavailable),
            (403, "forbidden", .accessUnavailable),
            (401, "unauthorized", .reconnectRequired),
            (503, "digilocker_not_configured", .uncertain),
            (503, "PRIVATE_PROVIDER_ERROR", .uncertain),
            (429, "rate_limited", .uncertain)
        ]
        for (status, code, expected) in cases {
            for verify in [false, true] {
                await MockURLProtocolStorage.shared.reset()
                let service = try await makeService()
                await MockURLProtocolStorage.shared.setHandler { request in
                    XCTAssertEqual(request.url?.path, Self.root + (verify ? "/eaadhaar/verify" : "/eaadhaar/availability"))
                    let payload = Data("{\"error\":{\"code\":\"\(code)\",\"message\":\"PRIVATE_NAME HMAC XML 123412341234\",\"details\":[\"PRIVATE_ADDRESS\"]}}".utf8)
                    return (try Self.response(request, status: status), payload)
                }
                do {
                    if verify { _ = try await service.verifyAadhaar() }
                    else { _ = try await service.aadhaarAvailability() }
                    XCTFail("Expected safe failure")
                } catch {
                    XCTAssertEqual(error as? DigiLockerAadhaarState, expected)
                    XCTAssertEqual(DigiLockerAadhaarState.from(error: error), expected)
                    for secret in [code, "PRIVATE_NAME", "PRIVATE_ADDRESS", "HMAC", "XML", "123412341234"] {
                        XCTAssertFalse(error.localizedDescription.contains(secret))
                        XCTAssertFalse(String(reflecting: error).contains(secret))
                    }
                }
                let requests = await MockURLProtocolStorage.shared.requests()
                XCTAssertEqual(requests.count, 1, "No provider replay, token refresh, or reconnect")
            }
        }
    }

    func testProvider401DoesNotRefreshOrClearCandidateTokens() async throws {
        let tokens = InMemoryTokenStore()
        let service = try await makeService(tokens: tokens)
        await MockURLProtocolStorage.shared.setHandler { request in
            return (try Self.response(request, status: 401), Data(#"{"error":{"code":"digilocker_invalid_token"}}"#.utf8))
        }
        do { _ = try await service.verifyAadhaar(); XCTFail("Expected reconnect state") }
        catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .reconnectRequired) }
        let access = try await tokens.readToken(for: .accessToken)
        let refresh = try await tokens.readToken(for: .refreshToken)
        XCTAssertEqual(access, "synthetic-access")
        XCTAssertEqual(refresh, "synthetic-refresh")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testAvailabilityFalseIsNotLinkedAndDoesNotClaimEntitlement() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(request), Data(#"{"available":false,"entitlement_confirmed":false}"#.utf8))
        }
        let result = try await service.aadhaarAvailability()
        XCTAssertFalse(result.available)
        XCTAssertFalse(result.entitlementConfirmed)
        XCTAssertThrowsError(try decode(DigiLockerAadhaarAvailabilityDTO.self,
            #"{"available":true,"entitlement_confirmed":true}"#))
        XCTAssertThrowsError(try decode(DigiLockerAadhaarAvailabilityDTO.self, #"{"available":true}"#))
    }

    func testAadhaarDisabledDoesNotDisableIssuedPANDLVerification() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.path {
            case Self.root + "/eaadhaar/availability":
                return (try Self.response(request, status: 404), Data(#"{"error":{"code":"not_found"}}"#.utf8))
            case Self.root + "/documents/issued":
                return (try Self.response(request), Data(#"{"items":[{"doctype":"PANCR","supported":true},{"doctype":"DRVLC","supported":true}]}"#.utf8))
            case Self.root + "/identity/verify":
                let body = try requestJSONBody(from: request)
                XCTAssertEqual(body["document_types"] as? [String], ["PANCR", "DRVLC"])
                XCTAssertEqual(Set(body.keys), ["document_types", "consent", "consent_version"])
                return (try Self.response(request), Self.legacyHistoryPayload)
            default:
                XCTFail("Unexpected route")
                return (try Self.response(request, status: 404), Data())
            }
        }
        do { _ = try await service.aadhaarAvailability(); XCTFail("Expected gated route") }
        catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .unavailable) }
        let issued = try await service.issuedDocuments()
        XCTAssertEqual(issued.items.map(\.documentType), ["PANCR", "DRVLC"])
        let verified = try await service.verify(documentTypes: [.pan, .drivingLicence])
        XCTAssertTrue(try XCTUnwrap(verified.items.first).isVerified)
        XCTAssertEqual(DigiLockerDocumentType.allCases.map(\.rawValue), ["PANCR", "DRVLC"])
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 3)
    }

    func testBaseDisabledIsUncertainRatherThanAadhaarFeatureAvailability() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(request, status: 503), Data(#"{"error":{"code":"digilocker_not_configured","message":"PRIVATE_ENVIRONMENT"}}"#.utf8))
        }
        do { _ = try await service.aadhaarAvailability(); XCTFail("Expected disabled base") }
        catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .uncertain) }
        do { _ = try await service.issuedDocuments(); XCTFail("Expected disabled base") }
        catch {
            XCTAssertEqual((error as? DigiLockerBackendError)?.code, .notConfigured)
            XCTAssertFalse(error.localizedDescription.contains("PRIVATE_ENVIRONMENT"))
        }
    }

    func testSavedMetadataReadsAlsoUsePrivateTransport() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
            XCTAssertFalse(request.httpShouldHandleCookies)
            switch request.url?.path {
            case Self.root + "/identity/verifications":
                return (try Self.response(request), Self.legacyHistoryPayload)
            case Self.root + "/identity/trust":
                return (try Self.response(request), Data(#"{"state":"unverified","sources":[]}"#.utf8))
            case Self.root + "/documents/issued":
                return (try Self.response(request), Data(#"{"items":[]}"#.utf8))
            default:
                XCTFail("Unexpected route")
                return (try Self.response(request, status: 404), Data())
            }
        }
        _ = try await service.verificationHistory()
        _ = try await service.identityTrust()
        _ = try await service.issuedDocuments()
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 3)
    }

    func testDedicatedResponseRejectsWrongProvenanceAndIntegrity() async throws {
        let variants: [(String, String, DigiLockerAadhaarState)] = [
            ("\"source_type\":\"eaadhaar\"", "\"source_type\":\"issued\"", .uncertain),
            ("\"source\":\"digilocker\"", "\"source\":\"kairo\"", .uncertain),
            ("\"document_type\":\"EAADHAAR\"", "\"document_type\":\"PANCR\"", .uncertain),
            ("\"integrity_result\":\"verified\"", "\"integrity_result\":\"failed\"", .integrityFailure),
            ("2026-01-01T10:00:00Z", "PRIVATE_INVALID_DATE", .uncertain)
        ]
        for (original, replacement, expected) in variants {
            let payload = Data(String(decoding: Self.verificationPayload, as: UTF8.self)
                .replacingOccurrences(of: original, with: replacement).utf8)
            let service = try await makeService()
            await MockURLProtocolStorage.shared.setHandler { request in (try Self.response(request), payload) }
            do { _ = try await service.verifyAadhaar(); XCTFail("Expected safe rejection") }
            catch { XCTAssertEqual(error as? DigiLockerAadhaarState, expected) }
        }
    }

    func testOnlyStrictCurrentAadhaarMatchIsVerifiedAndLegacyNilDatesStillWork() throws {
        let valid = try APIJSONCoder.makeDecoder().decode(DigiLockerVerificationDTO.self, from: Self.verificationPayload)
        XCTAssertTrue(valid.isVerified)
        for result in [DigiLockerMatchResult.partialMatch, .mismatch, .unableToVerify] {
            XCTAssertFalse(verification(match: result).isVerified)
        }
        XCTAssertFalse(verification(current: false).isVerified)
        XCTAssertFalse(verification(integrity: "failed").isVerified)
        XCTAssertFalse(verification(date: nil).isVerified)
        XCTAssertFalse(verification(date: Date(timeIntervalSince1970: 0)).isVerified)
        XCTAssertFalse(verification(date: Date().addingTimeInterval(86_400)).isVerified)
        for type in ["PANCR", "DRVLC"] {
            XCTAssertTrue(verification(type: type, date: nil).isVerified)
        }
        XCTAssertEqual(DigiLockerPresentation.documentTitle("EAADHAAR"), "e-Aadhaar")
    }

    func testUnknownTypesAndIntegrityAreNormalizedWithoutRetainingPrivateStrings() throws {
        let unknown = try decode(DigiLockerIssuedDocumentsDTO.self,
            #"{"items":[{"doctype":"PRIVATE_NUMBER_123412341234","supported":true}]}"#)
        XCTAssertEqual(unknown.items.first?.documentType, "unknown")
        XCTAssertEqual(unknown.items.first?.supported, false)
        let raw = String(decoding: Self.verificationPayload, as: UTF8.self)
            .replacingOccurrences(of: "EAADHAAR", with: "PRIVATE_NUMBER_123412341234")
            .replacingOccurrences(of: "\"integrity_result\":\"verified\"", with: "\"integrity_result\":\"PRIVATE_XML\"")
        let result = try decode(DigiLockerVerificationDTO.self, raw)
        XCTAssertEqual(result.documentType, "unknown")
        XCTAssertEqual(result.integrityResult, "unknown")
        XCTAssertFalse(String(reflecting: result).contains("PRIVATE_"))
        let trust = try decode(DigiLockerTrustSourceDTO.self,
            #"{"source":"digilocker","document_type":"PRIVATE_NUMBER_123412341234","current":false,"match_result":"MISMATCH","reason":null}"#)
        XCTAssertEqual(trust.documentType, "unknown")
        XCTAssertFalse(String(reflecting: trust).contains("PRIVATE_"))
        for type in ["PANCR", "DRVLC", "EAADHAAR", "DGCER", "HSCER", "SSCER", "HSMRK", "SSMRK", "identity"] {
            let json = String(decoding: Self.verificationPayload, as: UTF8.self).replacingOccurrences(of: "EAADHAAR", with: type)
            XCTAssertEqual(try decode(DigiLockerVerificationDTO.self, json).documentType, type)
        }
    }

    func testDTOsDiscardAllIdentifierAndProviderFieldsBeforeObservableState() throws {
        let extras = #", "aadhaar_number":"PRIVATE_NUMBER", "masked_aadhaar":"PRIVATE_MASK", "name":"PRIVATE_NAME", "address":"PRIVATE_ADDRESS", "dob":"PRIVATE_DOB", "photo":"PRIVATE_PHOTO", "xml":"PRIVATE_XML", "provider_reference":"PRIVATE_REFERENCE", "id":"PRIVATE_ID", "document_number":"PRIVATE_DOCUMENT_NUMBER", "extracted_payload":{"secret":"PRIVATE_PAYLOAD"}, "reviewer_note":"PRIVATE_NOTE", "original_filename":"PRIVATE_FILENAME"}"#
        let verificationJSON = String(String(decoding: Self.verificationPayload, as: UTF8.self).dropLast()) + extras
        let result = try decode(DigiLockerAadhaarVerificationResponseDTO.self, verificationJSON).verification
        XCTAssertTrue(result.isVerified)
        XCTAssertFalse(String(reflecting: result).contains("PRIVATE_"))
        let availability = try decode(DigiLockerAadhaarAvailabilityDTO.self,
            #"{"available":true,"entitlement_confirmed":false"# + extras)
        XCTAssertFalse(String(reflecting: availability).contains("PRIVATE_"))
        let fields = Set(Mirror(reflecting: result).children.compactMap(\.label))
        XCTAssertEqual(fields, ["documentType", "source", "current", "matchResult", "matchReason", "integrityResult", "verifiedAt"])
    }

    func testFiniteErrorDecoderDiscardsUnknownCodesAndAllRawDescriptions() {
        for payload in [
            #"{"error":{"code":"PRIVATE_UNKNOWN_CODE","message":"PRIVATE_NAME","details":["PRIVATE_XML"]}}"#,
            #"{"code":"PRIVATE_UNKNOWN_CODE","message":"PRIVATE_NAME"}"#,
            "PRIVATE_NON_JSON_BODY"
        ] {
            let failure = DigiLockerBackendError.decode(from: Data(payload.utf8), statusCode: 503)
            XCTAssertNil(failure.code)
            XCTAssertEqual(DigiLockerAadhaarState.from(error: failure), .uncertain)
            XCTAssertFalse(String(reflecting: failure).contains("PRIVATE_"))
            XCTAssertFalse(failure.localizedDescription.contains("PRIVATE_"))
        }
        let known = DigiLockerBackendError.decode(from: Data(#"{"code":"digilocker_integrity_failed","message":"PRIVATE_XML"}"#.utf8), statusCode: 503)
        XCTAssertEqual(known.code, .integrityFailed)
        XCTAssertEqual(DigiLockerAadhaarState.from(error: known), .integrityFailure)
        let expiredConnection = DigiLockerBackendError.decode(
            from: Data(#"{"error":{"code":"digilocker_access_unavailable","message":"PRIVATE_CONNECTION_DETAILS"}}"#.utf8),
            statusCode: 400
        )
        XCTAssertEqual(expiredConnection.code, .connectionAccessUnavailable)
        XCTAssertEqual(DigiLockerAadhaarState.from(error: expiredConnection), .reconnectRequired)
        XCTAssertFalse(String(reflecting: expiredConnection).contains("PRIVATE_"))
        XCTAssertFalse(expiredConnection.localizedDescription.contains("PRIVATE_"))
    }

    func testTimeoutInvalidJSONAndNonJSONResponsesAreUncertainWithoutRetries() async throws {
        let service = try await makeService()
        for mode in 0..<4 {
            await MockURLProtocolStorage.shared.reset()
            await MockURLProtocolStorage.shared.setHandler { request in
                switch mode {
                case 0: throw URLError(.timedOut, userInfo: [NSLocalizedDescriptionKey: "PRIVATE_URL"])
                case 1: return (try Self.response(request), Data("PRIVATE_INVALID_JSON".utf8))
                case 2: return (try Self.response(request, contentType: "text/html"), Self.verificationPayload)
                default: return (try Self.response(request, status: 302), Data())
                }
            }
            do { _ = try await service.verifyAadhaar(); XCTFail("Expected uncertain outcome") }
            catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .uncertain) }
            let requests = await MockURLProtocolStorage.shared.requests()
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testErrorBodiesAreBoundedBeforeCodeExtraction() async throws {
        let service = try await makeService()
        let oversized = Data((#"{"error":{"code":"digilocker_aadhaar_not_linked","message":""#
            + String(repeating: "x", count: 16_385) + "\"}}").utf8)
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(request, status: 422), oversized)
        }
        do { _ = try await service.aadhaarAvailability(); XCTFail("Expected bounded rejection") }
        catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .uncertain) }
    }

    func testPreCancelledActionDoesNotSendAnyRequest() async throws {
        let service = try await makeService()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await service.verifyAadhaar()
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testStatesAndProtocolDefaultsAreSafeAndDemoIsSynthetic() async throws {
        for state in DigiLockerAadhaarState.allCases {
            XCTAssertEqual(state.isBusy, state == .checking || state == .verifying)
            XCTAssertFalse(state.message.isEmpty)
        }
        XCTAssertEqual(DigiLockerAadhaarState.from(error: URLError(.timedOut)), .uncertain)
        let legacy = LegacyDigiLockerServiceStub()
        do { _ = try await legacy.aadhaarAvailability(); XCTFail("Expected safe default") }
        catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .unavailable) }
        do { _ = try await legacy.verifyAadhaar(); XCTFail("Expected safe default") }
        catch { XCTAssertEqual(error as? DigiLockerAadhaarState, .unavailable) }
        let demo = DemoDigiLockerService()
        let available = try await demo.aadhaarAvailability()
        XCTAssertTrue(available.available)
        XCTAssertFalse(available.entitlementConfirmed)
        let result = try await demo.verifyAadhaar()
        XCTAssertTrue(result.isVerified)
        let history = try await demo.verificationHistory()
        XCTAssertEqual(history.items.filter { $0.documentType == "EAADHAAR" }, [result])
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    private func makeService(tokens: InMemoryTokenStore = InMemoryTokenStore()) async throws -> DigiLockerService {
        try await tokens.save("synthetic-access", for: .accessToken)
        try await tokens.save("synthetic-refresh", for: .refreshToken)
        let configuration = AppConfiguration(
            buildConfiguration: .development, environment: .staging, isDemoModeEnabled: false,
            apiBaseURL: URL(string: "https://digilocker-tests.invalid/api/v1")!,
            keychainService: "com.kairoid.Kairo.tests.aadhaar"
        )
        return DigiLockerService(sessionService: SessionService(
            configuration: configuration,
            networkClient: URLSessionNetworkClient(baseURL: configuration.apiBaseURL, session: makeMockedURLSession()),
            tokenStore: tokens
        ))
    }

    private func decode<T: Decodable>(_ type: T.Type, _ value: String) throws -> T {
        try APIJSONCoder.makeDecoder().decode(type, from: Data(value.utf8))
    }

    private func verification(type: String = "EAADHAAR", current: Bool = true,
                              match: DigiLockerMatchResult = .verifiedMatch, integrity: String = "verified",
                              date: Date? = Date(timeIntervalSince1970: 1_767_225_600)) -> DigiLockerVerificationDTO {
        .init(documentType: type, source: .digilocker, current: current, matchResult: match,
              matchReason: nil, integrityResult: integrity, verifiedAt: date)
    }

    private nonisolated static func response(_ request: URLRequest, status: Int = 200,
                                             contentType: String = "application/json") throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: status,
            httpVersion: nil, headerFields: ["Content-Type": contentType, "Cache-Control": "no-store"]))
    }

    private nonisolated static let root = "/api/v1/integrations/digilocker"
    private nonisolated static let verificationPayload = Data(#"{"document_type":"EAADHAAR","source":"digilocker","source_type":"eaadhaar","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-01-01T10:00:00Z","consent_purpose":"identity_verification","consent_version":"v1","consented_at":"2026-01-01T10:00:00Z"}"#.utf8)
    private nonisolated static let legacyHistoryPayload = Data(#"{"items":[{"document_type":"PANCR","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":null}],"identity_verified":true}"#.utf8)
}

private actor LegacyDigiLockerServiceStub: DigiLockerServiceProtocol {
    func status() async throws -> DigiLockerStatusDTO { .init(connected: true, status: .active) }
    func connect() async throws -> DigiLockerConnectResponseDTO { throw DigiLockerServiceError.invalidResponse }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO { .init(items: []) }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO { .init(items: [], identityVerified: false) }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO { .init(state: .unverified, sources: []) }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        .init(items: [], identityVerified: false)
    }
}
