import Combine
import Foundation

@MainActor
final class CandidateNotificationStore: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var items: [CandidateNotification] = []
    @Published private(set) var unreadCount: Int?
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var isMarkingAllRead = false
    @Published private(set) var markingNotificationIDs: Set<String> = []
    @Published var actionErrorMessage: String?
    @Published private(set) var requiresSessionRecovery = false

    private let service: any CandidateNotificationServiceProtocol
    private let pageSize: Int
    private var currentPage = 0
    private var totalPages = 0

    init(
        service: any CandidateNotificationServiceProtocol,
        pageSize: Int = 20
    ) {
        self.service = service
        self.pageSize = pageSize
    }

    var hasUnreadNotifications: Bool {
        (unreadCount ?? 0) > 0
    }

    var unreadBadgeText: String? {
        guard let unreadCount, unreadCount > 0 else { return nil }
        return unreadCount >= 10 ? "9+" : String(unreadCount)
    }

    var canLoadNextPage: Bool {
        currentPage > 0 && currentPage < totalPages
    }

    func reset() {
        phase = .idle
        items = []
        unreadCount = nil
        isLoadingNextPage = false
        isMarkingAllRead = false
        markingNotificationIDs = []
        actionErrorMessage = nil
        requiresSessionRecovery = false
        currentPage = 0
        totalPages = 0
    }

    func refreshUnreadCount() async {
        do {
            unreadCount = try await service.unreadCount()
        } catch {
            unreadCount = nil
            requiresSessionRecovery = Self.isTerminalSessionError(error)
        }
    }

    func loadInitial() async {
        phase = .loading
        items = []
        currentPage = 0
        totalPages = 0
        unreadCount = nil
        requiresSessionRecovery = false
        actionErrorMessage = nil

        do {
            async let page = service.list(page: 1, pageSize: pageSize)
            async let count = service.unreadCount()
            let (loadedPage, loadedCount) = try await (page, count)
            applyInitialPage(loadedPage, unreadCount: loadedCount)
        } catch {
            phase = .error(Self.message(for: error))
            unreadCount = nil
            requiresSessionRecovery = Self.isTerminalSessionError(error)
        }
    }

    func refresh() async {
        await loadInitial()
    }

    func loadNextPageIfNeeded(after item: CandidateNotification) async {
        guard item.id == items.last?.id, canLoadNextPage, !isLoadingNextPage else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }

        do {
            let page = try await service.list(page: currentPage + 1, pageSize: pageSize)
            let existingIDs = Set(items.map(\.id))
            items.append(contentsOf: page.items.filter { !existingIDs.contains($0.id) })
            currentPage = page.page
            totalPages = page.totalPages
        } catch {
            actionErrorMessage = Self.message(for: error)
            requiresSessionRecovery = Self.isTerminalSessionError(error)
        }
    }

    @discardableResult
    func prepareToOpen(_ item: CandidateNotification) async -> Bool {
        guard !markingNotificationIDs.contains(item.id) else { return false }
        guard !item.isRead else { return true }

        markingNotificationIDs.insert(item.id)
        defer { markingNotificationIDs.remove(item.id) }

        do {
            try await service.markRead(id: item.id)
            try await reloadAuthoritativeFirstPage()
            return true
        } catch {
            actionErrorMessage = Self.message(for: error)
            requiresSessionRecovery = Self.isTerminalSessionError(error)
            return false
        }
    }

    func markAllRead() async {
        guard hasUnreadNotifications, !isMarkingAllRead else { return }
        isMarkingAllRead = true
        defer { isMarkingAllRead = false }

        do {
            try await service.markAllRead()
            try await reloadAuthoritativeFirstPage()
        } catch {
            actionErrorMessage = Self.message(for: error)
            requiresSessionRecovery = Self.isTerminalSessionError(error)
        }
    }

    private func reloadAuthoritativeFirstPage() async throws {
        async let page = service.list(page: 1, pageSize: pageSize)
        async let count = service.unreadCount()
        let (loadedPage, loadedCount) = try await (page, count)
        applyInitialPage(loadedPage, unreadCount: loadedCount)
    }

    private func applyInitialPage(_ page: CandidateNotificationPage, unreadCount: Int) {
        items = page.items
        currentPage = page.page
        totalPages = page.totalPages
        self.unreadCount = unreadCount
        phase = page.items.isEmpty ? .empty : .loaded
        requiresSessionRecovery = false
    }

    private static func isTerminalSessionError(_ error: Error) -> Bool {
        if let sessionError = error as? SessionServiceError {
            return sessionError == .missingAccessToken || sessionError == .sessionExpired
        }
        return false
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return "Notifications are unavailable right now. Please try again."
    }
}
