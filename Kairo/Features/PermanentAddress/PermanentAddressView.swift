import SwiftUI
import UniformTypeIdentifiers

struct PermanentAddressView: View {
    @StateObject private var model: PermanentAddressStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @State private var editing = false
    @State private var address = ClaimedPermanentAddress()
    @State private var adding = false
    @State private var selecting = false
    @State private var file: URL?
    @State private var type = ""
    @State private var issued = ""
    @State private var confirmed = false
    init(service: any PermanentAddressServing, collector: any AddressLocationCollecting = CoreAddressLocationCollector()) {
        _model = StateObject(wrappedValue: PermanentAddressStore(service: service, collector: collector))
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A private check of your claimed permanent address. This does not change your Trust Score.")
                    if let error = model.error { Text(error).accessibilityIdentifier("address.error") }
                    if let stage = model.stage { ProgressView(stage) }
                    if let state = model.state {
                        if !state.enabled { Text("Address verification is not available yet.") }
                        else {
                            if editing || state.claimedAddress == nil { addressForm }
                            else if let claimed = state.claimedAddress {
                                KairoSection(compact: true) {
                                    KairoSectionHeading(title: "Your claimed address")
                                    Text(claimed.display)
                                    Button("Edit permanent address") { address = claimed; editing = true }.disabled(model.busy)
                                }
                            }
                            if state.addressVersionId != nil && !editing {
                                progress(state)
                                documentCard
                                locationCard(state)
                            }
                        }
                    } else if model.busy { ProgressView("Loading address verification...") }
                    Button("Refresh verification status") { model.refresh() }.disabled(model.busy)
                }.padding().fixedSize(horizontal: false, vertical: true)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(KairoColors.background.ignoresSafeArea())
            .navigationTitle("Permanent address").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { model.stop(); dismiss() } } }
            .task { model.refresh() }
            .onDisappear { model.stop(); file = nil; address = .init() }
            .onChange(of: phase) { _, value in
                if value != .active { model.cancelLocation() }
                else { model.refresh() }
            }
            .onChange(of: model.state?.addressVersionId) { _, _ in resetDocumentInput(); editing = false }
            .onChange(of: model.addressSaveRevision) { _, _ in editing = false }
            .onChange(of: model.document) { _, _ in confirmed = false; if model.document?.status != "UPLOADING" { file = nil; adding = false } }
            .fileImporter(isPresented: $selecting, allowedContentTypes: [.pdf, .jpeg, .png, .webP]) { result in
                if case .success(let url) = result { file = url; confirmed = false }
            }
        }
        .tint(KairoColors.brandPrimary)
    }
    private var addressForm: some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: "Permanent Address")
            Text("Enter your permanent address, not just your city. Changing it starts a new verification version; previous location checks will not carry over.")
            TextField("Address line 1", text: $address.addressLine1)
            TextField("Address line 2 (optional)", text: Binding(get: { address.addressLine2 ?? "" }, set: { address.addressLine2 = $0 }))
            TextField("Locality (optional)", text: Binding(get: { address.locality ?? "" }, set: { address.locality = $0 }))
            TextField("City", text: $address.city)
            TextField("State", text: $address.state)
            TextField("PIN code", text: $address.postalCode).keyboardType(.numberPad)
            Text("Country: India")
            Button("Save permanent address") { model.save(address) }.buttonStyle(KairoActionStyle(role: .secondary))
                .disabled(model.busy || !address.isValid)
            if model.state?.claimedAddress != nil { Button("Cancel edit") { editing = false }.disabled(model.busy) }
        }.textFieldStyle(.roundedBorder).disabled(model.busy)
    }
    private func progress(_ state: PermanentAddressState) -> some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: "Verification progress")
            Text(state.label).font(.headline).accessibilityIdentifier("address.status")
            Text("Location checks: \(state.progress)").accessibilityIdentifier("address.progress")
            Text("Three successful checks on separate India calendar days within seven days, plus an approved matching address document, are required.")
            if state.targetSource == "onsite_confirmation" && state.successfulGpsChecks == 1 { Text("Location confirmed. 2 more checks are required on different days.") }
            if !state.isVerified { Text("Permanent Address: Not yet verified") }
            if state.todayComplete == true { Text("Today's location check is complete. Come back on another day to continue verification.") }
            if state.geocodeStatus == "NEEDS_REVIEW" { Text("We couldn't locate this address precisely enough. Please review your address. Location checks are unavailable until the address is resolved.") }
            if let expiry = state.expiresAt { Text("Current window ends \(Self.expiryText(expiry)).") }
        }
    }
    private var documentCard: some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: "Address document")
            Text(model.documentError ?? model.document?.label ?? "Loading document status...").font(.headline).accessibilityIdentifier("address.document.status")
            Text("Provide one document showing your current permanent address. Admin review is required. This private proof is not included in your shared Passport or Document Packs. Aadhaar is not required.")
            Text("Document approval is separate from your three location checks and does not change your Trust Score.")
            if model.document?.label == "Needs correction" { Text("Please provide a clear, current document that supports this address.") }
            if adding, model.document?.approved != true {
                Picker("Document type", selection: $type) {
                    Text("Choose document type").tag("")
                    ForEach(model.policy?.items ?? []) { Text($0.label).tag($0.value) }
                }.pickerStyle(.menu)
                TextField("Issue date (YYYY-MM-DD)", text: $issued).textInputAutocapitalization(.never)
                if let days = model.policy?.items.first(where: { $0.value == type })?.maxAgeDays { Text("Issue date required. This type must have been issued within \(days) days.") }
                Button("Choose address document") { selecting = true }
                if file != nil { Text("File selected") }
                if let policy = model.policy { Text("PDF, JPG, PNG or WebP. Maximum \(policy.maxBytes / 1_048_576) MB.") }
                Button("Upload document") {
                    if let file { model.upload(file: file, type: type, issued: issued.isEmpty ? nil : issued) }
                }.disabled(model.busy || file == nil || type.isEmpty || model.policy == nil || (model.policy?.items.first(where: { $0.value == type })?.maxAgeDays != nil && issued.isEmpty))
                Button("Cancel") { resetDocumentInput() }.disabled(model.busy)
            } else if model.document?.approved == false {
                Button(model.document?.documentId == nil ? "Add address document" : "Replace document") { adding = true }
                    .disabled(model.busy || model.policy == nil).accessibilityIdentifier("address.document.add")
            }
            if model.document?.status == "UPLOADED" && !adding {
                Toggle("I am providing this document as proof of my current permanent address.", isOn: $confirmed)
                Button("Submit for review") { model.submitDocument(confirmed: confirmed) }
                    .disabled(model.busy || !confirmed).accessibilityIdentifier("address.document.submit")
            }
            Button("Refresh document status") { model.refresh() }.disabled(model.busy)
        }.disabled(model.busy)
    }
    private func locationCard(_ state: PermanentAddressState) -> some View {
        KairoSection(compact: true) {
            KairoSectionHeading(title: state.targetConfirmationRequired == true ? "Confirm your address location" : "Verify your location")
            if state.targetConfirmationRequired == true { Text("We found your address area, but we need one location check while you're at the address to confirm the exact location.") }
            Text("KairoID uses your precise location only during this check to confirm that you are at your claimed address. We do not continuously track your location.")
            Text("Keep KairoID open and the screen on for 30–60 seconds. Collection stops if you leave, lock the screen or cancel. GPS alone does not verify your permanent address.")
            Button(state.targetConfirmationRequired == true ? "Confirm my location" : "Verify my location") { model.locate() }
                .disabled(model.busy || state.canStartLocation != true).accessibilityIdentifier("address.location.start")
            if model.locationActive { Button("Cancel location check") { model.cancelLocation() } }
        }
    }
    private func resetDocumentInput() { adding = false; file = nil; type = ""; issued = ""; confirmed = false }
    private static func expiryText(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.dateStyle = .medium; formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        return formatter.string(from: date)
    }
}

