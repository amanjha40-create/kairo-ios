import Foundation

enum UITestLaunchRoute: String {
    case onboarding
    case demoHome
}

struct UITestLaunchConfiguration {
    static let enabledArgument = "-KAIRO_UI_TESTING"
    static let routeEnvironmentKey = "KAIRO_UI_TEST_ROUTE"
    static let onboardingStepEnvironmentKey = "KAIRO_UI_TEST_ONBOARDING_STEP"
    static let disableAnimationsEnvironmentKey = "KAIRO_UI_TEST_DISABLE_ANIMATIONS"

    let isEnabled: Bool
    let route: UITestLaunchRoute
    let onboardingStep: OnboardingStep?
    let disablesAnimations: Bool

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestLaunchConfiguration {
        let isEnabled = arguments.contains(enabledArgument)
        let route = UITestLaunchRoute(rawValue: environment[routeEnvironmentKey] ?? "") ?? .onboarding
        let onboardingStep = OnboardingStep(rawValue: environment[onboardingStepEnvironmentKey] ?? "")

        return UITestLaunchConfiguration(
            isEnabled: isEnabled,
            route: route,
            onboardingStep: isEnabled ? onboardingStep : nil,
            disablesAnimations: isEnabled && environment[disableAnimationsEnvironmentKey] != "0"
        )
    }
}

enum AppBuildConfiguration: String, CaseIterable, Sendable {
    case development = "Development"
    case staging = "Staging"
    case demo = "Demo"
    case production = "Production"

    init(rawValue: String?) {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development":
            self = .development
        case "staging":
            self = .staging
        case "demo":
            self = .demo
        case "production":
            self = .production
        default:
            self = .development
        }
    }

    var defaultEnvironment: AppEnvironment {
        switch self {
        case .development, .demo:
            .development
        case .staging:
            .staging
        case .production:
            .production
        }
    }

    var isDemoModeEnabledByDefault: Bool {
        self == .demo
    }
}

enum AppEnvironment: String, CaseIterable, Codable, Sendable {
    case development
    case staging
    case production

    init(rawValue: String?) {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development", "dev":
            self = .development
        case "staging", "stage":
            self = .staging
        case "production", "prod":
            self = .production
        default:
            self = .development
        }
    }

    var displayName: String {
        switch self {
        case .development: "Development"
        case .staging: "Staging"
        case .production: "Production"
        }
    }
}

struct AppConfiguration: Equatable, Sendable {
    enum InfoPlistKey {
        static let buildConfiguration = "KAIROBuildConfiguration"
        static let environment = "KAIROAppEnvironment"
        static let demoMode = "KAIRODemoMode"
    }

    static let environmentVariable = "KAIRO_APP_ENVIRONMENT"
    static let demoModeVariable = "KAIRO_DEMO_MODE"
    static let buildConfigurationVariable = "KAIRO_BUILD_CONFIGURATION"
    nonisolated static let resumeImportConsentVersion = "resume_processing_v1"

    let buildConfiguration: AppBuildConfiguration
    let environment: AppEnvironment
    let isDemoModeEnabled: Bool
    let apiBaseURL: URL
    let keychainService: String

    var supportEmailAddress: String {
        "support@kairoid.com"
    }

    var helpCenterURL: URL? {
        nil
    }

    var termsOfServiceURL: URL? {
        nil
    }

    var privacyPolicyURL: URL? {
        nil
    }

    var cookiePolicyURL: URL? {
        nil
    }

    var currentResumeImportConsentVersion: String {
        Self.resumeImportConsentVersion
    }

    static func resolve(
        bundleValues: [String: Any] = Bundle.main.infoDictionary ?? [:],
        environmentVariables: [String: String] = ProcessInfo.processInfo.environment,
        defaultBuildConfiguration: AppBuildConfiguration? = nil
    ) -> AppConfiguration {
        let buildConfiguration: AppBuildConfiguration

        if let override = environmentVariables[buildConfigurationVariable] {
            buildConfiguration = AppBuildConfiguration(rawValue: override)
        } else if let defaultBuildConfiguration {
            buildConfiguration = defaultBuildConfiguration
        } else {
            buildConfiguration = AppBuildConfiguration(
                rawValue: bundleValues[InfoPlistKey.buildConfiguration] as? String
            )
        }

        let embeddedEnvironment = resolveEmbeddedEnvironment(
            bundleValue: bundleValues[InfoPlistKey.environment] as? String,
            buildConfiguration: buildConfiguration
        )

        let environment: AppEnvironment

        if let rawEnvironment = environmentVariables[environmentVariable] {
            environment = AppEnvironment(rawValue: rawEnvironment)
        } else {
            environment = embeddedEnvironment
        }

        let isDemoModeEnabled = resolveDemoMode(
            bundleValue: bundleValues[InfoPlistKey.demoMode] as? String,
            rawValue: environmentVariables[demoModeVariable],
            buildConfiguration: buildConfiguration
        )

        return AppConfiguration(
            buildConfiguration: buildConfiguration,
            environment: environment,
            isDemoModeEnabled: isDemoModeEnabled,
            apiBaseURL: APIConfiguration.make(for: environment).baseURL,
            keychainService: "com.kairoid.Kairo.\(environment.rawValue)"
        )
    }

    private static func resolveDemoMode(
        bundleValue: String?,
        rawValue: String?,
        buildConfiguration: AppBuildConfiguration
    ) -> Bool {
        if let rawValue, let parsed = parseBool(rawValue) {
            return parsed
        }

        if let bundleValue, let parsed = parseBool(bundleValue) {
            return parsed
        }

        return buildConfiguration.isDemoModeEnabledByDefault
    }

    private static func resolveEmbeddedEnvironment(
        bundleValue: String?,
        buildConfiguration: AppBuildConfiguration
    ) -> AppEnvironment {
        guard let bundleValue else {
            return buildConfiguration.defaultEnvironment
        }

        switch bundleValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development", "dev":
            return .development
        case "staging", "stage":
            return .staging
        case "production", "prod":
            return .production
        default:
            return buildConfiguration.defaultEnvironment
        }
    }

    private static func parseBool(_ rawValue: String) -> Bool? {
        switch rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y":
            true
        case "0", "false", "no", "n":
            false
        default:
            nil
        }
    }

}
