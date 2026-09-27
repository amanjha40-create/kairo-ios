import Foundation
import XCTest
@testable import Kairo

@MainActor
final class HomeOverviewMapperTests: XCTestCase {
    func testCompactHomeUsesOnlyAuthoritativeCareerCounts() throws {
        let overview = baseline()
        let result = try content(HomeOverviewMapper.map(overview))
        XCTAssertEqual(result.careerSummary, "\(overview.vaultSummary.employments) Employment · \(overview.vaultSummary.educations) Education · \(overview.vaultSummary.certifications) Certifications · \(overview.vaultSummary.projects) Projects · \(overview.vaultSummary.skills) Skills")
        XCTAssertEqual(result.profileCompletion.percentage, overview.profileCompletion.completionPercentage)
    }

    func testHomeAttentionPresentationDoesNotRewriteStatusOrRoute() throws {
        let attention: [VerifyVerificationStatus] = [.pendingSubjectAcceptance, .pendingSubjectSubmission,
                                                    .awaitingSubjectCorrections, .awaitingInformation]
        for status in VerifyVerificationStatus.displayOrder where status.group != .completed && status != .draft {
            let item = try XCTUnwrap(try content(HomeOverviewMapper.map(baseline(), verificationOverview: .init(requests: [request(status: status)]))).verificationRequests.first)
            XCTAssertEqual(item.needsAttention, attention.contains(status))
            XCTAssertEqual(item.status, status.style.title)
            XCTAssertEqual(item.authoritativeDestinationID, "public-request-id")
        }
    }

    func testHomeDoesNotDropOtherCurrentRequestsWhenOneNeedsAttention() throws {
        let requests = [request(status: .inProgress, route: "progress"),
                        request(status: .awaitingInformation, route: "attention"),
                        request(status: .withdrawnByCandidate, route: "history")]
        let result = try content(HomeOverviewMapper.map(baseline(), verificationOverview: .init(requests: requests)))
        XCTAssertEqual(Set(result.verificationRequests.compactMap(\.authoritativeDestinationID)), ["progress", "attention"])
        XCTAssertEqual(result.verificationRequests.filter(\.needsAttention).count, 1)
    }

    func testCompactTasksConsolidateRecommendationWithoutInventingState() throws {
        let result = try content(HomeOverviewState.populatedFixture())
        XCTAssertFalse(result.compactTrustTasks.contains { $0.title == result.recommendation.title })
        XCTAssertTrue(result.compactTrustTasks.allSatisfy { result.visibleTrustTasks.contains($0) })
        XCTAssertNil(result.careerSummary, "Fixture must not fabricate live record counts")
    }

    func test_mapCreatesPopulatedHomeStateFromLiveDashboardOverview() {
        let overview = makeOverview(
            trustScoreOverall: 78,
            missingRequirements: ["verify_identity", "employment"],
            nextRecommendedStep: "verify_identity",
            totalVaultItems: 6,
            analyticsCount: 1,
            activityCategories: [.verification, .passportShare]
        )

        let state = HomeOverviewMapper.map(overview)

        guard case .populated(let content) = state.phase else {
            return XCTFail("Expected populated Home state")
        }

        XCTAssertEqual(state.header.firstName, "Aarav")
        XCTAssertEqual(state.header.initials, "AM")
        XCTAssertEqual(content.dataSourceLabel, "Live data")
        XCTAssertEqual(content.trustScore.score, 78)
        XCTAssertEqual(content.trustScore.status, "Calculated")
        XCTAssertEqual(content.trustScore.progress, 0.78)
        XCTAssertEqual(content.recommendation.title, "Finish identity verification")
        XCTAssertEqual(content.recommendation.actionTitle, "Start verification")
        XCTAssertEqual(content.recommendation.destinationTab, .verify)
        XCTAssertEqual(content.visibleTrustTasks.map(\.title), [
            "Finish identity verification",
            "Add your employment history",
            "Verify your email"
        ])
        XCTAssertTrue(content.verificationRequests.isEmpty)
        XCTAssertFalse(content.verificationRequestsAvailable)
        XCTAssertEqual(content.profileCompletion.destinationTab, .career)
        XCTAssertEqual(content.recentActivity.count, 2)
        XCTAssertEqual(content.recentPassportViews.count, 1)
        XCTAssertTrue(content.trustScore.supportingCopy.contains("verified"))
    }

