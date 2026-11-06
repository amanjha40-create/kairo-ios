import XCTest
@testable import Kairo

final class FirebaseAnalyticsPrivacyTests: XCTestCase {
    func test_onlyApprovedParameterlessEventNamesExist() {
        XCTAssertEqual(
            Set(KairoAnalyticsEvent.allCases.map(\.rawValue)),
            Set([
                "sign_up",
                "profile_created",
                "verification_started",
                "verification_completed",
                "trust_score_viewed",
                "share_link_created"
            ])
        )
    }

    func test_onlyCanonicalInternalUUIDIsAcceptedAsUserID() {
        XCTAssertTrue(KairoAnalytics.isValidInternalUserID("5266dd7b-e6ed-4666-b714-43d4a94a2630"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID("person@example.com"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID("+919999999999"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID("ABCDE1234F"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID(nil))
    }

    func test_analyticsConfigurationExcludesAutomaticScreensAndDeviceAdvertisingIdentifiers() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let development = try XCTUnwrap(
            NSDictionary(contentsOf: repositoryRoot.appendingPathComponent("Kairo-Info.plist"))
        )
        let production = try XCTUnwrap(
            NSDictionary(contentsOf: repositoryRoot.appendingPathComponent("Kairo-Production-Info.plist"))
        )

        for configuration in [development, production] {
            XCTAssertEqual(configuration["FirebaseAutomaticScreenReportingEnabled"] as? Bool, false)
            XCTAssertEqual(
                configuration["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS"] as? Bool,
                false
            )
            XCTAssertEqual(configuration["GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED"] as? Bool, false)
        }
    }
}
