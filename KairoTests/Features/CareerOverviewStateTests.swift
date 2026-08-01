import XCTest
@testable import Kairo

@MainActor
final class CareerOverviewStateTests: XCTestCase {
    func test_populatedFixtureExposesCareerTimelineSectionsInOrder() {
        let state = CareerOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(state.summary.name, "Aarav Anand")
        XCTAssertEqual(content.employment.count, 3)
        XCTAssertEqual(content.education.count, 2)
        XCTAssertEqual(content.certifications.count, 2)
        XCTAssertEqual(content.projects.count, 2)
        XCTAssertEqual(content.skills.count, 8)
        XCTAssertEqual(content.visibleSections, [
            .professionalSummary,
            .employment,
            .education,
            .certifications,
            .projects,
            .skills
        ])
    }

    func test_emptyFixtureKeepsTimelineArraysEmpty() {
        let state = CareerOverviewState.emptyFixture()

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty state")
        }

        XCTAssertEqual(state.summary.currentCompany, "Add your current role")
        XCTAssertTrue(content.employment.isEmpty)
        XCTAssertTrue(content.education.isEmpty)
        XCTAssertTrue(content.certifications.isEmpty)
        XCTAssertTrue(content.projects.isEmpty)
        XCTAssertTrue(content.skills.isEmpty)
        XCTAssertEqual(content.visibleSections, [.professionalSummary])
    }

    func test_loadingAndErrorFixturesExposeExpectedPhases() {
        XCTAssertEqual(CareerOverviewState.loadingFixture().phase, .loading)

        guard case .error(let errorState) = CareerOverviewState.errorFixture().phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "Career overview unavailable")
    }

    func test_defaultStateUsesExpectedDataSourceLabels() {
        XCTAssertEqual(CareerOverviewState.default(isDemoMode: true).dataSourceLabel, "Demo data")
        XCTAssertEqual(CareerOverviewState.default(isDemoMode: false).dataSourceLabel, "Preview data")
    }

    func test_verificationStatusesExposeStableBadgePresentation() {
        XCTAssertEqual(
            CareerVerificationStatus.verified.badgeStyle,
            CareerVerificationBadgeStyle(
                title: "Verified",
                symbol: "checkmark.seal.fill",
                tone: .success
            )
        )
        XCTAssertEqual(
            CareerVerificationStatus.pendingVerification.badgeStyle,
            CareerVerificationBadgeStyle(
                title: "Pending Verification",
                symbol: "clock.badge.checkmark.fill",
                tone: .pending
            )
        )
        XCTAssertEqual(
            CareerVerificationStatus.notVerified.badgeStyle,
            CareerVerificationBadgeStyle(
                title: "Not Verified",
                symbol: "circle.dashed",
                tone: .neutral
            )
        )
    }
}
