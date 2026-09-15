import SwiftUI

struct KairoButtonChrome: ButtonStyle {
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
                in: RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
            )
            .overlay {
                if let borderColor {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.medium, style: .continuous)
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
                        .tint(KairoColors.onPrimary)
                }

                Text(title)
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
        }
        .accessibilityIdentifier(accessibilityIdentifier ?? title)
        .buttonStyle(
            KairoButtonChrome(
                foregroundColor: KairoColors.onPrimary,
                backgroundColor: KairoColors.brandPrimary,
                pressedBackgroundColor: KairoColors.brandPrimaryPressed,
                borderColor: nil
            )
        )
    }
}

enum KairoActionRole {
    case tertiary, destructiveSecondary, destructivePrimary, icon
}

struct KairoActionStyle: ButtonStyle {
    var role: KairoActionRole = .tertiary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KairoTypography.action)
            .foregroundStyle(foreground)
            .padding(.horizontal, role == .tertiary ? 0 : KairoSpacing.small)
            .frame(minWidth: 44, minHeight: 44)
            .background(background, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
            .overlay {
                if role == .destructiveSecondary {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small)
                        .stroke(KairoColors.danger.opacity(0.4), lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.45)
    }

    private var foreground: Color {
        switch role {
        case .tertiary, .icon: KairoColors.brandPrimary
        case .destructiveSecondary: KairoColors.danger
        case .destructivePrimary: .white
        }
    }

    private var background: Color {
        switch role {
        case .tertiary: .clear
        case .icon: KairoColors.surfaceMuted
        case .destructiveSecondary: KairoColors.danger.opacity(0.05)
        case .destructivePrimary: KairoColors.danger
        }
    }
}

struct KairoSecondaryButton: View {
    let title: String
    var isLoading: Bool = false
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: KairoSpacing.xSmall) {
                if isLoading {
                    ProgressView()
                        .tint(KairoColors.brandPrimary)
                }

                Text(title)
                    .font(.system(.subheadline, design: .default).weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 48)
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
