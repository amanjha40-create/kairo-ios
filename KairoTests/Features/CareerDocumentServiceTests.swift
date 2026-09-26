import Foundation
import XCTest
@testable import Kairo

@MainActor
final class CareerDocumentServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_listEmploymentDocumentsUsesPrivateMetadataRoute() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/employments/employment-1/documents")
            XCTAssertEqual(request.httpMethod, "GET")
            return (try Self.response(for: request, statusCode: 200), Self.pagePayload)
        }

        let documents = try await service.listDocuments(
            for: .employment(id: "employment-1", title: "Role", canUpload: true, canDelete: true)
        )

        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(documents.first?.originalFilename, "evidence.pdf")
        XCTAssertEqual(documents.first?.verificationStatus, "pending_review")
    }

    func test_downloadReturnsSecureEphemeralURLWithoutEmbeddingItInDomainState() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/educations/education-1/documents/document-1/download-url")
            return (
                try Self.response(for: request, statusCode: 200),
                Data(#"{"document_id":"document-1","download_url":"https://storage.example/private","expires_in_seconds":300}"#.utf8)
            )
        }
        let document = CareerDocument(
            id: "document-1",
            documentType: "transcript",
            originalFilename: "evidence.pdf",
            contentType: "application/pdf",
            byteSize: 8,
            verificationStatus: "pending_review"
        )

        let url = try await service.downloadURL(
            for: document,
            parent: .education(id: "education-1", title: "University")
        )

        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "storage.example")
    }

    func test_uploadUsesIntentStoragePutCompletionAndAuthoritativeReload() async throws {
        let service = try await makeService()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("kairo-7d-document.pdf")
        try Data("%PDF-private-fixture".utf8).write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/educations/education-1/documents/upload-intent"):
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(payload["document_type"] as? String, "transcript")
                XCTAssertEqual(payload["content_type"] as? String, "application/pdf")
                return (try Self.response(for: request, statusCode: 201), Self.intentPayload)
            case ("PUT", "storage.example", "/private-upload"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), nil)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/pdf")
                return (try Self.response(for: request, statusCode: 200), Data())
            case ("POST", "staging-api.kairoid.com", "/api/v1/educations/education-1/documents/document-1/complete-upload"):
                let body = try requestBodyData(from: request)
                let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(payload["checksum_sha256"]?.count, 64)
                return (try Self.response(for: request, statusCode: 200), Self.documentPayload)
            case ("GET", "staging-api.kairoid.com", "/api/v1/educations/education-1/documents"):
                return (try Self.response(for: request, statusCode: 200), Self.pagePayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let documents = try await service.uploadDocument(
            fileURL: fileURL,
            documentType: "transcript",
            to: .education(id: "education-1", title: "University")
        )

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(documents.count, 1)
        XCTAssertEqual(requests.filter { $0.httpMethod == "PUT" }.count, 1)
        XCTAssertEqual(requests.filter { $0.url?.path.contains("complete-upload") == true }.count, 1)
    }

    func test_failedStorageUploadDeletesOnlyIncompleteIntentRow() async throws {
        let service = try await makeService()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("kairo-7d-failed.pdf")
        try Data("%PDF-private-fixture".utf8).write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await MockURLProtocolStorage.shared.setHandler { request in
            if request.url?.path.contains("upload-intent") == true {
                return (try Self.response(for: request, statusCode: 201), Self.intentPayload)
            }
            if request.httpMethod == "PUT" {
                return (try Self.response(for: request, statusCode: 500), Data())
            }
            if request.httpMethod == "DELETE" {
                XCTAssertEqual(request.url?.path, "/api/v1/educations/education-1/documents/document-1")
                return (try Self.response(for: request, statusCode: 204), Data())
            }
            XCTFail("Unexpected request")
            throw URLError(.badURL)
        }

        do {
            _ = try await service.uploadDocument(
                fileURL: fileURL,
                documentType: "transcript",
                to: .education(id: "education-1", title: "University")
            )
            XCTFail("Expected failed storage upload")
        } catch {
            XCTAssertEqual(error as? SecureDocumentTransferError, .storageUploadFailed)
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.httpMethod == "DELETE" }.count, 1)
    }

    func test_replaceUploadsNewDocumentBeforeRemovingExactOldDocument() async throws {
        let spy = CareerDocumentReplacementSpy()
        let oldDocument = CareerDocument(
            id: "old-document",
            documentType: "transcript",
            originalFilename: "old.pdf",
            contentType: "application/pdf",
            byteSize: 10,
            verificationStatus: "pending_review"
        )
        let parent = CareerDocumentParent.education(id: "education-1", title: "University")

        _ = try await spy.replaceDocument(
            oldDocument,
            with: URL(fileURLWithPath: "/private/tmp/replacement.pdf"),
            documentType: "transcript",
            parent: parent
        )

        let events = spy.events()
        XCTAssertEqual(events, ["upload:transcript", "delete:old-document"])
    }

    func test_portfolioAttachmentLifecycleUsesIntentCompleteDetachAndSameRecord() async throws {
        let service = try await makeService()
        let backend = PortfolioAttachmentFixture()
        await MockURLProtocolStorage.shared.setHandler { request in try await backend.respond(request) }
        let parent = CareerDocumentParent.portfolio(id: "portfolio", title: "Case study")
        let initial = try await service.listDocuments(for: parent)
        XCTAssertTrue(initial.isEmpty)

        let file = FileManager.default.temporaryDirectory.appendingPathComponent("portfolio-\(UUID().uuidString).pdf")
        try Data("%PDF-synthetic-portfolio".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let added = try await service.uploadDocument(fileURL: file, documentType: "project", to: parent)
        XCTAssertEqual(added.first?.originalFilename, file.lastPathComponent)
        let removed = try await service.deleteDocument(try XCTUnwrap(added.first), parent: parent)
        XCTAssertTrue(removed.isEmpty)
        let readded = try await service.uploadDocument(fileURL: file, documentType: "project", to: parent)
        XCTAssertEqual(readded.count, 1)

        let counts = await backend.counts()
        XCTAssertEqual(counts.intents, 2)
        XCTAssertEqual(counts.completions, 2)
        XCTAssertEqual(counts.detaches, 1)
        let writes = await MockURLProtocolStorage.shared.requests().filter { $0.httpMethod != "GET" }
        XCTAssertFalse(writes.contains { $0.url?.path == "/api/v1/portfolio" })
    }

    func test_portfolioReplaceCompletesWithoutDetachingNewAttachment() async throws {
        let service = try await makeService()
        let backend = PortfolioAttachmentFixture(initiallyAttached: true)
        await MockURLProtocolStorage.shared.setHandler { request in try await backend.respond(request) }
        let parent = CareerDocumentParent.portfolio(id: "portfolio", title: "Case study")
        let existing = try await service.listDocuments(for: parent)
        let old = try XCTUnwrap(existing.first)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("replacement-\(UUID().uuidString).pdf")
        try Data("%PDF-replacement".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let replaced = try await service.replaceDocument(old, with: file, documentType: "project", parent: parent)

        XCTAssertEqual(replaced.first?.originalFilename, file.lastPathComponent)
        let counts = await backend.counts()
        XCTAssertEqual(counts.completions, 1)
        XCTAssertEqual(counts.detaches, 0)
    }

    func test_failedPortfolioReplacementPreservesPriorPresentedMetadataAndNeverDetaches() async throws {
        let service = try await makeService()
        let backend = PortfolioAttachmentFixture(initiallyAttached: true, failUpload: true)
        await MockURLProtocolStorage.shared.setHandler { request in try await backend.respond(request) }
        let parent = CareerDocumentParent.portfolio(id: "portfolio", title: "Case study")
        let existing = try await service.listDocuments(for: parent)
        let old = try XCTUnwrap(existing.first)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("failed-replacement-\(UUID().uuidString).pdf")
        try Data("%PDF-failed".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        do {
            _ = try await service.replaceDocument(old, with: file, documentType: "project", parent: parent)
            XCTFail("Expected upload failure")
        } catch {
            XCTAssertEqual(error as? SecureDocumentTransferError, .storageUploadFailed)
        }

        XCTAssertEqual(old.originalFilename, "existing-private.pdf")
        let counts = await backend.counts()
        XCTAssertEqual(counts.completions, 0)
        XCTAssertEqual(counts.detaches, 0)
    }

    func test_portfolioProtectedViewerFetchesAuthenticatedContentWithoutDownloadURL() async throws {
        let service = try await makeService()
        let backend = PortfolioAttachmentFixture(initiallyAttached: true)
        await MockURLProtocolStorage.shared.setHandler { request in try await backend.respond(request) }

        let content = try await service.protectedContent(for: .portfolio(id: "portfolio", title: "Case study"))

        XCTAssertEqual(content.contentType, "application/pdf")
        XCTAssertTrue(content.data.starts(with: Data("%PDF".utf8)))
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.contains { request in
            request.url?.path == "/api/v1/portfolio/portfolio/content"
                && request.value(forHTTPHeaderField: "Authorization") == "Bearer access-123"
        })
        XCTAssertFalse(requests.contains { $0.url?.path.contains("download-url") == true })
        XCTAssertFalse(requests.contains { $0.url?.host?.contains("storage") == true })
    }

    func test_portfolioSignedDownloadURLIsUnavailableByConstruction() async throws {
        let service = try await makeService()
        let document = CareerDocument(
            id: "portfolio",
            documentType: "project",
            originalFilename: "private.pdf",
            contentType: "application/pdf",
            byteSize: 1,
            verificationStatus: "draft"
        )

        do {
            _ = try await service.downloadURL(
                for: document,
                parent: .portfolio(id: "portfolio", title: "Case study")
            )
            XCTFail("Portfolio must not expose signed download URLs")
        } catch {
            XCTAssertEqual(error as? CareerDocumentServiceError, .protectedContentUnavailable)
        }
        let recordedRequests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(recordedRequests.isEmpty)
    }

    private func makeService() async throws -> CareerDocumentService {
        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-123", for: .accessToken)
        let client = URLSessionNetworkClient(
            baseURL: APIConfiguration.baseURL(for: .staging),
            session: makeMockedURLSession()
        )
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.career-documents"
        )
        return CareerDocumentService(
            sessionService: SessionService(
                configuration: configuration,
                networkClient: client,
                tokenStore: tokenStore
            ),
            transferClient: SecureDocumentTransferClient(session: makeMockedURLSession())
        )
    }

    func testParity3ACertificationFullAttachmentLifecycleUsesSameRecord() async throws {
        let service = try await makeService()
        let backend = CertificationAttachmentFixture()
        await MockURLProtocolStorage.shared.setHandler { request in try await backend.respond(request) }
        let parent = CareerDocumentParent.certification(id: "cert", title: "Synthetic certificate")
        let initial = try await service.listDocuments(for: parent)
        XCTAssertTrue(initial.isEmpty)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("parity3a-certificate-\(UUID().uuidString).pdf")
        try Data("%PDF-synthetic-local-fixture".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let added = try await service.uploadDocument(fileURL: file, documentType: "certificate", to: parent)
        XCTAssertEqual(added.count, 1)
        let reopened = try await service.listDocuments(for: parent)
        XCTAssertEqual(added, reopened)
        let url = try await service.downloadURL(for: XCTUnwrap(reopened.first), parent: parent)
        XCTAssertEqual(url, URL(string: "https://storage.example/certificate"))
        let replaced = try await service.replaceDocument(XCTUnwrap(reopened.first), with: file, documentType: "certificate", parent: parent)
        XCTAssertEqual(replaced.count, 1)
        let requestsBeforeRemoval = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requestsBeforeRemoval.filter { $0.httpMethod == "DELETE" }.count, 0, "Replacement must not detach the newly completed file")
        let reopenedReplacement = try await service.listDocuments(for: parent)
        XCTAssertEqual(reopenedReplacement, replaced)
        let removed = try await service.deleteDocument(XCTUnwrap(replaced.first), parent: parent)
        XCTAssertTrue(removed.isEmpty)
        let reopenedEmpty = try await service.listDocuments(for: parent)
        XCTAssertTrue(reopenedEmpty.isEmpty)
        let readded = try await service.uploadDocument(fileURL: file, documentType: "certificate", to: parent)
        XCTAssertEqual(readded.count, 1)
        let counts = await backend.counts()
        XCTAssertEqual(counts.completions, 3)
        XCTAssertEqual(counts.detaches, 1)
        let allRequests = await MockURLProtocolStorage.shared.requests()
        XCTAssertFalse(allRequests.contains { $0.url?.path == "/api/v1/certifications" && $0.httpMethod == "POST" })
    }

    func testParity3ACertificationFailedReplacementNeverDetachesOldAttachment() async throws {
        let service = try await makeService()
        let backend = CertificationAttachmentFixture(failUpload: true)
        await MockURLProtocolStorage.shared.setHandler { request in try await backend.respond(request) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("parity3a-failed-\(UUID().uuidString).pdf")
        try Data("%PDF-local".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let doc = CareerDocument(id: "cert", documentType: "certificate", originalFilename: "old.pdf", contentType: "application/pdf", byteSize: 10, verificationStatus: "draft")
        do {
            _ = try await service.replaceDocument(doc, with: file, documentType: "certificate", parent: .certification(id: "cert", title: "Certificate"))
            XCTFail("Expected failed upload")
        } catch { XCTAssertEqual(error as? SecureDocumentTransferError, .storageUploadFailed) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertFalse(requests.contains { $0.httpMethod == "DELETE" || $0.url?.path.contains("complete-upload") == true })
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: try XCTUnwrap(request.url), statusCode: statusCode, httpVersion: nil, headerFields: nil))
    }

    private nonisolated static let intentPayload = Data(
        #"{"document_id":"document-1","upload_url":"https://storage.example/private-upload","expires_in_seconds":300,"headers_required":{"Content-Type":"application/pdf"}}"#.utf8
    )

    private nonisolated static let documentPayload = Data(
        #"{"id":"document-1","document_type":"transcript","original_filename":"evidence.pdf","content_type":"application/pdf","byte_size":20,"verification_status":"pending_review"}"#.utf8
    )

    private nonisolated static let pagePayload = Data(
        #"{"items":[{"id":"document-1","document_type":"transcript","original_filename":"evidence.pdf","content_type":"application/pdf","byte_size":20,"verification_status":"pending_review"}],"total":1,"offset":0,"limit":100}"#.utf8
    )
}

private actor PortfolioAttachmentFixture {
    private var attached: Bool
    private var filename = "existing-private.pdf"
    private var intents = 0
    private var completions = 0
    private var detaches = 0
    private let failUpload: Bool

    init(initiallyAttached: Bool = false, failUpload: Bool = false) {
        attached = initiallyAttached
        self.failUpload = failUpload
    }

    func counts() -> (intents: Int, completions: Int, detaches: Int) {
        (intents, completions, detaches)
    }

    func respond(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        var status = 200
        var data = Data()
        var headers: [String: String]?
        switch (request.httpMethod, url.path) {
        case ("GET", "/api/v1/portfolio/portfolio"):
            var record: [String: Any] = [
                "id": "portfolio", "title": "Case study", "tags": ["Research"],
                "verification_status": "draft"
            ]
            if attached {
                record["original_filename"] = filename
                record["content_type"] = "application/pdf"
                record["byte_size"] = 22
                record["upload_completed_at"] = "2026-09-01T08:00:00Z"
            }
            data = try JSONSerialization.data(withJSONObject: record)
        case ("POST", "/api/v1/portfolio/portfolio/upload-intent"):
            intents += 1
            let body = try requestJSONBody(from: request)
            filename = try XCTUnwrap(body["original_filename"] as? String)
            XCTAssertEqual(body["content_type"] as? String, "application/pdf")
            XCTAssertGreaterThan(body["byte_size"] as? Int ?? 0, 0)
            data = try JSONSerialization.data(withJSONObject: [
                "upload_url": "https://storage.example/portfolio-put",
                "headers_required": ["Content-Type": "application/pdf"]
            ])
        case ("PUT", "/portfolio-put"):
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if failUpload { status = 500 }
        case ("POST", "/api/v1/portfolio/portfolio/complete-upload"):
            completions += 1
            attached = true
            let body = try requestJSONBody(from: request)
            XCTAssertEqual((body["checksum_sha256"] as? String)?.count, 64)
            data = try JSONSerialization.data(withJSONObject: ["id": "portfolio", "title": "Case study"])
        case ("DELETE", "/api/v1/portfolio/portfolio/document"):
            detaches += 1
            attached = false
            status = 204
        case ("GET", "/api/v1/portfolio/portfolio/content"):
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
            data = Data("%PDF-protected-portfolio".utf8)
            headers = [
                "Content-Type": "application/pdf",
                "Content-Length": String(data.count),
                "Content-Disposition": "inline; filename=portfolio.pdf"
            ]
        default:
            XCTFail("Unexpected Portfolio fixture endpoint \(request.httpMethod ?? "nil") \(url.path)")
            throw URLError(.badURL)
        }
        return (
            try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: headers)),
            data
        )
    }
}

