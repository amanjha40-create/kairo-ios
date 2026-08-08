import Foundation
import XCTest
@testable import Kairo

@MainActor
final class VerifyOverviewServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadOverviewFetchesListDetailAndTimelineOverAuthenticatedRequests() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let service = VerifyOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/verification-requests/me":
                return (try Self.response(for: request, statusCode: 200), Self.requestListPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/request_1":
                return (try Self.response(for: request, statusCode: 200), Self.requestDetailPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/request_1/timeline":
                return (try Self.response(for: request, statusCode: 200), Self.requestTimelinePayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(
            Set(requests.compactMap(\.url?.path)),
            [
                "/api/v1/verification-requests/me",
                "/api/v1/verification-requests/request_1",
                "/api/v1/verification-requests/request_1/timeline"
            ]
        )
        XCTAssertEqual(overview.requests.count, 1)
        XCTAssertEqual(overview.requests.first?.organizationName, "BrightPath Technologies")
        XCTAssertEqual(overview.requests.first?.status, .pendingSubjectAcceptance)
        XCTAssertEqual(overview.requests.first?.timeline.first?.newStatus, .pendingSubjectAcceptance)
    }

    func test_loadOverviewAcceptsPageEnvelopeForRequestList() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let service = VerifyOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/verification-requests/me":
                return (try Self.response(for: request, statusCode: 200), Self.requestListEnvelopePayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/request_1":
                return (try Self.response(for: request, statusCode: 200), Self.requestDetailPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/request_1/timeline":
                return (try Self.response(for: request, statusCode: 200), Self.requestTimelinePayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()

        XCTAssertEqual(overview.requests.count, 1)
        XCTAssertEqual(overview.requests.first?.id, "request_1")
    }

    func test_loadOverviewKeepsLegacyListItemsWithoutRoutablePublicID() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let service = VerifyOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/verification-requests/me":
                return (try Self.response(for: request, statusCode: 200), Self.requestListWithLegacyBlankIDPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/request_1":
                return (try Self.response(for: request, statusCode: 200), Self.requestDetailPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/request_1/timeline":
                return (try Self.response(for: request, statusCode: 200), Self.requestTimelinePayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()
        let paths = await MockURLProtocolStorage.shared.requests().compactMap(\.url?.path)

        XCTAssertEqual(paths, [
            "/api/v1/verification-requests/me",
            "/api/v1/verification-requests/request_1",
            "/api/v1/verification-requests/request_1/timeline"
        ])
        XCTAssertEqual(overview.requests.count, 2)

        let detailedRequest = try XCTUnwrap(overview.requests.first(where: { $0.id == "request_1" }))
        XCTAssertEqual(detailedRequest.routeID, "request_1")

        let legacyRequest = try XCTUnwrap(overview.requests.first(where: { $0.id == "verify-list-0" }))
        XCTAssertNil(legacyRequest.routeID)
        XCTAssertEqual(legacyRequest.organizationName, "Archive University")
        XCTAssertEqual(legacyRequest.status, .pendingSubjectSubmission)
    }

    func test_loadOverviewUsesTrustInvitationPublicIDAsRoutingFallback() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let service = VerifyOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/verification-requests/me":
                return (try Self.response(for: request, statusCode: 200), Self.requestListWithFallbackRoutingPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/invite_123":
                return (try Self.response(for: request, statusCode: 200), Self.requestDetailWithFallbackRoutingPayload)
            case "https://staging-api.kairoid.com/api/v1/verification-requests/invite_123/timeline":
                return (try Self.response(for: request, statusCode: 200), Self.requestTimelineForFallbackRoutingPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()
        let paths = await MockURLProtocolStorage.shared.requests().compactMap(\.url?.path)

        XCTAssertEqual(paths, [
            "/api/v1/verification-requests/me",
            "/api/v1/verification-requests/invite_123",
            "/api/v1/verification-requests/invite_123/timeline"
        ])
        XCTAssertEqual(overview.requests.count, 1)
        XCTAssertEqual(overview.requests.first?.id, "invite_123")
        XCTAssertEqual(overview.requests.first?.routeID, "invite_123")
        XCTAssertEqual(overview.requests.first?.timeline.first?.id, "timeline_invite_1")
    }

    func test_performActionSubmitsInformationBody() async throws {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)

        let networkClient = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        let service = VerifyOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/verification-requests/request_1/submit-information")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(request.httpBody)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(json["response"] as? String, "Updated employer contact")
            return (try Self.response(for: request, statusCode: 200), Self.requestDetailPayload)
        }

        try await service.performAction(
            requestID: "request_1",
            action: .submitInformation,
            response: "Updated employer contact"
        )

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.verify"
        )
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }

    private nonisolated static let requestListPayload = Data(
        """
        [
          {
            "public_id": "request_1",
            "subject_name": "Aman Jha",
            "subject_email": "aman@example.com",
            "target_organization_name": "BrightPath Technologies",
            "request_type": "employment",
            "status": "pending_subject_acceptance",
            "priority": "high",
            "created_at": "2026-08-08T08:00:00Z",
            "updated_at": "2026-08-08T09:00:00Z",
            "consented_fields": [],
            "consented_evidence_scope": [],
            "evidence_summary": {
              "total_items": 0,
              "document_items": 0,
              "field_keys": []
            }
          }
        ]
        """.utf8
    )

    private nonisolated static let requestListEnvelopePayload = Data(
        """
        {
          "items": [
            {
              "public_id": "request_1",
              "subject_name": "Aman Jha",
              "subject_email": "aman@example.com",
              "target_organization_name": "BrightPath Technologies",
              "request_type": "employment",
              "status": "pending_subject_acceptance",
              "priority": "high",
              "created_at": "2026-08-08T08:00:00Z",
              "updated_at": "2026-08-08T09:00:00Z",
              "consented_fields": [],
              "consented_evidence_scope": [],
              "evidence_summary": {
                "total_items": 0,
                "document_items": 0,
                "field_keys": []
              }
            }
          ]
        }
        """.utf8
    )

    private nonisolated static let requestListWithLegacyBlankIDPayload = Data(
        """
        [
          {
            "public_id": "   ",
            "subject_name": "Legacy Candidate",
            "target_organization_name": "Archive University",
            "request_type": "education",
            "status": "pending_subject_submission",
            "priority": "normal",
            "created_at": "2026-08-07T08:00:00Z",
            "updated_at": "2026-08-07T09:00:00Z",
            "consented_fields": [],
            "consented_evidence_scope": [],
            "evidence_summary": {
              "total_items": 0,
              "document_items": 0,
              "field_keys": []
            }
          },
          {
            "public_id": "request_1",
            "subject_name": "Aman Jha",
            "subject_email": "aman@example.com",
            "target_organization_name": "BrightPath Technologies",
            "request_type": "employment",
            "status": "pending_subject_acceptance",
            "priority": "high",
            "created_at": "2026-08-08T08:00:00Z",
            "updated_at": "2026-08-08T09:00:00Z",
            "consented_fields": [],
            "consented_evidence_scope": [],
            "evidence_summary": {
              "total_items": 0,
              "document_items": 0,
              "field_keys": []
            }
          }
        ]
        """.utf8
    )

    private nonisolated static let requestListWithFallbackRoutingPayload = Data(
        """
        [
          {
            "public_id": "   ",
            "trust_invitation_public_id": "invite_123",
            "subject_name": "Legacy Candidate",
            "subject_email": "legacy@example.com",
            "target_organization_name": "Keiretsu Forum Northwest",
            "request_type": "employment",
            "status": "pending_subject_acceptance",
            "priority": "high",
            "created_at": "2026-08-08T08:00:00Z",
            "updated_at": "2026-08-08T09:00:00Z",
            "consented_fields": [],
            "consented_evidence_scope": [],
            "evidence_summary": {
              "total_items": 0,
              "document_items": 0,
              "field_keys": []
            }
          }
        ]
        """.utf8
    )

    private nonisolated static let requestDetailPayload = Data(
        """
        {
          "public_id": "request_1",
          "employment_id": "employment_1",
          "subject_name": "Aman Jha",
          "subject_email": "aman@example.com",
          "target_organization_name": "BrightPath Technologies",
          "target_organization_email": "hr@brightpath.example.com",
          "request_type": "employment",
          "status": "pending_subject_acceptance",
          "priority": "high",
          "due_date": "2026-08-12",
          "created_at": "2026-08-08T08:00:00Z",
          "updated_at": "2026-08-08T09:00:00Z",
          "candidate_response": null,
          "candidate_response_submitted_at": null,
          "accepted_at": null,
          "consented_fields": ["employment_dates"],
          "consented_evidence_scope": ["employment_letter"],
          "organization_summary": {
            "public_id": "org_1",
            "name": "BrightPath Technologies"
          },
          "verification_target": {
            "organization_name": "BrightPath Technologies",
            "organization_email": "hr@brightpath.example.com"
          },
          "employment_claim": {
            "employer_name": "BrightPath Technologies",
            "role": "Product Operations Manager",
            "start_date": "2025-01-01",
            "end_date": null,
            "employment_type": "full_time",
            "work_location_country": "India",
            "work_location_region": "Karnataka"
          },
          "evidence_summary": {
            "total_items": 1,
            "document_items": 1,
            "field_keys": ["employment_letter"]
          }
        }
        """.utf8
    )

    private nonisolated static let requestDetailWithFallbackRoutingPayload = Data(
        """
        {
          "public_id": "   ",
          "trust_invitation_public_id": "invite_123",
          "subject_name": "Legacy Candidate",
          "subject_email": "legacy@example.com",
          "target_organization_name": "Keiretsu Forum Northwest",
          "target_organization_email": "verifications@keiretsu.example.com",
          "request_type": "employment",
          "status": "pending_subject_acceptance",
          "priority": "high",
          "due_date": "2026-08-12",
          "created_at": "2026-08-08T08:00:00Z",
          "updated_at": "2026-08-08T09:00:00Z",
          "candidate_response": null,
          "candidate_response_submitted_at": null,
          "accepted_at": null,
          "consented_fields": ["employment_dates"],
          "consented_evidence_scope": ["employment_letter"],
          "organization_summary": {
            "public_id": "org_1",
            "name": "Keiretsu Forum Northwest"
          },
          "verification_target": {
            "organization_name": "Keiretsu Forum Northwest",
            "organization_email": "verifications@keiretsu.example.com"
          },
          "employment_claim": {
            "employer_name": "Keiretsu Forum Northwest",
            "role": "Associate",
            "start_date": "2025-01-01",
            "end_date": null,
            "employment_type": "full_time",
            "work_location_country": "India",
            "work_location_region": "Karnataka"
          },
          "evidence_summary": {
            "total_items": 1,
            "document_items": 1,
            "field_keys": ["employment_letter"]
          }
        }
        """.utf8
    )

    private nonisolated static let requestTimelinePayload = Data(
        """
        {
          "verification_request_public_id": "request_1",
          "items": [
            {
              "public_id": "timeline_1",
              "event_type": "verification_requested",
              "event_source": "organization",
              "previous_status": null,
              "new_status": "pending_subject_acceptance",
              "metadata": {},
              "created_at": "2026-08-08T08:00:00Z"
            }
          ],
          "total": 1,
          "page": 1,
          "page_size": 50,
          "total_pages": 1,
          "offset": 0,
          "limit": 50
        }
        """.utf8
    )

    private nonisolated static let requestTimelineForFallbackRoutingPayload = Data(
        """
        {
          "verification_request_public_id": "invite_123",
          "items": [
            {
              "public_id": "timeline_invite_1",
              "event_type": "verification_requested",
              "event_source": "organization",
              "previous_status": null,
              "new_status": "pending_subject_acceptance",
              "created_at": "2026-08-08T08:00:00Z"
            }
          ],
          "total": 1,
          "page": 1,
          "page_size": 50,
          "total_pages": 1,
          "offset": 0,
          "limit": 50
        }
        """.utf8
    )
}
