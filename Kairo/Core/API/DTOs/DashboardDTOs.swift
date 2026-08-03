import Foundation

nonisolated struct DashboardResponseDTO: Decodable, Equatable, Sendable {
    let profileCompletion: OnboardingStatusResponseDTO
    let profileCompletionPercentage: Int
    let trustScore: TrustScoreResponseDTO
    let verificationSummary: PassportVerificationSummaryDTO
    let vaultSummary: DashboardVaultSummaryDTO
    let activePassportShares: DashboardActivePassportSharesDTO
    let recentShareAnalytics: [DashboardShareAnalyticsItemDTO]
    let recentActivity: [DashboardActivityItemDTO]

    private enum CodingKeys: String, CodingKey {
        case profileCompletion
        case profileCompletionPercentage
        case trustScore
        case verificationSummary
        case vaultSummary
        case activePassportShares
        case recentShareAnalytics
        case recentActivity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileCompletion = try container.decode(OnboardingStatusResponseDTO.self, forKey: .profileCompletion)
        profileCompletionPercentage = try container.decodeIfPresent(
            Int.self,
            forKey: .profileCompletionPercentage
        ) ?? profileCompletion.completionPercentage
        trustScore = try container.decode(TrustScoreResponseDTO.self, forKey: .trustScore)
        verificationSummary = try container.decode(
            PassportVerificationSummaryDTO.self,
            forKey: .verificationSummary
        )
        vaultSummary = try container.decode(DashboardVaultSummaryDTO.self, forKey: .vaultSummary)
        activePassportShares = try container.decode(
            DashboardActivePassportSharesDTO.self,
            forKey: .activePassportShares
        )
        recentShareAnalytics = try container.decodeIfPresent(
            [DashboardShareAnalyticsItemDTO].self,
            forKey: .recentShareAnalytics
        ) ?? []
        recentActivity = try container.decodeIfPresent(
            [DashboardActivityItemDTO].self,
            forKey: .recentActivity
        ) ?? []
    }
}

nonisolated struct TrustScoreResponseDTO: Decodable, Equatable, Sendable {
    nonisolated enum Status: String, Decodable, Equatable, Sendable {
        case consentRequired = "consent_required"
        case incompleteVerification = "incomplete_verification"
        case calculated
        case criticalManualFraudReview = "critical_manual_fraud_review"
    }

    let overall: Int?
    let breakdown: TrustScoreComponentBreakdownDTO?
    let domainDetails: [String: TrustScoreDomainScoreDTO]
    let status: Status
    let positiveContributors: [TrustScoreContributorDTO]
    let negativeContributors: [TrustScoreContributorDTO]
    let criticalOverrides: [TrustScoreContributorDTO]
    let manualReviewReason: String?
    let scoreVersion: String
    let lastCalculatedAt: Date?
    let verificationCompletenessPercentage: Int
    let weekChange: Int

    private enum CodingKeys: String, CodingKey {
        case overall
        case breakdown
        case domainDetails
        case status
        case positiveContributors
        case negativeContributors
        case criticalOverrides
        case manualReviewReason
        case scoreVersion
        case lastCalculatedAt
        case verificationCompletenessPercentage
        case weekChange
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overall = try container.decodeIfPresent(Int.self, forKey: .overall)
        breakdown = try container.decodeIfPresent(TrustScoreComponentBreakdownDTO.self, forKey: .breakdown)
        domainDetails = try container.decodeIfPresent(
            [String: TrustScoreDomainScoreDTO].self,
            forKey: .domainDetails
        ) ?? [:]
        status = try container.decodeIfPresent(Status.self, forKey: .status) ?? .calculated
        positiveContributors = try container.decodeIfPresent(
            [TrustScoreContributorDTO].self,
            forKey: .positiveContributors
        ) ?? []
        negativeContributors = try container.decodeIfPresent(
            [TrustScoreContributorDTO].self,
            forKey: .negativeContributors
        ) ?? []
        criticalOverrides = try container.decodeIfPresent(
            [TrustScoreContributorDTO].self,
            forKey: .criticalOverrides
        ) ?? []
        manualReviewReason = try container.decodeIfPresent(String.self, forKey: .manualReviewReason)
        scoreVersion = try container.decodeIfPresent(String.self, forKey: .scoreVersion) ?? "v1"
        lastCalculatedAt = try container.decodeIfPresent(Date.self, forKey: .lastCalculatedAt)
        verificationCompletenessPercentage = try container.decodeIfPresent(
            Int.self,
            forKey: .verificationCompletenessPercentage
        ) ?? 0
        weekChange = try container.decodeIfPresent(Int.self, forKey: .weekChange) ?? 0
    }
}

nonisolated struct TrustScoreComponentBreakdownDTO: Decodable, Equatable, Sendable {
    let identity: Double
    let employment: Double
    let education: Double
}

