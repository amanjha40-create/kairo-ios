import Foundation

struct UITestPassportConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_PASSPORT_STATE"

    let state: PassportOverviewState?

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestPassportConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              launchConfiguration.route == .demoHome,
              let rawValue = environment[stateEnvironmentKey],
              let kind = PassportOverviewFixtureKind(rawValue: rawValue) else {
            return UITestPassportConfiguration(state: nil)
        }

        let state: PassportOverviewState = switch kind {
        case .populated:
            .populatedFixture()
        case .empty:
            .emptyFixture()
        case .loading:
            .loadingFixture()
        case .error:
            .errorFixture()
        }

        return UITestPassportConfiguration(state: state)
    }
}
