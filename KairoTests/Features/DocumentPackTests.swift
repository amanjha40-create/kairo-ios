import XCTest
@testable import Kairo

@MainActor
final class DocumentPackTests: XCTestCase {
    let files = DemoDocumentPackService.fixtures
    override func tearDown() async throws { await MockURLProtocolStorage.shared.reset(); try await super.tearDown() }

    func testZeroSelectionRejected() { XCTAssertThrowsError(try input(files: [])) }
    func testPurposeTrimsWhitespace() throws { XCTAssertEqual(try input(purpose: "  Employment onboarding \n").purpose, "Employment onboarding") }
    func testBlankPurposeRejected() { XCTAssertThrowsError(try input(purpose: " \n\t")) }
    func testLongPurposeRejected() { XCTAssertThrowsError(try input(purpose: String(repeating: "a", count: 121))) }
    func testPurposeBoundaryAccepted() throws { XCTAssertEqual(try input(purpose: String(repeating: "a", count: 120)).purpose.count, 120) }
    func testPurposeCountsUnicodeScalarsLikeBackend() { XCTAssertThrowsError(try input(purpose: String(repeating: "👨‍👩‍👧‍👦", count: 20))) }
    func testExpiryOptionsExactAndSevenDayDefault() {
        XCTAssertEqual(DocumentPackLimits.expiryDays, [1, 3, 7, 14, 30]); XCTAssertEqual(DocumentPackStore().expiryDays, 7)
        XCTAssertThrowsError(try DocumentPackCreate(purpose: "Example", expiryDays: 0, documents: files))
    }
    func testDuplicateSelectionRejected() { XCTAssertThrowsError(try input(files: [files[0], files[0]])) }
    func testFileCountLimit() {
        let items = (0..<21).map { makeFile(id: String($0), size: 1) }
        XCTAssertThrowsError(try input(files: items))
        XCTAssertNoThrow(try input(files: Array(items.prefix(20))))
    }
    func testAggregateLimitAndOverflowSafety() {
        XCTAssertThrowsError(try input(files: [makeFile(id: "one", size: Int.max)]))
        XCTAssertThrowsError(try input(files: [makeFile(id: "one", size: DocumentPackLimits.maximumBytes), makeFile(id: "two", size: 1)]))
        XCTAssertNoThrow(try input(files: [makeFile(id: "one", size: DocumentPackLimits.maximumBytes)]))
    }
    func testCreateDTOContainsOnlyExplicitSelectionPurposeExpiry() throws {
        let data = try APIJSONCoder.makeEncoder().encode(input(files: [files[1]]))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(json.keys), ["purpose", "expiry_days", "items"])
        let item = try XCTUnwrap((json["items"] as? [[String: String]])?.first)
        XCTAssertEqual(Set(item.keys), ["source_type", "source_id", "selection_version"])
        XCTAssertEqual(item["source_id"], files[1].sourceId)
    }
    func testCanonicalURLPreservedForAllActionsAndDescriptionsRedacted() throws {
        let cap = try capability()
        XCTAssertEqual(cap.copyURL, cap.qrURL); XCTAssertEqual(cap.copyURL, cap.shareURL); XCTAssertEqual(cap.copyURL, cap.previewURL)
        XCTAssertEqual(cap.url.absoluteString, Self.fixtureURL)
        XCTAssertFalse(String(describing: cap).contains(cap.token)); XCTAssertFalse(String(reflecting: cap).contains(cap.token))
    }
    func testMalformedOrUnapprovedCapabilityRejected() {
        for value in ["http://demo.invalid/document-pack#token=" + Self.token, "https://evil.invalid/document-pack#token=" + Self.token,
                      "https://demo.invalid/document-pack?token=" + Self.token, "https://demo.invalid/passport/" + Self.token,
                      "https://user@demo.invalid/document-pack#token=" + Self.token, Self.fixtureURL + "&extra=1"] {
            XCTAssertThrowsError(try DocumentPackCapability(serverURL: value, allowedHosts: ["demo.invalid"]))
        }
    }
    func testHistoryStatesAndAnalytics() throws {
        for state in ["active", "expired", "revoked"] {
            let data = try Self.packData(status: state)
            let pack = try APIJSONCoder.makeDecoder().decode(DocumentPack.self, from: data)
            XCTAssertEqual(pack.status, state); XCTAssertEqual(pack.viewCount, 3); XCTAssertNotNil(pack.lastViewedAt)
            XCTAssertEqual(pack.documentCount, 1); XCTAssertEqual(pack.items.first?.filename, "synthetic.pdf")
            XCTAssertEqual(pack.isActive, state == "active")
        }
    }
    func testPublicDTOIgnoresPrivateFieldsAndPreservesSnapshot() throws {
        let pack = try APIJSONCoder.makeDecoder().decode(PublicDocumentPack.self, from: Self.packData())
        let representation = String(describing: pack)
        XCTAssertFalse(representation.contains("source_id")); XCTAssertFalse(representation.contains("trust_score"))
        XCTAssertEqual(pack.items.first?.context, "Synthetic Company")
    }
    func testServerEligibleCatalogPaginatedAndAuthenticated() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.path, "/api/v1/document-share-packs/documents")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-only-access")
            let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "page" })?.value
            return try Self.response(request, json: ["items": page == "1" ? [Self.fileJSON] : [], "total": 1, "total_pages": 2])
        }
        let documents = try await service.documents()
        XCTAssertEqual(documents.count, 1); XCTAssertEqual(documents[0].selectionVersion, String(repeating: "a", count: 64))
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 2)
    }
    func testCreateExactMappingAndNoAutomaticReplay() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "POST"); XCTAssertEqual(request.url?.path, "/api/v1/document-share-packs")
            let body = try requestJSONBody(from: request)
            XCTAssertEqual(body["purpose"] as? String, "Example"); XCTAssertEqual(body["expiry_days"] as? Int, 7)
            var json = try Self.packJSON(); json["share_url"] = Self.fixtureURL
            return try Self.response(request, json: json, status: 201)
        }
        let result = try await service.create(input())
        XCTAssertEqual(result.capability.url.absoluteString, Self.fixtureURL)
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }
    func testCreateValidationAndAuthorizationErrorsAreSafeToCorrect() async throws {
        let service = try await service()
        for (status, expected) in [(422, DocumentPackError.rejected), (404, .unavailable), (403, .unauthorized), (401, .unauthorized)] {
            await MockURLProtocolStorage.shared.setHandler { request in try Self.response(request, json: ["secret": "must-not-be-shown"], status: status) }
            do { _ = try await service.create(input()); XCTFail("Expected rejection") }
            catch { XCTAssertEqual(error as? DocumentPackError, expected); XCTAssertFalse(error.localizedDescription.contains("must-not-be-shown")) }
        }
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 4)
    }
    func testCreateNetworkOrServerFailureIsAmbiguousNotRetryable() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { _ in throw URLError(.timedOut) }
        do { _ = try await service.create(input()); XCTFail("Expected ambiguous failure") }
        catch { XCTAssertEqual(error as? DocumentPackError, .ambiguousCreation) }
    }
    func testRevokeUsesExactPackIDThenIdempotentServerState() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/api/v1/document-share-packs/" + DemoDocumentPackService.activeID + "/revoke")
            return try Self.response(request, data: Self.packData(status: "revoked"))
        }
        let first = try await service.revoke(id: DemoDocumentPackService.activeID)
        let second = try await service.revoke(id: DemoDocumentPackService.activeID)
        XCTAssertEqual(first.status, "revoked"); XCTAssertEqual(first, second)
    }
    func testRevokeUnavailableAndForbidden() async throws {
        let service = try await service()
        for (status, expected) in [(404, DocumentPackError.unavailable), (403, .unauthorized)] {
            await MockURLProtocolStorage.shared.setHandler { request in try Self.response(request, json: [:], status: status) }
            do { _ = try await service.revoke(id: DemoDocumentPackService.activeID); XCTFail("Expected failure") }
            catch { XCTAssertEqual(error as? DocumentPackError, expected) }
        }
    }
    func testPublicRecipientHasNoOwnerAuthenticationAndExactlyOneViewRequest() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization")); XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertTrue(request.url!.path.hasPrefix("/api/v1/public/document-share-packs/"))
            return try Self.response(request, data: Self.packData())
        }
        _ = try await service.recipient(capability())
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }
    func testSignedContentRejectsRawStorageOtherItemAndQueries() throws {
        let path = "/api/v1/public/document-share-packs/" + Self.token + "/items/" + DemoDocumentPackService.activeID + "/content"
        let query = "?expires=9999999999&signature=" + String(repeating: "a", count: 64)
        XCTAssertNoThrow(try DocumentPackService.validatedContentPath(path + query, expectedPath: path))
        for value in ["https://s3.example.invalid" + path + query, "//s3.example.invalid" + path + query, path + query + "&other=1", path + "-other" + query] {
            XCTAssertThrowsError(try DocumentPackService.validatedContentPath(value, expectedPath: path))
        }
    }
    func testPrivateJSONRejectsRedirectAndUnsupportedMIME() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            (HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: nil, headerFields: ["Location": "https://storage.invalid/private"])!, Data())
        }
        do { _ = try await service.history(); XCTFail("Redirect must fail") } catch { }
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }
    func testStateExplicitSelectionFilteringAndDeselect() async {
        let store = DocumentPackStore(); await store.loadDocuments(DemoDocumentPackService())
        XCTAssertTrue(store.selected.isEmpty); XCTAssertFalse(store.canContinue)
        store.toggle(files[0]); store.toggle(files[1]); XCTAssertEqual(store.selected.count, 2)
        store.category = "identity"; XCTAssertEqual(store.visible.count, 1); XCTAssertEqual(store.selected.count, 2)
        store.toggle(files[0]); XCTAssertEqual(store.selected, [files[1]])
        store.clearSelection(); XCTAssertTrue(store.selected.isEmpty)
    }
    func testStateCannotSelectOutsideCatalog() async {
        let store = DocumentPackStore(); await store.loadDocuments(DemoDocumentPackService())
        store.toggle(makeFile(id: "historical-evidence", size: 1)); XCTAssertTrue(store.selected.isEmpty)
    }
    func testStatePurposeExpiryReviewAndSingleCreate() async {
        let service = DemoDocumentPackService(); let store = DocumentPackStore()
        await store.loadDocuments(service); store.toggle(files[0]); store.next()
        XCTAssertEqual(store.step, .purpose); XCTAssertFalse(store.canContinue)
        store.purpose = "Example"; store.next(); XCTAssertEqual(store.step, .expiry)
        store.expiryDays = 3; store.next(); XCTAssertEqual(store.step, .review)
        async let first: Void = store.create(service)
        async let second: Void = store.create(service)
        _ = await (first, second)
        XCTAssertEqual(store.creation?.pack.documentCount, 1)
        let history = try? await service.history(); XCTAssertEqual(history?.filter { $0.id == DemoDocumentPackService.createdID }.count, 1)
    }
    func testStateAmbiguousCreationCannotRetry() async {
        let service = DemoDocumentPackService(scenario: "create-ambiguous"); let store = DocumentPackStore()
        await store.loadDocuments(service); store.toggle(files[0]); store.purpose = "Example"
        await store.create(service); XCTAssertTrue(store.ambiguous); XCTAssertFalse(store.canCreate)
        await store.create(service); XCTAssertNil(store.creation)
    }
    func testRejectedCreateCanRetryWithoutAFirstSuccess() async {
        let service = DemoDocumentPackService(scenario: "create-rejected"); let store = DocumentPackStore()
        await store.loadDocuments(service); store.toggle(files[0]); store.purpose = "Example"
        await store.create(service); XCTAssertEqual(store.error, .rejected); XCTAssertTrue(store.canCreate)
        await store.create(service); XCTAssertNotNil(store.creation)
    }
    func testSessionChangeClearsCapabilitiesAndLateCreate() async {
        let service = DemoDocumentPackService(); let store = DocumentPackStore()
        await store.loadDocuments(service); store.toggle(files[0]); store.purpose = "Example"
        let task = Task { await store.create(service) }
        await Task.yield(); store.endSession(); await task.value
        XCTAssertNil(store.creation); XCTAssertTrue(store.selected.isEmpty); XCTAssertTrue(store.purpose.isEmpty)
    }
    func testRevokeRefreshesAuthoritativeHistoryWithoutTouchingSources() async {
        let service = DemoDocumentPackService(); let store = DocumentPackStore()
        let before = try? await service.documents()
        await store.revoke(DemoDocumentPackService.activeID, service: service)
        XCTAssertEqual(store.detail?.status, "revoked"); XCTAssertEqual(store.packs.first?.status, "revoked")
        let after = try? await service.documents(); XCTAssertEqual(before, after)
    }
    func testRoutingUsesCanonicalDocumentsPresentation() {
        let router = AppRouter(); router.showDocumentPacks(); XCTAssertEqual(router.documentPackPresentation?.history, false)
        router.showDocumentPacks(history: true); XCTAssertEqual(router.documentPackPresentation?.history, true)
    }

    func testCatalogRefreshDropsChangedVersionInsteadOfSilentlySharingReplacement() async throws {
        let service = try await service(); let store = DocumentPackStore()
        await MockURLProtocolStorage.shared.setHandler { request in
            try Self.response(request, json: ["items": [Self.fileJSON], "total": 1, "total_pages": 1])
        }
        await store.loadDocuments(service)
        store.toggle(try XCTUnwrap(store.documents.first)); XCTAssertEqual(store.selected.count, 1)
        await MockURLProtocolStorage.shared.setHandler { request in
            var changed = Self.fileJSON; changed["selection_version"] = String(repeating: "b", count: 64)
            return try Self.response(request, json: ["items": [changed], "total": 1, "total_pages": 1])
        }
        await store.loadDocuments(service)
        XCTAssertEqual(store.documents.count, 1); XCTAssertTrue(store.selected.isEmpty); XCTAssertFalse(store.canContinue)
    }

    func testPublicContentUsesOnlySignedProxyWithoutOwnerCredentials() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.url?.host, "staging-api.kairoid.com")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            if request.url!.path.hasSuffix("/download-url") {
                let path = request.url!.path.replacingOccurrences(of: "/download-url", with: "/content")
                return try Self.response(request, json: ["download_url": path + "?expires=9999999999&signature=" + String(repeating: "a", count: 64), "expires_in_seconds": 60])
            }
            XCTAssertTrue(request.url!.path.hasSuffix("/content"))
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/pdf", "Content-Length": "8"])!, Data("%PDF-QA!".utf8))
        }
        let content = try await service.content(capability(), itemID: DemoDocumentPackService.activeID)
        XCTAssertEqual(content.contentType, "application/pdf")
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 2)
    }
    func testInvalidSignedDownloadNeverRequestsStorageHost() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            try Self.response(request, json: ["download_url": "https://storage.invalid/private", "expires_in_seconds": 60])
        }
        do { _ = try await service.content(capability(), itemID: DemoDocumentPackService.activeID); XCTFail("Unsafe URL accepted") }
        catch { XCTAssertEqual(error as? DocumentPackError, .unavailable) }
        let requests = await MockURLProtocolStorage.shared.requests(); XCTAssertEqual(requests.count, 1)
    }
    func testHistoryDetailDoNotLoadPublicRecipientOrReissueURL() async throws {
        let service = try await service()
        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertFalse(request.url!.path.contains("/public/"))
            if request.url!.path.hasSuffix(DemoDocumentPackService.activeID) { return try Self.response(request, data: Self.packData()) }
            return try Self.response(request, json: ["items": [Self.packJSON()], "total": 1, "total_pages": 1])
        }
        let history = try await service.history(); let detail = try await service.detail(id: DemoDocumentPackService.activeID)
        XCTAssertEqual(history.first, detail)
        XCTAssertFalse(String(describing: detail).contains(Self.token))
    }
    func testUnknownPackStatusFailsClosed() throws {
        let pack = try APIJSONCoder.makeDecoder().decode(DocumentPack.self, from: Self.packData(status: "future_status"))
        XCTAssertFalse(pack.isActive); XCTAssertEqual(pack.statusTitle, "Unavailable")
    }
    func testHistoryEmptyAndErrorRetryStates() async {
        let store = DocumentPackStore()
        await store.loadHistory(DemoDocumentPackService(scenario: "empty")); XCTAssertTrue(store.packs.isEmpty)
        let failing = DemoDocumentPackService(scenario: "error")
        await store.loadHistory(failing); XCTAssertEqual(store.error, .connection)
        await store.loadHistory(failing); XCTAssertNil(store.error); XCTAssertEqual(store.packs.count, 3)
    }
    func testSuccessfulCreationCannotBeResubmitted() async {
        let service = DemoDocumentPackService(); let store = DocumentPackStore()
        await store.loadDocuments(service); store.toggle(files[0]); store.purpose = "Example"
        await store.create(service); XCTAssertFalse(store.canCreate)
        await store.create(service)
        let history = try? await service.history(); XCTAssertEqual(history?.filter { $0.id == DemoDocumentPackService.createdID }.count, 1)
    }
    func testRevokeDropsRetainedCapabilityAndKeepsSelectedSnapshot() async {
        let service = DemoDocumentPackService(); let store = DocumentPackStore()
        await store.loadDocuments(service); store.toggle(files[0]); store.purpose = "Example"
        await store.create(service); let items = store.creation?.pack.items
        await store.revoke(DemoDocumentPackService.createdID, service: service)
        XCTAssertNil(store.creation); XCTAssertEqual(store.detail?.items, items); XCTAssertEqual(store.detail?.status, "revoked")
    }
    func testPrivateJSONRejectsHTMLAndOversizedDeclaredResponse() async throws {
        let service = try await service()
        for headers in [["Content-Type": "text/html"], ["Content-Type": "application/json", "Content-Length": "999999999"]] {
            await MockURLProtocolStorage.shared.setHandler { request in
                (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: headers)!, Data("{}".utf8))
            }
            do { _ = try await service.history(); XCTFail("Unsupported response accepted") } catch { }
        }
    }

    private func input(purpose: String = "Example", files: [PackSelectableDocument]? = nil) throws -> DocumentPackCreate {
        try .init(purpose: purpose, expiryDays: 7, documents: files ?? self.files)
    }
    private func makeFile(id: String, size: Int) -> PackSelectableDocument {
        .init(sourceType: "vault", sourceId: id, selectionVersion: String(repeating: "a", count: 64), category: "identity", title: "Fixture", context: nil, filename: "fixture.pdf", contentType: "application/pdf", byteSize: size)
    }
    private func capability() throws -> DocumentPackCapability { try .init(serverURL: Self.fixtureURL, allowedHosts: ["demo.invalid"]) }
    private func service() async throws -> DocumentPackService {
        let client = URLSessionNetworkClient(baseURL: URL(string: "https://staging-api.kairoid.com/api/v1")!, session: makeMockedURLSession())
        let tokens = InMemoryTokenStore(); try await tokens.save("test-only-access", for: .accessToken)
        let session = SessionService(configuration: .resolve(), networkClient: client, tokenStore: tokens)
        return DocumentPackService(session: session, publicClient: client, allowedHosts: ["demo.invalid"])
    }
    nonisolated static let token = String(repeating: "A", count: 43)
    nonisolated static let fixtureURL = "https://demo.invalid/document-pack#token=" + token
    nonisolated static var fileJSON: [String: Any] {
        ["source_type": "vault", "source_id": DemoDocumentPackService.activeID, "selection_version": String(repeating: "a", count: 64), "category": "identity", "title": "Synthetic", "context": NSNull(), "filename": "synthetic.pdf", "content_type": "application/pdf", "byte_size": 10]
    }
    nonisolated static func packJSON(status: String = "active") throws -> [String: Any] {
        ["public_id": DemoDocumentPackService.activeID, "purpose": "Fixture purpose", "expires_at": "2099-01-01T00:00:00Z", "document_count": 1,
         "created_at": "2026-01-01T00:00:00Z", "revoked_at": status == "revoked" ? "2026-01-02T00:00:00Z" : NSNull(), "status": status,
         "view_count": 3, "last_viewed_at": "2026-01-01T01:00:00Z",
         "items": [["public_id": DemoDocumentPackService.activeID, "category": "employment", "title": "Synthetic letter", "context": "Synthetic Company", "filename": "synthetic.pdf", "content_type": "application/pdf", "byte_size": 10]]]
    }
    nonisolated static func packData(status: String = "active") throws -> Data { try JSONSerialization.data(withJSONObject: packJSON(status: status)) }
    nonisolated static func response(_ request: URLRequest, json: [String: Any], status: Int = 200) throws -> (HTTPURLResponse, Data) {
        try response(request, data: JSONSerialization.data(withJSONObject: json), status: status)
    }
    nonisolated static func response(_ request: URLRequest, data: Data, status: Int = 200) throws -> (HTTPURLResponse, Data) {
        (HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, data)
    }
}
