import SwiftUI

enum OnboardingScreenLayoutMode {
    case hero
    case form
    case choice
    case task

    var pinsActionsToBottom: Bool {
        switch self {
        case .hero, .choice:
            true
        case .form, .task:
            false
        }
    }
}

struct OnboardingScreenLayout<Hero: View, Content: View, Actions: View>: View {
    @State private var actionBarHeight: CGFloat = 0

    let layoutMode: OnboardingScreenLayoutMode
    let eyebrow: String?
    let title: String
    let subtitle: String
    let titleAccessibilityIdentifier: String
    @ViewBuilder private let hero: Hero
    @ViewBuilder private let content: Content
    @ViewBuilder private let actions: Actions

    init(
        layoutMode: OnboardingScreenLayoutMode = .hero,
        eyebrow: String? = nil,
        title: String,
        subtitle: String,
        titleAccessibilityIdentifier: String,
        @ViewBuilder hero: () -> Hero,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.layoutMode = layoutMode
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
            let topPadding = geometry.safeAreaInsets.top + topPadding(for: layoutMode)
            let scrollingContentBottomPadding = layoutMode.pinsActionsToBottom
                ? KairoSpacing.large + actionBarHeight
                : max(geometry.safeAreaInsets.bottom + KairoSpacing.large, KairoSpacing.xxLarge)
            let minimumContentHeight = layoutMode.pinsActionsToBottom
                ? max(
                    geometry.size.height - actionBarHeight - topPadding - scrollingContentBottomPadding,
                    0
                )
                : nil

            let content = scrollingContent(
                isLandscape: isLandscape,
                size: geometry.size,
                topPadding: topPadding,
                bottomPadding: scrollingContentBottomPadding,
                minimumContentHeight: minimumContentHeight,
                bottomInset: geometry.safeAreaInsets.bottom
            )

            Group {
                if layoutMode.pinsActionsToBottom {
                    content.safeAreaInset(edge: .bottom, spacing: 0) {
                        actionBar(for: geometry.size, bottomInset: geometry.safeAreaInsets.bottom)
                    }
                } else {
                    content
                }
            }
            .background(KairoColors.background.ignoresSafeArea())
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func contentLayout(isLandscape: Bool) -> some View {
        switch layoutMode {
        case .hero:
            if isLandscape {
                landscapeHeroContent()
            } else {
                portraitHeroContent()
            }
        case .form:
            formContent()
        case .choice:
            if isLandscape {
                landscapeChoiceContent()
            } else {
                portraitChoiceContent()
            }
        case .task:
            if isLandscape {
                landscapeTaskContent()
            } else {
                portraitTaskContent()
            }
        }
    }

    private func portraitHeroContent() -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
            hero
                .frame(maxWidth: .infinity)

            copyBlock(
                contentSpacing: KairoSpacing.large,
                titleSpacing: KairoSpacing.medium
            )

            content
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func landscapeHeroContent() -> some View {
        HStack(alignment: .center, spacing: KairoSpacing.xxLarge) {
            hero
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: KairoSpacing.xLarge) {
                copyBlock(
                    contentSpacing: KairoSpacing.large,
                    titleSpacing: KairoSpacing.medium
                )
                content
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func formContent() -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            copyBlock(
                contentSpacing: KairoSpacing.medium,
                titleSpacing: KairoSpacing.small
            )

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func portraitChoiceContent() -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            hero
                .frame(maxWidth: .infinity)

            copyBlock(
                contentSpacing: KairoSpacing.medium,
                titleSpacing: KairoSpacing.small
            )

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func landscapeChoiceContent() -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.xLarge) {
            hero
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                copyBlock(
                    contentSpacing: KairoSpacing.medium,
                    titleSpacing: KairoSpacing.small
                )
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func portraitTaskContent() -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            hero
                .frame(maxWidth: .infinity)

            copyBlock(
                contentSpacing: KairoSpacing.medium,
                titleSpacing: KairoSpacing.small
            )

            content
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func landscapeTaskContent() -> some View {
        HStack(alignment: .top, spacing: KairoSpacing.xLarge) {
            hero
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: KairoSpacing.large) {
                copyBlock(
                    contentSpacing: KairoSpacing.medium,
                    titleSpacing: KairoSpacing.small
                )
                content
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func copyBlock(contentSpacing: CGFloat, titleSpacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            if let eyebrow {
                Text(eyebrow)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(KairoColors.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }

            VStack(alignment: .leading, spacing: titleSpacing) {
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

    private func topPadding(for layoutMode: OnboardingScreenLayoutMode) -> CGFloat {
        switch layoutMode {
        case .hero, .choice, .task:
            KairoSpacing.medium
        case .form:
            KairoSpacing.small
        }
    }

    private func inlineActionBlock(for size: CGSize, bottomInset: CGFloat) -> some View {
        actions
            .padding(.top, KairoSpacing.large)
            .padding(.bottom, max(bottomInset + KairoSpacing.medium, KairoSpacing.xLarge))
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, horizontalPadding(for: size))
    }

    @ViewBuilder
    private func scrollContentBody(isLandscape: Bool, size: CGSize, bottomInset: CGFloat) -> some View {
        contentLayout(isLandscape: isLandscape)
            .modifier(OnboardingPageTransitionModifier())

        if !layoutMode.pinsActionsToBottom {
            inlineActionBlock(for: size, bottomInset: bottomInset)
                .modifier(OnboardingPageTransitionModifier())
        }
    }

    private func scrollingContent(
        isLandscape: Bool,
        size: CGSize,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        minimumContentHeight: CGFloat?,
        bottomInset: CGFloat
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                scrollContentBody(
                    isLandscape: isLandscape,
                    size: size,
                    bottomInset: bottomInset
                )
            }
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(minHeight: minimumContentHeight, alignment: .top)
                .padding(.horizontal, horizontalPadding(for: size))
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.immediately)
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
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: OnboardingActionBarHeightPreferenceKey.self,
                                value: geometry.size.height
                            )
                    }
                }
        }
        .onPreferenceChange(OnboardingActionBarHeightPreferenceKey.self) { newValue in
            actionBarHeight = newValue
        }
    }
}

private struct OnboardingActionBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
