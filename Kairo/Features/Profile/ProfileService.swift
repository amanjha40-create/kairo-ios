import Foundation

protocol ProfileServiceProtocol: Sendable {
    func load() async throws -> ProfileSnapshot
    func update(_ draft: ProfileEditDraft) async throws -> ProfileSnapshot
    func uploadAvatar(jpegData: Data) async throws -> ProfileSnapshot
    func removeAvatar() async throws -> ProfileSnapshot
    func addSkill(name: String) async throws -> ProfileSnapshot
    func removeSkill(id: String) async throws -> ProfileSnapshot
    func addLanguage(name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot
    func updateLanguage(id: String, name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot
    func removeLanguage(id: String) async throws -> ProfileSnapshot
    func addLink(type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot
    func updateLink(id: String, type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot
    func removeLink(id: String) async throws -> ProfileSnapshot
}

actor ProfileService: ProfileServiceProtocol {
    private let session: any SessionServiceProtocol
    private let transfer: SecureDocumentTransferClient
    private var lastLoadedUser: AppUser?

    init(
        session: any SessionServiceProtocol,
        transfer: SecureDocumentTransferClient = SecureDocumentTransferClient()
    ) {
        self.session = session
        self.transfer = transfer
    }

    func load() async throws -> ProfileSnapshot {
        async let userData = session.sendAuthenticated(jsonRequest(path: "/users/me"))
        async let skillsData = session.sendAuthenticated(jsonRequest(path: "/skills"))
        let (resolvedUser, resolvedSkills) = try await (userData, skillsData)
        let decoder = APIJSONCoder.makeDecoder()
        let snapshot = ProfileSnapshot(
            user: try decoder.decode(UserPublicDTO.self, from: resolvedUser).asDomainModel(),
            skills: try decoder.decode([CareerSkillDTO].self, from: resolvedSkills).map {
                ProfileSkill(id: $0.id, name: $0.name)
            }
        )
        lastLoadedUser = snapshot.user
        return snapshot
    }

    func update(_ draft: ProfileEditDraft) async throws -> ProfileSnapshot {
        _ = try await session.sendAuthenticated(
            try jsonRequest(path: "/users/me", method: .patch, body: draft.request)
        )
        return try await load()
    }

    func uploadAvatar(jpegData: Data) async throws -> ProfileSnapshot {
        guard !jpegData.isEmpty else { throw ProfileServiceError.emptyPhoto }
        guard jpegData.count <= 5 * 1_024 * 1_024 else { throw ProfileServiceError.photoTooLarge }
        let data = try await session.sendAuthenticated(
            try jsonRequest(
                path: "/users/me/avatar-upload-url",
                method: .post,
                body: ProfileAvatarIntentRequestDTO(contentType: "image/jpeg")
            )
        )
        let intent = try APIJSONCoder.makeDecoder().decode(ProfileAvatarIntentDTO.self, from: data)
        let selection = SecureDocumentSelection(
            filename: "profile-photo.jpg",
            contentType: "image/jpeg",
            data: jpegData
        )
        try await transfer.upload(selection, to: intent.uploadURL, requiredHeaders: ["Content-Type": "image/jpeg"])
        _ = try await session.sendAuthenticated(
            jsonRequest(path: "/users/me/avatar/complete", method: .post)
        )
        return try await load()
    }

    func removeAvatar() async throws -> ProfileSnapshot {
        _ = try await session.sendAuthenticated(jsonRequest(path: "/users/me/avatar", method: .delete))
        return try await load()
    }

    func addSkill(name: String) async throws -> ProfileSnapshot {
        guard let skill = ProfileCatalogues.resolve(name, in: ProfileCatalogues.skills) else {
            throw ProfileServiceError.invalidSkill
        }
        _ = try await session.sendAuthenticated(
            try jsonRequest(path: "/skills", method: .post, body: CareerSkillCreateRequestDTO(name: skill.name))
        )
        return try await load()
    }

    func removeSkill(id: String) async throws -> ProfileSnapshot {
        _ = try await session.sendAuthenticated(jsonRequest(path: "/skills/\(id)", method: .delete))
        return try await load()
    }

    func addLanguage(name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        guard let language = ProfileCatalogues.resolve(name, in: ProfileCatalogues.languages) else {
            throw ProfileServiceError.invalidLanguage
        }
        _ = try await session.sendAuthenticated(
            try jsonRequest(
                path: "/users/me/languages",
                method: .post,
                body: ProfileLanguageMutationDTO(language: language.name, proficiency: proficiency)
            )
        )
        return try await load()
    }

    func updateLanguage(
        id: String,
        name: String,
        proficiency: ProfileLanguageProficiency
    ) async throws -> ProfileSnapshot {
        guard let language = ProfileCatalogues.resolve(name, in: ProfileCatalogues.languages) else {
            throw ProfileServiceError.invalidLanguage
        }
        _ = try await session.sendAuthenticated(
            try jsonRequest(
                path: "/users/me/languages/\(id)",
                method: .patch,
                body: ProfileLanguageMutationDTO(language: language.name, proficiency: proficiency)
            )
        )
        return try await load()
    }

    func removeLanguage(id: String) async throws -> ProfileSnapshot {
        _ = try await session.sendAuthenticated(
            jsonRequest(path: "/users/me/languages/\(id)", method: .delete)
        )
        return try await load()
    }

    func addLink(type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        try await mutateLink(path: "/users/me/links", method: .post, type: type, label: label, url: url)
    }

    func updateLink(
        id: String,
        type: ProfileLinkType,
        label: String?,
        url: URL
    ) async throws -> ProfileSnapshot {
        try await mutateLink(path: "/users/me/links/\(id)", method: .patch, type: type, label: label, url: url)
    }

    func removeLink(id: String) async throws -> ProfileSnapshot {
        _ = try await session.sendAuthenticated(jsonRequest(path: "/users/me/links/\(id)", method: .delete))
        return try await load()
    }

    private func mutateLink(
        path: String,
        method: HTTPMethod,
        type: ProfileLinkType,
        label: String?,
        url: URL
    ) async throws -> ProfileSnapshot {
        guard let safeURL = ProfileURLValidator.normalized(url.absoluteString) else {
            throw ProfileServiceError.unsafeURL
        }
        let existingID = path.split(separator: "/").last.map(String.init)
        let existing = lastLoadedUser?.professionalLinks.first { $0.id == existingID }
        let labelChange: OptionalFieldChange<String>? = method == .patch
            ? (existing.map { .between($0.label, label) } ?? label.map { .set($0) } ?? .clear)
            : nil
        _ = try await session.sendAuthenticated(
            try jsonRequest(
                path: path,
                method: method,
                body: ProfileLinkMutationDTO(linkType: type, label: label, url: safeURL.absoluteString,
                    labelChange: labelChange)
            )
        )
        return try await load()
    }

    private func jsonRequest(path: String, method: HTTPMethod = .get) -> NetworkRequest {
        NetworkRequest(path: path, method: method, headers: ["Accept": "application/json"])
    }

    private func jsonRequest<Body: Encodable>(
        path: String,
        method: HTTPMethod,
        body: Body
    ) throws -> NetworkRequest {
        NetworkRequest(
            path: path,
            method: method,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try APIJSONCoder.makeEncoder().encode(body)
        )
    }
}

actor ProfileFixtureService: ProfileServiceProtocol {
    private var snapshot: ProfileSnapshot
    private var sequence = 0

    init(snapshot: ProfileSnapshot = .fixture) {
        self.snapshot = snapshot
    }

    func load() async throws -> ProfileSnapshot { snapshot }

    func update(_ draft: ProfileEditDraft) async throws -> ProfileSnapshot {
        let user = snapshot.user.replacing(with: draft)
        snapshot = ProfileSnapshot(user: user, skills: snapshot.skills)
        return snapshot
    }

    func uploadAvatar(jpegData: Data) async throws -> ProfileSnapshot {
        guard !jpegData.isEmpty else { throw ProfileServiceError.emptyPhoto }
        snapshot = ProfileSnapshot(user: snapshot.user.replacingAvatar("https://example.invalid/avatar.jpg"), skills: snapshot.skills)
        return snapshot
    }

    func removeAvatar() async throws -> ProfileSnapshot {
        snapshot = ProfileSnapshot(user: snapshot.user.replacingAvatar(nil), skills: snapshot.skills)
        return snapshot
    }

    func addSkill(name: String) async throws -> ProfileSnapshot {
        guard let skill = ProfileCatalogues.resolve(name, in: ProfileCatalogues.skills) else {
            throw ProfileServiceError.invalidSkill
        }
        sequence += 1
        snapshot = ProfileSnapshot(
            user: snapshot.user,
            skills: snapshot.skills + [ProfileSkill(id: "fixture_skill_\(sequence)", name: skill.name)]
        )
        return snapshot
    }

    func removeSkill(id: String) async throws -> ProfileSnapshot {
        snapshot = ProfileSnapshot(user: snapshot.user, skills: snapshot.skills.filter { $0.id != id })
        return snapshot
    }

    func addLanguage(name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        guard let language = ProfileCatalogues.resolve(name, in: ProfileCatalogues.languages) else {
            throw ProfileServiceError.invalidLanguage
        }
        sequence += 1
        let item = AppUser.Language(id: "fixture_language_\(sequence)", language: language.name, proficiency: proficiency.rawValue)
        snapshot = ProfileSnapshot(user: snapshot.user.replacingLanguages(snapshot.user.languages + [item]), skills: snapshot.skills)
        return snapshot
    }

    func updateLanguage(id: String, name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        guard let language = ProfileCatalogues.resolve(name, in: ProfileCatalogues.languages) else {
            throw ProfileServiceError.invalidLanguage
        }
        let values = snapshot.user.languages.map {
            $0.id == id ? AppUser.Language(id: id, language: language.name, proficiency: proficiency.rawValue) : $0
        }
        snapshot = ProfileSnapshot(user: snapshot.user.replacingLanguages(values), skills: snapshot.skills)
        return snapshot
    }

    func removeLanguage(id: String) async throws -> ProfileSnapshot {
        snapshot = ProfileSnapshot(user: snapshot.user.replacingLanguages(snapshot.user.languages.filter { $0.id != id }), skills: snapshot.skills)
        return snapshot
    }

    func addLink(type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        guard let safeURL = ProfileURLValidator.normalized(url.absoluteString) else {
            throw ProfileServiceError.unsafeURL
        }
        sequence += 1
        let item = AppUser.ProfessionalLink(id: "fixture_link_\(sequence)", linkType: type.rawValue, label: label, url: safeURL.absoluteString)
        snapshot = ProfileSnapshot(user: snapshot.user.replacingLinks(snapshot.user.professionalLinks + [item]), skills: snapshot.skills)
        return snapshot
    }

    func updateLink(id: String, type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        guard let safeURL = ProfileURLValidator.normalized(url.absoluteString) else {
            throw ProfileServiceError.unsafeURL
        }
        let values = snapshot.user.professionalLinks.map {
            $0.id == id ? AppUser.ProfessionalLink(id: id, linkType: type.rawValue, label: label, url: safeURL.absoluteString) : $0
        }
        snapshot = ProfileSnapshot(user: snapshot.user.replacingLinks(values), skills: snapshot.skills)
        return snapshot
    }

    func removeLink(id: String) async throws -> ProfileSnapshot {
        snapshot = ProfileSnapshot(user: snapshot.user.replacingLinks(snapshot.user.professionalLinks.filter { $0.id != id }), skills: snapshot.skills)
        return snapshot
    }
}

private extension AppUser {
    nonisolated func replacing(with draft: ProfileEditDraft) -> AppUser {
        AppUser(
            id: id, email: email, fullName: draft.request.fullName, profileSlug: profileSlug,
            phone: draft.request.phone, currentRole: draft.request.currentRole, industry: draft.request.industry,
            yearsOfExperience: draft.request.yearsOfExperience, location: draft.request.location,
            locationCity: draft.request.locationCity, locationRegion: draft.request.locationRegion,
            locationCountry: draft.request.locationCountry, headline: draft.request.headline,
            bio: draft.request.bio, dateOfBirth: draft.parsedDateOfBirth, avatarURL: avatarURL, role: role,
            isActive: isActive, phoneVerifiedAt: phoneVerifiedAt, emailVerifiedAt: emailVerifiedAt,
            employmentOnboardingCompletedAt: employmentOnboardingCompletedAt, languages: languages,
            professionalLinks: professionalLinks, profileCompletionPercentage: profileCompletionPercentage,
            createdAt: createdAt
        )
    }

    nonisolated func replacingAvatar(_ value: String?) -> AppUser {
        copy(avatarURL: value, languages: languages, links: professionalLinks)
    }

    nonisolated func replacingLanguages(_ value: [Language]) -> AppUser {
        copy(avatarURL: avatarURL, languages: value, links: professionalLinks)
    }

    nonisolated func replacingLinks(_ value: [ProfessionalLink]) -> AppUser {
        copy(avatarURL: avatarURL, languages: languages, links: value)
    }

    nonisolated func copy(avatarURL: String?, languages: [Language], links: [ProfessionalLink]) -> AppUser {
        AppUser(
            id: id, email: email, fullName: fullName, profileSlug: profileSlug, phone: phone,
            currentRole: currentRole, industry: industry, yearsOfExperience: yearsOfExperience,
            location: location, locationCity: locationCity, locationRegion: locationRegion,
            locationCountry: locationCountry, headline: headline, bio: bio, dateOfBirth: dateOfBirth,
            avatarURL: avatarURL, role: role, isActive: isActive, phoneVerifiedAt: phoneVerifiedAt,
            emailVerifiedAt: emailVerifiedAt, employmentOnboardingCompletedAt: employmentOnboardingCompletedAt,
            languages: languages, professionalLinks: links, profileCompletionPercentage: profileCompletionPercentage,
            createdAt: createdAt
        )
    }
}

nonisolated enum ProfileServiceError: Error, LocalizedError, Equatable, Sendable {
    case emptyPhoto
    case photoTooLarge
    case invalidSkill
    case invalidLanguage
    case unsafeURL

    var errorDescription: String? {
        switch self {
        case .emptyPhoto: "Choose a profile photo."
        case .photoTooLarge: "Choose a profile photo no larger than 5 MB."
        case .invalidSkill: "Choose a Skill from the catalogue."
        case .invalidLanguage: "Choose a Language from the catalogue."
        case .unsafeURL: "Enter a valid HTTP or HTTPS professional link."
        }
    }
}

struct MissingProfileService: ProfileServiceProtocol {
    private func missing<T>() -> T { fatalError("Missing Profile service injection.") }

    func load() async throws -> ProfileSnapshot { missing() }
    func update(_ draft: ProfileEditDraft) async throws -> ProfileSnapshot { _ = draft; return missing() }
    func uploadAvatar(jpegData: Data) async throws -> ProfileSnapshot { _ = jpegData; return missing() }
    func removeAvatar() async throws -> ProfileSnapshot { missing() }
    func addSkill(name: String) async throws -> ProfileSnapshot { _ = name; return missing() }
    func removeSkill(id: String) async throws -> ProfileSnapshot { _ = id; return missing() }
    func addLanguage(name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        _ = (name, proficiency); return missing()
    }
    func updateLanguage(id: String, name: String, proficiency: ProfileLanguageProficiency) async throws -> ProfileSnapshot {
        _ = (id, name, proficiency); return missing()
    }
    func removeLanguage(id: String) async throws -> ProfileSnapshot { _ = id; return missing() }
    func addLink(type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        _ = (type, label, url); return missing()
    }
    func updateLink(id: String, type: ProfileLinkType, label: String?, url: URL) async throws -> ProfileSnapshot {
        _ = (id, type, label, url); return missing()
    }
    func removeLink(id: String) async throws -> ProfileSnapshot { _ = id; return missing() }
}
