import SwiftUI

/// Flat, divided groups keep the hierarchy in the content, rather than nested card borders.
struct KairoSection<Content: View>: View {
    var compact: Bool
    @ViewBuilder let content: Content

    init(compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, compact ? KairoSpacing.xSmall : KairoSpacing.medium)
        .overlay(alignment: .bottom) { Rectangle().fill(KairoColors.border).frame(height: 1) }
    }
}

/// One full-width destination, with no nested action or fixed content height.
/// Callers supply authoritative metadata; this component never infers status/counts.
struct KairoCompactDestinationRow: View {
    let title: String
    var metadata: String? = nil
    let systemImage: String
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: KairoSpacing.small) {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(KairoColors.brandPrimary)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(title)
                        .font(KairoTypography.recordTitle)
                        .foregroundStyle(KairoColors.textPrimary)
                    if let metadata, !metadata.isEmpty {
                        Text(metadata)
                            .font(KairoTypography.metadata)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(KairoTypography.caption)
                    .foregroundStyle(KairoColors.textSecondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, KairoSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
    }
}

struct KairoSectionHeading: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: KairoSpacing.small) {
            Text(title)
                .font(KairoTypography.sectionTitle)
                .foregroundStyle(KairoColors.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: KairoSpacing.xSmall)
            if let count {
                Text(String(count))
                    .font(KairoTypography.caption)
                    .monospacedDigit()
                    .foregroundStyle(KairoColors.textSecondary)
                    .padding(.horizontal, KairoSpacing.xSmall)
                    .padding(.vertical, KairoSpacing.xxSmall)
                    .background(KairoColors.surfaceMuted, in: Capsule())
                    .accessibilityLabel("\(count) items")
            }
        }
    }
}

enum KairoStatusTone: CaseIterable {
    case verified, pending, attention, rejected, withdrawn, draft, candidateProvided

    var canonicalTitle: String {
        switch self {
        case .verified: "Verified"
        case .pending: "Pending KairoID Review"
        case .attention: "Needs your attention"
        case .rejected: "Rejected"
        case .withdrawn: "Withdrawn"
        case .draft: "Draft"
        case .candidateProvided: "Candidate-provided"
        }
    }

    var color: Color {
        switch self {
        case .verified: KairoColors.success
        case .pending: KairoColors.pending
        case .attention: KairoColors.attention
        case .rejected: KairoColors.rejected
        case .withdrawn, .draft: KairoColors.draft
        case .candidateProvided: KairoColors.candidateProvided
        }
    }

    var symbol: String {
        switch self {
        case .verified: "checkmark.shield"
        case .pending: "clock"
        case .attention: "exclamationmark.circle"
        case .rejected: "xmark.circle"
        case .withdrawn: "minus.circle"
        case .draft: "pencil"
        case .candidateProvided: "person.crop.circle"
        }
    }
}

/// Callers retain authoritative status copy and explicitly supply its visual meaning.
struct KairoStatusChip: View {
    @State private var verifiedTransition = 0
    let title: String
    var tone: KairoStatusTone = .draft
    var systemImage: String? = nil

    init(title: String? = nil, tone: KairoStatusTone = .draft, systemImage: String? = nil) {
        self.title = title ?? tone.canonicalTitle
        self.tone = tone
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            if tone == .verified {
                KairoTrustSignature(kind: .verified, trigger: verifiedTransition, animateInitially: verifiedTransition > 0, size: 20)
            } else { Image(systemName: systemImage ?? tone.symbol).accessibilityHidden(true) }
            Text(title)
        }
            .font(KairoTypography.caption)
            .foregroundStyle(tone.color)
            .padding(.horizontal, KairoSpacing.xSmall)
            .padding(.vertical, KairoSpacing.xxSmall)
            .background(tone.color.opacity(0.09), in: Capsule())
            .overlay(Capsule().stroke(tone.color.opacity(0.25), lineWidth: 1))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
            .onChange(of: tone) { old, next in if old != .verified && next == .verified { verifiedTransition += 1 } }
    }
}

struct KairoDocumentRow<Details: View, Actions: View>: View {
    let filename: String
    let metadata: String
    let source: String
    let status: String
    var isHistorical = false
    @ViewBuilder let details: Details
    @ViewBuilder let actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            HStack(alignment: .top, spacing: KairoSpacing.small) {
                Image(systemName: isHistorical ? "doc.badge.clock" : "doc.text")
                    .font(.title3)
                    .foregroundStyle(KairoColors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: KairoSpacing.xxSmall) {
                    Text(filename)
                        .font(KairoTypography.recordTitle)
                        .foregroundStyle(KairoColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(metadata)
                        .font(KairoTypography.metadata)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text(source)
                        .font(KairoTypography.footnote)
                        .foregroundStyle(KairoColors.textSecondary)
                    Text(status)
                        .font(KairoTypography.caption)
                        .foregroundStyle(KairoColors.textSecondary)
                    if isHistorical {
                        Label("Historical record · Read only", systemImage: "lock")
                            .font(KairoTypography.caption)
                            .foregroundStyle(KairoColors.textSecondary)
                    }
                    details
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            actions
                .font(KairoTypography.action)
        }
        .padding(.vertical, KairoSpacing.small)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Rectangle().fill(KairoColors.border).frame(height: 1) }
        .accessibilityElement(children: .contain)
    }
}

struct KairoTrustSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(KairoSpacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack {
                    LinearGradient(colors: [KairoColors.navy, KairoColors.trustNavy], startPoint: .topLeading, endPoint: .bottomTrailing)
                    RadialGradient(colors: [KairoColors.accent.opacity(0.18), .clear], center: .bottomLeading, startRadius: 0, endRadius: 320)
                    Canvas { context, size in
                        var grid = Path()
                        for x in stride(from: 0.0, to: size.width, by: 24) {
                            grid.move(to: CGPoint(x: x, y: 0))
                            grid.addLine(to: CGPoint(x: x, y: size.height))
                        }
                        for y in stride(from: 0.0, to: size.height, by: 24) {
                            grid.move(to: CGPoint(x: 0, y: y))
                            grid.addLine(to: CGPoint(x: size.width, y: y))
                        }
                        context.stroke(grid, with: .color(.white.opacity(0.035)), lineWidth: 0.5)
                    }
                    .accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.trustSurface, style: .continuous))
    }
}
