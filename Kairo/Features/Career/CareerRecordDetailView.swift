import SwiftUI

nonisolated enum CareerRecordKind { case employment, education, certification, project, portfolio }

/// Only supplied web links become destinations; display labels are never URLs.
nonisolated struct CareerRecordLink: Equatable, Sendable {
    let title: String
    let url: URL
    init?(title: String, url: URL?) {
        guard let url, ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return nil }
        self.title = title
        self.url = url
    }
}

/// Callbacks return to the canonical owner after dismissal, preserving confirmations.
struct CareerRecordDetailPresentation: Identifiable {
    let id: String
    let title: String
    let organization: String
    let status: CareerVerificationStatus?
    let metadata: [(title: String, value: String)]
    var documents: CareerDocumentParent? = nil
    var edit: (() -> Void)? = nil
    var delete: (() -> Void)? = nil
    var verify: (() -> Void)? = nil
    var kind: CareerRecordKind = .employment
    var supportingMetadata: [(title: String, value: String)] = []
    var links: [CareerRecordLink] = []
    var attachmentPresent: Bool? = nil

    var showsVerification: Bool { kind == .employment || kind == .education }

    var documentSectionTitle: String {
        switch kind {
        case .employment, .education: "Evidence"
        case .certification: "Certificate document"
        case .portfolio: "Portfolio attachment"
        case .project: "Documents"
        }
    }

    var documentActionTitle: String {
        switch kind {
        case .employment, .education: "Manage evidence"
        case .certification: "Manage document"
        case .portfolio: "View attachment"
        case .project: "View documents"
        }
    }

    static func employment(_ item: CareerEmploymentItem, edit: (() -> Void)?, delete: (() -> Void)?, verify: (() -> Void)?) -> Self {
        Self(id: item.routeID, title: item.role, organization: item.company, status: item.verificationStatus,
            metadata: [("Employment dates", item.dateRange)] + item.detailMetadata.map { ($0.title, $0.value) },
            documents: .employment(id: item.routeID, title: "\(item.role) at \(item.company)", canUpload: item.allowsEdit, canDelete: item.allowsDelete),
            edit: item.allowsEdit ? edit : nil, delete: item.allowsDelete ? delete : nil,
            verify: item.verificationStatus.canStartVerification ? verify : nil)
    }

    static func education(_ item: CareerEducationItem, edit: (() -> Void)?, delete: (() -> Void)?, verify: (() -> Void)?) -> Self {
        Self(id: item.routeID, title: item.degree, organization: item.institution, status: item.verificationStatus,
            metadata: [("Dates", item.dateRange)] + item.detailMetadata.filter { $0.title == "Field of study" }.map { ($0.title, $0.value) },
            documents: .education(id: item.routeID, title: item.institution), edit: edit, delete: delete,
            verify: item.verificationStatus.canStartVerification ? verify : nil, kind: .education,
            supportingMetadata: item.detailMetadata.filter { $0.title != "Field of study" }.map { ($0.title, $0.value) })
    }

    static func certification(_ item: CareerCertificationItem, edit: (() -> Void)?, delete: (() -> Void)?) -> Self {
        Self(id: item.routeID, title: item.title, organization: item.issuer, status: item.verificationStatus,
            metadata: [("Issue date", item.issueDate)] + item.detailMetadata.map { ($0.title, $0.value) },
            documents: .certification(id: item.routeID, title: item.title), edit: edit, delete: delete, kind: .certification,
            links: [CareerRecordLink(title: "Credential URL", url: item.credentialURL)].compactMap { $0 }, attachmentPresent: item.hasDocument)
    }

    static func project(_ item: CareerProjectItem, edit: (() -> Void)?, delete: (() -> Void)?) -> Self {
        Self(id: item.routeID, title: item.title, organization: item.role, status: item.verificationStatus ?? .notVerified,
            metadata: item.detailMetadata.filter { $0.title != "Origin" }.map { ($0.title, $0.value) }
                + (item.duration.isEmpty ? [] : [("Dates", item.duration)]),
            documents: item.legacyPortfolioID.map { .legacyPortfolio(id: $0, title: item.title) },
            edit: item.legacyPortfolioID == nil ? edit : nil, delete: item.legacyPortfolioID == nil ? delete : nil, kind: .project,
            supportingMetadata: item.detailMetadata.filter { $0.title == "Origin" }.map { ($0.title, $0.value) }, links: item.links)
    }

