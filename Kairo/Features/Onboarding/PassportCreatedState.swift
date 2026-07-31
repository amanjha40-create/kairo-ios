import Foundation

struct PassportCreatedState: Equatable, Sendable {
    struct SummaryRow: Equatable, Identifiable, Sendable {
        enum Status: String, Equatable, Sendable {
            case verified = "Verified"
            case created = "Created"
            case active = "Active"
        }

        let id: String
        let title: String
        let status: Status
    }

    let title: String
    let subtitle: String
    let supportingCopy: String
    let summaryRows: [SummaryRow]
    let trustScoreTitle: String
    let trustScoreMessage: String
    let primaryActionTitle: String
    let secondaryActionTitle: String
    let reviewDestination: CandidateTab?

    static let completed = PassportCreatedState(
        title: "Your Trust Passport is ready.",
        subtitle: "Your verified professional identity is now ready to grow with every achievement, role, and verification you add.",
        supportingCopy: "This is only the beginning.\n\nYour Trust Passport will become stronger as you verify employment, education, certifications, projects, and professional experience.",
        summaryRows: [
            SummaryRow(id: "identity", title: "Identity", status: .verified),
            SummaryRow(id: "email", title: "Email", status: .verified),
            SummaryRow(id: "mobile", title: "Mobile", status: .verified),
            SummaryRow(id: "profile", title: "Profile", status: .created),
            SummaryRow(id: "trust-passport", title: "Trust Passport", status: .active)
        ],
        trustScoreTitle: "Trust Score",
        trustScoreMessage: "Trust Score will appear after your first professional verification.",
        primaryActionTitle: "Continue to Home",
        secondaryActionTitle: "Review my profile",
        reviewDestination: .passport
    )
}

extension OnboardingFlowState {
    var passportCreatedState: PassportCreatedState {
        .completed
    }
}
