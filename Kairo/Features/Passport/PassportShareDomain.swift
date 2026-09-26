import Foundation

nonisolated struct PassportSharePermissions: Codable, Equatable, Sendable {
    var includeEmployments: Bool
    var includeEducations: Bool
    var includeInternships: Bool
    var includeFreelance: Bool
    var includeGigPlatforms: Bool
    var includePortfolio: Bool
    var includeCertifications: Bool
    var includeSkills: Bool
    var includeProjects: Bool
    var includeUserDocuments: Bool
    var showEmployerNames: Bool
    var showDocuments: Bool
    var showTrustScore: Bool
    // Pre-V2 responses implicitly included profile and photo. Preserve that legacy truth.
    var includeProfile: Bool = true
    var showPhoto: Bool = true

    static let privacyPreserving = PassportSharePermissions(
        includeEmployments: false,
        includeEducations: false,
        includeInternships: false,
        includeFreelance: false,
        includeGigPlatforms: false,
        includePortfolio: false,
        includeCertifications: false,
        includeSkills: false,
        includeProjects: false,
        includeUserDocuments: false,
        showEmployerNames: false,
        showDocuments: false,
        showTrustScore: false,
        includeProfile: false,
        showPhoto: false
    )

    func isEnabled(_ option: PassportSharePermissionOption) -> Bool {
        switch option {
        case .employments: includeEmployments
        case .educations: includeEducations
        case .internships: includeInternships
        case .freelance: includeFreelance
        case .gigPlatforms: includeGigPlatforms
        case .portfolio: includePortfolio
        case .certifications: includeCertifications
        case .skills: includeSkills
        case .projects: includeProjects
        case .userDocuments: includeUserDocuments
        case .employerNames: showEmployerNames
        case .documents: showDocuments
        case .trustScore: showTrustScore
        case .profile: includeProfile
        case .photo: showPhoto
        }
    }

    mutating func set(_ enabled: Bool, for option: PassportSharePermissionOption) {
        switch option {
        case .employments: includeEmployments = enabled
        case .educations: includeEducations = enabled
        case .internships: includeInternships = enabled
        case .freelance: includeFreelance = enabled
        case .gigPlatforms: includeGigPlatforms = enabled
        case .portfolio: includePortfolio = enabled
        case .certifications: includeCertifications = enabled
        case .skills: includeSkills = enabled
        case .projects: includeProjects = enabled
        case .userDocuments: includeUserDocuments = enabled
        case .employerNames: showEmployerNames = enabled
        case .documents: showDocuments = enabled
        case .trustScore: showTrustScore = enabled
        case .profile: includeProfile = enabled
        case .photo: showPhoto = enabled
        }
    }

    var enabledOptions: [PassportSharePermissionOption] {
        PassportSharePermissionOption.allCases.filter(isEnabled)
    }

    var conciseSummary: String {
        let labels = enabledOptions.map(\.shortTitle)
        guard !labels.isEmpty else { return "No optional sections shared" }
        if labels.count <= 3 { return labels.joined(separator: ", ") }
        return labels.prefix(3).joined(separator: ", ") + " +\(labels.count - 3) more"
    }

    private enum CodingKeys: String, CodingKey {
        case includeEmployments
        case includeEducations
        case includeInternships
        case includeFreelance
        case includeGigPlatforms
        case includePortfolio
        case includeCertifications
        case includeSkills
        case includeProjects
        case includeUserDocuments
        case showEmployerNames
        case showDocuments
        case showTrustScore
        case includeProfile
        case showPhoto
    }
}

