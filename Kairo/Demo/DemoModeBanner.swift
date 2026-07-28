import SwiftUI

struct DemoModeBanner: View {
    let environment: AppEnvironment

    var body: some View {
        HStack(spacing: KairoSpacing.xSmall) {
            Image(systemName: "play.circle.fill")
            Text("Demo Mode • \(environment.displayName)")
                .font(KairoTypography.caption)
                .accessibilityIdentifier("demo.banner")
        }
        .foregroundStyle(KairoColors.brandPrimary)
        .padding(.horizontal, KairoSpacing.small)
        .padding(.vertical, KairoSpacing.xSmall)
        .background(KairoColors.surface, in: Capsule())
        .overlay(
            Capsule()
                .stroke(KairoColors.border, lineWidth: 1)
        )
    }
}
