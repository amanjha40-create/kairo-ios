import SwiftUI

/// Reachable only behind the explicit UI-test launch/route guard. No live requests.
struct VerifyNavigationFixtureHostView: View {
    @EnvironmentObject private var refreshStore: CandidateDataRefreshStore
    @State private var preset: VerificationInitiationPreset?
    @State private var service = VerifyNavigationFixtureService()

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button("Prepare new request") { preset = .employment(id: "fixture-employment") }
                    .accessibilityIdentifier("fixture.verify.begin")
                Button("Finish refresh") { Task { await service.finishRefresh() } }
                    .accessibilityIdentifier("fixture.verify.release")
            }
            Text(refreshStore.focusedVerificationRequestID ?? "none")
                .accessibilityIdentifier("fixture.verify.pending")
            VerifyOverviewContainerView()
                .environment(\.verifyOverviewService, service)
                .environment(\.verificationInitiationService, service)
        }
        .verificationInitiationSheet(preset: $preset, service: service) { id in
            refreshStore.verificationRequested(requestID: id)
        }
    }
}

private actor VerifyNavigationFixtureService: VerifyOverviewServiceProtocol, VerificationInitiationServiceProtocol {
    private var newID: String?
    private var held = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var sequence = 0

    func loadOverview() async throws -> VerifyOverview {
        if held { await withCheckedContinuation { waiters.append($0) } }
        var records = [Self.record("fixture-withdrawn", .withdrawnByCandidate)]
        if let newID, ProcessInfo.processInfo.environment["KAIRO_UI_TEST_VERIFY_MISSING"] != "1" {
            records.append(Self.record(newID, .pendingAdminReview))
        }
        return .init(requests: records)
    }
    func finishRefresh() {
        held = false
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
    func loadEligibility() async throws -> VerificationInitiationEligibility {
        .init(subjects: [.init(id: "fixture-employment", kind: .employment, title: "Synthetic navigation employer",
            subtitle: "Synthetic navigation role", verificationStatus: .notVerified, hasActiveRequest: false)])
    }
    func loadEvidence(for subject: VerificationInitiationSubject) async throws -> [VerificationEvidenceDocument] {
        [.init(id: "fixture-document", documentType: "other", filename: "synthetic-navigation.pdf", isUploadComplete: true)]
    }
    func submit(_ draft: VerificationInitiationDraft) async throws -> VerificationInitiationResult {
        sequence += 1
        let id = "fixture-new-\(sequence)"
        newID = id
        held = true
        return .init(requestID: id, status: .pendingAdminReview, reusedExistingRequest: false)
    }
    func performAction(requestID: String, action: VerifyRequestAction, response: String?, consent: VerificationSubmissionConsent?) async throws {
        throw URLError(.unsupportedURL)
    }
    private nonisolated static func record(_ id: String, _ status: VerifyVerificationStatus) -> VerifyRequestRecord {
        .init(id: id, routeID: id, subjectIDs: ["fixture-employment"], kind: .employment,
            typeTitle: "Employment verification", organizationName: "Synthetic navigation employer", requesterName: "Synthetic QA",
            requestedItem: "Synthetic navigation role", status: status, priority: "normal", dueDate: nil,
            createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 2), candidateResponse: nil,
            candidateResponseSubmittedAt: nil, acceptedAt: nil, consentedFields: [], consentedEvidenceScope: [],
            evidenceSummary: .init(totalItems: 0, documentItems: 0, fieldKeys: []), timeline: [])
    }
}
