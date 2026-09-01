import Foundation

enum SessionServiceError: Error, Equatable, LocalizedError, Sendable {
    case missingAccessToken
    case missingRefreshToken
    case missingSignupSession
    case sessionExpired

    var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            "An authenticated request was attempted without an access token."
        case .missingRefreshToken:
            "A refresh was attempted without a refresh token."
        case .missingSignupSession:
            "A signup verification step was attempted without a signup session."
        case .sessionExpired:
            "Your session has expired. Please sign in again."
        }
    }
}

protocol SessionServiceProtocol: Sendable {
    func hasStoredAccessToken() async throws -> Bool
    func hasStoredRefreshToken() async throws -> Bool
    func readSignupSessionID() async throws -> String?
    func storeSignupSessionID(_ signupSessionID: String) async throws
    func clearSignupSessionID() async throws
    func persistTokens(_ tokens: TokenResponseDTO) async throws
    func clearSession() async throws
    func logoutRemotely() async throws
    func prepareBootstrapSession() async throws -> Bool
    func sendAuthenticated(_ request: NetworkRequest) async throws -> Data
    func sendAuthenticatedResponse(_ request: NetworkRequest) async throws -> NetworkResponse
}

extension SessionServiceProtocol {
    func sendAuthenticatedResponse(_ request: NetworkRequest) async throws -> NetworkResponse {
        NetworkResponse(data: try await sendAuthenticated(request), statusCode: 200)
    }
}

actor SessionService: SessionServiceProtocol {
    private let networkClient: any NetworkClient
    private let tokenStore: any TokenStore
    private var inFlightRefreshTask: Task<Void, Error>?

    init(
        configuration: AppConfiguration,
        networkClient: any NetworkClient,
        tokenStore: any TokenStore
    ) {
        self.networkClient = networkClient
        self.tokenStore = tokenStore
        _ = configuration
    }

    func hasStoredAccessToken() async throws -> Bool {
        try await tokenStore.readToken(for: .accessToken) != nil
    }

    func hasStoredRefreshToken() async throws -> Bool {
        try await tokenStore.readToken(for: .refreshToken) != nil
    }

    func readSignupSessionID() async throws -> String? {
        try await tokenStore.readToken(for: .signupSessionID)
    }

    func storeSignupSessionID(_ signupSessionID: String) async throws {
        try await tokenStore.save(signupSessionID, for: .signupSessionID)
    }

    func clearSignupSessionID() async throws {
        try await tokenStore.deleteToken(for: .signupSessionID)
    }

    func persistTokens(_ tokens: TokenResponseDTO) async throws {
        try await tokenStore.save(tokens.accessToken, for: .accessToken)
        try await tokenStore.save(tokens.refreshToken, for: .refreshToken)
    }

    func clearSession() async throws {
        try await tokenStore.deleteAllTokens()
    }

    func logoutRemotely() async throws {
        let refreshToken = try await requireToken(.refreshToken)
        _ = try await networkClient.sendJSON(
            path: "/auth/logout",
            method: .post,
            body: RefreshRequestDTO(refreshToken: refreshToken),
            headers: [
                "Accept": "application/json",
                "X-Request-ID": UUID().uuidString,
                "X-Correlation-ID": UUID().uuidString
            ]
        )
    }

    func prepareBootstrapSession() async throws -> Bool {
        if try await hasStoredAccessToken() {
            return true
        }

        guard try await hasStoredRefreshToken() else {
            return false
        }

        do {
            try await refreshSession()
            return true
        } catch {
            try await clearSession()
            throw SessionServiceError.sessionExpired
        }
    }

    func sendAuthenticated(_ request: NetworkRequest) async throws -> Data {
        try await sendAuthenticatedResponse(request).data
    }

    func sendAuthenticatedResponse(_ request: NetworkRequest) async throws -> NetworkResponse {
        try await sendAuthenticatedResponse(
            request,
            allowRefreshReplay: true,
            correlationID: UUID().uuidString
        )
    }

    private func sendAuthenticatedResponse(
        _ request: NetworkRequest,
        allowRefreshReplay: Bool,
        correlationID: String
    ) async throws -> NetworkResponse {
        guard let accessToken = try await tokenStore.readToken(for: .accessToken) else {
            throw SessionServiceError.missingAccessToken
        }

        let decoratedRequest = authenticatedRequest(
            from: request,
            accessToken: accessToken,
            correlationID: correlationID
        )

        do {
            return try await networkClient.sendResponse(decoratedRequest)
        } catch let error as NetworkError {
            if case .api(let apiError) = error, apiError.code == .unauthorized {
                guard allowRefreshReplay else {
                    try await clearSession()
                    throw SessionServiceError.sessionExpired
                }

                do {
                    try await refreshSession()
                } catch {
                    try await clearSession()
                    throw SessionServiceError.sessionExpired
                }

                return try await sendAuthenticatedResponse(
                    request,
                    allowRefreshReplay: false,
                    correlationID: correlationID
                )
            }

            throw error
        }
    }

    private func refreshSession() async throws {
        if let inFlightRefreshTask {
            return try await inFlightRefreshTask.value
        }

        let refreshTask = Task {
            let refreshToken = try await requireToken(.refreshToken)
            let response: TokenResponseDTO = try await decodeJSON(
                RefreshRequestDTO(refreshToken: refreshToken),
                path: "/auth/refresh"
            )
            try await persistTokens(response)
        }

        inFlightRefreshTask = refreshTask
        defer { inFlightRefreshTask = nil }
        try await refreshTask.value
    }

    private func requireToken(_ key: TokenKey) async throws -> String {
        if let value = try await tokenStore.readToken(for: key) {
            return value
        }

        switch key {
        case .accessToken:
            throw SessionServiceError.missingAccessToken
        case .refreshToken:
            throw SessionServiceError.missingRefreshToken
        case .signupSessionID:
            throw SessionServiceError.missingSignupSession
        }
    }

    private func authenticatedRequest(
        from request: NetworkRequest,
        accessToken: String,
        correlationID: String
    ) -> NetworkRequest {
        var headers = request.headers
        headers["Authorization"] = "Bearer \(accessToken)"
        headers["X-Request-ID"] = headers["X-Request-ID"] ?? UUID().uuidString
        headers["X-Correlation-ID"] = headers["X-Correlation-ID"] ?? correlationID
        headers["Accept"] = headers["Accept"] ?? "application/json"

        return NetworkRequest(
            path: request.path,
            method: request.method,
            headers: headers,
            queryItems: request.queryItems,
            body: request.body
        )
    }

    private func decodeJSON<Response: Decodable, Body: Encodable>(
        _ body: Body,
        path: String
    ) async throws -> Response {
        let data = try await networkClient.sendJSON(
            path: path,
            method: .post,
            body: body,
            headers: [
                "Accept": "application/json",
                "X-Request-ID": UUID().uuidString,
                "X-Correlation-ID": UUID().uuidString
            ]
        )
        return try APIJSONCoder.makeDecoder().decode(Response.self, from: data)
    }
}