extension PassportSharePermissions {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        includeEmployments = try c.decode(Bool.self, forKey: .includeEmployments)
        includeEducations = try c.decode(Bool.self, forKey: .includeEducations)
        includeInternships = try c.decode(Bool.self, forKey: .includeInternships)
        includeFreelance = try c.decode(Bool.self, forKey: .includeFreelance)
        includeGigPlatforms = try c.decode(Bool.self, forKey: .includeGigPlatforms)
        includePortfolio = try c.decode(Bool.self, forKey: .includePortfolio)
        includeCertifications = try c.decode(Bool.self, forKey: .includeCertifications)
        includeSkills = try c.decode(Bool.self, forKey: .includeSkills)
        includeProjects = try c.decode(Bool.self, forKey: .includeProjects)
        includeUserDocuments = try c.decode(Bool.self, forKey: .includeUserDocuments)
        showEmployerNames = try c.decode(Bool.self, forKey: .showEmployerNames)
        showDocuments = try c.decode(Bool.self, forKey: .showDocuments)
        showTrustScore = try c.decode(Bool.self, forKey: .showTrustScore)
        includeProfile = try c.decodeIfPresent(Bool.self, forKey: .includeProfile) ?? true
        showPhoto = try c.decodeIfPresent(Bool.self, forKey: .showPhoto) ?? true
    }
}

nonisolated enum PassportSharePermissionOption: String, CaseIterable, Identifiable, Sendable {
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
    case employerNames
    case documents
    case trustScore
    case profile
    case photo

    static let candidateV1Sections: [PassportSharePermissionOption] = [
        .employments,
        .educations,
        .certifications,
        .skills,
        .projects
    ]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .employments: "Employment"
        case .educations: "Education"
        case .internships: "Internships"
        case .freelance: "Freelance work"
        case .gigPlatforms: "Gig platforms"
        case .portfolio: "Portfolio"
        case .certifications: "Certifications"
        case .skills: "Skills"
        case .projects: "Projects"
        case .userDocuments: "User documents"
        case .employerNames: "Employer names"
        case .documents: "Supporting documents"
        case .trustScore: "Trust Score"
        case .profile: "Profile details"
        case .photo: "Profile photo"
        }
    }

    var shortTitle: String {
        switch self {
        case .userDocuments: "User documents"
        case .employerNames: "Employer names"
        case .documents: "Evidence"
        default: title
        }
    }

    var detail: String {
        switch self {
        case .employments: "Eligible public employment records."
        case .educations: "Eligible education records."
        case .internships: "Eligible internship records."
        case .freelance: "Eligible freelance records."
        case .gigPlatforms: "Eligible gig-platform records."
        case .portfolio: "Eligible portfolio records."
        case .certifications: "Eligible certification records."
        case .skills: "Skills included in your Passport."
        case .projects: "Projects included in your Passport."
        case .userDocuments: "Documents from your user document vault."
        case .employerNames: "Show employer names with shared employment records."
        case .documents: "Show supporting evidence for shared records where available."
        case .trustScore: "Account-wide backend-calculated aggregate, not a score limited to shared records."
        case .profile: "Candidate-provided headline, location and profile details; not verified identity."
        case .photo: "Show your profile photo. Requires profile details."
        }
    }

    var backendKey: String {
        switch self {
        case .employments: "include_employments"
        case .educations: "include_educations"
        case .internships: "include_internships"
        case .freelance: "include_freelance"
        case .gigPlatforms: "include_gig_platforms"
        case .portfolio: "include_portfolio"
        case .certifications: "include_certifications"
        case .skills: "include_skills"
        case .projects: "include_projects"
        case .userDocuments: "include_user_documents"
        case .employerNames: "show_employer_names"
        case .documents: "show_documents"
        case .trustScore: "show_trust_score"
        case .profile: "include_profile"
        case .photo: "show_photo"
        }
    }
}

nonisolated enum PassportSharingMode: String, Codable, Sendable {
    case verifiedOnly = "verified_only"
    case mixed = "verified_and_candidate_provided"
    case legacyMixed = "legacy_mixed"
    case unknown

    var title: String {
        switch self {
        case .verifiedOnly: "Verified only"
        case .mixed: "Verified and candidate-provided"
        case .legacyMixed: "Legacy sharing policy"
        case .unknown: "Sharing policy unavailable"
        }
    }
}

