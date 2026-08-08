import Foundation

struct PassportOverview: Equatable, Sendable {
    let user: AppUser
    let trustScore: TrustScore
    let metadata: Metadata
    let sharingSummary: SharingSummary
    let verificationSummary: VerificationSummary
    let vault: Vault

    struct TrustScore: Equatable, Sendable {
        enum Status: String, Equatable, Sendable {
            case consentRequired
            case incompleteVerification
            case calculated
            case criticalManualFraudReview
        }

        struct Contributor: Equatable, Sendable {
            let code: String
            let label: String
            let points: Double
            let detail: String
        }

        let overall: Int?
        let status: Status
        let breakdown: TrustScoreComponentBreakdownDTO?
        let domainDetails: [String: TrustScoreDomainScoreDTO]
        let positiveContributors: [Contributor]
        let negativeContributors: [Contributor]
        let criticalOverrides: [Contributor]
        let manualReviewReason: String?
        let scoreVersion: String
        let lastCalculatedAt: Date?
        let verificationCompletenessPercentage: Int
        let weekChange: Int
    }

    struct Metadata: Equatable, Sendable {
        let ownerUserId: String
        let profileSlug: String?
        let isEmailVerified: Bool
        let isOnboardingComplete: Bool
        let createdAt: Date
        let updatedAt: Date
        let employmentOnboardingCompletedAt: Date?
    }

    struct SharingSummary: Equatable, Sendable {
        let totalLinks: Int
        let activeLinks: Int
        let revokedLinks: Int
        let expiredLinks: Int
        let totalViews: Int
        let uniqueViews: Int
        let latestShareCreatedAt: Date?
        let lastViewedAt: Date?
    }

    struct VerificationSummary: Equatable, Sendable {
        struct SectionSummary: Equatable, Sendable {
            let total: Int
            let statuses: [String: Int]
        }

        let overall: SectionSummary
        let employments: SectionSummary
        let educations: SectionSummary
        let certifications: SectionSummary
        let skills: SectionSummary
        let projects: SectionSummary
    }

    struct Vault: Equatable, Sendable {
        let employments: [PassportEmploymentRecordDomain]
        let educations: [PassportEducationRecordDomain]
        let certifications: [PassportCertificationRecordDomain]
        let projects: [PassportProjectRecordDomain]
        let skills: [PassportSkillRecordDomain]
        let userDocuments: [PassportDocumentRecordDomain]
    }
}

struct PassportEmploymentRecordDomain: Identifiable, Equatable, Sendable {
    let id: String
    let company: String
    let role: String
    let startDate: Date?
    let endDate: Date?
    let verificationStatus: PassportRecordVerificationStatus
    let verificationMethod: String?
    let documents: [PassportDocumentRecordDomain]
}

struct PassportEducationRecordDomain: Identifiable, Equatable, Sendable {
    let id: String
    let institution: String
    let degree: String?
    let fieldOfStudy: String?
    let educationLevel: String?
    let grade: String?
    let startDate: Date?
    let endDate: Date?
    let startDatePrecision: String?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
    let verificationStatus: PassportRecordVerificationStatus
}

struct PassportCertificationRecordDomain: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let issuer: String?
    let issuedDate: Date?
    let expiryDate: Date?
    let doesNotExpire: Bool
    let credentialID: String?
    let credentialURL: URL?
    let verificationStatus: PassportRecordVerificationStatus
}

struct PassportProjectRecordDomain: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let role: String?
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let isOngoing: Bool
    let projectURL: URL?
    let repositoryURL: URL?
    let organizationName: String?
    let verificationStatus: PassportRecordVerificationStatus?
}

struct PassportSkillRecordDomain: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let verificationStatus: PassportRecordVerificationStatus
}

struct PassportDocumentRecordDomain: Identifiable, Equatable, Sendable {
    let id: String
    let documentType: String
    let originalFilename: String
    let byteSize: Int
    let verificationStatus: PassportRecordVerificationStatus
}

enum PassportRecordVerificationStatus: String, Equatable, Sendable {
    case verified
    case pending
    case notVerified

    nonisolated init(rawBackendValue: String) {
        switch rawBackendValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "verified", "approved":
            self = .verified
        case "pending", "pending_verification", "awaiting_verification", "in_review",
             "submitted", "under_review", "additional_info_requested":
            self = .pending
        case "not_verified", "unverified", "missing", "draft", "rejected", "cancelled":
            self = .notVerified
        default:
            self = .notVerified
        }
    }
}

extension PassportOverview {
    nonisolated init(dto: OwnerPassportResponseDTO) {
        self.init(
            user: dto.profile.asDomainModel(),
            trustScore: TrustScore(dto: dto.trustScore),
            metadata: Metadata(dto: dto.passportMetadata),
            sharingSummary: SharingSummary(dto: dto.sharingSummary),
            verificationSummary: VerificationSummary(dto: dto.verificationSummary),
            vault: Vault(dto: dto.vault)
        )
    }
}

extension PassportOverview.TrustScore {
    nonisolated init(dto: TrustScoreResponseDTO) {
        self.init(
            overall: dto.overall,
            status: .init(dtoStatus: dto.status),
            breakdown: dto.breakdown,
            domainDetails: dto.domainDetails,
            positiveContributors: dto.positiveContributors.map(Self.Contributor.init(dto:)),
            negativeContributors: dto.negativeContributors.map(Self.Contributor.init(dto:)),
            criticalOverrides: dto.criticalOverrides.map(Self.Contributor.init(dto:)),
            manualReviewReason: dto.manualReviewReason,
            scoreVersion: dto.scoreVersion,
            lastCalculatedAt: dto.lastCalculatedAt,
            verificationCompletenessPercentage: dto.verificationCompletenessPercentage,
            weekChange: dto.weekChange
        )
    }
}

