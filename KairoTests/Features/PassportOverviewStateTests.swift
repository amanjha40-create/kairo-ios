import XCTest
@testable import Kairo

@MainActor
final class PassportOverviewStateTests: XCTestCase {
    func test_populatedFixtureExposesPassportSectionsInOrder() {
        let state = PassportOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(state.header.name, "Aarav Mehta")
        XCTAssertEqual(content.trustScore.value, 72)
        XCTAssertEqual(content.strengthSummary.count, 7)
        XCTAssertEqual(content.employment.count, 2)
        XCTAssertEqual(content.education.count, 1)
        XCTAssertEqual(content.certifications.count, 1)
        XCTAssertEqual(content.projects.count, 1)
        XCTAssertEqual(content.timeline.count, 5)
        XCTAssertEqual(content.visibleSections, [
            .trustScore,
            .passportStrength,
            .identity,
            .employment,
            .education,
            .certifications,
            .projects,
            .trustTimeline,
            .actions
        ])
    }

    func test_emptyFixtureExposesMeaningfulNextStepMessaging() {
        let state = PassportOverviewState.emptyFixture()

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty state")
        }

        XCTAssertEqual(content.title, "Your Trust Passport is taking shape.")
        XCTAssertEqual(content.dataSourceLabel, "Demo data")
        XCTAssertTrue(content.message.contains("reuse throughout your career"))
    }

    func test_loadingAndErrorFixturesExposeExpectedPhases() {
        XCTAssertEqual(PassportOverviewState.loadingFixture().phase, .loading)

        guard case .error(let errorState) = PassportOverviewState.errorFixture().phase else {
            return XCTFail("Expected error state")
        }

        XCTAssertEqual(errorState.title, "Trust Passport unavailable")
    }

    func test_defaultStateUsesExpectedDataSourceLabels() {
        guard case .populated(let demoContent) = PassportOverviewState.default(isDemoMode: true).phase else {
            return XCTFail("Expected populated state")
        }

        guard case .populated(let previewContent) = PassportOverviewState.default(isDemoMode: false).phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(demoContent.dataSourceLabel, "Demo data")
        XCTAssertEqual(previewContent.dataSourceLabel, "Preview data")
    }

    func test_verificationStatusesExposeStablePresentationMapping() {
        XCTAssertEqual(PassportVerificationStatus.verified.style, PassportStatusStyle(
            title: "Verified",
            symbol: "checkmark.seal.fill",
            tone: .verified
        ))
        XCTAssertEqual(PassportVerificationStatus.pendingVerification.style, PassportStatusStyle(
            title: "Pending verification",
            symbol: "clock.badge.checkmark.fill",
            tone: .pending
        ))
        XCTAssertEqual(PassportVerificationStatus.notVerified.style, PassportStatusStyle(
            title: "Not verified",
            symbol: "circle.dashed",
            tone: .neutral
        ))
    }

    func test_trustScoreFixtureIsMarkedAsFixtureData() {
        guard case .populated(let content) = PassportOverviewState.populatedFixture().phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertTrue(content.trustScore.isFixture)
        XCTAssertEqual(content.trustScore.progress, 0.72)
        XCTAssertEqual(content.trustScore.status, "Building strong trust")
    }

    func test_strengthSummaryCapturesExpectedTrustFoundation() {
        guard case .populated(let content) = PassportOverviewState.populatedFixture().phase else {
            return XCTFail("Expected populated state")
        }

        XCTAssertEqual(content.strengthSummary.map(\.title), [
            "Identity",
            "Email",
            "Mobile",
            "Employment",
            "Education",
            "Certifications",
            "Profile"
        ])
        XCTAssertEqual(content.strengthSummary.first?.status, .verified)
        XCTAssertEqual(content.strengthSummary.last?.status, .complete)
    }
}
