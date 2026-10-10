import Foundation

nonisolated enum CareerDocumentParent: Equatable, Sendable {
    case employment(id: String, title: String, canUpload: Bool, canDelete: Bool)
    case education(id: String, title: String)
    case certification(id: String, title: String)
    case portfolio(id: String, title: String)

    var id: String {
        switch self {
        case .employment(let id, _, _, _): "employment.\(id)"
        case .education(let id, _): "education.\(id)"
        case .certification(let id, _): "certification.\(id)"
        case .portfolio(let id, _): "portfolio.\(id)"
        }
    }

    var title: String {
        switch self {
        case .employment(_, let title, _, _), .education(_, let title), .certification(_, let title), .portfolio(_, let title): title
        }
    }

    var categoryTitle: String {
        switch self {
        case .employment: "Employment documents"
        case .education: "Education documents"
        case .certification: "Certification document"
        case .portfolio: "Portfolio attachment"
        }
    }

    var canUpload: Bool {
        switch self {
        case .employment(_, _, let canUpload, _): canUpload
        case .education: true
        case .certification: true
        case .portfolio: true
        }
    }

    var canDelete: Bool {
        switch self {
        case .employment(_, _, _, let canDelete): canDelete
        case .education: true
        case .certification: true
        case .portfolio: true
        }
    }
}

extension CareerDocumentParent {
    var isCertification: Bool {
        if case .certification = self { return true }
        return false
    }

    var isPortfolio: Bool {
        if case .portfolio = self { return true }
        return false
    }
}

nonisolated struct CareerDocumentPresentation: Identifiable, Equatable, Sendable {
    let parent: CareerDocumentParent
    var id: String { parent.id }
}

nonisolated struct CareerDocument: Identifiable, Equatable, Sendable {
    let id: String
    let documentType: String
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let verificationStatus: String
    var evidenceRole: EmploymentEvidenceRole? = nil
    var checksumSha256: String? = nil

    var canClassifyLegacyEvidence: Bool {
        evidenceRole == nil && EmploymentEvidenceEligibility.isCompleted(status: verificationStatus, checksum: checksumSha256)
    }
}

nonisolated struct CareerDocumentType: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
}

protocol CareerDocumentServiceProtocol: Sendable {
    func employmentEligibility(id: String) async throws -> EmploymentEvidenceEligibility
    func classifyEvidence(_ document: CareerDocument, parent: CareerDocumentParent, role: EmploymentEvidenceRole) async throws
    func uploadDocument(fileURL: URL, documentType: String, evidenceRole: EmploymentEvidenceRole, to parent: CareerDocumentParent) async throws -> [CareerDocument]
    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument]
    func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType]
    func uploadDocument(
        fileURL: URL,
        documentType: String,
        to parent: CareerDocumentParent
    ) async throws -> [CareerDocument]
    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL
    func protectedContent(for parent: CareerDocumentParent) async throws -> ProtectedDocumentContent
    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument]
}

extension CareerDocumentServiceProtocol {
    func employmentEligibility(id: String) async throws -> EmploymentEvidenceEligibility {
        throw CareerDocumentServiceError.uploadUnavailable
    }

    func classifyEvidence(_ document: CareerDocument, parent: CareerDocumentParent, role: EmploymentEvidenceRole) async throws {
        throw CareerDocumentServiceError.uploadUnavailable
    }

    func uploadDocument(fileURL: URL, documentType: String, evidenceRole: EmploymentEvidenceRole, to parent: CareerDocumentParent) async throws -> [CareerDocument] {
        try await uploadDocument(fileURL: fileURL, documentType: documentType, to: parent)
    }
    func protectedContent(for parent: CareerDocumentParent) async throws -> ProtectedDocumentContent {
        _ = parent
        throw CareerDocumentServiceError.protectedContentUnavailable
    }

