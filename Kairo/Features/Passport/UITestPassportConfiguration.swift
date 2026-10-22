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

#if KAIRO_LOCAL_BATCH1_QA
        if arguments.contains(LocalBatch1QA.argument),
           environment["KAIRO_POSTBUILD8_LONG_IDENTITY"] == "1",
           case .populated(let content) = state.phase {
            return UITestPassportConfiguration(state: .init(header: state.header, phase: .populated(.init(
                dataSourceLabel: content.dataSourceLabel, trustScore: content.trustScore,
                strengthSummary: content.strengthSummary,
                identity: .init(fullName: "Synthetic layout candidate",
                    emailAddress: "synthetic.long.identity.wrapping@example.invalid (not verified)",
                    mobileNumber: "+00 00000 00000 (not verified)", status: .notVerified, lastVerifiedDate: "Not verified"),
                employment: content.employment, education: content.education,
                certifications: content.certifications, skills: content.skills, projects: content.projects,
                portfolio: content.portfolio, timeline: content.timeline))))
        }
#endif
        return UITestPassportConfiguration(state: state)
    }
}
