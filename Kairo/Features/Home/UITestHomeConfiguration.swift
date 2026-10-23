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
              let rawValue = environment[stateEnvironmentKey],
              let kind = HomeOverviewFixtureKind(rawValue: rawValue) else {
            return UITestHomeConfiguration(state: nil)
        }

        if environment["KAIRO_UI_TEST_PROFILE_TASKS"] == "1",
           case .populated(let fixture) = HomeOverviewState.populatedFixture().phase {
            let targets: [ProfileEditTarget] = [.headline, .currentRole, .industry]
            let titles = ["Add your professional headline", "Add your current role", "Add your industry"]
            return UITestHomeConfiguration(state: HomeOverviewState(header: .fixture, phase: .populated(.init(
                dataSourceLabel: fixture.dataSourceLabel, trustScore: fixture.trustScore,
                recommendation: .init(title: titles[0], supportingCopy: "Update your profile", actionTitle: "Continue profile",
                    destinationTab: .more, profileTarget: .headline),
                trustTasks: targets.enumerated().map { index, target in
                    .init(priority: index + 1, systemImage: "pencil", title: titles[index], valueStatement: "Update your profile",
                        status: .pending, destinationTab: .more, profileTarget: target)
                }, verificationRequests: [], profileCompletion: fixture.profileCompletion, recentActivity: [], recentPassportViews: []))))
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