nonisolated struct TrustScoreDomainScoreDTO: Decodable, Equatable, Sendable {
    let score: Double
    let verificationPoints: Double
    let fraudDeduction: Double
    let weight: Double
    let positiveContributors: [TrustScoreContributorDTO]
    let negativeContributors: [TrustScoreContributorDTO]

    private enum CodingKeys: String, CodingKey {
        case score
        case verificationPoints
        case fraudDeduction
        case weight
        case positiveContributors
        case negativeContributors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        score = try container.decode(Double.self, forKey: .score)
        verificationPoints = try container.decode(Double.self, forKey: .verificationPoints)
        fraudDeduction = try container.decode(Double.self, forKey: .fraudDeduction)
        weight = try container.decode(Double.self, forKey: .weight)
        positiveContributors = try container.decodeIfPresent(
            [TrustScoreContributorDTO].self,
            forKey: .positiveContributors
        ) ?? []
        negativeContributors = try container.decodeIfPresent(
            [TrustScoreContributorDTO].self,
            forKey: .negativeContributors
        ) ?? []
    }
}

nonisolated struct TrustScoreContributorDTO: Decodable, Equatable, Sendable {
    let code: String
    let label: String
    let points: Double
    let detail: String
}

nonisolated struct PassportVerificationSummaryDTO: Decodable, Equatable, Sendable {
    let overall: PassportSectionStatusSummaryDTO
    let employments: PassportSectionStatusSummaryDTO
    let educations: PassportSectionStatusSummaryDTO
    let internships: PassportSectionStatusSummaryDTO
    let freelance: PassportSectionStatusSummaryDTO
    let gigPlatforms: PassportSectionStatusSummaryDTO
    let portfolio: PassportSectionStatusSummaryDTO
    let certifications: PassportSectionStatusSummaryDTO
    let skills: PassportSectionStatusSummaryDTO
    let projects: PassportSectionStatusSummaryDTO
    let userDocuments: PassportSectionStatusSummaryDTO

    private enum CodingKeys: String, CodingKey {
        case overall
        case employments
        case educations
        case internships
        case freelance
        case gigPlatforms
        case portfolio
        case certifications
        case skills
        case projects
        case userDocuments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overall = try container.decode(PassportSectionStatusSummaryDTO.self, forKey: .overall)
        employments = try container.decode(PassportSectionStatusSummaryDTO.self, forKey: .employments)
        educations = try container.decode(PassportSectionStatusSummaryDTO.self, forKey: .educations)
        internships = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .internships
        ) ?? .empty
        freelance = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .freelance
        ) ?? .empty
        gigPlatforms = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .gigPlatforms
        ) ?? .empty
        portfolio = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .portfolio
        ) ?? .empty
        certifications = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .certifications
        ) ?? .empty
        skills = try container.decodeIfPresent(PassportSectionStatusSummaryDTO.self, forKey: .skills) ?? .empty
        projects = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .projects
        ) ?? .empty
        userDocuments = try container.decodeIfPresent(
            PassportSectionStatusSummaryDTO.self,
            forKey: .userDocuments
        ) ?? .empty
    }
}

nonisolated struct PassportSectionStatusSummaryDTO: Decodable, Equatable, Sendable {
    let total: Int
    let statuses: [String: Int]

    static let empty = PassportSectionStatusSummaryDTO(total: 0, statuses: [:])
}

nonisolated struct DashboardVaultSummaryDTO: Decodable, Equatable, Sendable {
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

    private enum CodingKeys: String, CodingKey {
        case totalItems
        case employments
        case educations
        case internships
        case freelance
        case gigPlatforms
        case portfolio
        case certifications
        case skills
        case projects
        case userDocuments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalItems = try container.decode(Int.self, forKey: .totalItems)
        employments = try container.decode(Int.self, forKey: .employments)
        educations = try container.decode(Int.self, forKey: .educations)
        internships = try container.decode(Int.self, forKey: .internships)
        freelance = try container.decode(Int.self, forKey: .freelance)
        gigPlatforms = try container.decode(Int.self, forKey: .gigPlatforms)
        portfolio = try container.decode(Int.self, forKey: .portfolio)
        certifications = try container.decode(Int.self, forKey: .certifications)
        skills = try container.decodeIfPresent(Int.self, forKey: .skills) ?? 0
        projects = try container.decodeIfPresent(Int.self, forKey: .projects) ?? 0
        userDocuments = try container.decode(Int.self, forKey: .userDocuments)
    }
}

nonisolated struct DashboardActivePassportSharesDTO: Decodable, Equatable, Sendable {
    let count: Int
    let items: [DashboardShareSummaryItemDTO]

    private enum CodingKeys: String, CodingKey {
        case count
        case items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decode(Int.self, forKey: .count)
        items = try container.decodeIfPresent([DashboardShareSummaryItemDTO].self, forKey: .items) ?? []
    }
}

nonisolated struct DashboardShareSummaryItemDTO: Decodable, Equatable, Sendable {
    let shareId: String
    let label: String?
    let state: String
    let expiresAt: Date?
    let lastViewedAt: Date?
    let createdAt: Date
}

nonisolated struct DashboardShareAnalyticsItemDTO: Decodable, Equatable, Sendable {
    let shareId: String
    let label: String?
    let state: String
    let totalViews: Int
    let uniqueViews: Int
    let lastViewedAt: Date?
}

nonisolated struct DashboardActivityItemDTO: Decodable, Equatable, Sendable {
    nonisolated enum Category: String, Decodable, Equatable, Sendable {
        case verification
        case passportShare = "passport_share"
    }

    let occurredAt: Date
    let category: Category
    let action: String
    let title: String
    let detail: String?
    let subjectId: String?
}
