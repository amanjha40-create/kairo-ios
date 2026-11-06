import XCTest
@testable import Kairo

final class FirebaseAnalyticsPrivacyTests: XCTestCase {
    func test_productionDebugViewTransportWhenExplicitlyEnabled() async throws {
        #if KAIRO_FIREBASE_DEBUGVIEW_QA
        let debugModeKey = "/google/firebase/debug_mode"
        UserDefaults.standard.set(true, forKey: debugModeKey)
        defer { UserDefaults.standard.removeObject(forKey: debugModeKey) }

        KairoAnalytics.configure()
        await KairoAnalytics.shared.setAnonymousUserID(UUID().uuidString)

        let occurrenceID = "debugview-\(UUID().uuidString)"
        await KairoAnalytics.shared.log(.signUp)
        await KairoAnalytics.shared.logOnce(.profileCreated, occurrenceID: occurrenceID)
        await KairoAnalytics.shared.logOnce(.profileCreated, occurrenceID: occurrenceID)
        await KairoAnalytics.shared.log(.verificationStarted)
        await KairoAnalytics.shared.log(.verificationCompleted)
        await KairoAnalytics.shared.log(.trustScoreViewed)

        try await Task.sleep(for: .seconds(4))

        // Exercise the same nil transition used by logout/account switching before
        // emitting the final event, so it cannot inherit the previous account ID.
        await KairoAnalytics.shared.setAnonymousUserID(nil)
        await KairoAnalytics.shared.log(.shareLinkCreated)

        try await Task.sleep(for: .seconds(8))
        #else
        throw XCTSkip("Production Firebase DebugView transport is opt-in only.")
        #endif
    }

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
