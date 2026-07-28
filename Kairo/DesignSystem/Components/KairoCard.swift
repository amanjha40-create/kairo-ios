import SwiftUI

struct KairoCard<Content: View>: View {
    @ViewBuilder private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.small) {
            content
        }
        .padding(KairoSpacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KairoColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: KairoCornerRadius.medium)
                .stroke(KairoColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous))
        .kairoShadow(KairoShadow.card)
    }
}
