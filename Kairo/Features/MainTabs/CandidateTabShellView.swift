import SwiftUI

struct CandidateTabShellView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.appConfiguration) private var appConfiguration
    private let uiTestHomeConfiguration: UITestHomeConfiguration
    private let uiTestCareerConfiguration: UITestCareerConfiguration
    private let uiTestVerifyConfiguration: UITestVerifyConfiguration
    private let uiTestPassportConfiguration: UITestPassportConfiguration

    init() {
        uiTestHomeConfiguration = UITestHomeConfiguration.current()
        uiTestCareerConfiguration = UITestCareerConfiguration.current()
        uiTestVerifyConfiguration = UITestVerifyConfiguration.current()
        uiTestPassportConfiguration = UITestPassportConfiguration.current()
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(CandidateTab.allCases) { tab in
                destinationView(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .tint(KairoColors.brandPrimary)
        .accessibilityIdentifier(KairoAccessibilityID.candidateTabShell)
    }

    @ViewBuilder
    private func destinationView(for tab: CandidateTab) -> some View {
        switch tab {
        case .home:
            HomeOverviewScreenView(
                state: uiTestHomeConfiguration.state ?? .default(isDemoMode: appConfiguration.isDemoModeEnabled)
            )
        case .career:
            CareerOverviewScreenView(
                state: uiTestCareerConfiguration.state ?? .default(isDemoMode: appConfiguration.isDemoModeEnabled)
            )
        case .verify:
            VerifyOverviewScreenView(
                state: uiTestVerifyConfiguration.state ?? .default(isDemoMode: appConfiguration.isDemoModeEnabled)
            )
        case .passport:
            PassportOverviewScreenView(
                state: uiTestPassportConfiguration.state ?? .default(isDemoMode: appConfiguration.isDemoModeEnabled)
            )
        case .more:
            TabPlaceholderScreen(tab: tab)
        }
    }
}
