import Foundation

/// Network-blocked UI fixture for API87 discovery orchestration and presentation.
actor DigiLockerDiscoveryFixtureService: DigiLockerServiceProtocol {
    private let scenario: String
    private let base = DemoDigiLockerService()

    init(scenario: String) { self.scenario = scenario }

    func status() async throws -> DigiLockerStatusDTO { .init(connected: true, status: .active) }
    func connect() async throws -> DigiLockerConnectResponseDTO { throw DigiLockerServiceError.invalidAuthorizationURL }
    func issuedDocuments() async throws -> DigiLockerIssuedDocumentsDTO {
        if scenario == "partial-issued-failure" {
            throw DigiLockerBackendError(statusCode: 530, code: nil)
        }
        return try await base.issuedDocuments()
    }
    func availableRecords() async throws -> DigiLockerAvailableRecordsDTO {
        try APIJSONCoder.makeDecoder().decode(
            DigiLockerAvailableRecordsDTO.self,
            from: Data(Self.partialPayload.utf8)
        )
    }
    func verificationHistory() async throws -> DigiLockerVerificationHistoryDTO {
        try await base.verificationHistory()
    }
    func identityTrust() async throws -> DigiLockerIdentityTrustDTO { try await base.identityTrust() }
    func verify(documentTypes: [DigiLockerDocumentType]) async throws -> DigiLockerVerificationHistoryDTO {
        _ = documentTypes
        throw DigiLockerServiceError.invalidResponse
    }

    private nonisolated static let partialPayload = #"{"discovery_status":"partial_success","identity":[{"candidate_id":"fixture-pan","doctype":"PANCR","record_type":"identity","display_type":"PAN","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","failure_reason":null},{"candidate_id":"fixture-dl","doctype":"DRVLC","record_type":"identity","display_type":"Driving Licence","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","failure_reason":null}],"education":[{"candidate_id":"fixture-education","record_type":"education","display_type":"Education records","source":"digilocker","possible_existing_record_match":"NO_MATCH","import_status":"available","review_state":"ready","evidence":[{"candidate_id":"fixture-degree","doctype":"DGCER","record_type":"education","display_type":"Degree certificate","description":null,"issuer_name":null,"source":"digilocker","xml_available":true,"pdf_available":true,"parsed_data_available":true,"import_status":"available","possible_existing_record_match":"NO_MATCH","review_state":"ready","evidence_type":"degree","failure_reason":null},{"candidate_id":"fixture-school","doctype":"SPCER","record_type":"education","display_type":"School certificate","description":null,"issuer_name":null,"source":"digilocker","xml_available":false,"pdf_available":false,"parsed_data_available":false,"import_status":"needs_review","possible_existing_record_match":"NO_MATCH","review_state":"parse_failed","evidence_type":"certificate","failure_reason":"provider_unavailable"}]}],"address_candidates":[],"address_prefill_candidates":[{"candidate_id":"fixture-address","doctype":"DRVLC","display_type":"Driving Licence address","source":"digilocker_driving_licence","review_state":"ready","candidate_type":"prefill","address_state":"ADDRESS_PREFILL_CANDIDATE","document_address_type":"untyped","requires_permanent_confirmation":true,"requires_replacement_confirmation":false,"prefill_text":"Synthetic address for review","structured_address":null}],"address_discovery_state":"ADDRESS_PREFILL_CANDIDATE","counts":{"total_issued":5,"supported":5,"unsupported":0,"identity":2,"education":1,"address_candidates":0,"address_prefill_candidates":1,"xml_available":3,"pdf_only":0,"parse_failures":1,"malformed":0,"provider_failures":1},"discovered_at":"2026-11-02T10:00:00Z"}"#
}

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

    func availableRecords() async throws -> DigiLockerAvailableRecordsDTO {
        DigiLockerAvailableRecordsDTO(
            identity: [], education: [], addressCandidates: [], addressPrefillCandidates: [],
            addressDiscoveryState: "NO_ADDRESS_AVAILABLE",
            counts: DigiLockerDiscoveryCountsDTO(
                totalIssued: 0, supported: 0, unsupported: 0, identity: 0, education: 0,
                addressCandidates: 0, addressPrefillCandidates: 0,
                xmlAvailable: 0, pdfOnly: 0, parseFailures: 0, malformed: 0
            ),
            discoveredAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
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
