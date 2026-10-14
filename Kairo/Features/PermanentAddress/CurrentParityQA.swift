import SwiftUI

// Isolated synthetic harness: no network, Keychain, real address files or Core Location.
enum CurrentParityQA {
    static func isEnabled(configuration: AppConfiguration,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        configuration.buildConfiguration == .staging && configuration.environment == .staging
        && !configuration.isDemoModeEnabled && arguments.contains(UITestLaunchConfiguration.enabledArgument)
        && environment["KAIRO_UI_TEST_CURRENT_PARITY"] == "1"
    }
}

actor CurrentParityFixtures: PermanentAddressServing, EmploymentReferencesServing {
    nonisolated let enabled = true
    nonisolated static let version = "00000000-0000-4000-8000-000000000001"
    nonisolated static let documentID = "00000000-0000-4000-8000-000000000002"
    nonisolated static let employmentID = "00000000-0000-4000-8000-000000000003"
    private var addressState: PermanentAddressState
    private var documentState: AddressDocumentState
    private var references: CandidateReferences
    private let scenario: String
    private(set) var starts = 0
    private(set) var completions = 0
    private(set) var cancellations = 0
    private(set) var uploads = 0
    private(set) var submissions = 0
    init(scenario: String = "required") {
        self.scenario = scenario
        let status = scenario == "verified" ? "PERMANENT_ADDRESS_VERIFIED" : "NEEDS_REVIEW"
        let doc = ["approved":"APPROVED_MATCHING", "verified":"APPROVED_MATCHING", "review":"UNDER_REVIEW", "rejected":"REJECTED", "correction":"NEEDS_CORRECTION", "uploaded":"UPLOADED"][scenario] ?? "REQUIRED"
        addressState = .init(enabled: true, status: status, addressVersionId: Self.version,
            claimedAddress: .init(addressLine1: "10 Synthetic QA Road", city: "Test City", state: "Test State", postalCode: "110001"),
            documentStatus: doc, successfulGpsChecks: scenario == "verified" ? 3 : scenario == "one" ? 1 : 0,
            requiredGpsChecks: 3, canStartLocation: true)
        documentState = .init(documentId: doc == "REQUIRED" ? nil : Self.documentID, documentType: "utility_bill", status: doc)
        let complete = scenario == "completed"
        let managerStatus = ["former":"completed", "confirmed":"ready_to_invite", "withheld":"ready_to_invite", "sent":"invitation_sent", "expired":"expired", "cannot_confirm":"cannot_confirm"][scenario] ?? (complete ? "completed" : "not_started")
        references = .init(employmentId: Self.employmentID, completedCount: complete ? 2 : 1, totalCount: 2,
            hrReference: .init(status: "completed"), reportingManager: .init(status: managerStatus,
                nominationId: managerStatus == "not_started" ? nil : Self.documentID,
                fullName: scenario == "withheld" ? "Private identity must not render" : nil,
                relationship: scenario == "former" ? "former_reporting_manager" : "reporting_manager",
                relationshipConfirmedByHr: ["confirmed", "withheld"].contains(scenario),
                identityWithheld: scenario == "withheld"))
    }
    func state() async throws -> PermanentAddressState {
        if scenario == "offline" { throw URLError(.notConnectedToInternet) }
        return addressState
    }
    func save(_ address: ClaimedPermanentAddress) async throws -> PermanentAddressState {
        guard address.isValid else { throw NetworkError.invalidResponse }
        if address == addressState.claimedAddress { return addressState }
        addressState.addressVersionId = "00000000-0000-4000-8000-000000000004"
        addressState.claimedAddress = address; addressState.successfulGpsChecks = 0
        addressState.documentStatus = "REQUIRED"
        // Exact backend-like invalidation, never infer verification from old proof.
        addressState = .init(enabled: true, status: "DOCUMENT_REQUIRED", addressVersionId: addressState.addressVersionId,
            claimedAddress: address, documentStatus: "REQUIRED", successfulGpsChecks: 0, requiredGpsChecks: 3, canStartLocation: false)
        documentState = .init(status: "REQUIRED")
        return addressState
    }
    func policy() async throws -> AddressDocumentPolicy {
        .init(items: [.init(value: "utility_bill", label: "Utility bill", maxAgeDays: 90), .init(value: "voter_id", label: "Voter ID", maxAgeDays: nil)],
            allowedContentTypes: ["application/pdf", "image/jpeg", "image/png", "image/webp"], maxBytes: 10_485_760)
    }
    func document(version: String) async throws -> AddressDocumentState {
        guard version == addressState.addressVersionId else { throw NetworkError.invalidResponse }; return documentState
    }
    func upload(version: String, type: String, file: URL, issued: String?) async throws -> AddressDocumentState {
        guard version == addressState.addressVersionId else { throw NetworkError.invalidResponse }
        uploads += 1
        if scenario == "upload_failure" { throw URLError(.networkConnectionLost) }
        // Deliberately does not open the selected file or create/upload bytes.
        documentState = .init(documentId: Self.documentID, documentType: type, status: "UPLOADED", issuedOn: issued)
        return documentState
    }
    func submit(version: String, document: String) async throws -> PermanentAddressState {
        guard version == addressState.addressVersionId, document == Self.documentID, documentState.status == "UPLOADED" else { throw NetworkError.invalidResponse }
        submissions += 1; documentState.status = "UNDER_REVIEW"; addressState.documentStatus = "UNDER_REVIEW"
        return addressState
    }
    func start(version: String) async throws -> AddressLocationChallenge {
        guard version == addressState.addressVersionId else { throw NetworkError.invalidResponse }
        starts += 1
        return .init(sessionId: Self.documentID, challenge: "synthetic-non-capability", expiresAt: Date().addingTimeInterval(120),
            minimumDurationSeconds: 30, maximumDurationSeconds: 60, minimumSamples: 5, maximumSamples: 10)
    }
    func complete(_ challenge: AddressLocationChallenge, samples: [AddressLocationSample]) async throws -> PermanentAddressState {
        completions += 1; addressState.lastLocationResult = "NEEDS_REVIEW"; return addressState
    }
    func cancel(_ challenge: AddressLocationChallenge) async throws { try Task.checkCancellation(); cancellations += 1 }
    func load(employmentID: String) async throws -> CandidateReferences {
        if scenario == "offline" { throw URLError(.notConnectedToInternet) }
        return references
    }
    func save(employmentID: String, input: ManagerNominationInput, change: Bool) async throws -> CandidateReferences {
        guard input.isValid else { throw NetworkError.invalidResponse }
        references = .init(employmentId: Self.employmentID, completedCount: 1, totalCount: 2,
            hrReference: .init(status: "completed"), reportingManager: .init(status: "awaiting_hr_validation",
                nominationId: Self.documentID, fullName: input.normalized.fullName, designation: input.normalized.designation,
                invitationBlockedReason: "awaiting_hr_validation"))
        return references
    }
}

