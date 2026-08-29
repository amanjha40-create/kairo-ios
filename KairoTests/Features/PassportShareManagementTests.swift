import Foundation
import XCTest
@testable import Kairo

@MainActor
final class PassportShareManagementTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_listSharesDecodesPageAndAllBackendLifecycleStates() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/passport-shares")
            XCTAssertEqual(Self.queryValue("offset", request), "0")
            XCTAssertEqual(Self.queryValue("limit", request), "100")
            return (
                try Self.response(request, 200),
                Self.pagePayload(items: [
                    Self.sharePayload(id: "00000000-0000-0000-0000-000000000001", state: "active"),
                    Self.sharePayload(id: "00000000-0000-0000-0000-000000000002", state: "expired"),
                    Self.sharePayload(id: "00000000-0000-0000-0000-000000000003", state: "revoked")
                ])
            )
        }

        let shares = try await service.listShares()

        XCTAssertEqual(shares.map(\.state), [.active, .expired, .revoked])
        XCTAssertEqual(shares.first?.permissions.includeEmployments, true)
        XCTAssertEqual(shares.first?.permissions.includeUserDocuments, false)
        XCTAssertEqual(shares.first?.lastViewedAt, Self.date("2030-01-02T12:00:00Z"))
    }

    func test_shareDetailAndAnalyticsDecodeAcronymBackedKeysWithProductionDecoder() async throws {
        let service = try await makeService()
        let shareID = "00000000-0000-0000-0000-000000000011"

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.path {
            case "/api/v1/passport-shares/\(shareID)":
                return (try Self.response(request, 200), Self.sharePayload(id: shareID, state: "active"))
            case "/api/v1/passport-shares/\(shareID)/analytics":
                return (
                    try Self.response(request, 200),
                    Data(
                        """
                        {
                          "share_id": "\(shareID)",
                          "total_views": 7,
                          "unique_views": 5,
                          "last_viewed_at": "2030-01-02T12:00:00Z",
                          "recent_views": [{
                            "viewed_at": "2030-01-02T12:00:00Z",
                            "user_agent": null,
                            "referrer": null,
                            "is_unique_view": true
                          }]
                        }
                        """.utf8
                    )
                )
            default:
                XCTFail("Unexpected path: \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let share = try await service.getShare(id: shareID)
        let analytics = try await service.getAnalytics(shareID: shareID)

        XCTAssertEqual(share.id, shareID)
        XCTAssertEqual(analytics.shareID, shareID)
        XCTAssertEqual(analytics.totalViews, 7)
        XCTAssertEqual(analytics.uniqueViews, 5)
    }

    func test_createEncodesExactPermissionAndExpiryContractAndMapsAuthoritativeURL() async throws {
        let service = try await makeService()
        let shareID = "00000000-0000-0000-0000-000000000021"
        let expiry = Self.date("2030-03-04T05:06:07Z")
        var permissions = PassportSharePermissions.privacyPreserving
        permissions.includeEmployments = true
        permissions.includeEducations = true
        permissions.showEmployerNames = true
        permissions.showTrustScore = true
        let input = PassportShareMutationInput(
            label: "Recruiter access",
            permissions: permissions,
            expiresAt: expiry
        )

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/passport-shares")
            let body = try requestJSONBody(from: request)
            XCTAssertEqual(Set(body.keys), ["label", "expires_at", "track_views", "permissions"])
            XCTAssertEqual(body["label"] as? String, "Recruiter access")
            XCTAssertEqual(body["track_views"] as? Bool, true)
            XCTAssertTrue((body["expires_at"] as? String)?.hasPrefix("2030-03-04T05:06:07") == true)

            let encodedPermissions = try XCTUnwrap(body["permissions"] as? [String: Any])
            XCTAssertEqual(Set(encodedPermissions.keys), Self.permissionKeys)
            XCTAssertEqual(encodedPermissions["include_employments"] as? Bool, true)
            XCTAssertEqual(encodedPermissions["include_educations"] as? Bool, true)
            XCTAssertEqual(encodedPermissions["include_user_documents"] as? Bool, false)
            XCTAssertEqual(encodedPermissions["show_employer_names"] as? Bool, true)
            XCTAssertEqual(encodedPermissions["show_trust_score"] as? Bool, true)
            XCTAssertNil(encodedPermissions["show_trust_s_core"])

            return (
                try Self.response(request, 201),
                Self.createPayload(
                    id: shareID,
                    shareURL: "https://d3kpvsn9kfajzc.cloudfront.net/passport/public-token-value"
                )
            )
        }

        let created = try await service.createShare(input)

        XCTAssertEqual(created.share.id, shareID)
        XCTAssertEqual(
            created.publicURL.absoluteString,
            "https://d3kpvsn9kfajzc.cloudfront.net/passport/public-token-value"
        )
    }

    func test_noExpiryIsEncodedAsExplicitNull() throws {
        let request = PassportShareCreateRequestDTO(
            input: PassportShareMutationInput(
                label: nil,
                permissions: .privacyPreserving,
                expiresAt: nil
            )
        )
        let data = try APIJSONCoder.makeEncoder().encode(request)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertTrue(json["expires_at"] is NSNull)
        XCTAssertTrue(json["label"] is NSNull)
        XCTAssertEqual(json["track_views"] as? Bool, true)
    }

    func test_updateClearsExpiryAndRefetchesAuthoritativeDetail() async throws {
        let service = try await makeService()
        let shareID = "00000000-0000-0000-0000-000000000031"

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("PATCH", "/api/v1/passport-shares/\(shareID)"):
                let body = try requestJSONBody(from: request)
                XCTAssertTrue(body["expires_at"] is NSNull)
                XCTAssertTrue(body["label"] is NSNull)
                XCTAssertNotNil(body["permissions"])
                XCTAssertNil(body["track_views"])
                return (try Self.response(request, 200), Self.sharePayload(id: shareID, state: "active"))
            case ("GET", "/api/v1/passport-shares/\(shareID)"):
                return (
                    try Self.response(request, 200),
                    Self.sharePayload(id: shareID, state: "active", label: nil, expiresAt: nil)
                )
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let updated = try await service.updateShare(
            id: shareID,
            input: PassportShareMutationInput(
                label: nil,
                permissions: .privacyPreserving,
                expiresAt: nil
            )
        )
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertNil(updated.expiresAt)
        XCTAssertEqual(requests.map(\.httpMethod), ["PATCH", "GET"])
    }

    func test_revokePostsThenRefetchesAuthoritativeRevokedState() async throws {
        let service = try await makeService()
        let shareID = "00000000-0000-0000-0000-000000000041"

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/passport-shares/\(shareID)/revoke"):
                XCTAssertNil(request.httpBody)
                return (try Self.response(request, 200), Self.sharePayload(id: shareID, state: "revoked"))
            case ("GET", "/api/v1/passport-shares/\(shareID)"):
                return (try Self.response(request, 200), Self.sharePayload(id: shareID, state: "revoked"))
            default:
                XCTFail("Unexpected request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let revoked = try await service.revokeShare(id: shareID)
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(revoked.state, .revoked)
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "GET"])
    }

    func test_validationFailureCreatesNoFakeLocalShare() async throws {
        let service = try await makeService()
        let model = PassportShareCreateViewModel(service: service)

        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try Self.response(request, 422),
                Data(
                    """
                    {"code":"validation_error","message":"Invalid permissions","details":[{"location":["body","permissions"],"message":"Unsupported permission","error_type":"value_error"}]}
                    """.utf8
                )
            )
        }

        let succeeded = await model.create()

        XCTAssertFalse(succeeded)
        XCTAssertNil(model.creation)
        XCTAssertEqual(model.error?.title, "Check sharing choices")
        XCTAssertTrue(model.error?.message.contains("permissions") == true)
    }

    func test_invalidOrInsecureLivePublicURLIsRejected() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try Self.response(request, 201),
                Self.createPayload(
                    id: "00000000-0000-0000-0000-000000000051",
                    shareURL: "http://staging-api.kairoid.com/internal-token"
                )
            )
        }

        do {
            _ = try await service.createShare(
                PassportShareMutationInput(
                    label: nil,
                    permissions: .privacyPreserving,
                    expiresAt: nil
                )
            )
            XCTFail("Expected insecure staging public URL to be rejected")
        } catch let error as PassportShareServiceError {
            XCTAssertEqual(error, .invalidPublicURL)
        }
    }

    func test_qrPayloadUsesOnlyTheAuthoritativePublicURL() throws {
        let publicURL = try XCTUnwrap(
            URL(string: "https://d3kpvsn9kfajzc.cloudfront.net/passport/public-token-value")
        )

        let payload = PassportShareQRPayload.publicURLString(from: publicURL)

        XCTAssertEqual(payload, publicURL.absoluteString)
        XCTAssertFalse(payload.contains("Bearer"))
        XCTAssertFalse(payload.contains("/api/v1"))
        XCTAssertNotNil(PassportShareQRCode.image(for: publicURL))
    }

    func test_privacyDefaultSelectsNoOptionalPassportSections() {
        let permissions = PassportSharePermissions.privacyPreserving

        XCTAssertTrue(permissions.enabledOptions.isEmpty)
        XCTAssertEqual(permissions.conciseSummary, "Basic public profile only")
    }

    func test_demoDependenciesUseDeterministicLocalShareServiceWithoutNetwork() async throws {
        let configuration = AppConfiguration(
            buildConfiguration: .demo,
            environment: .development,
            isDemoModeEnabled: true,
            apiBaseURL: APIConfiguration.baseURL(for: .development),
            keychainService: "com.kairoid.Kairo.tests.passport-share-demo"
        )
        let dependencies = AppDependencies.make(
            configuration: configuration,
            uiTestConfiguration: UITestLaunchConfiguration(
                isEnabled: false,
                route: .onboarding,
                onboardingStep: nil,
                disablesAnimations: false
            )
        )

        let shares = try await dependencies.passportShareService.listShares()
        let created = try await dependencies.passportShareService.createShare(
            PassportShareMutationInput(
                label: "Demo only",
                permissions: .privacyPreserving,
                expiresAt: nil
            )
        )
        let refreshedShares = try await dependencies.passportShareService.listShares()

        XCTAssertEqual(shares.first?.id, "demo-share-1")
        XCTAssertEqual(created.publicURL.host, "demo.kairoid.invalid")
        XCTAssertEqual(refreshedShares.count, 2)
    }

    func test_shareMutationsInvalidateExistingCrossTabRefreshStore() {
        let store = CandidateDataRefreshStore()

        store.passportSharesChanged()

        XCTAssertEqual(store.revision, 1)
        XCTAssertNil(store.focusedVerificationRequestID)
    }

    func test_errorMappingKeepsConflictGoneRateLimitTimeoutAndServerFailureDistinct() {
        let conflict = PassportSharePresentationError.map(
            NetworkError.api(Self.apiError(status: 409, message: "Revoked share links cannot be updated")),
            fallbackTitle: "Failed"
        )
        let gone = PassportSharePresentationError.map(
            NetworkError.api(Self.apiError(status: 410, message: "Gone")),
            fallbackTitle: "Failed"
        )
        let rateLimited = PassportSharePresentationError.map(
            NetworkError.api(Self.apiError(status: 429, message: "Too many")),
            fallbackTitle: "Failed"
        )
        let timeout = PassportSharePresentationError.map(
            NetworkError.transport("The request timed out."),
            fallbackTitle: "Failed"
        )
        let server = PassportSharePresentationError.map(
            NetworkError.api(Self.apiError(status: 503, message: "Unavailable")),
            fallbackTitle: "Failed"
        )

        XCTAssertEqual(conflict.title, "Share already revoked")
        XCTAssertEqual(gone.title, "Share no longer available")
        XCTAssertEqual(rateLimited.title, "Too many attempts")
        XCTAssertEqual(timeout.title, "Request timed out")
        XCTAssertEqual(server.title, "Passport sharing unavailable")
    }

    private func makeService() async throws -> PassportShareService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-passport-share", for: .accessToken)
        let configuration = AppConfiguration(
            buildConfiguration: .staging,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.passport-share"
        )
        let networkClient = URLSessionNetworkClient(
            baseURL: configuration.apiBaseURL,
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: configuration,
            networkClient: networkClient,
            tokenStore: tokenStore
        )
        return PassportShareService(sessionService: sessionService, configuration: configuration)
    }

    private nonisolated static func response(_ request: URLRequest, _ statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )
        )
    }

    private nonisolated static func queryValue(_ name: String, _ request: URLRequest) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private nonisolated static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    private nonisolated static func pagePayload(items: [Data]) -> Data {
        let itemStrings = items.compactMap { String(data: $0, encoding: .utf8) }
        return Data(
            """
            {
              "items": [\(itemStrings.joined(separator: ","))],
              "total": \(items.count),
              "page": 1,
              "page_size": 100,
              "total_pages": 1,
              "offset": 0,
              "limit": 100
            }
            """.utf8
        )
    }

    private nonisolated static func sharePayload(
        id: String,
        state: String,
        label: String? = "Recruiter access",
        expiresAt: String? = "2030-03-04T05:06:07Z"
    ) -> Data {
        let labelJSON = label.map { "\"\($0)\"" } ?? "null"
        let expiryJSON = expiresAt.map { "\"\($0)\"" } ?? "null"
        let revokedJSON = state == "revoked" ? "\"2030-01-03T12:00:00Z\"" : "null"
        return Data(
            """
            {
              "id": "\(id)",
              "label": \(labelJSON),
              "permissions": \(permissionJSON),
              "track_views": true,
              "expires_at": \(expiryJSON),
              "revoked_at": \(revokedJSON),
              "last_viewed_at": "2030-01-02T12:00:00Z",
              "created_at": "2030-01-01T10:00:00Z",
              "updated_at": "2030-01-02T11:00:00Z",
              "state": "\(state)"
            }
            """.utf8
        )
    }

    private nonisolated static func createPayload(id: String, shareURL: String) -> Data {
        let base = String(data: sharePayload(id: id, state: "active"), encoding: .utf8)!
        let withURL = base.dropLast().appending(",\"share_url\":\"\(shareURL)\"}")
        return Data(withURL.utf8)
    }

    private nonisolated static let permissionJSON =
        """
        {
          "include_employments": true,
          "include_educations": true,
          "include_internships": false,
          "include_freelance": false,
          "include_gig_platforms": false,
          "include_portfolio": false,
          "include_certifications": true,
          "include_skills": false,
          "include_projects": false,
          "include_user_documents": false,
          "show_employer_names": true,
          "show_documents": false,
          "show_trust_score": true
        }
        """

    private nonisolated static let permissionKeys: Set<String> = [
        "include_employments",
        "include_educations",
        "include_internships",
        "include_freelance",
        "include_gig_platforms",
        "include_portfolio",
        "include_certifications",
        "include_skills",
        "include_projects",
        "include_user_documents",
        "show_employer_names",
        "show_documents",
        "show_trust_score"
    ]

    private nonisolated static func apiError(status: Int, message: String) -> APIError {
        APIError(
            statusCode: status,
            code: .conflict,
            message: message,
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        )
    }
}
