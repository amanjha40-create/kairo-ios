import Foundation

nonisolated struct OwnerPassportResponseDTO: Decodable, Equatable, Sendable {
    let profile: UserPublicDTO
    let trustScore: TrustScoreResponseDTO
    let vault: PublicPassportVaultDTO
    let passportMetadata: PassportMetadataDTO
    let sharingSummary: PassportSharingSummaryDTO
    let verificationSummary: PassportVerificationSummaryDTO
}

nonisolated struct PassportMetadataDTO: Decodable, Equatable, Sendable {
    let ownerUserId: String
    let profileSlug: String?
    let isEmailVerified: Bool
    let isOnboardingComplete: Bool
    let createdAt: Date
    let updatedAt: Date
    let employmentOnboardingCompletedAt: Date?
}

nonisolated struct PassportSharingSummaryDTO: Decodable, Equatable, Sendable {
    let totalLinks: Int
    let activeLinks: Int
    let revokedLinks: Int
    let expiredLinks: Int
    let totalViews: Int
    let uniqueViews: Int
    let latestShareCreatedAt: Date?
    let lastViewedAt: Date?
}

nonisolated struct PublicPassportVaultDTO: Decodable, Equatable, Sendable {
    let employments: [PublicPassportEmploymentDTO]
    let educations: [PublicPassportEducationDTO]
    let internships: [PublicPassportEmploymentDTO]
    let freelance: [PublicPassportEmploymentDTO]
    let gigPlatforms: [PublicPassportEmploymentDTO]
    let portfolio: [PublicPassportProjectDTO]
    let certifications: [PublicPassportCertificationDTO]
    let skills: [PublicPassportSkillDTO]
    let projects: [PublicPassportProjectDTO]
    let userDocuments: [PublicPassportDocumentDTO]

    private enum CodingKeys: String, CodingKey {
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
        employments = try container.decodeIfPresent([PublicPassportEmploymentDTO].self, forKey: .employments) ?? []
        educations = try container.decodeIfPresent([PublicPassportEducationDTO].self, forKey: .educations) ?? []
        internships = try container.decodeIfPresent([PublicPassportEmploymentDTO].self, forKey: .internships) ?? []
        freelance = try container.decodeIfPresent([PublicPassportEmploymentDTO].self, forKey: .freelance) ?? []
        gigPlatforms = try container.decodeIfPresent([PublicPassportEmploymentDTO].self, forKey: .gigPlatforms) ?? []
        portfolio = try container.decodeIfPresent([PublicPassportProjectDTO].self, forKey: .portfolio) ?? []
        certifications = try container.decodeIfPresent([PublicPassportCertificationDTO].self, forKey: .certifications) ?? []
        skills = try container.decodeIfPresent([PublicPassportSkillDTO].self, forKey: .skills) ?? []
        projects = try container.decodeIfPresent([PublicPassportProjectDTO].self, forKey: .projects) ?? []
        userDocuments = try container.decodeIfPresent([PublicPassportDocumentDTO].self, forKey: .userDocuments) ?? []
    }
}

nonisolated struct PublicPassportEmploymentDTO: Decodable, Equatable, Sendable {
    let id: String
    let employerLegalName: String?
    let jobTitle: String
    let startDate: Date?
    let endDate: Date?
    let verificationStatus: String
    let verificationMethod: String
    let documents: [PublicPassportDocumentDTO]
}

nonisolated struct PublicPassportEducationDTO: Decodable, Equatable, Sendable {
    let id: String
    let institutionName: String?
    let degree: String?
    let fieldOfStudy: String?
    let educationLevel: String?
    let grade: String?
    let startDate: Date?
    let endDate: Date?
    let startDatePrecision: String?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
    let verificationStatus: String
}

nonisolated struct PublicPassportCertificationDTO: Decodable, Equatable, Sendable {
    let id: String
    let title: String
    let issuingOrganization: String?
    let issuedDate: Date?
    let expiryDate: Date?
    let doesNotExpire: Bool
    let credentialID: String?
    let credentialURL: URL?
    let verificationStatus: String
}

nonisolated struct PublicPassportProjectDTO: Decodable, Equatable, Sendable {
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
    let verificationStatus: String?
}

nonisolated struct PublicPassportSkillDTO: Decodable, Equatable, Sendable {
    let name: String
    let verificationStatus: String
}

nonisolated struct PublicPassportDocumentDTO: Decodable, Equatable, Sendable {
    let id: String
    let documentType: String
    let originalFilename: String
    let byteSize: Int
    let verificationStatus: String
}
