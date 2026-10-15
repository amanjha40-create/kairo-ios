import SwiftUI

/// Explicit Staging + UI-test gate. AppDependencies supplies in-memory credentials and
/// DemoNetworkClient before this view exists. Normal launch has no preview entry point.
enum FinalMirrorQA {
    static func isEnabled(configuration: AppConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        configuration.buildConfiguration == .staging && configuration.environment == .staging
        && !configuration.isDemoModeEnabled && arguments.contains(UITestLaunchConfiguration.enabledArgument)
        && environment["KAIRO_UI_TEST_FINAL_MIRROR"] == "1"
    }
}

struct FinalMirrorQAHostView: View {
    @State private var previews = false
    var body: some View {
        VStack(spacing: 0) {
            // Keep the harness control above the tab shell's full-window tour
            // geometry layer; that layer must not intercept this synthetic entry.
            Button { previews = true } label: {
                Text("Synthetic surface & motion previews")
                    .font(.caption).frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).background(KairoColors.surface)
            .accessibilityIdentifier("mirror.preview.open")
            .sheet(isPresented: $previews) { FinalMirrorPreviewView() }
            .zIndex(1)
            AppRootView().zIndex(0)
        }
    }
}

struct FinalMirrorPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var verified = false
    @State private var references = 1
    @State private var connected = false
    @State private var checks = 0
    @State private var country = "IN"
    @State private var region = "Karnataka"
    @State private var city = "Bengaluru"
    @State private var childText = "Preserved draft"
    @State private var scenarios = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Synthetic values only. No account writes, provider, GPS, documents or email.").font(.caption)
                    KairoSection(compact: true) {
                        KairoStatusChip(title: verified ? "Verified" : "Pending", tone: verified ? .verified : .pending)
                        Button("Preview newly Verified") { verified.toggle() }.buttonStyle(KairoActionStyle())
                    }
                    previewRow("References", detail: "\(references) of 2 completed", kind: .references, trigger: references) {
                        references = references == 1 ? 2 : 1
                    }
                    previewRow("DigiLocker", detail: connected ? "Connected" : "Not connected", kind: .connected, trigger: connected ? 1 : 0) {
                        connected.toggle()
                    }
                    previewRow("Location checks", detail: "\(checks) of 3 completed", kind: .location, trigger: checks) {
                        checks = checks < 3 ? checks + 1 : 0
                    }
                    KairoDisclosure(title: "Retained draft", identifier: "mirror.draft") {
                        TextField("Synthetic draft", text: $childText).textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("mirror.draft.field")
                    }
                    CandidateLocationFields(country: $country, region: $region, city: $city, identifier: "mirror.location")
                    Button("References & address state matrix") { scenarios = true }.buttonStyle(KairoActionStyle())
                }.padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Surface & motion preview").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $scenarios) {
                CurrentParityQARootView().safeAreaInset(edge: .bottom) {
                    Button("Back to motion previews") { scenarios = false }
                        .frame(maxWidth: .infinity, minHeight: 44).background(KairoColors.surface)
                }
            }
        }
    }
    private func previewRow(_ title: String, detail: String, kind: KairoTrustSymbol, trigger: Int, action: @escaping () -> Void) -> some View {
        KairoSection(compact: true) {
            HStack {
                KairoTrustSignature(kind: kind, trigger: trigger)
                VStack(alignment: .leading) { Text(title).font(.headline); Text(detail) }
            }.accessibilityElement(children: .combine)
            Button("Preview \(title)", action: action).buttonStyle(KairoActionStyle())
        }
    }
}
