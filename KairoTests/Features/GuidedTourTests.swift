import Foundation
import XCTest
@testable import Kairo

@MainActor
final class GuidedTourTests: XCTestCase {
    func testFloatingTabLayersResolveToFiveActualSlots() {
        let slots = (0..<5).map { CGRect(x: 25 + $0 * 70, y: 795, width: 78, height: 54) }
        XCTAssertEqual(GuidedTourTargetResolver.orderedTabFrames(Array((slots + slots).reversed()), expectedCount: 5), slots)
        XCTAssertEqual(GuidedTourTargetResolver.orderedTabFrames(slots, expectedCount: 5), slots)
        XCTAssertNil(GuidedTourTargetResolver.orderedTabFrames(Array(slots.dropLast()), expectedCount: 5))
        XCTAssertNil(GuidedTourTargetResolver.orderedTabFrames(slots + [CGRect(x: 12, y: 700, width: 40, height: 40)], expectedCount: 5))
    }

    func testNewEligibleCandidateAccountBecomesPendingOnReadyHome() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        XCTAssertEqual(coordinator.currentStep, .trustScore)
    }

    func testBackendUserRoleIsTreatedAsAuthenticatedCandidateAccount() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        coordinator.updateContext(accountID: "account-a", role: "user", isHomeSelected: true)
        coordinator.setHomeReady(true)
        XCTAssertEqual(coordinator.currentStep, .trustScore)
    }

    func testOnboardingIncompleteDoesNotPresentTour() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        coordinator.updateContext(accountID: "account-a", role: "candidate", isHomeSelected: true)
        coordinator.setHomeReady(false)
        XCTAssertNil(coordinator.currentStep)
    }

    func testCompletedAccountDoesNotPresentTour() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markCompleted(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        XCTAssertNil(coordinator.currentStep)
    }

    func testSkippedAccountUsesAndroidTerminalSemanticsAndDoesNotPresentAgain() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.skip()
        makeHomeReady(coordinator, accountID: "account-a")
        XCTAssertEqual(preferences.status(for: "account-a"), .completed)
        XCTAssertNil(coordinator.currentStep)
    }

    func testDifferentAccountRemainsIndependentlyEligible() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        preferences.markPendingIfEligible(for: "account-b")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.complete()
        makeHomeReady(coordinator, accountID: "account-b")
        XCTAssertEqual(preferences.status(for: "account-a"), .completed)
        XCTAssertEqual(coordinator.currentStep, .trustScore)
    }

    func testSequenceContainsExactlyFiveAndroidApprovedTargets() {
        XCTAssertEqual(GuidedTourStep.allCases.count, 5)
        XCTAssertEqual(
            GuidedTourStep.allCases.map(\.target),
            [.trustScore, .passport, .career, .verify, .more]
        )
    }

    func testNextProgressesWithoutNavigatingAwayFromHome() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.advance()
        XCTAssertEqual(coordinator.currentStep, .passport)
        coordinator.advance()
        XCTAssertEqual(coordinator.currentStep, .career)
    }

    func testBackMovesWithinTour() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.advance()
        coordinator.moveBack()
        XCTAssertEqual(coordinator.currentStep, .trustScore)
    }

    func testFinalActionPersistsCompletionAndDismisses() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        GuidedTourStep.allCases.dropLast().forEach { _ in coordinator.advance() }
        XCTAssertEqual(coordinator.currentStep, .more)
        coordinator.advance()
        XCTAssertNil(coordinator.currentStep)
        XCTAssertEqual(preferences.status(for: "account-a"), .completed)
    }

    func testSkipPersistsTerminalStateImmediately() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.advance()
        coordinator.skip()
        XCTAssertNil(coordinator.currentStep)
        XCTAssertEqual(preferences.status(for: "account-a"), .completed)
    }

    func testCompletionDoesNotWriteTwice() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.complete()
        coordinator.complete()
        XCTAssertEqual(preferences.completionWrites, 1)
    }

    func testAppRestartRestartsPendingTourAtFirstStep() {
        let preferences = TestGuidedTourPreferences()
        preferences.markPendingIfEligible(for: "account-a")
        let first = GuidedTourCoordinator(preferences: preferences, testConfiguration: .disabled)
        makeHomeReady(first, accountID: "account-a")
        first.advance()
        XCTAssertEqual(first.currentStep, .passport)

        let restarted = GuidedTourCoordinator(preferences: preferences, testConfiguration: .disabled)
        makeHomeReady(restarted, accountID: "account-a")
        XCTAssertEqual(restarted.currentStep, .trustScore)
    }

    func testLogoutAndLoginContextDoesNotLeakAnotherAccountState() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        preferences.markPendingIfEligible(for: "account-b")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.complete()
        coordinator.updateContext(accountID: nil, role: nil, isHomeSelected: false)
        XCTAssertNil(coordinator.currentStep)
        makeHomeReady(coordinator, accountID: "account-b")
        XCTAssertEqual(coordinator.currentStep, .trustScore)
    }

    func testLeavingHomeSuppressesOverlayWithoutManufacturingCompletion() {
        let (coordinator, preferences) = makeCoordinator()
        preferences.markPendingIfEligible(for: "account-a")
        makeHomeReady(coordinator, accountID: "account-a")
        coordinator.updateContext(accountID: "account-a", role: "candidate", isHomeSelected: false)
        XCTAssertNil(coordinator.currentStep)
        XCTAssertEqual(preferences.status(for: "account-a"), .pending)
    }

    func testExpectedTargetPerStep() {
        XCTAssertEqual(GuidedTourStep.trustScore.target, .trustScore)
        XCTAssertEqual(GuidedTourStep.passport.target, .passport)
        XCTAssertEqual(GuidedTourStep.career.target, .career)
        XCTAssertEqual(GuidedTourStep.verify.target, .verify)
        XCTAssertEqual(GuidedTourStep.more.target, .more)
    }

    func testMissingTargetFailsClosed() {
        XCTAssertNil(GuidedTourTargetResolver.frame(
            for: .passport,
            homeFrames: [:],
            tabFrames: [.career: CGRect(x: 0, y: 700, width: 60, height: 60)]
        ))
    }

    func testResolverNeverFallsBackToWrongTarget() {
        let passport = CGRect(x: 20, y: 300, width: 320, height: 60)
        let career = CGRect(x: 72, y: 700, width: 72, height: 60)
        XCTAssertEqual(GuidedTourTargetResolver.frame(
            for: .passport,
            homeFrames: [.passport: passport],
            tabFrames: [.career: career]
        ), passport)
        XCTAssertEqual(GuidedTourTargetResolver.frame(
            for: .career,
            homeFrames: [.passport: passport],
            tabFrames: [.career: career]
        ), career)
    }

    func testWindowTabFrameConvertsToOverlayOriginWithoutSafeAreaDrift() {
        let tab = CGRect(x: 172, y: 820, width: 70, height: 58)
        for origin in [CGPoint.zero, CGPoint(x: 0, y: 48), CGPoint(x: 12, y: 59)] {
            let local = GuidedTourTargetResolver.overlayFrame(windowFrame: tab, overlayOrigin: origin)
            XCTAssertEqual(local.offsetBy(dx: origin.x, dy: origin.y), tab)
            XCTAssertEqual(local.size, tab.size)
        }
    }

    func testAllFiveTargetsResolveInOneOverlayCoordinateSpace() {
        let origin = CGPoint(x: 0, y: 48)
        let home: [GuidedTourTarget: CGRect] = [
            .trustScore: CGRect(x: 16, y: 124, width: 382, height: 256),
            .passport: CGRect(x: 16, y: 396, width: 382, height: 60)
        ]
        let tabs: [GuidedTourTarget: CGRect] = [
            .career: CGRect(x: 94, y: 820, width: 70, height: 58),
            .verify: CGRect(x: 172, y: 820, width: 70, height: 58),
            .more: CGRect(x: 326, y: 820, width: 70, height: 58)
        ]
        let localHome = home.mapValues { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
        let localTabs = tabs.mapValues {
            GuidedTourTargetResolver.overlayFrame(windowFrame: $0, overlayOrigin: origin)
        }
        for step in GuidedTourStep.allCases {
            let expected = home[step.target] ?? tabs[step.target]
            let resolved = GuidedTourTargetResolver.frame(for: step.target, homeFrames: localHome, tabFrames: localTabs)
            XCTAssertEqual(resolved?.offsetBy(dx: origin.x, dy: origin.y), expected)
        }
    }

    func testCoachPlacementUsesAvailableSpaceOnMultipleViewportSizes() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 393, height: 852), CGSize(width: 430, height: 932)] {
            let viewport = CGRect(origin: .zero, size: size)
            XCTAssertEqual(GuidedTourLayout.placement(
                target: CGRect(x: 12, y: 100, width: size.width - 24, height: 150),
                viewport: viewport
            ), .below)
            XCTAssertEqual(GuidedTourLayout.placement(
                target: CGRect(x: 0, y: size.height - 90, width: size.width / 5, height: 80),
                viewport: viewport
            ), .above)
        }
    }

    func testCanonicalTitlesAndExactAndroidCopy() {
        XCTAssertEqual(GuidedTourStep.allCases.map(\.title), [
            "Your Trust Score",
            "Your Trust Passport",
            "Build your career record",
            "Get important records verified",
            "Everything else is here"
        ])
        let published = GuidedTourStep.allCases.map { "\($0.title) \($0.body)" }.joined(separator: " ")
        for required in ["Trust Score", "Trust Passport", "Career", "More", "KairoID", "Help Center"] {
            XCTAssertTrue(published.localizedCaseInsensitiveContains(required), "Missing \(required)")
        }
        XCTAssertEqual(GuidedTourStep.verify.target.rawValue, "verify")
        XCTAssertFalse(published.contains("Documents tab"))
        XCTAssertFalse(published.contains("Trust Profile"))
    }

    func testPreferencesHashAccountIdentifierAndPreserveCompletionsWhenClearingPending() throws {
        let suite = "GuidedTourTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preferences = GuidedTourPreferences(defaults: defaults)
        preferences.markPendingIfEligible(for: "private-account-id")
        preferences.markCompleted(for: "completed-account-id")
        preferences.clearPendingStates()
        XCTAssertNil(preferences.status(for: "private-account-id"))
        XCTAssertEqual(preferences.status(for: "completed-account-id"), .completed)
        XCTAssertFalse(defaults.dictionaryRepresentation().keys.contains { $0.contains("private-account-id") })
    }

    private func makeCoordinator() -> (GuidedTourCoordinator, TestGuidedTourPreferences) {
        let preferences = TestGuidedTourPreferences()
        return (
            GuidedTourCoordinator(preferences: preferences, testConfiguration: .disabled),
            preferences
        )
    }

    private func makeHomeReady(_ coordinator: GuidedTourCoordinator, accountID: String) {
        coordinator.updateContext(accountID: accountID, role: "candidate", isHomeSelected: true)
        coordinator.setHomeReady(true)
    }
}

@MainActor
private final class TestGuidedTourPreferences: GuidedTourPreferenceStoring {
    private var states: [String: GuidedTourAccountStatus] = [:]
    private(set) var completionWrites = 0

    func status(for accountID: String) -> GuidedTourAccountStatus? { states[accountID] }

    func markPendingIfEligible(for accountID: String) {
        if states[accountID] != .completed { states[accountID] = .pending }
    }

    func markCompleted(for accountID: String) {
        guard states[accountID] != .completed else { return }
        states[accountID] = .completed
        completionWrites += 1
    }

    func clearPendingStates() {
        states = states.filter { $0.value == .completed }
    }

    func removeState(for accountID: String) {
        states.removeValue(forKey: accountID)
    }
}
