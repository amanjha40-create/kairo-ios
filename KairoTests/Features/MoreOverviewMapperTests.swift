import Foundation
import XCTest
@testable import Kairo

@MainActor
final class MoreOverviewMapperTests: XCTestCase {
    func test_mapCreatesLiveMoreStateFromOverview() {
        let overview = MoreOverview(
            user: makeUser(),
            trustScoreConsent: MoreTrustScoreConsent(
                status: "granted",
                version: "resume_processing_v1",
                consentedAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 31, second: 0)
            ),
            notificationPreferences: [
                MoreNotificationSetting(
                    id: "notif_1",
                    eventType: "verification_updates",
                    enabled: true,
                    preferredChannels: ["email"],
                    quietHours: [:],
                    metadata: [:],
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 32, second: 0),
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 33, second: 0)
                ),
                MoreNotificationSetting(
                    id: "notif_2",
                    eventType: "passport_views",
                    enabled: false,
                    preferredChannels: ["email"],
                    quietHours: ["start": "22:00"],
                    metadata: ["source": "staging"],
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 34, second: 0),
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 35, second: 0)
                )
            ],
            bundleAppVersion: "1.4.0 (104)",
            backendAppVersion: "2026.08.09",
            apiVersion: "v1",
            trustScoreVersion: "ts_2026_08"
        )

        let state = MoreOverviewMapper.map(
            overview,
            destinations: MoreExternalDestinations(
                supportEmailAddress: "support@kairoid.com",
                helpCenterURL: URL(string: "https://help.kairoid.com"),
                termsOfServiceURL: URL(string: "https://www.kairoid.com/terms"),
                privacyPolicyURL: URL(string: "https://www.kairoid.com/privacy"),
                cookiePolicyURL: URL(string: "https://www.kairoid.com/cookies")
            )
        )

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated More state")
        }

        XCTAssertEqual(state.accountSummary.initials, "AJ")
        XCTAssertEqual(state.accountSummary.name, "Aman Jha")
        XCTAssertEqual(state.accountSummary.emailAddress, "aman@kairoid.com")
        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertEqual(content.notificationPreferences.map(\.title), [
            "Verification updates",
            "Passport views"
        ])
        XCTAssertEqual(content.accountRows.first?.subtitle, "Email verified • Phone not verified")
        XCTAssertEqual(content.privacyRows.first(where: { $0.id == "manageConsent" })?.subtitle, "Trust Score consent is currently Granted.")
        XCTAssertEqual(content.supportRows.first(where: { $0.id == "helpCentre" })?.subtitle, "Open Kairo's help resources.")
        XCTAssertEqual(content.aboutRows.first(where: { $0.id == "privacyPolicy" })?.subtitle, "Open the latest Kairo document.")
        XCTAssertFalse(content.accountRows.contains(where: { $0.id == "connectedAccounts" }))
        XCTAssertFalse(content.privacyRows.contains(where: { $0.id == "privacySettings" || $0.id == "downloadMyData" }))
        XCTAssertFalse(content.aboutRows.contains(where: { $0.id == "cookiePolicy" || $0.id == "openSourceLicences" }))
    }

    func test_mapHandlesUnknownNotificationEventTypeWithReadableFallback() {
        let overview = MoreOverview(
            user: makeUser(),
            trustScoreConsent: MoreTrustScoreConsent(status: "pending", version: nil, consentedAt: nil),
            notificationPreferences: [
                MoreNotificationSetting(
                    id: "notif_unknown",
                    eventType: "weekly_digest_digest",
                    enabled: true,
                    preferredChannels: [],
                    quietHours: [:],
                    metadata: [:],
                    createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 32, second: 0),
                    updatedAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 33, second: 0)
                )
            ],
            bundleAppVersion: "1.4.0 (104)",
            backendAppVersion: "2026.08.09",
            apiVersion: "v1",
            trustScoreVersion: "ts_2026_08"
        )

        let state = MoreOverviewMapper.map(
            overview,
            destinations: MoreExternalDestinations(
                supportEmailAddress: "support@kairoid.com",
                helpCenterURL: nil,
                termsOfServiceURL: nil,
                privacyPolicyURL: nil,
                cookiePolicyURL: nil
            )
        )

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated More state")
        }

        XCTAssertEqual(content.notificationPreferences.first?.title, "Weekly Digest Digest")
        XCTAssertEqual(
            content.notificationPreferences.first?.subtitle,
            "Control whether Kairo sends this notification."
        )
    }

    func test_errorStateMapsTransportToOfflineExperience() {
        let state = MoreOverviewMapper.errorState(
            for: NetworkError.transport("offline"),
            accountSummary: .fixture
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "You're offline")
        XCTAssertTrue(errorState.message.contains("couldn't reach"))
    }

    func test_errorStatePreservesBackendAPIMessage() {
        let apiError = APIError(
            statusCode: 422,
            code: .validationError,
            message: "Current password is incorrect.",
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        )

        let state = MoreOverviewMapper.errorState(
            for: NetworkError.api(apiError),
            accountSummary: .fixture
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "Account settings unavailable")
        XCTAssertEqual(errorState.message, "Current password is incorrect.")
    }

    func test_requiresSessionRecoveryOnlyForExpiredSessions() {
        XCTAssertTrue(MoreOverviewMapper.requiresSessionRecovery(for: SessionServiceError.sessionExpired))
        XCTAssertFalse(MoreOverviewMapper.requiresSessionRecovery(for: SessionServiceError.missingAccessToken))
        XCTAssertFalse(MoreOverviewMapper.requiresSessionRecovery(for: NetworkError.transport("offline")))
    }

    func test_cachedSummaryFallsBackToFixtureWhenUserUnavailable() {
        XCTAssertEqual(MoreOverviewMapper.cachedSummary(from: nil), .fixture)
        XCTAssertEqual(MoreOverviewMapper.cachedSummary(from: makeUser()).name, "Aman Jha")
    }

    func test_accountDeletionFailureMappingDistinguishesAuthenticationAndPreservesBackendValidation() {
        let unauthorized = MoreAccountDeletionErrorMapper.map(apiError(
            statusCode: 401,
            code: .unauthorized,
            message: "Current password is incorrect"
        ))
        XCTAssertEqual(
            unauthorized.currentPasswordError,
            "The current password is missing or incorrect."
        )
        XCTAssertTrue(unauthorized.message.contains("not deleted"))

        let validation = MoreAccountDeletionErrorMapper.map(apiError(
            statusCode: 422,
            code: .validationError,
            message: "Account deletion requires confirm=DELETE"
        ))
        XCTAssertNil(validation.currentPasswordError)
        XCTAssertEqual(validation.message, "Account deletion requires confirm=DELETE")
    }

    func test_accountDeletionFailureMappingCoversProtectedBackendFailureClasses() {
        let forbidden = MoreAccountDeletionErrorMapper.map(apiError(
            statusCode: 403,
            code: .forbidden,
            message: "Forbidden"
        ))
        let conflict = MoreAccountDeletionErrorMapper.map(apiError(
            statusCode: 409,
            code: .conflict,
            message: "Conflict"
        ))
        let rateLimited = MoreAccountDeletionErrorMapper.map(apiError(
            statusCode: 429,
            code: .rateLimited,
            message: "Rate limited"
        ))
        let serviceUnavailable = MoreAccountDeletionErrorMapper.map(apiError(
            statusCode: 503,
            code: .serviceUnavailable,
            message: "Unavailable"
        ))
        let timeout = MoreAccountDeletionErrorMapper.map(
            NetworkError.transport("The request timed out")
        )

        XCTAssertTrue(forbidden.message.contains("not eligible"))
        XCTAssertTrue(conflict.message.contains("not deleted"))
        XCTAssertTrue(rateLimited.message.contains("not deleted"))
        XCTAssertTrue(serviceUnavailable.message.contains("session remain unchanged"))
        XCTAssertTrue(timeout.message.contains("session was preserved"))
    }

    private func apiError(
        statusCode: Int,
        code: APIErrorCode,
        message: String
    ) -> NetworkError {
        NetworkError.api(APIError(
            statusCode: statusCode,
            code: code,
            message: message,
            fieldErrors: [:],
            globalErrors: [],
            validationDetails: []
        ))
    }

    private func makeUser() -> AppUser {
        AppUser(
            id: "user_123",
            email: "aman@kairoid.com",
            fullName: "Aman Jha",
            profileSlug: "aman-jha",
            phone: "+919876543210",
            currentRole: "Product Operations Manager",
            industry: "Technology",
            yearsOfExperience: 7,
            location: "Bengaluru, Karnataka, India",
            locationCity: "Bengaluru",
            locationRegion: "Karnataka",
            locationCountry: "India",
            headline: "Product Operations Manager",
            bio: nil,
            dateOfBirth: nil,
            avatarURL: nil,
            role: "user",
            isActive: true,
            phoneVerifiedAt: nil,
            emailVerifiedAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 30, second: 0),
            employmentOnboardingCompletedAt: nil,
            languages: [],
            professionalLinks: [],
            profileCompletionPercentage: 85,
            createdAt: makeUTCTimestamp(year: 2026, month: 8, day: 9, hour: 8, minute: 0, second: 0)
        )
    }

    private func makeUTCTimestamp(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int
    ) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date ?? .distantPast
    }
}