    /// Replaces mutable evidence without risking loss of the existing file if the
    /// new upload fails. The backend remains authoritative for whether the old
    /// document is still mutable when its exact delete is attempted.
    func replaceDocument(
        _ document: CareerDocument,
        with fileURL: URL,
        documentType: String,
        evidenceRole: EmploymentEvidenceRole? = nil,
        parent: CareerDocumentParent
    ) async throws -> [CareerDocument] {
        if case .certification = parent {
            // Completion atomically swaps the attachment; never detach afterward.
            return try await uploadDocument(fileURL: fileURL, documentType: documentType, to: parent)
        }
        if case .portfolio = parent {
            return try await uploadDocument(fileURL: fileURL, documentType: documentType, to: parent)
        }
        _ = try await uploadDocument(fileURL: fileURL, documentType: documentType, evidenceRole: document.evidenceRole ?? evidenceRole ?? .primary, to: parent)
        return try await deleteDocument(document, parent: parent)
    }
}

actor CareerDocumentService: CareerDocumentServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let transferClient: SecureDocumentTransferClient
    private let decoder = APIJSONCoder.makeDecoder()
    private let encoder = APIJSONCoder.makeEncoder()

    init(
        sessionService: any SessionServiceProtocol,
        transferClient: SecureDocumentTransferClient = SecureDocumentTransferClient()
    ) {
        self.sessionService = sessionService
        self.transferClient = transferClient
    }

    nonisolated func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType] {
        switch parent {
        case .employment:
            [
                .init(id: "offer_letter", label: "Offer letter"),
                .init(id: "appointment_letter", label: "Appointment letter"),
                .init(id: "experience_letter", label: "Experience letter"),
                .init(id: "payslip", label: "Payslip"),
                .init(id: "employment_contract", label: "Employment contract"),
                .init(id: "hr_letter", label: "HR letter"),
                .init(id: "relieving_letter", label: "Relieving letter"),
                .init(id: "other", label: "Other")
            ]
        case .education:
            [
                .init(id: "degree_certificate", label: "Degree certificate"),
                .init(id: "transcript", label: "Transcript"),
                .init(id: "marksheet", label: "Marksheet"),
                .init(id: "admission_letter", label: "Admission letter"),
                .init(id: "enrollment_proof", label: "Enrollment proof"),
                .init(id: "other", label: "Other")
            ]
        case .certification:
            [.init(id: "certificate", label: "Certificate")]
        case .portfolio:
            [.init(id: "project", label: "Project attachment")]
        }
    }

    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument] {
        switch parent {
        case .employment(let id, _, _, _):
            return try await list(path: "/employments/\(id)/documents")
        case .education(let id, _):
            return try await list(path: "/educations/\(id)/documents")
        case .certification(let id, _):
            let data = try await sessionService.sendAuthenticated(
                NetworkRequest(path: "/certifications/\(id)", headers: ["Accept": "application/json"])
            )
            let certification = try decoder.decode(CareerCertificationDTO.self, from: data)
            guard let filename = certification.originalFilename, !filename.isEmpty else { return [] }
            return [
                CareerDocument(
                    id: certification.id,
                    documentType: "certificate",
                    originalFilename: filename,
                    contentType: certification.contentType ?? "application/octet-stream",
                    byteSize: certification.byteSize ?? 0,
                    verificationStatus: certification.verificationStatus
                )
            ]
        case .portfolio(let id, _):
            let data = try await sessionService.sendAuthenticated(NetworkRequest(path: "/portfolio/\(id)", headers: ["Accept": "application/json"]))
            let record = try decoder.decode(PortfolioRecord.self, from: data)
            return record.document.map { [$0] } ?? []
        }
    }

    func uploadDocument(
        fileURL: URL,
        documentType: String,
        to parent: CareerDocumentParent
    ) async throws -> [CareerDocument] {
        try await uploadDocument(fileURL: fileURL, documentType: documentType, evidenceRole: .primary, to: parent)
    }

    func employmentEligibility(id: String) async throws -> EmploymentEvidenceEligibility {
        let data = try await sessionService.sendAuthenticated(NetworkRequest(path: "/employments/\(id)/evidence-eligibility", headers: ["Accept": "application/json"]))
        return try decoder.decode(EmploymentEvidenceEligibility.self, from: data)
    }

    func classifyEvidence(_ document: CareerDocument, parent: CareerDocumentParent, role: EmploymentEvidenceRole) async throws {
        guard case .employment(let id, _, _, _) = parent else { throw CareerDocumentServiceError.uploadUnavailable }
        // The authenticated backend, not client-supplied owner IDs, authorizes this exact attachment.
        _ = try await sessionService.sendAuthenticated(NetworkRequest(
            path: "/employments/\(id)/documents/\(document.id)/evidence-role", method: .patch,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try encoder.encode(["evidence_role": role.rawValue])))
    }

    func uploadDocument(fileURL: URL, documentType: String, evidenceRole: EmploymentEvidenceRole, to parent: CareerDocumentParent) async throws -> [CareerDocument] {
        guard parent.canUpload else { throw CareerDocumentServiceError.uploadUnavailable }
        if case .certification(let id, _) = parent {
            return try await uploadCertificationDocument(fileURL: fileURL, id: id, parent: parent)
        }
        if case .portfolio(let id, _) = parent {
            return try await uploadPortfolioDocument(fileURL: fileURL, id: id, parent: parent)
        }
        let selection = try await transferClient.prepare(
            fileURL: fileURL,
            maximumBytes: 20 * 1_024 * 1_024,
            allowedContentTypes: SecureDocumentTransferClient.careerContentTypes
        )
        let intentPath: String
        let completionPath: (String) -> String

        switch parent {
        case .employment(let id, _, _, _):
            intentPath = "/employments/\(id)/documents/upload-intent"
            completionPath = { "/employments/\(id)/documents/\($0)/complete-upload" }
        case .education(let id, _):
            intentPath = "/educations/\(id)/documents/upload-intent"
            completionPath = { "/educations/\(id)/documents/\($0)/complete-upload" }
        case .certification, .portfolio:
            throw CareerDocumentServiceError.uploadUnavailable
        }

        let intentData = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: intentPath,
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(
                    CareerDocumentUploadIntentRequestDTO(
                        documentType: documentType,
                        originalFilename: selection.filename,
                        contentType: selection.contentType,
                        byteSize: selection.data.count,
                        evidenceRole: { if case .employment = parent { return evidenceRole }; return nil }()
                    )
                )
            )
        )
        let intent = try decoder.decode(CareerDocumentUploadIntentResponseDTO.self, from: intentData)
        do {
            try await transferClient.upload(
                selection,
                to: intent.uploadUrl,
                requiredHeaders: intent.headersRequired
            )
        } catch {
            try? await discardIncompleteUpload(documentID: intent.documentId, parent: parent)
            throw error
        }

        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: completionPath(intent.documentId),
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(
                    CareerDocumentCompleteRequestDTO(checksumSHA256: selection.checksumSHA256)
                )
            )
        )
        return try await listDocuments(for: parent)
    }

    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL {
        let path: String
        switch parent {
        case .employment(let id, _, _, _):
            path = "/employments/\(id)/documents/\(document.id)/download-url"
        case .education(let id, _):
            path = "/educations/\(id)/documents/\(document.id)/download-url"
        case .certification(let id, _):
            path = "/certifications/\(id)/download-url"
        case .portfolio:
            // Portfolio content is fetched only through the authenticated
            // protected-content transport; never hand a signed URL to UI code.
            throw CareerDocumentServiceError.protectedContentUnavailable
        }
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, headers: ["Accept": "application/json"])
        )
        let response = try decoder.decode(CareerDocumentDownloadResponseDTO.self, from: data)
        return try SecureDocumentTransferClient.validatedDownloadURL(response.downloadUrl)
    }

    func protectedContent(for parent: CareerDocumentParent) async throws -> ProtectedDocumentContent {
        guard case .portfolio(let id, _) = parent else {
            throw CareerDocumentServiceError.protectedContentUnavailable
        }
        let response = try await sessionService.sendAuthenticatedResponse(
            NetworkRequest(
                path: "/portfolio/\(id)/content",
                headers: ["Accept": "application/pdf, image/jpeg, image/png"],
                requiresProtectedDocumentTransport: true
            )
        )
        return try ProtectedDocumentContent(response: response)
    }

    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument] {
        guard parent.canDelete else { throw CareerDocumentServiceError.deleteUnavailable }
        let path: String
        switch parent {
        case .employment(let id, _, _, _):
            path = "/employments/\(id)/documents/\(document.id)"
        case .education(let id, _):
            path = "/educations/\(id)/documents/\(document.id)"
        case .certification(let id, _):
            path = "/certifications/\(id)/document"
        case .portfolio(let id, _):
            path = "/portfolio/\(id)/document"
        }
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, method: .delete, headers: ["Accept": "application/json"])
        )
        return try await listDocuments(for: parent)
    }

    private func list(path: String) async throws -> [CareerDocument] {
        try await loadOwnerCollection(CareerDocumentDTO.self, path: path, session: sessionService).map(\.domain)
    }

    private func uploadPortfolioDocument(fileURL: URL, id: String, parent: CareerDocumentParent) async throws -> [CareerDocument] {
        let selection = try await transferClient.prepare(fileURL: fileURL, maximumBytes: 50 * 1_024 * 1_024, allowedContentTypes: SecureDocumentTransferClient.careerContentTypes)
        let data = try await sessionService.sendAuthenticated(NetworkRequest(path: "/portfolio/\(id)/upload-intent", method: .post,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try encoder.encode(PortfolioUploadIntentDTO(originalFilename: selection.filename, contentType: selection.contentType, byteSize: selection.data.count))))
        let intent = try decoder.decode(PortfolioUploadIntentResponseDTO.self, from: data)
        try await transferClient.upload(selection, to: intent.uploadUrl, requiredHeaders: intent.headersRequired)
        _ = try await sessionService.sendAuthenticated(NetworkRequest(path: "/portfolio/\(id)/complete-upload", method: .post,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try encoder.encode(CareerDocumentCompleteRequestDTO(checksumSHA256: selection.checksumSHA256))))
        return try await listDocuments(for: parent)
    }

    private func uploadCertificationDocument(fileURL: URL, id: String, parent: CareerDocumentParent) async throws -> [CareerDocument] {
        let selection = try await transferClient.prepare(fileURL: fileURL, maximumBytes: 50 * 1_024 * 1_024, allowedContentTypes: SecureDocumentTransferClient.careerContentTypes)
        let data = try await sessionService.sendAuthenticated(NetworkRequest(
            path: "/certifications/\(id)/document/upload-intent", method: .post,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try encoder.encode(CertificationDocumentIntentDTO(originalFilename: selection.filename, contentType: selection.contentType, byteSize: selection.data.count, checksumSha256: selection.checksumSHA256))
        ))
        let intent = try decoder.decode(CertificationDocumentIntentResponseDTO.self, from: data)
        // The one-use token stays in memory. Incomplete intents expire server-side.
        try await transferClient.upload(selection, to: intent.uploadUrl, requiredHeaders: intent.headersRequired)
        _ = try await sessionService.sendAuthenticated(NetworkRequest(
            path: "/certifications/\(id)/document/complete-upload", method: .post,
            headers: ["Accept": "application/json", "Content-Type": "application/json"],
            body: try encoder.encode(CertificationDocumentCompletionDTO(uploadToken: intent.uploadToken, checksumSha256: selection.checksumSHA256))
        ))
        return try await listDocuments(for: parent)
    }

    private func discardIncompleteUpload(documentID: String, parent: CareerDocumentParent) async throws {
        let path: String
        switch parent {
        case .employment(let id, _, _, _):
            path = "/employments/\(id)/documents/\(documentID)"
        case .education(let id, _):
            path = "/educations/\(id)/documents/\(documentID)"
        case .certification, .portfolio:
            return
        }
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, method: .delete, headers: ["Accept": "application/json"])
        )
    }

}

