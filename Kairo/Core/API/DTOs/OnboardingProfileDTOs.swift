import Foundation

nonisolated struct OnboardingProfileUpdateRequestDTO: Encodable, Equatable, Sendable {
    let fullName: String?
    let currentRole: String
    let industry: String
    let yearsOfExperience: Int
    let location: String?
    let locationCity: String?
    let locationCountry: String?
    let headline: String
}

nonisolated struct ManualEmploymentCreateRequestDTO: Encodable, Equatable, Sendable {
    let subjectFullName: String
    let subjectEmail: String?
    let employerLegalName: String
    let employerTradeName: String?
    let jobTitle: String
    let employmentType: String
    let verificationMethod: String
    let startDate: String
    let endDate: String?
    let workLocationCountry: String
    let workLocationRegion: String?
}

nonisolated struct ManualEducationCreateRequestDTO: Encodable, Equatable, Sendable {
    let institutionName: String
    let degree: String
    let fieldOfStudy: String?
    let educationLevel: String
    let grade: String?
    let startDate: String
    let startDatePrecision: String?
    let endDate: String?
    let endDatePrecision: String?
    let isCurrentlyStudying: Bool
}

nonisolated struct ManualCreatedRecordDTO: Decodable, Equatable, Sendable {
    let id: String
}
