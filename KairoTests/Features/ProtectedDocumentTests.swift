import Foundation
import XCTest
@testable import Kairo

@MainActor
final class ProtectedDocumentTests: XCTestCase {
    override func tearDown() async throws {
        DocumentPreviewFileStore.shared.clear()
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func testEphemeralConfigurationHasNoCacheCookiesOrCredentialStorage() {
        let configuration = ProtectedDocumentTransport.configuration()
        XCTAssertNil(configuration.urlCache)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertNil(configuration.urlCredentialStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 60)
    }

    func testUnsupportedMIMEAndJSONStorageURLAreRejectedAsNotDocumentBytes() throws {
        for mime in ["application/json", "text/html", "application/octet-stream", ""] {
            let response = NetworkResponse(data: Data(#"{"download_url":"https://storage.example/private"}"#.utf8),
                statusCode: 200, headers: ["Content-Type": mime])
            XCTAssertThrowsError(try ProtectedDocumentContent(response: response)) {
                XCTAssertEqual($0 as? ProtectedDocumentError, .unsupportedType)
            }
        }
    }

    func testAllSupportedMIMEsAndParameters() throws {
        for mime in ["application/pdf", "image/jpeg", "image/png", "image/webp"] {
            let content = try ProtectedDocumentContent(response: .init(data: Data([1]), statusCode: 200,
                headers: ["Content-Type": "\(mime.uppercased()); charset=binary"]))
            XCTAssertEqual(content.contentType, mime)
        }
    }

    func testEmptyOversizedAndTruncatedContentIsRejected() {
        for data in [Data(), Data(repeating: 0, count: ProtectedDocumentContent.maximumBytes + 1)] {
            XCTAssertThrowsError(try ProtectedDocumentContent(response: .init(data: data, statusCode: 200,
                headers: ["Content-Type": "application/pdf"])))
        }
        for length in ["2", "-1", "invalid", String(ProtectedDocumentContent.maximumBytes + 1)] {
            XCTAssertThrowsError(try ProtectedDocumentContent(response: .init(data: Data([1]), statusCode: 200,
                headers: ["Content-Type": "application/pdf", "Content-Length": length])))
        }
    }

    func testRFC5987FilenameIsDisplayOnlyAndUnsafeNamesFallBack() throws {
        let named = try content(disposition: "inline; filename*=UTF-8''Birth%20Certificate.pdf")
        XCTAssertEqual(named.filename, "Birth Certificate.pdf")
        for name in ["../secret.pdf", "C:\\secret.pdf", "https://storage.example/private.pdf", "bad\nname.pdf", ".hidden.pdf", "wrong.html"] {
            XCTAssertEqual(try content(disposition: "inline; filename=\"\(name)\"").filename, "Document.pdf")
        }
    }

    func testProtectedRandomTempFileAndDismissalCleanup() throws {
        let store = DocumentPreviewFileStore.shared
        let content = try content(disposition: "inline; filename=\"Sensitive Name.pdf\"")
        let first = try store.write(content, generation: store.generation)
        let second = try store.write(content, generation: store.generation)
        XCTAssertNotEqual(first, second)
        XCTAssertFalse(first.lastPathComponent.contains("Sensitive"))
        XCTAssertEqual(try Data(contentsOf: first), content.data)
        XCTAssertTrue(DocumentPreviewFileStore.writeOptions.contains(.completeFileProtection))
        XCTAssertTrue(DocumentPreviewFileStore.writeOptions.contains(.atomic))
        #if !targetEnvironment(simulator)
        // Simulator's macOS filesystem does not expose iOS Data Protection attributes.
        let attributes = try FileManager.default.attributesOfItem(atPath: first.path)
        XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .complete)
        #endif
        XCTAssertEqual(try first.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        store.remove(first)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
        store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.path))
    }

    func testSessionClearRemovesFilesAndRejectsLatePreviewWrites() async throws {
        let session = try await makeSession()
        let store = DocumentPreviewFileStore.shared
        let generation = store.generation
        let content = try content()
        let file = try store.write(content, generation: generation)
        try await session.clearSession()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertThrowsError(try store.write(content, generation: generation)) { XCTAssertTrue($0 is CancellationError) }
        let hasToken = try await session.hasStoredAccessToken()
        XCTAssertFalse(hasToken)
    }

