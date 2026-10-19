import SwiftUI

struct MoreOverviewFixtureHostView: View {
    @State private var state: MoreOverviewState
    @State private var showingDeletion = false
    @State private var deletionCalls = 0
    private let deletionFixture: Bool
    private let addressFixture: CurrentParityFixtures?

    init(state: MoreOverviewState) {
        let testing = UITestLaunchConfiguration.current().isEnabled
        let variant = testing ? ProcessInfo.processInfo.environment["KAIRO_UI_TEST_SETTINGS_VARIANT"] : nil
        deletionFixture = variant == "deletion"
        if let variant, variant.hasPrefix("address_") {
            addressFixture = CurrentParityFixtures(scenario: String(variant.dropFirst("address_".count)))
        } else {
            addressFixture = nil
        }
        var initial = state
        if variant == "long" {
            initial.accountSummary = MoreAccountSummary(initials: "QA",
                name: "Synthetic QA Account With A Deliberately Long Display Name",
                emailAddress: "synthetic.long.account.label.for.accessibility@example.invalid",
                trustPassportStatus: "Active", supportingCopy: "")
        } else if variant == "minimal" {
            initial.accountSummary = MoreAccountSummary(initials: "K", name: "KairoID account", emailAddress: "",
                trustPassportStatus: "Pending", supportingCopy: "")
            initial.replaceNotificationPreferences([])
        }
        _state = State(initialValue: initial)
    }

    var body: some View {
        if deletionFixture {
            // Only the existing confirmation UI is exercised; this callback never calls a service.
            VStack {
                Text("Deletion handler calls: \(deletionCalls)").accessibilityIdentifier("settings.fixture.deletionCalls")
                Button("Open deletion confirmation") { showingDeletion = true }
            }
            .sheet(isPresented: $showingDeletion) {
                MoreDeleteAccountSheetView { _, _ in deletionCalls += 1 }
            }
        } else {
            MoreOverviewScreenView(state: $state, isLiveMode: false)
                .environment(\.permanentAddressService, addressFixture)
        }
    }
}
