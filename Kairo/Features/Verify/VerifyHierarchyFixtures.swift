import Foundation
import SwiftUI

/// Synthetic, read-only screen states reachable only through explicit UI-test configuration.
nonisolated enum VerifyHierarchyFixtures {
    static var state: VerifyOverviewState {
        VerifyOverviewMapper.map(.init(requests: [
            record("attention", .pendingSubjectAcceptance), record("active", .pendingAdminReview),
            record("verified", .verified), record("rejected", .rejected),
            record("withdrawn", .withdrawnByCandidate), record("unable", .unableToVerify),
            record("expired", .expired), record("cancelled", .cancelled), record("unknown", .unknown("future_state"))
        ]))
    }

    static func record(_ id: String, _ status: VerifyVerificationStatus) -> VerifyRequestRecord {
        .init(id: "qa-\(id)", routeID: "qa-\(id)", subjectIDs: ["same-synthetic-employment"], kind: .employment,
            typeTitle: "Employment verification",
            organizationName: "Synthetic International Organization for Research and Community Development",
            requesterName: "Synthetic QA reviewer",
            requestedItem: "Senior Research and Community Programme Coordinator",
            status: status, priority: "normal", dueDate: nil,
            createdAt: Date(timeIntervalSince1970: 1), updatedAt: Date(timeIntervalSince1970: 3),
            candidateResponse: nil, candidateResponseSubmittedAt: nil, acceptedAt: nil,
            consentedAt: Date(timeIntervalSince1970: 1), consentVersion: "qa-v1",
            consentedFields: ["role", "employment_dates"], consentedEvidenceScope: ["employment_document"],
            evidenceSummary: .init(totalItems: 1, documentItems: 1, fieldKeys: ["employment_document"]),
            verificationContact: .init(id: "qa-contact", name: "Synthetic Verification Contact", email: "qa@example.invalid",
                role: "Synthetic reviewer", type: "employer", candidateNote: nil, reviewStatus: "pending",
                reviewNotes: nil, reviewedAt: nil),
            evidence: [.init(id: "qa-evidence", evidenceType: "document", fieldKey: "employment_document", status: "submitted",
                documentType: "other", originalFilename: "synthetic-verification.pdf", fileSize: 100,
                uploadStatus: "completed", downloadURL: nil)],
            timeline: [
                .init(id: "qa-event-late", eventType: "verification_submitted", eventSource: "candidate",
                    previousStatus: nil, newStatus: .pendingAdminReview, createdAt: Date(timeIntervalSince1970: 3)),
                .init(id: "qa-event-early", eventType: "evidence_uploaded", eventSource: "candidate",
                    previousStatus: nil, newStatus: nil, createdAt: Date(timeIntervalSince1970: 2))])
    }
}

struct VerifyHierarchyFixtureHostView: View {
    let initial: VerifyOverviewState
    @State private var state: VerifyOverviewState

    init(state: VerifyOverviewState) {
        initial = state
        _state = State(initialValue: state)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Reload fixture") { state = initial }.accessibilityIdentifier("verify.fixture.reload")
                Button("Fail refresh") { state = .errorFixture() }.accessibilityIdentifier("verify.fixture.fail")
            }
            .font(.caption)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            VerifyOverviewScreenView(state: $state, retryAction: { state = initial }, refreshAction: { state = initial })
        }
    }
}
