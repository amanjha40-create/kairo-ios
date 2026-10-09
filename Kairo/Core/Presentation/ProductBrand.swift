import Foundation

nonisolated enum ProductBrand {
    static let name = "KairoID"
    static let displayName = "KairoID"
    static let tagline = "Verify once. Trusted everywhere."
    static let supportEmailAddress = "contact@kairoid.com"
}

nonisolated enum ProductStatusLanguage {
    /// Optional record display only; stored provenance and verification stay intact.
    static func optionalRecordTitle(_ title: String) -> String? {
        title.caseInsensitiveCompare(candidateProvided) == .orderedSame ? nil : title
    }
    static let verified = "Verified"
    static let pendingReview = "Pending KairoID Review"
    static let needsAttention = "Needs your attention"
    static let rejected = "Rejected"
    static let withdrawn = "Withdrawn"
    static let draft = "Draft"
    static let candidateProvided = "Candidate-provided"
    static let unavailable = "Status unavailable"
    static let verificationIncomplete = "Verification incomplete"

    static func title(for rawValue: String) -> String {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch value {
        case "verified", "approved": return verified
        case "pending", "pending_review", "pending_verification", "awaiting_verification", "submitted", "under_review", "in_review": return pendingReview
        case "additional_info_requested": return needsAttention
        case "withdrawn": return withdrawn
        case "pending_upload": return draft
        case "self_declared", "not_verified", "unverified", "missing": return candidateProvided
        default: return VerifyVerificationStatus(rawBackendValue: value).style.title
        }
    }
}
