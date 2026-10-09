import Foundation

/// Counts the supplied owner records; never derives verification or Trust Score.
nonisolated struct PassportHierarchyCounts: Equatable, Sendable {
    let verified: Int
    let candidateProvided: Int

    init(content: PassportOverviewContent) {
        let statuses = content.employment.map(\.verificationStatus)
            + content.education.map(\.verificationStatus)
            + content.certifications.map(\.verificationStatus)
            + content.skills.map(\.verificationStatus)
            + content.portfolio.map(\.verificationStatus)
        verified = statuses.filter { $0 == .verified }.count
        // Optional records retain neutral per-category counts, not a generic provenance count.
        let attributed = content.employment.map(\.verificationStatus)
            + content.education.map(\.verificationStatus)
            + content.portfolio.map(\.verificationStatus)
        candidateProvided = attributed.filter { $0 != .verified }.count
    }
}

/// Display-only projection. The canonical draft/capabilities still validate every mutation.
nonisolated enum PassportShareHierarchy {
    static let stages = ["1. Sharing mode", "2. Choose what to share", "3. Purpose & expiry", "4. Review", "5. Share ready"]

    static func modeTitle(_ mode: PassportSharingMode) -> String {
        mode == .mixed ? "Verified + Candidate-provided" : mode.title
    }

    static func selectedSections(_ permissions: PassportSharePermissions) -> [String] {
        permissions.enabledOptions.filter { ![.profile, .photo, .trustScore].contains($0) }.map(\.title)
    }

    static func purpose(_ draft: PassportShareDraft) -> String {
        let value = draft.label.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Required" : value
    }

    static func expiry(_ draft: PassportShareDraft) -> String {
        draft.expiryPreset == .custom
            ? draft.customExpiry.formatted(date: .abbreviated, time: .shortened)
            : draft.expiryPreset.title
    }
}