private nonisolated struct PortfolioUploadIntentDTO: Encodable {
    let originalFilename: String
    let contentType: String
    let byteSize: Int
}
private nonisolated struct PortfolioUploadIntentResponseDTO: Decodable {
    let uploadUrl: URL
    let headersRequired: [String: String]
}

actor DemoCareerDocumentService: CareerDocumentServiceProtocol {
    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument] {
        [
            CareerDocument(
                id: "demo-document",
                documentType: parent.categoryTitle,
                originalFilename: "demo-evidence.pdf",
                contentType: "application/pdf",
                byteSize: 128_000,
                verificationStatus: "pending_review"
            )
        ]
    }

    nonisolated func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType] {
        _ = parent
        return [.init(id: "other", label: "Other")]
    }

    func uploadDocument(fileURL: URL, documentType: String, to parent: CareerDocumentParent) async throws -> [CareerDocument] {
        _ = (fileURL, documentType, parent)
        throw NetworkError.unavailableInDemoMode
    }

    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL {
        _ = (document, parent)
        throw NetworkError.unavailableInDemoMode
    }

    func protectedContent(for parent: CareerDocumentParent) async throws -> ProtectedDocumentContent {
        _ = parent
        throw NetworkError.unavailableInDemoMode
    }

    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument] {
        _ = (document, parent)
        throw NetworkError.unavailableInDemoMode
    }
}

