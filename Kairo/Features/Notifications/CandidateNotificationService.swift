import Foundation

nonisolated protocol CandidateNotificationServiceProtocol: Sendable {
    func list(page: Int, pageSize: Int) async throws -> CandidateNotificationPage
    func unreadCount() async throws -> Int
    func markRead(id: String) async throws
    func markAllRead() async throws
}

nonisolated struct CandidateNotificationService: CandidateNotificationServiceProtocol {
    let sessionService: any SessionServiceProtocol

    func list(page: Int, pageSize: Int) async throws -> CandidateNotificationPage {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/notifications",
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "page_size", value: String(pageSize))
                ]
            )
        )
        return CandidateNotificationMapper.map(
            try APIJSONCoder.makeDecoder().decode(CandidateNotificationPageDTO.self, from: data)
        )
    }

    func unreadCount() async throws -> Int {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(path: "/notifications/unread-count")
        )
        return try APIJSONCoder.makeDecoder()
            .decode(NotificationUnreadCountDTO.self, from: data)
            .unreadCount
    }

    func markRead(id: String) async throws {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(path: "/notifications/\(id)/read", method: .post)
        )
    }

    func markAllRead() async throws {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(path: "/notifications/read-all", method: .post)
        )
    }
}

nonisolated enum DemoNotificationFixture: String, Sendable {
    case unread
    case read
    case empty
    case error
}

actor DemoCandidateNotificationService: CandidateNotificationServiceProtocol {
    private var notifications: [CandidateNotification]
    private let failsFirstListRequest: Bool
    private var listFailureDelivered = false

    init(fixture: DemoNotificationFixture) {
        failsFirstListRequest = fixture == .error
        switch fixture {
        case .empty:
            notifications = []
        case .read:
            notifications = Self.fixtures.map { item in
                CandidateNotification(
                    id: item.id,
                    type: item.type,
                    eventType: item.eventType,
                    category: item.category,
                    title: item.title,
                    message: item.message,
                    createdAt: item.createdAt,
                    isRead: true,
                    destination: item.destination,
                    relatedEntityID: item.relatedEntityID
                )
            }
        case .unread, .error:
            notifications = Self.fixtures
        }
    }

    func list(page: Int, pageSize: Int) async throws -> CandidateNotificationPage {
        if failsFirstListRequest, !listFailureDelivered {
            listFailureDelivered = true
            throw NetworkError.transport("The notification inbox is temporarily unavailable.")
        }

        let start = min((page - 1) * pageSize, notifications.count)
        let end = min(start + pageSize, notifications.count)
        let totalPages = notifications.isEmpty ? 0 : Int(ceil(Double(notifications.count) / Double(pageSize)))
        return CandidateNotificationPage(
            items: Array(notifications[start ..< end]),
            total: notifications.count,
            page: page,
            pageSize: pageSize,
            totalPages: totalPages
        )
    }

    func unreadCount() async throws -> Int {
        notifications.filter { !$0.isRead }.count
    }

    func markRead(id: String) async throws {
        guard let index = notifications.firstIndex(where: { $0.id == id }) else {
            throw NetworkError.api(APIError(
                statusCode: 404,
                code: .notFound,
                message: "Notification not found.",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        }
        notifications[index] = notifications[index].withReadState(true)
    }

    func markAllRead() async throws {
        notifications = notifications.map { $0.withReadState(true) }
    }

    private static let fixtures: [CandidateNotification] = [
        CandidateNotification(
            id: "demo-verification-complete",
            type: .verificationCompleted,
            eventType: "verification_completed",
            category: "verification",
            title: "Verification completed",
            message: "Your employment verification is complete.",
            createdAt: Date().addingTimeInterval(-300),
            isRead: false,
            destination: .verificationRequest("employment-brightpath"),
            relatedEntityID: "employment-brightpath"
        ),
        CandidateNotification(
            id: "demo-generic-update",
            type: .unknown("candidate_update"),
            eventType: "candidate_update",
            category: "system",
            title: "A Kairo update",
            message: "This deterministic message verifies the generic notification detail fallback.",
            createdAt: Date().addingTimeInterval(-7_200),
            isRead: false,
            destination: .genericDetail,
            relatedEntityID: nil
        ),
        CandidateNotification(
            id: "demo-earlier-update",
            type: .unknown("earlier_update"),
            eventType: "earlier_update",
            category: "system",
            title: "Earlier update",
            message: "A previously read notification remains available in your history.",
            createdAt: Date().addingTimeInterval(-172_800),
            isRead: true,
            destination: .genericDetail,
            relatedEntityID: nil
        )
    ]
}

private extension CandidateNotification {
    nonisolated func withReadState(_ value: Bool) -> CandidateNotification {
        CandidateNotification(
            id: id,
            type: type,
            eventType: eventType,
            category: category,
            title: title,
            message: message,
            createdAt: createdAt,
            isRead: value,
            destination: destination,
            relatedEntityID: relatedEntityID
        )
    }
}
