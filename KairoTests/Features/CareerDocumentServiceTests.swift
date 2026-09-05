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
            XCTAssertEqual(error as? CareerDocumentServiceError, .storageUploadFailed)
        }

        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.httpMethod == "DELETE" }.count, 1)
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
            storageSession: makeMockedURLSession()
        )
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
