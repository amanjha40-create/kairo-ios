import SwiftUI

struct WelcomeScreenView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var selectedPage: IntroPage = .trust

    var body: some View {
        GeometryReader { geometry in
            let metrics = IntroMetrics(size: geometry.size)

            VStack(spacing: 0) {
                TabView(selection: $selectedPage) {
                    ForEach(IntroPage.allCases) { page in
                        IntroPageView(
                            page: page,
                            metrics: metrics,
                            onSkip: navigateToCreateAccount
                        )
                        .tag(page)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer(minLength: metrics.bottomContentSpacing)

                IntroPageIndicator(
                    pages: IntroPage.allCases,
                    selectedPage: selectedPage
                )
                .padding(.bottom, metrics.indicatorBottomSpacing)

                Button(action: advance) {
                    Text(selectedPage.primaryButtonTitle)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .frame(height: metrics.primaryButtonHeight)
                }
                .buttonStyle(IntroPrimaryButtonStyle())
                .accessibilityIdentifier(
                    selectedPage == .trust
                        ? KairoAccessibilityID.onboardingGetStarted
                        : KairoAccessibilityID.onboardingContinue
                )

                if selectedPage == .trust {
                    Button(action: { router.showLogin() }) {
                        Text("I already have an account")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: metrics.secondaryButtonHeight)
                    }
                    .buttonStyle(IntroSecondaryButtonStyle())
                    .accessibilityIdentifier(KairoAccessibilityID.onboardingExistingAccount)
                    .padding(.top, 12)
                }
            }
            .padding(.horizontal, metrics.horizontalPadding)
            .padding(.top, geometry.safeAreaInsets.top + metrics.topInset)
            .padding(.bottom, max(metrics.bottomInset, geometry.safeAreaInsets.bottom + 12))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(IntroPalette.background.ignoresSafeArea())
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func advance() {
        if let nextPage = selectedPage.next {
            withAnimation(.easeInOut(duration: 0.24)) {
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

private enum IntroPage: Int, CaseIterable, Identifiable {
    case trust
    case betterWay
    case solution
    case outcome

    var id: Int { rawValue }

    var next: IntroPage? {
        IntroPage(rawValue: rawValue + 1)
    }

    var showsSkip: Bool {
        self != .trust
    }

    var primaryButtonTitle: String {
        self == .trust ? "Get Started" : "Continue"
    }

    var eyebrow: String? {
        switch self {
        case .trust:
            nil
        case .betterWay:
            "A BETTER WAY"
        case .solution:
            "THE SOLUTION"
        case .outcome:
            "THE OUTCOME"
        }
    }

    var supportLines: [String] {
        switch self {
        case .trust:
            ["Build professional trust that moves with you."]
        case .betterWay:
            [
                "Keep your professional record together",
                "as your career grows."
            ]
        case .solution:
            [
                "Build your record once.",
                "Verify facts over time."
            ]
        case .outcome:
            [
                "Share your professional trust",
                "when it matters."
            ]
        }
    }
}

private struct IntroMetrics {
    let size: CGSize

    var isCompactHeight: Bool {
        size.height < 780
    }

    var isSmallWidth: Bool {
        size.width < 390
    }

    var horizontalPadding: CGFloat {
        isSmallWidth ? 20 : 28
    }

    var topInset: CGFloat {
        isCompactHeight ? 8 : 14
    }

    var bottomInset: CGFloat {
        isCompactHeight ? 16 : 22
    }

    var heroHeight: CGFloat {
        isCompactHeight ? 270 : 312
    }

    var titleSpacing: CGFloat {
        isCompactHeight ? 2 : 6
    }

    var pageSpacing: CGFloat {
        isCompactHeight ? 18 : 22
    }

    var supportSpacing: CGFloat {
        6
    }

    var heroToCopySpacing: CGFloat {
        isCompactHeight ? 18 : 24
    }

    var wordmarkWidth: CGFloat {
        isSmallWidth ? 160 : 188
    }

    var primaryButtonHeight: CGFloat {
        62
    }

    var secondaryButtonHeight: CGFloat {
        58
    }

    var indicatorBottomSpacing: CGFloat {
        isCompactHeight ? 18 : 22
    }

    var bottomContentSpacing: CGFloat {
        isCompactHeight ? 6 : 10
    }

    var headlineSize: CGFloat {
        isSmallWidth ? 29 : 33
    }

    var supportSize: CGFloat {
        isSmallWidth ? 14.5 : 15.5
    }
}

private struct IntroPageView: View {
    let page: IntroPage
    let metrics: IntroMetrics
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: metrics.pageSpacing) {
            topBar

            hero
                .frame(maxWidth: .infinity)
                .frame(height: metrics.heroHeight)

            VStack(spacing: metrics.heroToCopySpacing) {
                if let eyebrow = page.eyebrow {
                    IntroEyebrow(text: eyebrow)
                }

                headline
                    .multilineTextAlignment(.center)

                VStack(spacing: metrics.supportSpacing) {
                    ForEach(Array(page.supportLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: metrics.supportSize, weight: .medium, design: .rounded))
                            .foregroundStyle(IntroPalette.support)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var topBar: some View {
        HStack(alignment: .top) {
            if page == .trust {
                Image("KairoWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: metrics.wordmarkWidth)
                    .padding(.top, 8)

                Spacer(minLength: 0)
            } else {
                Spacer(minLength: 0)

                Button("Skip", action: onSkip)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(IntroPalette.teal)
                    .accessibilityIdentifier("onboarding.intro.skip")
            }
        }
        .frame(height: 44, alignment: .top)
    }

    @ViewBuilder
    private var headline: some View {
        switch page {
        case .trust:
            VStack(spacing: metrics.titleSpacing) {
                Text("Your trust.")
                Text("Your career.")
                Text("Anywhere.")
                    .foregroundStyle(IntroPalette.teal)
            }
            .font(.system(size: metrics.headlineSize, weight: .bold, design: .rounded))
            .foregroundStyle(IntroPalette.navy)
            .accessibilityIdentifier(OnboardingStep.welcome.titleAccessibilityIdentifier)
        case .betterWay:
            VStack(spacing: metrics.titleSpacing) {
                Text("Your career should")
                Text("build on itself.")
                    .foregroundStyle(IntroPalette.teal)
            }
            .font(.system(size: metrics.headlineSize, weight: .bold, design: .rounded))
            .foregroundStyle(IntroPalette.navy)
        case .solution:
            VStack(spacing: metrics.titleSpacing) {
                Text("Your professional trust,")
                Text("in one place.")
                    .foregroundStyle(IntroPalette.teal)
            }
            .font(.system(size: metrics.headlineSize, weight: .bold, design: .rounded))
            .foregroundStyle(IntroPalette.navy)
        case .outcome:
            VStack(spacing: metrics.titleSpacing) {
                Text("Opportunities")
                Text("find you faster.")
                    .foregroundStyle(IntroPalette.teal)
            }
            .font(.system(size: metrics.headlineSize, weight: .bold, design: .rounded))
            .foregroundStyle(IntroPalette.navy)
        }
    }

    @ViewBuilder
    private var hero: some View {
        switch page {
        case .trust:
            IntroTrustHero()
        case .betterWay:
            IntroRecordsHero()
        case .solution:
            IntroSolutionHero()
        case .outcome:
            IntroOutcomeHero()
        }
    }
}

private struct IntroEyebrow: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(IntroPalette.teal)
                .frame(width: 10, height: 10)

            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(IntroPalette.eyebrow)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.9))
                .overlay(
                    Capsule()
                        .stroke(IntroPalette.line, lineWidth: 1)
                )
        )
    }
}

private struct IntroPageIndicator: View {
    let pages: [IntroPage]
    let selectedPage: IntroPage

    var body: some View {
        HStack(spacing: 10) {
            ForEach(pages) { page in
                Circle()
                    .fill(page == selectedPage ? IntroPalette.teal : IntroPalette.dot)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

private struct IntroPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(IntroPalette.navy.opacity(configuration.isPressed ? 0.92 : 1))
            )
    }
}

private struct IntroSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(IntroPalette.navy)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.92 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(IntroPalette.line, lineWidth: 1.2)
            )
    }
}

private struct IntroTrustHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(IntroPalette.heroGlow)
                .padding(.horizontal, 26)
                .padding(.vertical, 10)

            VStack(spacing: 18) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(IntroPalette.navy)
                    .frame(maxWidth: 360)
                    .frame(height: 184)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 54, height: 54)

                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(IntroPalette.teal)
                                }

                                Spacer()

                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("Shared with consent")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(IntroPalette.teal)
                                .padding(.horizontal, 14)
                                .frame(height: 40)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.09))
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Kairo Passport")
                                    .font(.system(size: 21, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.white)

                                Text("Professional trust that moves with you.")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.84))
                            }

                            VStack(spacing: 12) {
                                Capsule()
                                    .fill(Color.white.opacity(0.94))
                                    .frame(height: 12)
                                Capsule()
                                    .fill(Color.white.opacity(0.42))
                                    .frame(width: 250, height: 12)
                            }
                        }
                        .padding(22)
                    }
            }
        }
    }
}

