import SwiftUI

struct KairoSemanticSurface: ViewModifier {
    let accent: KairoSemanticAccent

    func body(content: Content) -> some View {
        content
            .padding(KairoSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(accent.surface, in: RoundedRectangle(cornerRadius: KairoCornerRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: KairoCornerRadius.large)
                    .strokeBorder(accent.border, lineWidth: 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
    }
}

extension View {
    func kairoSemanticSurface(_ accent: KairoSemanticAccent = .neutral) -> some View {
        modifier(KairoSemanticSurface(accent: accent))
    }
}

struct KairoIconTile: View {
    let symbol: String
    var accent: KairoSemanticAccent = .info

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: KairoControlMetrics.icon, weight: .semibold))
            .foregroundStyle(accent.foreground)
            .frame(width: KairoControlMetrics.iconTile, height: KairoControlMetrics.iconTile)
            .background(accent.surface, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
            .accessibilityHidden(true)
    }
}
