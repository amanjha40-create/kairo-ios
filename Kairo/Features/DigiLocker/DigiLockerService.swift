import Foundation

/// One-shot private JSON transport. Only finite error codes leave this boundary.
nonisolated enum DigiLockerPrivateTransport {
    static func send(_ request: URLRequest, protocolClasses: [AnyClass]? = nil) async throws -> NetworkResponse {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.protocolClasses = protocolClasses
        let session = URLSession(configuration: configuration, delegate: NoDocumentRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var privateRequest = request
        privateRequest.timeoutInterval = 30
        privateRequest.cachePolicy = .reloadIgnoringLocalCacheData
        privateRequest.httpShouldHandleCookies = false
        privateRequest.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        privateRequest.setValue("no-cache", forHTTPHeaderField: "Pragma")
        privateRequest.setValue(nil, forHTTPHeaderField: "Cookie")
        privateRequest.setValue(nil, forHTTPHeaderField: "Referer")
        do {
            try Task.checkCancellation()
            let (bytes, response) = try await session.bytes(for: privateRequest)
            guard let http = response as? HTTPURLResponse else { throw DigiLockerAadhaarState.uncertain }
            // Do not follow redirects or inspect their bodies.
            guard !(300..<400).contains(http.statusCode) else { throw DigiLockerAadhaarState.uncertain }
            let successful = (200..<300).contains(http.statusCode)
            let limit = successful ? 1_048_576 : 16_384
            guard http.mimeType == "application/json", response.expectedContentLength <= Int64(limit) else {
                if !successful { throw DigiLockerBackendError(statusCode: http.statusCode, code: nil) }
                throw DigiLockerAadhaarState.uncertain
            }
            var data = Data()
            for try await byte in bytes {
                guard data.count < limit else {
                    if !successful { throw DigiLockerBackendError(statusCode: http.statusCode, code: nil) }
                    throw DigiLockerAadhaarState.uncertain
                }
                data.append(byte)
            }
            try Task.checkCancellation()
            guard successful else {
                throw DigiLockerBackendError.decode(from: data, statusCode: http.statusCode)
            }
            return NetworkResponse(data: data, statusCode: http.statusCode)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled { throw CancellationError() }
            if let failure = error as? DigiLockerBackendError { throw failure }
            throw DigiLockerAadhaarState.from(error: error)
        }
    }
}

nonisolated protocol DigiLockerServiceProtocol: Sendable {
    func status() async throws -> DigiLockerStatusDTO
    func connect() async throws -> DigiLockerConnectResponseDTO
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO
    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO
    func verifyAadhaar() async throws -> DigiLockerVerificationDTO
}

extension DigiLockerServiceProtocol {
    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO {
        throw DigiLockerAadhaarState.unavailable
    }

    func verifyAadhaar() async throws -> DigiLockerVerificationDTO {
        throw DigiLockerAadhaarState.unavailable
    }
}

nonisolated enum DigiLockerAuthorizationURLValidator {
    static let allowedHost = "digilocker.meripehchaan.gov.in"
    static let allowedPath = "/public/oauth2/2/authorize"

    static func validate(_ value: String) throws -> URL {
        guard !value.contains(where: { $0.isWhitespace || $0 == "\\" }),
              let components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host?.lowercased() == allowedHost,
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              components.path == allowedPath,
              let url = components.url else {
            throw DigiLockerServiceError.invalidAuthorizationURL
        }
        return url
    }
}

nonisolated enum DigiLockerServiceError: Error, Equatable, LocalizedError, Sendable {
    case invalidAuthorizationURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidAuthorizationURL: "DigiLocker connection is unavailable."
        case .invalidResponse: "DigiLocker returned an unexpected response."
        }
    }
}

actor DigiLockerService: DigiLockerServiceProtocol {
    private static let root = "/integrations/digilocker"
    private let sessionService: any SessionServiceProtocol
    private let decoder = APIJSONCoder.makeDecoder()

    init(sessionService: any SessionServiceProtocol) {
        self.sessionService = sessionService
    }

    func status() async throws -> DigiLockerStatusDTO {
        try await decode(path: "\(Self.root)/status")
    }

    func connect() async throws -> DigiLockerConnectResponseDTO {
        let response: DigiLockerConnectResponseDTO = try await decode(
            NetworkRequest(
                path: "\(Self.root)/connect",
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: Data("{}".utf8),
                allowsSessionRefreshOnUnauthorized: false
            )
        )
        guard response.connectionState == .pending else { throw DigiLockerServiceError.invalidResponse }
        _ = try DigiLockerAuthorizationURLValidator.validate(response.authorizationURL)
        return response
    }

    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO {
        try await decode(path: "\(Self.root)/documents/issued")
    }

    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        try await decode(path: "\(Self.root)/identity/verifications")
    }

    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        try await decode(path: "\(Self.root)/identity/trust")
    }

    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        let body = DigiLockerVerifyRequestDTO(documentTypes: documentTypes.map(\.rawValue))
        return try await decode(
            NetworkRequest(
                path: "\(Self.root)/identity/verify",
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try APIJSONCoder.makeEncoder().encode(body),
                allowsSessionRefreshOnUnauthorized: false,
                requiresDigiLockerTransport: true
            )
        )
    }

    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO {
        try await aadhaarRequest(path: "/eaadhaar/availability")
    }

    func verifyAadhaar() async throws -> DigiLockerVerificationDTO {
        let response: DigiLockerAadhaarVerificationResponseDTO = try await aadhaarRequest(
            path: "/eaadhaar/verify", method: .post,
            body: APIJSONCoder.makeEncoder().encode(DigiLockerAadhaarVerifyRequestDTO())
        )
        return response.verification
    }

    private func aadhaarRequest<Response: Decodable>(
        path: String, method: HTTPMethod = .get, body: Data? = nil
    ) async throws -> Response {
        do {
            try Task.checkCancellation()
            let request = NetworkRequest(
                path: Self.root + path, method: method,
                headers: ["Accept": "application/json", "Content-Type": "application/json", "Cache-Control": "no-store"],
                body: body, allowsSessionRefreshOnUnauthorized: false,
                requiresDigiLockerTransport: true
            )
            let data = try await sessionService.sendAuthenticated(request)
            try Task.checkCancellation()
            return try decoder.decode(Response.self, from: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DigiLockerAadhaarState.from(error: error)
        }
    }

    private func decode<Response: Decodable>(path: String) async throws -> Response {
        let privateMetadata = path != "\(Self.root)/status"
        return try await decode(NetworkRequest(
            path: path,
            headers: ["Accept": "application/json"],
            allowsSessionRefreshOnUnauthorized: !privateMetadata,
            requiresDigiLockerTransport: privateMetadata
        ))
    }

    private func decode<Response: Decodable>(_ request: NetworkRequest) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(request)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw DigiLockerServiceError.invalidResponse
        }
    }
}

