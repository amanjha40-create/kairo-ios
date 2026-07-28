import SwiftUI

struct KairoLoadingStateView: View {
    let title: String
    let message: String

    var body: some View {
        KairoCard {
            ProgressView()
                .tint(KairoColors.brandPrimary)
            Text(title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
        }
    }
}

struct KairoEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        KairoCard {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(KairoColors.accent)
            Text(title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
        }
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
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(KairoColors.warning)
            Text(title)
                .font(KairoTypography.title2)
                .foregroundStyle(KairoColors.textPrimary)
            Text(message)
                .font(KairoTypography.body)
                .foregroundStyle(KairoColors.textSecondary)
                .modifier(OptionalAccessibilityIdentifier(identifier: messageAccessibilityIdentifier))

            if let retryAction {
                KairoSecondaryButton(title: retryTitle, action: retryAction)
                    .padding(.top, KairoSpacing.xSmall)
            }
        }
    }
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
