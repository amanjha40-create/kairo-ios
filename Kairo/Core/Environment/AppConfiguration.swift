import Foundation

enum UITestLaunchRoute: String {
    case onboarding
    case demoHome
}

struct UITestLaunchConfiguration {
    static let enabledArgument = "-KAIRO_UI_TESTING"
    static let routeEnvironmentKey = "KAIRO_UI_TEST_ROUTE"
    static let disableAnimationsEnvironmentKey = "KAIRO_UI_TEST_DISABLE_ANIMATIONS"

    let isEnabled: Bool
    let route: UITestLaunchRoute
    let disablesAnimations: Bool

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestLaunchConfiguration {
        let isEnabled = arguments.contains(enabledArgument)
        let route = UITestLaunchRoute(rawValue: environment[routeEnvironmentKey] ?? "") ?? .onboarding

        return UITestLaunchConfiguration(
            isEnabled: isEnabled,
            route: route,
            disablesAnimations: isEnabled && environment[disableAnimationsEnvironmentKey] != "0"
        )
    }
}

enum AppBuildConfiguration: String, CaseIterable, Sendable {
    case development = "Development"
    case demo = "Demo"
    case production = "Production"

    init(rawValue: String?) {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "development":
            self = .development
        case "demo":
            self = .demo
        case "production":
            self = .production
        default:
            self = .development
        }
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

    let buildConfiguration: AppBuildConfiguration
    let environment: AppEnvironment
    let isDemoModeEnabled: Bool
    let apiBaseURL: URL
    let keychainService: String

    static func resolve(
        bundleValues: [String: Any] = Bundle.main.infoDictionary ?? [:],
        environmentVariables: [String: String] = ProcessInfo.processInfo.environment,
        defaultBuildConfiguration: AppBuildConfiguration? = nil
    ) -> AppConfiguration {
        let buildConfiguration: AppBuildConfiguration

        if let override = environmentVariables[InfoPlistKey.buildConfiguration] {
            buildConfiguration = AppBuildConfiguration(rawValue: override)
        } else if let defaultBuildConfiguration {
            buildConfiguration = defaultBuildConfiguration
        } else {
            buildConfiguration = AppBuildConfiguration(
                rawValue: bundleValues[InfoPlistKey.buildConfiguration] as? String
            )
        }

        let defaultEnvironment = AppEnvironment(
            rawValue: bundleValues[InfoPlistKey.environment] as? String
        )

        let environment: AppEnvironment

        if let rawEnvironment = environmentVariables[environmentVariable] {
            environment = AppEnvironment(rawValue: rawEnvironment)
        } else {
            environment = defaultEnvironment
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
            apiBaseURL: baseURL(for: environment),
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

        return buildConfiguration == .demo
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

    private static func baseURL(for environment: AppEnvironment) -> URL {
        switch environment {
        case .development:
            URL(string: "https://dev-api.kairo.invalid")!
        case .staging:
            URL(string: "https://staging-api.kairo.invalid")!
        case .production:
            URL(string: "https://api.kairo.invalid")!
        }
    }
}