actor DemoDigiLockerService: DigiLockerServiceProtocol {
    private var connection = DigiLockerStatusDTO(connected: true, status: .active)
    private let returnFixture: DigiLockerReturnFixture?
    private var reads = 0
    private var aadhaarVerification: DigiLockerVerificationDTO?

    init(returnFixture: DigiLockerReturnFixture? = nil) {
        self.returnFixture = returnFixture
        if let returnFixture, returnFixture != .consent {
            connection = DigiLockerStatusDTO(connected: false, status: .disconnected)
        }
    }

    func status() async throws -> DigiLockerStatusDTO {
        reads += 1
        if returnFixture == .refreshFailure, reads > 2 { throw DigiLockerServiceError.invalidResponse }
        return connection
    }

    func connect() async throws -> DigiLockerConnectResponseDTO {
        guard returnFixture == nil else { throw DigiLockerServiceError.invalidResponse }
        connection = DigiLockerStatusDTO(connected: false, status: .pending)
        return try APIJSONCoder.makeDecoder().decode(
            DigiLockerConnectResponseDTO.self,
            from: Data(#"{"authorization_url":"https://digilocker.meripehchaan.gov.in/public/oauth2/2/authorize?client_id=demo","expires_at":"2026-12-01T10:00:00Z","connection_state":"pending"}"#.utf8)
        )
    }

    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO {
        DigiLockerIssuedDocumentsDTO(items: [
            DigiLockerIssuedDocumentDTO(documentType: "PANCR", supported: true),
            DigiLockerIssuedDocumentDTO(documentType: "DRVLC", supported: true)
        ])
    }

    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        let history = try fixtureHistory()
        guard let aadhaarVerification else { return history }
        return .init(items: history.items + [aadhaarVerification], identityVerified: true)
    }

    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        if returnFixture != nil {
            return .init(state: .verified, sources: DigiLockerDocumentType.allCases.map {
                .init(source: .digilocker, documentType: $0.rawValue, current: true, matchResult: .verifiedMatch, reason: nil)
            })
        }
        return try APIJSONCoder.makeDecoder().decode(
            DigiLockerIdentityTrustDTO.self,
            from: Data(#"{"state":"verified","sources":[{"source":"digilocker","document_type":"DRVLC","current":true,"match_result":"VERIFIED_MATCH","reason":null},{"source":"digilocker","document_type":"PANCR","current":false,"match_result":"MISMATCH","reason":"NAME_MISMATCH"}]}"#.utf8)
        )
    }

    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        guard returnFixture == nil else { throw DigiLockerServiceError.invalidResponse }
        _ = documentTypes
        return try fixtureHistory()
    }

    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO {
        .init(available: true)
    }

    func verifyAadhaar() async throws -> DigiLockerVerificationDTO {
        let result = DigiLockerVerificationDTO(
            documentType: "EAADHAAR", source: .digilocker, current: true,
            matchResult: .verifiedMatch, matchReason: nil, integrityResult: "verified", verifiedAt: Date()
        )
        aadhaarVerification = result
        return result
    }

    private func fixtureHistory() throws -> DigiLockerVerificationHistoryDTO {
        if returnFixture != nil {
            return .init(items: DigiLockerDocumentType.allCases.map {
                .init(documentType: $0.rawValue, source: .digilocker, current: true, matchResult: .verifiedMatch, matchReason: nil, integrityResult: "verified", verifiedAt: nil)
            }, identityVerified: true)
        }
        return try APIJSONCoder.makeDecoder().decode(
            DigiLockerVerificationHistoryDTO.self,
            from: Data(#"{"items":[{"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-08-01T10:00:00Z"},{"document_type":"PANCR","source":"digilocker","current":false,"match_result":"MISMATCH","match_reason":"NAME_MISMATCH","integrity_result":"verified","verified_at":null}],"identity_verified":true}"#.utf8)
        )
    }
}
