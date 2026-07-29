import XCTest
@testable import Kairo

final class ChooseStartStateTests: XCTestCase {
    func test_continueIsDisabledUntilSelectionIsMade() {
        let state = ChooseStartState()

        XCTAssertNil(state.selection)
        XCTAssertFalse(state.canContinue)
    }

    func test_selectingResumeEnablesContinue() {
        var state = ChooseStartState()

        state.select(.importResume)

        XCTAssertEqual(state.selection, .importResume)
        XCTAssertTrue(state.canContinue)
    }

    func test_selectingManualProfileReplacesPreviousSelection() {
        var state = ChooseStartState(selection: .importResume)

        state.select(.buildProfileManually)

        XCTAssertEqual(state.selection, .buildProfileManually)
        XCTAssertTrue(state.canContinue)
    }
}
