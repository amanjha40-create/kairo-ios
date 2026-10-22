import Foundation

/// Server values are open-ended; upload choices are deliberately closed.
nonisolated struct VaultDocumentType: RawRepresentable, Hashable, Identifiable, Sendable {
    let rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    static let aadhaar = Self(rawValue: "aadhaar")
    static let pan = Self(rawValue: "pan")
    static let passport = Self(rawValue: "passport")
    static let drivingLicense = Self(rawValue: "driving_license")
    static let voterID = Self(rawValue: "voter_id")
    static let birthCertificate = Self(rawValue: "birth_certificate")
    static let addressProof = Self(rawValue: "address_proof")
    static let governmentID = Self(rawValue: "government_id")
    static let other = Self(rawValue: "other")
    static let newUploadTypes: [Self] = [
        .aadhaar, .pan, .passport, .drivingLicense, .voterID, .birthCertificate, .addressProof
    ]
    var allowsNewUpload: Bool { Self.newUploadTypes.contains(self) }
    var allowsDocumentNumber: Bool { self != .aadhaar }

    func metadataFilename(_ filename: String, contentType: String) -> String {
        guard self == .aadhaar else { return filename }
        let suffix: String
        switch contentType {
        case "application/pdf": suffix = ".pdf"
        case "image/jpeg": suffix = ".jpg"
        case "image/png": suffix = ".png"
        case "image/webp": suffix = ".webp"
        default: suffix = ""
        }
        return "Aadhaar document" + suffix
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aadhaar: "Aadhaar"
        case .pan: "PAN"
        case .drivingLicense: "Driving Licence"
        case .passport: "Passport"
        case .voterID: "Voter ID"
        case .governmentID: "Government ID"
        case .other: "Other"
        case .birthCertificate: "Birth Certificate"
        case .addressProof: "Address Proof"
        default: "Identity document"
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
    func content(documentID: String) async throws -> ProtectedDocumentContent
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
        var result: [VaultDocument] = []
        while true {
            try Task.checkCancellation()
            // Mixed owner collections may contain Aadhaar, including replaced versions.
            let data = try await sessionService.sendAuthenticated(NetworkRequest(
                path: "/user-documents",
                headers: ["Accept": "application/json", "Cache-Control": "no-store"],
                queryItems: [.init(name: "offset", value: String(result.count)), .init(name: "limit", value: "100")],
                requiresPrivateJSONTransport: true
            ))
            if let array = try? decoder.decode([VaultDocumentDTO].self, from: data) {
                return array.map(\.domain)
            }
            let page = try decoder.decode(VaultDocumentPageDTO.self, from: data)
            result.append(contentsOf: page.items.map(\.domain))
            if page.items.isEmpty || result.count >= (page.total ?? result.count) { return result }
        }
    }

    func uploadDocument(
        fileURL: URL,
        type: VaultDocumentType,
        documentNumber: String?,
        expiresAt: Date?,
        replacing documentID: String?
    ) async throws -> [VaultDocument] {
        guard documentID != nil || type.allowsNewUpload else {
            throw SecureDocumentTransferError.unsupportedFileType
        }
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
                        originalFilename: type.metadataFilename(selection.filename, contentType: selection.contentType),
                        contentType: selection.contentType,
                        byteSize: selection.data.count,
                        documentNumber: type.allowsDocumentNumber ? Self.normalized(documentNumber) : nil,
                        expiresAt: expiresAt.map(Self.dateString),
                        replacesDocumentId: documentID
                    )
                ),
                requiresPrivateJSONTransport: type == .aadhaar
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
                ),
                requiresPrivateJSONTransport: type == .aadhaar
            )
        )
        return try await listDocuments()
    }

    func updateMetadata(
        documentID: String,
        documentNumber: String?,
        expiresAt: Date?
    ) async throws -> [VaultDocument] {
        guard let document = try await listDocuments().first(where: { $0.id == documentID }) else {
            throw NetworkError.invalidResponse
        }
        _ = try await sessionService.sendAuthenticated(
            NetworkRequest(
                path: "/user-documents/\(documentID)",
                method: .patch,
                headers: ["Accept": "application/json", "Content-Type": "application/json"],
                body: try encoder.encode(
                    VaultUpdateRequestDTO(
                        documentNumber: document.documentType.allowsDocumentNumber
                            ? .between(document.documentNumber, Self.normalized(documentNumber)) : .unchanged,
                        expiresAt: .between(document.expiresAt.map(Self.dateString), expiresAt.map(Self.dateString))
                    )
                ),
                requiresPrivateJSONTransport: document.documentType == .aadhaar
            )
        )
        return try await listDocuments()
    }

    func content(documentID: String) async throws -> ProtectedDocumentContent {
        let response = try await sessionService.sendAuthenticatedResponse(
            NetworkRequest(
                path: "/user-documents/\(documentID)/content",
                headers: ["Accept": "application/pdf, image/jpeg, image/png, image/webp"],
                requiresProtectedDocumentTransport: true
            )
        )
        return try ProtectedDocumentContent(response: response)
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

    func content(documentID: String) async throws -> ProtectedDocumentContent {
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
    let total: Int?
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

    private enum CodingKeys: String, CodingKey {
        case id, documentType, documentNumber, originalFilename, contentType, byteSize
        case verificationStatus, verifiedAt, reviewerNote, expiresAt, supersededAt
        case supersededById, replacesDocumentId, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        documentType = try values.decode(String.self, forKey: .documentType)
        contentType = try values.decode(String.self, forKey: .contentType)
        let type = VaultDocumentType(rawValue: documentType)
        if type == .aadhaar {
            // Do not decode private metadata, even if a legacy response still sends it.
            documentNumber = nil
            reviewerNote = nil
            originalFilename = type.metadataFilename("", contentType: contentType)
        } else {
            documentNumber = try values.decodeIfPresent(String.self, forKey: .documentNumber)
            reviewerNote = try values.decodeIfPresent(String.self, forKey: .reviewerNote)
            originalFilename = try values.decode(String.self, forKey: .originalFilename)
        }
        byteSize = try values.decode(Int.self, forKey: .byteSize)
        verificationStatus = try values.decode(String.self, forKey: .verificationStatus)
        verifiedAt = try values.decodeIfPresent(Date.self, forKey: .verifiedAt)
        expiresAt = try values.decodeIfPresent(Date.self, forKey: .expiresAt)
        supersededAt = try values.decodeIfPresent(Date.self, forKey: .supersededAt)
        supersededById = try values.decodeIfPresent(String.self, forKey: .supersededById)
        replacesDocumentId = try values.decodeIfPresent(String.self, forKey: .replacesDocumentId)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        updatedAt = try values.decode(Date.self, forKey: .updatedAt)
    }

    var domain: VaultDocument {
        VaultDocument(
            id: id,
            documentType: VaultDocumentType(rawValue: documentType),
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
    let documentNumber: OptionalFieldChange<String>
    let expiresAt: OptionalFieldChange<String>

    private enum CodingKeys: String, CodingKey { case documentNumber, expiresAt }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeChange(documentNumber, forKey: .documentNumber)
        try values.encodeChange(expiresAt, forKey: .expiresAt)
    }
}
