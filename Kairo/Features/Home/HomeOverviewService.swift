import Foundation

protocol HomeOverviewServiceProtocol: Sendable {
    func loadOverview() async throws -> DashboardOverview
}

actor HomeOverviewService: HomeOverviewServiceProtocol {
    private let authService: any AuthServiceProtocol
    private let sessionService: any SessionServiceProtocol

    init(
        authService: any AuthServiceProtocol,
        sessionService: any SessionServiceProtocol
    ) {
        self.authService = authService
        self.sessionService = sessionService
    }

    func loadOverview() async throws -> DashboardOverview {
        async let currentUser = authService.currentUser()
        async let dashboardData = sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/dashboard",
                headers: ["Accept": "application/json"]
            )
        )

        let user = try await currentUser.asDomainModel()
        let dashboard = try APIJSONCoder.makeDecoder().decode(
            DashboardResponseDTO.self,
            from: try await dashboardData
        )
        return DashboardOverview(user: user, dashboard: dashboard)
    }
}
