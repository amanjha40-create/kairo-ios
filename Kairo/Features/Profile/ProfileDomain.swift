import Foundation

nonisolated enum ProfileEditTarget: String, Identifiable, Sendable {
    case headline
    case currentRole = "current_role"
    case industry
    case dateOfBirth = "date_of_birth"
    var id: String { rawValue }

    static func requirement(_ code: String) -> Self? { Self(rawValue: code) }
}

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

nonisolated enum ProfileBirthDate {
    private static func formatter(_ format: String) -> DateFormatter {
        let value = DateFormatter()
        value.calendar = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(secondsFromGMT: 0)
        value.dateFormat = format
        value.isLenient = false
        return value
    }
    static func display(_ date: Date) -> String { formatter("dd-MM-yyyy").string(from: date) }
    static func wire(_ date: Date) -> String { formatter("yyyy-MM-dd").string(from: date) }
    static func formatInput(_ text: String) -> String {
        // Format a complete digits-only entry without rewriting partial edits,
        // stripping invalid characters, or guessing another date ordering.
        guard text.range(of: #"^[0-9]{8}$"#, options: .regularExpression) != nil else { return text }
        return "\(text.prefix(2))-\(text.dropFirst(2).prefix(2))-\(text.suffix(4))"
    }
    static func parse(_ text: String) -> Date? {
        let text = formatInput(profileNormalized(text))
        guard text.range(of: #"^[0-9]{2}-[0-9]{2}-[0-9]{4}$"#, options: .regularExpression) != nil,
              let date = formatter("dd-MM-yyyy").date(from: text), display(date) == text else { return nil }
        return date
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
        dateOfBirth = user.dateOfBirth.map(ProfileBirthDate.display) ?? ""
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
        if !date.isEmpty, ProfileBirthDate.parse(date) == nil {
            errors["date_of_birth"] = "Enter a valid date using DD-MM-YYYY."
        }
        if bio.count > 500 {
            errors["bio"] = "Professional Bio must be 500 characters or fewer."
        }
        if profileNormalized(headline).count > 255 {
            errors["headline"] = "Professional headline must be 255 characters or fewer."
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
            bio: profileBio(bio),
            dateOfBirth: parsedDateOfBirth.map(ProfileBirthDate.wire),
            fieldChanges: Dictionary(uniqueKeysWithValues: textValues.map { key, value in
                    (key, OptionalFieldChange<String>.edited(original: originalText[key], current: value,
                        encoded: key == "dateOfBirth" ? parsedDateOfBirth.map(ProfileBirthDate.wire) :
                            (key == "bio" ? profileBio(value) : key == "locationCountry" ? profileOptional(value)?.uppercased() : profileOptional(value))))
                }),
            experienceChange: .between(originalExperience, Int(profileNormalized(yearsOfExperience)))
        )
    }

    var parsedDateOfBirth: Date? {
        let value = profileNormalized(dateOfBirth)
        return value.isEmpty ? nil : ProfileBirthDate.parse(value)
    }

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

nonisolated func profileBio(_ value: String) -> String? {
    let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
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
