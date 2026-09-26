import SwiftUI
import QuickLook
import UniformTypeIdentifiers

struct SecureDocumentPreview: Identifiable {
    let id = UUID()
    enum Source {
        case authorizedCareerURL(URL)
        case protectedCareerContent(CareerDocumentParent)
        case vault(documentID: String)
        case documentPack(DocumentPackCapability, itemID: String)
    }
    let source: Source
    let filename: String

    init(url: URL, filename: String) {
        source = .authorizedCareerURL(url)
        self.filename = filename
    }

    init(careerParent: CareerDocumentParent, filename: String) {
        source = .protectedCareerContent(careerParent)
        self.filename = filename
    }

    init(vaultDocumentID: String, filename: String) {
        source = .vault(documentID: vaultDocumentID)
        self.filename = filename
    }

    init(documentPack: DocumentPackCapability, itemID: String, filename: String) {
        source = .documentPack(documentPack, itemID: itemID)
        self.filename = filename
    }
}

/// No browser address bar, bearer header, persistent URL cache, or capability logging.
struct SecureDocumentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.documentVaultService) private var vault
    @Environment(\.documentPackService) private var documentPacks
    @Environment(\.careerDocumentService) private var careerDocuments
    @EnvironmentObject private var sessionStore: AppSessionStore
    let preview: SecureDocumentPreview
    @State private var localURL: URL?
    @State private var failed = false
    @State private var lifecycle = UUID()

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
            let lifecycle = lifecycle
            let generation = DocumentPreviewFileStore.shared.generation
            do {
                let content: ProtectedDocumentContent
                switch preview.source {
                case .vault(let id): content = try await vault.content(documentID: id)
                case .documentPack(let capability, let itemID): content = try await documentPacks.content(capability, itemID: itemID)
                case .protectedCareerContent(let parent): content = try await careerDocuments.protectedContent(for: parent)
                case .authorizedCareerURL(let url):
                    content = try await ProtectedDocumentContent(response: ProtectedDocumentTransport.send(URLRequest(url: url)))
                }
                try Task.checkCancellation()
                guard lifecycle == self.lifecycle else { return }
                localURL = try DocumentPreviewFileStore.shared.write(content, generation: generation)
            } catch is CancellationError { }
            catch { if lifecycle == self.lifecycle { failed = true } }
        }
        .onDisappear { cleanup() }
        .onChange(of: sessionStore.currentUser?.id) { _, _ in
            cleanup()
            dismiss()
        }
    }

    private func cleanup() {
        lifecycle = UUID()
        if let localURL { DocumentPreviewFileStore.shared.remove(localURL) }
        localURL = nil
    }
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
