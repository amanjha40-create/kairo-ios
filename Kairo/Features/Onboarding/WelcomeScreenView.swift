import SwiftUI

struct WelcomeScreenView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage: WelcomePage = .career

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 12) {
                TabView(selection: $selectedPage) {
                    ForEach(WelcomePage.allCases) { page in
                        ScrollView(.vertical) {
                            WelcomePageContent(page: page, onSkip: navigateToCreateAccount)
                                .padding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                        .accessibilityIdentifier("onboarding.welcome.page.\(page.rawValue)")
                        .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .clipped()

                pageIndicator
                Button(action: advance) {
                    HStack(spacing: 12) {
                        Text(selectedPage.primaryButtonTitle)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(WelcomePalette.arrow)
                            .accessibilityHidden(true)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(.white)
                    .background(WelcomePalette.navy, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(
                    selectedPage == .career
                        ? KairoAccessibilityID.onboardingGetStarted
                        : KairoAccessibilityID.onboardingContinue
                )

                Button(action: { router.showLogin() }) {
                    (Text("Already have an account? ").foregroundColor(WelcomePalette.support)
                        + Text("Log in").foregroundColor(WelcomePalette.teal).bold().underline())
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(KairoAccessibilityID.onboardingExistingAccount)
                .accessibilityHint("Log in without completing the introduction.")
            }
            .padding(.horizontal, geometry.size.width < 390 ? 20 : 28)
            .padding(.top, 8)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            // Only the background crosses safe areas.
            .background(WelcomePalette.background.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var pageIndicator: some View {
        HStack(spacing: 9) {
            ForEach(WelcomePage.allCases) { page in
                Capsule()
                    .fill(page == selectedPage ? WelcomePalette.teal : WelcomePalette.inactiveDot)
                    .frame(width: page == selectedPage ? 22 : 7, height: 7)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: selectedPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Introduction")
        .accessibilityValue("Page \(selectedPage.rawValue + 1) of \(WelcomePage.allCases.count)")
        .accessibilityIdentifier("onboarding.intro.pageIndicator")
    }

    private func advance() {
        if let nextPage = selectedPage.next {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.24)) {
                selectedPage = nextPage
            }
        } else {
            navigateToCreateAccount()
        }
    }

    private func navigateToCreateAccount() {
        router.advanceOnboarding(from: .welcome)
    }
}

private struct WelcomePageContent: View {
    let page: WelcomePage
    let onSkip: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 29

    var body: some View {
        VStack(spacing: 16) {
            if page == .career {
                KairoIDBrandView(width: 174)
                    .accessibilityIdentifier("onboarding.welcome.wordmark")
            } else {
                HStack {
                    Spacer()
                    Button("Skip", action: onSkip)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(WelcomePalette.teal)
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("onboarding.intro.skip")
                }
            }

            if page.artworkComesFirst { artwork }
            headline
            Text(page.support)
                .font(.body)
                .foregroundStyle(WelcomePalette.support)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(page == .career ? "onboarding.welcome.support" : "onboarding.intro.\(page.rawValue).support.0")
            if !page.artworkComesFirst { artwork }

            if let benefit = page.benefit { benefitView(benefit) }
            if page == .ownership {
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .center, spacing: 20))
                    : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                layout {
                    ForEach(WelcomePage.ownershipBenefits) { benefit in
                        benefitView(benefit).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var headline: some View {
        VStack(spacing: 2) {
            Text(page.headline).foregroundStyle(WelcomePalette.navy)
            Text(page.accentHeadline).foregroundStyle(WelcomePalette.teal)
        }
        .font(.system(size: headlineSize, weight: .bold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(page == .career ? OnboardingStep.welcome.titleAccessibilityIdentifier : "onboarding.intro.\(page.rawValue).title")
    }

    private var artwork: some View {
        WelcomeArtwork(page: page)
            .frame(height: page == .career ? 258 : 225)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(page.artworkDescription)
            .accessibilityAddTraits(.isImage)
    }

    private func benefitView(_ benefit: WelcomeBenefit) -> some View {
        VStack(spacing: 8) {
            Image(systemName: benefit.symbol)
                .font(.title2)
                .foregroundStyle(WelcomePalette.teal)
                .frame(width: 44, height: 44)
                .background(WelcomePalette.teal.opacity(0.06), in: Circle())
                .accessibilityHidden(true)
            Text(benefit.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WelcomePalette.navy)
            Text(benefit.body)
                .font(.subheadline)
                .foregroundStyle(WelcomePalette.support)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Illustration-only viewport over the unmodified Android reference asset.
/// All headlines, benefits, progress and controls remain native accessible views.
private struct WelcomeArtwork: View {
    let page: WelcomePage

    var body: some View {
        GeometryReader { geometry in
            let crop = page.artworkCrop
            let scale = min(geometry.size.width / crop.width, geometry.size.height / crop.height)
            ZStack(alignment: .topLeading) {
                Image(page.artworkName)
                    .resizable()
                    .frame(width: page.artworkSize.width * scale, height: page.artworkSize.height * scale)
                    .offset(x: -crop.minX * scale, y: -crop.minY * scale)
                if page == .sharing {
                    // Replace the old wordmark once; do not copy the doubled Android overlay.
                    RoundedRectangle(cornerRadius: 8 * scale)
                        .fill(Color(red: 0.91, green: 0.96, blue: 0.97))
                        .frame(width: 202 * scale, height: 80 * scale)
                        .overlay {
                            KairoIDBrandView(width: 186 * scale).padding(8 * scale)
                        }
                        .offset(x: (315 - crop.minX) * scale, y: (755 - crop.minY) * scale)
                }
            }
            .frame(width: crop.width * scale, height: crop.height * scale, alignment: .topLeading)
            .clipped()
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.035),
                    .init(color: .black, location: 0.96), .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private enum WelcomePalette {
    static let navy = Color(red: 8 / 255, green: 30 / 255, blue: 67 / 255)
    static let teal = Color(red: 0, green: 0.46, blue: 0.49)
    static let arrow = Color(red: 0.02, green: 0.81, blue: 0.78)
    static let support = Color(red: 0.30, green: 0.37, blue: 0.46)
    static let inactiveDot = Color(red: 0.79, green: 0.83, blue: 0.86)
    // Reference welcome canvas stays light in both appearances. Explicit text
    // colours preserve contrast independently of the system colour scheme.
    static let background = Color(red: 0.975, green: 0.99, blue: 0.99)
}
