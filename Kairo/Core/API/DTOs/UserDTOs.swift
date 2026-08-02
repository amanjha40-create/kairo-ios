import Foundation

nonisolated struct UserPublicDTO: Decodable, Equatable, Sendable {
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
    let languages: [ProfileLanguageDTO]
    let professionalLinks: [ProfileLinkDTO]
    let profileCompletionPercentage: Int
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName
        case profileSlug
        case phone
        case currentRole
        case industry
        case yearsOfExperience
        case location
        case locationCity
        case locationRegion
        case locationCountry
        case headline
        case bio
        case dateOfBirth
        case avatarURL
        case role
        case isActive
        case phoneVerifiedAt
        case emailVerifiedAt
        case employmentOnboardingCompletedAt
        case languages
        case professionalLinks
        case profileCompletionPercentage
        case createdAt
    }

    nonisolated init(
        id: String,
        email: String,
        fullName: String?,
        profileSlug: String?,
        phone: String?,
        currentRole: String?,
        industry: String?,
        yearsOfExperience: Int?,
        location: String?,
        locationCity: String?,
        locationRegion: String?,
        locationCountry: String?,
        headline: String?,
        bio: String?,
        dateOfBirth: Date?,
        avatarURL: String?,
        role: String,
        isActive: Bool,
        phoneVerifiedAt: Date?,
        emailVerifiedAt: Date?,
        employmentOnboardingCompletedAt: Date?,
        languages: [ProfileLanguageDTO],
        professionalLinks: [ProfileLinkDTO],
        profileCompletionPercentage: Int,
        createdAt: Date
    ) {
        self.id = id
        self.email = email
        self.fullName = fullName
        self.profileSlug = profileSlug
        self.phone = phone
        self.currentRole = currentRole
        self.industry = industry
        self.yearsOfExperience = yearsOfExperience
        self.location = location
        self.locationCity = locationCity
        self.locationRegion = locationRegion
        self.locationCountry = locationCountry
        self.headline = headline
        self.bio = bio
        self.dateOfBirth = dateOfBirth
        self.avatarURL = avatarURL
        self.role = role
        self.isActive = isActive
        self.phoneVerifiedAt = phoneVerifiedAt
        self.emailVerifiedAt = emailVerifiedAt
        self.employmentOnboardingCompletedAt = employmentOnboardingCompletedAt
        self.languages = languages
        self.professionalLinks = professionalLinks
        self.profileCompletionPercentage = profileCompletionPercentage
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        fullName = try container.decode(String?.self, forKey: .fullName)
        profileSlug = try container.decodeIfPresent(String.self, forKey: .profileSlug)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        currentRole = try container.decodeIfPresent(String.self, forKey: .currentRole)
        industry = try container.decodeIfPresent(String.self, forKey: .industry)
        yearsOfExperience = try container.decodeIfPresent(Int.self, forKey: .yearsOfExperience)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        locationCity = try container.decodeIfPresent(String.self, forKey: .locationCity)
        locationRegion = try container.decodeIfPresent(String.self, forKey: .locationRegion)
        locationCountry = try container.decodeIfPresent(String.self, forKey: .locationCountry)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        dateOfBirth = try container.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        role = try container.decode(String.self, forKey: .role)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        phoneVerifiedAt = try container.decodeIfPresent(Date.self, forKey: .phoneVerifiedAt)
        emailVerifiedAt = try container.decodeIfPresent(Date.self, forKey: .emailVerifiedAt)
        employmentOnboardingCompletedAt = try container.decodeIfPresent(
            Date.self,
            forKey: .employmentOnboardingCompletedAt
        )
        languages = try container.decodeIfPresent([ProfileLanguageDTO].self, forKey: .languages) ?? []
        professionalLinks = try container.decodeIfPresent(
            [ProfileLinkDTO].self,
            forKey: .professionalLinks
        ) ?? []
        profileCompletionPercentage = try container.decodeIfPresent(
            Int.self,
            forKey: .profileCompletionPercentage
        ) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

nonisolated struct ProfileLanguageDTO: Decodable, Equatable, Sendable {
    let id: String
    let language: String
    let proficiency: String?

    nonisolated init(id: String, language: String, proficiency: String?) {
        self.id = id
        self.language = language
        self.proficiency = proficiency
    }
}

nonisolated struct ProfileLinkDTO: Decodable, Equatable, Sendable {
    let id: String
    let linkType: String
    let label: String?
    let url: String

    nonisolated init(id: String, linkType: String, label: String?, url: String) {
        self.id = id
        self.linkType = linkType
        self.label = label
        self.url = url
    }
}
