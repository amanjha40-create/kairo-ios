import Foundation
import CoreGraphics

/// Exact current Android Staging story, inspected 2026-09-30. Presentation only.
enum WelcomePage: Int, CaseIterable, Identifiable {
    case career, identity, sharing, ownership
    var id: Int { rawValue }
    var next: Self? { Self(rawValue: rawValue + 1) }
    var primaryButtonTitle: String { self == .career || self == .ownership ? "Get Started" : "Continue" }
    var artworkComesFirst: Bool { self == .career || self == .ownership }

    var headline: String {
        switch self {
        case .career: "Your career."
        case .identity: "One identity."
        case .sharing: "Share with confidence."
        case .ownership: "Your verified career"
        }
    }
    var accentHeadline: String {
        switch self {
        case .career: "Verified once."
        case .identity: "All your trust."
        case .sharing: "Wherever you need."
        case .ownership: "comes with you."
        }
    }
    var support: String {
        switch self {
        case .career: "Build a verified professional identity that stays with you and can be shared wherever your career takes you."
        case .identity: "We bring your verified career information together in one secure identity."
        case .sharing: "Share your verified identity instantly and open doors to new opportunities."
        case .ownership: "Build your professional identity once and share it whenever you need."
        }
    }
    var benefit: WelcomeBenefit? {
        switch self {
        case .identity: WelcomeBenefit(symbol: "lock", title: "Private by default", body: "Only you decide what to share and with whom.")
        case .sharing: WelcomeBenefit(symbol: "checkmark", title: "You’re always in control", body: "Share what matters, with the right people, for the right purpose.")
        case .career, .ownership: nil
        }
    }
    static let ownershipBenefits = [
        WelcomeBenefit(symbol: "checkmark.shield", title: "Verify once", body: "We verify with trusted sources."),
        WelcomeBenefit(symbol: "lock", title: "You own it", body: "Your verified identity stays with you."),
        WelcomeBenefit(symbol: "square.and.arrow.up", title: "Share with confidence", body: "Share what matters, where it matters.")
    ]
    var artworkName: String { "WelcomeArtwork\(rawValue + 1)" }
    var artworkSize: CGSize { self == .ownership ? CGSize(width: 881, height: 1786) : CGSize(width: 853, height: self == .career ? 1685 : 1844) }
    var artworkCrop: CGRect {
        switch self {
        case .career: CGRect(x: 0, y: 320, width: 853, height: 635)
        case .identity: CGRect(x: 0, y: 585, width: 853, height: 705)
        case .sharing: CGRect(x: 0, y: 555, width: 853, height: 738)
        case .ownership: CGRect(x: 0, y: 225, width: 881, height: 650)
        }
    }
    var artworkDescription: String {
        switch self {
        case .career: "Career journey: Education, First Job, New Role, Achievements, Your verified identity."
        case .identity: "Work, Education, Certifications and References brought together in one identity."
        case .sharing: "A Trust Passport connecting Employers, Universities, Verifiers and Opportunities."
        case .ownership: "Your professional identity with work, education and achievements."
        }
    }
}

struct WelcomeBenefit: Identifiable {
    let symbol: String
    let title: String
    let body: String
    var id: String { title }
}
