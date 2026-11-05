import UIKit
import PDFKit
import XCTest
@testable import Kairo

@MainActor
final class PassportPDFExportTests: XCTestCase {
    private let productionShareURL = URL(string: "https://app.kairoid.com/passport/opaque-test-token")!

    func test_exportAcceptsOnlyCanonicalHTTPSShareURLs() {
        XCTAssertTrue(PassportPDFExportService.isAllowedShareURL(productionShareURL))
        XCTAssertTrue(PassportPDFExportService.isAllowedShareURL(
            URL(string: "https://staging.kairoid.com/passport/opaque-test-token")!
        ))

        for url in [
            "http://app.kairoid.com/passport/token",
            "https://evil.example/passport/token",
            "https://app.kairoid.com/api/v1/passport/me/pdf",
            "https://app.kairoid.com/passport/token/extra",
            "https://app.kairoid.com/passport/"
        ] {
            XCTAssertFalse(PassportPDFExportService.isAllowedShareURL(URL(string: url)!))
        }
    }

    func test_exportRejectsLegacyOwnerPDFEndpoint() {
        let legacy = URL(string: "https://app.kairoid.com/api/v1/passport/me/pdf")!
        XCTAssertFalse(PassportPDFExportService.isAllowedShareURL(legacy))
    }

    func test_pdfValidationAcceptsRenderedPDFAndRejectsNonPDFPayloads() {
        XCTAssertTrue(PassportPDFExportService.isValidPDF(makeValidPDFData()))
        XCTAssertFalse(PassportPDFExportService.isValidPDF(Data()))
        XCTAssertFalse(PassportPDFExportService.isValidPDF(Data("%PDF- malformed".utf8)))
        XCTAssertFalse(PassportPDFExportService.isValidPDF(Data(#"{"detail":"not a pdf"}"#.utf8)))
    }

    func test_filenameUsesSharedPageNameAndRejectsUnsafeValues() {
        XCTAssertEqual(PassportPDFExportService.safeFilename(nil), "KairoID-Shared-Passport.pdf")
        XCTAssertEqual(
            PassportPDFExportService.safeFilename("KairoID-Shared-Passport.pdf"),
            "KairoID-Shared-Passport.pdf"
        )
        XCTAssertEqual(
            PassportPDFExportService.safeFilename("../../private.pdf"),
            "KairoID-Shared-Passport.pdf"
        )
        XCTAssertEqual(
            PassportPDFExportService.safeFilename("passport.json"),
            "KairoID-Shared-Passport.pdf"
        )
    }

    func test_presentationErrorsCoverShareAvailabilityAndCaptureFailures() {
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.invalidShareURL).title,
            "Unsafe Passport link"
        )
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.shareUnavailable).title,
            "Passport share unavailable"
        )
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.exportTimedOut).title,
            "PDF export timed out"
        )
        XCTAssertEqual(
            PassportPDFPresentationError.map(PassportPDFExportError.malformedDocument).title,
            "PDF could not be opened"
        )
    }

    func test_viewModelUsesExactShareURLAndPreventsDuplicateDownload() async throws {
        let service = DelayedPassportPDFExportService()
        let model = PassportPDFExportViewModel()

        model.startExport(from: productionShareURL, using: service)
        model.startExport(from: URL(string: "https://app.kairoid.com/passport/other")!, using: service)

        try await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(model.isDownloading)
        XCTAssertEqual(service.exportedURLs(), [productionShareURL])

        try await Task.sleep(for: .milliseconds(250))
        XCTAssertFalse(model.isDownloading)
        XCTAssertEqual(model.error?.title, "Demo export unavailable")
    }

    func test_viewModelLifecycleCancellationRequestsTemporaryCleanup() async throws {
        let service = DelayedPassportPDFExportService()
        let model = PassportPDFExportViewModel()

        model.startExport(from: productionShareURL, using: service)
        try await Task.sleep(for: .milliseconds(30))
        await model.endLifecycle(using: service)
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertFalse(model.isDownloading)
        XCTAssertNil(model.artifact)
        XCTAssertEqual(service.removeAllCount(), 1)
    }

    func test_configuredLiveSharedPageProducesOpenablePDF() async throws {
        guard let rawURL = ProcessInfo.processInfo.environment["KAIRO_PASSPORT_E2E_URL"],
              let publicURL = URL(string: rawURL) else {
            throw XCTSkip("Set KAIRO_PASSPORT_E2E_URL only for an approved active share.")
        }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PassportLiveExport-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = PassportPDFExportService(temporaryDirectory: root)
        let artifact = try await service.exportPassportPDF(from: publicURL)
        let document = try XCTUnwrap(PDFDocument(url: artifact.fileURL))

        XCTAssertEqual(artifact.filename, "KairoID-Shared-Passport.pdf")
        XCTAssertGreaterThan(artifact.byteCount, 1_000)
        XCTAssertGreaterThan(document.pageCount, 0)
        await service.removeArtifact(artifact)
        XCTAssertFalse(FileManager.default.fileExists(atPath: artifact.fileURL.path))
    }

    private func makeValidPDFData() -> Data {
        UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 320, height: 480)).pdfData { context in
            context.beginPage()
            "KairoID Trust Passport".draw(
                at: CGPoint(x: 24, y: 24),
                withAttributes: [.font: UIFont.systemFont(ofSize: 18, weight: .semibold)]
            )
        }
    }
}

@MainActor
private final class DelayedPassportPDFExportService: PassportPDFExportServiceProtocol {
    private var urls: [URL] = []
    private var removeAllCalls = 0

    func exportPassportPDF(from publicURL: URL) async throws -> PassportPDFArtifact {
        urls.append(publicURL)
        try await Task.sleep(for: .milliseconds(200))
        throw PassportPDFExportError.unavailableInDemoMode
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        _ = artifact
    }

    func removeAllArtifacts() async {
        removeAllCalls += 1
    }

    func exportedURLs() -> [URL] { urls }
    func removeAllCount() -> Int { removeAllCalls }
}
