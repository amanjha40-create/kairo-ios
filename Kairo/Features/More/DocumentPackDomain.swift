import Foundation

/// Contract constants from backend 62e1ab0: no capabilities endpoint is exposed.
nonisolated enum DocumentPackLimits {
    static let maximumFiles = 20
    static let maximumBytes = 200 * 1_024 * 1_024
    static let maximumPurposeLength = 120
    static let expiryDays = [1, 3, 7, 14, 30]
    static let defaultExpiryDays = 7
    static func validPurpose(_ value: String) -> Bool {
        (1...maximumPurposeLength).contains(value.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count)
    }
}

nonisolated struct DocumentPackSelection: Codable, Equatable, Hashable, Sendable {
    let sourceType: String
    let sourceId: String
    let selectionVersion: String
    var key: String { "\(sourceType):\(sourceId)" }
}

nonisolated struct PackSelectableDocument: Decodable, Equatable, Identifiable, Sendable {
    let sourceType: String
    let sourceId: String
    let selectionVersion: String
    let category: String
    let title: String
    let context: String?
    let filename: String
    let contentType: String
    let byteSize: Int
    var selection: DocumentPackSelection { .init(sourceType: sourceType, sourceId: sourceId, selectionVersion: selectionVersion) }
    var id: String { selection.key }
    var categoryTitle: String { DocumentPackCategory.title(category) }
}

nonisolated enum DocumentPackCategory {
    static func title(_ raw: String) -> String {
        switch raw {
        case "identity": "Identity & Personal"
        case "employment": "Employment"
        case "education": "Education"
        case "certifications": "Certifications"
        case "projects": "Projects / Portfolio"
        default: "Other documents"
        }
    }
}

/// Snapshot metadata only. No owner/profile, source identity, or object-storage field.
nonisolated struct DocumentPackItem: Decodable, Equatable, Identifiable, Sendable {
    let publicId: String
    let category: String
    let title: String
    let context: String?
    let filename: String
    let contentType: String
    let byteSize: Int
    var id: String { publicId }
}

nonisolated struct PublicDocumentPack: Decodable, Equatable, Sendable {
    let purpose: String
    let expiresAt: Date
    let documentCount: Int
    let items: [DocumentPackItem]
}

nonisolated struct DocumentPack: Decodable, Equatable, Identifiable, Sendable {
    let publicId: String
    let purpose: String
    let expiresAt: Date
    let documentCount: Int
    let items: [DocumentPackItem]
    let createdAt: Date
    let revokedAt: Date?
    let status: String
    let viewCount: Int
    let lastViewedAt: Date?
    var id: String { publicId }
    var isActive: Bool { status == "active" && revokedAt == nil && expiresAt > Date() }
    var statusTitle: String {
        if revokedAt != nil || status == "revoked" { return "Revoked" }
        if status == "expired" || expiresAt <= Date() { return "Expired" }
        return status == "active" ? "Active" : "Unavailable"
    }
}

nonisolated struct DocumentPackCreate: Encodable, Equatable, Sendable {
    let purpose: String
    let expiryDays: Int
    let items: [DocumentPackSelection]

    init(purpose: String, expiryDays: Int, documents: [PackSelectableDocument]) throws {
        guard DocumentPackLimits.validPurpose(purpose) else { throw DocumentPackError.invalidPurpose }
        guard DocumentPackLimits.expiryDays.contains(expiryDays) else { throw DocumentPackError.invalidExpiry }
        guard !documents.isEmpty, documents.count <= DocumentPackLimits.maximumFiles,
              Set(documents.map(\.id)).count == documents.count else { throw DocumentPackError.invalidSelection }
        var size = 0
        for document in documents {
            guard document.byteSize > 0, document.byteSize <= DocumentPackLimits.maximumBytes - size else { throw DocumentPackError.limit }
            size += document.byteSize
        }
        self.purpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        self.expiryDays = expiryDays
        items = documents.map(\.selection)
    }
}

nonisolated enum DocumentPackError: Error, Equatable, LocalizedError, Sendable {
    case invalidPurpose, invalidExpiry, invalidSelection, limit, rejected, unauthorized, unavailable, connection, ambiguousCreation
    var errorDescription: String? {
        switch self {
        case .invalidPurpose: "Enter a purpose of 1–120 characters, excluding surrounding whitespace."
        case .invalidExpiry: "Choose a supported expiry."
        case .invalidSelection: "Select 1–20 distinct eligible documents."
        case .limit: "Select up to 20 files totaling no more than 200 MB."
        case .rejected: "The server rejected this selection. A file may have changed or a limit was reached. Refresh and select again."
        case .unauthorized: "Your session or permission could not be confirmed. Sign in again if needed."
        case .unavailable: "This document pack or selected file is unavailable. It may have expired, been revoked, or changed."
        case .connection: "Document packs could not be loaded. Check your connection and try again."
        case .ambiguousCreation: "Link creation could not be confirmed. Do not create again: check Shared document packs first. A successful link cannot be recovered from history."
        }
    }
    static func map(_ error: Error, creating: Bool = false) -> Self {
        if let value = error as? Self { return value }
        if error is SessionServiceError { return .unauthorized }
        if case NetworkError.api(let api) = error {
            switch api.statusCode {
            case 401, 403: return .unauthorized
            case 404: return .unavailable
            case 400, 409, 422, 429: return .rejected
            default: break
            }
        }
        return creating ? .ambiguousCreation : .connection
    }
}

/// Memory-only capability; all four owner actions use this exact server URL.
nonisolated struct DocumentPackCapability: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let url: URL
    var description: String { "DocumentPackCapability(<redacted>)" }
    var debugDescription: String { description }
    var token: String { String(url.fragment!.dropFirst("token=".count)) }

    init(serverURL: String, allowedHosts: Set<String>) throws {
        guard let url = URL(string: serverURL), url.absoluteString == serverURL,
              url.scheme == "https", let host = url.host, allowedHosts.contains(host.lowercased()),
              url.user == nil, url.password == nil, url.port == nil, url.query == nil,
              url.path == "/document-pack", let fragment = url.fragment,
              fragment.range(of: "^token=[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil else {
            throw DocumentPackError.ambiguousCreation
        }
        self.url = url
    }
    var copyURL: URL { url }
    var qrURL: URL { url }
    var shareURL: URL { url }
    var previewURL: URL { url }
}

nonisolated struct DocumentPackCreation: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let pack: DocumentPack
    let capability: DocumentPackCapability
    var description: String { "DocumentPackCreation(capability: <redacted>)" }
    var debugDescription: String { description }
}

nonisolated struct DocumentPackPage<T: Decodable & Sendable>: Decodable, Sendable {
    let items: [T]
    let total: Int
    let totalPages: Int
}

nonisolated struct DocumentPackCreatedDTO: Decodable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let pack: DocumentPack
    let shareUrl: String
    var description: String { "DocumentPackCreatedDTO(shareURL: <redacted>)" }
    var debugDescription: String { description }
    init(from decoder: Decoder) throws {
        pack = try DocumentPack(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shareUrl = try container.decode(String.self, forKey: .shareUrl)
    }
    enum CodingKeys: String, CodingKey { case shareUrl }
}
