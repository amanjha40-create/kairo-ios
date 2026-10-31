import XCTest
@testable import Kairo

@MainActor final class AndroidV11ParityTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func testSignalsNeverClaimContactVerificationIsIdentityProof() throws {
        guard case .populated(let content) = PassportOverviewState.populatedFixture().phase else { return XCTFail("Missing fixture") }
        let rows = PassportSignalPresentation.rows(content)
        XCTAssertEqual(rows.first?.title, "Account contact")
        XCTAssertEqual(rows.first?.value, "Email verified")
        XCTAssertFalse(rows.contains { $0.title == "Identity" })
        XCTAssertEqual(rows.first { $0.title == "Skills" }?.value, "3 self-declared skills")
        XCTAssertEqual(rows.first { $0.title == "Certifications" }?.value, "1 certification")
        XCTAssertFalse(rows.first { $0.title == "Certifications" }?.value.localizedCaseInsensitiveContains("candidate-provided") == true)
        XCTAssertEqual(rows.first { $0.title == "Projects" }?.value, "1 optional project")
    }

    func testInvitationReadAndExplicitAcceptanceUsePrivateTransportAndCanonicalSession() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("synthetic-test-access", for: .accessToken)
        let configuration = AppConfiguration(buildConfiguration: .staging, environment: .staging, isDemoModeEnabled: false,
            apiBaseURL: URL(string: "https://synthetic.invalid/api/v1")!, keychainService: "unused-in-memory")
        let client = URLSessionNetworkClient(baseURL: configuration.apiBaseURL, session: makeMockedURLSession())
        let service = TrustInvitationService(publicClient: client, session: SessionService(configuration: configuration, networkClient: client, tokenStore: tokens))
        await MockURLProtocolStorage.shared.setHandler { request in
            let response = try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
            if request.httpMethod == "GET" {
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                return (response, Data(#"{"public_id":"invitation-1","organization_name":"Synthetic","subject_name":"Synthetic","purpose":null,"requested_verification_types":[],"expires_at":"2030-01-01T00:00:00Z","status":"pending"}"#.utf8))
            }
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.path.hasSuffix("/accept") == true)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-test-access")
            return (response, Data(#"{"public_id":"invitation-1","organization_public_id":"organization-1","status":"accepted","accepted_at":"2026-01-01T00:00:00Z"}"#.utf8))
        }
        let token = String(repeating: "synthetic", count: 6)
        let invitation = try await service.read(token: token)
        XCTAssertEqual(invitation.status, "pending")
        let afterRead = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(afterRead.count, 1)
        let accepted = try await service.accept(token: token)
        XCTAssertEqual(accepted.status, "accepted")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "Cookie") == nil })
    }

    func testExactlyFourTabsAndLegacyVerificationRoutesIntoCareer() {
        XCTAssertEqual(CandidateTab.allCases, [.home, .career, .passport, .more])
        let router = AppRouter(rootDestination: .mainTabs, selectedTab: .verify)
        XCTAssertEqual(router.selectedTab, .career)
        XCTAssertTrue(router.showsCareerVerification)
        router.selectTab(.passport)
        XCTAssertFalse(router.showsCareerVerification)
        router.enterMainTabs(selectedTab: .verify)
        XCTAssertEqual(router.selectedTab, .career)
        XCTAssertTrue(router.showsCareerVerification)
    }

    func testTrustPassportLightIsPrimaryAndDarkIsLightMonochrome() {
        XCTAssertEqual(TrustPassportMarkVariant.adaptive(dark: false), .primary)
        XCTAssertEqual(TrustPassportMarkVariant.adaptive(dark: true), .monochromeLight)
        XCTAssertEqual(TrustPassportMarkVariant.adaptive(dark: false, small: true), .small)
        XCTAssertEqual(TrustPassportMarkVariant.allCases.count, 4)
    }

    func testProfileFirstInvalidOrderMatchesVisualFields() {
        XCTAssertEqual(ManualProfileBasicField.allCases, [.fullName, .professionalHeadline, .currentRole, .industry, .yearsOfExperience, .currentCity, .currentCountry])
    }

    func testInvitationParserRejectsCrossHostQueriesAndEncodedSeparators() throws {
        let token = String(repeating: "a", count: 43)
        let base = "https://d3kpvsn9kfajzc.cloudfront.net/trust-invitations/"
        let hosts: Set<String> = ["d3kpvsn9kfajzc.cloudfront.net"]
        let result = try XCTUnwrap(TrustInvitationPresentation.parse(try XCTUnwrap(URL(string: base + token)), allowedHosts: hosts))
        XCTAssertEqual(result.token, token)
        XCTAssertFalse(String(describing: result).contains(token))
        XCTAssertFalse(String(reflecting: result).contains(token))
        for value in [base + token + "?token=other", base + token + "#fragment", base + "%2F" + token,
                      base + "short", "https://app.kairoid.com/trust-invitations/" + token,
                      base.replacingOccurrences(of: "https:", with: "http:") + token] {
            XCTAssertNil(TrustInvitationPresentation.parse(try XCTUnwrap(URL(string: value)), allowedHosts: hosts))
        }
    }

    func testCanonicalInvitationUniversalLinkParsesOnlyOpaqueTokenOnWebsiteHost() throws {
        let token = String(repeating: "aB9_", count: 8)
        let parsed = TrustInvitationPresentation.parse(
            try XCTUnwrap(URL(string: "https://kairoid.com/invite/\(token)")),
            allowedHosts: ["kairoid.com"]
        )
        XCTAssertEqual(parsed?.token, token)
        XCTAssertNil(TrustInvitationPresentation.parse(
            try XCTUnwrap(URL(string: "https://kairoid.com/invite/\(token)?email=private@example.com")),
            allowedHosts: ["kairoid.com"]
        ))
    }

    func testCandidateInvitationAPIsUseAuthoritativeRoutesAndFinalizeOnlyShareIdentifier() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("synthetic-test-access", for: .accessToken)
        let configuration = AppConfiguration(buildConfiguration: .staging, environment: .staging, isDemoModeEnabled: false,
            apiBaseURL: URL(string: "https://synthetic.invalid/api/v1")!, keychainService: "unused-in-memory")
        let client = URLSessionNetworkClient(baseURL: configuration.apiBaseURL, session: makeMockedURLSession())
        let service = TrustInvitationService(publicClient: client, session: SessionService(configuration: configuration, networkClient: client, tokenStore: tokens))
        let invitation = Data(Self.candidateInvitationJSON.utf8)
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-test-access")
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/candidate/trust-invitations"):
                return (try Self.response(for: request), Data("[\(Self.candidateInvitationJSON)]".utf8))
            case ("GET", "/api/v1/candidate/trust-invitations/home-summary"):
                return (try Self.response(for: request), Data("{\"pending_invitation_count\":1,\"action_required_invitation_count\":1,\"latest_actionable_invitation\":\(Self.candidateInvitationJSON)}".utf8))
            case ("GET", "/api/v1/candidate/trust-invitations/invite-1"),
                 ("POST", "/api/v1/candidate/trust-invitations/invite-1/accept"),
                 ("POST", "/api/v1/candidate/trust-invitations/invite-1/decline"):
                return (try Self.response(for: request), invitation)
            case ("POST", "/api/v1/candidate/trust-invitations/invite-1/finalize"):
                let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBodyData(from: request)) as? [String: Any])
                XCTAssertEqual(body["passport_share_id"] as? String, "share-1")
                XCTAssertEqual(body["consent_version"] as? Int, 4)
                XCTAssertEqual(Set(body.keys), ["passport_share_id", "consent_version"])
                return (try Self.response(for: request), invitation)
            default:
                XCTFail("Unexpected invitation route")
                return (try Self.response(for: request, statusCode: 404), Data())
            }
        }

        let listed = try await service.listMine()
        let summary = try await service.homeSummary()
        let detail = try await service.readMine(id: "invite-1")
        XCTAssertEqual(listed.map(\.publicId), ["invite-1"])
        XCTAssertEqual(summary.latestActionableInvitation?.organizationName, "Synthetic Labs")
        XCTAssertEqual(detail.requirements.first?.mandatory, true)
        _ = try await service.acceptMine(id: "invite-1")
        _ = try await service.declineMine(id: "invite-1")
        _ = try await service.finalizeMine(id: "invite-1", shareID: "share-1", consentVersion: 4)
    }

    func testInvitationSharePermissionsLockMandatoryIncludeOnlyCompletedSelectedOptionalAndExcludeUnrelated() {
        let requirements = [
            CandidateTrustInvitationRequirement(requirementType: "identity", mandatory: true, status: "completed", action: nil),
            CandidateTrustInvitationRequirement(requirementType: "education", mandatory: false, status: "completed", action: nil),
            CandidateTrustInvitationRequirement(requirementType: "certification", mandatory: false, status: "pending", action: nil),
            CandidateTrustInvitationRequirement(requirementType: "permanent_address", mandatory: false, status: "completed", action: nil)
        ]

        let permissions = CandidateTrustInvitationSharing.permissions(
            for: requirements,
            selectedOptional: ["education", "certification", "permanent_address"]
        )

        XCTAssertTrue(permissions.includeProfile, "Mandatory identity remains locked into final consent")
        XCTAssertTrue(permissions.includeEducations, "A completed, explicitly selected optional section is included")
        XCTAssertFalse(permissions.includeCertifications, "Incomplete optional data cannot be shared")
        XCTAssertFalse(permissions.includeUserDocuments, "Unrelated requirements never widen Passport permissions")
    }

    func testEducationEvidenceDecodesOnlySafePreviewContract() throws {
        let education = try APIJSONCoder.makeDecoder().decode(
            CareerEducationDTO.self,
            from: Data(
                #"{"id":"education-1","institution_name":"Synthetic University","degree":"BSc","is_currently_studying":false,"verification_status":"verified","evidence":[{"evidence_id":"evidence-1","document_type":"degree_certificate","display_name":"Degree certificate","source":"digilocker","verification_status":"verified","verified_at":"2026-10-31T10:00:00Z","preview_available":true,"preview_type":"structured","content_type":null}]}"#.utf8
            )
        )
        XCTAssertEqual(education.evidence.first?.previewType, .structured)
        XCTAssertFalse(String(reflecting: education.evidence).contains("object_key"))
        let preview = try APIJSONCoder.makeDecoder().decode(
            EducationEvidencePreviewDTO.self,
            from: Data(#"{"evidence_id":"evidence-1","preview_type":"structured","content_type":null,"preview_url":null,"expires_in_seconds":null,"structured":{"document_type":"degree_certificate","issuer":"Synthetic University","qualification":"BSc","completion_year":2026,"verification_source":"digilocker","verified_at":"2026-10-31T10:00:00Z"}}"#.utf8)
        )
        XCTAssertEqual(preview.structured?.safeRows.first?.0, "Document type")
        XCTAssertFalse(String(reflecting: preview.structured?.safeRows).lowercased().contains("xml"))
    }

    func testHasPasswordDecodesFalseForFederatedAccount() throws {
        let dto = try APIJSONCoder.makeDecoder().decode(
            UserPublicDTO.self,
            from: Data(#"{"id":"user-1","email":"candidate@example.com","full_name":null,"role":"user","is_active":true,"has_password":false,"created_at":"2026-10-31T10:00:00Z"}"#.utf8)
        )
        XCTAssertFalse(dto.hasPassword)
        XCTAssertFalse(dto.asDomainModel().hasPassword)
    }

    func testInvitationDecodesCanonicalContractAndExpiryFailsClosed() throws {
        let json = #"{"public_id":"synthetic-invitation","organization_name":"Synthetic organization","subject_name":"Synthetic candidate","purpose":null,"requested_verification_types":["employment"],"expires_at":"2026-01-01T00:00:00Z","status":"pending"}"#
        let invitation = try APIJSONCoder.makeDecoder().decode(PublicTrustInvitation.self, from: Data(json.utf8))
        XCTAssertEqual(invitation.publicId, "synthetic-invitation")
        XCTAssertTrue(invitation.canAccept(at: invitation.expiresAt.addingTimeInterval(-1)))
        XCTAssertFalse(invitation.canAccept(at: invitation.expiresAt))
    }

    func testNotificationRoutesUseRequestIdentifiersNotInvitationCapabilities() throws {
        XCTAssertEqual(try destination("verification_invitation", metadata: ["verification_request_public_id": "request-1"]), .verificationRequest("request-1"))
        XCTAssertEqual(try destination("evidence_review", metadata: ["request_public_id": "request-2"]), .verificationRequest("request-2"))
        XCTAssertEqual(try destination("verification_invitation", metadata: ["trust_invitation_public_id": "not-a-token"]), .genericDetail)
        XCTAssertEqual(try destination("document_uploaded"), .documents)
        XCTAssertEqual(try destination("passport_share_viewed"), .sharing)
        XCTAssertEqual(try destination("passport_updated"), .passport)
        XCTAssertEqual(try destination("security_notice"), .settings)
        XCTAssertEqual(try destination("trust_score_updated"), .home)
        XCTAssertEqual(try destination("unknown_future_event"), .genericDetail)
    }

    private func destination(_ event: String, metadata: [String: String] = [:]) throws -> CandidateNotificationDestination {
        let data = try JSONSerialization.data(withJSONObject: ["public_id": "notification-fixture", "category": "system", "event_type": event, "title": "Synthetic update", "body": "Synthetic content", "metadata": metadata, "created_at": "2026-01-01T00:00:00Z"])
        return CandidateNotificationMapper.map(try APIJSONCoder.makeDecoder().decode(CandidateNotificationDTO.self, from: data)).destination
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int = 200) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
    }

    private nonisolated static let candidateInvitationJSON = #"{"public_id":"invite-1","organization_public_id":"organization-1","organization_name":"Synthetic Labs","role":"Engineer","purpose":"Hiring","message":null,"lifecycle_state":"available","requirements_version":4,"requirements":[{"requirement_type":"identity","mandatory":true,"status":"completed","action":null,"configuration":{}}],"completed_requirements":1,"required_requirements":1,"accepted_at":null,"declined_at":null,"completed_at":null,"expires_at":"2030-01-01T00:00:00Z","share_action":{"action":"OPEN_PASSPORT","label":"Share Passport with Synthetic Labs"}}"#
}
