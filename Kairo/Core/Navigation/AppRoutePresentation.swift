import Foundation

extension CandidateTab {
    var title: String {
        switch self {
        case .home: "Home"
        case .career: "Career"
        case .verify: "Verify"
        case .passport: "Passport"
        case .more: "More"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .career: "briefcase"
        case .verify: "checkmark.shield"
        case .passport: "person.text.rectangle"
        case .more: "ellipsis.circle"
        }
    }
}

extension OnboardingStep {
    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .createAccount: "Create Account"
        case .verifyIdentity: "Verify Identity"
        case .chooseStart: "Choose Start"
        case .resumeImportOrQuickProfile: "Resume Import or Quick Profile"
        case .passportCreated: "Passport Created"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "Build, own, and share your professional trust that moves with you."
        case .createAccount:
            "Start building your portable professional trust profile."
        case .verifyIdentity:
            "Identity verification remains a placeholder in this milestone."
        case .chooseStart:
            "The branching point is locked in, but not yet connected to product flows."
        case .resumeImportOrQuickProfile:
            "Resume import and quick profile capture will plug into this placeholder later."
        case .passportCreated:
            "Passport completion hands off into the main candidate application shell."
        }
    }
}
