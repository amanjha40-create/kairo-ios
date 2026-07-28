import SwiftUI

struct RootShellView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        switch router.rootDestination {
        case .onboarding:
            OnboardingFlowView()
        case .mainTabs:
            CandidateTabShellView()
        }
    }
}
