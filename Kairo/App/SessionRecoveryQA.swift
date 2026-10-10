import SwiftUI
import Combine

// Explicit Staging-only fixture. No Keychain, URLSession, or live credentials.
enum SessionRecoveryQA {
    static func isEnabled(
        configuration: AppConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        configuration.buildConfiguration == .staging
            && configuration.environment == .staging
            && !configuration.isDemoModeEnabled
            && arguments.contains(UITestLaunchConfiguration.enabledArgument)
            && environment["KAIRO_UI_TEST_SESSION_RECOVERY"] == "1"
    }
}

actor SessionRecoveryQANetwork: NetworkClient {
    enum Mode { case healthy, transient, rejected }
    private var mode: Mode = .healthy
    func configure(_ mode: Mode) { self.mode = mode }

    func send(_ request: NetworkRequest) async throws -> Data {
        switch (request.path, request.method) {
        case ("/users/me", .get):
            if request.headers["Authorization"] != "Bearer fixture-recovered-access" {
                throw rejection()
            }
            return Data(#"{"ok":true}"#.utf8)
        case ("/auth/refresh", .post):
            switch mode {
            case .transient: throw NetworkError.transport("Synthetic temporary connection failure")
            case .rejected: throw rejection()
            case .healthy:
                return Data(#"{"access_token":"fixture-recovered-access","refresh_token":"fixture-recovered-refresh","token_type":"bearer","expires_in":3600}"#.utf8)
            }
        default:
            throw NetworkError.unavailableInDemoMode
        }
    }

    private func rejection() -> NetworkError {
        .api(APIError(statusCode: 401, code: .unauthorized, message: "Synthetic rejection",
                      fieldErrors: [:], globalErrors: [], validationDetails: []))
    }
}

@MainActor
final class SessionRecoveryQAModel: ObservableObject {
    @Published private(set) var message = "Preparing synthetic session"
    @Published private(set) var credentialsPresent = false
    @Published private(set) var busy = true
    @Published private(set) var expired = false
    @Published private(set) var retryAvailable = false
    let router = AppRouter()
    let store: AppSessionStore
    let auth: UITestAuthService
    private let tokens = InMemoryTokenStore()
    private let network = SessionRecoveryQANetwork()
    private let session: SessionService
    private var started = false

    init(configuration: AppConfiguration) {
        session = SessionService(configuration: configuration, networkClient: network, tokenStore: tokens)
        auth = UITestAuthService(sessionService: session, configuration: .current(
            environment: [UITestAuthConfiguration.onboardingStatusKey: "complete"]
        ))
        store = AppSessionStore(configuration: configuration,
            uiTestConfiguration: .init(isEnabled: false, route: .onboarding, onboardingStep: nil, disablesAnimations: true),
            router: router, authService: auth, sessionService: session,
            manualProfileService: DemoManualProfileService(authService: auth),
            resumeImportService: DemoResumeImportService())
    }

    func start() async {
        guard !started else { return }
        started = true
        do {
            try await session.persistTokens(.init(accessToken: "fixture-expired-access",
                refreshToken: "fixture-refresh", tokenType: "bearer", expiresIn: 3600))
            await store.refreshLaunchRoute()
            await read()
        } catch {
            message = "Fixture setup failed"
            busy = false
        }
    }

    func failTemporarily() async { await exercise(.transient) }
    func reject() async { await exercise(.rejected) }
    func retry() async {
        await network.configure(.healthy)
        await read()
    }

    private func exercise(_ mode: SessionRecoveryQANetwork.Mode) async {
        guard !busy, !expired else { return }
        do {
            // Only disposable in-memory access is expired; never a real token.
            try await tokens.save("fixture-expired-access", for: .accessToken)
            await network.configure(mode)
            await read()
        } catch { message = "Fixture setup failed" }
    }

    private func read() async {
        busy = true
        defer { busy = false }
        do {
            _ = try await session.sendAuthenticated(NetworkRequest(path: "/users/me"))
            message = "Authenticated fixture data loaded"
            retryAvailable = false
        } catch SessionServiceError.sessionExpired {
            await store.refreshLaunchRoute()
            expired = store.currentUser == nil && router.rootDestination == .onboarding
            message = "Synthetic session expired"
            retryAvailable = false
        } catch {
            message = "Temporary failure. Your synthetic session is preserved. Retry when ready."
            retryAvailable = true
        }
        let access = (try? await session.hasStoredAccessToken()) == true
        let refresh = (try? await session.hasStoredRefreshToken()) == true
        credentialsPresent = access && refresh
    }
}

struct SessionRecoveryQARootView: View {
    @StateObject private var model: SessionRecoveryQAModel
    init(configuration: AppConfiguration) {
        _model = StateObject(wrappedValue: SessionRecoveryQAModel(configuration: configuration))
    }
    var body: some View {
        VStack {
            Text("Session QA — synthetic; network blocked").font(.caption)
            Text(model.message).accessibilityIdentifier("sessionQA.status")
            Text(model.credentialsPresent ? "Synthetic credentials present" : "Synthetic credentials absent")
                .accessibilityIdentifier("sessionQA.credentials")
            if model.expired {
                // Actual signed-out route: authenticated tabs are no longer rendered.
                RootShellView()
                    .environmentObject(model.router)
                    .environmentObject(model.store)
                    .environment(\.authService, model.auth)
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Synthetic signed-in session").accessibilityIdentifier("sessionQA.signedIn")
                        Button("Trigger temporary refresh failure") { Task { await model.failTemporarily() } }
                            .accessibilityIdentifier("sessionQA.fail")
                        if model.retryAvailable {
                            Button("Retry") { Task { await model.retry() } }.accessibilityIdentifier("sessionQA.retry")
                        }
                        Button("Trigger confirmed auth rejection") { Task { await model.reject() } }
                            .accessibilityIdentifier("sessionQA.reject")
                    }.padding().disabled(model.busy)
                }
            }
        }.padding(.top).task { await model.start() }
    }
}
