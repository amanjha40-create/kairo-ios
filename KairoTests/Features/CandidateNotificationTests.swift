import Foundation
import XCTest
@testable import Kairo

@MainActor
final class CandidateNotificationTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_listDecodesCanonicalPageAndVerificationDestination() async throws {
        let service = try await makeLiveService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/notifications")
            XCTAssertEqual(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems, [
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "page_size", value: "20")
            ])
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            return (try Self.response(for: request, statusCode: 200), Self.pagePayload)
        }

        let page = try await service.list(page: 2, pageSize: 20)

        XCTAssertEqual(page.total, 22)
        XCTAssertEqual(page.page, 2)
        XCTAssertEqual(page.totalPages, 2)
        XCTAssertFalse(page.hasNextPage)
        let notification = try XCTUnwrap(page.items.first)
        XCTAssertEqual(notification.id, "00000000-0000-0000-0000-000000000701")
        XCTAssertEqual(notification.type, .verificationCompleted)
        XCTAssertFalse(notification.isRead)
        XCTAssertEqual(notification.relatedEntityID, "00000000-0000-0000-0000-000000000801")
        XCTAssertEqual(
            notification.destination,
            .verificationRequest("00000000-0000-0000-0000-000000000801")
        )
    }

    func test_unknownEventUsesGenericDetailWithoutFabricatingDestination() throws {
        let dto = try APIJSONCoder.makeDecoder().decode(
            CandidateNotificationDTO.self,
            from: Data(
                """
                {
                  "public_id": "00000000-0000-0000-0000-000000000901",
                  "category": "system",
                  "event_type": "future_backend_event",
                  "title": "Future update",
                  "body": "Read the supplied notification body.",
                  "metadata": {"count": 3, "enabled": true, "nested": {"safe": "value"}},
                  "read_at": "2026-09-04T08:01:00Z",
                  "created_at": "2026-09-04T08:00:00Z"
                }
                """.utf8
            )
        )

        let notification = CandidateNotificationMapper.map(dto)

        XCTAssertEqual(notification.type, .unknown("future_backend_event"))
        XCTAssertEqual(notification.destination, .genericDetail)
        XCTAssertNil(notification.relatedEntityID)
        XCTAssertTrue(notification.isRead)
    }

    func test_unreadCountAndReadMutationsUseCanonicalRoutes() async throws {
        let service = try await makeLiveService()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/notifications/unread-count"):
                return (try Self.response(for: request, statusCode: 200), Data(#"{"unread_count":12}"#.utf8))
            case ("POST", "/api/v1/notifications/00000000-0000-0000-0000-000000000701/read"),
                 ("POST", "/api/v1/notifications/read-all"):
                return (try Self.response(for: request, statusCode: 204), Data())
            default:
                XCTFail("Unexpected notification request: \(request.httpMethod ?? "nil") \(request.url?.path ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let unreadCount = try await service.unreadCount()
        XCTAssertEqual(unreadCount, 12)
        try await service.markRead(id: "00000000-0000-0000-0000-000000000701")
        try await service.markAllRead()

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 3)
        XCTAssertTrue(requests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer access-123" })
    }

    func test_terminal401UsesCanonicalSessionRecoverySemantics() async throws {
        let service = try await makeLiveService()
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(for: request, statusCode: 401), Data(#"{"code":"unauthorized","message":"Expired"}"#.utf8))
        }

        do {
            _ = try await service.unreadCount()
            XCTFail("Expected a terminal session error")
        } catch let error as SessionServiceError {
            XCTAssertEqual(error, .sessionExpired)
        }
    }

    func test_HTTPFailuresRemainTypedFor403404429And5xx() async throws {
        for (status, expectedCode) in [
            (403, APIErrorCode.forbidden),
            (404, APIErrorCode.notFound),
            (429, APIErrorCode.rateLimited),
            (500, APIErrorCode.internalError)
        ] {
            await MockURLProtocolStorage.shared.reset()
            let service = try await makeLiveService()
            await MockURLProtocolStorage.shared.setHandler { request in
                (try Self.response(for: request, statusCode: status), Data())
            }

            do {
                try await service.markRead(id: "00000000-0000-0000-0000-000000000701")
                XCTFail("Expected HTTP \(status) to fail")
            } catch let NetworkError.api(error) {
                XCTAssertEqual(error.code, expectedCode)
                XCTAssertEqual(error.statusCode, status)
            } catch {
                XCTFail("Expected typed API error for HTTP \(status), got \(error)")
            }
        }
    }

    func test_timeoutRemainsTransportFailure() async throws {
        let service = try await makeLiveService()
        await MockURLProtocolStorage.shared.setHandler { _ in
            throw URLError(.timedOut)
        }

        do {
            _ = try await service.list(page: 1, pageSize: 20)
            XCTFail("Expected timeout")
        } catch let NetworkError.transport(message) {
            XCTAssertFalse(message.isEmpty)
        }
    }

    func test_storeLoadsEmptyStateAndAuthoritativeUnreadCount() async {
        let service = NotificationServiceStub(items: [], unreadCount: 0)
        let store = CandidateNotificationStore(service: service, pageSize: 2)

        await store.loadInitial()

        XCTAssertEqual(store.phase, .empty)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertNil(store.unreadBadgeText)
    }

    func test_storePaginatesWithoutDuplicateRows() async {
        let values = [
            Self.notification(id: "one", isRead: false),
            Self.notification(id: "two", isRead: true),
            Self.notification(id: "three", isRead: true)
        ]
        let service = NotificationServiceStub(items: values, unreadCount: 1)
        let store = CandidateNotificationStore(service: service, pageSize: 2)

        await store.loadInitial()
        await store.loadNextPageIfNeeded(after: try! XCTUnwrap(store.items.last))

        XCTAssertEqual(store.items.map(\.id), ["one", "two", "three"])
        XCTAssertFalse(store.canLoadNextPage)
    }

    func test_successfulMarkReadRefetchesAuthoritativeInboxAndCount() async throws {
        let item = Self.notification(id: "one", isRead: false)
        let service = NotificationServiceStub(items: [item], unreadCount: 1)
        let store = CandidateNotificationStore(service: service)
        await store.loadInitial()

        let didOpen = await store.prepareToOpen(item)
        XCTAssertTrue(didOpen)

        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(try XCTUnwrap(store.items.first).isRead)
        let markedIDs = await service.markReadIDs()
        XCTAssertEqual(markedIDs, ["one"])
    }

    func test_failedMarkReadPreservesUnreadTruth() async throws {
        let item = Self.notification(id: "one", isRead: false)
        let service = NotificationServiceStub(
            items: [item],
            unreadCount: 1,
            markReadError: NetworkError.api(APIError(
                statusCode: 429,
                code: .rateLimited,
                message: "Try later.",
                fieldErrors: [:],
                globalErrors: [],
                validationDetails: []
            ))
        )
        let store = CandidateNotificationStore(service: service)
        await store.loadInitial()

        let didOpen = await store.prepareToOpen(item)
        XCTAssertFalse(didOpen)

        XCTAssertEqual(store.unreadCount, 1)
        XCTAssertFalse(try XCTUnwrap(store.items.first).isRead)
        XCTAssertEqual(store.actionErrorMessage, "Try later.")
    }

    func test_markAllReadRefetchesBackendTruth() async {
        let service = NotificationServiceStub(
            items: [Self.notification(id: "one", isRead: false), Self.notification(id: "two", isRead: false)],
            unreadCount: 2
        )
        let store = CandidateNotificationStore(service: service)
        await store.loadInitial()

        await store.markAllRead()

        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(store.items.allSatisfy(\.isRead))
        let markAllCount = await service.markAllReadCallCount()
        XCTAssertEqual(markAllCount, 1)
    }

    func test_badgeCapsAtNinePlus() async {
        let store = CandidateNotificationStore(
            service: NotificationServiceStub(items: [Self.notification(id: "one", isRead: false)], unreadCount: 14)
        )
        await store.loadInitial()
        XCTAssertEqual(store.unreadBadgeText, "9+")
    }

    func test_storeResetRemovesPriorSessionNotificationState() async {
        let store = CandidateNotificationStore(
            service: NotificationServiceStub(items: [Self.notification(id: "one", isRead: false)], unreadCount: 1)
        )
        await store.loadInitial()

        store.reset()

        XCTAssertEqual(store.phase, .idle)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertNil(store.unreadCount)
        XCTAssertNil(store.unreadBadgeText)
    }

    func test_timestampFormattingUsesExpectedCandidateLabels() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_788_547_200) // 2026-09-04 16:00 UTC

        XCTAssertEqual(
            CandidateNotificationTimestampFormatter.string(
                for: now.addingTimeInterval(-20), relativeTo: now, calendar: calendar,
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "Just now"
        )
        XCTAssertEqual(
            CandidateNotificationTimestampFormatter.string(
                for: now.addingTimeInterval(-300), relativeTo: now, calendar: calendar,
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "5m ago"
        )
        XCTAssertEqual(
            CandidateNotificationTimestampFormatter.string(
                for: now.addingTimeInterval(-7_200), relativeTo: now, calendar: calendar,
                locale: Locale(identifier: "en_US_POSIX")
            ),
            "2h ago"
        )
    }

    func test_demoServiceMutationsNeverUseNetwork() async throws {
        let service = DemoCandidateNotificationService(fixture: .unread)
        let initial = try await service.list(page: 1, pageSize: 20)
        let unread = try XCTUnwrap(initial.items.first(where: { !$0.isRead }))

        try await service.markRead(id: unread.id)
        let afterOne = try await service.unreadCount()
        XCTAssertEqual(afterOne, 1)
        try await service.markAllRead()
        let afterAll = try await service.unreadCount()
        XCTAssertEqual(afterAll, 0)
    }

    private func makeLiveService() async throws -> CandidateNotificationService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.notifications"
        )
        let client = URLSessionNetworkClient(
            baseURL: configuration.apiBaseURL,
            session: makeMockedURLSession()
        )
        return CandidateNotificationService(
            sessionService: SessionService(
                configuration: configuration,
                networkClient: client,
                tokenStore: tokenStore
            )
        )
    }

    nonisolated private static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        ))
    }

    private static func notification(id: String, isRead: Bool) -> CandidateNotification {
        CandidateNotification(
            id: id,
            type: .unknown("fixture"),
            eventType: "fixture",
            category: "system",
            title: "Update \(id)",
            message: "Fixture body",
            createdAt: Date(timeIntervalSince1970: 1_788_547_200),
            isRead: isRead,
            destination: .genericDetail,
            relatedEntityID: nil
        )
    }

    nonisolated private static let pagePayload = Data(
        """
        {
          "items": [{
            "public_id": "00000000-0000-0000-0000-000000000701",
            "category": "verification",
            "event_type": "verification_completed",
            "title": "Verification completed",
            "body": "Your verification request has been completed.",
            "metadata": {
              "verification_request_public_id": "00000000-0000-0000-0000-000000000801",
              "nullable": null
            },
            "read_at": null,
            "created_at": "2026-09-04T08:00:00.123456Z"
          }],
          "total": 22,
          "page": 2,
          "page_size": 20,
          "total_pages": 2,
          "offset": 20,
          "limit": 20
        }
        """.utf8
    )
}

