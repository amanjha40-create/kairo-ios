import XCTest
@testable import Kairo

@MainActor
final class VerifyOverviewStateTests: XCTestCase {
    func test_populatedFixtureGroupsRequestsIntoExpectedSections() {
        let state = VerifyOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(content.visibleSections, [
            .priorityAction,
            .pendingRequests,
            .inProgress,
            .completed,
            .suggestedNext
        ])
        XCTAssertEqual(content.pendingRequests.map(\.organization), [
            "BrightPath Technologies",
            "Welingkar Institute of Management"
        ])
        XCTAssertEqual(content.inProgressRequests.map(\.organization), [
            "Northstar Labs",
            "Welingkar Institute of Management"
        ])
        XCTAssertEqual(content.completedRequests.map(\.organization), [
            "BrightPath Technologies",
            "Aarav Mehta",
            "aarav@example.com"
        ])
    }

    func test_loadingEmptyAndErrorFixturesExposeExpectedPhases() {
        XCTAssertEqual(VerifyOverviewState.loadingFixture().phase, .loading)

        guard case .empty(let emptyContent) = VerifyOverviewState.emptyFixture().phase else {
            return XCTFail("Expected empty state")
        }

        XCTAssertEqual(emptyContent.title, "No verifications yet.")

        guard case .error(let errorState) = VerifyOverviewState.errorFixture().phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "Verify overview unavailable")
    }

    func test_defaultStateUsesExpectedDataSourceLabels() {
        guard case .populated(let demoContent) = VerifyOverviewState.default(isDemoMode: true).phase else {
            return XCTFail("Expected populated state")
        }

        guard case .populated(let previewContent) = VerifyOverviewState.default(isDemoMode: false).phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(demoContent.dataSourceLabel, "Demo data")
        XCTAssertEqual(previewContent.dataSourceLabel, "Preview data")
    }

    func test_statusDisplayOrderRemainsStable() {
        XCTAssertEqual(VerifyVerificationStatus.displayOrder, [
            .draft,
            .pendingSubjectAcceptance,
            .accepted,
            .pendingSubjectSubmission,
            .awaitingInformation,
            .awaitingSubjectCorrections,
            .pendingAdminReview,
            .pendingAdminReReview,
            .approvedForOrganizationVerification,
            .pendingOrganizationResolution,
            .pendingOrganizationAcceptance,
            .inProgress,
            .verified,
            .rejected,
            .cancelled,
            .expired
        ])
        XCTAssertTrue(VerifyVerificationStatus.pendingSubjectAcceptance.rank < VerifyVerificationStatus.verified.rank)
    }

    func test_requestActionTransitionsUpdateLocalFixtureState() {
        let state = VerifyOverviewState.populatedFixture()
        let acceptedState = state.applying(.accept, to: "employment-brightpath")
        let declinedState = state.applying(.decline, to: "education-welingkar-pending")

        guard case .populated(let acceptedContent) = acceptedState.phase else {
            return XCTFail("Expected populated state")
        }

        guard case .populated(let declinedContent) = declinedState.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(
            acceptedContent.request(id: "employment-brightpath")?.status,
            .pendingAdminReview
        )
        XCTAssertEqual(
            declinedContent.request(id: "education-welingkar-pending")?.status,
            .rejected
        )
        XCTAssertEqual(acceptedContent.pendingRequests.count, 1)
        XCTAssertEqual(acceptedContent.inProgressRequests.count, 3)
        XCTAssertEqual(declinedContent.completedRequests.count, 4)
    }

    func test_rejectedAndExpiredStatusesExposeExpectedPresentation() {
        XCTAssertEqual(
            VerifyVerificationStatus.rejected.style,
            VerifyStatusStyle(
                title: "Rejected",
                symbol: "xmark.octagon",
                tone: .danger
            )
        )
        XCTAssertEqual(
            VerifyVerificationStatus.expired.style,
            VerifyStatusStyle(
                title: "Expired",
                symbol: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tone: .neutral
            )
        )
        XCTAssertEqual(VerifyVerificationStatus.expired.group, .completed)
    }
}