extension PassportOverview.TrustScore.Contributor {
    nonisolated init(dto: TrustScoreContributorDTO) {
        self.init(code: dto.code, label: dto.label, points: dto.points, detail: dto.detail)
    }
}

extension PassportOverview.Metadata {
    nonisolated init(dto: PassportMetadataDTO) {
        self.init(
            ownerUserId: dto.ownerUserId,
            profileSlug: dto.profileSlug,
            isEmailVerified: dto.isEmailVerified,
            isOnboardingComplete: dto.isOnboardingComplete,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt,
            employmentOnboardingCompletedAt: dto.employmentOnboardingCompletedAt
        )
    }
}

extension PassportOverview.SharingSummary {
    nonisolated init(dto: PassportSharingSummaryDTO) {
        self.init(
            totalLinks: dto.totalLinks,
            activeLinks: dto.activeLinks,
            revokedLinks: dto.revokedLinks,
            expiredLinks: dto.expiredLinks,
            totalViews: dto.totalViews,
            uniqueViews: dto.uniqueViews,
            latestShareCreatedAt: dto.latestShareCreatedAt,
            lastViewedAt: dto.lastViewedAt
        )
    }
}

extension PassportOverview.VerificationSummary {
    nonisolated init(dto: PassportVerificationSummaryDTO) {
        self.init(
            overall: .init(dto: dto.overall),
            employments: .init(dto: dto.employments),
            educations: .init(dto: dto.educations),
            certifications: .init(dto: dto.certifications),
            skills: .init(dto: dto.skills),
            projects: .init(dto: dto.projects)
        )
    }
}

extension PassportOverview.VerificationSummary.SectionSummary {
    nonisolated init(dto: PassportSectionStatusSummaryDTO) {
        self.init(total: dto.total, statuses: dto.statuses)
    }
}

extension PassportOverview.Vault {
    nonisolated init(dto: PublicPassportVaultDTO) {
        self.init(
            employments: dto.employments.map(PassportEmploymentRecordDomain.init(dto:)),
            educations: dto.educations.map(PassportEducationRecordDomain.init(dto:)),
            certifications: dto.certifications.map(PassportCertificationRecordDomain.init(dto:)),
            projects: dto.projects.map(PassportProjectRecordDomain.init(dto:)),
            skills: dto.skills.map(PassportSkillRecordDomain.init(dto:)),
            userDocuments: dto.userDocuments.map(PassportDocumentRecordDomain.init(dto:))
        )
    }
}

extension PassportEmploymentRecordDomain {
    nonisolated init(dto: PublicPassportEmploymentDTO) {
        self.init(
            id: dto.id,
            company: dto.employerLegalName?.nonEmpty ?? "Employer not added yet",
            role: dto.jobTitle,
            startDate: dto.startDate,
            endDate: dto.endDate,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus),
            verificationMethod: dto.verificationMethod.nonEmpty,
            documents: dto.documents.map(PassportDocumentRecordDomain.init(dto:))
        )
    }
}

extension PassportEducationRecordDomain {
    nonisolated init(dto: PublicPassportEducationDTO) {
        self.init(
            id: dto.id,
            institution: dto.institutionName?.nonEmpty ?? "Institution not added yet",
            degree: dto.degree?.nonEmpty,
            fieldOfStudy: dto.fieldOfStudy?.nonEmpty,
            educationLevel: dto.educationLevel?.nonEmpty,
            grade: dto.grade?.nonEmpty,
            startDate: dto.startDate,
            endDate: dto.endDate,
            startDatePrecision: dto.startDatePrecision?.nonEmpty,
            endDatePrecision: dto.endDatePrecision?.nonEmpty,
            isCurrentlyStudying: dto.isCurrentlyStudying,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
        )
    }
}

extension PassportCertificationRecordDomain {
    nonisolated init(dto: PublicPassportCertificationDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            issuer: dto.issuingOrganization?.nonEmpty,
            issuedDate: dto.issuedDate,
            expiryDate: dto.expiryDate,
            doesNotExpire: dto.doesNotExpire,
            credentialID: dto.credentialID?.nonEmpty,
            credentialURL: dto.credentialURL,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
        )
    }
}

extension PassportProjectRecordDomain {
    nonisolated init(dto: PublicPassportProjectDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            role: dto.role?.nonEmpty,
            description: dto.description?.nonEmpty,
            startDate: dto.startDate,
            endDate: dto.endDate,
            isOngoing: dto.isOngoing,
            projectURL: dto.projectURL,
            repositoryURL: dto.repositoryURL,
            organizationName: dto.organizationName?.nonEmpty,
            verificationStatus: dto.verificationStatus.map(PassportRecordVerificationStatus.init(rawBackendValue:))
        )
    }
}

extension PassportSkillRecordDomain {
    nonisolated init(dto: PublicPassportSkillDTO) {
        self.init(
            id: "\(dto.name)-\(dto.verificationStatus)",
            name: dto.name,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
        )
    }
}

extension PassportDocumentRecordDomain {
    nonisolated init(dto: PublicPassportDocumentDTO) {
        self.init(
            id: dto.id,
            documentType: dto.documentType,
            originalFilename: dto.originalFilename,
            byteSize: dto.byteSize,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
        )
    }
}

private extension PassportOverview.TrustScore.Status {
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

private extension String {
    nonisolated var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
