import Foundation

/// A first-class Portfolio record. Portfolio remains independent from canonical Projects.
nonisolated struct PortfolioRecord: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String?
    let url: URL?
    let tags: [String]
    let originalFilename: String?
    let contentType: String?
    let byteSize: Int?
    let uploadCompletedAt: Date?
    let verificationStatus: String
    let createdAt: Date?
    let updatedAt: Date?

    init(
        id: String,
        title: String,
        description: String? = nil,
        url: URL? = nil,
        tags: [String] = [],
        originalFilename: String? = nil,
        contentType: String? = nil,
        byteSize: Int? = nil,
        uploadCompletedAt: Date? = nil,
        verificationStatus: String = "draft",
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.url = url
        self.tags = tags
        self.originalFilename = originalFilename
        self.contentType = contentType
        self.byteSize = byteSize
        self.uploadCompletedAt = uploadCompletedAt
        self.verificationStatus = verificationStatus
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, url, tags
        case originalFilename, contentType, byteSize, uploadCompletedAt
        case verificationStatus, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        description = try values.decodeIfPresent(String.self, forKey: .description)
        url = try values.decodeIfPresent(URL.self, forKey: .url)
        tags = try values.decodeIfPresent([String].self, forKey: .tags) ?? []
        originalFilename = try values.decodeIfPresent(String.self, forKey: .originalFilename)
        contentType = try values.decodeIfPresent(String.self, forKey: .contentType)
        byteSize = try values.decodeIfPresent(Int.self, forKey: .byteSize)
        uploadCompletedAt = try values.decodeIfPresent(Date.self, forKey: .uploadCompletedAt)
        verificationStatus = try values.decodeIfPresent(String.self, forKey: .verificationStatus) ?? "draft"
        createdAt = try values.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try values.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var document: CareerDocument? {
        guard let originalFilename, uploadCompletedAt != nil else { return nil }
        return CareerDocument(id: id, documentType: "project", originalFilename: originalFilename,
                              contentType: contentType ?? "application/octet-stream", byteSize: byteSize ?? 0,
                              verificationStatus: verificationStatus)
    }
}

nonisolated struct PortfolioCreateRequestDTO: Encodable, Equatable, Sendable {
    let title: String
    let description: String?
    let url: String?
    let tags: [String]
}

nonisolated struct PortfolioUpdateRequestDTO: Encodable, Equatable, Sendable {
    let title: String?
    let description: String?
    let url: String?
    let tags: [String]

    private enum CodingKeys: String, CodingKey {
        case title, description, url, tags
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(title, forKey: .title)
        // Explicit null clears optional metadata, matching Android and the
        // backend's exclude-unset PATCH semantics.
        try values.encode(description, forKey: .description)
        try values.encode(url, forKey: .url)
        try values.encode(tags, forKey: .tags)
    }
}

nonisolated struct OwnerCollectionPage<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let total: Int?
}

/// Reads either the canonical array response or every page; never silently truncates a hub.
func loadOwnerCollection<Item: Decodable & Sendable>(
    _ type: Item.Type, path: String, session: any SessionServiceProtocol, startsWithPaging: Bool = true
) async throws -> [Item] {
    var result: [Item] = []
    while true {
        let data = try await session.sendAuthenticated(NetworkRequest(
            path: path, headers: ["Accept": "application/json"],
            queryItems: !startsWithPaging && result.isEmpty ? [] : [URLQueryItem(name: "offset", value: String(result.count)), URLQueryItem(name: "limit", value: "100")]
        ))
        let decoder = APIJSONCoder.makeDecoder()
        if let array = try? decoder.decode([Item].self, from: data) { return array }
        let page = try decoder.decode(OwnerCollectionPage<Item>.self, from: data)
        result.append(contentsOf: page.items)
        if page.items.isEmpty || result.count >= (page.total ?? result.count) { return result }
    }
}
