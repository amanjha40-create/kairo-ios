import Foundation

struct UITestMoreConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_MORE_STATE"

    let state: MoreOverviewState?

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestMoreConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              launchConfiguration.route == .demoHome,
              let rawValue = environment[stateEnvironmentKey],
              let kind = MoreOverviewFixtureKind(rawValue: rawValue) else {
            return UITestMoreConfiguration(state: nil)
        }

        let state: MoreOverviewState = switch kind {
        case .populated:
            .populatedFixture()
        case .loading:
            .loadingFixture()
        case .error:
            .errorFixture()
        }

        return UITestMoreConfiguration(state: state)
    }
}
