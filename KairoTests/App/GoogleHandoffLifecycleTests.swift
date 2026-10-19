import SwiftUI
import XCTest
@testable import Kairo

/// Hosts the real root/sheet and AuthService. No URLSession or Keychain is used.
@MainActor
final class GoogleHandoffLifecycleTests: XCTestCase {
    private var window: UIWindow?
    private var previousKeyWindow: UIWindow?

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
        super.tearDown()
    }

    func test_coldHandoffQueuedBeforeRootMountStartsExchange() async throws {
        let fixture = Fixture()
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        mount(fixture)
        await assertExchange(fixture)
    }

    func test_warmHandoffAfterSignedOutBootstrapStartsExchange() async throws {
        let fixture = Fixture()
        mount(fixture)
        await settle()
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        await assertExchange(fixture)
    }

    func test_duplicateEntryDeliveryRetainsOnePresentationIdentity() throws {
        let fixture = Fixture()
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        let first = try XCTUnwrap(fixture.router.googleAuthenticationPresentation?.id)
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        XCTAssertEqual(fixture.router.googleAuthenticationPresentation?.id, first,
                       "onOpenURL and browsing-web continuation must not replace the same one-time handoff")
    }

    func test_linkDuringDelayedSessionBootstrapStillStartsExchange() async throws {
        let tokens = DelayedEmptyTokenStore()
        let fixture = Fixture(tokens: tokens)
        mount(fixture)
        for _ in 0..<40 {
            if await tokens.readStarted { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(fixture.store.launchPhase, .bootstrapping)
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        await assertExchange(fixture)
        await tokens.releaseReads()
        await settle()
        XCTAssertNotNil(fixture.router.googleAuthenticationPresentation,
                        "Finishing signed-out bootstrap must not discard a handoff")
        XCTAssertEqual(fixture.network.exchangeCount, 1)
    }

    func test_duplicateDeliveryDuringExchangeDoesNotStartSecondRequest() async throws {
        let fixture = Fixture()
        fixture.network.delayResponse = true
        mount(fixture)
        await settle()
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        for _ in 0..<40 {
            if fixture.network.exchangeCount > 0 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(fixture.network.exchangeCount, 1)
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        try await Task.sleep(for: .seconds(2))
        XCTAssertEqual(fixture.network.exchangeCount, 1, "Repeated delivery must not exchange a one-time code twice")
    }

    private func assertExchange(_ fixture: Fixture) async {
        for _ in 0..<40 {
            if fixture.network.exchangeCount > 0 { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        await settle()
        let count = fixture.network.exchangeCount
        XCTAssertEqual(count, 1, "A valid queued link must start exactly one exchange from the actual rendered handoff")
        XCTAssertNotNil(fixture.router.googleAuthenticationPresentation)
        XCTAssertEqual(fixture.router.rootDestination, .onboarding, "A synthetic failed outcome cannot authenticate")
    }

    private func settle() async { try? await Task.sleep(for: .milliseconds(400)) }

    private func mount(_ fixture: Fixture) {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let view = AppRootView()
            .environmentObject(fixture.router)
            .environmentObject(fixture.store)
            .environmentObject(CandidateDataRefreshStore())
            .environmentObject(CandidateNotificationStore(service: fixture.demo.candidateNotificationService))
            .environmentObject(DigiLockerStore(service: fixture.demo.digiLockerService))
            .environmentObject(AppAppearanceStore())
            .environmentObject(GuidedTourCoordinator(preferences: GuidedTourPreferences(), testConfiguration: .disabled))
            .environment(\.appConfiguration, fixture.configuration)
            .environment(\.authService, fixture.auth)
            .environment(\.networkClient, fixture.network)
            .environment(\.tokenStore, fixture.tokens)
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        self.window = window
    }

    @MainActor
    private final class Fixture {
        let configuration = AppConfiguration(buildConfiguration: .production, environment: .production,
            isDemoModeEnabled: false, apiBaseURL: APIConfiguration.baseURL(for: .production),
            keychainService: "synthetic.handoff.lifecycle.never.used")
        let router = AppRouter()
        let network = HandoffNetwork()
        let tokens: any TokenStore
        let demo: AppDependencies
        let auth: AuthService
        let store: AppSessionStore
        let url = URL(string: "https://api.kairoid.com/auth/google/complete?code=synthetic_01234567890123456789012345678901234")!

        init(tokens: any TokenStore = InMemoryTokenStore()) {
            self.tokens = tokens
            demo = AppDependencies.make(configuration: AppConfiguration(buildConfiguration: .demo,
                environment: .development, isDemoModeEnabled: true,
                apiBaseURL: APIConfiguration.baseURL(for: .development), keychainService: "synthetic.demo"))
            let session = SessionService(configuration: configuration, networkClient: network, tokenStore: tokens)
            auth = AuthService(configuration: configuration, networkClient: network, sessionService: session)
            store = AppSessionStore(configuration: configuration,
                uiTestConfiguration: UITestLaunchConfiguration(isEnabled: false, route: .onboarding,
                    onboardingStep: nil, disablesAnimations: false), router: router,
                authService: auth, sessionService: session, manualProfileService: demo.manualProfileService,
                resumeImportService: demo.resumeImportService)
        }
    }
}

@MainActor
private final class HandoffNetwork: NetworkClient {
    private(set) var exchangeCount = 0
    var delayResponse = false
    func send(_ request: NetworkRequest) async throws -> Data {
        guard request.path == "/auth/google/handoff/exchange" else {
            throw NetworkError.transport("Synthetic network blocks every other route")
        }
        exchangeCount += 1
        if delayResponse { try await Task.sleep(for: .seconds(3)) }
        return Data(#"{"outcome":"AUTH_FAILED","message":"Synthetic failure","tokens":null,"signup":null}"#.utf8)
    }
}

private actor DelayedEmptyTokenStore: TokenStore {
    private(set) var readStarted = false
    private var blocked = true
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func readToken(for key: TokenKey) async throws -> String? {
        readStarted = true
        if blocked { await withCheckedContinuation { waiting.append($0) } }
        return nil
    }

    func releaseReads() {
        blocked = false
        waiting.forEach { $0.resume() }
        waiting.removeAll()
    }

    func save(_ token: String, for key: TokenKey) async throws {
        XCTFail("Synthetic failure must never persist a session")
    }

    func deleteToken(for key: TokenKey) async throws {}
}
