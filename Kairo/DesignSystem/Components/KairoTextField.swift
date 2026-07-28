import SwiftUI

struct KairoTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xSmall) {
            Text(title)
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(KairoTypography.body)
                .padding(.horizontal, KairoSpacing.medium)
                .padding(.vertical, KairoSpacing.medium)
                .background(KairoColors.surfaceMuted.opacity(0.65))
                .overlay(
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .stroke(KairoColors.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous))
        }
    }
}
