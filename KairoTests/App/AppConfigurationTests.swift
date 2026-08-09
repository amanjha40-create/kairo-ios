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

    func test_processOverridesWinOverBundleDefaults() {
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
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://staging-api.kairoid.com/api/v1"))
    }

    func test_developmentBuildDefaultsToDevelopmentAPI() {
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
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "http://localhost:8000/api/v1"))
    }

    func test_stagingBuildDefaultsToStagingAPIWithoutProcessOverrides() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Staging",
                AppConfiguration.InfoPlistKey.environment: "staging",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.buildConfiguration, .staging)
        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertFalse(configuration.isDemoModeEnabled)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://staging-api.kairoid.com/api/v1"))
    }

    func test_productionBuildDefaultsToProductionAPIWithoutProcessOverrides() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "production",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.buildConfiguration, .production)
        XCTAssertEqual(configuration.environment, .production)
        XCTAssertFalse(configuration.isDemoModeEnabled)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://api.kairoid.com/api/v1"))
    }

    func test_invalidEmbeddedEnvironmentFallsBackToBuildConfigurationDefault() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Staging",
                AppConfiguration.InfoPlistKey.environment: "qa",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.buildConfiguration, .staging)
        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://staging-api.kairoid.com/api/v1"))
    }

    func test_missingEmbeddedEnvironmentFallsBackToBuildConfigurationDefault() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.buildConfiguration, .production)
        XCTAssertEqual(configuration.environment, .production)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://api.kairoid.com/api/v1"))
    }

    func test_processEnvironmentOverrideWinsOverEmbeddedEnvironment() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "production",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [
                AppConfiguration.environmentVariable: "development"
            ]
        )

        XCTAssertEqual(configuration.buildConfiguration, .production)
        XCTAssertEqual(configuration.environment, .development)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "http://localhost:8000/api/v1"))
    }

    func test_demoOverrideRemainsIndependentFromEnvironment() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Staging",
                AppConfiguration.InfoPlistKey.environment: "staging",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [
                AppConfiguration.demoModeVariable: "true"
            ]
        )

        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertTrue(configuration.isDemoModeEnabled)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://staging-api.kairoid.com/api/v1"))
    }

    func test_buildConfigurationProcessOverrideCanSeedEmbeddedDefaults() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [:],
            environmentVariables: [
                AppConfiguration.buildConfigurationVariable: "Staging"
            ]
        )

        XCTAssertEqual(configuration.buildConfiguration, .staging)
        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertFalse(configuration.isDemoModeEnabled)
    }
}
