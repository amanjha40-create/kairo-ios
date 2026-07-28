import SwiftUI

struct CandidateTabShellView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(CandidateTab.allCases) { tab in
                TabPlaceholderScreen(tab: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    .tag(tab)
            }
        }
        .tint(KairoColors.brandPrimary)
        .accessibilityIdentifier(KairoAccessibilityID.candidateTabShell)
    }
}
