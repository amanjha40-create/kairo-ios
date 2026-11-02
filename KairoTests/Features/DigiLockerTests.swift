import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DigiLockerTests: XCTestCase {
    func testDiscoveryDOBGuardBlocksIdentityButNotEducationOnly() {
        XCTAssertTrue(DigiLockerDiscoveryDOBPrecondition.isBlocking(includesIdentity: true, dateOfBirth: nil))
        XCTAssertFalse(DigiLockerDiscoveryDOBPrecondition.isBlocking(includesIdentity: false, dateOfBirth: nil))
        XCTAssertFalse(DigiLockerDiscoveryDOBPrecondition.isBlocking(
            includesIdentity: true,
            dateOfBirth: Date(timeIntervalSince1970: 946_684_800)
        ))
        XCTAssertEqual(DigiLockerDiscoveryDOBPrecondition.title, "Date of birth required")
    }

    func testMissingDOBBlocksPANAndDLWithoutProviderOrRefreshError() async throws {
        let service = DigiLockerServiceStub(status: .init(connected: true, status: .active),
            trust: try decode(DigiLockerIdentityTrustDTO.self, #"{"state":"unverified","sources":[]}"#),
            history: .init(items: [], identityVerified: false))
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        let before = store.history
        for type in [DigiLockerDocumentType.pan, .drivingLicence] {
            let result = await store.verify([type], profile: ProfileSnapshot.fixture.user)
            XCTAssertFalse(result)
            XCTAssertEqual(store.verificationErrorMessage, "Add your date of birth to continue verification.")
            XCTAssertNil(store.actionErrorMessage)
            XCTAssertEqual(store.history, before)
            XCTAssertFalse(store.isVerifying)
        }
        XCTAssertNil(DigiLockerDOBPrecondition.message(types: [.pan, .drivingLicence], dateOfBirth: Date(timeIntervalSince1970: 946684800)))
        XCTAssertNil(DigiLockerDOBPrecondition.message(types: [], dateOfBirth: nil))
        let calls = await service.verificationCalls()
        XCTAssertEqual(calls, 0, "Missing DOB must block before any verification/provider request")
    }
    func testPartialPANFailureRetainsSuccessfulDLAndUsesSanitizedCopy() async throws {
        let response = try decode(
            DigiLockerVerificationHistoryDTO.self,
            #"{"items":[{"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z"}],"identity_verified":true,"document_outcomes":[{"document_type":"DRVLC","status":"verified","verification_id":"safe-id","error_code":null,"retryable":false},{"document_type":"PANCR","status":"failed","verification_id":null,"error_code":"digilocker_document_request_rejected","retryable":true}]}"#
        )
        let service = DigiLockerServiceStub(
            status: .init(connected: true, status: .active),
            trust: try decode(DigiLockerIdentityTrustDTO.self, String(decoding: Self.trustPayload, as: UTF8.self)),
            history: response
        )
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()

        let retainedSuccess = await store.verify([.pan, .drivingLicence])
        XCTAssertTrue(retainedSuccess)
        XCTAssertEqual(store.history?.items.map(\.documentType), ["DRVLC"])
        XCTAssertEqual(
            store.verificationErrorMessage,
            "PAN verification couldn’t be completed right now. Please try again later."
        )
        XCTAssertFalse(store.verificationErrorMessage?.contains("uri_missing") == true)
    }
    func testStalePANReferenceUsesActionableRefreshWithoutProviderDetails() async throws {
        let response = try decode(
            DigiLockerVerificationHistoryDTO.self,
            #"{"items":[{"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z"}],"identity_verified":true,"document_outcomes":[{"document_type":"DRVLC","status":"already_verified","verification_id":"safe-id","error_code":null,"retryable":false},{"document_type":"PANCR","status":"failed","verification_id":null,"error_code":"digilocker_pan_reference_unavailable","retryable":false}]}"#
        )
        let service = DigiLockerServiceStub(
            status: .init(connected: true, status: .active),
            trust: try decode(DigiLockerIdentityTrustDTO.self, String(decoding: Self.trustPayload, as: UTF8.self)),
            history: response
        )
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()

        let verified = await store.verify([.pan, .drivingLicence])

        XCTAssertTrue(verified)
        XCTAssertEqual(store.history?.items.map(\.documentType), ["DRVLC"])
        XCTAssertEqual(store.history?.items.first?.matchResult, .verifiedMatch)
        XCTAssertFalse(store.history?.items.contains(where: { $0.documentType == "PANCR" }) == true)
        XCTAssertNil(store.actionErrorMessage, "PAN failure belongs to Verify, not Refresh")
        let calls = await service.verificationCalls()
        XCTAssertEqual(calls, 1, "No automatic retry for an unavailable PAN reference")
        XCTAssertEqual(
            store.verificationErrorMessage,
            "DigiLocker couldn’t resolve this PAN. Refresh or re-add your PAN in DigiLocker, then return to KairoID and verify again."
        )
        XCTAssertFalse(store.verificationErrorMessage?.contains("uri_missing") == true)
        XCTAssertFalse(store.verificationErrorMessage?.contains("XML") == true)
        XCTAssertFalse(store.verificationErrorMessage?.contains("provider") == true)
    }

    func testSuccessfulPANRetainsVerifiedPresentationWithoutRecoveryGuidance() async throws {
        let history = DigiLockerVerificationHistoryDTO(items: [.init(documentType: "PANCR", source: .digilocker,
            current: true, matchResult: .verifiedMatch, matchReason: nil, integrityResult: "verified", verifiedAt: .distantPast)],
            identityVerified: true)
        let trust = try decode(DigiLockerIdentityTrustDTO.self,
            #"{"state":"verified","sources":[{"source":"digilocker","document_type":"PANCR","current":true,"match_result":"VERIFIED_MATCH","reason":null}]}"#)
        let store = DigiLockerStore(service: DigiLockerServiceStub(status: .init(connected: true, status: .active),
            trust: trust, history: history))
        await store.refreshSummary()
        let success = await store.verify([.pan])
        XCTAssertTrue(success)
        XCTAssertTrue(store.history?.items.first?.isVerified == true)
        XCTAssertTrue(store.identityIsVerified)
        XCTAssertNil(store.verificationErrorMessage)
    }
    func testVerificationFailureKeepsSafeBackendCategoriesWithoutProviderProse() async throws {
        let service = try await makeService()
        for (status, code, expected) in [
            (422, "validation_error", "request was rejected"),
            (503, "digilocker_not_configured", "currently unavailable"),
            (403, "digilocker_insufficient_scope", "not granted access"),
            (503, "digilocker_integrity_failed", "integrity checks"),
            (400, "digilocker_document_request_rejected", "PAN verification couldn’t be completed"),
            (400, "digilocker_pan_reference_unavailable", "Refresh or re-add your PAN in DigiLocker")
        ] {
            await MockURLProtocolStorage.shared.setHandler { request in
                XCTAssertEqual(request.url?.path, "/api/v1/integrations/digilocker/identity/verify")
                return (try Self.response(for: request, statusCode: status),
                        Data("{\"error\":{\"code\":\"\(code)\",\"message\":\"PRIVATE_PROVIDER_DETAILS\"}}".utf8))
            }
            do {
                _ = try await service.verify(documentTypes: [.pan, .drivingLicence])
                XCTFail("Expected a verification failure")
            } catch {
                XCTAssertNotNil(error as? DigiLockerBackendError)
                let message = DigiLockerVerificationFailure.message(for: error)
                XCTAssertTrue(message.contains(expected), message)
                XCTAssertFalse(message.contains("PRIVATE"))
            }
        }
    }
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

    func test_dynamicDiscoveryAndImportUseAPI79ContractsWithoutProviderSecrets() async throws {
        let service = try await makeService()
        let available = Data(
            #"{"identity":[{"candidate_id":"identity-1","doctype":"PANCR","record_type":"identity","display_type":"PAN","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready"}],"education":[{"candidate_id":"education-1","record_type":"education","display_type":"Degree certificate","source":"digilocker","possible_existing_record_match":"CLEAR_MATCH","import_status":"needs_review","review_state":"needs_review","evidence":[]}],"address_candidates":[],"address_prefill_candidates":[{"candidate_id":"address-1","doctype":"DRVLC","display_type":"Driving Licence address","source":"digilocker_driving_licence","review_state":"ready","candidate_type":"prefill","address_state":"ADDRESS_PREFILL_CANDIDATE","document_address_type":"untyped","requires_permanent_confirmation":true,"requires_replacement_confirmation":false,"prefill_text":"Synthetic address for review","structured_address":null}],"address_discovery_state":"ADDRESS_PREFILL_CANDIDATE","counts":{"total_issued":3,"supported":3,"unsupported":0,"identity":1,"education":1,"address_candidates":0,"address_prefill_candidates":1,"xml_available":2,"pdf_only":0,"parse_failures":0,"malformed":0},"discovered_at":"2026-10-31T10:00:00Z"}"#.utf8
        )
        let imported = Data(
            #"{"outcomes":[{"candidate_id":"identity-1","domain":"identity","status":"imported","record_id":null,"verification_id":null,"evidence_count":1,"review_state":"ready"}],"completed_at":"2026-10-31T10:01:00Z"}"#.utf8
        )
        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/integrations/digilocker/available-records"):
                return (try Self.response(for: request), available)
            case ("POST", "/api/v1/integrations/digilocker/records/import"):
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBodyData(from: request)) as? [String: Any])
                XCTAssertEqual(json["candidate_ids"] as? [String], ["identity-1"])
                XCTAssertEqual(json["education_targets"] as? [String: String], [:])
                XCTAssertEqual(json["consent"] as? Bool, true)
                XCTAssertEqual(json["consent_version"] as? String, "v1")
                XCTAssertNil(json["provider_token"])
                return (try Self.response(for: request), imported)
            default:
                XCTFail("Unexpected dynamic DigiLocker request")
                return (try Self.response(for: request, statusCode: 404), Data())
            }
        }

        let discovery = try await service.availableRecords()
        XCTAssertEqual(discovery.identity.map(\.displayType), ["PAN"])
        XCTAssertEqual(discovery.education.first?.importStatus, .needsReview)
        XCTAssertEqual(discovery.addressPrefillCandidates.first?.candidateType, .prefill)
        XCTAssertTrue(discovery.addressPrefillCandidates.first?.requiresPermanentConfirmation == true)
        let result = try await service.importRecords(
            candidateIDs: ["identity-1"], educationTargets: [:], consent: true
        )
        XCTAssertEqual(result.outcomes.first?.status, "imported")
    }

    func testAPI87PartialDiscoveryDecodesAuthoritativeRecordsAndSafeFailures() throws {
        let response = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87PartialPayload, as: UTF8.self)
        )

        XCTAssertEqual(response.discoveryStatus, .partialSuccess)
        XCTAssertEqual(response.counts.providerFailures, 1)
        XCTAssertEqual(response.identity.map(\.documentType), ["PANCR", "DRVLC"])
        XCTAssertTrue(response.identity.allSatisfy(\.canImport))
        XCTAssertEqual(response.education.first?.evidence.map(\.documentType), ["DGCER", "SPCER"])
        XCTAssertEqual(response.education.first?.evidence.last?.failureReason, .providerUnavailable)
        XCTAssertEqual(response.education.first?.evidence.last?.reviewState, .parseFailed)
        XCTAssertTrue(response.education.first?.canImport == true)
        XCTAssertEqual(response.addressPrefillCandidates.first?.documentType, "DRVLC")
        XCTAssertEqual(response.addressPrefillCandidates.first?.prefillText, "Synthetic address for review")

        let reflected = String(reflecting: response)
        XCTAssertFalse(reflected.contains("PRIVATE_PROVIDER_BODY"))
        XCTAssertFalse(reflected.contains("530"))
    }

    func testAuthoritativeSuccessSurvivesSupplementalIssuedFailure() async throws {
        let records = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87SuccessPayload, as: UTF8.self)
        )
        let service = DigiLockerInventoryStub(available: [.value(records)], issued: .failure)
        let store = DigiLockerStore(service: service)

        await store.refreshSummary()
        await store.refreshInventory()

        XCTAssertFalse(store.inventoryError)
        XCTAssertTrue(store.issuedDocumentsError)
        XCTAssertEqual(store.availableRecords?.identity.map(\.documentType), ["PANCR", "DRVLC"])
        XCTAssertEqual(store.availableRecords?.addressPrefillCandidates.count, 1)
        XCTAssertTrue(store.issuedDocuments.isEmpty)
    }

    func testPartialDiscoveryAndAddressSurviveIssued530Equivalent() async throws {
        let records = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87PartialPayload, as: UTF8.self)
        )
        let service = DigiLockerInventoryStub(available: [.value(records)], issued: .failure)
        let store = DigiLockerStore(service: service)

        await store.refreshSummary()
        await store.refreshInventory()

        XCTAssertFalse(store.inventoryError)
        XCTAssertTrue(store.issuedDocumentsError)
        XCTAssertEqual(store.availableRecords?.discoveryStatus, .partialSuccess)
        XCTAssertEqual(store.availableRecords?.identity.filter(\.canImport).count, 2)
        XCTAssertEqual(store.availableRecords?.education.filter(\.canImport).count, 1)
        XCTAssertEqual(store.availableRecords?.addressPrefillCandidates.count, 1)
        XCTAssertEqual(
            DigiLockerDiscoveryPresentation.status(.needsReview, failureReason: .providerUnavailable),
            "Temporarily unavailable"
        )
    }

    func testUnavailableDiscoveryWinsOverSuccessfulIssuedSupplement() async throws {
        let records = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87UnavailablePayload, as: UTF8.self)
        )
        let service = DigiLockerInventoryStub(
            available: [.value(records)],
            issued: .value(DigiLockerIssuedDocumentsDTO(items: [
                DigiLockerIssuedDocumentDTO(documentType: "PANCR", supported: true)
            ]))
        )
        let store = DigiLockerStore(service: service)

        await store.refreshSummary()
        await store.refreshInventory()

        XCTAssertTrue(store.inventoryError)
        XCTAssertEqual(store.availableRecords?.discoveryStatus, .unavailable)
        XCTAssertEqual(store.issuedDocuments.map(\.documentType), ["PANCR"])
        XCTAssertTrue(store.availableRecords?.identity.isEmpty == true)
    }

    func testAuthoritativeRequestFailureCannotBeReconstructedFromIssuedSupplement() async {
        let service = DigiLockerInventoryStub(
            available: [.failure],
            issued: .value(DigiLockerIssuedDocumentsDTO(items: [
                DigiLockerIssuedDocumentDTO(documentType: "PANCR", supported: true)
            ]))
        )
        let store = DigiLockerStore(service: service)

        await store.refreshSummary()
        await store.refreshInventory()

        XCTAssertTrue(store.inventoryError)
        XCTAssertNil(store.availableRecords)
        XCTAssertEqual(store.issuedDocuments.map(\.documentType), ["PANCR"])
    }

    func testRefreshRelaunchAndReconnectRemainAuthoritative() async throws {
        let partial = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87PartialPayload, as: UTF8.self)
        )
        let success = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87SuccessPayload, as: UTF8.self)
        )
        let service = DigiLockerInventoryStub(
            status: DigiLockerStatusDTO(connected: true, status: .active),
            available: [.value(partial), .value(success), .value(success)],
            issued: .failure
        )
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()
        await store.refreshInventory()
        XCTAssertEqual(store.availableRecords?.discoveryStatus, .partialSuccess)

        await store.refreshInventory()
        XCTAssertEqual(store.availableRecords?.discoveryStatus, .success)
        XCTAssertFalse(store.inventoryError)

        let relaunched = DigiLockerStore(service: service)
        await relaunched.refreshAll()
        XCTAssertEqual(relaunched.availableRecords?.identity.count, 2)
        XCTAssertFalse(relaunched.inventoryError)

        await service.setStatus(.init(connected: false, status: .reconnectRequired))
        await relaunched.refreshAll()
        XCTAssertNil(relaunched.availableRecords)
        await service.appendAvailable(.value(success))
        await service.setStatus(.init(connected: true, status: .active))
        await relaunched.refreshAll()
        XCTAssertEqual(relaunched.availableRecords?.discoveryStatus, .success)
    }

    func testCancellationKeepsAlreadyAppliedAuthoritativeDiscovery() async throws {
        let records = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87SuccessPayload, as: UTF8.self)
        )
        let service = DigiLockerInventoryStub(
            available: [.value(records)],
            issued: .delayedValue(DigiLockerIssuedDocumentsDTO(items: []))
        )
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()

        let task = Task { await store.refreshInventory() }
        for _ in 0..<100 where store.availableRecords == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(store.availableRecords?.identity.count, 2)
        task.cancel()
        await task.value

        XCTAssertEqual(store.availableRecords?.identity.count, 2)
        XCTAssertFalse(store.inventoryError)
    }

    func testIdentityResetRejectsStaleAuthoritativeAndSupplementalResponses() async throws {
        let records = try decode(
            DigiLockerAvailableRecordsDTO.self,
            String(decoding: Self.api87SuccessPayload, as: UTF8.self)
        )
        let service = DigiLockerInventoryStub(
            available: [.delayedValue(records)],
            issued: .delayedValue(DigiLockerIssuedDocumentsDTO(items: [
                DigiLockerIssuedDocumentDTO(documentType: "PANCR", supported: true)
            ]))
        )
        let store = DigiLockerStore(service: service)
        await store.refreshSummary()

        let task = Task { await store.refreshInventory() }
        try await Task.sleep(for: .milliseconds(50))
        store.resetForIdentityChange()
        await task.value

        XCTAssertNil(store.availableRecords)
        XCTAssertTrue(store.issuedDocuments.isEmpty)
        XCTAssertFalse(store.inventoryError)
        XCTAssertFalse(store.issuedDocumentsError)
    }

    func testPartialDiscoveryCopyNeverExposesProviderCodes() {
        let copy = [
            DigiLockerDiscoveryPresentation.partialTitle,
            DigiLockerDiscoveryPresentation.partialMessage,
            DigiLockerDiscoveryPresentation.status(.needsReview, failureReason: .providerUnavailable)
        ].joined(separator: " ")
        XCTAssertFalse(copy.contains("530"))
        XCTAssertFalse(copy.contains("provider_unavailable"))
        XCTAssertFalse(copy.contains("parse_failed"))
        XCTAssertTrue(copy.contains("temporarily unavailable"))
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

    func test_maskedIdentifiersDecodeFailClosedAndOnlyDisplayForCurrentVerifiedResults() throws {
        let history = try decode(
            DigiLockerVerificationHistoryDTO.self,
            """
            {"items":[
              {"document_type":"PANCR","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z","masked_identifier":"••••••234F"},
              {"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z","masked_identifier":"••••••••1234"},
              {"document_type":"PANCR","source":"digilocker","current":false,"match_result":"PARTIAL_MATCH","match_reason":"REQUIRED_FIELD_MISSING","integrity_result":"verified","verified_at":null,"masked_identifier":"••••••999Z"},
              {"document_type":"PANCR","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z","masked_identifier":"ABCDE1234F"},
              {"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-09-25T10:00:00Z"}
            ],"identity_verified":true}
            """
        )
        XCTAssertEqual(history.items[0].displayMaskedIdentifier, "••••••234F")
        XCTAssertEqual(history.items[1].displayMaskedIdentifier, "••••••••1234")
        XCTAssertNil(history.items[2].displayMaskedIdentifier)
        XCTAssertNil(history.items[3].maskedIdentifier, "A raw identifier must fail closed")
        XCTAssertNil(history.items[4].displayMaskedIdentifier)
        XCTAssertEqual(
            DigiLockerPresentation.maskedIdentifierAccessibilityLabel(
                try XCTUnwrap(history.items[0].displayMaskedIdentifier),
                documentType: "PANCR"
            ),
            "PAN Card ending in 234F"
        )
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
    private nonisolated static let api87PartialPayload = Data(#"{"discovery_status":"partial_success","identity":[{"candidate_id":"pan-1","doctype":"PANCR","record_type":"identity","display_type":"PAN","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","failure_reason":null},{"candidate_id":"dl-1","doctype":"DRVLC","record_type":"identity","display_type":"Driving Licence","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","failure_reason":null}],"education":[{"candidate_id":"education-1","record_type":"education","display_type":"Education records","source":"digilocker","possible_existing_record_match":"NO_MATCH","import_status":"available","review_state":"ready","evidence":[{"candidate_id":"degree-1","doctype":"DGCER","record_type":"education","display_type":"Degree certificate","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","evidence_type":"degree","failure_reason":null},{"candidate_id":"school-1","doctype":"SPCER","record_type":"education","display_type":"School certificate","description":null,"issuer_name":null,"source":"digilocker","xml_available":false,"pdf_available":false,"parsed_data_available":false,"import_status":"needs_review","possible_existing_record_match":"NO_MATCH","review_state":"parse_failed","evidence_type":"certificate","failure_reason":"provider_unavailable"}]}],"address_candidates":[],"address_prefill_candidates":[{"candidate_id":"address-1","doctype":"DRVLC","display_type":"Driving Licence address","source":"digilocker_driving_licence","review_state":"ready","candidate_type":"prefill","address_state":"ADDRESS_PREFILL_CANDIDATE","document_address_type":"untyped","requires_permanent_confirmation":true,"requires_replacement_confirmation":false,"prefill_text":"Synthetic address for review","structured_address":null}],"address_discovery_state":"ADDRESS_PREFILL_CANDIDATE","counts":{"total_issued":5,"supported":5,"unsupported":0,"identity":2,"education":1,"address_candidates":0,"address_prefill_candidates":1,"xml_available":3,"pdf_only":0,"parse_failures":1,"malformed":0,"provider_failures":1},"discovered_at":"2026-11-02T10:00:00Z"}"#.utf8)
    private nonisolated static let api87SuccessPayload = Data(#"{"discovery_status":"success","identity":[{"candidate_id":"pan-1","doctype":"PANCR","record_type":"identity","display_type":"PAN","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","failure_reason":null},{"candidate_id":"dl-1","doctype":"DRVLC","record_type":"identity","display_type":"Driving Licence","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","failure_reason":null}],"education":[],"address_candidates":[],"address_prefill_candidates":[{"candidate_id":"address-1","doctype":"DRVLC","display_type":"Driving Licence address","source":"digilocker_driving_licence","review_state":"ready","candidate_type":"prefill","address_state":"ADDRESS_PREFILL_CANDIDATE","document_address_type":"untyped","requires_permanent_confirmation":true,"requires_replacement_confirmation":false,"prefill_text":"Synthetic address for review","structured_address":null}],"address_discovery_state":"ADDRESS_PREFILL_CANDIDATE","counts":{"total_issued":2,"supported":2,"unsupported":0,"identity":2,"education":0,"address_candidates":0,"address_prefill_candidates":1,"xml_available":2,"pdf_only":0,"parse_failures":0,"malformed":0,"provider_failures":0},"discovered_at":"2026-11-02T10:00:00Z"}"#.utf8)
    private nonisolated static let api87UnavailablePayload = Data(#"{"discovery_status":"unavailable","identity":[],"education":[],"address_candidates":[],"address_prefill_candidates":[],"address_discovery_state":"UNAVAILABLE","counts":{"total_issued":0,"supported":0,"unsupported":0,"identity":0,"education":0,"address_candidates":0,"address_prefill_candidates":0,"xml_available":0,"pdf_only":0,"parse_failures":0,"malformed":0,"provider_failures":0},"discovered_at":"2026-11-02T10:00:00Z"}"#.utf8)
}

private actor DigiLockerInventoryStub: DigiLockerServiceProtocol {
    enum AvailableResponse: Sendable {
        case value(DigiLockerAvailableRecordsDTO)
        case delayedValue(DigiLockerAvailableRecordsDTO)
        case failure
    }

    enum IssuedResponse: Sendable {
        case value(DigiLockerIssuedDocumentsDTO)
        case delayedValue(DigiLockerIssuedDocumentsDTO)
        case failure
    }

    private var currentStatus: DigiLockerStatusDTO
    private var availableResponses: [AvailableResponse]
    private let issuedResponse: IssuedResponse

    init(
        status: DigiLockerStatusDTO = .init(connected: true, status: .active),
        available: [AvailableResponse],
        issued: IssuedResponse
    ) {
        currentStatus = status
        availableResponses = available
        issuedResponse = issued
    }

    func setStatus(_ value: DigiLockerStatusDTO) { currentStatus = value }
    func appendAvailable(_ value: AvailableResponse) { availableResponses.append(value) }
    func status() async throws -> DigiLockerStatusDTO { currentStatus }
    func connect() async throws -> DigiLockerConnectResponseDTO { throw DigiLockerServiceError.invalidResponse }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO {
        switch issuedResponse {
        case .value(let value): return value
        case .delayedValue(let value):
            try await Task.sleep(for: .seconds(5))
            return value
        case .failure: throw DigiLockerBackendError(statusCode: 530, code: nil)
        }
    }
    func availableRecords() async throws -> DigiLockerAvailableRecordsDTO {
        guard !availableResponses.isEmpty else { throw DigiLockerServiceError.invalidResponse }
        switch availableResponses.removeFirst() {
        case .value(let value): return value
        case .delayedValue(let value):
            try await Task.sleep(for: .milliseconds(250))
            return value
        case .failure: throw DigiLockerServiceError.invalidResponse
        }
    }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        .init(items: [], identityVerified: false)
    }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        .init(state: .unverified, sources: [])
    }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        _ = documentTypes
        return .init(items: [], identityVerified: false)
    }
}

private actor DigiLockerServiceStub: DigiLockerServiceProtocol {
    private var verifyCalls = 0
    func verificationCalls() -> Int { verifyCalls }
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
        verifyCalls += 1
        if verificationFails { throw URLError(.timedOut) }
        return historyValue
    }
    func setStatus(_ status: DigiLockerStatusDTO) { currentStatus = status }
    func statusReads() -> Int { reads }
}
