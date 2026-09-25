import Foundation

nonisolated protocol DigiLockerServiceProtocol: Sendable {
    func status() async throws -> DigiLockerStatusDTO
    func connect() async throws -> DigiLockerConnectResponseDTO
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO
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
                allowsSessionRefreshOnUnauthorized: false
            )
        )
    }

    private func decode<Response: Decodable>(path: String) async throws -> Response {
        try await decode(NetworkRequest(path: path, headers: ["Accept": "application/json"]))
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

    func status() async throws -> DigiLockerStatusDTO { connection }

    func connect() async throws -> DigiLockerConnectResponseDTO {
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
        try fixtureHistory()
    }

    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        try APIJSONCoder.makeDecoder().decode(
            DigiLockerIdentityTrustDTO.self,
            from: Data(#"{"state":"verified","sources":[{"source":"digilocker","document_type":"DRVLC","current":true,"match_result":"VERIFIED_MATCH","reason":null},{"source":"digilocker","document_type":"PANCR","current":false,"match_result":"MISMATCH","reason":"NAME_MISMATCH"}]}"#.utf8)
        )
    }

    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        _ = documentTypes
        return try fixtureHistory()
    }

    private func fixtureHistory() throws -> DigiLockerVerificationHistoryDTO {
        try APIJSONCoder.makeDecoder().decode(
            DigiLockerVerificationHistoryDTO.self,
            from: Data(#"{"items":[{"document_type":"DRVLC","source":"digilocker","current":true,"match_result":"VERIFIED_MATCH","match_reason":null,"integrity_result":"verified","verified_at":"2026-08-01T10:00:00Z"},{"document_type":"PANCR","source":"digilocker","current":false,"match_result":"MISMATCH","match_reason":"NAME_MISMATCH","integrity_result":"verified","verified_at":null}],"identity_verified":true}"#.utf8)
        )
    }
}
