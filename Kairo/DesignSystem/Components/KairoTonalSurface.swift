import SwiftUI

/// Opt-in hierarchy for related content; no new actions, motion or status meaning.
enum KairoSurfaceEmphasis {
    case primary, standard, secondary

    var fill: Color {
        switch self {
        case .primary: KairoColors.surfaceBrand
        case .standard: KairoColors.surface
        case .secondary: KairoColors.surfaceMuted
        }
    }
}

struct KairoTonalSurface: ViewModifier {
    let emphasis: KairoSurfaceEmphasis

    func body(content: Content) -> some View {
        content
            .padding(KairoSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(emphasis.fill, in: RoundedRectangle(cornerRadius: KairoCornerRadius.large))
            .overlay {
                if emphasis == .primary {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.large)
                        .strokeBorder(KairoColors.borderBrand, lineWidth: 1)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

extension View {
    func kairoTonalSurface(_ emphasis: KairoSurfaceEmphasis) -> some View {
        modifier(KairoTonalSurface(emphasis: emphasis))
    }
}
