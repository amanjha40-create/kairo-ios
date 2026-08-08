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
    let company: String
    let role: String
    let employmentType: String?
    let startDate: Date?
    let endDate: Date?
    let currentlyWorking: Bool
    let verificationStatus: CareerRecordVerificationStatus
}

struct CareerEducationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let institution: String
    let degree: String
    let fieldOfStudy: String?
    let startYear: Int?
    let endYear: Int?
    let verificationStatus: CareerRecordVerificationStatus
}

struct CareerCertificationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let issuer: String
    let issueDate: Date?
    let verificationStatus: CareerRecordVerificationStatus
}

struct CareerProjectRecord: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let role: String
    let startDate: Date?
    let endDate: Date?
    let portfolioURL: URL?
    let verificationStatus: CareerRecordVerificationStatus?
}

struct CareerSkillRecord: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
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
            company: dto.companyDisplayName,
            role: dto.jobTitle,
            employmentType: dto.employmentType,
            startDate: dto.startDate,
            endDate: dto.endDate,
            currentlyWorking: dto.currentlyWorking,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
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
            startYear: Date.utcYear(from: dto.startDate),
            endYear: dto.isCurrentlyStudying ? nil : Date.utcYear(from: dto.endDate),
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
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
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
        )
    }
}

extension CareerProjectRecord {
    nonisolated init(dto: CareerProjectDTO) {
        self.init(
            id: dto.id,
            title: dto.title,
            role: dto.role ?? "Role not added yet",
            startDate: dto.startDate,
            endDate: dto.isOngoing ? nil : dto.endDate,
            portfolioURL: dto.projectURL ?? dto.repositoryURL,
            verificationStatus: .init(rawBackendValue: dto.verificationStatus)
        )
    }
}

extension CareerSkillRecord {
    nonisolated init(dto: CareerSkillDTO) {
        self.init(id: dto.id, name: dto.name)
    }
}

private extension Date {
    nonisolated static func utcYear(from date: Date?) -> Int? {
        guard let date else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar.component(.year, from: date)
    }
}
