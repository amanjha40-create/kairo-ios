import Foundation
import XCTest
@testable import Kairo

final class AppConfigurationTests: XCTestCase {
    func test_resolvesBundleDrivenDemoDefaults() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Demo",
                AppConfiguration.InfoPlistKey.environment: "development",
                AppConfiguration.InfoPlistKey.demoMode: "YES"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.buildConfiguration, .demo)
        XCTAssertEqual(configuration.environment, .development)
        XCTAssertTrue(configuration.isDemoModeEnabled)
    }

    func test_runtimeOverridesWinOverBundleDefaults() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "production",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [
                AppConfiguration.environmentVariable: "staging",
                AppConfiguration.demoModeVariable: "true"
            ]
        )

        XCTAssertEqual(configuration.buildConfiguration, .production)
        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertTrue(configuration.isDemoModeEnabled)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://staging-api.kairo.invalid"))
    }

    func test_developmentBuildDefaultsToLiveModeUnlessDemoConfigured() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Development",
                AppConfiguration.InfoPlistKey.environment: "development",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.buildConfiguration, .development)
        XCTAssertEqual(configuration.environment, .development)
        XCTAssertFalse(configuration.isDemoModeEnabled)
    }
}
