import Foundation
import XCTest
@testable import Kairo

@MainActor
final class DocumentVaultServiceTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func testNewUploadTaxonomyIsExactlyCanonicalSevenWithNoLegacyChoices() {
        let types = VaultDocumentType.newUploadTypes
        XCTAssertEqual(types.map(\.rawValue), ["aadhaar", "pan", "passport", "driving_license", "voter_id", "birth_certificate", "address_proof"])
        XCTAssertEqual(types.map(\.title), ["Aadhaar", "PAN", "Passport", "Driving Licence", "Voter ID", "Birth Certificate", "Address Proof"])
        XCTAssertFalse(types.contains(.governmentID))
        XCTAssertFalse(types.contains(.other))
        XCTAssertFalse(VaultDocumentType(rawValue: "future_identity").allowsNewUpload)
    }

    func testLegacyAndUnknownValuesPreserveRawIdentifierAndPreciseHubLabels() async throws {
        let service = try await makeService()
        let expected = ["birth_certificate": "Birth Certificate", "address_proof": "Address Proof",
                        "government_id": "Government ID", "other": "Other", "future_identity": "Identity document"]
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            let objects = expected.keys.sorted().map { raw in
                ["id": raw, "document_type": raw, "original_filename": "fixture.pdf", "content_type": "application/pdf",
                 "byte_size": 8, "verification_status": "draft", "created_at": "2030-01-01T00:00:00Z", "updated_at": "2030-01-01T00:00:00Z"] as [String: Any]
            }
            return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: ["items": objects]))
        }
        let docs = try await service.listDocuments()
        XCTAssertEqual(docs.count, 5)
        for doc in docs {
            XCTAssertEqual(doc.documentType.rawValue, doc.id)
            XCTAssertEqual(doc.documentType.title, expected[doc.id])
        }
    }

    func testLegacyOrFutureValueCannotBeSubmittedAsNewUpload() async throws {
        let service = try await makeService()
        for type in [VaultDocumentType.governmentID, .other, .init(rawValue: "future_identity")] {
            do {
                _ = try await service.uploadDocument(fileURL: URL(fileURLWithPath: "/not-read.pdf"), type: type,
                    documentNumber: nil, expiresAt: nil, replacing: nil)
                XCTFail("Legacy value must not be a new-upload choice")
            } catch { XCTAssertEqual(error as? SecureDocumentTransferError, .unsupportedFileType) }
        }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertTrue(requests.isEmpty)
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

    func test_ownerContentUsesAuthenticatedBytesAndDeleteUsesExactDocumentID() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/api/v1/user-documents/document-current/content"):
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-123")
                return (
                    try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil,
                        headerFields: ["Content-Type": "application/pdf", "Content-Disposition": "inline; filename*=UTF-8''Private%20Document.pdf"])),
                    Data("%PDF-private-fixture".utf8)
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

        let content = try await service.content(documentID: "document-current")
        let remaining = try await service.deleteDocument(documentID: "document-current")

        XCTAssertEqual(content.filename, "Private Document.pdf")
        XCTAssertEqual(content.contentType, "application/pdf")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertFalse(requests.contains { $0.url?.path.contains("download-url") == true })
        XCTAssertTrue(requests.allSatisfy { $0.url?.host == "staging-api.kairoid.com" })
        XCTAssertTrue(remaining.isEmpty)
    }

    func testAadhaarMetadataIsDiscardedForCurrentAndHistoricalArrayAndPagedResponses() async throws {
        let service = try await makeService()
        for paged in [false, true] {
            await MockURLProtocolStorage.shared.setHandler { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-store")
                var current = Self.metadataRecord(type: "aadhaar")
                current["extracted_payload"] = ["number": "synthetic-extracted-secret", "photo": "synthetic-photo"]
                current["unknown_private_field"] = "synthetic-unknown-secret"
                var historical = current
                historical["id"] = "document-history"
                historical["superseded_at"] = "2030-02-01T00:00:00Z"
                historical["superseded_by_id"] = "document-current"
                let records = [current, historical]
                let payload: Any = paged ? ["items": records, "total": 2] : records
                return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: payload))
            }
            let documents = try await service.listDocuments()
            XCTAssertEqual(documents.count, 2)
            XCTAssertTrue(documents[0].isCurrent)
            XCTAssertFalse(documents[1].isCurrent)
            XCTAssertEqual(documents[1].supersededByID, "document-current")
            for document in documents {
                XCTAssertNil(document.documentNumber)
                XCTAssertNil(document.reviewerNote)
                XCTAssertEqual(document.originalFilename, "Aadhaar document.pdf")
                XCTAssertEqual(document.verificationStatus, "pending_review")
            }
            XCTAssertFalse(String(reflecting: documents).contains("synthetic-"))
        }
    }

    func testAadhaarNeverDecodesMissingOrMalformedPrivateMetadata() async throws {
        let service = try await makeService()
        for omit in [false, true] {
            await MockURLProtocolStorage.shared.setHandler { request in
                var record = Self.metadataRecord(type: "aadhaar")
                for key in ["document_number", "reviewer_note", "original_filename"] {
                    if omit { record.removeValue(forKey: key) }
                    else { record[key] = ["unexpected": ["synthetic-private-secret"]] }
                }
                record["extracted_payload"] = ["nested": ["synthetic-extracted-secret"]]
                return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: [record]))
            }
            let documents = try await service.listDocuments()
            let document = try XCTUnwrap(documents.first)
            XCTAssertNil(document.documentNumber)
            XCTAssertNil(document.reviewerNote)
            XCTAssertEqual(document.originalFilename, "Aadhaar document.pdf")
        }
    }

    func testAadhaarFilteringAppliesOnEveryPageWithoutChangingPANOrDrivingLicenceMetadata() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems
            let offset = query?.first(where: { $0.name == "offset" })?.value
            let type: String
            switch offset {
            case "0": type = "pan"
            case "1": type = "aadhaar"
            case "2": type = "driving_license"
            default: throw URLError(.badURL)
            }
            return (try Self.response(for: request, statusCode: 200),
                    try JSONSerialization.data(withJSONObject: ["items": [Self.metadataRecord(type: type)], "total": 3]))
        }
        let documents = try await service.listDocuments()
        XCTAssertEqual(documents.map(\.documentType.rawValue), ["pan", "aadhaar", "driving_license"])
        XCTAssertNil(documents[1].documentNumber)
        XCTAssertEqual(documents[1].originalFilename, "Aadhaar document.pdf")
        for index in [0, 2] {
            XCTAssertEqual(documents[index].documentNumber, "synthetic-number-secret")
            XCTAssertEqual(documents[index].originalFilename, "synthetic-private-original.pdf")
            XCTAssertEqual(documents[index].reviewerNote, "synthetic-reviewer-secret")
        }
    }

    func testAadhaarGenericFilenameUsesOnlyAllowlistedContentType() {
        let expected = ["application/pdf": ".pdf", "image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp",
                        "application/unknown": ""]
        for (contentType, suffix) in expected {
            XCTAssertEqual(VaultDocumentType.aadhaar.metadataFilename("synthetic-private-original.pdf", contentType: contentType),
                           "Aadhaar document" + suffix)
        }
        XCTAssertFalse(VaultDocumentType.aadhaar.allowsDocumentNumber)
        for type in [VaultDocumentType.pan, .drivingLicense] {
            XCTAssertTrue(type.allowsDocumentNumber)
            XCTAssertEqual(type.metadataFilename("unchanged.pdf", contentType: "application/pdf"), "unchanged.pdf")
        }
    }

    func testVaultPaginationStopsOnEmptyPageOrMissingTotal() async throws {
        let service = try await makeService()
        for empty in [false, true] {
            await MockURLProtocolStorage.shared.reset()
            await MockURLProtocolStorage.shared.setHandler { request in
                let payload: [String: Any] = empty
                    ? ["items": [], "total": 100]
                    : ["items": [Self.metadataRecord(type: "aadhaar")]]
                return (try Self.response(for: request, statusCode: 200), try JSONSerialization.data(withJSONObject: payload))
            }
            let documents = try await service.listDocuments()
            XCTAssertEqual(documents.count, empty ? 0 : 1)
            let requests = await MockURLProtocolStorage.shared.requests()
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testAadhaarNewAndReplacementUploadsOmitNumberAndPrivateFilenameWithoutRedactingBytes() async throws {
        let service = try await makeService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("synthetic-private-original.pdf")
        let bytes = Data("%PDF-synthetic-private-file-contents".utf8)
        try bytes.write(to: fileURL)
        for replacement in [nil, "document-history"] as [String?] {
            await MockURLProtocolStorage.shared.reset()
            await MockURLProtocolStorage.shared.setHandler { request in
                switch (request.httpMethod, request.url?.path) {
                case ("POST", "/api/v1/user-documents/upload-intent"):
                    let body = try requestBodyData(from: request)
                    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                    XCTAssertEqual(json["document_type"] as? String, "aadhaar")
                    XCTAssertEqual(json["original_filename"] as? String, "Aadhaar document.pdf")
                    XCTAssertEqual(json["replaces_document_id"] as? String, replacement)
                    XCTAssertEqual(json["byte_size"] as? Int, bytes.count)
                    XCTAssertNil(json["document_number"])
                    XCTAssertFalse(String(decoding: body, as: UTF8.self).contains("synthetic-"))
                    return (try Self.response(for: request, statusCode: 201), Self.intentPayload)
                case ("PUT", "/vault-upload"):
                    XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                    XCTAssertEqual(try requestBodyData(from: request), bytes)
                    return (try Self.response(for: request, statusCode: 200), Data())
                case ("POST", "/api/v1/user-documents/document-current/complete-upload"):
                    return (try Self.response(for: request, statusCode: 200),
                            try JSONSerialization.data(withJSONObject: Self.metadataRecord(type: "aadhaar")))
                case ("GET", "/api/v1/user-documents"):
                    return (try Self.response(for: request, statusCode: 200),
                            try JSONSerialization.data(withJSONObject: [Self.metadataRecord(type: "aadhaar")]))
                default: throw URLError(.badURL)
                }
            }
            let documents = try await service.uploadDocument(fileURL: fileURL, type: .aadhaar,
                documentNumber: "synthetic-number-secret", expiresAt: nil, replacing: replacement)
            XCTAssertEqual(documents.first?.originalFilename, "Aadhaar document.pdf")
            XCTAssertNil(documents.first?.documentNumber)
            let requests = await MockURLProtocolStorage.shared.requests()
            XCTAssertEqual(requests.count, 4)
        }
    }

    func testMetadataUpdateUsesOwnerTypeToOmitAadhaarNumberButPreservesPANAndDrivingLicence() async throws {
        let service = try await makeService()
        for type in ["aadhaar", "pan", "driving_license"] {
            await MockURLProtocolStorage.shared.reset()
            await MockURLProtocolStorage.shared.setHandler { request in
                if request.httpMethod == "PATCH" {
                    XCTAssertEqual(request.url?.path, "/api/v1/user-documents/document-current")
                    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBodyData(from: request)) as? [String: Any])
                    if type == "aadhaar" { XCTAssertNil(json["document_number"]) }
                    else { XCTAssertEqual(json["document_number"] as? String, "synthetic-edited-number") }
                    XCTAssertEqual(json["expires_at"] as? String, "1970-01-01")
                    if type == "aadhaar" {
                        return (try Self.response(for: request, statusCode: 200),
                                try JSONSerialization.data(withJSONObject: Self.metadataRecord(type: type)))
                    }
                    return (try Self.response(for: request, statusCode: 204), Data())
                }
                XCTAssertEqual(request.httpMethod, "GET")
                return (try Self.response(for: request, statusCode: 200),
                        try JSONSerialization.data(withJSONObject: [Self.metadataRecord(type: type)]))
            }
            let documents = try await service.updateMetadata(documentID: "document-current",
                documentNumber: " synthetic-edited-number ", expiresAt: Date(timeIntervalSince1970: 0))
            if type == "aadhaar" {
                XCTAssertNil(documents.first?.documentNumber)
                XCTAssertNil(documents.first?.reviewerNote)
                XCTAssertEqual(documents.first?.originalFilename, "Aadhaar document.pdf")
            }
            let requests = await MockURLProtocolStorage.shared.requests()
            XCTAssertEqual(requests.map(\.httpMethod), ["GET", "PATCH", "GET"])
        }
    }

    func testPANAndDrivingLicenceUploadsKeepOriginalFilenameAndNumber() async throws {
        let service = try await makeService()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("unchanged.pdf")
        try Data("%PDF-synthetic-fixture".utf8).write(to: fileURL)
        for type in [VaultDocumentType.pan, .drivingLicense] {
            await MockURLProtocolStorage.shared.setHandler { request in
                switch (request.httpMethod, request.url?.path) {
                case ("POST", "/api/v1/user-documents/upload-intent"):
                    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBodyData(from: request)) as? [String: Any])
                    XCTAssertEqual(json["document_type"] as? String, type.rawValue)
                    XCTAssertEqual(json["document_number"] as? String, "synthetic-number")
                    XCTAssertEqual(json["original_filename"] as? String, "unchanged.pdf")
                    return (try Self.response(for: request, statusCode: 201), Self.intentPayload)
                case ("PUT", "/vault-upload"), ("POST", "/api/v1/user-documents/document-current/complete-upload"):
                    return (try Self.response(for: request, statusCode: 200), Data("{}".utf8))
                case ("GET", "/api/v1/user-documents"):
                    return (try Self.response(for: request, statusCode: 200), Data("[]".utf8))
                default: throw URLError(.badURL)
                }
            }
            _ = try await service.uploadDocument(fileURL: fileURL, type: type,
                documentNumber: " synthetic-number ", expiresAt: nil, replacing: nil)
        }
    }

    func testMetadataUpdateWithoutKnownOwnerTypeFailsBeforePatch() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(for: request, statusCode: 200), Data("[]".utf8))
        }
        do {
            _ = try await service.updateMetadata(documentID: "missing", documentNumber: "synthetic-secret", expiresAt: nil)
            XCTFail("An unknown document type must not permit number transmission")
        } catch { XCTAssertEqual(error as? NetworkError, .invalidResponse) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET"])
    }

    func testVaultPrivateMetadataTransportRejectsNonJSONAndDoesNotEchoErrorBody() async throws {
        let service = try await makeService()
        for status in [200, 400] {
            await MockURLProtocolStorage.shared.setHandler { request in
                (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil,
                                              headerFields: ["Content-Type": "text/html"])),
                 Data("synthetic-private-error-body".utf8))
            }
            do { _ = try await service.listDocuments(); XCTFail("Private transport must reject the response") }
            catch { XCTAssertFalse(String(reflecting: error).contains("synthetic-private-error-body")) }
        }
    }

    func testAadhaarPatchResponseUsesPrivateJSONTransport() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.httpMethod == "PATCH" {
                return (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 200, httpVersion: nil,
                                                     headerFields: ["Content-Type": "text/html"])),
                        Data("synthetic-private-patch-response".utf8))
            }
            return (try Self.response(for: request, statusCode: 200),
                    try JSONSerialization.data(withJSONObject: [Self.metadataRecord(type: "aadhaar")]))
        }
        do {
            _ = try await service.updateMetadata(documentID: "document-current", documentNumber: "synthetic-secret", expiresAt: nil)
            XCTFail("Aadhaar PATCH responses must use private JSON transport")
        } catch { XCTAssertEqual(error as? NetworkError, .invalidResponse) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "PATCH"])
    }

    func testAadhaarDeleteStillAcceptsNoContentAndReloadsOwnerCollection() async throws {
        let service = try await makeService()
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.httpMethod == "DELETE" {
                XCTAssertEqual(request.url?.path, "/api/v1/user-documents/aadhaar-current")
                return (try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: 204, httpVersion: nil,
                                                    headerFields: nil)), Data())
            }
            XCTAssertEqual(request.url?.path, "/api/v1/user-documents")
            return (try Self.response(for: request, statusCode: 200), Data("[]".utf8))
        }
        let documents = try await service.deleteDocument(documentID: "aadhaar-current")
        XCTAssertTrue(documents.isEmpty)
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.map(\.httpMethod), ["DELETE", "GET"])
    }

    func testPassportAadhaarDocumentDiscardsPrivateFilenameBeforeDomainMapping() throws {
        let decoder = APIJSONCoder.makeDecoder()
        let privateValues: [Any] = ["synthetic-private-original.pdf", NSNull(), ["unexpected": "synthetic-private-secret"]]
        for value in privateValues {
            var payload = Self.metadataRecord(type: "aadhaar")
            payload["original_filename"] = value
            payload["extracted_payload"] = ["secret": "synthetic-private-secret"]
            let dto = try decoder.decode(PublicPassportDocumentDTO.self, from: JSONSerialization.data(withJSONObject: payload))
            XCTAssertEqual(dto.originalFilename, "Aadhaar document")
            XCTAssertEqual(dto.documentType, "aadhaar")
            XCTAssertEqual(dto.byteSize, 128)
            XCTAssertEqual(dto.verificationStatus, "pending_review")
            XCTAssertFalse(String(reflecting: dto).contains("synthetic-"))
            XCTAssertEqual(PassportDocumentRecordDomain(dto: dto).originalFilename, "Aadhaar document")
        }
        var missing = Self.metadataRecord(type: "aadhaar")
        missing.removeValue(forKey: "original_filename")
        let dto = try decoder.decode(PublicPassportDocumentDTO.self, from: JSONSerialization.data(withJSONObject: missing))
        XCTAssertEqual(dto.originalFilename, "Aadhaar document")
    }

    func testPassportNonAadhaarDocumentFilenamesAreNotClassifiedByTheirNames() throws {
        for type in ["pan", "driving_license", "other", "future_identity", "EAADHAAR"] {
            var payload = Self.metadataRecord(type: type)
            payload["original_filename"] = "aadhaar-in-filename-only.pdf"
            let dto = try APIJSONCoder.makeDecoder().decode(PublicPassportDocumentDTO.self,
                from: JSONSerialization.data(withJSONObject: payload))
            XCTAssertEqual(dto.documentType, type)
            XCTAssertEqual(dto.originalFilename, "aadhaar-in-filename-only.pdf")
        }
    }

    private nonisolated static func metadataRecord(type: String) -> [String: Any] {
        ["id": "document-current", "document_type": type, "document_number": "synthetic-number-secret",
         "original_filename": "synthetic-private-original.pdf", "reviewer_note": "synthetic-reviewer-secret",
         "content_type": "application/pdf", "byte_size": 128, "verification_status": "pending_review",
         "created_at": "2030-01-01T00:00:00Z", "updated_at": "2030-01-01T00:00:00Z"]
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
                headerFields: ["Content-Type": "application/json"]
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