private actor NotificationServiceStub: CandidateNotificationServiceProtocol {
    private var values: [CandidateNotification]
    private var authoritativeUnreadCount: Int
    private var readIDs: [String] = []
    private var markAllCount = 0
    private let markReadError: Error?

    init(
        items: [CandidateNotification],
        unreadCount: Int,
        markReadError: Error? = nil
    ) {
        values = items
        authoritativeUnreadCount = unreadCount
        self.markReadError = markReadError
    }

    func list(page: Int, pageSize: Int) async throws -> CandidateNotificationPage {
        let start = min((page - 1) * pageSize, values.count)
        let end = min(start + pageSize, values.count)
        let pages = values.isEmpty ? 0 : Int(ceil(Double(values.count) / Double(pageSize)))
        return CandidateNotificationPage(
            items: Array(values[start ..< end]),
            total: values.count,
            page: page,
            pageSize: pageSize,
            totalPages: pages
        )
    }

    func unreadCount() async throws -> Int {
        authoritativeUnreadCount
    }

    func markRead(id: String) async throws {
        if let markReadError { throw markReadError }
        readIDs.append(id)
        values = values.map { item in
            guard item.id == id else { return item }
            return Self.copy(item, isRead: true)
        }
        authoritativeUnreadCount = values.filter { !$0.isRead }.count
    }

    func markAllRead() async throws {
        markAllCount += 1
        values = values.map { Self.copy($0, isRead: true) }
        authoritativeUnreadCount = 0
    }

    func markReadIDs() -> [String] { readIDs }
    func markAllReadCallCount() -> Int { markAllCount }

    private static func copy(_ item: CandidateNotification, isRead: Bool) -> CandidateNotification {
        CandidateNotification(
            id: item.id,
            type: item.type,
            eventType: item.eventType,
            category: item.category,
            title: item.title,
            message: item.message,
            createdAt: item.createdAt,
            isRead: isRead,
            destination: item.destination,
            relatedEntityID: item.relatedEntityID
        )
    }
}
