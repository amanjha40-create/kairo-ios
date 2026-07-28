import SwiftUI

private struct KairoButtonChrome: ButtonStyle {
    let foregroundColor: Color
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let borderColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor)
            .background(
                (configuration.isPressed ? pressedBackgroundColor : backgroundColor),
                in: Capsule()
            )
            .overlay {
                if let borderColor {
                    Capsule()
                        .stroke(borderColor, lineWidth: 1)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct KairoPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairoSpacing.xSmall) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }

                Text(title)
                    .font(KairoTypography.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoSpacing.medium)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
        .buttonStyle(
            KairoButtonChrome(
                foregroundColor: .white,
                backgroundColor: KairoColors.brandPrimary,
                pressedBackgroundColor: KairoColors.brandPrimaryPressed,
                borderColor: nil
            )
        )
    }
}

struct KairoSecondaryButton: View {
    let title: String
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KairoTypography.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoSpacing.medium)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
        .buttonStyle(
            KairoButtonChrome(
                foregroundColor: KairoColors.brandPrimary,
                backgroundColor: KairoColors.surfaceMuted,
                pressedBackgroundColor: KairoColors.surface,
                borderColor: KairoColors.border
            )
        )
    }
}
