import Combine
import Foundation

/// A cached list is renderable, but is not evidence that a newly requested route is absent.
@MainActor
final class VerifyOverviewLoadState: ObservableObject {
    @Published var state = VerifyOverviewState.loading()
    @Published private(set) var authoritativeFocusID: String?
    private var generation = 0

    /// Returns true only when the winning load requires session recovery.
    func load(
        service: any VerifyOverviewServiceProtocol,
        focusedRequestID: String?,
        showLoading: Bool
    ) async -> Bool {
        generation += 1
        let attempt = generation
        let previous = state
        authoritativeFocusID = nil
        if showLoading || !Self.isRenderable(previous) { state = .loading() }

        do {
            let overview = try await service.loadOverview()
            guard attempt == generation, !Task.isCancelled else { return false }
            state = VerifyOverviewMapper.map(overview)
            // Publish only after the corresponding authoritative list is installed.
            authoritativeFocusID = focusedRequestID
        } catch {
            guard attempt == generation, !Task.isCancelled else { return false }
            if VerifyOverviewMapper.requiresSessionRecovery(for: error) { return true }
            // Never present cached filter counts as current after a failed refresh.
            // Keep focused navigation pending: an error is not authoritative absence.
            state = VerifyOverviewMapper.errorState(for: error)
        }
        return false
    }

    private static func isRenderable(_ state: VerifyOverviewState) -> Bool {
        switch state.phase {
        case .populated, .empty: true
        case .loading, .error: false
        }
    }
}

nonisolated enum VerifyFocusedDestination: Equatable {
    case pending
    case request(String)
    case unavailable

    static func resolve(target: String, authoritativeFocusID: String?, state: VerifyOverviewState) -> Self {
        guard authoritativeFocusID == target else { return .pending }
        switch state.phase {
        case .populated(let content):
            guard let request = content.request(matchingAuthoritativeIdentifier: target) else { return .unavailable }
            return .request(request.id)
        case .empty: return .unavailable
        case .loading, .error: return .pending
        }
    }
}
