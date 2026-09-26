import Foundation

nonisolated struct UITestGuidedTourConfiguration: Equatable, Sendable {
    enum Scenario: String, Sendable {
        case pending
        case completed
    }

    static let scenarioEnvironmentKey = "KAIRO_UI_TEST_GUIDED_TOUR"
    static let accountEnvironmentKey = "KAIRO_UI_TEST_GUIDED_TOUR_ACCOUNT"
    static let resetEnvironmentKey = "KAIRO_UI_TEST_GUIDED_TOUR_RESET"
    static let unavailableTargetEnvironmentKey = "KAIRO_UI_TEST_GUIDED_TOUR_UNAVAILABLE_TARGET"

    let scenario: Scenario?
    let accountID: String?
    let resetsAccountState: Bool
    let unavailableTarget: GuidedTourTarget?

    static let disabled = UITestGuidedTourConfiguration(
        scenario: nil,
        accountID: nil,
        resetsAccountState: false,
        unavailableTarget: nil
    )

    @MainActor
    static func current(
        launchConfiguration: UITestLaunchConfiguration,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> UITestGuidedTourConfiguration {
        guard launchConfiguration.isEnabled,
              let scenario = Scenario(rawValue: environment[scenarioEnvironmentKey] ?? ""),
              let accountID = environment[accountEnvironmentKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accountID.isEmpty else {
            return .disabled
        }

        return UITestGuidedTourConfiguration(
            scenario: scenario,
            accountID: accountID,
            resetsAccountState: environment[resetEnvironmentKey] == "1",
            unavailableTarget: GuidedTourTarget(
                rawValue: environment[unavailableTargetEnvironmentKey] ?? ""
            )
        )
    }

    @MainActor
    func prepare(_ preferences: any GuidedTourPreferenceStoring) {
        guard let scenario, let accountID else { return }
        if resetsAccountState {
            preferences.removeState(for: accountID)
        }
        switch scenario {
        case .pending:
            preferences.markPendingIfEligible(for: accountID)
        case .completed:
            preferences.markCompleted(for: accountID)
        }
    }
}
