import Foundation
import XCTest
@testable import Kairo

@MainActor
final class TrustScoreServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadScoreDecodesBackendOwnedValueAndBreakdown() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/trust-score")
            return (try Self.response(for: request, statusCode: 200), Self.scorePayload)
        }

        let score = try await service.loadScore()

        XCTAssertEqual(score.overall, 72)
        XCTAssertEqual(score.status, .incompleteVerification)
        XCTAssertEqual(score.breakdown?.identity, 85)
        XCTAssertEqual(score.breakdown?.employment, 70)
        XCTAssertEqual(score.breakdown?.education, 60)
        XCTAssertEqual(score.positiveContributors.first?.label, "Email verified")
    }

    func test_grantConsentPostsVersionThenReloadsAuthoritativeScore() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.httpMethod == "POST" {
                XCTAssertEqual(request.url?.path, "/api/v1/trust-score/consent")
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(payload, ["consent_version": "v1"])
                return (try Self.response(for: request, statusCode: 204), Data())
            }
            XCTAssertEqual(request.url?.path, "/api/v1/trust-score")
            return (try Self.response(for: request, statusCode: 200), Self.scorePayload)
        }

        let score = try await service.grantConsent(version: "v1")
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(score.overall, 72)
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "GET"])
    }

    func test_withdrawConsentDeletesThenReloadsConsentRequiredState() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.httpMethod == "DELETE" {
                XCTAssertEqual(request.url?.path, "/api/v1/trust-score/consent")
                return (try Self.response(for: request, statusCode: 204), Data())
            }
            return (try Self.response(for: request, statusCode: 200), Self.consentRequiredPayload)
        }

        let score = try await service.withdrawConsent()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertNil(score.overall)
        XCTAssertEqual(score.status, .consentRequired)
        XCTAssertEqual(requests.map(\.httpMethod), ["DELETE", "GET"])
    }

    func test_demoServiceIsDeterministicAndDoesNotUseNetwork() async throws {
        let service = DemoTrustScoreService()
        let initial = try await service.loadScore()
        let withdrawn = try await service.withdrawConsent()
        let restored = try await service.grantConsent(version: "v1")

        XCTAssertEqual(initial.overall, 72)
        XCTAssertEqual(withdrawn.status, .consentRequired)
        XCTAssertNil(withdrawn.overall)
        XCTAssertEqual(restored.overall, 72)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 0)
    }

    private func makeService() async throws -> TrustScoreService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        let client = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.trust-score"
        )
        return TrustScoreService(
            sessionService: SessionService(
                configuration: configuration,
                networkClient: client,
                tokenStore: tokenStore
            )
        )
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: statusCode, httpVersion: nil, headerFields: nil))
    }

    private nonisolated static let scorePayload = Data(
        """
        {
          "overall": 72,
          "breakdown": {"identity": 85, "employment": 70, "education": 60},
          "status": "incomplete_verification",
          "positive_contributors": [{"code":"email_verified","label":"Email verified","points":15,"detail":"Email verification is complete."}],
          "negative_contributors": [],
          "critical_overrides": [],
          "manual_review_reason": "Mandatory verification checks remain incomplete.",
          "score_version": "v1",
          "last_calculated_at": "2026-08-01T10:00:00Z",
          "verification_completeness_percentage": 72,
          "week_change": 0
        }
        """.utf8
    )

    private nonisolated static let consentRequiredPayload = Data(
        """
        {
          "overall": null,
          "breakdown": null,
          "status": "consent_required",
          "positive_contributors": [],
          "negative_contributors": [],
          "critical_overrides": [],
          "manual_review_reason": "Explicit Trust Score consent is required before screening starts.",
          "score_version": "v1",
          "last_calculated_at": "2026-08-01T10:00:00Z",
          "verification_completeness_percentage": 0,
          "week_change": 0
        }
        """.utf8
    )
}
