import AuthenticationServices
import Combine
import Foundation

nonisolated enum DigiLockerReturnOutcome: Equatable, Sendable {
    case connected, failed, cancelled, invalid, unavailable

    var message: String? {
        switch self {
        case .connected: nil // Only the subsequent authenticated read may say Connected.
        case .cancelled: "DigiLocker connection cancelled. Your saved verification results are preserved."
        case .failed, .invalid: "Couldn't connect DigiLocker. Your existing KairoID verification data was not changed. Refresh status before trying again."
        case .unavailable: "Couldn't open DigiLocker. Refresh status before trying again."
        }
    }
}

nonisolated enum DigiLockerReturnParser {
    static let scheme = "com.kairoid.staging.digilocker"

    static func parse(_ url: URL) -> DigiLockerReturnOutcome {
        // Match the complete canonical serialization too: encoded keys, whitespace,
        // userinfo, extra separators, paths, ports and fragments are not this contract.
        switch url.absoluteString {
        case "\(scheme)://complete?result=connected": .connected
        case "\(scheme)://complete?result=failed": .failed
        default: .invalid
        }
    }
}

@MainActor
protocol DigiLockerBrowserSession: AnyObject {
    func start(url: URL, completion: @escaping @MainActor (DigiLockerReturnOutcome) -> Void) -> Bool
    func cancel()
}

/// Uses system authentication UI. No global scheme, web-view inspection, or credentials.
@MainActor
final class SystemDigiLockerBrowserSession: NSObject, DigiLockerBrowserSession, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?

    func start(url: URL, completion: @escaping @MainActor (DigiLockerReturnOutcome) -> Void) -> Bool {
        let handler: ASWebAuthenticationSession.CompletionHandler = { url, error in
            let outcome: DigiLockerReturnOutcome
            if let error = error as? ASWebAuthenticationSessionError, error.code == .canceledLogin {
                outcome = .cancelled
            } else if error != nil {
                outcome = .unavailable
            } else {
                outcome = url.map(DigiLockerReturnParser.parse) ?? .invalid
            }
            Task { @MainActor in completion(outcome) }
        }
        let session: ASWebAuthenticationSession
        if #available(iOS 17.4, *) {
            session = ASWebAuthenticationSession(url: url, callback: .customScheme(DigiLockerReturnParser.scheme), completionHandler: handler)
        } else {
            session = ASWebAuthenticationSession(url: url, callbackURLScheme: DigiLockerReturnParser.scheme, completionHandler: handler)
        }
        self.session = session
        session.presentationContextProvider = self
        return session.start()
    }

    func cancel() { session?.cancel(); session = nil }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}

/// Covers connect request AND browser lifetime; callbacks are consumed at most once.
@MainActor
final class DigiLockerAuthenticationCoordinator: ObservableObject {
    @Published private(set) var isActive = false
    private let browser: any DigiLockerBrowserSession
    private var attempt: UUID?
    private var continuation: CheckedContinuation<DigiLockerReturnOutcome, Never>?

    init(browser: any DigiLockerBrowserSession = SystemDigiLockerBrowserSession()) {
        self.browser = browser
    }

    func connect(authorize: () async -> URL?) async -> DigiLockerReturnOutcome? {
        guard !isActive else { return nil }
        let id = UUID()
        attempt = id
        isActive = true
        defer { if attempt == id { attempt = nil; isActive = false } }
        guard let url = await authorize() else { return .unavailable }
        guard attempt == id else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            if !browser.start(url: url, completion: { [weak self] outcome in
                self?.finish(outcome, id: id)
            }) { finish(.unavailable, id: id) }
        }
    }

    private func finish(_ outcome: DigiLockerReturnOutcome, id: UUID) {
        guard attempt == id, let continuation else { return }
        self.continuation = nil
        // Consumed continuation prevents reentry; keep the attempt locked until return.
        browser.cancel()
        continuation.resume(returning: outcome)
    }

    func cancel() {
        if let id = attempt, continuation != nil { finish(.cancelled, id: id) }
        else { attempt = nil; isActive = false; browser.cancel() }
    }
}

nonisolated struct DigiLockerConsent: Equatable, Sendable {
    private(set) var selected = Set<DigiLockerDocumentType>()
    var accepted = false
    var canVerify: Bool { !selected.isEmpty && accepted }
    mutating func select(_ type: DigiLockerDocumentType, enabled: Bool) {
        if enabled { selected.insert(type) } else { selected.remove(type) }
        accepted = false
    }
}

/// Explicit synthetic QA only. Never starts government OAuth or writes Candidate data.
nonisolated enum DigiLockerReturnFixture: String, Sendable {
    case connected, failed, consent, refreshFailure, invalid

    static func current(configuration: AppConfiguration) -> Self? {
        guard configuration.environment == .staging,
              UITestLaunchConfiguration.current().validated(for: configuration).isEnabled else { return nil }
        return Self(rawValue: ProcessInfo.processInfo.environment["KAIRO_UI_TEST_DIGILOCKER_RETURN"] ?? "")
    }

    var completionURL: URL {
        // Fixed public safe-result page only; no provider URL or capability parameter.
        URL(string: "https://staging-api.kairoid.com/api/v1/integrations/digilocker/complete?digilocker_result=\(self == .failed ? "failed" : "connected")")!
    }
}
