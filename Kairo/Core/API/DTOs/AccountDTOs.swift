import Foundation

nonisolated struct AccountSettingsResponseDTO: Decodable, Equatable, Sendable {
    let profile: UserPublicDTO
    let trustScoreConsent: TrustScoreConsentSummaryDTO
    let notificationPreferences: [NotificationPreferenceResponseDTO]
    let appVersion: String
    let apiVersion: String
    let trustScoreVersion: String
}

nonisolated struct AccountSettingsUpdateRequestDTO: Encodable, Equatable, Sendable {
    let notificationPreferences: [NotificationPreferenceUpsertRequestDTO]?
    let withdrawTrustScoreConsent: Bool

    nonisolated init(
        notificationPreferences: [NotificationPreferenceUpsertRequestDTO]? = nil,
        withdrawTrustScoreConsent: Bool = false
    ) {
        self.notificationPreferences = notificationPreferences
        self.withdrawTrustScoreConsent = withdrawTrustScoreConsent
    }
}

nonisolated struct NotificationPreferenceResponseDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let userID: String
    let eventType: String
    let enabled: Bool
    let preferredChannels: [String]
    let quietHours: [String: String]
    let metadata: [String: String]
    let createdAt: Date
    let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case publicID = "publicId"
        case userID = "userId"
        case eventType
        case enabled
        case preferredChannels
        case quietHours
        case metadata
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        publicID = try container.decode(String.self, forKey: .publicID)
        userID = try container.decode(String.self, forKey: .userID)
        eventType = try container.decode(String.self, forKey: .eventType)
        enabled = try container.decode(Bool.self, forKey: .enabled)
        preferredChannels = try container.decodeIfPresent([String].self, forKey: .preferredChannels) ?? []
        quietHours = try container.decodeDictionaryStrings(forKey: .quietHours)
        metadata = try container.decodeDictionaryStrings(forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

nonisolated struct NotificationPreferenceUpsertRequestDTO: Encodable, Equatable, Sendable {
    let eventType: String
    let enabled: Bool
    let preferredChannels: [String]?
    let quietHours: [String: String]?
    let metadata: [String: String]?

    nonisolated init(
        eventType: String,
        enabled: Bool,
        preferredChannels: [String]? = nil,
        quietHours: [String: String]? = nil,
        metadata: [String: String]? = nil
    ) {
        self.eventType = eventType
        self.enabled = enabled
        self.preferredChannels = preferredChannels
        self.quietHours = quietHours
        self.metadata = metadata
    }
}

nonisolated struct TrustScoreConsentSummaryDTO: Decodable, Equatable, Sendable {
    let status: String
    let version: String?
    let consentedAt: Date?
}

nonisolated struct AccountSessionResponseDTO: Decodable, Equatable, Sendable {
    let id: String
    let createdAt: Date
    let expiresAt: Date
    let lastActiveAt: Date
    let current: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case expiresAt
        case lastActiveAt
        case current
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        expiresAt = try container.decode(Date.self, forKey: .expiresAt)
        lastActiveAt = try container.decode(Date.self, forKey: .lastActiveAt)
        current = try container.decodeIfPresent(Bool.self, forKey: .current) ?? false
    }
}

nonisolated struct ChangePasswordRequestDTO: Encodable, Equatable, Sendable {
    let currentPassword: String
    let newPassword: String
    let confirmPassword: String
}

nonisolated struct ChangePasswordResponseDTO: Decodable, Equatable, Sendable {
    let message: String
}

nonisolated struct UserUpdateRequestDTO: Encodable, Equatable, Sendable {
    let fullName: String?
    let currentRole: String?
    let industry: String?
    let yearsOfExperience: Int?
    let locationCity: String?
    let locationCountry: String?
    let headline: String?
}

private extension KeyedDecodingContainer {
    nonisolated func decodeDictionaryStrings(forKey key: Key) throws -> [String: String] {
        guard contains(key) else {
            return [:]
        }

        guard let object = try decodeIfPresent([String: AnyJSONValue].self, forKey: key) else {
            return [:]
        }

        return object.reduce(into: [:]) { result, pair in
            result[pair.key] = pair.value.displayValue
        }
    }
}

private nonisolated enum AnyJSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([AnyJSONValue])
    case object([String: AnyJSONValue])
    case null

    var displayValue: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .array(let values):
            return values.map(\.displayValue).joined(separator: ", ")
        case .object(let value):
            return value.keys.sorted().joined(separator: ", ")
        case .null:
            return ""
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: AnyJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([AnyJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value."
            )
        }
    }
}
