import Foundation

struct MissingDocumentPackService: DocumentPackServiceProtocol {
    func documents() async throws -> [PackSelectableDocument] { throw DocumentPackError.unavailable }
    func history() async throws -> [DocumentPack] { throw DocumentPackError.unavailable }
    func detail(id: String) async throws -> DocumentPack { throw DocumentPackError.unavailable }
    func create(_ input: DocumentPackCreate) async throws -> DocumentPackCreation { throw DocumentPackError.unavailable }
    func revoke(id: String) async throws -> DocumentPack { throw DocumentPackError.unavailable }
    func recipient(_ capability: DocumentPackCapability) async throws -> PublicDocumentPack { throw DocumentPackError.unavailable }
    func content(_ capability: DocumentPackCapability, itemID: String) async throws -> ProtectedDocumentContent { throw DocumentPackError.unavailable }
}

/// Installed only in explicit Demo or validated UI-test dependency graphs. Never a live fallback.
actor DemoDocumentPackService: DocumentPackServiceProtocol {
    let scenario: String
    private var rows: [DocumentPack]
    private var failed = false
    init(scenario: String = "populated") {
        self.scenario = scenario
        rows = scenario == "empty" ? [] : [Self.pack(id: Self.activeID, status: "active"), Self.pack(id: Self.expiredID, status: "expired"), Self.pack(id: Self.revokedID, status: "revoked")]
    }
    nonisolated static let activeID = "00000000-0000-4000-8000-000000000001"
    nonisolated static let expiredID = "00000000-0000-4000-8000-000000000002"
    nonisolated static let revokedID = "00000000-0000-4000-8000-000000000003"
    nonisolated static let createdID = "00000000-0000-4000-8000-000000000004"
    nonisolated static var fixtures: [PackSelectableDocument] {
        [
            .init(sourceType: "vault", sourceId: activeID, selectionVersion: String(repeating: "a", count: 64), category: "identity", title: "Demo Birth Certificate", context: nil, filename: "demo-birth-certificate.pdf", contentType: "application/pdf", byteSize: 100),
            .init(sourceType: "employment", sourceId: expiredID, selectionVersion: String(repeating: "b", count: 64), category: "employment", title: "Demo Employment Letter", context: "Synthetic Example Company", filename: "demo-employment-letter-with-a-long-descriptive-filename.pdf", contentType: "application/pdf", byteSize: 200)
        ]
    }
    nonisolated static func pack(id: String, status: String, purpose: String = "Demo document pack", items: [DocumentPackItem]? = nil) -> DocumentPack {
        let items = items ?? fixtures.map { DocumentPackItem(publicId: $0.sourceId, category: $0.category, title: $0.title, context: $0.context, filename: $0.filename, contentType: $0.contentType, byteSize: $0.byteSize) }
        return DocumentPack(publicId: id, purpose: purpose, expiresAt: status == "expired" ? Date(timeIntervalSince1970: 1) : Date().addingTimeInterval(604800), documentCount: items.count, items: items, createdAt: Date().addingTimeInterval(-3600), revokedAt: status == "revoked" ? Date() : nil, status: status, viewCount: 2, lastViewedAt: Date().addingTimeInterval(-60))
    }
    func documents() async throws -> [PackSelectableDocument] {
        try await behavior()
        return scenario == "empty" ? [] : Self.fixtures
    }
    func history() async throws -> [DocumentPack] { try await behavior(); return rows }
    func detail(id: String) async throws -> DocumentPack {
        guard let row = rows.first(where: { $0.id == id }) else { throw DocumentPackError.unavailable }
        return row
    }
    func create(_ input: DocumentPackCreate) async throws -> DocumentPackCreation {
        try await Task.sleep(for: .milliseconds(350))
        if scenario == "create-ambiguous" { throw DocumentPackError.ambiguousCreation }
        if scenario == "create-rejected", !failed { failed = true; throw DocumentPackError.rejected }
        let items = Self.fixtures.filter { input.items.contains($0.selection) }.map {
            DocumentPackItem(publicId: $0.sourceId, category: $0.category, title: $0.title, context: $0.context, filename: $0.filename, contentType: $0.contentType, byteSize: $0.byteSize)
        }
        let pack = DocumentPack(publicId: Self.createdID, purpose: input.purpose, expiresAt: Date().addingTimeInterval(Double(input.expiryDays) * 86400), documentCount: items.count, items: items, createdAt: Date(), revokedAt: nil, status: "active", viewCount: 0, lastViewedAt: nil)
        rows.insert(pack, at: 0)
        return try DocumentPackCreation(pack: pack, capability: .init(serverURL: "https://demo.invalid/document-pack#token=" + String(repeating: "A", count: 43), allowedHosts: ["demo.invalid"]))
    }
    func revoke(id: String) async throws -> DocumentPack {
        let old = try await detail(id: id)
        let value = DocumentPack(publicId: old.id, purpose: old.purpose, expiresAt: old.expiresAt, documentCount: old.documentCount, items: old.items, createdAt: old.createdAt, revokedAt: Date(), status: "revoked", viewCount: old.viewCount, lastViewedAt: old.lastViewedAt)
        rows = rows.map { $0.id == id ? value : $0 }
        return value
    }
    func recipient(_ capability: DocumentPackCapability) async throws -> PublicDocumentPack {
        guard let pack = rows.first(where: { $0.id == Self.createdID }), pack.isActive else { throw DocumentPackError.unavailable }
        return PublicDocumentPack(purpose: pack.purpose, expiresAt: pack.expiresAt, documentCount: pack.documentCount, items: pack.items)
    }
    func content(_ capability: DocumentPackCapability, itemID: String) async throws -> ProtectedDocumentContent { throw DocumentPackError.unavailable }
    private func behavior() async throws {
        if scenario == "loading" { try await Task.sleep(for: .seconds(2)) }
        if scenario == "error", !failed { failed = true; throw DocumentPackError.connection }
    }
}
