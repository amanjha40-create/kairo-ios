import SwiftUI

struct OnboardingScreenLayout<Hero: View, Content: View, Actions: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let eyebrow: String?
    let title: String
    let subtitle: String
    let titleAccessibilityIdentifier: String
    @ViewBuilder private let hero: Hero
    @ViewBuilder private let content: Content
    @ViewBuilder private let actions: Actions

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        titleAccessibilityIdentifier: String,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.titleAccessibilityIdentifier = titleAccessibilityIdentifier
        self.hero = hero()
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let topPadding = geometry.safeAreaInsets.top + KairoSpacing.medium
            let contentBottomPadding = KairoSpacing.large

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    scrollingContent(
                        isLandscape: isLandscape,
                        size: geometry.size,
                        topPadding: topPadding,
                        bottomPadding: contentBottomPadding
                    )
                } else {
                    ViewThatFits(in: .vertical) {
                        contentLayout(isLandscape: isLandscape)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, horizontalPadding(for: geometry.size))
                            .padding(.top, topPadding)
                            .padding(.bottom, contentBottomPadding)
                            .frame(maxWidth: .infinity, alignment: .top)

                        scrollingContent(
                            isLandscape: isLandscape,
                            size: geometry.size,
                            topPadding: topPadding,
                            bottomPadding: contentBottomPadding
                        )
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar(for: geometry.size, bottomInset: geometry.safeAreaInsets.bottom)
            }
            .background(KairoColors.background.ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func contentLayout(isLandscape: Bool) -> some View {
        if isLandscape {
            landscapeContent()
        } else {
            portraitContent()
        }
    }

    private func portraitContent() -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
            hero
                .frame(maxWidth: .infinity)

            copyBlock

            content
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .modifier(OnboardingPageTransitionModifier())
    }

    private func landscapeContent() -> some View {
        HStack(alignment: .center, spacing: KairoSpacing.xxLarge) {
            hero
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
                copyBlock
                content
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .modifier(OnboardingPageTransitionModifier())
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(KairoColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }

            VStack(alignment: .leading, spacing: KairoSpacing.medium) {
                Text(title)
                    .font(KairoTypography.largeTitle)
                    .foregroundStyle(KairoColors.textPrimary)
                    .accessibilityIdentifier(titleAccessibilityIdentifier)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scrollingContent(
        isLandscape: Bool,
        size: CGSize,
        topPadding: CGFloat,
        bottomPadding: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            contentLayout(isLandscape: isLandscape)
                .padding(.horizontal, horizontalPadding(for: size))
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func horizontalPadding(for size: CGSize) -> CGFloat {
        size.width > 430 ? KairoSpacing.xxLarge : KairoSpacing.large
    }

    private func actionBar(for size: CGSize, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(KairoColors.border)

            actions
                .padding(.horizontal, horizontalPadding(for: size))
                .padding(.top, KairoSpacing.medium)
                .padding(.bottom, max(bottomInset + KairoSpacing.small, KairoSpacing.xLarge))
                .background(KairoColors.background)
        }
    }
}
private struct OnboardingPageTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    func body(content: Content) -> some View {
        let disablesAnimations = UITestLaunchConfiguration.current().disablesAnimations

        content
            .opacity(isVisible || reduceMotion || disablesAnimations ? 1 : 0)
            .offset(y: isVisible || reduceMotion || disablesAnimations ? 0 : 10)
            .onAppear {
                guard !reduceMotion, !disablesAnimations else {
                    isVisible = true
                    return
                }

                withAnimation(.easeOut(duration: 0.28)) {
                    isVisible = true
                }
            }
    }
}
