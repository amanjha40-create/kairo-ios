import CoreGraphics
import Foundation
import UIKit
import WebKit

nonisolated struct PassportPDFArtifact: Identifiable, Equatable, Sendable {
    let id: UUID
    let fileURL: URL
    let filename: String
    let byteCount: Int

    init(
        id: UUID = UUID(),
        fileURL: URL,
        filename: String,
        byteCount: Int
    ) {
        self.id = id
        self.fileURL = fileURL
        self.filename = filename
        self.byteCount = byteCount
    }
}

nonisolated enum PassportPDFExportError: Error, Equatable, LocalizedError, Sendable {
    case invalidContentType
    case emptyDocument
    case malformedDocument
    case invalidShareURL
    case shareUnavailable
    case exportTimedOut
    case temporaryStorageUnavailable
    case unavailableInDemoMode

    var errorDescription: String? {
        switch self {
        case .invalidContentType:
            "KairoID received an unexpected file type instead of a Passport PDF."
        case .emptyDocument:
            "KairoID received an empty Passport PDF."
        case .malformedDocument:
            "KairoID received a Passport PDF that could not be opened safely."
        case .invalidShareURL:
            "KairoID could not open this Passport share safely."
        case .shareUnavailable:
            "This Passport share is no longer available for download."
        case .exportTimedOut:
            "The shared Passport page did not finish preparing its PDF."
        case .temporaryStorageUnavailable:
            "KairoID could not prepare temporary storage for the Passport PDF."
        case .unavailableInDemoMode:
            "PDF export is unavailable in Demo Mode because Demo Mode never calls the live Passport service."
        }
    }
}

protocol PassportPDFExportServiceProtocol: Sendable {
    func exportPassportPDF(from publicURL: URL) async throws -> PassportPDFArtifact
    func removeArtifact(_ artifact: PassportPDFArtifact) async
    func removeAllArtifacts() async
}

actor PassportPDFExportService: PassportPDFExportServiceProtocol {
    nonisolated static let fallbackFilename = "KairoID-Shared-Passport.pdf"

    private let exportDirectoryURL: URL

    init(temporaryDirectory: URL? = nil) {
        exportDirectoryURL = (temporaryDirectory ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("KairoPassportPDFExports", isDirectory: true)

        // A previous process may have ended before its presentation callback ran.
        try? FileManager.default.removeItem(at: exportDirectoryURL)
    }

    func exportPassportPDF(from publicURL: URL) async throws -> PassportPDFArtifact {
        removeAllArtifactsImmediately()
        guard Self.isAllowedShareURL(publicURL) else {
            throw PassportPDFExportError.invalidShareURL
        }

        let download = try await SharedPassportPagePDFDownloader.download(from: publicURL)
        guard !download.data.isEmpty else { throw PassportPDFExportError.emptyDocument }
        guard Self.isValidPDF(download.data) else { throw PassportPDFExportError.malformedDocument }

        let filename = Self.safeFilename(download.filename)
        let artifactDirectory = exportDirectoryURL
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = artifactDirectory.appendingPathComponent(filename, isDirectory: false)

        do {
            try FileManager.default.createDirectory(
                at: artifactDirectory,
                withIntermediateDirectories: true
            )
            try download.data.write(to: fileURL, options: [.atomic])

            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var mutableFileURL = fileURL
            try? mutableFileURL.setResourceValues(resourceValues)

            let writtenData = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            guard writtenData.count == download.data.count,
                  Self.isValidPDF(writtenData) else {
                try? FileManager.default.removeItem(at: artifactDirectory)
                throw PassportPDFExportError.temporaryStorageUnavailable
            }

            return PassportPDFArtifact(
                fileURL: fileURL,
                filename: filename,
                byteCount: writtenData.count
            )
        } catch let error as PassportPDFExportError {
            throw error
        } catch {
            try? FileManager.default.removeItem(at: artifactDirectory)
            throw PassportPDFExportError.temporaryStorageUnavailable
        }
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        let artifactDirectory = artifact.fileURL.deletingLastPathComponent()
        guard artifactDirectory.deletingLastPathComponent() == exportDirectoryURL else { return }
        try? FileManager.default.removeItem(at: artifactDirectory)
    }

    func removeAllArtifacts() async {
        removeAllArtifactsImmediately()
    }

    nonisolated static func safeFilename(_ candidate: String?) -> String {
        guard let candidate else {
            return fallbackFilename
        }

        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed.count <= 120,
              !trimmed.hasPrefix("."),
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              !trimmed.contains(":"),
              trimmed.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              URL(fileURLWithPath: trimmed).pathExtension.lowercased() == "pdf"
        else {
            return fallbackFilename
        }

        return trimmed
    }

    private func removeAllArtifactsImmediately() {
        try? FileManager.default.removeItem(at: exportDirectoryURL)
    }

    nonisolated static func isAllowedShareURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              let host = url.host?.lowercased(),
              ["app.kairoid.com", "staging.kairoid.com", "demo.kairoid.invalid"].contains(host)
        else { return false }
        return url.path.split(separator: "/").count == 2 && url.path.hasPrefix("/passport/")
    }

    nonisolated static func isValidPDF(_ data: Data) -> Bool {
        let signature = Data("%PDF-".utf8)
        guard data.count >= signature.count,
              data.prefix(signature.count) == signature,
              let provider = CGDataProvider(data: data as CFData),
              let document = CGPDFDocument(provider),
              document.numberOfPages > 0 else {
            return false
        }

        return true
    }

}

