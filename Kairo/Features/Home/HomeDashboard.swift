import Foundation

struct DashboardOverview: Equatable, Sendable {
    let user: AppUser
    let profileCompletion: ProfileCompletion
    let trustScore: TrustScore
    let verificationSummary: VerificationSummary
    let vaultSummary: VaultSummary
    let activePassportShares: ActivePassportShares
    let recentShareAnalytics: [ShareAnalyticsItem]
    let recentActivity: [ActivityItem]

    struct ProfileCompletion: Equatable, Sendable {
        let currentStep: String
        let emailVerified: Bool
        let phoneVerified: Bool
        let passportReady: Bool
        let completedSteps: [String]
        let missingRequirements: [String]
        let nextRecommendedStep: String?
        let completionPercentage: Int
        let isOnboardingComplete: Bool
    }

    struct TrustScore: Equatable, Sendable {
        enum Status: String, Equatable, Sendable {
            case consentRequired
            case incompleteVerification
            case calculated
            case criticalManualFraudReview
        }

        let overall: Int?
        let status: Status
        let positiveContributors: [Contributor]
        let negativeContributors: [Contributor]
        let criticalOverrides: [Contributor]
        let manualReviewReason: String?
        let verificationCompletenessPercentage: Int
        let weekChange: Int

        struct Contributor: Equatable, Sendable {
            let code: String
            let label: String
            let points: Double
            let detail: String
        }
    }

    struct VerificationSummary: Equatable, Sendable {
        let overall: SectionStatus
        let employments: SectionStatus
        let educations: SectionStatus
        let internships: SectionStatus
        let freelance: SectionStatus
        let gigPlatforms: SectionStatus
        let portfolio: SectionStatus
        let certifications: SectionStatus
        let skills: SectionStatus
        let projects: SectionStatus
        let userDocuments: SectionStatus

        struct SectionStatus: Equatable, Sendable {
            let total: Int
            let statuses: [String: Int]
        }
    }

    struct VaultSummary: Equatable, Sendable {
        let totalItems: Int
        let employments: Int
        let educations: Int
        let internships: Int
        let freelance: Int
        let gigPlatforms: Int
        let portfolio: Int
        let certifications: Int
        let skills: Int
        let projects: Int
        let userDocuments: Int
    }

    struct ActivePassportShares: Equatable, Sendable {
        let count: Int
        let items: [ShareSummaryItem]
    }

    struct ShareSummaryItem: Equatable, Sendable {
        let shareID: String
        let label: String?
        let state: String
        let expiresAt: Date?
        let lastViewedAt: Date?
        let createdAt: Date
    }

    struct ShareAnalyticsItem: Equatable, Identifiable, Sendable {
        let shareID: String
        let label: String?
        let state: String
        let totalViews: Int
        let uniqueViews: Int
        let lastViewedAt: Date?

        var id: String { shareID }
    }

    struct ActivityItem: Equatable, Identifiable, Sendable {
        enum Category: String, Equatable, Sendable {
            case verification
            case passportShare
        }

        let occurredAt: Date
        let category: Category
        let action: String
        let title: String
        let detail: String?
        let subjectID: String?

        var id: String { "\(category.rawValue)-\(title)-\(occurredAt.timeIntervalSince1970)" }
    }
}

