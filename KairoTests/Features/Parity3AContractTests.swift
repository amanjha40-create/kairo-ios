import Foundation
import XCTest
@testable import Kairo

@MainActor
final class Parity3AContractTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func testPreciseStatusLanguageAcrossCareerPassportAndDocuments() {
        let values = ["verified": "Verified", "pending_admin_review": "Pending KairoID Review",
            "additional_info_requested": "Needs your attention", "rejected": "Rejected",
            "withdrawn_by_candidate": "Withdrawn", "cancelled": "Cancelled", "unable_to_verify": "Unable to verify",
            "expired": "Expired", "draft": "Draft", "self_declared": "Candidate-provided", "future_state": "Status unavailable"]
        for (raw, expected) in values {
            XCTAssertEqual(ProductStatusLanguage.title(for: raw), expected, raw)
            let careerExpected = [
                "pending_admin_review": "Needs review",
                "withdrawn_by_candidate": "Candidate-provided",
                "additional_info_requested": "Needs review"
            ][raw] ?? expected
            XCTAssertEqual(CareerVerificationStatus(rawBackendValue: raw).badgeStyle.title, careerExpected, raw)
            let passport = PassportRecordVerificationStatus(rawBackendValue: raw)
            if case .precise(let value) = passport { XCTAssertEqual(ProductStatusLanguage.title(for: value), expected) }
        }
    }

    func testWithdrawalEligibilityIsOnlyTheTwoPreOutreachReviewStates() {
        for status in VerifyVerificationStatus.displayOrder {
            XCTAssertEqual(status.canCandidateWithdraw, [.pendingAdminReview, .pendingAdminReReview].contains(status), status.rawBackendValue)
        }
        XCTAssertFalse(VerifyVerificationStatus.unknown("future").canCandidateWithdraw)
        let withdrawn = VerifyVerificationStatus(rawBackendValue: "withdrawn_by_candidate")
        XCTAssertEqual(withdrawn, .withdrawnByCandidate)
        XCTAssertEqual(withdrawn.group, .completed)
        XCTAssertEqual(withdrawn.style.title, "Withdrawn")
        XCTAssertEqual(VerifyVerificationStatus.cancelled.style.title, "Cancelled")
    }

    func testAuthoritativeDraftCanRestartVerificationButUnknownStatusCannot() {
        XCTAssertTrue(CareerVerificationStatus(rawBackendValue: "draft").canStartVerification)
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "draft").badgeStyle.title, "Draft")
        for raw in ["pending_admin_review", "pending_admin_re_review", "future_state"] {
            XCTAssertFalse(CareerVerificationStatus(rawBackendValue: raw).canStartVerification)
            let subject = VerificationInitiationSubject(id: "record", kind: .employment, title: "QA", subtitle: "QA",
                verificationStatus: .init(rawBackendValue: raw), hasActiveRequest: false)
            XCTAssertFalse(subject.isEligible)
        }
        XCTAssertEqual(CareerRecordVerificationStatus(rawBackendValue: "future_state"), .unavailable)
    }

    func testV2MissingProfileScopeFailsClosedWithoutChangingLegacyDecoding() throws {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.shareData()) as? [String: Any])
        var permissions = try XCTUnwrap(object["permissions"] as? [String: Any])
        permissions.removeValue(forKey: "include_profile")
        permissions.removeValue(forKey: "show_photo")
        object["permissions"] = permissions
        object["policy_version"] = 2
        object["sharing_mode"] = "verified_only"
        let decoder = APIJSONCoder.makeDecoder()
        XCTAssertThrowsError(try decoder.decode(PassportShareResponseDTO.self, from: JSONSerialization.data(withJSONObject: object)))
        object["policy_version"] = 1
        object["sharing_mode"] = "legacy_mixed"
        let legacy = try decoder.decode(PassportShareResponseDTO.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.domain.sharingMode, .legacyMixed)
        XCTAssertTrue(legacy.permissions.includeProfile)
    }

    func testWithdrawalUsesExactPublicIDPostAndNoSyntheticFollowupMutation() async throws {
        let (session, _) = try await makeSession()
        let service = VerifyOverviewService(sessionService: session)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/verification-requests/request-public-id/withdraw")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertNil(request.httpBody)
            return (try Self.response(request), Data(#"{"public_id":"request-public-id","request_type":"employment","status":"withdrawn_by_candidate","created_at":"2030-01-01T00:00:00Z","updated_at":"2030-01-01T00:01:00Z"}"#.utf8))
        }
        try await service.performAction(requestID: "request-public-id", action: .withdraw, response: nil, consent: nil)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
        // The server releases the record; iOS must not PATCH Career or recycle the old request ID.
        XCTAssertFalse(requests.contains { $0.httpMethod == "PATCH" })
    }

    func testCapabilityFailurePreventsAnyCreateRequest() async throws {
        let (session, config) = try await makeSession()
        let service = PassportShareService(sessionService: session, configuration: config)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/passport-shares/capabilities")
            return (try Self.response(request, status: 503), Data(#"{"message":"Unavailable"}"#.utf8))
        }
        do {
            _ = try await service.createShare(.init(label: "Contract QA", permissions: .privacyPreserving, expiresAt: nil))
            XCTFail("Capabilities must fail closed")
        } catch {}
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests.allSatisfy { $0.httpMethod == "GET" })
    }

    func testWithdrawnHistoryDoesNotLockDraftAndNewVerificationUsesNewPublicID() async throws {
        let (session, _) = try await makeSession()
        let career = CareerOverviewService(authService: DemoAuthService(sessionService: session), sessionService: session)
        let service = VerificationInitiationService(careerService: career, sessionService: session)
        await MockURLProtocolStorage.shared.setHandler { request in
            func payload(_ id: String, _ status: String) -> String {
                "{\"public_id\":\"\(id)\",\"employment_id\":\"emp\",\"request_type\":\"employment\",\"status\":\"\(status)\",\"created_at\":\"2030-01-01T00:00:00Z\",\"updated_at\":\"2030-01-01T00:00:00Z\"}"
            }
            let json: String
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/employments/emp/evidence-eligibility"):
                json = #"{"eligible_primary_count":2,"minimum_required":2,"eligible":true}"#
            case ("GET", "/api/v1/employments"):
                json = #"[{"id":"emp","job_title":"Edited role","company_name":"Synthetic Company","verification_status":"draft","verification_method":"document_upload"}]"#
            case ("GET", "/api/v1/verification-requests/me"):
                json = "[\(payload("old-withdrawn", "withdrawn_by_candidate"))]"
            case ("GET", "/api/v1/educations"), ("GET", "/api/v1/certifications"), ("GET", "/api/v1/projects"), ("GET", "/api/v1/skills"), ("GET", "/api/v1/portfolio"):
                json = "[]"
            case ("POST", "/api/v1/employments/emp/verification-request"):
                json = payload("new-request", "pending_subject_submission")
            case ("POST", "/api/v1/verification-requests/new-request/submit-for-review"), ("GET", "/api/v1/verification-requests/new-request"):
                json = payload("new-request", "pending_admin_review")
            default: XCTFail("Unexpected recovery request"); throw URLError(.badURL)
            }
            return (try Self.response(request), Data(json.utf8))
        }
        let eligibility = try await service.loadEligibility()
        let subject = try XCTUnwrap(eligibility.eligibleSubjects.first)
        XCTAssertFalse(subject.hasActiveRequest)
        let overview = try await career.loadOverview()
        XCTAssertTrue(try XCTUnwrap(overview.employments.first).allowsCandidateEditing)
        var draft = VerificationInitiationDraft(subject: subject,
            documents: [.init(id: "doc", documentType: "other", filename: "synthetic.pdf", isUploadComplete: true, evidenceRole: .primary),
                        .init(id: "doc2", documentType: "other", filename: "synthetic2.pdf", isUploadComplete: true, evidenceRole: .primary)])
        draft.employmentEligibility = .init(eligiblePrimaryCount: 2, minimumRequired: 2, eligible: true)
        draft.selectedDocumentIDs = ["doc", "doc2"]
        draft.contactEmail = "verifier@example.invalid"
        draft.consentsToClaimFields = true
        draft.consentsToEvidence = true
        let result = try await service.submit(draft)
        XCTAssertEqual(result.requestID, "new-request")
        XCTAssertNotEqual(result.requestID, "old-withdrawn")
        XCTAssertFalse(result.reusedExistingRequest)
        let writes = await MockURLProtocolStorage.shared.requests().filter { $0.httpMethod != "GET" }
        XCTAssertEqual(writes.map { $0.url?.path }, ["/api/v1/employments/emp/verification-request", "/api/v1/verification-requests/new-request/submit-for-review"])
    }

    func testVerifiedDefaultMixedOptInAndDependencies() throws {
        var draft = PassportShareDraft()
        let caps = PassportShareCapabilities.demoV2
        draft.selectMode(.verifiedOnly, capabilities: caps)
        XCTAssertEqual(draft.sharingMode, .verifiedOnly)
        XCTAssertEqual(Set(draft.permissions.enabledOptions), Set([.employments, .educations, .employerNames]))
        XCTAssertFalse(caps.options(for: .verifiedOnly).contains(.certifications))
        XCTAssertFalse(caps.options(for: .verifiedOnly).contains(.profile))
        draft.selectMode(.mixed, capabilities: caps)
        XCTAssertTrue(draft.permissions.enabledOptions.isEmpty)
        XCTAssertTrue(caps.options(for: .mixed).contains(.profile))
        XCTAssertTrue(caps.options(for: .mixed).contains(.photo))
        XCTAssertFalse(caps.options(for: .mixed).contains(.portfolio))
        draft.label = " QA purpose "
        var input = try XCTUnwrap(draft.mutationInput())
        XCTAssertEqual(input.label, "QA purpose")
        var permissions = input.permissions
        permissions.showPhoto = true
        input = .init(label: input.label, permissions: permissions, expiresAt: nil, sharingMode: .mixed)
        XCTAssertThrowsError(try caps.validate(input))
    }

    func testPurposeMustBeTrimmedOneTo120Characters() {
        var draft = PassportShareDraft()
        for value in ["", "  \n\t", String(repeating: "a", count: 121)] {
            draft.label = value
            XCTAssertNil(draft.mutationInput())
            XCTAssertNotNil(draft.purposeValidationMessage)
        }
        for value in ["x", String(repeating: "a", count: 120), "  QA \n"] {
            draft.label = value
            XCTAssertNotNil(draft.mutationInput())
        }
    }

    func testNarrowPatchOnlyContainsDeliberatelyChangedPermissions() throws {
        var permissions = PassportSharePermissions.privacyPreserving
        permissions.includeEmployments = true
        permissions.includeEducations = true
        let share = Self.share(permissions: permissions)
        var draft = PassportShareDraft(share: share)
        draft.permissions.includeEducations = false
        let data = try APIJSONCoder.makeEncoder().encode(PassportShareUpdateRequestDTO(input: XCTUnwrap(draft.mutationInput())))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["permissions"] as? [String: Bool], ["include_educations": false])
        XCTAssertNil(json["sharing_mode"])
        XCTAssertNil(json["label"])
        XCTAssertNil(json["expires_at"])
    }

    func testExpansionRejectedBeforePatchEvenIfDraftIsForged() async throws {
        let (session, config) = try await makeSession()
        let service = PassportShareService(sessionService: session, configuration: config)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            return (try Self.response(request), try Self.shareData())
        }
        var permissions = PassportSharePermissions.privacyPreserving
        permissions.showDocuments = true
        do {
            _ = try await service.updateShare(id: "share-id", input: .init(label: "QA", permissions: permissions, expiresAt: nil))
            XCTFail("Cannot broaden an existing link")
        } catch { XCTAssertEqual(error as? PassportShareServiceError, .newLinkRequired) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testLegacyPolicyAndPermissionsAreNeverAutoConverted() throws {
        let decoder = APIJSONCoder.makeDecoder()
        let legacyData = try Self.shareData(policy: 1, mode: "legacy_mixed")
        let legacy = try decoder.decode(PassportShareResponseDTO.self, from: legacyData).domain
        XCTAssertEqual(legacy.sharingMode.title, "Legacy sharing policy")
        var draft = PassportShareDraft(share: legacy)
        draft.selectMode(.verifiedOnly, capabilities: .demoV2)
        XCTAssertEqual(draft.sharingMode, .legacyMixed)
        XCTAssertEqual(draft.permissions, legacy.permissions)
    }

    func testUnknownPolicyDoesNotEnableEditingOrCapabilities() throws {
        let share = try APIJSONCoder.makeDecoder().decode(PassportShareResponseDTO.self, from: Self.shareData(policy: 3, mode: "future_mode")).domain
        XCTAssertFalse(share.policyEditable)
        XCTAssertEqual(share.sharingMode, .unknown)
        let caps = PassportShareCapabilities(policyVersion: 3, defaultMode: "verified_only", modes: ["verified_only"], verifiedOnlySections: [], mixedSections: [], derivedTrustScore: true, narrowOnlyUpdates: true)
        XCTAssertFalse(caps.supportsV2)
        XCTAssertTrue(caps.options(for: .verifiedOnly).isEmpty)
    }

    func testDocumentsFiltersAndEvidenceMutability() {
        let doc = CareerDocument(id: "doc", documentType: "certificate", originalFilename: "certificate.pdf", contentType: "application/pdf", byteSize: 40, verificationStatus: "draft")
        let current = DocumentsHubRow(id: "current", category: .certifications, filename: doc.originalFilename,
            context: "Certification", contentType: doc.contentType, byteSize: doc.byteSize, status: "Draft", historical: false,
            immutable: false, source: .career(.certification(id: "cert", title: "Certificate"), doc))
        let historical = DocumentsHubRow(id: "old", category: .verification, filename: "Historical education evidence", context: "Immutable",
            contentType: "", byteSize: 0, status: "Status unavailable", historical: true, immutable: true, source: .unavailable)
        XCTAssertEqual(DocumentsHubRow.categories(in: [current, historical]), [.all, .certifications, .verification])
        XCTAssertTrue(current.canReplace && current.canRemove && current.canView)
        XCTAssertFalse(historical.canReplace || historical.canRemove || historical.canView)
        var attachedEvidence = current
        attachedEvidence.immutable = true
        XCTAssertTrue(attachedEvidence.canView)
        XCTAssertFalse(attachedEvidence.canReplace || attachedEvidence.canRemove)
    }

    func testOwnerCollectionReadsEveryPageWithoutDroppingPortfolioData() async throws {
        let (session, _) = try await makeSession()
        await MockURLProtocolStorage.shared.setHandler { request in
            let second = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "offset" && $0.value == "1" } == true
            let id = second ? "legacy-2" : "legacy-1"
            return (try Self.response(request), Data("{\"items\":[{\"id\":\"\(id)\",\"title\":\"Retained project\",\"verification_status\":\"draft\"}],\"total\":2}".utf8))
        }
        let rows = try await loadOwnerCollection(PortfolioRecord.self, path: "/portfolio", session: session)
        XCTAssertEqual(rows.map(\.id), ["legacy-1", "legacy-2"])
    }

    private func makeSession() async throws -> (SessionService, AppConfiguration) {
        let config = AppConfiguration(buildConfiguration: .staging, environment: .staging, isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging), keychainService: "tests.parity3a")
        let tokens = InMemoryTokenStore()
        try await tokens.save("mock-session", for: .accessToken)
        return (SessionService(configuration: config, networkClient: URLSessionNetworkClient(baseURL: config.apiBaseURL, session: makeMockedURLSession()), tokenStore: tokens), config)
    }

    func testHubAggregatesEveryOwnerSourceAndPreservesLegacyAndImmutableHistory() async throws {
        let (session, _) = try await makeSession()
        let career = CareerOverviewService(authService: DemoAuthService(sessionService: session), sessionService: session)
        let documents = CareerDocumentService(sessionService: session)
        let hub = DocumentsHubService(career: career, documents: documents, vault: DocumentVaultService(sessionService: session), session: session)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET", "Hub loading is read-only")
            let cert = #"{"id":"cert","title":"Certificate","original_filename":"certificate.pdf","content_type":"application/pdf","byte_size":10,"verification_status":"draft"}"#
            let legacy = #"{"id":"legacy","title":"Old project","original_filename":"legacy.pdf","content_type":"application/pdf","byte_size":20,"verification_status":"self_declared","upload_completed_at":"2030-01-01T00:00:00Z"}"#
            let json: String
            switch request.url?.path {
            case "/api/v1/employments": json = #"[{"id":"emp","job_title":"Engineer","company_name":"Synthetic Company","verification_status":"draft","verification_method":"document_upload"}]"#
            case "/api/v1/educations": json = #"[{"id":"edu","institution_name":"Synthetic School","verification_status":"draft"}]"#
            case "/api/v1/certifications": json = "[\(cert)]"
            case "/api/v1/certifications/cert": json = cert
            case "/api/v1/portfolio": json = "{\"items\":[\(legacy)],\"total\":1}"
            case "/api/v1/portfolio/legacy": json = legacy
            case "/api/v1/projects", "/api/v1/skills": json = "[]"
            case "/api/v1/employments/emp/documents", "/api/v1/educations/edu/documents":
                let id = request.url?.path.contains("employments") == true ? "emp-doc" : "edu-doc"
                json = "{\"items\":[{\"id\":\"\(id)\",\"document_type\":\"other\",\"original_filename\":\"\(id).pdf\",\"content_type\":\"application/pdf\",\"byte_size\":20,\"verification_status\":\"draft\"}],\"total\":1}"
            case "/api/v1/user-documents": json = #"{"items":[{"id":"vault","document_type":"other","original_filename":"vault.pdf","content_type":"application/pdf","byte_size":10,"verification_status":"draft","created_at":"2030-01-01T00:00:00Z","updated_at":"2030-01-01T00:00:00Z"}],"total":1}"#
            case "/api/v1/verification-requests/me": json = #"[{"public_id":"request","employment_id":"emp","status":"withdrawn_by_candidate"}]"#
            case "/api/v1/verification-requests/request/evidence": json = #"[{"public_id":"evidence-current","employment_document_id":"emp-doc"},{"public_id":"evidence-historical-education","education_document_id":"old-edu-doc","original_filename":"historic.pdf"},{"public_id":"evidence-removed-employment","employment_document_id":"removed-emp-doc","original_filename":"removed.pdf"}]"#
            default: XCTFail("Unexpected hub read"); throw URLError(.badURL)
            }
            return (try Self.response(request), Data(json.utf8))
        }
        let rows = try await hub.load()
        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(DocumentsHubRow.categories(in: rows), [.all, .employment, .education, .certifications, .portfolio, .verification, .other])
        let portfolio = try XCTUnwrap(rows.first { $0.category == .portfolio })
        XCTAssertTrue(portfolio.context.contains("Portfolio"))
        XCTAssertTrue(portfolio.canView)
        let emp = try XCTUnwrap(rows.first { $0.category == .employment })
        XCTAssertTrue(emp.immutable)
        XCTAssertFalse(emp.canRemove || emp.canReplace)
        let oldEducation = try XCTUnwrap(rows.first { $0.filename == "historic.pdf" })
        XCTAssertFalse(oldEducation.canView || oldEducation.canReplace || oldEducation.canRemove)
        let removedEmployment = try XCTUnwrap(rows.first { $0.filename == "removed.pdf" })
        XCTAssertFalse(removedEmployment.canView || removedEmployment.canReplace || removedEmployment.canRemove)
        XCTAssertTrue(rows.allSatisfy { !$0.context.contains("https://") && !$0.filename.contains("https://") })
        let overview = try await career.loadOverview()
        let mapped = CareerOverviewMapper.map(overview)
        guard case .populated(let content) = mapped.phase else { return XCTFail("Legacy content must remain visible") }
        XCTAssertTrue(content.projects.isEmpty)
        XCTAssertEqual(content.portfolio.first?.routeID, "legacy")
        XCTAssertEqual(content.portfolio.first?.title, "Old project")
    }
    func testHubKeepsPreciseVaultTaxonomyAndLegacyRawValues() async throws {
        let (session, _) = try await makeSession()
        let hub = DocumentsHubService(
            career: CareerOverviewService(authService: DemoAuthService(sessionService: session), sessionService: session),
            documents: CareerDocumentService(sessionService: session), vault: DocumentVaultService(sessionService: session), session: session)
        let types = ["birth_certificate": "Birth Certificate", "address_proof": "Address Proof", "government_id": "Government ID",
                     "other": "Other", "future_identity": "Identity document"]
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            if request.url?.path == "/api/v1/user-documents" {
                let records = types.keys.map { raw in
                    ["id": raw, "document_type": raw, "original_filename": "fixture.pdf", "content_type": "application/pdf",
                     "byte_size": 8, "verification_status": "draft", "created_at": "2030-01-01T00:00:00Z", "updated_at": "2030-01-01T00:00:00Z"] as [String: Any]
                }
                return (try Self.response(request), try JSONSerialization.data(withJSONObject: ["items": records]))
            }
            return (try Self.response(request), Data("[]".utf8))
        }
        let rows = try await hub.load()
        XCTAssertEqual(rows.count, types.count)
        for row in rows {
            guard case .vault(let document) = row.source else { return XCTFail("Vault source lost") }
            XCTAssertEqual(document.documentType.rawValue, document.id)
            XCTAssertEqual(row.context, "Vault · \(types[document.id]!) · Current")
        }
    }

    private nonisolated static func response(_ request: URLRequest, status: Int = 200) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: nil))
    }
    private nonisolated static func share(permissions: PassportSharePermissions) -> PassportShare {
        PassportShare(id: "share-id", label: "QA", permissions: permissions, trackViews: true, expiresAt: nil,
            revokedAt: nil, lastViewedAt: nil, createdAt: .distantPast, updatedAt: .distantPast, state: .active,
            policyVersion: 2, sharingMode: .verifiedOnly)
    }
    private nonisolated static func shareData(policy: Int = 2, mode: String = "verified_only") throws -> Data {
        let permissions = try JSONSerialization.jsonObject(with: APIJSONCoder.makeEncoder().encode(PassportSharePermissions.privacyPreserving))
        return try JSONSerialization.data(withJSONObject: ["id": "share-id", "label": "QA", "permissions": permissions,
            "track_views": true, "state": "active", "policy_version": policy, "sharing_mode": mode,
            "created_at": "2030-01-01T00:00:00Z", "updated_at": "2030-01-01T00:00:00Z"])
    }
}
