import Foundation

nonisolated enum DocumentsHubCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All", employment = "Employment", education = "Education", certifications = "Certifications"
    case projects = "Projects", portfolio = "Portfolio", verification = "Verification", other = "Other"
    var id: String { rawValue }
}

nonisolated enum DocumentsHubSource: Equatable, Sendable {
    case career(CareerDocumentParent, CareerDocument)
    case vault(VaultDocument)
    case unavailable
}

nonisolated struct DocumentsHubRow: Identifiable, Equatable, Sendable {
    let id: String
    let category: DocumentsHubCategory
    let filename: String
    let context: String
    let contentType: String
    let byteSize: Int
    let status: String
    let historical: Bool
    var immutable: Bool
    let source: DocumentsHubSource
    var canView: Bool { source != .unavailable }
    var displayStatus: String {
        if category == .certifications || category == .projects {
            return ProductStatusLanguage.optionalRecordTitle(status) ?? "Attachment"
        }
        return status
    }
    var canReplace: Bool {
        guard !immutable, !historical else { return false }
        switch source {
        case .career(let parent, _): return parent.canUpload && parent.canDelete
        case .vault(let document): return document.isCurrent
        case .unavailable: return false
        }
    }
    var canRemove: Bool {
        guard !immutable, !historical else { return false }
        switch source {
        case .career(let parent, _): return parent.canDelete
        case .vault(let document): return document.isCurrent
        case .unavailable: return false
        }
    }
    static func categories(in rows: [Self]) -> [DocumentsHubCategory] {
        [.all] + DocumentsHubCategory.allCases.filter { category in category != .all && rows.contains { $0.category == category } }
    }
}

protocol DocumentsHubServiceProtocol: Sendable {
    func load() async throws -> [DocumentsHubRow]
}

actor DocumentsHubService: DocumentsHubServiceProtocol {
    let career: any CareerOverviewServiceProtocol
    let documents: any CareerDocumentServiceProtocol
    let vault: any DocumentVaultServiceProtocol
    let session: any SessionServiceProtocol

    init(career: any CareerOverviewServiceProtocol, documents: any CareerDocumentServiceProtocol,
         vault: any DocumentVaultServiceProtocol, session: any SessionServiceProtocol) {
        self.career = career; self.documents = documents; self.vault = vault; self.session = session
    }

    func load() async throws -> [DocumentsHubRow] {
        let overview = try await career.loadOverview()
        var rows: [DocumentsHubRow] = []
        var byDocument: [String: DocumentsHubRow] = [:]
        var parents: [(CareerDocumentParent, DocumentsHubCategory)] = overview.employments.map {
            (.employment(id: $0.id, title: "\($0.role) at \($0.company)",
                         canUpload: $0.allowsCandidateEditing && $0.verificationMethod != "employer_confirmation",
                         canDelete: $0.allowsCandidateDeletion), .employment)
        }
        parents += overview.educations.map { (.education(id: $0.id, title: $0.institution), .education) }
        parents += overview.certifications.map { (.certification(id: $0.id, title: $0.title), .certifications) }
        parents += overview.portfolio.map { (.portfolio(id: $0.id, title: "\($0.title) · Portfolio"), .portfolio) }
        for (parent, category) in parents {
            for doc in try await documents.listDocuments(for: parent) {
                let row = DocumentsHubRow(id: "\(parent.id).\(doc.id)", category: category, filename: doc.originalFilename,
                    context: "\(parent.title) · Current", contentType: doc.contentType, byteSize: doc.byteSize,
                    status: ProductStatusLanguage.title(for: doc.verificationStatus), historical: false, immutable: false,
                    source: .career(parent, doc))
                rows.append(row)
                byDocument["\(category.rawValue).\(doc.id)"] = row
            }
        }
        for doc in try await vault.listDocuments() {
            let row = DocumentsHubRow(id: "vault.\(doc.id)", category: .other, filename: doc.originalFilename,
                context: "Vault · \(doc.documentType.title) · \(doc.isCurrent ? "Current" : "Replaced version")",
                contentType: doc.contentType, byteSize: doc.byteSize, status: ProductStatusLanguage.title(for: doc.verificationStatus),
                historical: !doc.isCurrent, immutable: !doc.isCurrent, source: .vault(doc))
            rows.append(row)
            byDocument["Other.\(doc.id)"] = row
        }
        let requests = try await loadOwnerCollection(HubRequest.self, path: "/verification-requests/me", session: session)
        var immutableIDs: Set<String> = []
        for request in requests {
            guard let requestID = request.publicId else { continue }
            let evidence = try await loadEvidence(requestID: requestID)
            for item in evidence {
                let key: String
                if let id = item.employmentDocumentId { key = "Employment.\(id)" }
                else if let id = item.educationDocumentId { key = "Education.\(id)" }
                else if let id = item.documentId { key = "Other.\(id)" }
                else { continue } // Non-document field evidence is not a uploaded file.
                let current = byDocument[key]
                if let current { immutableIDs.insert(current.id) }
                // A historical reference alone does not authorize a current-document route.
                // Use only an attachment confirmed by an owner collection; do not reconstruct
                // download routes for removed rows or invent Education history support.
                let source: DocumentsHubSource = current?.source ?? .unavailable
                let filename: String
                if case .vault(let document) = source, document.documentType == .aadhaar {
                    filename = document.documentType.metadataFilename("", contentType: document.contentType)
                } else if current == nil, item.documentId != nil,
                          item.employmentDocumentId == nil, item.educationDocumentId == nil,
                          item.documentType == nil {
                    filename = "Historical evidence"
                } else {
                    filename = item.originalFilename ?? current?.filename ?? "Historical evidence"
                }
                rows.append(DocumentsHubRow(id: "evidence.\(requestID).\(item.publicId)", category: .verification,
                    filename: filename,
                    context: "\(current?.context ?? "Verification request") · Immutable evidence · \(ProductStatusLanguage.title(for: request.status))",
                    contentType: item.mimeType ?? current?.contentType ?? "", byteSize: item.fileSize ?? current?.byteSize ?? 0,
                    status: ProductStatusLanguage.title(for: item.uploadStatus ?? "unknown"), historical: true,
                    immutable: true, source: source))
            }
        }
        return rows.map { row in
            var result = row
            if immutableIDs.contains(row.id) { result.immutable = true }
            return result
        }
    }

    private func loadEvidence(requestID: String) async throws -> [HubEvidence] {
        var result: [HubEvidence] = []
        let decoder = APIJSONCoder.makeDecoder()
        while true {
            try Task.checkCancellation()
            let data = try await session.sendAuthenticated(NetworkRequest(
                path: "/verification-requests/\(requestID)/evidence",
                headers: ["Accept": "application/json", "Cache-Control": "no-store"],
                queryItems: [.init(name: "offset", value: String(result.count)), .init(name: "limit", value: "100")],
                requiresPrivateJSONTransport: true
            ))
            if let array = try? decoder.decode([HubEvidence].self, from: data) { return array }
            let page = try decoder.decode(OwnerCollectionPage<HubEvidence>.self, from: data)
            result.append(contentsOf: page.items)
            if page.items.isEmpty || result.count >= (page.total ?? result.count) { return result }
        }
    }
}

