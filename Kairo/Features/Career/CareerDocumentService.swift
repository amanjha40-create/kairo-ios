import CryptoKit
import Foundation
import UniformTypeIdentifiers

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

actor CareerDocumentService: CareerDocumentServiceProtocol {
    private let sessionService: any SessionServiceProtocol
    private let storageSession: URLSession
    private let decoder = APIJSONCoder.makeDecoder()
    private let encoder = APIJSONCoder.makeEncoder()

    init(
        sessionService: any SessionServiceProtocol,
        storageSession: URLSession = CareerDocumentService.defaultStorageSession()
    ) {
        self.sessionService = sessionService
        self.storageSession = storageSession
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
        let selection = try readSelection(fileURL)
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
            try await upload(selection.data, contentType: selection.contentType, intent: intent)
        } catch {
            try? await discardIncompleteUpload(documentID: intent.documentId, parent: parent)
            throw error
        }

        let digest = SHA256.hash(data: selection.data).map { String(format: "%02x", $0) }.joined()
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: completionPath(intent.documentId),
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(CareerDocumentCompleteRequestDTO(checksumSHA256: digest))
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
        guard response.downloadUrl.scheme?.lowercased() == "https" else {
            throw CareerDocumentServiceError.invalidDownloadURL
        }
        return response.downloadUrl
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

    private func readSelection(_ url: URL) throws -> (filename: String, contentType: String, data: Data) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard !data.isEmpty else { throw CareerDocumentServiceError.emptyFile }
        guard data.count <= 20 * 1_024 * 1_024 else { throw CareerDocumentServiceError.fileTooLarge }

        let contentType = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType)
            ?? mimeType(for: url.pathExtension)
        guard ["application/pdf", "image/jpeg", "image/png"].contains(contentType) else {
            throw CareerDocumentServiceError.unsupportedFileType
        }
        return (url.lastPathComponent, contentType, data)
    }

    private func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "pdf": "application/pdf"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        default: "application/octet-stream"
        }
    }

    private func upload(
        _ data: Data,
        contentType: String,
        intent: CareerDocumentUploadIntentResponseDTO
    ) async throws {
        guard intent.uploadUrl.scheme?.lowercased() == "https" else {
            throw CareerDocumentServiceError.invalidUploadURL
        }
        var request = URLRequest(url: intent.uploadUrl)
        request.httpMethod = "PUT"
        for (header, value) in intent.headersRequired { request.setValue(value, forHTTPHeaderField: header) }
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        let (_, response) = try await storageSession.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200 ..< 300).contains(http.statusCode) else {
            throw CareerDocumentServiceError.storageUploadFailed
        }
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

    nonisolated private static func defaultStorageSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        return URLSession(configuration: configuration)
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
        case .invalidUploadURL: "Kairo received an invalid secure upload destination."
        case .storageUploadFailed: "The secure document upload did not complete. Try again."
        case .invalidDownloadURL: "Kairo received an invalid secure document destination."
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
