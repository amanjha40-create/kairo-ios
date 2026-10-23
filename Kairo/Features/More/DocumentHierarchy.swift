import SwiftUI

/// Display-only grouping. Every supplied row retains its source, identity and permissions.
nonisolated struct DocumentHierarchyGroup: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let rows: [DocumentsHubRow]
}

nonisolated enum DocumentHierarchy {
    static func groups(_ rows: [DocumentsHubRow], category: DocumentsHubCategory) -> [DocumentHierarchyGroup] {
        DocumentsHubCategory.allCases.filter { $0 != .all && (category == .all || category == $0) }.flatMap { category in
            let matches = rows.filter { $0.category == category }
            if category == .other {
                let identity = matches.filter { if case .vault = $0.source { true } else { false } }
                let other = matches.filter { if case .vault = $0.source { false } else { true } }
                return [DocumentHierarchyGroup(id: "identity", title: "Identity & Personal", rows: identity),
                        DocumentHierarchyGroup(id: category.id, title: category.rawValue, rows: other)].filter { !$0.rows.isEmpty }
            }
            return matches.isEmpty ? [] : [DocumentHierarchyGroup(id: category.id, title: category.rawValue, rows: matches)]
        }
    }

    static func title(_ row: DocumentsHubRow) -> String {
        if case .vault(let document) = row.source { return document.documentType.title }
        return row.filename
    }

    static func vaultIsLegacy(_ document: VaultDocument) -> Bool { !document.documentType.allowsNewUpload }
}

struct DocumentGroupHeading: View {
    let title: String
    let count: Int
    var titleColor: Color = KairoColors.textPrimary
    var titleFont: Font = KairoTypography.headline
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(titleFont).foregroundStyle(titleColor).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: KairoSpacing.small)
            Text("\(count)").font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
        }
        .foregroundStyle(KairoColors.textPrimary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(count) documents")
        .accessibilityAddTraits(.isHeader)
    }
}

struct CompactDocumentLabel: View {
    let title: String
    let filename: String
    let context: String?
    let metadata: String
    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
            Text(title).font(KairoTypography.bodyStrong).foregroundStyle(KairoColors.textPrimary)
            if filename != title { Text(filename).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary) }
            if let context, !context.isEmpty {
                Text(context).font(KairoTypography.footnote).foregroundStyle(KairoColors.textSecondary)
            }
            Text(metadata).font(KairoTypography.caption).foregroundStyle(KairoColors.textSecondary)
        }.fixedSize(horizontal: false, vertical: true)
    }
}
