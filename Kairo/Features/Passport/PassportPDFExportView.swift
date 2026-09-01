import Combine
import PDFKit
import SwiftUI
import UIKit

@MainActor
final class PassportPDFExportViewModel: ObservableObject {
    @Published private(set) var isDownloading = false
    @Published var artifact: PassportPDFArtifact?
    @Published private(set) var error: PassportPDFPresentationError?

    private var managedArtifact: PassportPDFArtifact?
    private var downloadTask: Task<Void, Never>?
    private var retriesAfterPreviewDismissal = false

    func startExport(using service: any PassportPDFExportServiceProtocol) {
        guard !isDownloading else { return }

        isDownloading = true
        error = nil
        downloadTask = Task { [weak self] in
            do {
                if let existing = self?.managedArtifact {
                    await service.removeArtifact(existing)
                }

                let exportedArtifact = try await service.exportPassportPDF()
                guard !Task.isCancelled else {
                    await service.removeArtifact(exportedArtifact)
                    return
                }

                self?.managedArtifact = exportedArtifact
                self?.artifact = exportedArtifact
                self?.isDownloading = false
                self?.downloadTask = nil
            } catch is CancellationError {
                self?.isDownloading = false
                self?.downloadTask = nil
            } catch {
                guard !Task.isCancelled else {
                    self?.isDownloading = false
                    self?.downloadTask = nil
                    return
                }
                self?.error = .map(error)
                self?.isDownloading = false
                self?.downloadTask = nil
            }
        }
    }

    func retry(using service: any PassportPDFExportServiceProtocol) {
        startExport(using: service)
    }

    func cleanupDismissedPreview(using service: any PassportPDFExportServiceProtocol) async {
        artifact = nil
        if let managedArtifact {
            await service.removeArtifact(managedArtifact)
        }
        managedArtifact = nil

        if retriesAfterPreviewDismissal {
            retriesAfterPreviewDismissal = false
            startExport(using: service)
        }
    }

    func retryAfterPreviewDismissal() {
        retriesAfterPreviewDismissal = true
    }

    func endLifecycle(using service: any PassportPDFExportServiceProtocol) async {
        downloadTask?.cancel()
        downloadTask = nil
        artifact = nil
        managedArtifact = nil
        retriesAfterPreviewDismissal = false
        isDownloading = false
        await service.removeAllArtifacts()
    }
}

struct PassportPDFPresentationError: Identifiable, Equatable {
    let title: String
    let message: String
    var id: String { title + "|" + message }

    static func map(_ error: Error) -> PassportPDFPresentationError {
        if let exportError = error as? PassportPDFExportError {
            switch exportError {
            case .invalidContentType:
                return .init(
                    title: "Unexpected PDF response",
                    message: exportError.localizedDescription
                )
            case .emptyDocument:
                return .init(
                    title: "Empty PDF",
                    message: exportError.localizedDescription
                )
            case .malformedDocument:
                return .init(
                    title: "PDF could not be opened",
                    message: exportError.localizedDescription
                )
            case .temporaryStorageUnavailable:
                return .init(
                    title: "PDF storage unavailable",
                    message: exportError.localizedDescription
                )
            case .unavailableInDemoMode:
                return .init(
                    title: "Demo export unavailable",
                    message: exportError.localizedDescription
                )
            }
        }

        if let sessionError = error as? SessionServiceError {
            _ = sessionError
            return .init(
                title: "Sign in required",
                message: "Your session is no longer valid. Sign in again before downloading your Passport PDF."
            )
        }

        if let networkError = error as? NetworkError {
            switch networkError {
            case .api(let apiError):
                return map(apiError)
            case .transport(let message) where message.localizedCaseInsensitiveContains("timed out"):
                return .init(
                    title: "PDF request timed out",
                    message: "The Passport PDF was not downloaded. Check your connection and retry."
                )
            case .transport:
                return .init(
                    title: "Network unavailable",
                    message: "Kairo could not reach Passport export. Check your connection and retry."
                )
            case .invalidResponse:
                return .init(
                    title: "Invalid PDF response",
                    message: "The server did not return a usable Passport PDF response."
                )
            case .invalidURL:
                return .init(
                    title: "PDF export unavailable",
                    message: "Kairo could not construct the Passport PDF request."
                )
            case .unavailableInDemoMode:
                return .init(
                    title: "Demo export unavailable",
                    message: "Demo Mode never calls the live Passport PDF service."
                )
            }
        }

        return .init(
            title: "PDF export failed",
            message: "Kairo could not download this Passport PDF. Retry when your connection is available."
        )
    }

