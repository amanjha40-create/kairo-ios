import XCTest
@testable import Kairo

@MainActor
final class LocalBatch1QATests: XCTestCase {
    func testDistributionMissingExpiredWrongTeamAndWrongAppProfilesFailClosed() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let valid: [String: Any] = ["Entitlements": ["get-task-allow": true,
            "application-identifier": "MVT4T97ZGC.com.kairoid.Kairo",
            "com.apple.developer.team-identifier": "MVT4T97ZGC"],
            "ProvisionedDevices": ["synthetic-device"], "ExpirationDate": now.addingTimeInterval(60)]
        XCTAssertTrue(LocalBatch1QA.permitsDevelopmentProfile(valid, now: now))
        XCTAssertFalse(LocalBatch1QA.permitsDevelopmentProfile([:], now: now))
        var expired = valid; expired["ExpirationDate"] = now
        XCTAssertFalse(LocalBatch1QA.permitsDevelopmentProfile(expired, now: now))
        var distribution = valid; distribution.removeValue(forKey: "ProvisionedDevices")
        XCTAssertFalse(LocalBatch1QA.permitsDevelopmentProfile(distribution, now: now))
        for (key, value) in [("get-task-allow", false as Any), ("application-identifier", "wrong.app" as Any),
                             ("com.apple.developer.team-identifier", "wrong-team" as Any)] {
            var profile = valid
            var entitlements = valid["Entitlements"] as! [String: Any]
            entitlements[key] = value; profile["Entitlements"] = entitlements
            XCTAssertFalse(LocalBatch1QA.permitsDevelopmentProfile(profile, now: now))
        }
    }

    func testOrdinaryProductionBuildNeverAcceptsLocalFixtureArguments() {
#if !KAIRO_LOCAL_BATCH1_QA
        let configuration = AppConfiguration(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production), keychainService: "synthetic")
        XCTAssertFalse(LocalBatch1QA.isEnabled(configuration: configuration,
            arguments: [LocalBatch1QA.argument, UITestLaunchConfiguration.enabledArgument]))
#endif
    }
}
