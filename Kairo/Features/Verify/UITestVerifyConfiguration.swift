import Foundation

struct UITestVerifyConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_VERIFY_STATE"

    let state: VerifyOverviewState?

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestVerifyConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              launchConfiguration.route == .demoHome,
              let rawValue = environment[stateEnvironmentKey],
              let kind = VerifyOverviewFixtureKind(rawValue: rawValue) else {
            return UITestVerifyConfiguration(state: nil)
        }

        let state: VerifyOverviewState = switch kind {
        case .populated:
            .populatedFixture()
        case .empty:
            .emptyFixture()
        case .loading:
            .loadingFixture()
        case .error:
            .errorFixture()
        }

        return UITestVerifyConfiguration(state: state)
    }
}