actor PreviewDocumentsHubService: DocumentsHubServiceProtocol {
    func load() async throws -> [DocumentsHubRow] {
        let document = CareerDocument(id: "demo-cert", documentType: "certificate", originalFilename: "demo-certificate.pdf",
            contentType: "application/pdf", byteSize: 1280, verificationStatus: "draft")
        return [
            DocumentsHubRow(id: "demo-cert", category: .certifications, filename: document.originalFilename,
                context: "Demo certification · Current", contentType: document.contentType, byteSize: document.byteSize,
                status: "Draft", historical: false, immutable: false,
                source: .career(.certification(id: "demo-cert", title: "Demo certification"), document)),
            DocumentsHubRow(id: "demo-history", category: .verification, filename: "demo-historical-evidence.pdf",
                context: "Historical education evidence · Immutable", contentType: "application/pdf", byteSize: 1280,
                status: "Candidate-provided", historical: true, immutable: true, source: .unavailable)
        ]
    }
}

private nonisolated struct HubRequest: Decodable, Sendable {
    let publicId: String?
    let employmentId: String?
    let status: String
}
private nonisolated struct HubEvidence: Decodable, Sendable {
    let publicId: String
    let documentId: String?
    let employmentDocumentId: String?
    let educationDocumentId: String?
    let documentType: String?
    let originalFilename: String?
    let mimeType: String?
    let fileSize: Int?
    let uploadStatus: String?

    private enum CodingKeys: String, CodingKey {
        case publicId, documentId, employmentDocumentId, educationDocumentId, documentType
        case originalFilename, mimeType, fileSize, uploadStatus
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        publicId = try values.decode(String.self, forKey: .publicId)
        documentId = try values.decodeIfPresent(String.self, forKey: .documentId)
        employmentDocumentId = try values.decodeIfPresent(String.self, forKey: .employmentDocumentId)
        educationDocumentId = try values.decodeIfPresent(String.self, forKey: .educationDocumentId)
        mimeType = try values.decodeIfPresent(String.self, forKey: .mimeType)
        fileSize = try values.decodeIfPresent(Int.self, forKey: .fileSize)
        uploadStatus = try values.decodeIfPresent(String.self, forKey: .uploadStatus)
        let type = try values.decodeIfPresent(String.self, forKey: .documentType)
        documentType = type?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? type : nil
        if documentType == VaultDocumentType.aadhaar.rawValue {
            originalFilename = VaultDocumentType.aadhaar.metadataFilename("", contentType: mimeType ?? "")
        } else {
            originalFilename = try values.decodeIfPresent(String.self, forKey: .originalFilename)
        }
    }
}
