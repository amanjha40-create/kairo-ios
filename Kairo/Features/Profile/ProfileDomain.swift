import Foundation

nonisolated struct ProfileSnapshot: Equatable, Sendable {
    let user: AppUser
    let skills: [ProfileSkill]
}

nonisolated struct ProfileSkill: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
}

nonisolated enum ProfileLanguageProficiency: String, CaseIterable, Codable, Sendable {
    case basic
    case conversational
    case professional
    case fluent
    case native

    var title: String {
        switch self {
        case .basic: "Basic"
        case .conversational: "Conversational"
        case .professional: "Professional"
        case .fluent: "Fluent"
        case .native: "Native / Bilingual"
        }
    }
}

nonisolated enum ProfileLinkType: String, CaseIterable, Codable, Sendable {
    case linkedin
    case github
    case website
    case portfolio
    case other

    var title: String {
        switch self {
        case .linkedin: "LinkedIn"
        case .github: "GitHub"
        case .website: "Personal Website"
        case .portfolio: "Professional Portfolio"
        case .other: "Other Professional Link"
        }
    }
}

nonisolated struct ProfileEditDraft: Equatable, Sendable {
    var fullName: String
    var phone: String
    var headline: String
    var currentRole: String
    var industry: String
    var yearsOfExperience: String
    var location: String
    var locationCity: String
    var locationRegion: String
    var locationCountry: String
    var bio: String
    var dateOfBirth: String
    private var originalText: [String: String] = [:]
    private var originalExperience: Int?

    init(user: AppUser) {
        fullName = user.fullName ?? ""
        phone = user.phone ?? ""
        headline = user.headline ?? ""
        currentRole = user.currentRole ?? ""
        industry = user.industry ?? ""
        yearsOfExperience = user.yearsOfExperience.map(String.init) ?? ""
        location = user.location ?? ""
        locationCity = user.locationCity ?? ""
        locationRegion = user.locationRegion ?? ""
        locationCountry = user.locationCountry ?? ""
        bio = user.bio ?? ""
        dateOfBirth = user.dateOfBirth.map(Self.dateFormatter.string(from:)) ?? ""
        originalText = textValues
        originalExperience = user.yearsOfExperience
    }

    private var textValues: [String: String] {
        ["fullName": fullName, "phone": phone, "currentRole": currentRole, "industry": industry,
         "location": location, "locationCity": locationCity, "locationRegion": locationRegion,
         "locationCountry": locationCountry, "headline": headline, "bio": bio, "dateOfBirth": dateOfBirth]
    }

    var validationErrors: [String: String] {
        var errors: [String: String] = [:]
        if profileNormalized(fullName).isEmpty {
            errors["full_name"] = "Enter your full name."
        }
        if !profileNormalized(yearsOfExperience).isEmpty,
           Int(profileNormalized(yearsOfExperience)).map({ (0 ... 80).contains($0) }) != true {
            errors["years_of_experience"] = "Enter whole years from 0 to 80."
        }
        let country = profileNormalized(locationCountry)
        if locationCountry != originalText["locationCountry"], !country.isEmpty, country.count != 2 {
            errors["location_country"] = "Use the two-letter country code."
        }
        let date = profileNormalized(dateOfBirth)
        if !date.isEmpty, Self.dateFormatter.date(from: date) == nil {
            errors["date_of_birth"] = "Use YYYY-MM-DD."
        }
        if bio.count > 500 {
            errors["bio"] = "About must be 500 characters or fewer."
        }
        return errors
    }

    var request: ProfileUpdateRequestDTO {
        ProfileUpdateRequestDTO(
            fullName: profileOptional(fullName),
            phone: profileOptional(phone),
            currentRole: profileOptional(currentRole),
            industry: profileOptional(industry),
            yearsOfExperience: Int(profileNormalized(yearsOfExperience)),
            location: profileOptional(location),
            locationCity: profileOptional(locationCity),
            locationRegion: profileOptional(locationRegion),
            locationCountry: profileOptional(locationCountry)?.uppercased(),
            headline: profileOptional(headline),
            bio: profileOptional(bio),
            dateOfBirth: profileOptional(dateOfBirth),
            fieldChanges: Dictionary(uniqueKeysWithValues: textValues.map { key, value in
                    (key, OptionalFieldChange<String>.edited(original: originalText[key], current: value,
                        encoded: key == "locationCountry" ? profileOptional(value)?.uppercased() : profileOptional(value)))
                }),
            experienceChange: .between(originalExperience, Int(profileNormalized(yearsOfExperience)))
        )
    }

    var parsedDateOfBirth: Date? {
        let value = profileNormalized(dateOfBirth)
        return value.isEmpty ? nil : Self.dateFormatter.date(from: value)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()
}

nonisolated enum ProfileURLValidator {
    static func normalized(_ value: String) -> URL? {
        var candidate = profileNormalized(value)
        guard !candidate.isEmpty else { return nil }
        if !candidate.contains("://") {
            guard candidate.split(separator: "/", maxSplits: 1).first?.contains(":") != true else {
                return nil
            }
            candidate = "https://\(candidate)"
        }
        guard let components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              let url = components.url else {
            return nil
        }
        return url
    }
}

nonisolated func profileNormalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: \.isWhitespace)
        .joined(separator: " ")
}

