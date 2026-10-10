import Foundation

nonisolated enum EmploymentEvidenceRole: String, Codable, CaseIterable, Sendable {
    case primary, supporting

    var title: String {
        self == .primary ? "Primary verification evidence" : "Supporting evidence"
    }
}

/// Readiness is a server response, never an upload-progress or category heuristic.
nonisolated struct EmploymentEvidenceEligibility: Decodable, Equatable, Sendable {
    let eligiblePrimaryCount: Int
    let minimumRequired: Int
    let eligible: Bool

    var canContinue: Bool { minimumRequired == 2 && eligible && eligiblePrimaryCount >= 2 }
    var progress: String {
        eligiblePrimaryCount >= 2 ? "\(eligiblePrimaryCount) documents added" : "\(max(0, eligiblePrimaryCount)) of 2 documents added"
    }

    static func isCompleted(status: String, checksum: String?) -> Bool {
        guard ["pending_review", "approved", "rejected"].contains(status.lowercased()),
              let checksum, checksum.count == 64, checksum != String(repeating: "0", count: 64) else { return false }
        return true
    }
}