private actor CertificationAttachmentFixture {
    private var attached = false
    private var completions = 0
    private var detaches = 0
    private let failUpload: Bool
    init(failUpload: Bool = false) { self.failUpload = failUpload }
    func counts() -> (completions: Int, detaches: Int) { (completions, detaches) }
    func respond(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        var status = 200
        var json: [String: Any] = [:]
        switch (request.httpMethod, url.path) {
        case ("GET", "/api/v1/certifications/cert"):
            json = ["id": "cert", "title": "Synthetic certificate", "verification_status": "draft", "does_not_expire": true]
            if attached { json.merge(["original_filename": "certificate.pdf", "content_type": "application/pdf", "byte_size": 40]) { _, new in new } }
        case ("POST", "/api/v1/certifications/cert/document/upload-intent"):
            let body = try requestJSONBody(from: request)
            XCTAssertEqual((body["checksum_sha256"] as? String)?.count, 64)
            XCTAssertEqual(body["content_type"] as? String, "application/pdf")
            json = ["upload_url": "https://storage.example/put", "upload_token": String(repeating: "fixture-only", count: 4), "headers_required": ["Content-Type": "application/pdf"]]
        case ("PUT", "/put"):
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if failUpload { status = 500 }
        case ("POST", "/api/v1/certifications/cert/document/complete-upload"):
            let body = try requestJSONBody(from: request)
            XCTAssertEqual(Set(body.keys), ["upload_token", "checksum_sha256"])
            completions += 1; attached = true
        case ("DELETE", "/api/v1/certifications/cert/document"):
            detaches += 1; attached = false
        case ("GET", "/api/v1/certifications/cert/download-url"):
            json = ["download_url": "https://storage.example/certificate"]
        default: XCTFail("Unexpected fixture endpoint"); throw URLError(.badURL)
        }
        return (try XCTUnwrap(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)), try JSONSerialization.data(withJSONObject: json))
    }
}

@MainActor
private final class CareerDocumentReplacementSpy: CareerDocumentServiceProtocol {
    private var recordedEvents: [String] = []

    func events() -> [String] { recordedEvents }
    func listDocuments(for parent: CareerDocumentParent) async throws -> [CareerDocument] { [] }
    nonisolated func documentTypes(for parent: CareerDocumentParent) -> [CareerDocumentType] { [] }

    func uploadDocument(
        fileURL: URL,
        documentType: String,
        to parent: CareerDocumentParent
    ) async throws -> [CareerDocument] {
        recordedEvents.append("upload:\(documentType)")
        return []
    }

    func downloadURL(for document: CareerDocument, parent: CareerDocumentParent) async throws -> URL {
        URL(string: "https://storage.example/private")!
    }

    func deleteDocument(
        _ document: CareerDocument,
        parent: CareerDocumentParent
    ) async throws -> [CareerDocument] {
        recordedEvents.append("delete:\(document.id)")
        return []
    }
}