actor UnavailablePassportPDFExportService: PassportPDFExportServiceProtocol {
    func exportPassportPDF(from publicURL: URL) async throws -> PassportPDFArtifact {
        _ = publicURL
        throw PassportPDFExportError.unavailableInDemoMode
    }

    func removeArtifact(_ artifact: PassportPDFArtifact) async {
        _ = artifact
    }

    func removeAllArtifacts() async {}
}

private nonisolated struct SharedPassportPagePDFDownload: Sendable {
    let data: Data
    let filename: String?
}

@MainActor
private final class SharedPassportPagePDFDownloader: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    private static let messageName = "kairoPassportPDF"
    private static let captureScript = #"""
    (() => {
      if (window.__kairoPassportPDFCaptureInstalled) return;
      window.__kairoPassportPDFCaptureInstalled = true;
      const original = URL.createObjectURL.bind(URL);
      URL.createObjectURL = function(blob) {
        if (blob && blob.type === "application/pdf") {
          const reader = new FileReader();
          reader.onloadend = () => window.webkit.messageHandlers.kairoPassportPDF.postMessage({
            filename: "KairoID-Shared-Passport.pdf",
            data: reader.result
          });
          reader.readAsDataURL(blob);
        }
        return original(blob);
      };
    })();
    """#

    private var continuation: CheckedContinuation<SharedPassportPagePDFDownload, Error>?
    private var webView: WKWebView?
    private var pollingTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var hostView: UIView?

    static func download(from url: URL) async throws -> SharedPassportPagePDFDownload {
        let downloader = SharedPassportPagePDFDownloader()
        return try await downloader.start(url: url)
    }

    private func start(url: URL) async throws -> SharedPassportPagePDFDownload {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let controller = WKUserContentController()
                controller.addUserScript(WKUserScript(
                    source: Self.captureScript,
                    injectionTime: .atDocumentStart,
                    forMainFrameOnly: true
                ))
                controller.add(self, name: Self.messageName)

                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .nonPersistent()
                configuration.userContentController = controller
                let webView = WKWebView(frame: CGRect(x: -2_000, y: 0, width: 430, height: 932), configuration: configuration)
                webView.navigationDelegate = self
                self.webView = webView
                attach(webView)
                webView.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30))

                timeoutTask = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(35))
                    guard !Task.isCancelled else { return }
                    self?.finish(.failure(PassportPDFExportError.exportTimedOut))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        _ = navigation
        pollingTask?.cancel()
        pollingTask = Task { [weak self, weak webView] in
            for _ in 0..<100 {
                guard !Task.isCancelled, let self, let webView else { return }
                let result = try? await webView.evaluateJavaScript(#"""
                (() => {
                  const button = document.querySelector('[data-testid="public-passport-download"]') ||
                    Array.from(document.querySelectorAll('button')).find((candidate) =>
                      (candidate.textContent || '').trim() === 'Download Passport'
                    );
                  if (button && !button.disabled) { button.click(); return "clicked"; }
                  const text = (document.body?.innerText || "").toLowerCase();
                  if (text.includes("passport link is unavailable") ||
                      text.includes("no longer available") ||
                      text.includes("not found")) return "unavailable";
                  return "waiting";
                })();
                """#) as? String
                if result == "clicked" { return }
                if result == "unavailable" {
                    finish(.failure(PassportPDFExportError.shareUnavailable))
                    return
                }
                try? await Task.sleep(for: .milliseconds(150))
            }
            self?.finish(.failure(PassportPDFExportError.exportTimedOut))
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        _ = (webView, navigation)
        finish(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        _ = (webView, navigation)
        finish(.failure(error))
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageName,
              let payload = message.body as? [String: Any],
              let encoded = payload["data"] as? String,
              let comma = encoded.firstIndex(of: ","),
              let data = Data(base64Encoded: String(encoded[encoded.index(after: comma)...]))
        else {
            finish(.failure(PassportPDFExportError.malformedDocument))
            return
        }
        finish(.success(SharedPassportPagePDFDownload(
            data: data,
            filename: payload["filename"] as? String
        )))
        _ = userContentController
    }

    private func attach(_ webView: WKWebView) {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController?.view else { return }
        root.addSubview(webView)
        hostView = root
    }

    private func finish(_ result: Result<SharedPassportPagePDFDownload, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        pollingTask?.cancel()
        timeoutTask?.cancel()
        pollingTask = nil
        timeoutTask = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.messageName)
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        hostView = nil
        continuation.resume(with: result)
    }
}
