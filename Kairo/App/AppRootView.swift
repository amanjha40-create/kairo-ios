import SwiftUI

struct AppRootView: View {
    @Environment(\.appConfiguration) private var appConfiguration

    var body: some View {
        ZStack(alignment: .top) {
            RootShellView()

            if appConfiguration.isDemoModeEnabled {
                DemoModeBanner(environment: appConfiguration.environment)
                    .padding(.horizontal, KairoSpacing.large)
                    .padding(.top, KairoSpacing.small)
            }
        }
        .background(KairoColors.background.ignoresSafeArea())
    }
}
