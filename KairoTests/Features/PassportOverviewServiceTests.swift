import Foundation
import XCTest
@testable import Kairo

@MainActor
final class PassportOverviewServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadOverviewFetchesOwnerPassportOverAuthenticatedRequest() async throws {
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
        let service = PassportOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/passport/me")

            return (try Self.response(for: request, statusCode: 200), Self.ownerPassportPayload)
        }

        let overview = try await service.loadOverview()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.url?.path, "/api/v1/passport/me")
        XCTAssertEqual(overview.user.email, "aarav@example.com")
        XCTAssertEqual(overview.vault.employments.first?.company, "Northline Career Services")
        XCTAssertEqual(overview.vault.educations.first?.institution, "Christ University")
        XCTAssertTrue(overview.vault.certifications.isEmpty)
        XCTAssertTrue(overview.vault.projects.isEmpty)
        XCTAssertEqual(overview.verificationSummary.projects.total, 0)
    }

    func test_loadOverviewSurfacesDecodeErrorForInvalidPassportPayload() async throws {
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
        let service = PassportOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(for: request, statusCode: 200), Data("{\"profile\":{}}".utf8))
        }

        do {
            _ = try await service.loadOverview()
            XCTFail("Expected loadOverview to throw a decoding error")
        } catch is DecodingError {
        } catch {
            XCTFail("Expected DecodingError, received \(error)")
        }
    }

    func test_loadOverviewCanRetryAfterTransportFailure() async throws {
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
        let service = PassportOverviewService(sessionService: sessionService)

        let failureGate = PassportFailureGate()
        await MockURLProtocolStorage.shared.setHandler { request in
            if await failureGate.consumeFirstFailure() {
                throw URLError(.notConnectedToInternet)
            }

            return (try Self.response(for: request, statusCode: 200), Self.ownerPassportPayload)
        }

        do {
            _ = try await service.loadOverview()
            XCTFail("Expected first loadOverview attempt to fail")
        } catch let error as NetworkError {
            guard case .transport = error else {
                return XCTFail("Expected transport error, received \(error)")
            }
        }

        let overview = try await service.loadOverview()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(requests.filter { $0.url?.path == "/api/v1/passport/me" }.count, 2)
        XCTAssertEqual(overview.user.email, "aarav@example.com")
    }

    func test_loadOverviewDecodesSparseLiveShapedPassportPayload() async throws {
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
        let service = PassportOverviewService(sessionService: sessionService)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/passport/me")
            return (try Self.response(for: request, statusCode: 200), Self.sparseOwnerPassportPayload)
        }

        let overview = try await service.loadOverview()

        XCTAssertEqual(overview.metadata.ownerUserId, "user_sparse_123")
        XCTAssertNil(overview.trustScore.overall)
        XCTAssertEqual(overview.vault.certifications, [])
        XCTAssertEqual(overview.vault.projects, [])
        XCTAssertEqual(overview.vault.userDocuments, [])
        XCTAssertEqual(overview.verificationSummary.skills.total, 1)
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.passport"
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

    private nonisolated static let ownerPassportPayload = Data(
        """
        {
          "profile": {
            "id": "user_123",
            "email": "aarav@example.com",
            "full_name": "Aarav Mehta",
            "profile_slug": "aarav-mehta",
            "phone": "+919876543210",
            "current_role": "Trust Operations Lead",
            "location": "Bengaluru, India",
            "location_city": "Bengaluru",
            "location_country": "India",
            "headline": "Trust Operations Lead",
            "role": "user",
            "is_active": true,
            "phone_verified_at": "2026-08-01T10:15:30Z",
            "email_verified_at": "2026-08-01T10:14:10Z",
            "employment_onboarding_completed_at": "2026-08-01T10:20:00Z",
            "languages": [],
            "professional_links": [],
            "profile_completion_percentage": 100,
            "created_at": "2026-07-30T08:00:00Z"
          },
          "trust_score": {
            "overall": 81,
            "breakdown": {
              "identity": 1.0,
              "employment": 0.75,
              "education": 0.5
            },
            "domain_details": {},
            "status": "calculated",
            "positive_contributors": [],
            "negative_contributors": [],
            "critical_overrides": [],
            "manual_review_reason": null,
            "score_version": "v1",
            "last_calculated_at": "2026-08-02T07:00:00Z",
            "verification_completeness_percentage": 68,
            "week_change": 4
          },
          "vault": {
            "employments": [
              {
                "id": "employment_1",
                "employer_legal_name": "Northline Career Services",
                "job_title": "Trust Operations Associate",
                "start_date": "2024-01-01",
                "end_date": null,
                "verification_status": "verified",
                "verification_method": "document_review",
                "documents": [
                  {
                    "id": "document_1",
                    "document_type": "employment_letter",
                    "original_filename": "employment-letter.pdf",
                    "byte_size": 152000,
                    "verification_status": "verified"
                  }
                ]
              }
            ],
            "educations": [
              {
                "id": "education_1",
                "institution_name": "Christ University",
                "degree": "BBA",
                "field_of_study": "Human Resources & Operations",
                "education_level": "bachelors",
                "grade": null,
                "start_date": "2016-06-01",
                "start_date_precision": "month",
                "end_date": "2019-05-01",
                "end_date_precision": "month",
                "is_currently_studying": false,
                "verification_status": "verified"
              }
            ],
            "internships": [],
            "freelance": [],
            "gig_platforms": [],
            "portfolio": [],
            "certifications": [],
            "skills": [
              {
                "name": "Trust Operations",
                "verification_status": "verified"
              }
            ],
            "projects": [],
            "user_documents": []
          },
          "passport_metadata": {
            "owner_user_id": "user_123",
            "profile_slug": "aarav-mehta",
            "is_email_verified": true,
            "is_onboarding_complete": true,
            "created_at": "2026-07-30T08:00:00Z",
            "updated_at": "2026-08-02T07:00:00Z",
            "employment_onboarding_completed_at": "2026-08-01T10:20:00Z"
          },
          "sharing_summary": {
            "total_links": 0,
            "active_links": 0,
            "revoked_links": 0,
            "expired_links": 0,
            "total_views": 0,
            "unique_views": 0,
            "latest_share_created_at": null,
            "last_viewed_at": null
          },
          "verification_summary": {
            "overall": { "total": 2, "statuses": { "verified": 2 } },
            "employments": { "total": 1, "statuses": { "verified": 1 } },
            "educations": { "total": 1, "statuses": { "verified": 1 } },
            "internships": { "total": 0, "statuses": {} },
            "freelance": { "total": 0, "statuses": {} },
            "gig_platforms": { "total": 0, "statuses": {} },
            "portfolio": { "total": 0, "statuses": {} },
            "certifications": { "total": 0, "statuses": {} },
            "skills": { "total": 1, "statuses": { "verified": 1 } },
            "projects": { "total": 0, "statuses": {} },
            "user_documents": { "total": 0, "statuses": {} }
          }
        }
        """.utf8
    )

    private nonisolated static let sparseOwnerPassportPayload = Data(
        """
        {
          "profile": {
            "id": "user_sparse_123",
            "email": "candidate@example.com",
            "full_name": "Candidate Example",
            "profile_slug": "candidate-example",
            "phone": "+919876543210",
            "current_role": null,
            "industry": null,
            "years_of_experience": null,
            "location": "Mumbai, Maharashtra, India",
            "location_city": null,
            "location_region": null,
            "location_country": null,
            "headline": "Corporate development professional",
            "bio": null,
            "date_of_birth": null,
            "avatar_url": null,
            "role": "user",
            "is_active": true,
            "phone_verified_at": "2026-08-01T10:15:30Z",
            "email_verified_at": "2026-08-01T10:14:10Z",
            "employment_onboarding_completed_at": "2026-08-01T10:20:00Z",
            "languages": [],
            "professional_links": [],
            "profile_completion_percentage": 100,
            "created_at": "2026-07-30T08:00:00Z"
          },
          "trust_score": {
            "status": "incomplete_verification",
            "positive_contributors": [],
            "negative_contributors": [],
            "critical_overrides": [],
            "manual_review_reason": null,
            "score_version": "v1",
            "last_calculated_at": null,
            "verification_completeness_percentage": 30,
            "week_change": 0
          },
          "vault": {
            "employments": [
              {
                "id": "employment_sparse_1",
                "employer_legal_name": "Example Capital",
                "job_title": "Analyst",
                "start_date": null,
                "end_date": null,
                "verification_status": "pending_verification",
                "verification_method": "document_review",
                "documents": []
              }
            ],
            "educations": [
              {
                "id": "education_sparse_1",
                "institution_name": "Example University",
                "degree": "BBA",
                "field_of_study": null,
                "education_level": null,
                "grade": null,
                "start_date": null,
                "start_date_precision": null,
                "end_date": null,
                "end_date_precision": null,
                "is_currently_studying": false,
                "verification_status": "verified"
              }
            ],
            "internships": [],
            "freelance": [],
            "gig_platforms": [],
            "portfolio": [],
            "certifications": [],
            "skills": [
              {
                "name": "Financial Analysis",
                "verification_status": "verified"
              }
            ],
            "projects": [],
            "user_documents": []
          },
          "passport_metadata": {
            "owner_user_id": "user_sparse_123",
            "profile_slug": "candidate-example",
            "is_email_verified": true,
            "is_onboarding_complete": true,
            "created_at": "2026-07-30T08:00:00Z",
            "updated_at": "2026-08-02T07:00:00Z",
            "employment_onboarding_completed_at": "2026-08-01T10:20:00Z"
          },
          "sharing_summary": {
            "total_links": 0,
            "active_links": 0,
            "revoked_links": 0,
            "expired_links": 0,
            "total_views": 0,
            "unique_views": 0,
            "latest_share_created_at": null,
            "last_viewed_at": null
          },
          "verification_summary": {
            "overall": { "total": 2, "statuses": { "verified": 1, "pending_verification": 1 } },
            "employments": { "total": 1, "statuses": { "pending_verification": 1 } },
            "educations": { "total": 1, "statuses": { "verified": 1 } },
            "internships": { "total": 0, "statuses": {} },
            "freelance": { "total": 0, "statuses": {} },
            "gig_platforms": { "total": 0, "statuses": {} },
            "portfolio": { "total": 0, "statuses": {} },
            "certifications": { "total": 0, "statuses": {} },
            "skills": { "total": 1, "statuses": { "verified": 1 } },
            "projects": { "total": 0, "statuses": {} },
            "user_documents": { "total": 0, "statuses": {} }
          }
        }
        """.utf8
    )
}

private actor PassportFailureGate {
    private var shouldFail = true

    func consumeFirstFailure() -> Bool {
        if shouldFail {
            shouldFail = false
            return true
        }

        return false
    }
}
