import Foundation

protocol VerificationInitiationServiceProtocol: Sendable {
    func loadEligibility() async throws -> VerificationInitiationEligibility
    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument]
    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult
}

actor VerificationInitiationService: VerificationInitiationServiceProtocol {
    private let careerService: any CareerOverviewServiceProtocol
    private let sessionService: any SessionServiceProtocol
    private let decoder = APIJSONCoder.makeDecoder()
    private let encoder = APIJSONCoder.makeEncoder()

    init(
        careerService: any CareerOverviewServiceProtocol,
        sessionService: any SessionServiceProtocol
    ) {
        self.careerService = careerService
        self.sessionService = sessionService
    }

    func loadEligibility() async throws -> VerificationInitiationEligibility {
        async let career = careerService.loadOverview()
        async let requests = loadRequestList()

        let overview = try await career
        let activeLinks = try await requests
            .filter { !Self.terminalStatuses.contains($0.status.lowercased()) }

        let activeEmploymentIDs = Set(activeLinks.compactMap(\.employmentID))
        let activeEducationIDs = Set(activeLinks.compactMap(\.educationID))

        let employments = overview.employments.map { record in
            VerificationInitiationSubject(
                id: record.id,
                kind: .employment,
                title: record.company,
                subtitle: record.role,
                verificationStatus: record.verificationStatus,
                hasActiveRequest: activeEmploymentIDs.contains(record.id)
            )
        }
        let educations = overview.educations.map { record in
            VerificationInitiationSubject(
                id: record.id,
                kind: .education,
                title: record.institution,
                subtitle: record.degree,
                verificationStatus: record.verificationStatus,
                hasActiveRequest: activeEducationIDs.contains(record.id)
            )
        }

        return VerificationInitiationEligibility(subjects: employments + educations)
    }

    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument] {
        let documents: [VerificationEvidenceDocument]

        switch subject.kind {
        case .employment:
            let page: VerificationDocumentPageDTO<EmploymentVerificationDocumentDTO> = try await get(
                path: "/employments/\(subject.id)/documents"
            )
            documents = page.items.map {
                VerificationEvidenceDocument(
                    id: $0.id,
                    documentType: $0.documentType,
                    filename: $0.originalFilename,
                    isUploadComplete: $0.verificationStatus.lowercased() != "pending_upload"
                )
            }
        case .education:
            let page: VerificationDocumentPageDTO<EducationVerificationDocumentDTO> = try await get(
                path: "/educations/\(subject.id)/documents"
            )
            // The current education document response contains only completed document rows;
            // the backend remains authoritative and revalidates checksum completion at creation.
            documents = page.items.map {
                VerificationEvidenceDocument(
                    id: $0.id,
                    documentType: $0.documentType,
                    filename: $0.originalFilename,
                    isUploadComplete: true
                )
            }
        }

        let completed = documents.filter(\.isUploadComplete)
        guard !completed.isEmpty else {
            throw VerificationInitiationServiceError.noCompletedEvidence
        }
        return completed
    }

    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult {
        guard draft.canSubmit else {
            throw VerificationInitiationServiceError.noCompletedEvidence
        }

        let created: VerificationRequestResponseDTO
        let reusedExistingRequest: Bool

        do {
            created = try await createDraft(draft)
            reusedExistingRequest = created.status.lowercased() != "pending_subject_submission"
        } catch let error as NetworkError {
            guard case .api(let apiError) = error, apiError.statusCode == 409 else {
                throw error
            }
            created = try await loadExistingRequest(for: draft.subject)
            reusedExistingRequest = true
        }

        let submitted: VerificationRequestResponseDTO
        if created.status.lowercased() == "pending_subject_submission" {
            guard let requestID = created.routingID else {
                throw VerificationInitiationServiceError.missingRequestIdentifier
            }
            submitted = try await post(
                path: "/verification-requests/\(requestID)/submit-for-review",
                body: VerificationSubmitForReviewRequestDTO(
                    consentedFields: draft.consentedFields,
                    consentedEvidenceScope: draft.consentedEvidenceScope,
                    consentVersion: "candidate_verification_initiation_v1"
                )
            )
        } else {
            submitted = created
        }

        guard let requestID = submitted.routingID else {
            throw VerificationInitiationServiceError.missingRequestIdentifier
        }

        let authoritative: VerificationRequestResponseDTO = try await get(
            path: "/verification-requests/\(requestID)"
        )
        guard let authoritativeID = authoritative.routingID else {
            throw VerificationInitiationServiceError.missingRequestIdentifier
        }

        return VerificationInitiationResult(
            requestID: authoritativeID,
            status: VerifyVerificationStatus(rawBackendValue: authoritative.status),
            reusedExistingRequest: reusedExistingRequest
        )
    }

    private func createDraft(_ draft: VerificationInitiationDraft) async throws -> VerificationRequestResponseDTO {
        let contact = VerificationContactRequestDTO(
            contactName: draft.contactName.nilIfBlank,
            contactEmail: draft.contactEmail.trimmingCharacters(in: .whitespacesAndNewlines),
            contactRole: draft.contactRole.nilIfBlank,
            contactType: draft.contactType.rawValue,
            candidateNote: draft.candidateNote.nilIfBlank
        )
        let documentIDs = draft.selectedDocuments.map(\.id)

        switch draft.subject.kind {
        case .employment:
            return try await post(
                path: "/employments/\(draft.subject.id)/verification-request",
                body: EmploymentVerificationDraftRequestDTO(
                    verificationContact: contact,
                    employmentDocumentIDs: documentIDs
                )
            )
        case .education:
            return try await post(
                path: "/educations/\(draft.subject.id)/verification-request",
                body: EducationVerificationDraftRequestDTO(
                    verificationContact: contact,
                    educationDocumentIDs: documentIDs
                )
            )
        }
    }

    private func loadExistingRequest(
        for subject: VerificationInitiationSubject
    ) async throws -> VerificationRequestResponseDTO {
        switch subject.kind {
        case .employment:
            try await get(path: "/employments/\(subject.id)/verification-request")
        case .education:
            try await get(path: "/educations/\(subject.id)/verification-request")
        }
    }

    private func loadRequestList() async throws -> [VerificationRequestResponseDTO] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/verification-requests/me",
                headers: ["Accept": "application/json"]
            )
        )

        if let array = try? decoder.decode([VerificationRequestResponseDTO].self, from: data) {
            return array
        }
        return try decoder.decode(
            VerificationRequestCollectionEnvelopeDTO<VerificationRequestResponseDTO>.self,
            from: data
        ).items
    }

    private func get<Response: Decodable>(path: String) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, headers: ["Accept": "application/json"])
        )
        return try decoder.decode(Response.self, from: data)
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body
    ) async throws -> Response {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                method: .post,
                headers: [
                    "Accept": "application/json",
                    "Content-Type": "application/json"
                ],
                body: try encoder.encode(body)
            )
        )
        return try decoder.decode(Response.self, from: data)
    }

    private nonisolated static let terminalStatuses: Set<String> = [
        "verified", "rejected", "unable_to_verify", "cancelled", "expired"
    ]
}