nonisolated struct PassportShareCapabilities: Decodable, Equatable, Sendable {
    let policyVersion: Int
    let defaultMode: String
    let modes: [String]
    let verifiedOnlySections: [String]
    let mixedSections: [String]
    let derivedTrustScore: Bool
    let narrowOnlyUpdates: Bool

    var supportsV2: Bool {
        policyVersion == 2 && defaultMode == PassportSharingMode.verifiedOnly.rawValue
            && modes.contains(defaultMode) && narrowOnlyUpdates
    }

    func options(for mode: PassportSharingMode) -> [PassportSharePermissionOption] {
        guard supportsV2, modes.contains(mode.rawValue), mode == .verifiedOnly || mode == .mixed else { return [] }
        let sections = mode == .verifiedOnly ? verifiedOnlySections : mixedSections
        let allowed: [PassportSharePermissionOption] = mode == .verifiedOnly
            ? [.employments, .educations] : [.employments, .educations, .certifications, .skills, .projects, .userDocuments, .profile, .photo]
        return allowed.filter { sections.contains($0.backendKey) }
            + [.employerNames, .documents] + (derivedTrustScore ? [.trustScore] : [])
    }

    func validate(_ input: PassportShareMutationInput) throws {
        guard supportsV2, modes.contains(input.sharingMode.rawValue) else { throw PassportShareServiceError.capabilitiesUnavailable }
        let supported = options(for: input.sharingMode)
        guard input.permissions.enabledOptions.allSatisfy(supported.contains),
              !input.permissions.showPhoto || input.permissions.includeProfile,
              !input.permissions.includeUserDocuments || input.permissions.showDocuments
        else { throw PassportShareServiceError.invalidDraft }
    }

    static let demoV2 = PassportShareCapabilities(
        policyVersion: 2, defaultMode: "verified_only",
        modes: ["verified_only", "verified_and_candidate_provided"],
        verifiedOnlySections: ["include_employments", "include_educations"],
        mixedSections: ["include_employments", "include_educations", "include_certifications", "include_skills", "include_projects", "include_user_documents", "include_profile", "show_photo"],
        derivedTrustScore: true, narrowOnlyUpdates: true
    )
}

nonisolated enum PassportShareLifecycleState: String, Equatable, Sendable {
    case active
    case expired
    case revoked
    case unknown

    init(backendValue: String) {
        self = Self(rawValue: backendValue.lowercased()) ?? .unknown
    }

    var title: String {
        switch self {
        case .active: "Active"
        case .expired: "Expired"
        case .revoked: "Revoked"
        case .unknown: "Unavailable"
        }
    }

    var symbol: String {
        switch self {
        case .active: "link.circle.fill"
        case .expired: "clock.badge.exclamationmark.fill"
        case .revoked: "xmark.shield.fill"
        case .unknown: "questionmark.circle.fill"
        }
    }
}

nonisolated struct PassportShare: Identifiable, Equatable, Sendable {
    let id: String
    let label: String?
    let permissions: PassportSharePermissions
    let trackViews: Bool
    let expiresAt: Date?
    let revokedAt: Date?
    let lastViewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let state: PassportShareLifecycleState
    var policyVersion: Int = 1
    var sharingMode: PassportSharingMode = .legacyMixed

    var policyEditable: Bool {
        (policyVersion == 1 && sharingMode == .legacyMixed)
            || (policyVersion == 2 && [.verifiedOnly, .mixed].contains(sharingMode))
    }

    var displayLabel: String {
        let trimmed = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Passport share" : trimmed
    }
}

nonisolated struct PassportShareCreation: Equatable, Sendable {
    let share: PassportShare
    let publicURL: URL
}

nonisolated struct PassportShareAnalytics: Equatable, Sendable {
    let shareID: String
    let totalViews: Int
    let uniqueViews: Int
    let lastViewedAt: Date?
}

nonisolated struct PassportShareMutationInput: Equatable, Sendable {
    let label: String?
    let permissions: PassportSharePermissions
    let expiresAt: Date?
    var sharingMode: PassportSharingMode = .verifiedOnly
    var originalShare: PassportShare? = nil
}

