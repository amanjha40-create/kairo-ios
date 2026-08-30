import SafariServices
import SwiftUI

struct PublicPassportHandoffView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var browserDestination: PublicPassportBrowserDestination?

    let presentation: PublicPassportPresentation

    var body: some View {
        NavigationStack {
            KairoScreenContainer(
                title: title,
                subtitle: subtitle,
                titleAccessibilityIdentifier: titleAccessibilityIdentifier,
                scrollBehavior: .fixed
            ) {
                switch presentation.content {
                case .handoff(let destination):
                    handoffContent(destination)
                case .unavailable:
                    unavailableContent
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sheet(item: $browserDestination) { destination in
            PublicPassportSafariView(url: destination.url)
                .ignoresSafeArea()
        }
    }

    private var title: String {
        switch presentation.content {
        case .handoff: "Public Passport"
        case .unavailable: "Passport link unavailable"
        }
    }

    private var subtitle: String {
        switch presentation.content {
        case .handoff:
            "Continue to Kairo's public web experience without signing in."
        case .unavailable:
            "This link is malformed or unsupported."
        }
    }

    private var titleAccessibilityIdentifier: String {
        switch presentation.content {
        case .handoff: KairoAccessibilityID.publicPassportContent
        case .unavailable: KairoAccessibilityID.publicPassportUnavailable
        }
    }

    private func handoffContent(_ destination: PublicPassportDestination) -> some View {
        VStack(alignment: .leading, spacing: KairoSpacing.large) {
            KairoCard {
                Label("Browser-first by design", systemImage: "safari")
                    .font(KairoTypography.title2)
                    .foregroundStyle(KairoColors.textPrimary)

                Text("The public web page is the authoritative recipient view. It enforces the owner's permissions and shows verified or self-declared information truthfully.")
                    .font(KairoTypography.body)
                    .foregroundStyle(KairoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("No Kairo account or owner session is required.")
                    .font(KairoTypography.footnote)
                    .foregroundStyle(KairoColors.textSecondary)
            }

            KairoPrimaryButton(
                title: "Open Public Passport",
                accessibilityIdentifier: KairoAccessibilityID.publicPassportOpenInBrowser,
                action: {
                    browserDestination = PublicPassportBrowserDestination(url: destination.url)
                }
            )

            Text("Invalid, expired, and revoked links use the same privacy-preserving unavailable response. Kairo does not reveal whether a link existed previously.")
                .font(KairoTypography.footnote)
                .foregroundStyle(KairoColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var unavailableContent: some View {
        KairoErrorStateView(
            title: "This Passport link is unavailable",
            message: "Check that you opened a complete Kairo Passport link. For privacy, no additional link details are shown."
        )
        .accessibilityIdentifier(KairoAccessibilityID.publicPassportUnavailable)
    }

}

private struct PublicPassportBrowserDestination: Identifiable {
    let id = UUID()
    let url: URL
}

private struct PublicPassportSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