private nonisolated struct VerificationDocumentPageDTO<Item: Decodable>: Decodable {
    let items: [Item]

    init(from decoder: Decoder) throws {
        if let array = try? decoder.singleValueContainer().decode([Item].self) {
            items = array
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decode([Item].self, forKey: .items)
    }

    private enum CodingKeys: String, CodingKey { case items }
}

private nonisolated struct EmploymentVerificationDocumentDTO: Decodable {
    let id: String
    let documentType: String
    let originalFilename: String
    let verificationStatus: String
}

private nonisolated struct EducationVerificationDocumentDTO: Decodable {
    let id: String
    let documentType: String
    let originalFilename: String
}

private nonisolated struct VerificationContactRequestDTO: Encodable {
    let contactName: String?
    let contactEmail: String
    let contactRole: String?
    let contactType: String
    let candidateNote: String?
}

private nonisolated struct EmploymentVerificationDraftRequestDTO: Encodable {
    let verificationContact: VerificationContactRequestDTO
    let employmentDocumentIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case verificationContact = "verification_contact"
        case employmentDocumentIDs = "employment_document_ids"
    }
}

private nonisolated struct EducationVerificationDraftRequestDTO: Encodable {
    let verificationContact: VerificationContactRequestDTO
    let educationDocumentIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case verificationContact = "verification_contact"
        case educationDocumentIDs = "education_document_ids"
    }
}

private nonisolated struct VerificationSubmitForReviewRequestDTO: Encodable {
    let consentedFields: [String]
    let consentedEvidenceScope: [String]
    let consentVersion: String
}

private extension String {
    nonisolated var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
