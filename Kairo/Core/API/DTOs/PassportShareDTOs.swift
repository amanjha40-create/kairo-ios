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
            state: PassportShareLifecycleState(backendValue: state)
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
            state: PassportShareLifecycleState(backendValue: state)
        )
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

    init(input: PassportShareMutationInput) {
        label = input.label
        expiresAt = input.expiresAt.map(PassportShareTimestamp.encode)
        trackViews = true
        permissions = input.permissions
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
    }

    private enum CodingKeys: String, CodingKey {
        case label
        case expiresAt
        case trackViews
        case permissions
    }
}

nonisolated struct PassportShareUpdateRequestDTO: Encodable, Equatable, Sendable {
    let label: String?
    let expiresAt: String?
    let permissions: PassportSharePermissions

    init(input: PassportShareMutationInput) {
        label = input.label
        expiresAt = input.expiresAt.map(PassportShareTimestamp.encode)
        permissions = input.permissions
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
        try container.encode(permissions, forKey: .permissions)
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