    private static func map(_ error: APIError) -> PassportPDFPresentationError {
        switch error.statusCode {
        case 401:
            return .init(
                title: "Sign in required",
                message: "Your session is no longer valid. Sign in again before downloading your Passport PDF."
            )
        case 403:
            return .init(
                title: "PDF access denied",
                message: "This account is not allowed to export the Passport PDF."
            )
        case 404:
            return .init(
                title: "Passport PDF not found",
                message: "Complete your Trust Passport before trying this export again."
            )
        case 429:
            return .init(
                title: "Too many PDF requests",
                message: "Passport export is temporarily rate-limited. Wait briefly, then retry."
            )
        case 500:
            return .init(
                title: "PDF export failed",
                message: "Kairo could not generate your Passport PDF. Retry shortly."
            )
        case 503:
            return .init(
                title: "PDF export temporarily unavailable",
                message: "The Passport PDF service is temporarily unavailable. Retry shortly."
            )
        default:
            return .init(title: "PDF export failed", message: error.message)
        }
    }
}

struct PassportPDFPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsSystemShare = false

    let artifact: PassportPDFArtifact
    let onRetry: () -> Void
    private let document: PDFDocument?

    init(artifact: PassportPDFArtifact, onRetry: @escaping () -> Void) {
        self.artifact = artifact
        self.onRetry = onRetry
        document = PDFDocument(url: artifact.fileURL)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let document, document.pageCount > 0 {
                    PassportPDFKitView(document: document)
                        .accessibilityIdentifier(KairoAccessibilityID.passportPDFPreview)
                } else {
                    previewFailure
                }
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle(artifact.filename)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if document != nil {
                    shareAction
                }
            }
        }
        .interactiveDismissDisabled(false)
        .sheet(isPresented: $showsSystemShare) {
            PassportPDFActivityView(fileURL: artifact.fileURL)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .background, !showsSystemShare else { return }
            dismiss()
        }
    }

    private var shareAction: some View {
        Button {
            showsSystemShare = true
        } label: {
            Label("Share or Save PDF", systemImage: "square.and.arrow.up")
                .font(KairoTypography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoSpacing.medium)
                .background(KairoColors.brandPrimary, in: Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, KairoSpacing.large)
        .padding(.vertical, KairoSpacing.small)
        .background(KairoColors.background.opacity(0.96))
        .accessibilityIdentifier(KairoAccessibilityID.passportPDFShare)
        .accessibilityHint("Opens the system share sheet, including Save to Files")
    }

    private var previewFailure: some View {
        VStack(spacing: KairoSpacing.large) {
            KairoErrorStateView(
                title: "PDF preview unavailable",
                message: "This temporary Passport PDF could not be opened. Close the preview and download a fresh copy.",
                messageAccessibilityIdentifier: KairoAccessibilityID.passportPDFPreviewError
            )
            KairoSecondaryButton(
                title: "Close and retry",
                accessibilityIdentifier: KairoAccessibilityID.passportPDFPreviewRetry,
                action: {
                    onRetry()
                    dismiss()
                }
            )
        }
        .padding(KairoSpacing.large)
        .accessibilityIdentifier(KairoAccessibilityID.passportPDFPreviewFailure)
    }
}

private struct PassportPDFActivityView: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        _ = controller
    }
}

private struct PassportPDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.displaysPageBreaks = true
        view.backgroundColor = .secondarySystemBackground
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document !== document {
            view.document = document
        }
    }
}
