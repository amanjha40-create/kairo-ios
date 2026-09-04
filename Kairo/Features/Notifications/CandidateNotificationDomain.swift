import Foundation

nonisolated enum CandidateNotificationType: Equatable, Sendable {
    case verificationCompleted
    case unknown(String)

    init(eventType: String) {
        switch eventType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "verification_completed":
            self = .verificationCompleted
        default:
            self = .unknown(eventType)
        }
    }
}

nonisolated enum CandidateNotificationDestination: Equatable, Sendable {
    case verificationRequest(String)
    case verify
    case genericDetail
}

nonisolated struct CandidateNotification: Equatable, Identifiable, Sendable {
    let id: String
    let type: CandidateNotificationType
    let eventType: String
    let category: String
    let title: String
    let message: String
    let createdAt: Date
    let isRead: Bool
    let destination: CandidateNotificationDestination
    let relatedEntityID: String?

    var categorySystemImage: String {
        switch type {
        case .verificationCompleted:
            "checkmark.shield.fill"
        case .unknown:
            switch category.lowercased() {
            case "security": "lock.shield.fill"
            case "verification": "checkmark.shield"
            default: "bell.fill"
            }
        }
    }
}

nonisolated struct CandidateNotificationPage: Equatable, Sendable {
    let items: [CandidateNotification]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int

    var hasNextPage: Bool {
        page < totalPages
    }
}

nonisolated enum CandidateNotificationMapper {
    static func map(_ dto: CandidateNotificationDTO) -> CandidateNotification {
        let type = CandidateNotificationType(eventType: dto.eventType)
        let destination: CandidateNotificationDestination
        let relatedEntityID: String?

        switch type {
        case .verificationCompleted:
            relatedEntityID = dto.metadata["verification_request_public_id"]?.stringValue
            if let relatedEntityID {
                destination = .verificationRequest(relatedEntityID)
            } else {
                destination = .verify
            }
        case .unknown:
            relatedEntityID = nil
            destination = .genericDetail
        }

        return CandidateNotification(
            id: dto.publicID,
            type: type,
            eventType: dto.eventType,
            category: dto.category,
            title: dto.title,
            message: dto.body,
            createdAt: dto.createdAt,
            isRead: dto.readAt != nil,
            destination: destination,
            relatedEntityID: relatedEntityID
        )
    }

    static func map(_ dto: CandidateNotificationPageDTO) -> CandidateNotificationPage {
        CandidateNotificationPage(
            items: dto.items.map(map),
            total: dto.total,
            page: dto.page,
            pageSize: dto.pageSize,
            totalPages: dto.totalPages
        )
    }
}

nonisolated enum CandidateNotificationTimestampFormatter {
    static func string(
        for date: Date,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))

        if elapsed < 60 {
            return "Just now"
        }

        if elapsed < 3_600 {
            return "\(max(1, Int(elapsed / 60)))m ago"
        }

        if elapsed < 86_400, calendar.isDate(date, inSameDayAs: now) {
            return "\(max(1, Int(elapsed / 3_600)))h ago"
        }

        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.component(.year, from: date) == calendar.component(.year, from: now)
            ? "MMM d"
            : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
