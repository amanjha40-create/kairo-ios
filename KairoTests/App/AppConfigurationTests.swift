import Foundation
import XCTest
@testable import Kairo

@MainActor
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

    func test_productionBuildIgnoresEnvironmentAndDemoProcessOverrides() {
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
        XCTAssertEqual(configuration.environment, .production)
        XCTAssertFalse(configuration.isDemoModeEnabled)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://api.kairoid.com/api/v1"))
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

    func test_productionBuildIgnoresDevelopmentEnvironmentOverride() {
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
        XCTAssertEqual(configuration.environment, .production)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://api.kairoid.com/api/v1"))
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

    func test_productionBuildIgnoresEmbeddedDemoFlagAndBuildOverride() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "staging",
                AppConfiguration.InfoPlistKey.demoMode: "YES"
            ],
            environmentVariables: [
                AppConfiguration.buildConfigurationVariable: "Demo",
                AppConfiguration.environmentVariable: "development",
                AppConfiguration.demoModeVariable: "true"
            ]
        )

        XCTAssertEqual(configuration.buildConfiguration, .production)
        XCTAssertEqual(configuration.environment, .production)
        XCTAssertFalse(configuration.isDemoModeEnabled)
        XCTAssertEqual(configuration.apiBaseURL, URL(string: "https://api.kairoid.com/api/v1"))
        XCTAssertFalse(configuration.apiBaseURL.absoluteString.contains("localhost"))
        XCTAssertFalse(configuration.apiBaseURL.absoluteString.contains("staging"))
    }

    func test_productionBuildDisablesUITestLaunchConfiguration() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "production",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )
        let requested = UITestLaunchConfiguration(
            isEnabled: true,
            route: .demoHome,
            onboardingStep: .chooseStart,
            disablesAnimations: true
        )

        let validated = requested.validated(for: configuration)

        XCTAssertFalse(validated.isEnabled)
        XCTAssertEqual(validated.route, .onboarding)
        XCTAssertNil(validated.onboardingStep)
        XCTAssertFalse(validated.disablesAnimations)
    }

    func test_productionDependenciesCannotResolveDemoOrUITestFixtures() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "staging",
                AppConfiguration.InfoPlistKey.demoMode: "YES"
            ],
            environmentVariables: [
                AppConfiguration.buildConfigurationVariable: "Demo",
                AppConfiguration.environmentVariable: "development",
                AppConfiguration.demoModeVariable: "true"
            ]
        )
        let requestedUITestConfiguration = UITestLaunchConfiguration(
            isEnabled: true,
            route: .demoHome,
            onboardingStep: .chooseStart,
            disablesAnimations: true
        )

        let dependencies = AppDependencies.make(
            configuration: configuration,
            uiTestConfiguration: requestedUITestConfiguration
        )

        XCTAssertTrue(dependencies.networkClient is URLSessionNetworkClient)
        XCTAssertTrue(dependencies.tokenStore is KeychainTokenStore)
        XCTAssertTrue(dependencies.authService is AuthService)
        XCTAssertTrue(dependencies.manualProfileService is ManualProfileService)
        XCTAssertTrue(dependencies.resumeImportService is ResumeImportService)
        XCTAssertTrue(dependencies.trustScoreService is TrustScoreService)
        XCTAssertTrue(dependencies.careerDocumentService is CareerDocumentService)
        XCTAssertTrue(dependencies.passportShareService is PassportShareService)
        XCTAssertTrue(dependencies.passportPDFExportService is PassportPDFExportService)
        XCTAssertTrue(dependencies.candidateNotificationService is CandidateNotificationService)
    }

    func test_releaseLegalDestinationsUseCanonicalHTTPSPages() {
        let configuration = AppConfiguration.resolve(
            bundleValues: [
                AppConfiguration.InfoPlistKey.buildConfiguration: "Production",
                AppConfiguration.InfoPlistKey.environment: "production",
                AppConfiguration.InfoPlistKey.demoMode: "NO"
            ],
            environmentVariables: [:]
        )

        XCTAssertEqual(configuration.termsOfServiceURL, URL(string: "https://kairoid.com/terms"))
        XCTAssertEqual(configuration.privacyPolicyURL, URL(string: "https://kairoid.com/privacy"))
        XCTAssertEqual(configuration.termsOfServiceURL?.scheme, "https")
        XCTAssertEqual(configuration.privacyPolicyURL?.scheme, "https")
    }
}