private struct IntroRecordsHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(IntroPalette.heroGlow)
                .frame(maxWidth: 360)

            OrbitPath(trimStart: 0.04, trimEnd: 0.88)
                .stroke(IntroPalette.orbit, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, dash: [9, 7]))
                .frame(width: 332, height: 206)
            OrbitPath(trimStart: 0.12, trimEnd: 0.98)
                .stroke(IntroPalette.orbit, style: StrokeStyle(lineWidth: 2.3, lineCap: .round, dash: [9, 7]))
                .frame(width: 280, height: 180)

            VStack(spacing: -16) {
                IntroRecordCard(icon: "graduationcap.fill", title: "Education", width: 332)
                    .rotationEffect(.degrees(1.2))
                    .offset(x: -8)

                IntroRecordCard(icon: "rosette", title: "Certification", width: 336)
                    .rotationEffect(.degrees(-1.2))
                    .offset(x: 12)

                IntroRecordCard(icon: "briefcase.fill", title: "Employment", width: 318)
                    .rotationEffect(.degrees(1.1))
                    .offset(x: -18)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct IntroRecordCard: View {
    let icon: String
    let title: String
    let width: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.97))
            .frame(width: width, height: 74)
            .overlay {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(IntroPalette.teal.opacity(0.12))
                            .frame(width: 40, height: 40)

                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(IntroPalette.teal)
                    }

                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(IntroPalette.navy)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
            }
            .shadow(color: Color.black.opacity(0.06), radius: 18, x: 0, y: 10)
    }
}

