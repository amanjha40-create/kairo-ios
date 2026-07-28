import SwiftUI

enum KairoScreenScrollBehavior {
    case scrolls
    case fixed
}

struct KairoScreenContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let titleAccessibilityIdentifier: String
    let scrollBehavior: KairoScreenScrollBehavior
    @ViewBuilder private let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        titleAccessibilityIdentifier: String = "screen.title",
        scrollBehavior: KairoScreenScrollBehavior = .scrolls,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.scrollBehavior = scrollBehavior
        self.content = content()
    }

    var body: some View {
        Group {
            switch scrollBehavior {
            case .scrolls:
                ScrollView {
                    contentStack
                }
            case .fixed:
                contentStack
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(
            LinearGradient(
                colors: [KairoColors.background, KairoColors.surfaceMuted.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            VStack(alignment: .leading, spacing: KairoSpacing.small) {
                Text(title)
                    .font(KairoTypography.largeTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                    .accessibilityIdentifier(titleAccessibilityIdentifier)

                if let subtitle {
                    Text(subtitle)
                        .font(KairoTypography.body)
                        .foregroundStyle(KairoColors.textSecondary)
                }
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, KairoSpacing.large)
        .padding(.vertical, KairoSpacing.xLarge)
    }
}
