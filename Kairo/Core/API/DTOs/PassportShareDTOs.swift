import Foundation

nonisolated struct PassportShareResponseDTO: Decodable, Equatable, Sendable {
    let id: String
    let label: String?
    let permissions: PassportSharePermissions
    let trackViews: Bool
    let expiresAt: Date?
    let revokedAt: Date?
    let lastViewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let state: String
    let policyVersion: Int?
    let sharingMode: String?

    private enum CodingKeys: String, CodingKey {
        case id, label, permissions, trackViews, expiresAt, revokedAt, lastViewedAt, createdAt, updatedAt, state, policyVersion, sharingMode
    }

    var domain: PassportShare {
        PassportShare(
            id: id,
            label: label,
            permissions: permissions,
            trackViews: trackViews,
            expiresAt: expiresAt,
            revokedAt: revokedAt,
            lastViewedAt: lastViewedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            state: PassportShareLifecycleState(backendValue: state),
            policyVersion: policyVersion ?? 1,
            sharingMode: sharingMode.map { PassportSharingMode(rawValue: $0) ?? .unknown }
                ?? (policyVersion == nil || policyVersion == 1 ? .legacyMixed : .unknown)
        )
    }
}

nonisolated struct PassportShareCreateResponseDTO: Decodable, Equatable, Sendable {
    let id: String
    let label: String?
    let permissions: PassportSharePermissions
    let trackViews: Bool
    let expiresAt: Date?
    let revokedAt: Date?
    let lastViewedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let state: String
    let shareURL: String
    let policyVersion: Int?
    let sharingMode: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case permissions
        case trackViews
        case expiresAt
        case revokedAt
        case lastViewedAt
        case createdAt
        case updatedAt
        case state
        case shareURL = "shareUrl"
        case policyVersion
        case sharingMode
    }

    var share: PassportShare {
        PassportShare(
            id: id,
            label: label,
            permissions: permissions,
            trackViews: trackViews,
            expiresAt: expiresAt,
            revokedAt: revokedAt,
            lastViewedAt: lastViewedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            state: PassportShareLifecycleState(backendValue: state),
            policyVersion: policyVersion ?? 1,
            sharingMode: sharingMode.map { PassportSharingMode(rawValue: $0) ?? .unknown }
                ?? (policyVersion == nil || policyVersion == 1 ? .legacyMixed : .unknown)
        )
    }
}

extension PassportShareResponseDTO {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        permissions = try c.decode(PassportSharePermissions.self, forKey: .permissions)
        trackViews = try c.decode(Bool.self, forKey: .trackViews)
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        revokedAt = try c.decodeIfPresent(Date.self, forKey: .revokedAt)
        lastViewedAt = try c.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        state = try c.decode(String.self, forKey: .state)
        policyVersion = try c.decodeIfPresent(Int.self, forKey: .policyVersion)
        sharingMode = try c.decodeIfPresent(String.self, forKey: .sharingMode)
        if policyVersion == 2 {
            // Legacy defaults cannot fill missing privacy fields in a V2 response.
            nonisolated struct ProfileScope: Decodable { let includeProfile: Bool; let showPhoto: Bool }
            _ = try c.decode(ProfileScope.self, forKey: .permissions)
        }
    }
}

extension PassportShareCreateResponseDTO {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        permissions = try c.decode(PassportSharePermissions.self, forKey: .permissions)
        trackViews = try c.decode(Bool.self, forKey: .trackViews)
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        revokedAt = try c.decodeIfPresent(Date.self, forKey: .revokedAt)
        lastViewedAt = try c.decodeIfPresent(Date.self, forKey: .lastViewedAt)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        state = try c.decode(String.self, forKey: .state)
        policyVersion = try c.decodeIfPresent(Int.self, forKey: .policyVersion)
        sharingMode = try c.decodeIfPresent(String.self, forKey: .sharingMode)
        shareURL = try c.decode(String.self, forKey: .shareURL)
        if policyVersion == 2 {
            // Legacy defaults cannot fill missing privacy fields in a V2 response.
            nonisolated struct ProfileScope: Decodable { let includeProfile: Bool; let showPhoto: Bool }
            _ = try c.decode(ProfileScope.self, forKey: .permissions)
        }
    }
}

nonisolated struct PassportSharePageDTO: Decodable, Equatable, Sendable {
    let items: [PassportShareResponseDTO]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let offset: Int
    let limit: Int

}

nonisolated struct PassportShareAnalyticsResponseDTO: Decodable, Equatable, Sendable {
    let shareID: String
    let totalViews: Int
    let uniqueViews: Int
    let lastViewedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case shareID = "shareId"
        case totalViews
        case uniqueViews
        case lastViewedAt
    }

    var domain: PassportShareAnalytics {
        PassportShareAnalytics(
            shareID: shareID,
            totalViews: totalViews,
            uniqueViews: uniqueViews,
            lastViewedAt: lastViewedAt
        )
    }
}

nonisolated struct PassportShareCreateRequestDTO: Encodable, Equatable, Sendable {
    let label: String?
    let expiresAt: String?
    let trackViews: Bool
    let permissions: PassportSharePermissions
    let sharingMode: PassportSharingMode

    init(input: PassportShareMutationInput) {
        label = input.label?.trimmingCharacters(in: .whitespacesAndNewlines)
        expiresAt = input.expiresAt.map(PassportShareTimestamp.encode)
        trackViews = true
        permissions = input.permissions
        sharingMode = input.sharingMode
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let label {
            try container.encode(label, forKey: .label)
        } else {
            try container.encodeNil(forKey: .label)
        }
        if let expiresAt {
            try container.encode(expiresAt, forKey: .expiresAt)
        } else {
            try container.encodeNil(forKey: .expiresAt)
        }
        try container.encode(trackViews, forKey: .trackViews)
        try container.encode(permissions, forKey: .permissions)
        try container.encode(sharingMode, forKey: .sharingMode)
    }

    private enum CodingKeys: String, CodingKey {
        case label
        case expiresAt
        case trackViews
        case permissions
        case sharingMode
    }
}

nonisolated struct PassportShareUpdateRequestDTO: Encodable, Equatable, Sendable {
    let label: String?
    let expiresAt: String?
    let permissions: [String: Bool]
    let changesLabel: Bool
    let changesExpiry: Bool

    init(input: PassportShareMutationInput) {
        label = input.label?.trimmingCharacters(in: .whitespacesAndNewlines)
        expiresAt = input.expiresAt.map(PassportShareTimestamp.encode)
        // Send only deliberate differences. Never re-enable a field another client narrowed.
        permissions = Dictionary(uniqueKeysWithValues: PassportSharePermissionOption.allCases.compactMap { option in
            guard input.originalShare?.permissions.isEnabled(option) != input.permissions.isEnabled(option) else { return nil }
            return (option.backendKey, input.permissions.isEnabled(option))
        })
        changesLabel = input.originalShare?.label != input.label
        changesExpiry = input.originalShare?.expiresAt != input.expiresAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if changesLabel {
            if let label { try container.encode(label, forKey: .label) }
            else { try container.encodeNil(forKey: .label) }
        }
        if changesExpiry {
            if let expiresAt { try container.encode(expiresAt, forKey: .expiresAt) }
            else { try container.encodeNil(forKey: .expiresAt) }
        }
        if !permissions.isEmpty { try container.encode(permissions, forKey: .permissions) }
    }

    private enum CodingKeys: String, CodingKey {
        case label
        case expiresAt
        case permissions
    }
}

nonisolated enum PassportShareTimestamp {
    static func encode(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
