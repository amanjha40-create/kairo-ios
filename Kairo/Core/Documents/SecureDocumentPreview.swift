import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct SecureDocumentPreview: Identifiable {
    let id = UUID()
    let url: URL
    let filename: String
}

/// No browser address bar, bearer header, persistent URL cache, or capability logging.
struct SecureDocumentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preview: SecureDocumentPreview
    @State private var localURL: URL?
    @State private var failed = false

    var body: some View {
        NavigationStack {
            Group {
                if let localURL { LocalDocumentQuickLook(url: localURL) }
                else if failed { Text("This document could not be previewed securely. Close and try again.") }
                else { ProgressView("Opening document securely") }
            }
            .navigationTitle("Document preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task {
            do {
                let url = try SecureDocumentTransferClient.validatedDownloadURL(preview.url)
                let configuration = URLSessionConfiguration.ephemeral
                configuration.urlCache = nil
                configuration.httpCookieStorage = nil
                configuration.timeoutIntervalForResource = 60
                let session = URLSession(configuration: configuration, delegate: NoDocumentRedirect(), delegateQueue: nil)
                defer { session.invalidateAndCancel() }
                let (data, response) = try await session.data(from: url)
                guard let response = response as? HTTPURLResponse, response.statusCode == 200,
                      !data.isEmpty, data.count <= 50 * 1_024 * 1_024,
                      let mime = response.mimeType, SecureDocumentTransferClient.vaultContentTypes.contains(mime)
                else { throw SecureDocumentTransferError.invalidDownloadURL }
                try Task.checkCancellation()
                let suffix = UTType(mimeType: mime)?.preferredFilenameExtension ?? "pdf"
                let file = FileManager.default.temporaryDirectory.appendingPathComponent("kairoid-document-\(UUID().uuidString).\(suffix)")
                try data.write(to: file, options: [.atomic, .completeFileProtection])
                localURL = file
            } catch { failed = true }
        }
        .onDisappear {
            if let localURL { try? FileManager.default.removeItem(at: localURL) }
            localURL = nil
        }
    }
}

private final class NoDocumentRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

private struct LocalDocumentQuickLook: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem { url as NSURL }
    }
}