@MainActor final class SyntheticAddressCollector: AddressLocationCollecting {
    enum Mode { case review, denied, disabled, timeout }
    var mode: Mode
    private(set) var cancelled = false
    init(mode: Mode = .review) { self.mode = mode }
    func ensurePermission() async throws {
        if mode == .denied { throw AddressCollectionError.permission }
        if mode == .disabled { throw AddressCollectionError.disabled }
    }
    func collect() async throws -> [AddressLocationSample] {
        defer { cancel() }
        if mode == .timeout { throw AddressCollectionError.timeout }
        return (0..<6).map { .init(latitude: 0, longitude: 0, accuracyM: 10,
            timestamp: Date(timeIntervalSince1970: 6 * Double($0)).ISO8601Format(), mockLocation: true) }
    }
    func cancel() { cancelled = true }
}

struct CurrentParityQARootView: View {
    @State private var selected: String?
    private let scenarios = ["required", "one", "review", "approved", "verified", "correction", "rejected", "uploaded", "offline", "denied", "disabled", "timeout", "upload_failure"]
    var body: some View {
        NavigationStack {
            List {
                Text("Synthetic parity QA — network, Keychain and GPS blocked").font(.caption)
                Section("Employment References") {
                    ForEach(["nomination", "completed", "confirmed", "former", "withheld", "sent", "expired", "cannot_confirm"], id: \.self) { value in
                        Button(value) { selected = "references:" + value }.accessibilityIdentifier("parity.references." + value)
                    }
                }
                Section("Permanent Address") {
                    ForEach(scenarios, id: \.self) { value in
                        Button(value) { selected = value }.accessibilityIdentifier("parity.address." + value)
                    }
                }
            }.navigationTitle("Current parity QA")
                .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
                    if let selected { CurrentParityQAScreen(scenario: selected).id(selected) }
                }
        }
    }
}

private struct CurrentParityQAScreen: View {
    let scenario: String
    @Environment(\.dismiss) private var dismiss
    @State private var fixture: CurrentParityFixtures
    init(scenario: String) {
        self.scenario = scenario
        _fixture = State(initialValue: CurrentParityFixtures(scenario: scenario.replacingOccurrences(of: "references:", with: "")))
    }
    var body: some View {
        if scenario.hasPrefix("references:") {
            NavigationStack {
                ScrollView { EmploymentReferencesView(employmentID: CurrentParityFixtures.employmentID).padding() }
                    .scrollDismissesKeyboard(.interactively)
                    .environment(\.employmentReferencesService, fixture)
                    .navigationTitle("Synthetic Employment")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            }
        } else {
            PermanentAddressView(service: fixture, collector: SyntheticAddressCollector(mode: scenario == "denied" ? .denied : scenario == "disabled" ? .disabled : scenario == "timeout" ? .timeout : .review))
        }
    }
}
