import Foundation

struct CareerOverview: Equatable, Sendable {
    let user: AppUser
    let employments: [CareerEmploymentRecord]
    let educations: [CareerEducationRecord]
    let certifications: [CareerCertificationRecord]
    let projects: [CareerProjectRecord]
    let skills: [CareerSkillRecord]
    var portfolio: [PortfolioRecord] = []
}

struct CareerEmploymentRecord: Identifiable, Equatable, Sendable {
    let id: String
    let subjectFullName: String?
    let subjectEmail: String?
    let company: String
    let employerLegalName: String
    let employerTradeName: String?
    let role: String
    let employmentType: String?
    let startDate: Date?
    let endDate: Date?
    let currentlyWorking: Bool
    let workLocationCountry: String?
    let workLocationRegion: String?
    var workLocationCity: String? = nil
    var workArrangement: String? = nil
    let verificationMethod: String?
    let verificationStatus: CareerRecordVerificationStatus
    let rawVerificationStatus: String

    nonisolated var allowsCandidateEditing: Bool {
        let normalized = rawVerificationStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return normalized == "draft" || normalized == "additional_info_requested"
    }

    nonisolated var allowsCandidateDeletion: Bool {
        allowsCandidateEditing
    }
}

struct CareerEducationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let institution: String
    let degree: String
    let fieldOfStudy: String?
    let educationLevel: String?
    let grade: String?
    let startDate: Date?
    let startDatePrecision: String?
    let endDate: Date?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
    let verificationStatus: CareerRecordVerificationStatus
    let rawVerificationStatus: String
    var institutionCatalogueID: String? = nil
    var institutionCatalogueVersion: String? = nil
}

struct CareerCertificationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let issuer: String
    let issueDate: Date?
    let expiryDate: Date?
    let doesNotExpire: Bool
    let credentialID: String?
    let credentialURL: URL?
    let originalFilename: String?
    let contentType: String?
    let byteSize: Int?
    let verificationStatus: CareerRecordVerificationStatus
    let rawVerificationStatus: String
}

struct CareerProjectRecord: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let role: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let isOngoing: Bool
    let projectURL: URL?
    let repositoryURL: URL?
    let organizationName: String?
    let verificationStatus: CareerRecordVerificationStatus?
    let rawVerificationStatus: String?

    nonisolated var portfolioURL: URL? {
        projectURL ?? repositoryURL
    }
}

struct CareerSkillRecord: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let verificationStatus: CareerRecordVerificationStatus
    let rawVerificationStatus: String
}

enum CareerRecordVerificationStatus: String, Equatable, Sendable {
    case verified
    case pending
    case notVerified
    case unavailable

    nonisolated init(rawBackendValue: String) {
        switch rawBackendValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
        case "verified", "approved":
            self = .verified
        case "pending", "pending_review", "pending_verification", "awaiting_verification", "in_review",
             "submitted", "under_review", "additional_info_requested", "pending_admin_review",
             "pending_admin_re_review", "pending_organization_acceptance", "accepted", "in_progress",
             "awaiting_information", "awaiting_quality_review":
            self = .pending
        case "not_verified", "unverified", "self_declared", "candidate_provided", "missing", "draft", "rejected", "cancelled", "withdrawn_by_candidate", "expired", "unable_to_verify":
            self = .notVerified
        default:
            self = .unavailable
        }
    }
}

extension CareerEmploymentRecord {
    nonisolated init(dto: CareerEmploymentDTO) {
        self.init(
            id: dto.id,
            subjectFullName: dto.subjectFullName,
            subjectEmail: dto.subjectEmail,
            company: dto.companyDisplayName,
            employerLegalName: dto.employerLegalName ?? dto.companyDisplayName,
            employerTradeName: dto.employerTradeName,
            role: dto.jobTitle,
            employmentType: dto.employmentType,
            startDate: dto.startDate,
            endDate: dto.endDate,
            currentlyWorking: dto.currentlyWorking,
            workLocationCountry: dto.workLocationCountry,
            workLocationRegion: dto.workLocationRegion,
            workLocationCity: dto.workLocationCity,
            workArrangement: dto.workArrangement,
            verificationMethod: dto.verificationMethod,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus),
            rawVerificationStatus: dto.verificationStatus
        )
    }
}

extension CareerEducationRecord {
    nonisolated init(dto: CareerEducationDTO) {
        self.init(
            id: dto.id,
            institution: dto.institutionName,
            degree: dto.degree ?? "Degree not added yet",
            fieldOfStudy: dto.fieldOfStudy,
            educationLevel: dto.educationLevel,
            grade: dto.grade,
            startDate: dto.startDate,
            startDatePrecision: dto.startDatePrecision,
            endDate: dto.endDate,
            endDatePrecision: dto.endDatePrecision,
            isCurrentlyStudying: dto.isCurrentlyStudying,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus),
            rawVerificationStatus: dto.verificationStatus,
            institutionCatalogueID: dto.institutionCatalogueID,
            institutionCatalogueVersion: dto.institutionCatalogueVersion
        )
    }
}

extension CareerCertificationRecord {
    nonisolated init(dto: CareerCertificationDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            issuer: dto.issuingOrganization ?? "Issuer not added yet",
            issueDate: dto.issuedDate,
            expiryDate: dto.expiryDate,
            doesNotExpire: dto.doesNotExpire,
            credentialID: dto.credentialID,
            credentialURL: dto.credentialURL,
            originalFilename: dto.originalFilename,
            contentType: dto.contentType,
            byteSize: dto.byteSize,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus),
            rawVerificationStatus: dto.verificationStatus
        )
    }
}

extension CareerProjectRecord {
    nonisolated init(dto: CareerProjectDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            // Keep absent data empty. This record also seeds the editable draft.
            role: dto.role ?? "",
            description: dto.description,
            startDate: dto.startDate,
            endDate: dto.isOngoing ? nil : dto.endDate,
            isOngoing: dto.isOngoing,
            projectURL: dto.projectURL,
            repositoryURL: dto.repositoryURL,
            organizationName: dto.organizationName,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus),
            rawVerificationStatus: dto.verificationStatus
        )
    }
}

extension CareerSkillRecord {
    nonisolated init(dto: CareerSkillDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus),
            rawVerificationStatus: dto.verificationStatus
        )
    }
}
