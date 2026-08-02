import Foundation

nonisolated struct AppUser: Equatable, Sendable {
    nonisolated struct Language: Equatable, Sendable {
        let id: String
        let language: String
        let proficiency: String?
    }

    nonisolated struct ProfessionalLink: Equatable, Sendable {
        let id: String
        let linkType: String
        let label: String?
        let url: String
    }

    let id: String
    let email: String
    let fullName: String?
    let profileSlug: String?
    let phone: String?
    let currentRole: String?
    let industry: String?
    let yearsOfExperience: Int?
    let location: String?
    let locationCity: String?
    let locationRegion: String?
    let locationCountry: String?
    let headline: String?
    let bio: String?
    let dateOfBirth: Date?
    let avatarURL: String?
    let role: String
    let isActive: Bool
    let phoneVerifiedAt: Date?
    let emailVerifiedAt: Date?
    let employmentOnboardingCompletedAt: Date?
    let languages: [Language]
    let professionalLinks: [ProfessionalLink]
    let profileCompletionPercentage: Int
    let createdAt: Date
}

extension UserPublicDTO {
    nonisolated func asDomainModel() -> AppUser {
        AppUser(
            id: id,
            email: email,
            fullName: fullName,
            profileSlug: profileSlug,
            phone: phone,
            currentRole: currentRole,
            industry: industry,
            yearsOfExperience: yearsOfExperience,
            location: location,
            locationCity: locationCity,
            locationRegion: locationRegion,
            locationCountry: locationCountry,
            headline: headline,
            bio: bio,
            dateOfBirth: dateOfBirth,
            avatarURL: avatarURL,
            role: role,
            isActive: isActive,
            phoneVerifiedAt: phoneVerifiedAt,
            emailVerifiedAt: emailVerifiedAt,
            employmentOnboardingCompletedAt: employmentOnboardingCompletedAt,
            languages: languages.map {
                AppUser.Language(
                    id: $0.id,
                    language: $0.language,
                    proficiency: $0.proficiency
                )
            },
            professionalLinks: professionalLinks.map {
                AppUser.ProfessionalLink(
                    id: $0.id,
                    linkType: $0.linkType,
                    label: $0.label,
                    url: $0.url
                )
            },
            profileCompletionPercentage: profileCompletionPercentage,
            createdAt: createdAt
        )
    }
}
