import Foundation

nonisolated enum NotificationJSONValue: Decodable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: NotificationJSONValue])
    case array([NotificationJSONValue])
    case null

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
        } else if let value = try? container.decode([String: NotificationJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([NotificationJSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported notification metadata value."
            )
        }
    }

    var stringValue: String? {
        guard case .string(let value) = self else { return nil }
        return value
    }
}

nonisolated struct CandidateNotificationDTO: Decodable, Equatable, Sendable {
    let publicID: String
    let category: String
    let eventType: String
    let title: String
    let body: String
    let metadata: [String: NotificationJSONValue]
    let readAt: Date?
    let createdAt: Date

    private enum CodingKeys: String, CodingKey {
        case publicID = "publicId"
        case category
        case eventType
        case title
        case body
        case metadata
        case readAt
        case createdAt
    }
}

nonisolated struct CandidateNotificationPageDTO: Decodable, Equatable, Sendable {
    let items: [CandidateNotificationDTO]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    let offset: Int
    let limit: Int
}

nonisolated struct NotificationUnreadCountDTO: Decodable, Equatable, Sendable {
    let unreadCount: Int
}
