import Foundation

protocol DocumentPackServiceProtocol: Sendable {
    func documents() async throws -> [PackSelectableDocument]
    func history() async throws -> [DocumentPack]
    func detail(id: String) async throws -> DocumentPack
    func create(_ input: DocumentPackCreate) async throws -> DocumentPackCreation
    func revoke(id: String) async throws -> DocumentPack
    func recipient(_ capability: DocumentPackCapability) async throws -> PublicDocumentPack
    func content(_ capability: DocumentPackCapability, itemID: String) async throws -> ProtectedDocumentContent
}

actor DocumentPackService: DocumentPackServiceProtocol {
    private let session: any SessionServiceProtocol
    private let publicClient: any NetworkClient
    private let allowedHosts: Set<String>
    private let root = "/document-share-packs"

    init(session: any SessionServiceProtocol, publicClient: any NetworkClient, allowedHosts: Set<String>) {
        self.session = session
        self.publicClient = publicClient
        self.allowedHosts = allowedHosts
    }
    func documents() async throws -> [PackSelectableDocument] { try await pages(root + "/documents") }
    func history() async throws -> [DocumentPack] { try await pages(root) }
    private func pages<T: Decodable & Sendable>(_ path: String) async throws -> [T] {
        var result: [T] = []
        var page = 1
        repeat {
            let response: DocumentPackPage<T> = try await owner(.init(path: path,
                queryItems: [.init(name: "page", value: String(page)), .init(name: "page_size", value: "50")],
                requiresPrivateJSONTransport: true))
            result.append(contentsOf: response.items)
            if page >= response.totalPages { return result }
            page += 1
            guard page <= 10_000 else { throw DocumentPackError.connection }
        } while true
    }
    func detail(id: String) async throws -> DocumentPack {
        try await owner(.init(path: root + "/" + safeID(id), requiresPrivateJSONTransport: true))
    }
    func create(_ input: DocumentPackCreate) async throws -> DocumentPackCreation {
        do {
            let dto: DocumentPackCreatedDTO = try await owner(.init(path: root, method: .post,
                headers: ["Content-Type": "application/json"], body: APIJSONCoder.makeEncoder().encode(input),
                allowsSessionRefreshOnUnauthorized: false, requiresPrivateJSONTransport: true), creating: true)
            return try DocumentPackCreation(pack: dto.pack,
                capability: DocumentPackCapability(serverURL: dto.shareUrl, allowedHosts: allowedHosts))
        } catch { throw DocumentPackError.map(error, creating: true) }
    }
    func revoke(id: String) async throws -> DocumentPack {
        // Idempotent contract. State is always read from the server, never inferred locally.
        try await owner(.init(path: root + "/" + safeID(id) + "/revoke", method: .post, requiresPrivateJSONTransport: true))
    }
    func recipient(_ capability: DocumentPackCapability) async throws -> PublicDocumentPack {
        do {
            return try await publicClient.decode(PublicDocumentPack.self,
                from: .init(path: publicPath(capability), requiresPrivateJSONTransport: true))
        } catch { throw DocumentPackError.map(error) }
    }
    func content(_ capability: DocumentPackCapability, itemID: String) async throws -> ProtectedDocumentContent {
        do {
            let path = publicPath(capability) + "/items/" + (try safeID(itemID))
            let download = try await publicClient.decode(DocumentPackDownload.self,
                from: .init(path: path + "/download-url", requiresPrivateJSONTransport: true))
            let components = try Self.validatedContentPath(download.downloadUrl, expectedPath: "/api/v1" + path + "/content")
            let response = try await publicClient.sendResponse(.init(path: path + "/content",
                queryItems: components.queryItems ?? [], requiresProtectedDocumentTransport: true))
            return try ProtectedDocumentContent(response: response)
        } catch { throw DocumentPackError.map(error) }
    }
    nonisolated static func validatedContentPath(_ value: String, expectedPath: String) throws -> URLComponents {
        guard let c = URLComponents(string: value), c.scheme == nil, c.host == nil, c.fragment == nil,
              c.percentEncodedPath == expectedPath, let query = c.queryItems, query.count == 2,
              Set(query.map(\.name)) == ["expires", "signature"],
              let expires = query.first(where: { $0.name == "expires" })?.value, Int(expires) != nil,
              let signature = query.first(where: { $0.name == "signature" })?.value,
              signature.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else { throw DocumentPackError.unavailable }
        return c
    }
    private func publicPath(_ capability: DocumentPackCapability) -> String { "/public/document-share-packs/" + capability.token }
    private func safeID(_ value: String) throws -> String {
        guard UUID(uuidString: value) != nil else { throw DocumentPackError.unavailable }
        return value
    }
    private func owner<T: Decodable>(_ request: NetworkRequest, creating: Bool = false) async throws -> T {
        do { return try APIJSONCoder.makeDecoder().decode(T.self, from: await session.sendAuthenticated(request)) }
        catch { throw DocumentPackError.map(error, creating: creating) }
    }
}

private nonisolated struct DocumentPackDownload: Decodable { let downloadUrl: String; let expiresInSeconds: Int }
