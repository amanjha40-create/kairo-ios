import XCTest
@testable import Kairo

@MainActor
final class MoreOverviewStateTests: XCTestCase {
    func test_populatedFixtureExposesExpectedSectionsAndAccountSummary() {
        let state = MoreOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(state.accountSummary.name, "Aarav Mehta")
        XCTAssertEqual(state.accountSummary.emailAddress, "aarav@example.com")
        XCTAssertEqual(content.visibleSections, [
            .account,
            .preferences,
            .privacyData,
            .helpSupport,
            .about
        ])
        XCTAssertEqual(content.accountRows.map(\.title), [
            "Personal information",
            "Login & security",
            "Connected accounts",
            "Sessions & devices"
        ])
        XCTAssertEqual(content.appVersion, "1.0.0 (1)")
        XCTAssertEqual(content.supportEmailAddress, "support@kairoid.com")
    }

    func test_defaultUsesDifferentFixtureLabelsForDemoAndPreview() {
        let demoState = MoreOverviewState.default(isDemoMode: true)
        let previewState = MoreOverviewState.default(isDemoMode: false)

        guard case .populated(let demoContent) = demoState.phase,
              case .populated(let previewContent) = previewState.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(demoContent.dataSourceLabel, "Demo data")
        XCTAssertEqual(previewContent.dataSourceLabel, "Preview data")
    }

    func test_setNotificationUpdatesPreferencesAndPopulatedContent() throws {
        var state = MoreOverviewState.populatedFixture()
        let firstID = try XCTUnwrap(state.preferences.notifications.first?.id)

        state.setNotification(id: firstID, isEnabled: false)

        XCTAssertEqual(
            state.preferences.notifications.first(where: { $0.id == firstID })?.isEnabled,
            false
        )

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(
            content.notificationPreferences.first(where: { $0.id == firstID })?.isEnabled,
            false
        )
    }

    func test_replaceNotificationPreferencesReplacesPreferencesAndContent() {
        var state = MoreOverviewState.populatedFixture()
        let replacement = [
            MoreNotificationPreferenceItem(
                id: "verification_updates",
                eventType: "verification_updates",
                title: "Verification updates",
                subtitle: "Stay updated when your verification status changes.",
                isEnabled: false,
                preferredChannels: ["email"],
                quietHours: [:],
                metadata: [:]
            )
        ]

        state.replaceNotificationPreferences(replacement)

        XCTAssertEqual(state.preferences.notifications, replacement)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(content.notificationPreferences, replacement)
    }

    func test_applyPreservesAppearanceAndLanguageWhileReplacingLiveContent() {
        var state = MoreOverviewState.populatedFixture()
        state.selectAppearance(.dark)
        state.preferences.language = "English (India)"

        state.apply(
            overview: makeOverview(),
            destinations: MoreExternalDestinations(
                supportEmailAddress: "support@kairoid.com",
                helpCenterURL: URL(string: "https://help.kairoid.com"),
                termsOfServiceURL: URL(string: "https://www.kairoid.com/terms"),
                privacyPolicyURL: URL(string: "https://www.kairoid.com/privacy"),
                cookiePolicyURL: URL(string: "https://www.kairoid.com/cookies")
            )
        )

        XCTAssertEqual(state.preferences.appearance, .dark)
        XCTAssertEqual(state.preferences.language, "English (India)")
        XCTAssertEqual(state.accountSummary.name, "Aman Jha")

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertEqual(content.notificationPreferences.count, 2)
        XCTAssertEqual(content.accountRows.first?.subtitle, "Email verified • Phone not verified")
    }

    private func makeOverview() -> MoreOverview {
        MoreOverview(
            user: AppUser(
                id: "user_live",
                email: "aman@kairoid.com",
                fullName: "Aman Jha",
                profileSlug: "aman-jha",
                phone: "+919812345678",
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
                emailVerifiedAt: ISO8601DateFormatter().date(from: "2026-08-09T08:30:00Z"),
                employmentOnboardingCompletedAt: nil,
                languages: [],
                professionalLinks: [],
                profileCompletionPercentage: 80,
                createdAt: ISO8601DateFormatter().date(from: "2026-08-09T08:00:00Z") ?? .distantPast
            ),
            trustScoreConsent: MoreTrustScoreConsent(
                status: "granted",
                version: "resume_processing_v1",
                consentedAt: ISO8601DateFormatter().date(from: "2026-08-09T08:31:00Z")
            ),
            notificationPreferences: [
                MoreNotificationSetting(
                    id: "notif_1",
                    eventType: "verification_updates",
                    enabled: true,
                    preferredChannels: ["email"],
                    quietHours: [:],
                    metadata: [:],
                    createdAt: ISO8601DateFormatter().date(from: "2026-08-09T08:32:00Z") ?? .distantPast,
                    updatedAt: ISO8601DateFormatter().date(from: "2026-08-09T08:32:30Z") ?? .distantPast
                ),
                MoreNotificationSetting(
                    id: "notif_2",
                    eventType: "passport_views",
                    enabled: false,
                    preferredChannels: ["email"],
                    quietHours: ["start": "22:00"],
                    metadata: ["source": "staging"],
                    createdAt: ISO8601DateFormatter().date(from: "2026-08-09T08:33:00Z") ?? .distantPast,
                    updatedAt: ISO8601DateFormatter().date(from: "2026-08-09T08:33:30Z") ?? .distantPast
                )
            ],
            bundleAppVersion: "1.4.0 (104)",
            backendAppVersion: "2026.08.09",
            apiVersion: "v1",
            trustScoreVersion: "ts_2026_08"
        )
    }
}
