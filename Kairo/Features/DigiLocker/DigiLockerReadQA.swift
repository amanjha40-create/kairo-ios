import Foundation

/// Opt-in diagnostic build only. Shipping builds cannot activate this harness.
nonisolated enum DigiLockerReadQA: String, Sendable {
    case success, refreshFailure

    static func current(configuration: AppConfiguration) -> Self? {
        #if DEBUG && KAIRO_DIGILOCKER_READ_QA
        return resolve(configuration: configuration, arguments: ProcessInfo.processInfo.arguments,
                       environment: ProcessInfo.processInfo.environment)
        #else
        return nil
        #endif
    }

    static func resolve(configuration: AppConfiguration, arguments: [String], environment: [String: String]) -> Self? {
        guard configuration.buildConfiguration == .staging, configuration.environment == .staging,
              !configuration.isDemoModeEnabled,
              configuration.apiBaseURL == BuildEndpointPolicy.stagingAPIBaseURL,
              arguments.contains("-KAIRO_DIGILOCKER_READ_QA"),
              !arguments.contains("-KAIRO_UI_TESTING") else { return nil }
        return Self(rawValue: environment["KAIRO_DIGILOCKER_READ_QA_MODE"] ?? "")
    }

    var completionURL: URL { DigiLockerReturnFixture.connected.completionURL }
}

nonisolated enum DigiLockerReadQAError: Error { case blocked, injectedFailure, requestFailed }

/// The existing Keychain is read, never copied, replaced, rotated or cleared.
struct DigiLockerReadOnlyTokens: TokenStore {
    let underlying: any TokenStore
    func readToken(for key: TokenKey) async throws -> String? { try await underlying.readToken(for: key) }
    func save(_ token: String, for key: TokenKey) async throws { throw DigiLockerReadQAError.blocked }
    func deleteToken(for key: TokenKey) async throws { throw DigiLockerReadQAError.blocked }
}

actor DigiLockerReadQAEvidence {
    static let shared = DigiLockerReadQAEvidence()
    private var afterCallback = false
    private var failNextStatus = false

    func beginCallback(mode: DigiLockerReadQA) {
        afterCallback = true
        failNextStatus = mode == .refreshFailure
        print("[DigiLockerReadQA] callback_received=true")
    }

    func context(path: String) -> (afterCallback: Bool, injectFailure: Bool) {
        let inject = afterCallback && failNextStatus && path == "/integrations/digilocker/status"
        if inject { failNextStatus = false }
        return (afterCallback, inject)
    }
}

/// Deny by default, even for GETs. Issued inventory is excluded: that backend
/// route can refresh provider credentials. No auth refresh/logout or writes pass.
struct DigiLockerReadOnlyNetwork: NetworkClient {
    static let allowedPaths: Set<String> = [
        "/integrations/digilocker/status",
        "/integrations/digilocker/identity/trust",
        "/integrations/digilocker/identity/verifications"
    ]
    let underlying: any NetworkClient
    var evidence: DigiLockerReadQAEvidence = .shared

    func send(_ request: NetworkRequest) async throws -> Data { try await sendResponse(request).data }

    func sendResponse(_ request: NetworkRequest) async throws -> NetworkResponse {
        guard request.method == .get, Self.allowedPaths.contains(request.path),
              request.body == nil, request.queryItems.isEmpty,
              request.headers["Authorization"]?.hasPrefix("Bearer ") == true else {
            print("[DigiLockerReadQA] blocked_request=true")
            throw DigiLockerReadQAError.blocked
        }
        let context = await evidence.context(path: request.path)
        var protected = request
        // Reuse normal URLSession client with its existing private, no-redirect,
        // no-cookie/cache transport. Never log response bodies or header values.
        protected.requiresPrivateJSONTransport = true
        protected.allowsSessionRefreshOnUnauthorized = false
        print("[DigiLockerReadQA] sent route=\(request.path) authenticated=true after_callback=\(context.afterCallback)")
        let response: NetworkResponse
        do { response = try await underlying.sendResponse(protected) }
        catch {
            if case NetworkError.api(let apiError) = error {
                print("[DigiLockerReadQA] failed route=\(request.path) http=\(apiError.statusCode) after_callback=\(context.afterCallback)")
            } else {
                print("[DigiLockerReadQA] failed route=\(request.path) category=transport_or_response after_callback=\(context.afterCallback)")
            }
            // Do not allow SessionService to rotate or clear the real session on 401.
            throw DigiLockerReadQAError.requestFailed
        }
        print("[DigiLockerReadQA] response route=\(request.path) http=\(response.statusCode) after_callback=\(context.afterCallback)")
        if context.injectFailure {
            print("[DigiLockerReadQA] injected_post_response_failure=true")
            throw DigiLockerReadQAError.injectedFailure
        }
        return response
    }
}
