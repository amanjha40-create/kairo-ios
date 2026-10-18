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
}
