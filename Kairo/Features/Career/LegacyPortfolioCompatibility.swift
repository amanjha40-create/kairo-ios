import Foundation

/// Transitional owner data only. Never re-identify these rows as canonical Projects.
nonisolated struct LegacyPortfolioItem: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String?
    let url: URL?
    let originalFilename: String?
    let contentType: String?
    let byteSize: Int?
    let uploadCompletedAt: Date?
    let verificationStatus: String

    var document: CareerDocument? {
        guard let originalFilename else { return nil }
        return CareerDocument(id: id, documentType: "project", originalFilename: originalFilename,
                              contentType: contentType ?? "application/octet-stream", byteSize: byteSize ?? 0,
                              verificationStatus: verificationStatus)
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
