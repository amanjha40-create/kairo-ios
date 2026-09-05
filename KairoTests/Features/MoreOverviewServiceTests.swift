import Foundation
import XCTest
@testable import Kairo

@MainActor
final class MoreOverviewServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_loadOverviewFetchesLiveAccountSettings() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/account/settings")
            return (try Self.response(for: request, statusCode: 200), Self.accountSettingsPayload)
        }

        let overview = try await service.loadOverview()

        XCTAssertEqual(overview.user.email, "aman@kairoid.com")
        XCTAssertEqual(overview.notificationPreferences.count, 2)
        XCTAssertEqual(overview.trustScoreConsent.status, "granted")
        XCTAssertEqual(overview.bundleAppVersion, "1.4.0 (104)")
        XCTAssertEqual(overview.apiVersion, "v1")
    }

    func test_updateProfilePatchesUsersMeAndRefetchesAccountSettings() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/users/me":
                XCTAssertEqual(request.httpMethod, "PATCH")
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                XCTAssertEqual(payload["full_name"] as? String, "Aman Jha")
                XCTAssertEqual(payload["headline"] as? String, "Product Operations Manager")
                XCTAssertEqual(payload["current_role"] as? String, "Product Operations Manager")
                XCTAssertEqual(payload["industry"] as? String, "Technology")
                XCTAssertEqual(payload["years_of_experience"] as? Int, 7)
                XCTAssertEqual(payload["location_city"] as? String, "Bengaluru")
                XCTAssertEqual(payload["location_country"] as? String, "India")
                return (try Self.response(for: request, statusCode: 200), Data("{}".utf8))
            case "https://staging-api.kairoid.com/api/v1/account/settings":
                return (try Self.response(for: request, statusCode: 200), Self.accountSettingsPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.updateProfile(
            MoreProfileDraft(
                fullName: "Aman Jha",
                professionalHeadline: "Product Operations Manager",
                currentRole: "Product Operations Manager",
                industry: "Technology",
                yearsOfExperience: "7",
                currentCity: "Bengaluru",
                currentCountry: "India"
            )
        )

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.first?.url?.path, "/api/v1/users/me")
        XCTAssertEqual(requests.last?.url?.path, "/api/v1/account/settings")
        XCTAssertEqual(overview.user.fullName, "Aman Jha")
    }

    func test_changePasswordPostsAuthenticatedRequestAndReturnsBackendMessage() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/auth/change-password")
            XCTAssertEqual(request.httpMethod, "POST")

            let body = try requestBodyData(from: request)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["current_password"] as? String, "OldPassword@2026")
            XCTAssertEqual(payload["new_password"] as? String, "NewPassword@2026")
            XCTAssertEqual(payload["confirm_password"] as? String, "NewPassword@2026")

            return (
                try Self.response(for: request, statusCode: 200),
                Data(#"{"message":"Password updated."}"#.utf8)
            )
        }

        let message = try await service.changePassword(
            currentPassword: "OldPassword@2026",
            newPassword: "NewPassword@2026",
            confirmPassword: "NewPassword@2026"
        )

        XCTAssertEqual(message, "Password updated.")
    }

    func test_changePasswordSurfacesBackendValidationFailure() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/auth/change-password")
            return (
                try Self.response(for: request, statusCode: 422),
                Data(
                    """
                    {
                      "error": {
                        "code": "validation_error",
                        "message": "Current password is incorrect."
                      }
                    }
                    """.utf8
                )
            )
        }

        do {
            _ = try await service.changePassword(
                currentPassword: "wrong",
                newPassword: "NewPassword@2026",
                confirmPassword: "NewPassword@2026"
            )
            XCTFail("Expected changePassword to throw")
        } catch let error as NetworkError {
            guard case .api(let apiError) = error else {
                return XCTFail("Expected API error, received \(error)")
            }

            XCTAssertEqual(apiError.code, .validationError)
            XCTAssertEqual(apiError.message, "Current password is incorrect.")
        }
    }

    func test_deleteAccountUsesAuthenticatedCandidateContract() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/users/me")
            XCTAssertEqual(request.httpMethod, "DELETE")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try requestBodyData(from: request)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["confirm"] as? String, "DELETE")
            XCTAssertEqual(payload["current_password"] as? String, "CurrentPassword@2026")
            XCTAssertEqual(Set(payload.keys), ["confirm", "current_password"])

            return (try Self.response(for: request, statusCode: 204), Data())
        }

        try await service.deleteAccount(
            confirm: "DELETE",
            currentPassword: "CurrentPassword@2026"
        )
    }

    func test_deleteAccountOmitsBlankPasswordForAccountsWithoutLocalCredential() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            let body = try requestBodyData(from: request)
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["confirm"] as? String, "DELETE")
            XCTAssertNil(payload["current_password"])
            XCTAssertEqual(Set(payload.keys), ["confirm"])
            return (try Self.response(for: request, statusCode: 204), Data())
        }

        try await service.deleteAccount(confirm: "DELETE", currentPassword: "   ")
    }

    func test_failedAccountDeletionPreservesLocalSession() async throws {
        let setup = try await makeServiceAndTokenStore()
        try await setup.tokenStore.save("refresh-456", for: .refreshToken)

        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try Self.response(for: request, statusCode: 503),
                Data(#"{"error":{"code":"service_unavailable","message":"Unavailable"}}"#.utf8)
            )
        }

        do {
            try await setup.service.deleteAccount(
                confirm: "DELETE",
                currentPassword: "CurrentPassword@2026"
            )
            XCTFail("Expected account deletion to fail.")
        } catch {
            let accessToken = try await setup.tokenStore.readToken(for: .accessToken)
            let refreshToken = try await setup.tokenStore.readToken(for: .refreshToken)
            XCTAssertEqual(accessToken, "access-123")
            XCTAssertEqual(refreshToken, "refresh-456")
        }
    }

    func test_wrongDeletionPasswordDoesNotRefreshOrClearValidSession() async throws {
        let setup = try await makeServiceAndTokenStore()
        try await setup.tokenStore.save("refresh-456", for: .refreshToken)

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/users/me")
            return (
                try Self.response(for: request, statusCode: 401),
                Data(#"{"error":{"code":"unauthorized","message":"Current password is incorrect"}}"#.utf8)
            )
        }

        do {
            try await setup.service.deleteAccount(
                confirm: "DELETE",
                currentPassword: "WrongPassword@2026"
            )
            XCTFail("Expected account deletion to reject the wrong password.")
        } catch let error as NetworkError {
            guard case .api(let apiError) = error else {
                return XCTFail("Expected the authoritative deletion API error.")
            }
            XCTAssertEqual(apiError.code, .unauthorized)
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        let accessToken = try await setup.tokenStore.readToken(for: .accessToken)
        let refreshToken = try await setup.tokenStore.readToken(for: .refreshToken)
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(accessToken, "access-123")
        XCTAssertEqual(refreshToken, "refresh-456")
    }

    func test_loadSessionsMapsCurrentAndNonCurrentSessions() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/account/sessions")
            return (try Self.response(for: request, statusCode: 200), Self.sessionsPayload)
        }

        let sessions = try await service.loadSessions()

        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.first(where: { $0.id == "session_current" })?.isCurrent ?? false)
        XCTAssertFalse(sessions.first(where: { $0.id == "session_other" })?.isCurrent ?? true)
    }

    func test_revokeSessionCallsCandidateSessionEndpoint() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.absoluteString, "https://staging-api.kairoid.com/api/v1/account/sessions/session_other")
            XCTAssertEqual(request.httpMethod, "DELETE")
            return (try Self.response(for: request, statusCode: 204), Data())
        }

        try await service.revokeSession(id: "session_other")
    }

    func test_updateNotificationPreferencePersistsAuthoritativeToggleAndRefetches() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/account/settings" where request.httpMethod == "PATCH":
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                let preferences = try XCTUnwrap(payload["notification_preferences"] as? [[String: Any]])
                let verificationPreference = try XCTUnwrap(
                    preferences.first(where: { $0["event_type"] as? String == "verification_updates" })
                )
                let marketingPreference = try XCTUnwrap(
                    preferences.first(where: { $0["event_type"] as? String == "product_updates" })
                )
                XCTAssertEqual(verificationPreference["enabled"] as? Bool, false)
                XCTAssertEqual(marketingPreference["enabled"] as? Bool, false)
                return (try Self.response(for: request, statusCode: 200), Data("{}".utf8))
            case "https://staging-api.kairoid.com/api/v1/account/settings":
                return (try Self.response(for: request, statusCode: 200), Self.accountSettingsAfterNotificationUpdatePayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.updateNotificationPreference(
            id: "notif_verification",
            enabled: false,
            existingPreferences: [
                MoreNotificationPreferenceItem(
                    id: "notif_verification",
                    eventType: "verification_updates",
                    title: "Verification updates",
                    subtitle: "Stay updated when your verification status changes.",
                    isEnabled: true,
                    preferredChannels: ["email"],
                    quietHours: [:],
                    metadata: [:]
                ),
                MoreNotificationPreferenceItem(
                    id: "notif_marketing",
                    eventType: "product_updates",
                    title: "Product updates",
                    subtitle: "Receive product updates from Kairo.",
                    isEnabled: false,
                    preferredChannels: ["email"],
                    quietHours: [:],
                    metadata: [:]
                )
            ]
        )

        XCTAssertEqual(
            overview.notificationPreferences.first(where: { $0.id == "notif_verification" })?.enabled,
            false
        )
    }

    func test_withdrawTrustScoreConsentPersistsFlagAndRefetches() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.absoluteString {
            case "https://staging-api.kairoid.com/api/v1/account/settings" where request.httpMethod == "PATCH":
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: body) as? [String: Any]
                )
                XCTAssertEqual(payload["withdraw_trust_score_consent"] as? Bool, true)
                XCTAssertNil(payload["notification_preferences"])
                return (try Self.response(for: request, statusCode: 200), Data("{}".utf8))
            case "https://staging-api.kairoid.com/api/v1/account/settings":
                return (try Self.response(for: request, statusCode: 200), Self.accountSettingsAfterConsentWithdrawalPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.withdrawTrustScoreConsent()

        XCTAssertEqual(overview.trustScoreConsent.status, "withdrawn")
        XCTAssertNil(overview.trustScoreConsent.consentedAt)
    }

    func test_grantTrustScoreConsentUsesCanonicalRouteAndRefetches() async throws {
        let service = try await makeService()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/trust-score/consent"):
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(payload["consent_version"], "v1")
                return (try Self.response(for: request, statusCode: 204), Data())
            case ("GET", "/api/v1/account/settings"):
                return (try Self.response(for: request, statusCode: 200), Self.accountSettingsPayload)
            default:
                XCTFail("Unexpected request URL: \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let overview = try await service.grantTrustScoreConsent(version: "v1")
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(overview.trustScoreConsent.status, "granted")
        XCTAssertEqual(requests.map(\.httpMethod), ["POST", "GET"])
    }

    private func makeService() async throws -> MoreOverviewService {
        try await makeServiceAndTokenStore().service
    }

    private func makeServiceAndTokenStore() async throws -> (
        service: MoreOverviewService,
        tokenStore: InMemoryTokenStore
    ) {
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

        return (
            MoreOverviewService(
                sessionService: sessionService,
                bundleAppVersion: "1.4.0 (104)"
            ),
            tokenStore
        )
    }

    private func makeConfiguration() -> AppConfiguration {
        AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.more"
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

    private nonisolated static let accountSettingsPayload = Data(
        """
        {
          "profile": {
            "id": "user_123",
            "email": "aman@kairoid.com",
            "full_name": "Aman Jha",
            "profile_slug": "aman-jha",
            "phone": "+919876543210",
            "current_role": "Product Operations Manager",
            "industry": "Technology",
            "years_of_experience": 7,
            "location": "Bengaluru, Karnataka, India",
            "location_city": "Bengaluru",
            "location_region": "Karnataka",
            "location_country": "India",
            "headline": "Product Operations Manager",
            "role": "user",
            "is_active": true,
            "email_verified_at": "2026-08-09T08:30:00Z",
            "phone_verified_at": null,
            "profile_completion_percentage": 85,
            "created_at": "2026-08-09T08:00:00Z"
          },
          "trust_score_consent": {
            "status": "granted",
            "version": "resume_processing_v1",
            "consented_at": "2026-08-09T08:31:00Z"
          },
          "notification_preferences": [
            {
              "public_id": "notif_verification",
              "user_id": "user_123",
              "event_type": "verification_updates",
              "enabled": true,
              "preferred_channels": ["email"],
              "quiet_hours": {},
              "metadata": {},
              "created_at": "2026-08-09T08:32:00Z",
              "updated_at": "2026-08-09T08:33:00Z"
            },
            {
              "public_id": "notif_marketing",
              "user_id": "user_123",
              "event_type": "product_updates",
              "enabled": false,
              "preferred_channels": ["email"],
              "quiet_hours": {
                "start": "22:00",
                "end": "07:00"
              },
              "metadata": {
                "source": "staging"
              },
              "created_at": "2026-08-09T08:34:00Z",
              "updated_at": "2026-08-09T08:35:00Z"
            }
          ],
          "app_version": "2026.08.09",
          "api_version": "v1",
          "trust_score_version": "ts_2026_08"
        }
        """.utf8
    )

    private nonisolated static let accountSettingsAfterNotificationUpdatePayload = Data(
        """
        {
          "profile": {
            "id": "user_123",
            "email": "aman@kairoid.com",
            "full_name": "Aman Jha",
            "role": "user",
            "is_active": true,
            "created_at": "2026-08-09T08:00:00Z"
          },
          "trust_score_consent": {
            "status": "granted",
            "version": "resume_processing_v1",
            "consented_at": "2026-08-09T08:31:00Z"
          },
          "notification_preferences": [
            {
              "public_id": "notif_verification",
              "user_id": "user_123",
              "event_type": "verification_updates",
              "enabled": false,
              "preferred_channels": ["email"],
              "quiet_hours": {},
              "metadata": {},
              "created_at": "2026-08-09T08:32:00Z",
              "updated_at": "2026-08-09T08:36:00Z"
            }
          ],
          "app_version": "2026.08.09",
          "api_version": "v1",
          "trust_score_version": "ts_2026_08"
        }
        """.utf8
    )

    private nonisolated static let accountSettingsAfterConsentWithdrawalPayload = Data(
        """
        {
          "profile": {
            "id": "user_123",
            "email": "aman@kairoid.com",
            "full_name": "Aman Jha",
            "role": "user",
            "is_active": true,
            "created_at": "2026-08-09T08:00:00Z"
          },
          "trust_score_consent": {
            "status": "withdrawn",
            "version": "resume_processing_v1",
            "consented_at": null
          },
          "notification_preferences": [],
          "app_version": "2026.08.09",
          "api_version": "v1",
          "trust_score_version": "ts_2026_08"
        }
        """.utf8
    )

    private nonisolated static let sessionsPayload = Data(
        """
        [
          {
            "id": "session_current",
            "created_at": "2026-08-09T08:00:00Z",
            "expires_at": "2026-08-16T08:00:00Z",
            "last_active_at": "2026-08-10T08:45:00Z",
            "current": true
          },
          {
            "id": "session_other",
            "created_at": "2026-08-08T08:00:00Z",
            "expires_at": "2026-08-15T08:00:00Z",
            "last_active_at": "2026-08-09T20:45:00Z",
            "current": false
          }
        ]
        """.utf8
    )
}
