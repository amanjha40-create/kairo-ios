import Foundation
import UIKit
import XCTest
@testable import Kairo

@MainActor
final class PassportPDFExportTests: XCTestCase {
    override func tearDown() async throws {
        await MockURLProtocolStorage.shared.reset()
        try await super.tearDown()
    }

    func test_exportUsesAuthenticatedCanonicalEndpointAndPreservesSafeFilename() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-token", for: .accessToken)
        let pdfData = makeValidPDFData()

        await MockURLProtocolStorage.shared.setHandler { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/passport/me/pdf")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/pdf")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")

            return (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "application/pdf",
                        "Content-Disposition": "attachment; filename=\"Founder-Passport.pdf\""
                    ]
                )),
                pdfData
            )
        }

        let service = makeService(tokenStore: tokenStore, temporaryDirectory: root)
        let artifact = try await service.exportPassportPDF()

        XCTAssertEqual(artifact.filename, "Founder-Passport.pdf")
        XCTAssertEqual(artifact.byteCount, pdfData.count)
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.fileURL.path))
        XCTAssertTrue(artifact.fileURL.path.hasPrefix(root.path))

        await service.removeArtifact(artifact)
        XCTAssertFalse(FileManager.default.fileExists(atPath: artifact.fileURL.path))
    }

    func test_eachExportMakesFreshRequestAndReplacesPreviousTemporaryArtifact() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-token", for: .accessToken)
        let pdfData = makeValidPDFData()

        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/pdf"]
                )),
                pdfData
            )
        }

        let service = makeService(tokenStore: tokenStore, temporaryDirectory: root)
        let first = try await service.exportPassportPDF()
        let second = try await service.exportPassportPDF()
        let requests = await MockURLProtocolStorage.shared.requests()

        XCTAssertEqual(requests.filter { $0.url?.path == "/api/v1/passport/me/pdf" }.count, 2)
        XCTAssertNotEqual(first.fileURL, second.fileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: first.fileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: second.fileURL.path))

        await service.removeAllArtifacts()
        XCTAssertFalse(FileManager.default.fileExists(atPath: second.fileURL.path))
    }

    func test_exportRefreshesExpiredSessionOnceAndReplaysPDFRequest() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("expired-access", for: .accessToken)
        try await tokenStore.save("refresh-token", for: .refreshToken)
        let pdfData = makeValidPDFData()

        await MockURLProtocolStorage.shared.setHandler { request in
            switch request.url?.path {
            case "/api/v1/passport/me/pdf":
                if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired-access" {
                    return (
                        try XCTUnwrap(HTTPURLResponse(
                            url: try XCTUnwrap(request.url),
                            statusCode: 401,
                            httpVersion: nil,
                            headerFields: ["Content-Type": "application/json"]
                        )),
                        Data(#"{"error":{"code":"unauthorized","message":"Expired"}}"#.utf8)
                    )
                }

                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer refreshed-access")
                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/pdf"]
                    )),
                    pdfData
                )
            case "/api/v1/auth/refresh":
                return (
                    try XCTUnwrap(HTTPURLResponse(
                        url: try XCTUnwrap(request.url),
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: ["Content-Type": "application/json"]
                    )),
                    Data(
                        """
                        {
                          "access_token": "refreshed-access",
                          "refresh_token": "refreshed-token",
                          "token_type": "bearer",
                          "expires_in": 3600
                        }
                        """.utf8
                    )
                )
            default:
                XCTFail("Unexpected request")
                throw URLError(.badURL)
            }
        }

        let service = makeService(tokenStore: tokenStore, temporaryDirectory: root)
        let artifact = try await service.exportPassportPDF()
        let paths = await MockURLProtocolStorage.shared.requests().map(\.url?.path)

        XCTAssertEqual(paths, [
            "/api/v1/passport/me/pdf",
            "/api/v1/auth/refresh",
            "/api/v1/passport/me/pdf"
        ])
        XCTAssertTrue(FileManager.default.fileExists(atPath: artifact.fileURL.path))
    }

    func test_exportRejectsJSONEvenWhenServerReturnsHTTP200() async throws {
        try await assertExportFailure(
            data: Data(#"{"detail":"not a pdf"}"#.utf8),
            contentType: "application/json",
            expected: .invalidContentType
        )
    }

    func test_exportRejectsEmptyPDFResponse() async throws {
        try await assertExportFailure(
            data: Data(),
            contentType: "application/pdf",
            expected: .emptyDocument
        )
    }

    func test_exportRejectsMalformedPDFWithSignatureOnly() async throws {
        try await assertExportFailure(
            data: Data("%PDF-1.7 malformed".utf8),
            contentType: "application/pdf",
            expected: .malformedDocument
        )
    }

    func test_exportClassifiesTemporaryWriteFailure() async throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("blocking parent".utf8).write(to: root)
        defer { try? FileManager.default.removeItem(at: root) }

        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-token", for: .accessToken)
        let pdfData = makeValidPDFData()

        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": "application/pdf"]
                )),
                pdfData
            )
        }

        let service = makeService(tokenStore: tokenStore, temporaryDirectory: root)

        do {
            _ = try await service.exportPassportPDF()
            XCTFail("Expected temporary storage failure")
        } catch let error as PassportPDFExportError {
            XCTAssertEqual(error, .temporaryStorageUnavailable)
        }
    }

    func test_filenameFallsBackForMissingUnsafeOrNonPDFServerNames() {
        XCTAssertEqual(PassportPDFExportService.safeFilename(from: nil), "Kairo-Trust-Passport.pdf")
        XCTAssertEqual(
            PassportPDFExportService.safeFilename(from: "attachment; filename=\"../../private.pdf\""),
            "Kairo-Trust-Passport.pdf"
        )
        XCTAssertEqual(
            PassportPDFExportService.safeFilename(from: "attachment; filename=\"passport.json\""),
            "Kairo-Trust-Passport.pdf"
        )
        XCTAssertEqual(
            PassportPDFExportService.safeFilename(from: "attachment; filename*=UTF-8''Kairo%20Passport.pdf"),
            "Kairo Passport.pdf"
        )
    }

    func test_presentationErrorsAreDistinctForRequiredStatusCodesAndPayloadFailures() {
        let statusExpectations: [(Int, String)] = [
            (401, "Sign in required"),
            (403, "PDF access denied"),
            (404, "Passport PDF not found"),
            (429, "Too many PDF requests"),
            (500, "PDF export failed"),
            (503, "PDF export temporarily unavailable")
        ]

        for (statusCode, expectedTitle) in statusExpectations {
            let error = PassportPDFPresentationError.map(
                NetworkError.api(APIError(
                    statusCode: statusCode,
                    code: .internalError,
                    message: "server message",
                    fieldErrors: [:],
                    globalErrors: [],
                    validationDetails: []
                ))
            )
            XCTAssertEqual(error.title, expectedTitle)
        }

        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.invalidContentType).title,
            "Unexpected PDF response"
        )
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.emptyDocument).title,
            "Empty PDF"
        )
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.malformedDocument).title,
            "PDF could not be opened"
        )
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.temporaryStorageUnavailable).title,
            "PDF storage unavailable"
        )
    }

    func test_viewModelPreventsDuplicateDownloadWhileRequestIsInFlight() async throws {
        let service = DelayedPassportPDFExportService()
        let model = PassportPDFExportViewModel()

        model.startExport(using: service)
        model.startExport(using: service)

        try await Task.sleep(nanoseconds: 50_000_000)
        let exportCount = await service.exportCount()
        XCTAssertTrue(model.isDownloading)
        XCTAssertEqual(exportCount, 1)

        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertFalse(model.isDownloading)
        XCTAssertEqual(model.error?.title, "Demo export unavailable")
    }

    func test_viewModelLifecycleCancellationRequestsTemporaryCleanup() async throws {
        let service = DelayedPassportPDFExportService()
        let model = PassportPDFExportViewModel()

        model.startExport(using: service)
        try await Task.sleep(nanoseconds: 30_000_000)
        await model.endLifecycle(using: service)
        try await Task.sleep(nanoseconds: 30_000_000)
        let removeAllCount = await service.removeAllCount()

        XCTAssertFalse(model.isDownloading)
        XCTAssertNil(model.artifact)
        XCTAssertEqual(removeAllCount, 1)
    }

    private func assertExportFailure(
        data: Data,
        contentType: String,
        expected: PassportPDFExportError
    ) async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }

        let tokenStore = InMemoryTokenStore()
        try await tokenStore.save("access-token", for: .accessToken)
        await MockURLProtocolStorage.shared.setHandler { request in
            (
                try XCTUnwrap(HTTPURLResponse(
                    url: try XCTUnwrap(request.url),
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: ["Content-Type": contentType]
                )),
                data
            )
        }

        let service = makeService(tokenStore: tokenStore, temporaryDirectory: root)

        do {
            _ = try await service.exportPassportPDF()
            XCTFail("Expected export failure")
        } catch let error as PassportPDFExportError {
            XCTAssertEqual(error, expected)
        }
    }

    private func makeService(
        tokenStore: any TokenStore,
        temporaryDirectory: URL
    ) -> PassportPDFExportService {
        let configuration = AppConfiguration(
            buildConfiguration: .development,
            environment: .staging,
            isDemoModeEnabled: false,
            apiBaseURL: APIConfiguration.baseURL(for: .staging),
            keychainService: "com.kairoid.Kairo.tests.pdf"
        )
        let client = URLSessionNetworkClient(
            baseURL: configuration.apiBaseURL,
            session: makeMockedURLSession()
        )
        let sessionService = SessionService(
            configuration: configuration,
            networkClient: client,
            tokenStore: tokenStore
        )
        return PassportPDFExportService(
            sessionService: sessionService,
            temporaryDirectory: temporaryDirectory
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("PassportPDFExportTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func makeValidPDFData() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 480))
        return renderer.pdfData { context in
            context.beginPage()
            let text = "Kairo Trust Passport"
            text.draw(
                at: CGPoint(x: 24, y: 24),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .semibold)]
            )
        }
    }
}

private actor DelayedPassportPDFExportService: PassportPDFExportServiceProtocol {
    private var exports = 0
    private var removeAllCalls = 0

    func exportPassportPDF() async throws -> PassportPDFArtifact {
        exports += 1
        try await Task.sleep(nanoseconds: 200_000_000)
        throw PassportPDFExportError.unavailableInDemoMode
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        _ = artifact
    }

    func removeAllArtifacts() async {
        removeAllCalls += 1
    }

    func exportCount() -> Int { exports }
    func removeAllCount() -> Int { removeAllCalls }
}
