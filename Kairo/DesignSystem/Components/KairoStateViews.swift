import SwiftUI

struct KairoLoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        KairoCard {
            VStack(spacing: KairoSpacing.small) {
                ZStack {
                    RoundedRectangle(cornerRadius: KairoCornerRadius.small, style: .continuous)
                        .fill(KairoColors.surfaceMuted)
                    ProgressView()
                        .tint(KairoColors.brandPrimary)
                }
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

                stateCopy(title: title, message: message)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoSpacing.small)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

struct KairoEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        KairoCard {
            VStack(spacing: KairoSpacing.small) {
                stateIcon(systemImage, color: KairoColors.brandPrimary)
                stateCopy(title: title, message: message)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoSpacing.medium)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

struct KairoErrorStateView: View {
    let title: String
    let message: String
    var messageAccessibilityIdentifier: String?
    var retryTitle: String = "Try Again"
    var retryAction: (() -> Void)?

    var body: some View {
        KairoCard {
            VStack(spacing: KairoSpacing.small) {
                stateIcon("exclamationmark.triangle.fill", color: KairoColors.warning)

                VStack(spacing: KairoSpacing.xSmall) {
                    Text(title)
                        .font(KairoTypography.title2)
                        .foregroundStyle(KairoColors.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .modifier(OptionalAccessibilityIdentifier(identifier: messageAccessibilityIdentifier))
                }

                if let retryAction {
                    KairoSecondaryButton(title: retryTitle, action: retryAction)
                        .padding(.top, KairoSpacing.xSmall)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, KairoSpacing.medium)
        }
    }
}

@ViewBuilder
private func stateCopy(title: String, message: String) -> some View {
    VStack(spacing: KairoSpacing.xSmall) {
        Text(title)
            .font(KairoTypography.title2)
            .foregroundStyle(KairoColors.textPrimary)
            .multilineTextAlignment(.center)
        Text(message)
            .font(KairoTypography.body)
            .foregroundStyle(KairoColors.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

@ViewBuilder
private func stateIcon(_ systemImage: String, color: Color) -> some View {
    Image(systemName: systemImage)
        .font(.system(size: 21, weight: .semibold))
        .foregroundStyle(color)
        .frame(width: 48, height: 48)
        .background(KairoColors.surfaceMuted, in: RoundedRectangle(cornerRadius: KairoCornerRadius.small))
        .accessibilityHidden(true)
}

private struct OptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
