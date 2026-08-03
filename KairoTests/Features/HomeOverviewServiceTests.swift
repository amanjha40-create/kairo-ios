import Foundation
import XCTest
@testable import Kairo

@MainActor
final class HomeOverviewServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadOverviewFetchesCurrentUserAndDashboardOverAuthenticatedRequests() async throws {
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
        let authService = AuthService(
            configuration: makeConfiguration(),
            networkClient: networkClient,
            sessionService: sessionService
        )
        let service = HomeOverviewService(
            authService: authService,
            sessionService: sessionService
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")

            switch request.url?.path {
            case "/api/v1/users/me":
                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )),
                    Self.userPayload
                )
            case "/api/v1/dashboard":
                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )),
                    Self.dashboardPayload
                )
            default:
                XCTFail("Unexpected request path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.loadOverview()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(Set(requests.compactMap(\.url?.path)), ["/api/v1/users/me", "/api/v1/dashboard"])
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(overview.user.email, "aarav@example.com")
        XCTAssertEqual(overview.trustScore.overall, 78)
        XCTAssertEqual(overview.profileCompletion.nextRecommendedStep, "employment")
        XCTAssertEqual(overview.recentShareAnalytics.first?.totalViews, 3)
        XCTAssertEqual(overview.recentActivity.first?.category, .verification)
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.home"
        )
    }

    private static let userPayload = Data(
        """
        {
          "id": "user_123",
          "email": "aarav@example.com",
          "full_name": "Aarav Mehta",
          "profile_slug": "aarav-mehta",
          "phone": "+919876543210",
          "current_role": "People Operations Lead",
          "industry": "Technology",
          "years_of_experience": 6,
          "location": "Bengaluru, India",
          "location_city": "Bengaluru",
          "location_region": "Karnataka",
          "location_country": "India",
          "headline": "People Operations Lead",
          "bio": "Building verified professional trust.",
          "role": "user",
          "is_active": true,
          "profile_completion_percentage": 70,
          "created_at": "2026-07-30T08:00:00Z"
        }
        """.utf8
    )

    private static let dashboardPayload = Data(
        """
        {
          "profile_completion": {
            "current_step": "complete_profile",
            "email_verified": true,
            "phone_verified": true,
            "passport_ready": false,
            "completed_steps": ["verify_email", "verify_phone"],
            "missing_requirements": ["employment", "education"],
            "next_recommended_step": "employment",
            "completion_percentage": 70,
            "is_onboarding_complete": false
          },
          "trust_score": {
            "overall": 78,
            "status": "calculated",
            "positive_contributors": [
              {
                "code": "verified_employment",
                "label": "Verified employment",
                "points": 22.5,
                "detail": "Your current role has been verified."
              }
            ],
            "negative_contributors": [],
            "critical_overrides": [],
            "verification_completeness_percentage": 72,
            "week_change": 4
          },
          "verification_summary": {
            "overall": {
              "total": 4,
              "statuses": {
                "verified": 2,
                "pending": 1,
                "not_verified": 1
              }
            },
            "employments": {
              "total": 2,
              "statuses": {
                "verified": 1,
                "pending": 1
              }
            },
            "educations": {
              "total": 1,
              "statuses": {
                "verified": 1
              }
            }
          },
          "vault_summary": {
            "total_items": 6,
            "employments": 2,
            "educations": 1,
            "internships": 0,
            "freelance": 0,
            "gig_platforms": 0,
            "portfolio": 0,
            "certifications": 1,
            "user_documents": 2
          },
          "active_passport_shares": {
            "count": 1,
            "items": [
              {
                "share_id": "share_123",
                "label": "Northstar Labs",
                "state": "active",
                "expires_at": "2026-08-10T10:00:00Z",
                "last_viewed_at": "2026-08-01T11:45:00Z",
                "created_at": "2026-07-30T08:00:00Z"
              }
            ]
          },
          "recent_share_analytics": [
            {
              "share_id": "share_123",
              "label": "Northstar Labs",
              "state": "active",
              "total_views": 3,
              "unique_views": 2,
              "last_viewed_at": "2026-08-01T11:45:00Z"
            }
          ],
          "recent_activity": [
            {
              "occurred_at": "2026-08-01T12:15:00Z",
              "category": "verification",
              "action": "awaiting_approval",
              "title": "Employment verification",
              "detail": "Northstar Labs",
              "subject_id": "employment_123"
            }
          ]
        }
        """.utf8
    )
}
