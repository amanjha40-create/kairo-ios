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
    var locationRegion: String? = nil
    var locationChanges: [String: OptionalFieldChange<String>] = [:]
    func encode(to encoder: Encoder) throws {
        try encodeOptionalStringChanges(to: encoder, values: [
            "fullName": fullName, "currentRole": currentRole, "industry": industry, "headline": headline,
            "location": location, "locationCity": locationCity, "locationRegion": locationRegion, "locationCountry": locationCountry
        ], changes: locationChanges)
        var container = encoder.container(keyedBy: PatchFieldKey.self)
        try container.encode(yearsOfExperience, forKey: .init("yearsOfExperience"))
    }
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
    let workLocationCountry: String?
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
    var institutionCatalogueID: String? = nil
    var institutionCatalogueVersion: String? = nil

    func encode(to encoder: Encoder) throws {
        try CareerEducationCreateRequestDTO(institutionName: institutionName, degree: degree,
            fieldOfStudy: fieldOfStudy, educationLevel: educationLevel, grade: grade,
            startDate: startDate, startDatePrecision: startDatePrecision, endDate: endDate,
            endDatePrecision: endDatePrecision, isCurrentlyStudying: isCurrentlyStudying,
            institutionCatalogueID: institutionCatalogueID, institutionCatalogueVersion: institutionCatalogueVersion).encode(to: encoder)
    }
}

nonisolated struct ManualCreatedRecordDTO: Decodable, Equatable, Sendable {
    let id: String
}