nonisolated enum PassportShareExpiryPreset: String, CaseIterable, Identifiable, Sendable {
    case noExpiry
    case sevenDays
    case thirtyDays
    case ninetyDays
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noExpiry: "No expiry"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .ninetyDays: "90 days"
        case .custom: "Choose date"
        }
    }
}

nonisolated struct PassportShareDraft: Equatable, Sendable {
    var label = ""
    var permissions = PassportSharePermissions.privacyPreserving
    var expiryPreset = PassportShareExpiryPreset.thirtyDays
    var customExpiry: Date
    var sharingMode: PassportSharingMode = .verifiedOnly
    var originalShare: PassportShare?

    init(now: Date = Date()) {
        customExpiry = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(2_592_000)
    }

    init(share: PassportShare, now: Date = Date()) {
        label = share.label ?? ""
        permissions = share.permissions
        sharingMode = share.sharingMode
        originalShare = share
        if let expiresAt = share.expiresAt {
            expiryPreset = .custom
            customExpiry = expiresAt
        } else {
            expiryPreset = .noExpiry
            customExpiry = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(2_592_000)
        }
    }

    func mutationInput(now: Date = Date(), calendar: Calendar = .current) -> PassportShareMutationInput? {
        guard purposeValidationMessage == nil else { return nil }

        let expiry: Date?
        switch expiryPreset {
        case .noExpiry:
            expiry = nil
        case .sevenDays:
            expiry = calendar.date(byAdding: .day, value: 7, to: now)
        case .thirtyDays:
            expiry = calendar.date(byAdding: .day, value: 30, to: now)
        case .ninetyDays:
            expiry = calendar.date(byAdding: .day, value: 90, to: now)
        case .custom:
            guard customExpiry > now else { return nil }
            expiry = customExpiry
        }

        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return PassportShareMutationInput(
            label: trimmed.isEmpty ? nil : trimmed,
            permissions: permissions,
            expiresAt: expiry,
            sharingMode: sharingMode,
            originalShare: originalShare
        )
    }

    var validationMessage: String? {
        if let purposeValidationMessage { return purposeValidationMessage }
        if expiryPreset == .custom, customExpiry <= Date() { return "Choose a future expiry date and time." }
        if permissions.showPhoto && !permissions.includeProfile { return "Profile photo requires profile details." }
        if permissions.includeUserDocuments && !permissions.showDocuments { return "User documents require supporting documents permission." }
        return nil
    }

    var purposeValidationMessage: String? {
        let count = label.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count
        if count == 0, originalShare?.policyVersion == 1, originalShare?.label == nil { return nil }
        return (1...120).contains(count) ? nil : "Purpose is required. Use 1–120 characters, excluding surrounding whitespace."
    }

    mutating func selectMode(_ mode: PassportSharingMode, capabilities: PassportShareCapabilities) {
        guard originalShare == nil, capabilities.supportsV2, capabilities.modes.contains(mode.rawValue) else { return }
        sharingMode = mode
        permissions = .privacyPreserving
        if mode == .verifiedOnly {
            let supported = capabilities.options(for: mode)
            for option in [PassportSharePermissionOption.employments, .educations, .employerNames] where supported.contains(option) {
                permissions.set(true, for: option)
            }
        }
    }
}

nonisolated enum PassportShareServiceError: Error, Equatable, LocalizedError, Sendable {
    case invalidDraft
    case invalidPublicURL
    case shareNotFound
    case capabilitiesUnavailable
    case newLinkRequired

    var errorDescription: String? {
        switch self {
        case .invalidDraft: "Enter a purpose of 1–120 characters and review sharing permissions and expiry."
        case .invalidPublicURL: "The server created the share but did not return a safe public Passport URL."
        case .shareNotFound: "The Passport share could not be found in the authoritative share list."
        case .capabilitiesUnavailable: "Sharing capabilities could not be confirmed. Creating a link is disabled until the server policy is available."
        case .newLinkRequired: "Existing links can only be narrowed. Create a new link to share additional information."
        }
    }
}

nonisolated enum PassportShareQRPayload {
    static func publicURLString(from url: URL) -> String {
        url.absoluteString
    }
}
