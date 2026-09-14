import Foundation

nonisolated enum VaultDocumentType: String, CaseIterable, Identifiable, Sendable {
    case aadhaar
    case pan
    case drivingLicense = "driving_license"
    case passport
    case voterID = "voter_id"
    case governmentID = "government_id"
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aadhaar: "Aadhaar"
        case .pan: "PAN"
        case .drivingLicense: "Driving licence"
        case .passport: "Passport"
        case .voterID: "Voter ID"
        case .governmentID: "Government ID"
        case .other: "Other"
        }
    }
}

nonisolated struct VaultDocument: Identifiable, Equatable, Sendable {
    let id: String
    let documentType: VaultDocumentType
    let documentNumber: String?
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let verificationStatus: String
    let verifiedAt: Date?
    let reviewerNote: String?
    let expiresAt: Date?
    let supersededAt: Date?
    let supersededByID: String?
    let replacesDocumentID: String?
    let createdAt: Date
    let updatedAt: Date

    var isCurrent: Bool { supersededAt == nil }
}

protocol DocumentVaultServiceProtocol: Sendable {
    func listDocuments() async throws -> [VaultDocument]
    func uploadDocument(
        fileURL: URL,
        type: VaultDocumentType,
        documentNumber: String?,
        expiresAt: Date?,
        replacing documentID: String?
    ) async throws -> [VaultDocument]
    func updateMetadata(documentID: String, documentNumber: String?, expiresAt: Date?) async throws -> [VaultDocument]
    func downloadURL(documentID: String) async throws -> URL
    func deleteDocument(documentID: String) async throws -> [VaultDocument]
}

actor DocumentVaultService: DocumentVaultServiceProtocol {
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

    func listDocuments() async throws -> [VaultDocument] {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents",
                headers: ["Accept": "application/json"],
                queryItems: [URLQueryItem(name: "limit", value: "100")]
            )
        )
        return try decoder.decode(VaultDocumentPageDTO.self, from: data).items.map(\.domain)
    }

    func uploadDocument(
        fileURL: URL,
        type: VaultDocumentType,
        documentNumber: String?,
        expiresAt: Date?,
        replacing documentID: String?
    ) async throws -> [VaultDocument] {
        let selection = try await transferClient.prepare(
            fileURL: fileURL,
            maximumBytes: 50 * 1_024 * 1_024,
            allowedContentTypes: SecureDocumentTransferClient.vaultContentTypes
        )
        let intentData = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/upload-intent",
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(
                    VaultUploadIntentRequestDTO(
                        documentType: type.rawValue,
                        originalFilename: selection.filename,
                        contentType: selection.contentType,
                        byteSize: selection.data.count,
                        documentNumber: Self.normalized(documentNumber),
                        expiresAt: expiresAt.map(Self.dateString),
                        replacesDocumentId: documentID
                    )
                )
            )
        )
        let intent = try decoder.decode(VaultUploadIntentResponseDTO.self, from: intentData)

        do {
            try await transferClient.upload(
                selection,
                to: intent.uploadUrl,
                requiredHeaders: intent.headersRequired
            )
        } catch {
            try? await discardIncompleteUpload(documentID: intent.documentId)
            throw error
        }

        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/\(intent.documentId)/complete-upload",
                method: .post,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(
                    VaultCompleteUploadRequestDTO(checksumSHA256: selection.checksumSHA256)
                )
            )
        )
        return try await listDocuments()
    }

    func updateMetadata(
        documentID: String,
        documentNumber: String?,
        expiresAt: Date?
    ) async throws -> [VaultDocument] {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/\(documentID)",
                method: .patch,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(
                    VaultUpdateRequestDTO(
                        documentNumber: Self.normalized(documentNumber),
                        expiresAt: expiresAt.map(Self.dateString)
                    )
                )
            )
        )
        return try await listDocuments()
    }

    func downloadURL(documentID: String) async throws -> URL {
        let data = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/\(documentID)/download-url",
                headers: ["Accept": "application/json"]
            )
        )
        let response = try decoder.decode(VaultDownloadResponseDTO.self, from: data)
        return try SecureDocumentTransferClient.validatedDownloadURL(response.downloadUrl)
    }

    func deleteDocument(documentID: String) async throws -> [VaultDocument] {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/\(documentID)",
                method: .delete,
                headers: ["Accept": "application/json"]
            )
        )
        return try await listDocuments()
    }

    private func discardIncompleteUpload(documentID: String) async throws {
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/\(documentID)",
                method: .delete,
                headers: ["Accept": "application/json"]
            )
        )
    }

    private nonisolated static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private nonisolated static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

actor DemoDocumentVaultService: DocumentVaultServiceProtocol {
    func listDocuments() async throws -> [VaultDocument] { [] }

    func uploadDocument(
        fileURL: URL,
        type: VaultDocumentType,
        documentNumber: String?,
        expiresAt: Date?,
        replacing documentID: String?
    ) async throws -> [VaultDocument] {
        _ = (fileURL, type, documentNumber, expiresAt, documentID)
        throw NetworkError.unavailableInDemoMode
    }

    func updateMetadata(documentID: String, documentNumber: String?, expiresAt: Date?) async throws -> [VaultDocument] {
        _ = (documentID, documentNumber, expiresAt)
        throw NetworkError.unavailableInDemoMode
    }

    func downloadURL(documentID: String) async throws -> URL {
        _ = documentID
        throw NetworkError.unavailableInDemoMode
    }

    func deleteDocument(documentID: String) async throws -> [VaultDocument] {
        _ = documentID
        throw NetworkError.unavailableInDemoMode
    }
}

private nonisolated struct VaultDocumentPageDTO: Decodable {
    let items: [VaultDocumentDTO]
}

private nonisolated struct VaultDocumentDTO: Decodable {
    let id: String
    let documentType: String
    let documentNumber: String?
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let verificationStatus: String
    let verifiedAt: Date?
    let reviewerNote: String?
    let expiresAt: Date?
    let supersededAt: Date?
    let supersededById: String?
    let replacesDocumentId: String?
    let createdAt: Date
    let updatedAt: Date

    var domain: VaultDocument {
        VaultDocument(
            id: id,
            documentType: VaultDocumentType(rawValue: documentType) ?? .other,
            documentNumber: documentNumber,
            originalFilename: originalFilename,
            contentType: contentType,
            byteSize: byteSize,
            verificationStatus: verificationStatus,
            verifiedAt: verifiedAt,
            reviewerNote: reviewerNote,
            expiresAt: expiresAt,
            supersededAt: supersededAt,
            supersededByID: supersededById,
            replacesDocumentID: replacesDocumentId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private nonisolated struct VaultUploadIntentRequestDTO: Encodable {
    let documentType: String
    let originalFilename: String
    let contentType: String
    let byteSize: Int
    let documentNumber: String?
    let expiresAt: String?
    let replacesDocumentId: String?
}

private nonisolated struct VaultUploadIntentResponseDTO: Decodable {
    let documentId: String
    let uploadUrl: URL
    let headersRequired: [String: String]
}

private nonisolated struct VaultCompleteUploadRequestDTO: Encodable {
    let checksumSHA256: String
}

private nonisolated struct VaultUpdateRequestDTO: Encodable {
    let documentNumber: String?
    let expiresAt: String?
}

private nonisolated struct VaultDownloadResponseDTO: Decodable {
    let downloadUrl: URL
}
