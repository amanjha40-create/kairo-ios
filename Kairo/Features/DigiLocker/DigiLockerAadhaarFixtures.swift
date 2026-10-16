import Foundation

/// Selected only inside the already validated, network-disabled UI-test dependency graph.
actor DigiLockerAadhaarFixtureService: DigiLockerServiceProtocol {
    private let scenario: String
    private let base = DemoDigiLockerService()
    private var didVerify = false

    init(scenario: String) { self.scenario = scenario }

    func status() async throws -> DigiLockerStatusDTO {
        if scenario == "base-disabled" { throw failure("digilocker_not_configured", status: 503) }
        if scenario == "reconnect" { return .init(connected: false, status: .reconnectRequired) }
        return .init(connected: true, status: .active)
    }

    func connect() async throws -> DigiLockerConnectResponseDTO {
        // Even an accidental fixture Connect tap cannot open a provider browser.
        throw DigiLockerServiceError.invalidAuthorizationURL
    }

    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO {
        try await base.issuedDocuments()
    }

    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        let saved = try await base.verificationHistory()
        return .init(items: saved.items + ((didVerify || scenario == "verified") ? [verifiedRecord()] : []), identityVerified: saved.identityVerified)
    }

    func identityTrust() async throws -> DigiLockerIdentityTrustDTO {
        let truth = try await base.identityTrust()
        return .init(state: truth.state, sources: truth.sources + ((didVerify || scenario == "verified") ? [
            .init(source: .digilocker, documentType: "EAADHAAR", current: true, matchResult: .verifiedMatch, reason: nil)
        ] : []))
    }

    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        try await verificationHistory()
    }

    func aadhaarAvailability() async throws -> DigiLockerAadhaarAvailabilityDTO {
        switch scenario {
        case "disabled": throw failure("NOT_FOUND", status: 404)
        case "denied": throw failure("digilocker_insufficient_scope", status: 403)
        case "expired": throw failure("digilocker_invalid_token", status: 400)
        case "temporary": throw failure("digilocker_provider_unavailable", status: 503)
        case "integrity": throw failure("digilocker_integrity_failed", status: 503)
        default: break
        }
        let body = scenario == "not-linked"
            ? #"{"available":false,"entitlement_confirmed":false}"#
            : #"{"available":true,"entitlement_confirmed":false}"#
        return try APIJSONCoder.makeDecoder().decode(DigiLockerAadhaarAvailabilityDTO.self, from: Data(body.utf8))
    }

    func verifyAadhaar() async throws -> DigiLockerVerificationDTO {
        didVerify = true
        return verifiedRecord()
    }

    private func verifiedRecord() -> DigiLockerVerificationDTO {
        .init(documentType: "EAADHAAR", source: .digilocker, current: true,
              matchResult: .verifiedMatch, matchReason: nil, integrityResult: "verified",
              verifiedAt: Date(timeIntervalSince1970: 1_790_000_000))
    }

    private func failure(_ code: String, status: Int) -> DigiLockerBackendError {
        .init(statusCode: status, code: DigiLockerBackendErrorCode(rawValue: code))
    }
}
