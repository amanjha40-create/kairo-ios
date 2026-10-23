import SwiftUI

/// Uses the shared full-sheet searchable selector. Selection remains visible,
/// and opening/dismissing never chooses a different type implicitly.
struct EvidenceTypeSelector: View {
    let value: String
    let options: [CareerDocumentType]
    var titleColor: Color = KairoColors.textSecondary
    var titleFont: Font = KairoTypography.caption
    let select: (String) -> Void

    var body: some View {
        CandidatePlacePicker(title: "Document type", value: value,
            options: options.map(\.id), required: true, placeholder: "Choose document type…",
            titleColor: titleColor, titleFont: titleFont,
            display: { id in options.first { $0.id == id }?.label ?? id }) { select($0) }
            .accessibilityIdentifier("evidence.documentType")
    }
}

struct EvidenceUploadReview: View {
    let type: String
    let filename: String
    let isUploading: Bool
    let retry: Bool
    var stage: DocumentUploadStage? = nil
    let upload: () -> Void
    let cancel: () -> Void

    var body: some View {
        KairoSection {
            Text("Review document").font(KairoTypography.headline)
                .accessibilityIdentifier("evidence.uploadReview")
            Text(type).font(KairoTypography.bodyStrong)
            Text(filename).font(KairoTypography.body).fixedSize(horizontal: false, vertical: true)
            Text("Uploading adds a private document. It does not submit verification or mark a claim verified.")
                .font(KairoTypography.footnote).fixedSize(horizontal: false, vertical: true)
            if isUploading {
                ProgressView(stage?.rawValue ?? "Uploading and confirming with KairoID…")
                    .accessibilityIdentifier("evidence.uploadProgress")
            }
            KairoPrimaryButton(title: retry ? "Retry upload" : "Upload document", isLoading: isUploading,
                accessibilityIdentifier: "evidence.confirmUpload", action: upload).disabled(isUploading)
            Button("Cancel selection", action: cancel).disabled(isUploading)
                .buttonStyle(KairoActionStyle(role: .secondary))
        }
    }
}
