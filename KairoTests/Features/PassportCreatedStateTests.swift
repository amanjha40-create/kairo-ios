import XCTest
@testable import Kairo

final class PassportCreatedStateTests: XCTestCase {
    func test_completedStateUsesApprovedCompactContentAndRoutesDirectlyHome() {
        let state = PassportCreatedState.completed

        XCTAssertEqual(
            state.subtitle,
            "Identity and contact verification are complete."
        )
        XCTAssertEqual(
            state.title,
            "Your Trust Passport is ready."
        )
        XCTAssertEqual(
            state.supportingCopy,
            "Continue to Home and start building your professional record."
        )
        XCTAssertEqual(
            state.primaryActionTitle,
            "Continue to Home"
        )
        XCTAssertEqual(state.secondaryActionTitle, "")
        XCTAssertNil(state.reviewDestination)
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
