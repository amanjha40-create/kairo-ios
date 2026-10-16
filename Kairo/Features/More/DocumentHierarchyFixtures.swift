import Foundation

/// Opt-in UI-test fixtures only; never installed for an authenticated live session.
actor DocumentHierarchyFixtures: DocumentsHubServiceProtocol, DocumentVaultServiceProtocol {
    let scenario: String
    init(scenario: String) { self.scenario = scenario }

    nonisolated static func vaultDocument(_ id: String, type: VaultDocumentType, historical: Bool = false) -> VaultDocument {
        VaultDocument(id: id, documentType: type, documentNumber: nil,
            originalFilename: "synthetic-\(id)-long-private-document-filename.pdf", contentType: "application/pdf", byteSize: 1024,
            verificationStatus: "draft", verifiedAt: nil, reviewerNote: nil, expiresAt: nil,
            supersededAt: historical ? Date(timeIntervalSince1970: 1) : nil, supersededByID: nil, replacesDocumentID: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000), updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
    }
    nonisolated static var vaultDocuments: [VaultDocument] {
        [vaultDocument("birth", type: .birthCertificate), vaultDocument("government", type: .governmentID),
         vaultDocument("other", type: .other), vaultDocument("historical", type: .aadhaar, historical: true)]
    }
    private var fixtureVaultDocuments: [VaultDocument] {
        guard scenario == "aadhaar-privacy" else { return Self.vaultDocuments }
        return [VaultDocument(id: "aadhaar-private", documentType: .aadhaar, documentNumber: "synthetic-number-secret",
            originalFilename: "synthetic-private-original.pdf", contentType: "application/pdf", byteSize: 1024,
            verificationStatus: "pending_review", verifiedAt: nil, reviewerNote: "synthetic-reviewer-secret", expiresAt: nil,
            supersededAt: nil, supersededByID: nil, replacesDocumentID: nil,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000), updatedAt: Date(timeIntervalSince1970: 1_800_000_000))]
    }
    func load() async throws -> [DocumentsHubRow] {
        if scenario == "error" { throw NetworkError.unavailableInDemoMode }
        if scenario == "empty" { return [] }
        var rows = try await PreviewDocumentsHubService().load()
        let sources: [(DocumentsHubCategory, CareerDocumentParent)] = [
            (.employment, .employment(id: "employment", title: "Synthetic Employer", canUpload: true, canDelete: true)),
            (.education, .education(id: "education", title: "Synthetic University")),
            (.portfolio, .portfolio(id: "portfolio", title: "Synthetic Portfolio item"))]
        for (category, parent) in sources {
            let document = CareerDocument(id: category.id, documentType: "other", originalFilename: "synthetic-\(category.id)-attachment.pdf",
                contentType: "application/pdf", byteSize: 2048, verificationStatus: "draft")
            rows.append(.init(id: category.id, category: category, filename: document.originalFilename,
                context: parent.title, contentType: document.contentType, byteSize: document.byteSize,
                status: "Candidate-provided", historical: false, immutable: false, source: .career(parent, document)))
        }
        rows += fixtureVaultDocuments.map { document in
            .init(id: "vault.\(document.id)", category: .other, filename: document.originalFilename,
                context: "Vault · \(document.documentType.title)", contentType: document.contentType, byteSize: document.byteSize,
                status: "Candidate-provided", historical: !document.isCurrent, immutable: !document.isCurrent, source: .vault(document))
        }
        return rows
    }
    func listDocuments() async throws -> [VaultDocument] { scenario == "empty" ? [] : fixtureVaultDocuments }
    func uploadDocument(fileURL: URL, type: VaultDocumentType, documentNumber: String?, expiresAt: Date?, replacing documentID: String?) async throws -> [VaultDocument] { throw NetworkError.unavailableInDemoMode }
    func updateMetadata(documentID: String, documentNumber: String?, expiresAt: Date?) async throws -> [VaultDocument] { throw NetworkError.unavailableInDemoMode }
    func content(documentID: String) async throws -> ProtectedDocumentContent { throw NetworkError.unavailableInDemoMode }
    func deleteDocument(documentID: String) async throws -> [VaultDocument] { throw NetworkError.unavailableInDemoMode }
}
