import Foundation
import XCTest
@testable import Kairo

@MainActor
final class PassportShareActivityTests: XCTestCase {
    func test_activityMapsZeroAndMultipleViewsFromBackendAnalytics() async {
        let viewed = Self.share(id: "viewed", state: .active, lastViewedAt: Self.date(300))
        let zero = Self.share(id: "zero", state: .active, lastViewedAt: nil)
        let service = PassportShareActivityServiceSpy(
            shares: [zero, viewed],
            analytics: [
                "viewed": PassportShareAnalytics(
                    shareID: "viewed",
                    totalViews: 7,
                    uniqueViews: 5,
                    lastViewedAt: Self.date(300)
                ),
                "zero": PassportShareAnalytics(
                    shareID: "zero",
                    totalViews: 0,
                    uniqueViews: 0,
                    lastViewedAt: nil
                )
            ]
        )
        let model = PassportShareActivityViewModel(service: service)

        await model.reload()

        XCTAssertEqual(model.recentlyViewed.map(\.id), ["viewed"])
        XCTAssertEqual(model.recentlyViewed.first?.totalViews, 7)
        XCTAssertEqual(model.recentlyViewed.first?.uniqueViews, 5)
        XCTAssertEqual(model.activeUnviewed.map(\.id), ["zero"])
        XCTAssertEqual(model.activeUnviewed.first?.totalViews, 0)
    }

    func test_revokedShareRemainsHistoricalAndReadOnlyWithAuthoritativeCounts() async {
        let revoked = Self.share(id: "revoked", state: .revoked, lastViewedAt: Self.date(400))
        let service = PassportShareActivityServiceSpy(
            shares: [revoked],
            analytics: [
                "revoked": PassportShareAnalytics(
                    shareID: "revoked",
                    totalViews: 2,
                    uniqueViews: 2,
                    lastViewedAt: Self.date(400)
                )
            ]
        )
        let model = PassportShareActivityViewModel(service: service)

        await model.reload()

        XCTAssertEqual(model.recentlyViewed.first?.share.state, .revoked)
        XCTAssertEqual(model.recentlyViewed.first?.totalViews, 2)
        XCTAssertTrue(model.activeUnviewed.isEmpty)
    }

    func test_unviewedRevokedShareAppearsInExpiredRevokedHistory() async {
        let revoked = Self.share(id: "revoked-zero", state: .revoked, lastViewedAt: nil)
        let service = PassportShareActivityServiceSpy(
            shares: [revoked],
            analytics: [
                "revoked-zero": PassportShareAnalytics(
                    shareID: "revoked-zero",
                    totalViews: 0,
                    uniqueViews: 0,
                    lastViewedAt: nil
                )
            ]
        )
        let model = PassportShareActivityViewModel(service: service)

        await model.reload()

        XCTAssertEqual(model.historicalUnviewed.map(\.id), ["revoked-zero"])
    }

    func test_activityLoadNeverIncrementsOrMutatesLocalCounts() async {
        let share = Self.share(id: "stable", state: .active, lastViewedAt: Self.date(500))
        let analytics = PassportShareAnalytics(
            shareID: "stable",
            totalViews: 11,
            uniqueViews: 8,
            lastViewedAt: Self.date(500)
        )
        let service = PassportShareActivityServiceSpy(
            shares: [share],
            analytics: ["stable": analytics]
        )
        let model = PassportShareActivityViewModel(service: service)

        await model.reload()
        await model.reload()

        let mutationCalls = await service.mutationCalls()
        let analyticsCalls = await service.analyticsCalls()

        XCTAssertEqual(model.items.first?.analytics, analytics)
        XCTAssertEqual(mutationCalls, 0)
        XCTAssertEqual(analyticsCalls, ["stable", "stable"])
    }

    func test_demoActivityUsesDeterministicLocalService() async throws {
        let service = DemoPassportShareService()
        let model = PassportShareActivityViewModel(service: service)

        await model.reload()

        XCTAssertEqual(model.items.count, 1)
        XCTAssertEqual(model.items.first?.totalViews, 0)
        XCTAssertEqual(model.items.first?.uniqueViews, 0)
    }

    private nonisolated static func share(
        id: String,
        state: PassportShareLifecycleState,
        lastViewedAt: Date?
    ) -> PassportShare {
        PassportShare(
            id: id,
            label: "Share \(id)",
            permissions: .privacyPreserving,
            trackViews: true,
            expiresAt: state == .expired ? date(200) : nil,
            revokedAt: state == .revoked ? date(250) : nil,
            lastViewedAt: lastViewedAt,
            createdAt: date(100),
            updatedAt: date(250),
            state: state
        )
    }

    private nonisolated static func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}

private actor PassportShareActivityServiceSpy: PassportShareServiceProtocol {
    private let shares: [PassportShare]
    private let analytics: [String: PassportShareAnalytics]
    private var requestedAnalytics: [String] = []
    private var mutationCount = 0

    init(shares: [PassportShare], analytics: [String: PassportShareAnalytics]) {
        self.shares = shares
        self.analytics = analytics
    }

    func listShares() async throws -> [PassportShare] {
        shares
    }

    func getShare(id: String) async throws -> PassportShare {
        guard let share = shares.first(where: { $0.id == id }) else {
            throw PassportShareServiceError.shareNotFound
        }
        return share
    }

    func getAnalytics(shareID: String) async throws -> PassportShareAnalytics {
        requestedAnalytics.append(shareID)
        guard let value = analytics[shareID] else {
            throw PassportShareServiceError.shareNotFound
        }
        return value
    }

    func createShare(_ input: PassportShareMutationInput) async throws -> PassportShareCreation {
        mutationCount += 1
        throw PassportShareServiceError.invalidDraft
    }

    func updateShare(id: String, input: PassportShareMutationInput) async throws -> PassportShare {
        mutationCount += 1
        throw PassportShareServiceError.invalidDraft
    }

    func revokeShare(id: String) async throws -> PassportShare {
        mutationCount += 1
        throw PassportShareServiceError.shareNotFound
    }

    func analyticsCalls() -> [String] {
        requestedAnalytics
    }

    func mutationCalls() -> Int {
        mutationCount
    }
}