    static func portfolio(_ item: CareerPortfolioItem) -> Self {
        Self(
            id: item.routeID,
            title: item.title,
            organization: "Portfolio",
            status: item.verificationStatus,
            metadata: item.description.map { [("Description", $0)] } ?? [],
            documents: .legacyPortfolio(id: item.routeID, title: item.title),
            kind: .portfolio,
            links: [CareerRecordLink(title: "Work sample URL", url: item.url)].compactMap { $0 },
            attachmentPresent: item.hasDocument
        )
    }
}

struct CareerRecordDetailView: View {
    let record: CareerRecordDetailPresentation
    let perform: (@escaping () -> Void) -> Void
    let openDocuments: (CareerDocumentParent) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.careerDocumentService) private var documentService
    @State private var documentCount: Int?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                        Text(record.title).font(KairoTypography.title2).foregroundStyle(KairoColors.textPrimary)
                            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("career.detail.title")
                        if !record.organization.isEmpty {
                            Text(record.organization).font(KairoTypography.body).foregroundStyle(KairoColors.textSecondary)
                        }
                        if record.kind != .project { status }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if !record.metadata.isEmpty || !record.links.isEmpty {
                        KairoSection(compact: true) {
                            KairoSectionHeading(title: "Details")
                            metadata(record.metadata)
                            ForEach(record.links, id: \.title) { link in
                                Link(destination: link.url) {
                                    VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                        Label(link.title, systemImage: "arrow.up.right")
                                        Text(link.url.absoluteString).font(KairoTypography.footnote)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .foregroundStyle(KairoColors.brandPrimary)
                                .accessibilityIdentifier("career.detail.link.\(link.title)")
                                .accessibilityHint("Opens the supplied website in your browser.")
                            }
                        }
                    }
                    if let documents = record.documents {
                        KairoSection(compact: true) {
                            KairoSectionHeading(title: record.documentSectionTitle, count: documentCount)
                            if let present = record.attachmentPresent {
                                Text(present ? "Attachment added" : "No attachment")
                                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                Text(present
                                    ? "Metadata edits preserve this file. Use Documents to view, replace, or remove the attachment."
                                    : "Use Documents to add an attachment. Uploading a file does not verify this record.")
                                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if record.kind == .education {
                                Text("Historical verification evidence may not be available to view. Documents shows only supported actions.")
                                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .accessibilityIdentifier("career.detail.educationEvidenceNotice")
                            }
                            KairoCompactDestinationRow(title: record.documentActionTitle, systemImage: "doc.text",
                                accessibilityIdentifier: "career.detail.documents") { openDocuments(documents) }
                        }
                    }
                    if record.showsVerification {
                        KairoSection(compact: true) {
                            KairoSectionHeading(title: "Verification")
                            if let verify = record.verify {
                                Button("Start verification") { perform(verify) }
                                    .buttonStyle(KairoActionStyle()).accessibilityIdentifier("career.detail.verify")
                            } else {
                                Text("Verification actions depend on this record’s current status.")
                                    .font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if record.kind == .project { status }
                    if !record.supportingMetadata.isEmpty {
                        KairoSection(compact: true) {
                            KairoSectionHeading(title: "Additional details")
                            metadata(record.supportingMetadata)
                        }
                    }
                    if record.edit != nil || record.delete != nil {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: KairoSpacing.medium) { actions }
                            VStack(alignment: .leading, spacing: KairoSpacing.xSmall) { actions }
                        }
                    }
                }
                .padding(KairoSpacing.medium)
            }
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Record details").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .accessibilityIdentifier("career.record.detail")
        .task(id: record.documents?.id) {
            await loadDocumentCount()
        }
    }

    private func metadata(_ items: [(title: String, value: String)]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                Text(item.title).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                Text(item.value).font(KairoTypography.body).foregroundStyle(KairoColors.textPrimary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine).accessibilityIdentifier("career.detail.field.\(item.title)")
        }
    }

    @ViewBuilder private var status: some View {
        if let status = record.status {
            CareerRecordStatus(status: status).accessibilityIdentifier("career.detail.status")
        }
    }

    @ViewBuilder private var actions: some View {
        if let edit = record.edit {
            Button("Edit") { perform(edit) }.buttonStyle(KairoActionStyle()).accessibilityIdentifier("career.detail.edit")
        }
        if let delete = record.delete {
            Button("Delete", role: .destructive) { perform(delete) }
                .buttonStyle(KairoActionStyle(role: .destructiveSecondary)).accessibilityIdentifier("career.detail.delete")
        }
    }

    private func loadDocumentCount() async {
        guard let parent = record.documents else {
            documentCount = nil
            return
        }
        do {
            let documents = try await documentService.listDocuments(for: parent)
            await MainActor.run { documentCount = documents.count }
        } catch {
            await MainActor.run { documentCount = nil }
        }
    }
}