nonisolated func profileOptional(_ value: String) -> String? {
    let value = profileNormalized(value)
    return value.isEmpty ? nil : value
}

nonisolated struct ProfileUpdateRequestDTO: Encodable, Equatable, Sendable {
    let fullName: String?
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
    let dateOfBirth: String?
    var fieldChanges: [String: OptionalFieldChange<String>] = [:]
    var experienceChange: OptionalFieldChange<Int>? = nil

    func encode(to encoder: Encoder) throws {
        try encodeOptionalStringChanges(to: encoder, values: [
            "fullName": fullName, "phone": phone, "currentRole": currentRole, "industry": industry,
            "location": location, "locationCity": locationCity, "locationRegion": locationRegion,
            "locationCountry": locationCountry, "headline": headline, "bio": bio, "dateOfBirth": dateOfBirth
        ], changes: fieldChanges)
        var container = encoder.container(keyedBy: PatchFieldKey.self)
        try container.encodeChange(experienceChange ?? .supplied(yearsOfExperience), forKey: .init("yearsOfExperience"))
    }
}

nonisolated struct ProfileLanguageMutationDTO: Encodable, Equatable, Sendable {
    let language: String
    let proficiency: ProfileLanguageProficiency
}

nonisolated struct ProfileLinkMutationDTO: Encodable, Equatable, Sendable {
    let linkType: ProfileLinkType
    let label: String?
    let url: String
    var labelChange: OptionalFieldChange<String>? = nil
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: PatchFieldKey.self)
        try container.encode(linkType, forKey: .init("linkType"))
        try container.encode(url, forKey: .init("url"))
        try container.encodeChange(labelChange ?? .supplied(label), forKey: .init("label"))
    }
}

nonisolated struct ProfileAvatarIntentDTO: Decodable, Equatable, Sendable {
    let uploadURL: URL

    private enum CodingKeys: String, CodingKey {
        case uploadURL = "uploadUrl"
    }
}

nonisolated struct ProfileAvatarIntentRequestDTO: Encodable, Equatable, Sendable {
    let contentType: String
}

extension ProfileSnapshot {
    nonisolated static var fixture: ProfileSnapshot {
        ProfileSnapshot(
            user: AppUser(
                id: "profile_fixture",
                email: "candidate@example.invalid",
                fullName: "Aarav Mehta",
                profileSlug: "aarav-mehta",
                phone: "+919876543210",
                currentRole: "Product Operations Manager",
                industry: "Technology",
                yearsOfExperience: 6,
                location: "Bengaluru, India",
                locationCity: "Bengaluru",
                locationRegion: "Karnataka",
                locationCountry: "IN",
                headline: "Building trustworthy professional products",
                bio: "Product operator focused on portable professional trust.",
                dateOfBirth: nil,
                avatarURL: nil,
                role: "candidate",
                isActive: true,
                phoneVerifiedAt: .distantPast,
                emailVerifiedAt: .distantPast,
                employmentOnboardingCompletedAt: .distantPast,
                languages: [
                    .init(id: "language_fixture_en", language: "English", proficiency: "fluent"),
                    .init(id: "language_fixture_hi", language: "Hindi", proficiency: "native")
                ],
                professionalLinks: [
                    .init(
                        id: "link_fixture",
                        linkType: "linkedin",
                        label: "LinkedIn",
                        url: "https://www.linkedin.com/in/kairoid-fixture"
                    )
                ],
                profileCompletionPercentage: 100,
                createdAt: .distantPast
            ),
            skills: [
                ProfileSkill(id: "skill_fixture_sql", name: "SQL"),
                ProfileSkill(id: "skill_fixture_product", name: "Product Management"),
                ProfileSkill(id: "skill_fixture_excel", name: "Microsoft Excel")
            ]
        )
    }
}
