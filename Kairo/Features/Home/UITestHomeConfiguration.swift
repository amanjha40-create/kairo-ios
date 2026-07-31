import Foundation

struct UITestHomeConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_HOME_STATE"

    let state: HomeOverviewState?

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestHomeConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              launchConfiguration.route == .demoHome,
              let rawValue = environment[stateEnvironmentKey],
              let kind = HomeOverviewFixtureKind(rawValue: rawValue) else {
            return UITestHomeConfiguration(state: nil)
        }

        let state: HomeOverviewState = switch kind {
        case .populated:
            .populatedFixture()
        case .empty:
            .emptyFixture()
        case .loading:
            .loadingFixture()
        case .error:
            .errorFixture()
        }

        return UITestHomeConfiguration(state: state)
    }
}
