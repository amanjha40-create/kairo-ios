import Foundation

struct UITestCareerConfiguration {
    static let stateEnvironmentKey = "KAIRO_UI_TEST_CAREER_STATE"

    let state: CareerOverviewState?

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestCareerConfiguration {
        let launchConfiguration = UITestLaunchConfiguration.current(
            arguments: arguments,
            environment: environment
        )

        guard launchConfiguration.isEnabled,
              launchConfiguration.route == .demoHome,
              let rawValue = environment[stateEnvironmentKey],
              let kind = CareerOverviewFixtureKind(rawValue: rawValue) else {
            return UITestCareerConfiguration(state: nil)
        }

        let state: CareerOverviewState = switch kind {
        case .populated:
            .populatedFixture()
        case .empty:
            .emptyFixture()
        case .loading:
            .loadingFixture()
        case .error:
            .errorFixture()
        }

        return UITestCareerConfiguration(state: state)
    }
}
