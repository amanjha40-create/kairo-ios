import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DocumentVaultServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_listMapsCurrentAndImmutableReplacementHistoryWithoutStoragePaths() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/user-documents")
            XCTAssertEqual(request.httpMethod, "GET")
            return (try Self.response(for: request, statusCode: 200), Self.pagePayload)
        }

        let documents = try await service.listDocuments()

        XCTAssertEqual(documents.count, 2)
        XCTAssertTrue(try XCTUnwrap(documents.first(where: { $0.id == "document-current" })).isCurrent)
        let historical = try XCTUnwrap(documents.first(where: { $0.id == "document-history" }))
        XCTAssertFalse(historical.isCurrent)
        XCTAssertEqual(historical.supersededByID, "document-current")
        XCTAssertFalse(String(describing: documents).contains("object_key"))
    }

    func test_replacementUsesAuthoritativeReplacementLinkThenReloads() async throws {
        let service = try await makeService()
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("vault-replacement.pdf")
        try Data("%PDF-private-vault-fixture".utf8).write(to: fileURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.host, request.url?.path) {
            case ("POST", "staging-api.kairoid.com", "/api/v1/user-documents/upload-intent"):
                let body = try requestBodyData(from: request)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(json["document_type"] as? String, "passport")
                XCTAssertEqual(json["replaces_document_id"] as? String, "document-history")
                return (try Self.response(for: request, statusCode: 201), Self.intentPayload)
            case ("PUT", "storage.example", "/vault-upload"):
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                return (try Self.response(for: request, statusCode: 200), Data())
            case ("POST", "staging-api.kairoid.com", "/api/v1/user-documents/document-current/complete-upload"):
                let body = try requestBodyData(from: request)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual((json["checksum_sha256"] as? String)?.count, 64)
                return (try Self.response(for: request, statusCode: 200), Self.currentDocumentPayload)
            case ("GET", "staging-api.kairoid.com", "/api/v1/user-documents"):
                return (try Self.response(for: request, statusCode: 200), Self.pagePayload)
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let documents = try await service.uploadDocument(
            fileURL: fileURL,
            type: .passport,
            documentNumber: nil,
            expiresAt: nil,
            replacing: "document-history"
        )

        XCTAssertEqual(documents.count, 2)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.filter { $0.httpMethod == "PUT" }.count, 1)
    }

    func test_downloadRequiresHTTPSAndDeleteUsesExactDocumentID() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/user-documents/document-current/download-url"):
                return (
                    try Self.response(for: request, statusCode: 200),
                    Data(#"{"document_id":"document-current","download_url":"https://storage.example/private","expires_in_seconds":300}"#.utf8)
                )
            case ("DELETE", "/api/v1/user-documents/document-current"):
                return (try Self.response(for: request, statusCode: 204), Data())
            case ("GET", "/api/v1/user-documents"):
                return (try Self.response(for: request, statusCode: 200), Data(#"{"items":[]}"#.utf8))
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "nil") \(request.url?.absoluteString ?? "nil")")
                throw URLError(.badURL)
            }
        }

        let url = try await service.downloadURL(documentID: "document-current")
        let remaining = try await service.deleteDocument(documentID: "document-current")

        XCTAssertEqual(url.scheme, "https")
        XCTAssertTrue(remaining.isEmpty)
    }

    private func makeService() async throws -> DocumentVaultService {
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
            keychainService: "com.kairoid.Kairo.tests.document-vault"
        )
        return DocumentVaultService(
            sessionService: SessionService(
                configuration: configuration,
                networkClient: client,
                tokenStore: tokenStore
            ),
            transferClient: SecureDocumentTransferClient(session: makeMockedURLSession())
        )
    }

    private nonisolated static func response(for request: URLRequest, statusCode: Int) throws -> HTTPURLResponse {
        try XCTUnwrap(
            HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )
        )
    }

    private nonisolated static let intentPayload = Data(
        #"{"document_id":"document-current","upload_url":"https://storage.example/vault-upload","expires_in_seconds":300,"headers_required":{"Content-Type":"application/pdf"}}"#.utf8
    )

    private nonisolated static let currentDocumentPayload = Data(
        #"{"id":"document-current","document_type":"passport","document_number":null,"original_filename":"vault-replacement.pdf","content_type":"application/pdf","byte_size":26,"verification_status":"pending_review","verified_at":null,"reviewer_note":null,"expires_at":null,"superseded_at":null,"superseded_by_id":null,"replaces_document_id":"document-history","created_at":"2026-09-14T10:00:00Z","updated_at":"2026-09-14T10:00:00Z"}"#.utf8
    )

    private nonisolated static let pagePayload = Data(
        """
        {"items":[
          {"id":"document-current","document_type":"passport","document_number":null,"original_filename":"current.pdf","content_type":"application/pdf","byte_size":2048,"verification_status":"pending_review","verified_at":null,"reviewer_note":null,"expires_at":null,"superseded_at":null,"superseded_by_id":null,"replaces_document_id":"document-history","created_at":"2026-09-14T10:00:00Z","updated_at":"2026-09-14T10:00:00Z"},
          {"id":"document-history","document_type":"passport","document_number":null,"original_filename":"history.pdf","content_type":"application/pdf","byte_size":1024,"verification_status":"verified","verified_at":"2026-09-10T10:00:00Z","reviewer_note":null,"expires_at":null,"superseded_at":"2026-09-14T10:00:00Z","superseded_by_id":"document-current","replaces_document_id":null,"created_at":"2026-09-10T10:00:00Z","updated_at":"2026-09-14T10:00:00Z"}
        ]}
        """.utf8
    )
}
