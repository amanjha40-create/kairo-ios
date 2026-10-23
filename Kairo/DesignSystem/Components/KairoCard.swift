import SwiftUI

struct KairoCard<Content: View>: View {
    let accent: KairoSemanticAccent
    @ViewBuilder private let content: Content

    init(accent: KairoSemanticAccent = .neutral, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            content
        }
        .kairoSemanticSurface(accent)
        .kairoShadow(KairoShadow.card)
    }
}