    func test_mapCreatesEmptyStateWhenDashboardHasNoTrustSignalsYet() {
        let overview = makeOverview(
            trustScoreOverall: nil,
            missingRequirements: ["employment"],
            nextRecommendedStep: "employment",
            totalVaultItems: 0,
            analyticsCount: 0,
            activityCategories: []
        )

        let state = HomeOverviewMapper.map(overview)

        guard case .empty(let content) = state.phase else {
            return XCTFail("Expected empty Home state")
        }

        XCTAssertNil(content.trustScore.score)
        XCTAssertNil(content.trustScore.progress)
        XCTAssertEqual(content.recommendation.title, "Add your employment history")
        XCTAssertEqual(content.recommendation.actionTitle, "Continue profile")
        XCTAssertEqual(content.recommendation.destinationTab, .career)
        XCTAssertTrue(content.verificationRequests.isEmpty)
        XCTAssertTrue(content.recentPassportViews.isEmpty)
    }

    func test_errorStateMapsTransportErrorToOfflineExperience() {
        let state = HomeOverviewMapper.errorState(
            for: NetworkError.transport("offline"),
            header: .placeholder
        )

        guard case .error(let errorState) = state.phase else {
            return XCTFail("Expected error Home state")
        }

        XCTAssertEqual(errorState.title, "You're offline")
        XCTAssertTrue(errorState.message.contains("couldn't reach"))
    }

    func test_errorStateDoesNotExposeBackendAPIMessage() {
        let raw = "internal dashboard relation failed"
        let error = APIError(statusCode: 500, code: .internalError, message: raw,
                             fieldErrors: [:], globalErrors: [], validationDetails: [])
        let state = HomeOverviewMapper.errorState(for: NetworkError.api(error), header: .placeholder)
        guard case .error(let presentation) = state.phase else { return XCTFail("Expected error Home state") }
        XCTAssertEqual(presentation.message, "KairoID couldn't load your Home overview. Please try again.")
        XCTAssertFalse(presentation.message.contains(raw))
    }

    func test_requiresSessionRecoveryOnlyForExpiredSession() {
        XCTAssertTrue(HomeOverviewMapper.requiresSessionRecovery(for: SessionServiceError.sessionExpired))
        XCTAssertFalse(HomeOverviewMapper.requiresSessionRecovery(for: SessionServiceError.missingAccessToken))
        XCTAssertFalse(HomeOverviewMapper.requiresSessionRecovery(for: NetworkError.transport("offline")))
    }

    func test_historicalEmploymentCreatedNeverBecomesARequest() throws {
        let overview = baseline(activity: [.verification])
        let state = HomeOverviewMapper.map(overview, verificationOverview: .init(requests: []))
        let content = try content(state)
        XCTAssertTrue(content.verificationRequests.isEmpty)
        XCTAssertTrue(content.verificationRequestsAvailable)
        XCTAssertEqual(content.recentActivity.count, 1)
        XCTAssertNotNil(overview.recentActivity.first?.subjectID)
    }

    func test_allKnownActiveStatusesUseAuthoritativeRouteAndStatus() throws {
        for status in VerifyVerificationStatus.displayOrder where status.group != .completed && status != .draft {
            let state = HomeOverviewMapper.map(baseline(), verificationOverview: .init(requests: [request(status: status)]))
            let item = try XCTUnwrap(try content(state).verificationRequests.first)
            XCTAssertEqual(item.authoritativeDestinationID, "public-request-id")
            XCTAssertEqual(item.status, status.style.title)
            XCTAssertEqual(item.destinationTab, .verify)
        }
    }

    func test_completedDraftUnknownAndUnrouteableRequestsNeverBecomeActiveCards() throws {
        let statuses: [VerifyVerificationStatus] = [.verified, .rejected, .unableToVerify, .cancelled, .expired, .draft, .unknown("new_state")]
        for status in statuses {
            XCTAssertTrue(try content(HomeOverviewMapper.map(baseline(), verificationOverview: .init(requests: [request(status: status)]))).verificationRequests.isEmpty)
        }
        for route in [nil, "", "  "] as [String?] {
            XCTAssertTrue(try content(HomeOverviewMapper.map(baseline(), verificationOverview: .init(requests: [request(status: .inProgress, route: route)]))).verificationRequests.isEmpty)
        }
    }

