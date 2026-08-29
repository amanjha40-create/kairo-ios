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
        showTrustScore: false
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
        }
    }

    var enabledOptions: [PassportSharePermissionOption] {
        PassportSharePermissionOption.allCases.filter(isEnabled)
    }

    var conciseSummary: String {
        let labels = enabledOptions.map(\.shortTitle)
        guard !labels.isEmpty else { return "Basic public profile only" }
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
        case .trustScore: "Show your current backend-calculated Trust Score."
        }
    }
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

    init(now: Date = Date()) {
        customExpiry = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(2_592_000)
    }

    init(share: PassportShare, now: Date = Date()) {
        label = share.label ?? ""
        permissions = share.permissions
        if let expiresAt = share.expiresAt {
            expiryPreset = .custom
            customExpiry = expiresAt
        } else {
            expiryPreset = .noExpiry
            customExpiry = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now.addingTimeInterval(2_592_000)
        }
    }

    func mutationInput(now: Date = Date(), calendar: Calendar = .current) -> PassportShareMutationInput? {
        guard label.count <= 120 else { return nil }

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
            expiresAt: expiry
        )
    }

    var validationMessage: String? {
        if label.count > 120 { return "Label must be 120 characters or fewer." }
        if expiryPreset == .custom, customExpiry <= Date() { return "Choose a future expiry date and time." }
        return nil
    }
}

nonisolated enum PassportShareServiceError: Error, Equatable, LocalizedError, Sendable {
    case invalidDraft
    case invalidPublicURL
    case shareNotFound

    var errorDescription: String? {
        switch self {
        case .invalidDraft: "Review the label and choose a future expiry before continuing."
        case .invalidPublicURL: "The server created the share but did not return a safe public Passport URL."
        case .shareNotFound: "The Passport share could not be found in the authoritative share list."
        }
    }
}

nonisolated enum PassportShareQRPayload {
    static func publicURLString(from url: URL) -> String {
        url.absoluteString
    }
}
