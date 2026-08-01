import SwiftUI

struct CandidateTabShellView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.appConfiguration) private var appConfiguration
    private let uiTestHomeConfiguration: UITestHomeConfiguration
    private let uiTestCareerConfiguration: UITestCareerConfiguration

    init() {
        uiTestHomeConfiguration = UITestHomeConfiguration.current()
        uiTestCareerConfiguration = UITestCareerConfiguration.current()
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
        case .verify, .passport, .more:
            TabPlaceholderScreen(tab: tab)
        }
    }
}
