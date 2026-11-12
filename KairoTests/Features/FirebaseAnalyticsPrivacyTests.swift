import XCTest
@testable import Kairo

final class FirebaseAnalyticsPrivacyTests: XCTestCase {
    func test_onlyApprovedParameterlessEventNamesExist() {
        XCTAssertEqual(Set(KairoAnalyticsEvent.allCases.map(\.rawValue)), Set([
            "sign_up", "profile_created", "verification_started", "verification_completed",
            "trust_score_viewed", "share_link_created"
        ]))
    }

    func test_onlyCanonicalInternalUUIDIsAcceptedAsUserID() {
        XCTAssertTrue(KairoAnalytics.isValidInternalUserID("5266dd7b-e6ed-4666-b714-43d4a94a2630"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID("person@example.com"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID("+919999999999"))
        XCTAssertFalse(KairoAnalytics.isValidInternalUserID(nil))
    }

    func test_freshStateDropsEventsAndKeepsEveryConsentDenied() async {
        let transport = AnalyticsTransportSpy()
        let analytics = KairoAnalytics(transport: transport, occurrenceDefaults: isolatedDefaults())
        await analytics.apply(accountID: nil, decision: nil)
        await analytics.log(.signUp)
        XCTAssertEqual(transport.events, [])
        XCTAssertEqual(transport.prepareCount, 0)
        XCTAssertEqual(transport.collectionStates.last, false)
        XCTAssertEqual(transport.consentStates.last, false)
        XCTAssertNil(transport.userIDs.last ?? nil)
    }

    func test_acceptanceEnablesAllowlistedEventsWithInternalUUID() async {
        let transport = AnalyticsTransportSpy()
        let analytics = KairoAnalytics(transport: transport, occurrenceDefaults: isolatedDefaults())
        let accountID = UUID().uuidString
        await analytics.apply(accountID: accountID, decision: .allowed)
        await analytics.log(.profileCreated)
        XCTAssertEqual(transport.events, [.profileCreated])
        XCTAssertEqual(transport.prepareCount, 1)
        XCTAssertEqual(transport.collectionStates.last, true)
        XCTAssertEqual(transport.consentStates.last, true)
        XCTAssertEqual(transport.userIDs.last ?? nil, accountID)
    }

    func test_withdrawalImmediatelyDisablesClearsIdentityAndResets() async {
        let transport = AnalyticsTransportSpy()
        let analytics = KairoAnalytics(transport: transport, occurrenceDefaults: isolatedDefaults())
        let accountID = UUID().uuidString
        await analytics.apply(accountID: accountID, decision: .allowed)
        await analytics.apply(accountID: accountID, decision: .denied)
        await analytics.log(.trustScoreViewed)
        XCTAssertEqual(transport.collectionStates.last, false)
        XCTAssertEqual(transport.consentStates.last, false)
        XCTAssertNil(transport.userIDs.last ?? nil)
        XCTAssertGreaterThanOrEqual(transport.resetCount, 1)
        XCTAssertEqual(transport.events, [])
    }

    func test_logoutAndAccountSwitchCannotCarryConsentOrIdentityForward() async {
        let transport = AnalyticsTransportSpy()
        let analytics = KairoAnalytics(transport: transport, occurrenceDefaults: isolatedDefaults())
        let firstAccountID = UUID().uuidString
        let secondAccountID = UUID().uuidString

        await analytics.apply(accountID: firstAccountID, decision: .allowed)
        await analytics.apply(accountID: nil, decision: nil)
        await analytics.apply(accountID: secondAccountID, decision: nil)
        await analytics.log(.trustScoreViewed)

        let state = await analytics.stateForTesting()
        XCTAssertFalse(state.allowed)
        XCTAssertEqual(state.accountID, secondAccountID)
        XCTAssertNil(transport.userIDs.last ?? nil)
        XCTAssertEqual(transport.events, [])
        XCTAssertGreaterThanOrEqual(transport.resetCount, 2)
    }

    func test_eventWithoutConsentIsNeverReplayedAfterConsent() async {
        let defaults = isolatedDefaults()
        let transport = AnalyticsTransportSpy()
        let analytics = KairoAnalytics(transport: transport, occurrenceDefaults: defaults)
        let occurrenceID = UUID().uuidString
        await analytics.logOnce(.verificationCompleted, occurrenceID: occurrenceID)
        await analytics.apply(accountID: UUID().uuidString, decision: .allowed)
        await analytics.logOnce(.verificationCompleted, occurrenceID: occurrenceID)
        XCTAssertEqual(transport.events, [])
    }

    func test_preferencesPersistRefusalAndScopeChoicesPerAccount() {
        let preferences = AnalyticsConsentPreferences(defaults: isolatedDefaults(), namespace: UUID().uuidString)
        preferences.setInstallationDecision(.denied)
        let first = UUID().uuidString
        let second = UUID().uuidString
        XCTAssertEqual(preferences.consumeInstallationDecision(for: first), .denied)
        XCTAssertEqual(preferences.decision(for: first), .denied)
        XCTAssertNil(preferences.decision(for: second))
        XCTAssertNil(preferences.installationDecision())
    }

    func test_accountDeletionRemovesOnlyThatAccountsDecision() {
        let preferences = AnalyticsConsentPreferences(defaults: isolatedDefaults(), namespace: UUID().uuidString)
        let first = UUID().uuidString
        let second = UUID().uuidString
        preferences.setDecision(.allowed, for: first)
        preferences.setDecision(.denied, for: second)
        preferences.removeDecision(for: first)
        XCTAssertNil(preferences.decision(for: first))
        XCTAssertEqual(preferences.decision(for: second), .denied)
    }

    func test_analyticsConfigurationStartsDisabledAndDeniesAdvertisingConsent() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        for name in ["Kairo-Info.plist", "Kairo-Production-Info.plist"] {
            let configuration = try XCTUnwrap(NSDictionary(contentsOf: root.appendingPathComponent(name)))
            XCTAssertEqual(configuration["FirebaseAutomaticScreenReportingEnabled"] as? Bool, false)
            XCTAssertEqual(configuration["FIREBASE_ANALYTICS_COLLECTION_ENABLED"] as? Bool, false)
            XCTAssertEqual(configuration["GOOGLE_ANALYTICS_DEFAULT_ALLOW_ANALYTICS_STORAGE"] as? Bool, false)
            XCTAssertEqual(configuration["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_STORAGE"] as? Bool, false)
            XCTAssertEqual(configuration["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_USER_DATA"] as? Bool, false)
            XCTAssertEqual(configuration["GOOGLE_ANALYTICS_DEFAULT_ALLOW_AD_PERSONALIZATION_SIGNALS"] as? Bool, false)
            XCTAssertEqual(configuration["GOOGLE_ANALYTICS_IDFV_COLLECTION_ENABLED"] as? Bool, false)
        }
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "FirebaseAnalyticsPrivacyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private final class AnalyticsTransportSpy: KairoAnalyticsTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _consentStates: [Bool] = []
    private var _collectionStates: [Bool] = []
    private var _userIDs: [String?] = []
    private var _events: [KairoAnalyticsEvent] = []
    private var _resetCount = 0
    private var _prepareCount = 0

    var consentStates: [Bool] { lock.withLock { _consentStates } }
    var collectionStates: [Bool] { lock.withLock { _collectionStates } }
    var userIDs: [String?] { lock.withLock { _userIDs } }
    var events: [KairoAnalyticsEvent] { lock.withLock { _events } }
    var resetCount: Int { lock.withLock { _resetCount } }
    var prepareCount: Int { lock.withLock { _prepareCount } }

    func prepareForCollection() { lock.withLock { _prepareCount += 1 } }
    func setConsent(analyticsAllowed: Bool) { lock.withLock { _consentStates.append(analyticsAllowed) } }
    func setCollectionEnabled(_ enabled: Bool) { lock.withLock { _collectionStates.append(enabled) } }
    func setUserID(_ userID: String?) { lock.withLock { _userIDs.append(userID) } }
    func resetAnalyticsData() { lock.withLock { _resetCount += 1 } }
    func log(_ event: KairoAnalyticsEvent) { lock.withLock { _events.append(event) } }
}
