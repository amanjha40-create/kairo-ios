import Foundation

struct CareerOverview: Equatable, Sendable {
    let user: AppUser
    let employments: [CareerEmploymentRecord]
    let educations: [CareerEducationRecord]
    let certifications: [CareerCertificationRecord]
    let projects: [CareerProjectRecord]
    let skills: [CareerSkillRecord]
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
            rawVerificationStatus: dto.verificationStatus
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
            role: dto.role ?? "Role not added yet",
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
