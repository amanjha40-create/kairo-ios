import XCTest
@testable import Kairo

final class AppConfigurationV1DestinationTests: XCTestCase {
    func test_helpAndSupportUseCanonicalPublicDestinations() {
        let configuration = AppConfiguration(
            buildConfiguration: .staging,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.destinations"
        )

        XCTAssertEqual(configuration.helpCenterURL?.absoluteString, "https://kairoid.com/help-center")
        XCTAssertEqual(configuration.supportEmailAddress, "contact@kairoid.com")
        XCTAssertEqual(configuration.termsOfServiceURL?.absoluteString, "https://kairoid.com/terms")
        XCTAssertEqual(configuration.privacyPolicyURL?.absoluteString, "https://kairoid.com/privacy")
        XCTAssertNil(configuration.cookiePolicyURL)
    }
}