    func testRedirectDelegateRejectsStorageDestination() async throws {
        let url = URL(string: "https://staging-api.kairoid.com/api/v1/user-documents/mock/content")!
        let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil,
                                       headerFields: ["Location": "https://storage.example/private"])!
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: url)
        let decision: URLRequest? = await withCheckedContinuation { continuation in
            NoDocumentRedirect().urlSession(session, task: task, willPerformHTTPRedirection: response,
                newRequest: URLRequest(url: URL(string: "https://storage.example/private")!)) {
                    continuation.resume(returning: $0)
                }
        }
        XCTAssertNil(decision)
    }

    func testRedirectResponseIsNotLoadedOrParsed() async throws {
        let service = DocumentVaultService(sessionService: try await makeSession())
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(request, status: 302, headers: ["Location": "https://storage.example/private"]), Data())
        }
        do { _ = try await service.content(documentID: "mock"); XCTFail("Redirect must fail closed") }
        catch { XCTAssertEqual(error as? ProtectedDocumentError, .unavailable) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests.allSatisfy { $0.url?.host == "staging-api.kairoid.com" })
    }

    func testUnauthorizedRefreshKeepsProtectedTransportAndOwnerAuthorization() async throws {
        let service = DocumentVaultService(sessionService: try await makeSession())
        await MockURLProtocolStorage.shared.setHandler { request in
            if request.url?.path == "/api/v1/auth/refresh" {
                return (try Self.response(request), Data(#"{"access_token":"new-mock","refresh_token":"new-refresh","token_type":"bearer"}"#.utf8))
            }
            XCTAssertEqual(request.url?.path, "/api/v1/user-documents/mock/content")
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer mock-access" {
                return (try Self.response(request, status: 401), Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer new-mock")
            return (try Self.response(request, headers: ["Content-Type": "application/pdf"]), Data("%PDF-mock".utf8))
        }
        let content = try await service.content(documentID: "mock")
        XCTAssertEqual(content.contentType, "application/pdf")
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 3)
        XCTAssertEqual(requests.filter { $0.url?.path.hasSuffix("/content") == true }.count, 2)
    }

    func testDeletedDocumentReturnsNotFoundWithoutAStorageRequest() async throws {
        let service = DocumentVaultService(sessionService: try await makeSession())
        await MockURLProtocolStorage.shared.setHandler { request in (try Self.response(request, status: 404), Data()) }
        do { _ = try await service.content(documentID: "deleted"); XCTFail("Deleted document must not load") }
        catch { guard case .api(let api) = error as? NetworkError else { return XCTFail("Expected API error") }; XCTAssertEqual(api.code, .notFound) }
        let requests = await MockURLProtocolStorage.shared.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testOfflineAndTimeoutUseSanitizedErrorWithoutURLs() async throws {
        let service = DocumentVaultService(sessionService: try await makeSession())
        for code in [URLError.notConnectedToInternet, .timedOut] {
            await MockURLProtocolStorage.shared.setHandler { _ in
                throw URLError(code, userInfo: [NSURLErrorFailingURLStringErrorKey: "https://storage.example/private"])
            }
            do { _ = try await service.content(documentID: "mock"); XCTFail("Must fail") }
            catch {
                XCTAssertEqual(error as? ProtectedDocumentError, .connection)
                XCTAssertFalse(error.localizedDescription.contains("https://"))
            }
        }
    }

    func testStreamingRejectsExcessBytesWithoutContentLength() async throws {
        await MockURLProtocolStorage.shared.setHandler { request in
            (try Self.response(request, headers: ["Content-Type": "application/pdf"]), Data(repeating: 1, count: 65))
        }
        do {
            _ = try await ProtectedDocumentTransport.send(URLRequest(url: URL(string: "https://staging-api.kairoid.com/mock")!),
                protocolClasses: [MockURLProtocol.self], maximumBytes: 64)
            XCTFail("Unbounded stream accepted")
        } catch { XCTAssertEqual(error as? ProtectedDocumentError, .tooLarge) }
    }

    func testTransportRejectsOversizedDeclaredLengthAndUnsupportedMIME() async throws {
        for headers in [["Content-Type": "text/html"],
                        ["Content-Type": "application/pdf", "Content-Length": String(ProtectedDocumentContent.maximumBytes + 1)]] {
            await MockURLProtocolStorage.shared.setHandler { request in (try Self.response(request, headers: headers), Data([1])) }
            do {
                _ = try await ProtectedDocumentTransport.send(URLRequest(url: URL(string: "https://staging-api.kairoid.com/mock")!), protocolClasses: [MockURLProtocol.self])
                XCTFail("Unsafe response accepted")
            } catch { XCTAssertTrue(error is ProtectedDocumentError) }
        }
    }

    private func content(disposition: String? = nil) throws -> ProtectedDocumentContent {
        var headers = ["Content-Type": "application/pdf"]
        headers["Content-Disposition"] = disposition
        return try ProtectedDocumentContent(response: .init(data: Data("%PDF-test".utf8), statusCode: 200, headers: headers))
    }

    private func makeSession() async throws -> SessionService {
        let tokens = InMemoryTokenStore()
        try await tokens.save("mock-access", for: .accessToken)
        try await tokens.save("mock-refresh", for: .refreshToken)
        let config = AppConfiguration(buildConfiguration: .staging, environment: .staging, isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging), keychainService: "tests.protected-document")
        return SessionService(configuration: config,
            networkClient: URLSessionNetworkClient(baseURL: config.apiBaseURL, session: makeMockedURLSession()), tokenStore: tokens)
    }

    private nonisolated static func response(_ request: URLRequest, status: Int = 200, headers: [String: String] = [:]) throws -> HTTPURLResponse {
        try XCTUnwrap(HTTPURLResponse(url: XCTUnwrap(request.url), statusCode: status, httpVersion: nil, headerFields: headers))
    }
}