private struct IntroSolutionHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(IntroPalette.heroGlow)
                .frame(maxWidth: 360)
                .padding(.horizontal, 12)

            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.97))
                        .frame(width: 240, height: 206)
                        .overlay {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(IntroPalette.teal)

                                    Text("Your Trust Passport")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundStyle(IntroPalette.navy)
                                }

                                IntroPassportRow(icon: "person.crop.circle.fill", label: "Identity")
                                IntroPassportRow(icon: "briefcase.fill", label: "Employment")
                                IntroPassportRow(icon: "graduationcap.fill", label: "Education")
                                IntroPassportRow(icon: "rosette", label: "Certification")
                            }
                            .padding(22)
                        }
                }

                VStack(spacing: 14) {
                    IntroMiniBadge(icon: "person.crop.circle.fill")
                    IntroMiniBadge(icon: "briefcase.fill")
                    IntroMiniBadge(icon: "graduationcap.fill")
                    IntroMiniBadge(icon: "rosette")
                }
            }
        }
    }
}

private struct IntroPassportRow: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(IntroPalette.teal.opacity(0.12))
                    .frame(width: 34, height: 34)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(IntroPalette.teal)
            }

            Text(label)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(IntroPalette.navy)

            Spacer(minLength: 0)
        }
    }
}

private struct IntroMiniBadge: View {
    let icon: String

    var body: some View {
        Circle()
            .fill(Color.white.opacity(0.97))
            .frame(width: 60, height: 60)
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(IntroPalette.teal)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }
}

private struct IntroOutcomeHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(IntroPalette.heroGlow)
                .frame(maxWidth: 360)

            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(IntroPalette.navy)
                    .frame(width: 220, height: 178)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.1))
                                        .frame(width: 42, height: 42)

                                    Image(systemName: "checkmark.shield.fill")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(IntroPalette.teal)
                                }

                                Capsule()
                                    .fill(Color.white.opacity(0.09))
                                    .frame(width: 126, height: 34)
                                    .overlay(
                                        HStack(spacing: 8) {
                                            Image(systemName: "paperplane.fill")
                                                .font(.system(size: 12, weight: .bold))
                                            Text("Share instantly")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        }
                                        .foregroundStyle(IntroPalette.teal)
                                    )
                            }

                            Text("Kairo Passport")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.white)

                            VStack(spacing: 12) {
                                Capsule()
                                    .fill(Color.white.opacity(0.92))
                                    .frame(height: 12)
                                Capsule()
                                    .fill(Color.white.opacity(0.42))
                                    .frame(width: 136, height: 12)
                            }
                        }
                        .padding(20)
                    }

                VStack(spacing: 18) {
                    Circle()
                        .fill(Color.white.opacity(0.97))
                        .frame(width: 68, height: 68)
                        .overlay {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(IntroPalette.teal)
                        }

                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(IntroPalette.teal)
                }
            }
        }
    }
}

private struct OrbitPath: Shape {
    let trimStart: CGFloat
    let trimEnd: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: rect)
        return path.trimmedPath(from: trimStart, to: trimEnd)
    }
}

private enum IntroPalette {
    static let teal = Color(red: 14 / 255, green: 165 / 255, blue: 164 / 255)
    static let navy = Color(red: 10 / 255, green: 20 / 255, blue: 58 / 255)
    static let support = Color(red: 104 / 255, green: 122 / 255, blue: 146 / 255)
    static let eyebrow = Color(red: 94 / 255, green: 110 / 255, blue: 135 / 255)
    static let dot = Color(red: 214 / 255, green: 222 / 255, blue: 232 / 255)
    static let line = Color.black.opacity(0.08)
    static let orbit = teal.opacity(0.44)
    static let heroGlow = LinearGradient(
        colors: [
            Color(red: 235 / 255, green: 252 / 255, blue: 250 / 255),
            Color(red: 225 / 255, green: 248 / 255, blue: 247 / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let background = LinearGradient(
        colors: [
            Color(red: 252 / 255, green: 255 / 255, blue: 255 / 255),
            Color(red: 246 / 255, green: 252 / 255, blue: 252 / 255)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
