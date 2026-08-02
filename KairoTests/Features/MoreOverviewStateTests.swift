import XCTest
@testable import Kairo

@MainActor
final class MoreOverviewStateTests: XCTestCase {
    func test_populatedFixtureExposesExpectedSectionsAndAccountSummary() {
        let state = MoreOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(state.accountSummary.name, "Aarav Mehta")
        XCTAssertEqual(state.accountSummary.emailAddress, "aarav@example.com")
        XCTAssertEqual(content.visibleSections, [
            .account,
            .preferences,
            .privacyData,
            .helpSupport,
            .about
        ])
        XCTAssertEqual(content.accountRows.map(\.title), [
            "Personal information",
            "Login & security",
            "Connected accounts",
            "Sessions & devices"
        ])
        XCTAssertEqual(content.appVersion, "1.0.0 (1)")
    }

    func test_loadingAndErrorFixturesExposeExpectedPhases() {
        XCTAssertEqual(MoreOverviewState.loadingFixture().phase, .loading)

        guard case .error(let errorState) = MoreOverviewState.errorFixture().phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "More unavailable")
    }

    func test_notificationToggleUpdatesAreLocalAndDeterministic() {
        var state = MoreOverviewState.populatedFixture()

        state.setNotification(.verificationUpdates, isEnabled: false)
        state.setNotification(.productUpdates, isEnabled: true)

        XCTAssertFalse(state.preferences.notifications.verificationUpdates)
        XCTAssertTrue(state.preferences.notifications.productUpdates)
        XCTAssertTrue(state.preferences.notifications.passportViews)
    }

    func test_appearanceSelectionUpdatesLocally() {
        var state = MoreOverviewState.populatedFixture()

        state.selectAppearance(.dark)

        XCTAssertEqual(state.preferences.appearance, .dark)
    }

    func test_deleteAccountConfirmationStateCanBePresentedAndDismissed() {
        var state = MoreOverviewState.populatedFixture()

        state.presentConfirmation(.deleteAccount)
        XCTAssertEqual(state.pendingConfirmation, .deleteAccount)

        state.dismissConfirmation()
        XCTAssertNil(state.pendingConfirmation)
    }

    func test_signOutConfirmationStateCanBePresented() {
        var state = MoreOverviewState.populatedFixture()

        state.presentConfirmation(.signOut)

        XCTAssertEqual(state.pendingConfirmation, .signOut)
        XCTAssertNil(state.signOutResult)
    }

    func test_confirmingSignOutProducesLocalSignOutResult() {
        var state = MoreOverviewState.populatedFixture()
        state.presentConfirmation(.signOut)

        state.confirmPendingAction()

        XCTAssertNil(state.pendingConfirmation)
        XCTAssertEqual(state.signOutResult, .signedOutLocally)
    }

    func test_confirmingNonSignOutActionsDoesNotPretendWorkCompleted() {
        var state = MoreOverviewState.populatedFixture()
        state.presentConfirmation(.downloadMyData)

        state.confirmPendingAction()

        XCTAssertNil(state.pendingConfirmation)
        XCTAssertNil(state.signOutResult)
    }
}
