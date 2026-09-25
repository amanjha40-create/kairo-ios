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
        XCTAssertEqual(content.portfolio.count, 1)
        XCTAssertEqual(content.visibleSections, [
            .professionalSummary,
            .employment,
            .education,
            .certifications,
            .skills,
            .projects,
            .portfolio
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
        XCTAssertTrue(content.portfolio.isEmpty)
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
                title: "Pending",
                symbol: "clock.badge.checkmark.fill",
                tone: .pending
            )
        )
        XCTAssertEqual(
            CareerVerificationStatus.notVerified.badgeStyle,
            CareerVerificationBadgeStyle(
                title: "Candidate-provided",
                symbol: "circle.dashed",
                tone: .candidateProvided
            )
        )
    }

    func test_wave2StatusesUseProductCopyAndNeverExposeUnknownEnums() {
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "partial_match").badgeStyle.title, "Partially verified")
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "additional_info_requested").badgeStyle.title, "Needs review")
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "submitted").badgeStyle.title, "Submitted")
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "future_internal_state").badgeStyle.title, "Status unavailable")
        XCTAssertEqual(CareerVerificationStatus(rawBackendValue: "rejected").badgeStyle.tone, .rejected)
    }
}