nonisolated enum CareerDocumentServiceError: Error, LocalizedError, Equatable {
    case emptyFile
    case fileTooLarge
    case unsupportedFileType
    case invalidUploadURL
    case storageUploadFailed
    case invalidDownloadURL
    case uploadUnavailable
    case deleteUnavailable
    case protectedContentUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyFile: "Choose a non-empty file."
        case .fileTooLarge: "Choose a file no larger than 20 MB."
        case .unsupportedFileType: "Choose a PDF, JPEG, or PNG file."
        case .invalidUploadURL: "KairoID received an invalid secure upload destination."
        case .storageUploadFailed: "The secure document upload did not complete. Try again."
        case .invalidDownloadURL: "KairoID received an invalid secure document destination."
        case .uploadUnavailable: "This record does not support adding a document in its current state."
        case .deleteUnavailable: "This document cannot be removed in its current state."
        case .protectedContentUnavailable: "This document is not available through the protected viewer."
        }
    }
}

private nonisolated struct CareerDocumentPageDTO: Decodable {
    let items: [CareerDocumentDTO]
}

private nonisolated struct CareerDocumentDTO: Decodable {
    let id: String
    let documentType: String
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let verificationStatus: String
    let evidenceRole: EmploymentEvidenceRole?
    let checksumSha256: String?

    var domain: CareerDocument {
        CareerDocument(
            id: id,
            documentType: documentType,
            originalFilename: originalFilename,
            contentType: contentType,
            byteSize: byteSize,
            verificationStatus: verificationStatus,
            evidenceRole: evidenceRole,
            checksumSha256: checksumSha256
        )
    }
}

private nonisolated struct CareerDocumentUploadIntentRequestDTO: Encodable {
    let documentType: String
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let evidenceRole: EmploymentEvidenceRole?
}

private nonisolated struct CareerDocumentUploadIntentResponseDTO: Decodable {
    let documentId: String
    let uploadUrl: URL
    let headersRequired: [String: String]
}

private nonisolated struct CareerDocumentCompleteRequestDTO: Encodable {
    let checksumSHA256: String
}

private nonisolated struct CareerDocumentDownloadResponseDTO: Decodable {
    let downloadUrl: URL
}

private nonisolated struct CertificationDocumentIntentDTO: Encodable {
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let checksumSha256: String
}

private nonisolated struct CertificationDocumentIntentResponseDTO: Decodable {
    let uploadUrl: URL
    let uploadToken: String
    let headersRequired: [String: String]
}

private nonisolated struct CertificationDocumentCompletionDTO: Encodable {
    let uploadToken: String
    let checksumSha256: String
}
