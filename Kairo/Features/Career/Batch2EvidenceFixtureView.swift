import SwiftUI

/// Explicit Staging UI-test mode only. All mutations stay in this disposable in-memory service.
struct Batch2EvidenceFixtureView: View {
    @State private var service = Batch2EvidenceFixtureService()
    @State private var presentation: CareerDocumentPresentation?
    @State private var detail: CareerRecordDetailPresentation?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Synthetic Batch 2 evidence QA").font(.headline)
                Text("No live documents or network writes.")
                ForEach(0...2, id: \.self) { count in
                    Button("\(count) primary evidence") {
                        Task {
                            await service.configure(count: count)
                            presentation = .init(parent: Self.parent)
                        }
                    }.accessibilityIdentifier("batch2.evidence.\(count)")
                }
                Button("Employment actions and location") {
                    detail = .init(id: "batch2", title: "Synthetic QA role", organization: "Synthetic employer",
                                   status: .init(rawBackendValue: "withdrawn_by_candidate"),
                                   metadata: [("Location", "Jaipur, India"), ("Missing country", "Jaipur")],
                                   documents: Self.parent, edit: {}, delete: {}, verify: {})
                }.accessibilityIdentifier("batch2.detail")
            }.padding()
        }
        .sheet(item: $presentation) { CareerDocumentsView(presentation: $0).environment(\.careerDocumentService, service) }
        .sheet(item: $detail) { record in
            CareerRecordDetailView(record: record, perform: { $0() }, openDocuments: { presentation = .init(parent: $0) })
                .environment(\.careerDocumentService, service)
        }
    }
    private static var parent: CareerDocumentParent {
        .employment(id: "synthetic-batch2", title: "Synthetic Employment", canUpload: true, canDelete: false)
    }
}

private actor Batch2EvidenceFixtureService: CareerDocumentServiceProtocol {
    private var primaryCount = 0
    private var legacyRole: EmploymentEvidenceRole?
    func configure(count: Int) { primaryCount = count; legacyRole = nil }
    func employmentEligibility(id: String) async throws -> EmploymentEvidenceEligibility {
        let count = primaryCount + (legacyRole == .primary ? 1 : 0)
        return .init(eligiblePrimaryCount: count, minimumRequired: 2, eligible: count >= 2)
    }
    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument] {
        (0..<primaryCount).map { document("primary-\($0)", .primary) }
            + [document("supporting", .supporting), document("legacy", legacyRole)]
    }
    private func document(_ id: String, _ role: EmploymentEvidenceRole?) -> CareerDocument {
        .init(id: id, documentType: "other", originalFilename: "synthetic-\(id).pdf", contentType: "application/pdf", byteSize: 120, verificationStatus: "pending_review", evidenceRole: role, checksumSha256: String(repeating: "a", count: 64))
    }
    func classifyEvidence(_ document: CareerDocument, parent: CareerDocumentParent, role: EmploymentEvidenceRole) async throws {
        guard document.id == "legacy", legacyRole == nil else { throw NetworkError.unavailableInDemoMode }
        legacyRole = role
    }
    nonisolated func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType] { [.init(id: "other", label: "Other")] }
    func uploadDocument(fileURL: URL, documentType: String, to parent: CareerDocumentParent) async throws -> [CareerDocument] { throw NetworkError.unavailableInDemoMode }
    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL { throw NetworkError.unavailableInDemoMode }
    func deleteDocument(_ document: CareerDocument, parent: CareerDocumentParent) async throws -> [CareerDocument] { throw NetworkError.unavailableInDemoMode }
}
