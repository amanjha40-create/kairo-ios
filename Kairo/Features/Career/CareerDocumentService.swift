import Foundation

nonisolated enum CareerDocumentParent: Equatable, Sendable {
    case employment(id: String, title: String, canUpload: Bool, canDelete: Bool)
    case education(id: String, title: String)
    case certification(id: String, title: String)

    var id: String {
        switch self {
        case .employment(let id, _, _, _): "employment.\(id)"
        case .education(let id, _): "education.\(id)"
        case .certification(let id, _): "certification.\(id)"
        }
    }

    var title: String {
        switch self {
        case .employment(_, let title, _, _), .education(_, let title), .certification(_, let title): title
        }
    }

    var categoryTitle: String {
        switch self {
        case .employment: "Employment documents"
        case .education: "Education documents"
        case .certification: "Certification document"
        }
    }

    var canUpload: Bool {
        switch self {
        case .employment(_, _, let canUpload, _): canUpload
        case .education: true
        case .certification: false
        }
    }

    var canDelete: Bool {
        switch self {
        case .employment(_, _, _, let canDelete): canDelete
        case .education: true
        case .certification: false
        }
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
}

nonisolated struct CareerDocumentType: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
}

protocol CareerDocumentServiceProtocol: Sendable {
    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument]
    func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType]
    func uploadDocument(
        fileURL: URL,
        documentType: String,
        to parent: CareerDocumentParent
    ) async throws -> [CareerDocument]
    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL
    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument]
}

extension CareerDocumentServiceProtocol {
    /// Replaces mutable evidence without risking loss of the existing file if the
    /// new upload fails. The backend remains authoritative for whether the old
    /// document is still mutable when its exact delete is attempted.
    func replaceDocument(
        _ document: CareerDocument,
        with fileURL: URL,
        documentType: String,
        parent: CareerDocumentParent
    ) async throws -> [CareerDocument] {
        _ = try await uploadDocument(fileURL: fileURL, documentType: documentType, to: parent)
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
            []
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
        }
    }

    func uploadDocument(
        fileURL: URL,
        documentType: String,
        to parent: CareerDocumentParent
    ) async throws -> [CareerDocument] {
        guard parent.canUpload else { throw CareerDocumentServiceError.uploadUnavailable }
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
        case .certification:
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
                        byteSize: selection.data.count
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
        }
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, headers: ["Accept": "application/json"])
        )
        let response = try decoder.decode(CareerDocumentDownloadResponseDTO.self, from: data)
        return try SecureDocumentTransferClient.validatedDownloadURL(response.downloadUrl)
    }

    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument] {
        guard parent.canDelete else { throw CareerDocumentServiceError.deleteUnavailable }
        let path: String
        switch parent {
        case .employment(let id, _, _, _):
            path = "/employments/\(id)/documents/\(document.id)"
        case .education(let id, _):
            path = "/educations/\(id)/documents/\(document.id)"
        case .certification:
            throw CareerDocumentServiceError.deleteUnavailable
        }
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, method: .delete, headers: ["Accept": "application/json"])
        )
        return try await listDocuments(for: parent)
    }

    private func list(path: String) async throws -> [CareerDocument] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: path,
                headers: ["Accept": "application/json"],
                queryItems: [URLQueryItem(name: "limit", value: "100")]
            )
        )
        let page = try decoder.decode(CareerDocumentPageDTO.self, from: data)
        return page.items.map(\.domain)
    }

    private func discardIncompleteUpload(documentID: String, parent: CareerDocumentParent) async throws {
        let path: String
        switch parent {
        case .employment(let id, _, _, _):
            path = "/employments/\(id)/documents/\(documentID)"
        case .education(let id, _):
            path = "/educations/\(id)/documents/\(documentID)"
        case .certification:
            return
        }
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(path: path, method: .delete, headers: ["Accept": "application/json"])
        )
    }

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

    var domain: CareerDocument {
        CareerDocument(
            id: id,
            documentType: documentType,
            originalFilename: originalFilename,
            contentType: contentType,
            byteSize: byteSize,
            verificationStatus: verificationStatus
        )
    }
}

private nonisolated struct CareerDocumentUploadIntentRequestDTO: Encodable {
    let documentType: String
    let originalFilename: String
    let contentType: String
    let byteSize: Int
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