struct PermanentAddressEntry: View {
    var passport = false
    @Environment(\.permanentAddressService) private var service
    @EnvironmentObject private var session: AppSessionStore
    @Environment(\.scenePhase) private var phase
    @State private var state: PermanentAddressState?
    @State private var presented = false
    var body: some View {
        Group {
            if let service, service.enabled, let state, state.enabled, !passport || state.isVerified {
                KairoSection(compact: true) {
                    KairoSectionHeading(title: "Permanent address")
                    Text(state.isVerified ? "Verified" : state.label)
                    Text(state.isVerified ? "Address document + repeated location confirmation" : "Address evidence and three location checks on separate days.")
                    if !passport {
                        Button("View address verification") { presented = true }
                            .accessibilityIdentifier("address.entry")
                    }
                }.sheet(isPresented: $presented, onDismiss: { Task { await load() } }) { PermanentAddressView(service: service) }
            }
        }
        .task(id: session.currentUser?.id) { presented = false; state = nil; await load() }
        .onChange(of: phase) { _, next in if next == .active { Task { await load() } } }
    }
    private func load() async {
        guard let service, service.enabled, let identity = session.currentUser?.id else { state = nil; return }
        let next = try? await service.state()
        guard !Task.isCancelled, session.currentUser?.id == identity else { return }
        state = next // A secondary source never fails the whole Home aggregate.
    }
}
