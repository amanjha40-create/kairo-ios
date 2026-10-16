import XCTest
@testable import Kairo

@MainActor final class PermanentAddressProductionTests: XCTestCase {
    func testProductionWiringUsesCanonicalHostAndRejectsFixtureOverrides() {
        let configuration = AppConfiguration.resolve(bundleValues: [
            "KAIROBuildConfiguration": "Production", "KAIROAppEnvironment": "production", "KAIRODemoMode": "NO"
        ], environmentVariables: ["KAIRO_APP_ENVIRONMENT": "staging", "KAIRO_DEMO_MODE": "true"])
        let dependencies = AppDependencies.make(configuration: configuration,
            uiTestConfiguration: .init(isEnabled: true, route: .demoHome, onboardingStep: nil, disablesAnimations: true))
        XCTAssertEqual(configuration.apiBaseURL.absoluteString, "https://api.kairoid.com/api/v1")
        XCTAssertTrue(dependencies.permanentAddressService is PermanentAddressService)
        XCTAssertTrue(dependencies.networkClient is URLSessionNetworkClient)
        XCTAssertTrue(dependencies.tokenStore is KeychainTokenStore)
        XCTAssertFalse(dependencies.employmentReferencesService.enabled)
        XCTAssertFalse(CurrentParityQA.isEnabled(configuration: configuration,
            arguments: [UITestLaunchConfiguration.enabledArgument], environment: ["KAIRO_UI_TEST_CURRENT_PARITY": "1"]))
        // Construction only. Never resolve credentials or make a live request.
    }
    func testStagingDemoAndUITestDependencyMatrix() {
        for demo in [false, true] {
            for testing in [false, true] {
                let configuration = AppConfiguration(buildConfiguration: .staging, environment: .staging,
                    isDemoModeEnabled: demo, apiBaseURL: APIConfiguration.baseURL(for: .staging), keychainService: "synthetic")
                let dependencies = AppDependencies.make(configuration: configuration,
                    uiTestConfiguration: .init(isEnabled: testing, route: .onboarding, onboardingStep: nil, disablesAnimations: true))
                XCTAssertEqual(dependencies.permanentAddressService != nil, !demo && !testing)
                XCTAssertEqual(configuration.apiBaseURL.host, "staging-api.kairoid.com")
                if demo || testing {
                    XCTAssertTrue(dependencies.networkClient is DemoNetworkClient)
                    XCTAssertTrue(dependencies.tokenStore is InMemoryTokenStore)
                }
            }
        }
    }
    func testProductionContractOffThenOnUsesAuthenticatedMockOnly() async throws {
        let tokens = InMemoryTokenStore()
        try await tokens.save("synthetic-access", for: .accessToken)
        let network = AddressProductionContractNetwork()
        let session = SessionService(configuration: .init(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production), keychainService: "synthetic"),
            networkClient: network, tokenStore: tokens)
        let service = PermanentAddressService(session: session, enabled: true)
        let off = try await service.state()
        XCTAssertFalse(off.enabled)
        network.featureEnabled = true
        let on = try await service.state()
        XCTAssertTrue(on.enabled); XCTAssertEqual(on.status, "NOT_STARTED")
        XCTAssertEqual(network.requests.count, 2)
        XCTAssertTrue(network.requests.allSatisfy { $0.path == "/permanent-address" && $0.method == .get && $0.requiresPrivateJSONTransport })
    }
    func testManualReviewContractDecodesOptionalAndUnknownSafely() throws {
        let statuses = ["pending", "in_review", "waiting_for_address_document", "additional_evidence_requested",
            "correction_requested", "rejected", "historical_target_not_retained", "review_window_expired", "approved", "private_future_enum"]
        for status in statuses {
            let json = "{\"enabled\":true,\"status\":\"NEEDS_REVIEW\",\"manual_review_status\":\"\(status)\"}"
            let state = try APIJSONCoder.makeDecoder().decode(PermanentAddressState.self, from: Data(json.utf8))
            XCTAssertEqual(state.manualReviewStatus, status)
            XCTAssertNotNil(state.reviewMessage)
            XCTAssertFalse(state.isVerified)
            if status.contains("_") { XCTAssertFalse(state.reviewMessage?.contains(status) == true) }
        }
        let old = try APIJSONCoder.makeDecoder().decode(PermanentAddressState.self, from: Data(#"{"enabled":true,"status":"NEEDS_REVIEW"}"#.utf8))
        XCTAssertNil(old.manualReviewStatus); XCTAssertNil(old.reviewMessage)
    }
    func testManualApprovalExplainsOnlyServerReportedCheckOne() {
        var state = PermanentAddressState(enabled: true, status: "LOCATION_CHECK_REQUIRED",
            targetSource: "onsite_confirmation_manual_review", manualReviewStatus: "approved", successfulGpsChecks: 1)
        XCTAssertEqual(state.firstCheckMessage, "Check 1 confirmed via review. 2 more checks are required on different days.")
        XCTAssertNil(state.reviewMessage); XCTAssertFalse(state.isVerified)
        state.successfulGpsChecks = 0; XCTAssertNil(state.firstCheckMessage)
        state.successfulGpsChecks = 3; XCTAssertNil(state.firstCheckMessage); XCTAssertFalse(state.isVerified)
    }
    func testBackendOffBlocksEveryActionEvenWithStaleEligibleFields() async {
        let service = CurrentParityFixtures()
        await service.setState(.init(enabled: false, status: "PERMANENT_ADDRESS_VERIFIED", addressVersionId: CurrentParityFixtures.version, canStartLocation: true))
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        XCTAssertFalse(store.actionsAvailable); XCTAssertFalse(store.state?.isVerified == true)
        store.locate(); store.upload(file: URL(fileURLWithPath: "/never-read.pdf"), type: "voter_id", issued: nil)
        store.submitDocument(confirmed: true)
        XCTAssertFalse(store.busy); XCTAssertNil(store.document); XCTAssertNil(store.policy)
        let starts = await service.starts, uploads = await service.uploads, submits = await service.submissions
        XCTAssertEqual(starts, 0); XCTAssertEqual(uploads, 0); XCTAssertEqual(submits, 0)
    }
    func testFailedRefreshPreservesResultsButRevokesStaleEligibilityUntilRecovery() async {
        let service = CurrentParityFixtures(scenario: "approved")
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store)
        XCTAssertTrue(store.actionsAvailable); XCTAssertTrue(store.document?.approved == true)
        await service.setReadFailure(true)
        store.refresh(); await wait(store)
        XCTAssertFalse(store.actionsAvailable); XCTAssertNotNil(store.error)
        XCTAssertTrue(store.document?.approved == true)
        store.locate(); XCTAssertFalse(store.locationActive)
        let starts = await service.starts; XCTAssertEqual(starts, 0)
        await service.setReadFailure(false)
        store.refresh(); await wait(store)
        XCTAssertTrue(store.actionsAvailable); XCTAssertNil(store.error)
    }
    func testSameDayAndLaterDayEligibilityComesOnlyFromBackend() async {
        let service = CurrentParityFixtures(scenario: "same_day")
        let store = PermanentAddressStore(service: service, collector: SyntheticAddressCollector())
        store.refresh(); await wait(store); store.locate()
        var starts = await service.starts; XCTAssertEqual(starts, 0)
        XCTAssertEqual(store.state?.successfulGpsChecks, 1)
        var next = try! XCTUnwrap(store.state)
        next.todayComplete = false; next.canStartLocation = true
        await service.setState(next)
        store.refresh(); await wait(store); store.locate(); await wait(store)
        starts = await service.starts; XCTAssertEqual(starts, 1)
        XCTAssertEqual(store.state?.successfulGpsChecks, 1, "No client increment even after collection")
    }
    func testStopInvalidatesActionEligibilityAndStopsSyntheticCollector() async {
        let collector = SyntheticAddressCollector()
        let store = PermanentAddressStore(service: CurrentParityFixtures(), collector: collector)
        store.refresh(); await wait(store); XCTAssertTrue(store.actionsAvailable)
        store.stop(); XCTAssertFalse(store.actionsAvailable); XCTAssertTrue(collector.cancelled)
    }
    func testAllSyntheticMatrixStatesNeverUseRealCollectorOrInferVerification() async throws {
        for scenario in ["feature_off", "no_address", "required", "one", "two", "three", "review", "approved", "rejected", "correction", "manual_pending", "manual_correction_requested", "manual_approved", "verified"] {
            let state = try await CurrentParityFixtures(scenario: scenario).state()
            XCTAssertEqual(state.isVerified, scenario == "verified")
        }
    }
    private func wait(_ store: PermanentAddressStore) async {
        for _ in 0..<200 where store.busy { try? await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(store.busy)
    }
}

@MainActor private final class AddressProductionContractNetwork: NetworkClient {
    var featureEnabled = false
    var requests: [NetworkRequest] = []
    func send(_ request: NetworkRequest) async throws -> Data {
        requests.append(request)
        return Data("{\"enabled\":\(featureEnabled),\"status\":\"NOT_STARTED\"}".utf8)
    }
}
