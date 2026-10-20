import SwiftUI
import XCTest
@testable import Kairo

/// Hosts the real root/sheet and AuthService. No URLSession or Keychain is used.
@MainActor
final class GoogleHandoffLifecycleTests: XCTestCase {
    private var window: UIWindow?
    private var previousKeyWindow: UIWindow?
    private var measureRoot: ((CGSize) -> CGSize)?

    override func tearDown() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        measureRoot = nil
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

    func test_productionSessionLoadingFillsSmallAndLargeViewportsInBothAppearances() async throws {
        let tokens = DelayedEmptyTokenStore()
        let fixture = Fixture(tokens: tokens)
        mount(fixture)
        for _ in 0..<40 {
            if await tokens.readStarted { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertEqual(fixture.store.launchPhase, .bootstrapping)
        if let controller = window?.rootViewController {
            for style in [UIUserInterfaceStyle.light, .dark] {
                controller.overrideUserInterfaceStyle = style
                for viewport in [CGSize(width: 414, height: 896), CGSize(width: 430, height: 932)] {
                    let measured = try XCTUnwrap(measureRoot)(viewport)
                    XCTAssertEqual(measured.width, viewport.width, accuracy: 1)
                    XCTAssertEqual(measured.height, viewport.height, accuracy: 1)
                }
            }
        } else {
            XCTFail("Expected the real Production-configured root view")
        }
        XCTAssertEqual(fixture.network.exchangeCount, 0)
        await tokens.releaseReads()
        await settle()
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

    func test_fragmentIsNeverForwardedToExchange() async throws {
        let fixture = Fixture()
        let url = URL(string: fixture.url.absoluteString + "#code=fragment_must_not_be_forwarded&state=synthetic")!
        mount(fixture)
        await settle()
        XCTAssertTrue(fixture.router.handleIncomingURL(url, configuration: fixture.configuration))
        await assertExchange(fixture)
        XCTAssertTrue(fixture.network.queryCodeOnly)
    }

    func test_duplicateWithDifferentFragmentRetainsPresentation() throws {
        let fixture = Fixture()
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        let id = try XCTUnwrap(fixture.router.googleAuthenticationPresentation?.id)
        let url = URL(string: fixture.url.absoluteString + "#different")!
        XCTAssertTrue(fixture.router.handleIncomingURL(url, configuration: fixture.configuration))
        XCTAssertEqual(fixture.router.googleAuthenticationPresentation?.id, id)
    }

    func test_exchangeClaimIsAtomicAndSurvivesDismissal() async throws {
        let fixture = Fixture()
        fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration)
        let presentation = try XCTUnwrap(fixture.router.googleAuthenticationPresentation)
        let claims = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask { await fixture.router.beginGoogleHandoffExchange(presentation) }
            }
            var successes = 0
            for await result in group { if result { successes += 1 } }
            return successes
        }
        XCTAssertEqual(claims, 1)
        fixture.router.dismissGoogleAuthentication()
        XCTAssertFalse(fixture.router.beginGoogleHandoffExchange(presentation))
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        XCTAssertNil(fixture.router.googleAuthenticationPresentation)
    }

    func test_completedExchangeAndDismissedPresentationCannotReplay() async throws {
        let fixture = Fixture()
        mount(fixture)
        await settle()
        fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration)
        await assertExchange(fixture)
        fixture.router.dismissGoogleAuthentication()
        await settle()
        XCTAssertTrue(fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration))
        await settle()
        XCTAssertNil(fixture.router.googleAuthenticationPresentation)
        XCTAssertEqual(fixture.network.exchangeCount, 1)
    }

    func test_distinctNewHandoffCanStartAfterPriorDismissal() throws {
        let fixture = Fixture()
        fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration)
        let first = try XCTUnwrap(fixture.router.googleAuthenticationPresentation)
        XCTAssertTrue(fixture.router.beginGoogleHandoffExchange(first))
        fixture.router.dismissGoogleAuthentication()
        let next = URL(string: "https://api.kairoid.com/auth/google/complete?code=another_synthetic_0123456789012345678901234")!
        XCTAssertTrue(fixture.router.handleIncomingURL(next, configuration: fixture.configuration))
        let second = try XCTUnwrap(fixture.router.googleAuthenticationPresentation)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertTrue(fixture.router.beginGoogleHandoffExchange(second))
    }

    func test_remountedHandoffViewCannotRestartClaimedExchange() async throws {
        let fixture = Fixture()
        fixture.router.handleIncomingURL(fixture.url, configuration: fixture.configuration)
        let presentation = try XCTUnwrap(fixture.router.googleAuthenticationPresentation)
        XCTAssertTrue(fixture.router.beginGoogleHandoffExchange(presentation))
        mount(fixture)
        await settle()
        XCTAssertEqual(fixture.network.exchangeCount, 0)
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
        let controller = UIHostingController(rootView: view)
        measureRoot = { controller.sizeThatFits(in: $0) }
        window.rootViewController = controller
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
    private(set) var queryCodeOnly = false
    var delayResponse = false
    func send(_ request: NetworkRequest) async throws -> Data {
        guard request.path == "/auth/google/handoff/exchange" else {
            throw NetworkError.transport("Synthetic network blocks every other route")
        }
        exchangeCount += 1
        if let body = request.body,
           let json = try? JSONSerialization.jsonObject(with: body) as? [String: String] {
            queryCodeOnly = json == ["code": "synthetic_01234567890123456789012345678901234"]
        }
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
