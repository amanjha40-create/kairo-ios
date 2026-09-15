import SwiftUI

/// Read-only presentation of the already-loaded Career record. Existing actions are
/// handed back to the owner after dismissal, so mutations keep their canonical flow.
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
}

struct CareerRecordDetailView: View {
    let record: CareerRecordDetailPresentation
    let perform: (@escaping () -> Void) -> Void
    let openDocuments: (CareerDocumentParent) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KairoSpacing.large) {
                    VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
                        Text(record.title)
                            .font(KairoTypography.title2)
                            .foregroundStyle(KairoColors.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                        Text(record.organization)
                            .font(KairoTypography.body)
                            .foregroundStyle(KairoColors.textSecondary)
                        status
                    }
                    KairoSection {
                        KairoSectionHeading(title: "Details")
                        ForEach(Array(record.metadata.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                                Text(item.title).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
                                Text(item.value).font(KairoTypography.body).foregroundStyle(KairoColors.textPrimary)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let documents = record.documents {
                        KairoSection {
                            KairoSectionHeading(title: "Documents")
                            Button { openDocuments(documents) } label: {
                                Label("View documents", systemImage: "doc.text")
                            }
                            .buttonStyle(KairoActionStyle())
                            .accessibilityIdentifier("career.detail.documents")
                        }
                    }
                    if record.status != nil || record.verify != nil {
                        KairoSection {
                            KairoSectionHeading(title: "Verification")
                            status
                            if let verify = record.verify {
                                Button("Start verification") { perform(verify) }
                                    .buttonStyle(KairoActionStyle())
                            }
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
            .navigationTitle("Record details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .accessibilityIdentifier("career.record.detail")
    }

    @ViewBuilder
    private var status: some View {
        if let status = record.status {
            KairoStatusChip(
                title: status.badgeStyle.title,
                tone: status == .verified ? .verified : status == .pendingVerification ? .pending : .candidateProvided,
                systemImage: status.badgeStyle.symbol
            )
        }
    }

    @ViewBuilder
    private var actions: some View {
        if let edit = record.edit {
            Button("Edit") { perform(edit) }.buttonStyle(KairoActionStyle())
                .accessibilityIdentifier("career.detail.edit")
        }
        if let delete = record.delete {
            Button("Delete", role: .destructive) { perform(delete) }
                .buttonStyle(KairoActionStyle(role: .destructiveSecondary))
                .accessibilityIdentifier("career.detail.delete")
        }
    }
}
