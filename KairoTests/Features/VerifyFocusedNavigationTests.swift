import XCTest
@testable import Kairo

@MainActor
final class VerifyFocusedNavigationTests: XCTestCase {
    private let oldID = "withdrawn-public-id"
    private let newID = "new-public-id"

    func testNewDistinctRequestWaitsForAuthoritativeRefreshWithWithdrawnHistory() async {
        let service = ControlledVerifyNavigationService()
        let model = VerifyOverviewLoadState()
        let store = CandidateDataRefreshStore()
        model.state = mapped([record(oldID, .withdrawnByCandidate)])
        store.verificationRequested(requestID: newID)
        XCTAssertEqual(resolve(model, store), .pending)
        let load = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: false) }
        await service.waitForCalls(1)
        XCTAssertEqual(resolve(model, store), .pending)
        XCTAssertEqual(store.focusedVerificationRequestID, newID)
        service.finish(0, with: .success(VerifyOverview(requests: [record(oldID, .withdrawnByCandidate), record(newID, .pendingAdminReview)])))
        _ = await load.value
        XCTAssertEqual(resolve(model, store), .request(newID))
        // Data resolution alone does not consume the destination; sheet appearance does.
        XCTAssertEqual(store.focusedVerificationRequestID, newID)
        store.clearVerificationFocus(requestID: newID)
        XCTAssertNil(store.focusedVerificationRequestID)
        guard case .populated(let content) = model.state.phase else { return XCTFail("Expected live history") }
        XCTAssertEqual(content.completedRequests.map(\.id), [oldID])
        XCTAssertEqual(content.completedRequests.first?.status, .withdrawnByCandidate)
    }

    func testMissingFromStaleCacheNeverResolvesUnavailable() {
        let cached = mapped([record(oldID, .withdrawnByCandidate)])
        XCTAssertEqual(VerifyFocusedDestination.resolve(target: newID, authoritativeFocusID: nil, state: cached), .pending)
        XCTAssertEqual(VerifyFocusedDestination.resolve(target: newID, authoritativeFocusID: oldID, state: cached), .pending)
    }

    func testMatchingCachedItemStillRequiresFreshAuthority() {
        XCTAssertEqual(VerifyFocusedDestination.resolve(target: newID, authoritativeFocusID: nil,
            state: mapped([record(newID, .pendingAdminReview)])), .pending)
    }

    func testAuthoritativeAbsenceDoesNotSubstituteOldHistory() async {
        let model = VerifyOverviewLoadState(), service = ControlledVerifyNavigationService()
        let load = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: false) }
        await service.waitForCalls(1)
        service.finish(0, with: .success(VerifyOverview(requests: [record(oldID, .withdrawnByCandidate)])))
        _ = await load.value
        XCTAssertEqual(VerifyFocusedDestination.resolve(target: newID, authoritativeFocusID: model.authoritativeFocusID, state: model.state), .unavailable)
    }

    func testAuthoritativeEmptyListResolvesUnavailable() async {
        let model = VerifyOverviewLoadState(), service = ControlledVerifyNavigationService()
        let load = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: true) }
        await service.waitForCalls(1)
        service.finish(0, with: .success(VerifyOverview(requests: [])))
        _ = await load.value
        XCTAssertEqual(VerifyFocusedDestination.resolve(target: newID, authoritativeFocusID: model.authoritativeFocusID, state: model.state), .unavailable)
    }

    func testFailedRefreshKeepsDestinationPendingAndCanRetry() async {
        let model = VerifyOverviewLoadState(), service = ControlledVerifyNavigationService(), store = CandidateDataRefreshStore()
        model.state = mapped([record(oldID, .withdrawnByCandidate)])
        store.verificationRequested(requestID: newID)
        let failed = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: false) }
        await service.waitForCalls(1)
        service.finish(0, with: .failure(URLError(.notConnectedToInternet)))
        _ = await failed.value
        XCTAssertEqual(resolve(model, store), .pending)
        XCTAssertEqual(store.focusedVerificationRequestID, newID)
        guard case .error = model.state.phase else { return XCTFail("Retry must be available") }
        let retry = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: true) }
        await service.waitForCalls(2)
        service.finish(1, with: .success(VerifyOverview(requests: [record(newID, .pendingAdminReview)])))
        _ = await retry.value
        XCTAssertEqual(resolve(model, store), .request(newID))
    }

    func testLateOldRefreshCannotOverwriteNewRequestResolution() async {
        let model = VerifyOverviewLoadState(), service = ControlledVerifyNavigationService()
        let old = Task { await model.load(service: service, focusedRequestID: nil, showLoading: false) }
        await service.waitForCalls(1)
        let new = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: false) }
        await service.waitForCalls(2)
        service.finish(1, with: .success(VerifyOverview(requests: [record(newID, .pendingAdminReview)])))
        _ = await new.value
        service.finish(0, with: .success(VerifyOverview(requests: [record(oldID, .withdrawnByCandidate)])))
        _ = await old.value
        XCTAssertEqual(VerifyFocusedDestination.resolve(target: newID, authoritativeFocusID: model.authoritativeFocusID, state: model.state), .request(newID))
    }

    func testRepeatedDistinctDestinationsNeverResolveToPriorPublicID() async {
        let model = VerifyOverviewLoadState(), service = ControlledVerifyNavigationService(), store = CandidateDataRefreshStore()
        for (index, id) in [newID, "third-public-id", "fourth-public-id"].enumerated() {
            store.verificationRequested(requestID: id)
            XCTAssertEqual(resolve(model, store), .pending)
            let load = Task { await model.load(service: service, focusedRequestID: id, showLoading: false) }
            await service.waitForCalls(index + 1)
            service.finish(index, with: .success(VerifyOverview(requests: [record(oldID, .withdrawnByCandidate), record(id, .pendingAdminReview)])))
            _ = await load.value
            XCTAssertEqual(resolve(model, store), .request(id))
            store.clearVerificationFocus(requestID: oldID)
            XCTAssertEqual(store.focusedVerificationRequestID, id)
            store.clearVerificationFocus(requestID: id)
        }
    }

    func testCancelledLoadCannotAuthorizeNavigation() async {
        let model = VerifyOverviewLoadState(), service = ControlledVerifyNavigationService()
        let load = Task { await model.load(service: service, focusedRequestID: self.newID, showLoading: false) }
        await service.waitForCalls(1)
        load.cancel()
        service.finish(0, with: .success(VerifyOverview(requests: [record(newID, .pendingAdminReview)])))
        _ = await load.value
        XCTAssertNil(model.authoritativeFocusID)
    }

    func testNavigationFixtureRequiresExplicitUITestLaunchGuard() {
        let env = ["KAIRO_UI_TEST_VERIFY_NAVIGATION": "1", "KAIRO_UI_TEST_VERIFY_STATE": "populated", "KAIRO_UI_TEST_ROUTE": "demoHome"]
        XCTAssertFalse(UITestVerifyConfiguration.current(arguments: [], environment: env).showsNavigationRecovery)
        XCTAssertTrue(UITestVerifyConfiguration.current(arguments: ["-KAIRO_UI_TESTING"], environment: env).showsNavigationRecovery)
    }

    private func resolve(_ model: VerifyOverviewLoadState, _ store: CandidateDataRefreshStore) -> VerifyFocusedDestination {
        VerifyFocusedDestination.resolve(target: store.focusedVerificationRequestID ?? "", authoritativeFocusID: model.authoritativeFocusID, state: model.state)
    }
    private func mapped(_ records: [VerifyRequestRecord]) -> VerifyOverviewState { VerifyOverviewMapper.map(.init(requests: records)) }
    private func record(_ id: String, _ status: VerifyVerificationStatus) -> VerifyRequestRecord {
        VerifyRequestRecord(id: id, routeID: id, subjectIDs: ["same-employment"], kind: .employment,
            typeTitle: "Employment verification", organizationName: "Synthetic employer", requesterName: "QA", requestedItem: "Synthetic role",
            status: status, priority: "normal", dueDate: nil, createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2),
            candidateResponse: nil, candidateResponseSubmittedAt: nil, acceptedAt: nil, consentedFields: [], consentedEvidenceScope: [],
            evidenceSummary: .init(totalItems: 0, documentItems: 0, fieldKeys: []), timeline: [])
    }
}

@MainActor
private final class ControlledVerifyNavigationService: VerifyOverviewServiceProtocol {
    private var calls: [CheckedContinuation<VerifyOverview, Error>?] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []
    func loadOverview() async throws -> VerifyOverview {
        try await withCheckedThrowingContinuation { continuation in
            calls.append(continuation)
            let ready = waiters.filter { $0.0 <= calls.count }
            waiters.removeAll { $0.0 <= calls.count }
            ready.forEach { $0.1.resume() }
        }
    }
    func waitForCalls(_ count: Int) async {
        if calls.count >= count { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }
    func finish(_ index: Int, with result: Result<VerifyOverview, Error>) {
        calls[index]?.resume(with: result)
        calls[index] = nil
    }
    func performAction(requestID: String, action: VerifyRequestAction, response: String?, consent: VerificationSubmissionConsent?) async throws {
        throw URLError(.unsupportedURL)
    }
}
