import XCTest
@testable import Kairo

@MainActor
final class PassportOverviewStateTests: XCTestCase {
    func test_populatedFixtureExposesPassportSectionsInOrder() {
        let state = PassportOverviewState.populatedFixture()

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        guard case .available(let trustScore) = content.trustScore else {
            return XCTFail("Expected available fixture trust score")
        }

        guard case .available(let timeline) = content.timeline else {
            return XCTFail("Expected available fixture timeline")
        }

        XCTAssertEqual(state.header.name, "Aarav Mehta")
        XCTAssertEqual(trustScore.value, 72)
        XCTAssertEqual(content.strengthSummary.count, 7)
        XCTAssertEqual(content.employment.count, 2)
        XCTAssertEqual(content.education.count, 1)
        XCTAssertEqual(content.certifications.count, 1)
        XCTAssertEqual(content.projects.count, 1)
        XCTAssertEqual(timeline.count, 5)
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

        guard case .available(let trustScore) = content.trustScore else {
            return XCTFail("Expected available fixture trust score")
        }

        XCTAssertTrue(trustScore.isFixture)
        XCTAssertEqual(trustScore.progress, 0.72)
        XCTAssertEqual(trustScore.status, "Building strong trust")
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

    func test_liveStateSupportsHonestUnavailableTrustScoreAndTimeline() {
        let state = PassportOverviewState.live(
            header: .fixture,
            dataSourceLabel: "Live data",
            content: PassportOverviewContent(
                dataSourceLabel: "Live data",
                trustScore: .unavailable(
                    PassportTrustScoreUnavailableState(
                        title: "Consent required",
                        message: "Kairo needs your consent before it can calculate and share your Trust Score."
                    )
                ),
                strengthSummary: [],
                identity: .fixture,
                employment: [
                    PassportEmploymentRecord(
                        company: "Kairo",
                        role: "Lead",
                        dateRange: "Jan 2026 – Present",
                        verificationStatus: .verified,
                        evidenceSummary: "1 supporting document on file."
                    )
                ],
                education: [],
                certifications: [],
                projects: [],
                timeline: .unavailable(
                    PassportUnavailableSectionState(
                        title: "Trust timeline not available yet",
                        message: "No unified owner Passport timeline is available."
                    )
                )
            ),
            isEmpty: false
        )

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated state")
        }

        guard case .unavailable(let trustScore) = content.trustScore else {
            return XCTFail("Expected unavailable live trust score")
        }

        guard case .unavailable(let timeline) = content.timeline else {
            return XCTFail("Expected unavailable timeline state")
        }

        XCTAssertEqual(trustScore.title, "Consent required")
        XCTAssertTrue(trustScore.message.contains("consent"))
        XCTAssertTrue(timeline.message.contains("timeline"))
    }
}
