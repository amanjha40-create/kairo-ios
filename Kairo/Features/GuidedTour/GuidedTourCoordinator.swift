import Combine
import Foundation

@MainActor
final class GuidedTourCoordinator: ObservableObject {
    @Published private(set) var currentStep: GuidedTourStep?

    private let preferences: any GuidedTourPreferenceStoring
    private let fixtureAccountID: String?
    let unavailableTargetForTesting: GuidedTourTarget?
    private var liveAccountID: String?
    private var liveRole: String?
    private var isHomeSelected = false
    private var isHomeReady = false
    private var resolvedAccountID: String?

    init(
        preferences: any GuidedTourPreferenceStoring,
        testConfiguration: UITestGuidedTourConfiguration = .disabled
    ) {
        self.preferences = preferences
        fixtureAccountID = testConfiguration.accountID
        unavailableTargetForTesting = testConfiguration.unavailableTarget
        testConfiguration.prepare(preferences)
    }

    var isPresenting: Bool {
        currentStep != nil
    }

    func updateContext(accountID: String?, role: String?, isHomeSelected: Bool) {
        liveAccountID = accountID
        liveRole = role
        self.isHomeSelected = isHomeSelected
        evaluateEligibility()
    }

    func setHomeReady(_ ready: Bool) {
        guard isHomeReady != ready else { return }
        isHomeReady = ready
        evaluateEligibility()
    }

    func advance() {
        guard let currentStep else { return }
        if let next = currentStep.next {
            self.currentStep = next
        } else {
            complete()
        }
    }

    func moveBack() {
        guard let previous = currentStep?.previous else { return }
        currentStep = previous
    }

    func skip() {
        persistTerminalState()
    }

    func complete() {
        persistTerminalState()
    }

    private func evaluateEligibility() {
        let accountID = fixtureAccountID ?? normalized(liveAccountID)
        let candidateRoles = Set(["candidate", "user"])
        let isCandidate = fixtureAccountID != nil || candidateRoles.contains(liveRole?.lowercased() ?? "")

        if resolvedAccountID != accountID {
            currentStep = nil
            resolvedAccountID = accountID
        }

        guard let accountID,
              isCandidate,
              isHomeSelected,
              isHomeReady,
              preferences.status(for: accountID) == .pending else {
            currentStep = nil
            return
        }

        if currentStep == nil {
            currentStep = .trustScore
        }
    }

    private func persistTerminalState() {
        guard let accountID = resolvedAccountID, currentStep != nil else { return }
        preferences.markCompleted(for: accountID)
        currentStep = nil
    }

    private func normalized(_ accountID: String?) -> String? {
        guard let value = accountID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }
        return value
    }
}
