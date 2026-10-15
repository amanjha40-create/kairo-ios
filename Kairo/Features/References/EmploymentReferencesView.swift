import SwiftUI

struct EmploymentReferencesView: View {
    let employmentID: String
    @Environment(\.employmentReferencesService) private var service
    @Environment(\.scenePhase) private var phase
    @State private var summary: CandidateReferences?
    @State private var loading = false
    @State private var error: String?
    @State private var editing = false
    @State private var input = ManagerNominationInput()
    @State private var originalManager: ManagerReferenceSummary?
    @State private var confirmed = false
    @State private var saving = false
    @State private var notice: String?
    @State private var generation = UUID()
    @State private var completionMotion = 0

    var body: some View {
        if service.enabled {
            KairoSection(compact: true) {
                KairoSectionHeading(title: "References")
                if loading && summary == nil { ProgressView("Loading references") }
                if let error { Text(error).accessibilityIdentifier("references.error") }
                if let summary {
                    HStack {
                        KairoTrustSignature(kind: .references, trigger: completionMotion, size: 36)
                        Text("\(summary.completedCount) of \(summary.totalCount) completed").font(.headline)
                            .accessibilityIdentifier("references.progress")
                    }
                    Text("HR Reference").font(.headline).accessibilityAddTraits(.isHeader)
                    Text(ReferenceCopy.status(summary.hrReference.status))
                    Text(summary.reportingManager.relationship == "former_reporting_manager" ? "Former Reporting Manager" : "Reporting Manager").font(.headline).accessibilityAddTraits(.isHeader)
                    Text(ReferenceCopy.status(summary.reportingManager.status))
                    if let name = summary.reportingManager.visibleName { Text(name) }
                    if let designation = summary.reportingManager.visibleDesignation { Text(designation) }
                    if summary.reportingManager.relationshipConfirmedByHr == true { Text("Relationship confirmed by employer") }
                    blockedCopy(summary.reportingManager.invitationBlockedReason)
                    if summary.reportingManager.requiresChange {
                        Text("These details cannot be edited directly. Request a manager change to submit a new nomination for HR confirmation.")
                    }
                    KairoDisclosure(title: "How references work", identifier: "references.policy") {
                        Text("Completed through your employer's employment verification, without a separate invitation.")
                        Text("Reference completion is separate from employment verification. A pending or expired reference does not change Verified employment.")
                    }
                    if let notice { Text(notice) }
                    if editing {
                        if originalManager != summary.reportingManager {
                            Text("The nomination has changed or been reviewed by HR. Review the latest details before continuing.")
                            Button("Review updated references") { close() }
                        } else { editor }
                    } else {
                        Button(summary.reportingManager.requiresChange ? "Request manager change" : summary.reportingManager.nominationId == nil ? "Add Reporting Manager" : "Edit manager nomination") {
                            originalManager = summary.reportingManager
                            input = summary.reportingManager.requiresChange ? .init() : .init(fullName: summary.reportingManager.visibleName ?? "", designation: summary.reportingManager.visibleDesignation ?? "")
                            confirmed = false; notice = nil; error = nil; editing = true
                        }.buttonStyle(KairoActionStyle(role: .secondary))
                        .accessibilityIdentifier("references.nominate")
                    }
                }
                Button("Refresh references") { Task { await load() } }.disabled(saving || loading)
            }
            .tint(KairoColors.brandPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .task(id: employmentID) { summary = nil; close(); await load() }
            .onChange(of: phase) { _, value in if value == .active { Task { await load() } } }
            .onChange(of: summary?.completedCount) { previous, current in
                if let current, PremiumMotion.shouldCelebrate(previous: previous, current: current, target: 2) { completionMotion += 1 }
            }
            .onDisappear { generation = UUID(); close(); summary = nil; loading = false; saving = false }
        }
    }
    @ViewBuilder private func blockedCopy(_ reason: String?) -> some View {
        switch reason {
        case "awaiting_hr_validation": Text("Your employer/HR must confirm the relationship and contact details before an invitation can be sent.")
        case "employment_not_verified": Text("The invitation is waiting for employment verification.")
        case "email_required": Text("An employer-confirmed email is needed before KairoID can send the invitation.")
        default: EmptyView()
        }
    }
    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reporting manager details").font(.headline)
            Text("Your employer/HR must confirm the reporting manager and contact details before KairoID sends the reference request. Saving these details does not send an invitation.")
            Text("Relationship: Reporting Manager")
            Text("Contact details are kept private. Re-enter the contact details for this nomination.")
            TextField("Name", text: $input.fullName).accessibilityIdentifier("references.name")
            TextField("Designation", text: $input.designation)
            TextField("Work email", text: Binding(get: { input.workEmail ?? "" }, set: { input.workEmail = $0 }))
                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
            TextField("Phone (+country code)", text: Binding(get: { input.phone ?? "" }, set: { input.phone = $0 }))
                .keyboardType(.phonePad)
            Text("Provide at least one contact method. Use + and the country code for phone numbers.")
            if originalManager?.requiresChange == true {
                Toggle("I understand that changing the manager invalidates the previous HR validation. The new nomination needs HR confirmation again. My employment verification stays unchanged.", isOn: $confirmed)
            }
            Button(saving ? "Saving nomination" : originalManager?.requiresChange == true ? "Request change and revalidation" : "Save nomination") { Task { await save() } }
                .buttonStyle(KairoActionStyle()).disabled(saving || !input.isValid || (originalManager?.requiresChange == true && !confirmed))
                .accessibilityIdentifier("references.save")
            Button("Cancel") { close() }.disabled(saving)
        }.textFieldStyle(.roundedBorder).disabled(saving)
    }
    private func close() { editing = false; input = .init(); originalManager = nil; confirmed = false }
    private func load() async {
        guard !loading, !saving else { return }
        let ticket = generation
        loading = true; defer { if generation == ticket { loading = false } }
        do {
            let latest = try await service.load(employmentID: employmentID)
            guard generation == ticket, !Task.isCancelled else { return }
            summary = latest; error = nil
        } catch {
            guard generation == ticket, !Task.isCancelled else { return }
            self.error = "References could not be loaded. Your employment verification is unchanged."
        }
    }
    private func save() async {
        guard !saving, let originalManager, input.isValid, !originalManager.requiresChange || confirmed else { return }
        let ticket = generation
        let submittedInput = input
        saving = true; defer { if generation == ticket { saving = false } }
        do {
            // Re-read immediately before mutation; no automatic write retry after ambiguous outcomes.
            let latest = try await service.load(employmentID: employmentID)
            guard generation == ticket, !Task.isCancelled else { return }
            summary = latest
            guard latest.reportingManager == originalManager else { return }
            let saved = try await service.save(employmentID: employmentID, input: submittedInput, change: originalManager.requiresChange)
            guard generation == ticket, !Task.isCancelled else { return }
            summary = saved
            close(); notice = "Nomination saved. HR confirmation is required before an invitation can be sent."; error = nil
        } catch {
            guard generation == ticket, !Task.isCancelled else { return }
            self.error = ReferenceCopy.error(error)
            if let latest = try? await service.load(employmentID: employmentID), generation == ticket, !Task.isCancelled { summary = latest }
        }
    }
}
