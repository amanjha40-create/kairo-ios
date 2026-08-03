import Foundation
import XCTest
@testable import Kairo

final class HomeOverviewMapperTests: XCTestCase {
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
        XCTAssertEqual(content.recommendation.title, "Finish identity verification")
        XCTAssertEqual(content.recommendation.actionTitle, "Start verification")
        XCTAssertEqual(content.recommendation.destinationTab, .verify)
        XCTAssertEqual(content.visibleTrustTasks.map(\.title), [
            "Finish identity verification",
            "Add your employment history",
            "Verify your email"
        ])
        XCTAssertEqual(content.verificationRequests.first?.title, "Employment verification")
        XCTAssertEqual(content.verificationRequests.first?.destinationTab, .verify)
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

    func test_requiresSessionRecoveryOnlyForExpiredSession() {
        XCTAssertTrue(HomeOverviewMapper.requiresSessionRecovery(for: SessionServiceError.sessionExpired))
        XCTAssertFalse(HomeOverviewMapper.requiresSessionRecovery(for: SessionServiceError.missingAccessToken))
        XCTAssertFalse(HomeOverviewMapper.requiresSessionRecovery(for: NetworkError.transport("offline")))
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
                    action: category == .verification ? "awaiting_approval" : "viewed",
                    title: category == .verification ? "Employment verification" : "Passport viewed",
                    detail: category == .verification ? "Northstar Labs" : "Public passport share",
                    subjectID: "subject_\(index)"
                )
            }
        )
    }
}