    func test_loaderUsesExistingVerifyCollectionRatherThanDashboardActivity() async throws {
        let state = try await HomeOverviewLoader.load(dashboardService: DashboardStub(value: baseline(activity: [.verification])), verificationService: VerifyStub(result: .success(.init(requests: [request(status: .pendingAdminReview)]))))
        XCTAssertEqual(try content(state).verificationRequests.first?.authoritativeDestinationID, "public-request-id")
    }

    func test_requestLoadFailureIsUnknownNotZeroOrHistoricalFallback() async throws {
        let state = try await HomeOverviewLoader.load(dashboardService: DashboardStub(value: baseline(activity: [.verification])), verificationService: VerifyStub(result: .failure(NetworkError.invalidResponse)))
        let content = try content(state)
        XCTAssertFalse(content.verificationRequestsAvailable)
        XCTAssertTrue(content.verificationRequests.isEmpty)
        XCTAssertEqual(content.recentActivity.count, 1)
    }

    func test_requestSessionExpiryIsNotSwallowed() async throws {
        do {
            _ = try await HomeOverviewLoader.load(dashboardService: DashboardStub(value: baseline()), verificationService: VerifyStub(result: .failure(SessionServiceError.sessionExpired)))
            XCTFail("Expected session recovery")
        } catch { XCTAssertEqual(error as? SessionServiceError, .sessionExpired) }
    }

    func test_incompleteTrustScoreDoesNotClaimWorkflowProgress() throws {
        let overview = makeOverview(trustScoreOverall: nil, missingRequirements: [], nextRecommendedStep: nil, totalVaultItems: 0, analyticsCount: 0, activityCategories: [])
        XCTAssertEqual(try content(HomeOverviewMapper.map(overview, verificationOverview: .init(requests: []))).trustScore.status, "Verification incomplete")
    }

    private func content(_ state: HomeOverviewState) throws -> HomeOverviewContent {
        switch state.phase {
        case .populated(let content), .empty(let content): return content
        default: throw XCTUnwrapError()
        }
    }

    private struct XCTUnwrapError: Error {}

    private func baseline(activity: [DashboardOverview.ActivityItem.Category] = []) -> DashboardOverview {
        makeOverview(trustScoreOverall: 78, missingRequirements: [], nextRecommendedStep: nil, totalVaultItems: 2, analyticsCount: 0, activityCategories: activity)
    }

    private func request(status: VerifyVerificationStatus, route: String? = "public-request-id") -> VerifyRequestRecord {
        .init(id: "internal-id", routeID: route, subjectIDs: ["employment-id"], kind: .employment, typeTitle: "Employment verification", organizationName: "Synthetic employer", requesterName: "Synthetic requester", requestedItem: "Synthetic role", status: status, priority: "normal", dueDate: nil, createdAt: .distantPast, updatedAt: .distantPast, candidateResponse: nil, candidateResponseSubmittedAt: nil, acceptedAt: nil, consentedFields: [], consentedEvidenceScope: [], evidenceSummary: .init(totalItems: 0, documentItems: 0, fieldKeys: []), timeline: [])
    }

    private struct DashboardStub: HomeOverviewServiceProtocol {
        let value: DashboardOverview
        func loadOverview() async throws -> DashboardOverview { value }
    }

    private struct VerifyStub: VerifyOverviewServiceProtocol {
        let result: Result<VerifyOverview, Error>
        func loadOverview() async throws -> VerifyOverview { try result.get() }
        func performAction(requestID: String, action: VerifyRequestAction, response: String?, consent: VerificationSubmissionConsent?) async throws { XCTFail("No mutations allowed") }
    }

