import XCTest
@testable import Kairo

final class PassportCreatedStateTests: XCTestCase {
    func test_completedStateProvidesExpectedSummaryRows() {
        let state = PassportCreatedState.completed

        XCTAssertEqual(state.summaryRows.map(\.title), [
            "Identity",
            "Email",
            "Mobile",
            "Profile",
            "Trust Passport"
        ])
        XCTAssertEqual(state.summaryRows.map(\.status), [
            .verified,
            .verified,
            .verified,
            .created,
            .active
        ])
    }

    func test_completedStateUsesTrustScorePlaceholderMessage() {
        let state = PassportCreatedState.completed

        XCTAssertEqual(
            state.trustScoreMessage,
            "Trust Score will appear after your first professional verification."
        )
        XCTAssertEqual(state.reviewDestination, .passport)
    }

    func test_onboardingFlowStateExposesSharedPassportCreatedStateAcrossBranches() {
        var resumeFlow = OnboardingFlowState()
        resumeFlow.chooseStartState.select(.importResume)

        var manualFlow = OnboardingFlowState()
        manualFlow.chooseStartState.select(.buildProfileManually)

        XCTAssertEqual(resumeFlow.passportCreatedState, manualFlow.passportCreatedState)
        XCTAssertEqual(resumeFlow.passportCreatedState, .completed)
    }
}
