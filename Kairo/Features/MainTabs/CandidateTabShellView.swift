import SwiftUI

struct CandidateTabShellView: View {
    @EnvironmentObject private var router: AppRouter
    @Environment(\.appConfiguration) private var appConfiguration
    private let uiTestHomeConfiguration: UITestHomeConfiguration
    private let uiTestCareerConfiguration: UITestCareerConfiguration
    private let uiTestVerifyConfiguration: UITestVerifyConfiguration
    private let uiTestPassportConfiguration: UITestPassportConfiguration
    private let uiTestMoreConfiguration: UITestMoreConfiguration

    init() {
        uiTestHomeConfiguration = UITestHomeConfiguration.current()
        uiTestCareerConfiguration = UITestCareerConfiguration.current()
        uiTestVerifyConfiguration = UITestVerifyConfiguration.current()
        uiTestPassportConfiguration = UITestPassportConfiguration.current()
        uiTestMoreConfiguration = UITestMoreConfiguration.current()
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
            if let uiTestState = uiTestHomeConfiguration.state {
                HomeOverviewScreenView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                HomeOverviewScreenView(state: .default(isDemoMode: true))
            } else {
                HomeOverviewContainerView()
            }
        case .career:
            if let uiTestState = uiTestCareerConfiguration.state {
                CareerOverviewScreenView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                CareerOverviewScreenView(state: .default(isDemoMode: true))
            } else {
                CareerOverviewContainerView()
            }
        case .verify:
            VerifyOverviewScreenView(
                state: uiTestVerifyConfiguration.state ?? .default(isDemoMode: appConfiguration.isDemoModeEnabled)
            )
        case .passport:
            if let uiTestState = uiTestPassportConfiguration.state {
                PassportOverviewScreenView(state: uiTestState)
            } else if appConfiguration.isDemoModeEnabled {
                PassportOverviewScreenView(state: .default(isDemoMode: true))
            } else {
                PassportOverviewContainerView()
            }
        case .more:
            MoreOverviewScreenView(
                state: uiTestMoreConfiguration.state ?? .default(isDemoMode: appConfiguration.isDemoModeEnabled)
            )
        }
    }
}
