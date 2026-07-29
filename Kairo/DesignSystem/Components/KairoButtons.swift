import SwiftUI

private struct KairoButtonChrome: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    let foregroundColor: Color
    let backgroundColor: Color
    let pressedBackgroundColor: Color
    let borderColor: Color?

    func makeBody(configuration: Configuration) -> some View {
        let resolvedForegroundColor = isEnabled ? foregroundColor : foregroundColor.opacity(0.58)
        let resolvedBackgroundColor = isEnabled ? (configuration.isPressed ? pressedBackgroundColor : backgroundColor) : backgroundColor.opacity(0.42)

        configuration.label
            .foregroundStyle(resolvedForegroundColor)
            .background(
                resolvedBackgroundColor,
                in: Capsule()
            )
            .overlay {
                if let borderColor {
                    Capsule()
                        .stroke(isEnabled ? borderColor : borderColor.opacity(0.45), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? 1 : 0.92)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
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
                    .multilineTextAlignment(.center)
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, KairoSpacing.medium)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
        .buttonStyle(
            KairoButtonChrome(
                foregroundColor: KairoColors.brandPrimary,
                backgroundColor: KairoColors.surface,
                pressedBackgroundColor: KairoColors.surfaceMuted,
                borderColor: KairoColors.border
            )
        )
    }
}