extension DashboardOverview {
    nonisolated init(user: AppUser, dashboard: DashboardResponseDTO) {
        self.user = user
        profileCompletion = ProfileCompletion(
            currentStep: dashboard.profileCompletion.currentStep,
            emailVerified: dashboard.profileCompletion.emailVerified,
            phoneVerified: dashboard.profileCompletion.phoneVerified,
            passportReady: dashboard.profileCompletion.passportReady,
            completedSteps: dashboard.profileCompletion.completedSteps,
            missingRequirements: dashboard.profileCompletion.missingRequirements,
            nextRecommendedStep: dashboard.profileCompletion.nextRecommendedStep,
            completionPercentage: dashboard.profileCompletionPercentage,
            isOnboardingComplete: dashboard.profileCompletion.isOnboardingComplete
        )
        trustScore = TrustScore(
            overall: dashboard.trustScore.overall,
            status: .init(dtoStatus: dashboard.trustScore.status),
            positiveContributors: dashboard.trustScore.positiveContributors.map {
                .init(code: $0.code, label: $0.label, points: $0.points, detail: $0.detail)
            },
            negativeContributors: dashboard.trustScore.negativeContributors.map {
                .init(code: $0.code, label: $0.label, points: $0.points, detail: $0.detail)
            },
            criticalOverrides: dashboard.trustScore.criticalOverrides.map {
                .init(code: $0.code, label: $0.label, points: $0.points, detail: $0.detail)
            },
            manualReviewReason: dashboard.trustScore.manualReviewReason,
            verificationCompletenessPercentage: dashboard.trustScore.verificationCompletenessPercentage,
            weekChange: dashboard.trustScore.weekChange
        )
        verificationSummary = VerificationSummary(
            overall: .init(dto: dashboard.verificationSummary.overall),
            employments: .init(dto: dashboard.verificationSummary.employments),
            educations: .init(dto: dashboard.verificationSummary.educations),
            internships: .init(dto: dashboard.verificationSummary.internships),
            freelance: .init(dto: dashboard.verificationSummary.freelance),
            gigPlatforms: .init(dto: dashboard.verificationSummary.gigPlatforms),
            portfolio: .init(dto: dashboard.verificationSummary.portfolio),
            certifications: .init(dto: dashboard.verificationSummary.certifications),
            skills: .init(dto: dashboard.verificationSummary.skills),
            projects: .init(dto: dashboard.verificationSummary.projects),
            userDocuments: .init(dto: dashboard.verificationSummary.userDocuments)
        )
        vaultSummary = VaultSummary(
            totalItems: dashboard.vaultSummary.totalItems,
            employments: dashboard.vaultSummary.employments,
            educations: dashboard.vaultSummary.educations,
            internships: dashboard.vaultSummary.internships,
            freelance: dashboard.vaultSummary.freelance,
            gigPlatforms: dashboard.vaultSummary.gigPlatforms,
            portfolio: dashboard.vaultSummary.portfolio,
            certifications: dashboard.vaultSummary.certifications,
            skills: dashboard.vaultSummary.skills,
            projects: dashboard.vaultSummary.projects,
            userDocuments: dashboard.vaultSummary.userDocuments
        )
        activePassportShares = ActivePassportShares(
            count: dashboard.activePassportShares.count,
            items: dashboard.activePassportShares.items.map {
                ShareSummaryItem(
                    shareID: $0.shareId,
                    label: $0.label,
                    state: $0.state,
                    expiresAt: $0.expiresAt,
                    lastViewedAt: $0.lastViewedAt,
                    createdAt: $0.createdAt
                )
            }
        )
        recentShareAnalytics = dashboard.recentShareAnalytics.map {
                ShareAnalyticsItem(
                    shareID: $0.shareId,
                label: $0.label,
                state: $0.state,
                totalViews: $0.totalViews,
                uniqueViews: $0.uniqueViews,
                lastViewedAt: $0.lastViewedAt
            )
        }
        recentActivity = dashboard.recentActivity.map {
            ActivityItem(
                occurredAt: $0.occurredAt,
                category: .init(dtoCategory: $0.category),
                action: $0.action,
                title: $0.title,
                detail: $0.detail,
                    subjectID: $0.subjectId
            )
        }
    }
}

private extension DashboardOverview.TrustScore.Status {
    nonisolated init(dtoStatus: TrustScoreResponseDTO.Status) {
        switch dtoStatus {
        case .consentRequired:
            self = .consentRequired
        case .incompleteVerification:
            self = .incompleteVerification
        case .calculated:
            self = .calculated
        case .criticalManualFraudReview:
            self = .criticalManualFraudReview
        }
    }
}

private extension DashboardOverview.VerificationSummary.SectionStatus {
    nonisolated init(dto: PassportSectionStatusSummaryDTO) {
        self.init(total: dto.total, statuses: dto.statuses)
    }
}

private extension DashboardOverview.ActivityItem.Category {
    nonisolated init(dtoCategory: DashboardActivityItemDTO.Category) {
        switch dtoCategory {
        case .verification:
            self = .verification
        case .passportShare:
            self = .passportShare
        }
    }
}
