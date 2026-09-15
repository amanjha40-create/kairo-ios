import Foundation

enum HomeOverviewLoader {
    static func load(
        dashboardService: any HomeOverviewServiceProtocol,
        verificationService: any VerifyOverviewServiceProtocol
    ) async throws -> HomeOverviewState {
        async let dashboard = dashboardService.loadOverview()
        let verification: VerifyOverview?
        do {
            verification = try await verificationService.loadOverview()
        } catch {
            if HomeOverviewMapper.requiresSessionRecovery(for: error) { throw error }
            // Unknown is not zero and must never reuse an old active-request card.
            verification = nil
        }
        return HomeOverviewMapper.map(try await dashboard, verificationOverview: verification)
    }
}
