import Foundation

nonisolated enum ProductBrand {
    static let name = "KairoID"
    static let displayName = "KairoID"
    static let tagline = "Verify once. Trusted everywhere."
    static let supportEmailAddress = "contact@kairoid.com"
}

nonisolated enum ProductStatusLanguage {
    static let verified = "Verified"
    static let pendingReview = "Pending KairoID Review"
    static let needsAttention = "Needs your attention"
    static let rejected = "Rejected"
    static let withdrawn = "Withdrawn"
    static let draft = "Draft"
    static let candidateProvided = "Candidate-provided"
    static let unavailable = "Status unavailable"
    static let verificationIncomplete = "Verification incomplete"
}