    private func makeOverview(
        trustScoreOverall: Int?,
        missingRequirements: [String],
        nextRecommendedStep: String?,
        totalVaultItems: Int,
        analyticsCount: Int,
        activityCategories: [DashboardOverview.ActivityItem.Category]
    ) -> DashboardOverview {
        DashboardOverview(
            user: AppUser(
                id: "user_123",
                email: "aarav@example.com",
                fullName: "Aarav Mehta",
                profileSlug: "aarav-mehta",
                phone: "+919876543210",
                currentRole: "People Operations Lead",
                industry: "Technology",
                yearsOfExperience: 6,
                location: "Bengaluru, India",
                locationCity: "Bengaluru",
                locationRegion: "Karnataka",
                locationCountry: "India",
                headline: "People Operations Lead",
                bio: "Building verified trust.",
                dateOfBirth: nil,
                avatarURL: nil,
                role: "user",
                isActive: true,
                phoneVerifiedAt: nil,
                emailVerifiedAt: nil,
                employmentOnboardingCompletedAt: nil,
                languages: [],
                professionalLinks: [],
                profileCompletionPercentage: 70,
                createdAt: Date(timeIntervalSince1970: 1_722_499_200)
            ),
            profileCompletion: DashboardOverview.ProfileCompletion(
                currentStep: "complete_profile",
                emailVerified: true,
                phoneVerified: true,
                passportReady: false,
                completedSteps: ["verify_email", "verify_phone"],
                missingRequirements: missingRequirements,
                nextRecommendedStep: nextRecommendedStep,
                completionPercentage: 70,
                isOnboardingComplete: false
            ),
            trustScore: DashboardOverview.TrustScore(
                overall: trustScoreOverall,
                status: trustScoreOverall == nil ? .incompleteVerification : .calculated,
                positiveContributors: [
                    DashboardOverview.TrustScore.Contributor(
                        code: "verified_employment",
                        label: "Verified employment",
                        points: 22.5,
                        detail: "Your current role has been verified."
                    )
                ],
                negativeContributors: [],
                criticalOverrides: [],
                manualReviewReason: nil,
                verificationCompletenessPercentage: trustScoreOverall == nil ? 0 : 72,
                weekChange: 4
            ),
            verificationSummary: DashboardOverview.VerificationSummary(
                overall: .init(total: 4, statuses: ["verified": 2, "pending": 1, "not_verified": 1]),
                employments: .init(total: 2, statuses: ["verified": 1, "pending": 1]),
                educations: .init(total: 1, statuses: ["verified": 1]),
                internships: .init(total: 0, statuses: [:]),
                freelance: .init(total: 0, statuses: [:]),
                gigPlatforms: .init(total: 0, statuses: [:]),
                portfolio: .init(total: 0, statuses: [:]),
                certifications: .init(total: 1, statuses: ["not_verified": 1]),
                skills: .init(total: 0, statuses: [:]),
                projects: .init(total: 0, statuses: [:]),
                userDocuments: .init(total: 2, statuses: ["verified": 1, "pending": 1])
            ),
            vaultSummary: DashboardOverview.VaultSummary(
                totalItems: totalVaultItems,
                employments: 2,
                educations: 1,
                internships: 0,
                freelance: 0,
                gigPlatforms: 0,
                portfolio: 0,
                certifications: 1,
                skills: 0,
                projects: 0,
                userDocuments: 2
            ),
            activePassportShares: DashboardOverview.ActivePassportShares(
                count: analyticsCount,
                items: analyticsCount == 0 ? [] : [
                    DashboardOverview.ShareSummaryItem(
                        shareID: "share_123",
                        label: "Northstar Labs",
                        state: "active",
                        expiresAt: nil,
                        lastViewedAt: Date(timeIntervalSince1970: 1_722_650_400),
                        createdAt: Date(timeIntervalSince1970: 1_722_499_200)
                    )
                ]
            ),
            recentShareAnalytics: analyticsCount == 0 ? [] : [
                DashboardOverview.ShareAnalyticsItem(
                    shareID: "share_123",
                    label: "Northstar Labs",
                    state: "active",
                    totalViews: 3,
                    uniqueViews: 2,
                    lastViewedAt: Date(timeIntervalSince1970: 1_722_650_400)
                )
            ],
            recentActivity: activityCategories.enumerated().map { index, category in
                DashboardOverview.ActivityItem(
                    occurredAt: Date(timeIntervalSince1970: 1_722_700_000 + Double(index)),
                    category: category,
                    action: category == .verification ? "employment_created" : "viewed",
                    title: category == .verification ? "Employment Created" : "Passport viewed",
                    detail: category == .verification ? "Northstar Labs" : "Public passport share",
                    subjectID: "subject_\(index)"
                )
            }
        )
    }
}
