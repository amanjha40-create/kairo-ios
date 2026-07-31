import XCTest
@testable import Kairo

@MainActor
final class HomeOverviewStateTests: XCTestCase {
    func test_populatedFixtureExposesDemoTrustOverview() {
        let state = HomeOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(state.header.firstName, "Aarav")
        XCTAssertEqual(content.trustScore.score, 72)
        XCTAssertEqual(content.verificationRequests.count, 1)
        XCTAssertEqual(content.recentPassportViews.count, 1)
    }

    func test_emptyFixtureKeepsTrustScoreHonestAndRequestsEmpty() {
        let state = HomeOverviewState.emptyFixture()

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty state")
        }

        XCTAssertNil(content.trustScore.score)
        XCTAssertEqual(content.trustScore.status, "Trust Score coming soon")
        XCTAssertTrue(content.verificationRequests.isEmpty)
        XCTAssertTrue(content.recentPassportViews.isEmpty)
    }

    func test_loadingFixtureUsesLoadingPhase() {
        let state = HomeOverviewState.loadingFixture()

        XCTAssertEqual(state.phase, .loading)
    }

    func test_errorFixtureUsesErrorPhase() {
        let state = HomeOverviewState.errorFixture()

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "Home overview unavailable")
    }

    func test_visibleTrustTasksRespectPriorityOrderingAndThreeItemLimit() {
        let state = HomeOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(content.visibleTrustTasks.map(\.title), [
            "Verify current employment",
            "Add your highest education",
            "Add a professional certification"
        ])
    }

    func test_profileCompletionClampsPercentageIntoExpectedRange() {
        let low = HomeProfileCompletion(
            percentage: -12,
            supportingCopy: "Low",
            destinationTab: .career
        )
        let high = HomeProfileCompletion(
            percentage: 140,
            supportingCopy: "High",
            destinationTab: .career
        )

        XCTAssertEqual(low.percentage, 0)
        XCTAssertEqual(low.progress, 0)
        XCTAssertEqual(high.percentage, 100)
        XCTAssertEqual(high.progress, 1)
    }
}
